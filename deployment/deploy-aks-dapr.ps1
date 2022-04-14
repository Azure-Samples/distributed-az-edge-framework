# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,
    [string]
    $Location = 'westeurope',
    [switch]
    $DeleteResourceGroup
)

Function Write-Title ($text) {
    $width = (Get-Host).UI.RawUI.WindowSize.Width
    $title = ""
    if($text.length -ne 0)
    {
        $title = "=[ " + $text + " ]="
    }

    Write-Host $title.PadRight($width, "=") -ForegroundColor green
}

$deploymentId = Get-Random

Write-Title("Start Deploying")
$startTime = Get-Date

# ----- Create AKS Service Principals
Write-Title("Create AKS Service Principals")
$aks1ServicePrincipalName = $ApplicationName + "-aks1-sp"
$aks2ServicePrincipalName = $ApplicationName + "-aks2-sp"

$aks1ServicePrincipal = (az ad sp create-for-rbac -n $aks1ServicePrincipalName) | ConvertFrom-Json
$aks2ServicePrincipal = (az ad sp create-for-rbac -n $aks2ServicePrincipalName) | ConvertFrom-Json

# Sleep to allow SP to be replicated across AAD instances.
# TODO: Update this to be more deterministic.
Start-Sleep -s 30

$aks1ClientId = $aks1ServicePrincipal.appId
$aks2ClientId = $aks2ServicePrincipal.appId
$aks1ObjectId = (az ad sp show --id $aks1ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks2ObjectId = (az ad sp show --id $aks2ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks1ClientSecret = $aks1ServicePrincipal.password
$aks2ClientSecret = $aks2ServicePrincipal.password

# ----- Retrieve Object Id of current user who is deploying solution.
$currentAzUsernameId = $(az ad signed-in-user show --query objectId | ConvertFrom-Json)

# ----- Deploy Bicep
Write-Title("Deploy Bicep files")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\main.bicep `
           --parameters currentAzUsernameId=$currentAzUsernameId applicationName=$ApplicationName `
           aks1ObjectId=$aks1ObjectId aks1ClientId=$aks1ClientId aks1ClientSecret=$aks1ClientSecret `
           aks2ObjectId=$aks2ObjectId aks2ClientId=$aks2ClientId aks2ClientSecret=$aks2ClientSecret `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$acrName = $r.properties.outputs.acrName.value
$aks1Name = $r.properties.outputs.aks1Name.value
$aks2Name = $r.properties.outputs.aks2Name.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value
$storageKey = $r.properties.outputs.storageKey.Value
$storageName = $r.properties.outputs.storageName.Value
$eventHubConnectionString = $r.properties.outputs.eventHubConnectionString.value

# ----- Build and Push Containers
Write-Title("Build and Push Containers")
$deploymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image datagatewaymodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.DataGatewayModule/Dockerfile .
az acr build --image simulatedtemperaturesensormodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Dockerfile .
Set-Location -Path $deploymentDir

# ----- Build and Push Containers (OPC Publisher)
Write-Title("Build and Push Containers (OPC Publisher)")
if (!(Test-Path .\..\..\Industrial-IoT-Temp))
{
    git clone -b feature/dapr-adapter https://github.com/suneetnangia/Industrial-IoT .\..\..\Industrial-IoT-Temp
}
Set-Location -Path .\..\..\Industrial-IoT-Temp
git pull
$Env:BUILD_SOURCEBRANCH = "feature/dapr-adapter"
$Env:Version_Prefix = $deploymentId
.\tools\scripts\acr-build.ps1 -Path .\modules\src\Microsoft.Azure.IIoT.Modules.OpcUa.Publisher\src -Registry $acrName
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials
Write-Title("Get AKS #1 Credentials")
az aks get-credentials `
    --admin `
    --name $aks1Name `
    --resource-group $resourceGroupName `
    --overwrite-existing

#----- Proxy
Write-Title("Install Proxy")
helm install squid-proxy ./helm/squid-proxy `
    --namespace edge-proxy `
    --create-namespace `
    --wait

#----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace edge-core `
    --create-namespace `
    --wait

#----- Redis
Write-Title("Install Redis")
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --wait `
--namespace edge-core `
--create-namespace `
--wait

# Copy Redis secret from edge-core namesapce to edge-app1 namespace where application is deployed.
kubectl create namespace edge-app1
kubectl get secret redis --namespace=edge-core -o yaml | % {$_.replace("namespace: edge-core","namespace: edge-app1")} | kubectl apply -f - 

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
$opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
$opcpublisherimage = $acrName + ".azurecr.io/dapr-adapter/iotedge/opc-publisher:" + $deploymentId
helm install iot-edge-accelerator ./helm/iot-edge-accelerator `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string images.opcplcmodule="$opcplcimage" `
    --set-string images.opcpublishermodule="$opcpublisherimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --namespace edge-app1 `
    --create-namespace `
    --wait

# ----- Get AKS #1 Proxy IP Address
Write-Title("Get AKS #1 Proxy IP Address")
$proxy1 = kubectl get service squid-proxy-module -n edge-proxy -o json | ConvertFrom-Json
$proxy1Ip = $proxy1.status.loadBalancer.ingress.ip
$proxy1Port = $proxy1.spec.ports.port
$proxy1Url = "http://" + $proxy1Ip + ":" + $proxy1Port

# ----- Install Arc CLI Extensions
Write-Title("Azure Arc CLI Extensions")
az extension add --name "connectedk8s"
az extension add --name "k8s-configuration"
az extension add --name "k8s-extension"
az extension add --name "customlocation"

# ----- Enroll AKS #1 with Arc
Write-Title("Enroll AKS #1 with Arc")
az connectedk8s connect --name $aks1Name --resource-group $resourceGroupName --location $Location --proxy-http $proxy1Url --proxy-https $proxy1Url --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
az connectedk8s enable-features -n $aks1Name -g $resourceGroupName --features cluster-connect

# ----- Get Cluster Credentials
Write-Title("Get AKS #2 Credentials")
az aks get-credentials --admin --name $aks2Name --resource-group $resourceGroupName --overwrite-existing

#----- Proxy
Write-Title("Install Proxy")
helm install squid-proxy ./helm/squid-proxy `
    --set-string parent.ipAddress="$proxy1Ip" `
    --set-string parent.port="3128" `
    --namespace edge-proxy `
    --create-namespace `
    --wait
    
#----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace edge-core `
    --create-namespace `
    --wait

#----- Redis
Write-Title("Install Redis")
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --wait `
--namespace edge-core `
--create-namespace `
--wait

# Copy Redis secret from edge-core namesapce to edge-app1 namespace where application is deployed.
kubectl create namespace edge-app1
kubectl get secret redis --namespace=edge-core -o yaml | % {$_.replace("namespace: edge-core","namespace: edge-app1")} | kubectl apply -f - 

# ----- Deploy Edge App via Helm
Write-Title("Install Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
$opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
$opcpublisherimage = $acrName + ".azurecr.io/dapr-adapter/iotedge/opc-publisher:" + $deploymentId
helm install iot-edge-accelerator ./helm/iot-edge-accelerator `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string images.opcplcmodule="$opcplcimage" `
    --set-string images.opcpublishermodule="$opcpublisherimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --namespace edge-app1 `
    --create-namespace `
    --wait

# ----- Get AKS #2 Proxy IP Address
Write-Title("Get AKS #2 Proxy IP Address")
$proxy2 = kubectl get service squid-proxy-module -n edge-proxy -o json | ConvertFrom-Json
$proxy2Ip = $proxy2.status.loadBalancer.ingress.ip
$proxy2Port = $proxy2.spec.ports.port
$proxy2Url = "http://" + $proxy2Ip + ":" + $proxy2Port

# ----- Enroll AKS #2 with Arc
Write-Title("Enroll AKS #2 with Arc")
az connectedk8s connect --name $aks2Name --resource-group $resourceGroupName --location $Location --proxy-http $proxy2Url --proxy-https $proxy2Url --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
az connectedk8s enable-features -n $aks2Name -g $resourceGroupName --features cluster-connect

# ----- Clean up
if($DeleteResourceGroup)
{
    Write-Title("Delete Resources")
    if(Remove-AzResourceGroup -Name $resourceGroupName -Force)
    {
        Write-Host "All resources deleted" -ForegroundColor Yellow
    }

    Write-Title("Delete AKS Service Principals")
    az ad sp delete --id $aks1ClientId
    az ad sp delete --id $aks2ClientId
}

$env:RESOURCEGROUPNAME=$resourceGroupName

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow