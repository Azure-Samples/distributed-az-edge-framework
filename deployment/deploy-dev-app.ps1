# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,

    [string]
    [Parameter(mandatory=$true)]
    $AksClusterName,

    [string]
    [Parameter(mandatory=$true)]
    $AksClusterResourceGroupName,

    [string]
    [Parameter(Mandatory=$true)]
    $AksServicePrincipalName,

    [string]
    $Location = 'westeurope'
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$deploymentId = Get-Random

Write-Title("Start Deploying Application")
$startTime = Get-Date

# Get AKS SP object ID
$aksServicePrincipal = az ad sp list --display-name $AksServicePrincipalName | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).objectId

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\iiot-app.bicep --parameters applicationName=$ApplicationName aksObjectId=$aksSpObjectId acrCreate=true `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json
 
$acrName = $r.properties.outputs.acrName.value
$storageName = $r.properties.outputs.storageName.value
$resourceGroupApp = $r.properties.outputs.resourceGroupName.value
$eventHubNamespace = $r.properties.outputs.eventHubNameSpaceName.value
$eventHubSendRuleName = $r.properties.outputs.eventHubSendRuleName.value
$eventHubName = $r.properties.outputs.eventHubName.value

$eventHubConnectionString = (az eventhubs eventhub authorization-rule keys list --resource-group $resourceGroupApp `
        --namespace-name $eventHubNamespace --eventhub-name $eventHubName `
        --name $eventHubSendRuleName --query primaryConnectionString) | ConvertFrom-Json

$storageKey = (az storage account keys list  --resource-group $resourceGroupApp `
                --account-name $storageName --query [0].value -o tsv)

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
    git clone -b feature/dapr-adapter https://github.com/azure-samples/Industrial-IoT .\..\..\Industrial-IoT-Temp
}
Set-Location -Path .\..\..\Industrial-IoT-Temp
git pull
$Env:BUILD_SOURCEBRANCH = "feature/dapr-adapter"
$Env:Version_Prefix = $deploymentId
.\tools\scripts\acr-build.ps1 -Path .\modules\src\Microsoft.Azure.IIoT.Modules.OpcUa.Publisher\src -Registry $acrName
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials
Write-Title("Get AKS Credentials")
az aks get-credentials `
    --admin `
    --name $AksClusterName `
    --resource-group $AksClusterResourceGroupName `
    --overwrite-existing

# Copy Redis secret from edge-core namesapce to edge-app1 namespace where application is deployed.
kubectl create namespace $appKubernetesNamespace
kubectl get secret redis --namespace=edge-core -o yaml | % {$_.replace("namespace: edge-core","namespace: $appKubernetesNamespace")} | kubectl apply -f - 

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
    --namespace $appKubernetesNamespace `
    --create-namespace `
    --wait

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment: " + $runningTime.ToString())