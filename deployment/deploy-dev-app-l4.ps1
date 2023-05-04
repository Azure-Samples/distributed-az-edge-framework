# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    #[Parameter(mandatory=$true)]
    $ApplicationName,

    [string]
    #[Parameter(mandatory=$true)]
    $AksClusterName,

    [string]
    #[Parameter(mandatory=$true)]
    $AksClusterResourceGroupName,

    [string]
    #[Parameter(Mandatory=$true)]
    $AksServicePrincipalName,

    [string]
    $Location = 'westeurope'
)

# Uncomment this if you are testing this script without deploy-az-dev-bootstrapper.ps1
Import-Module -Name ./modules/text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$deploymentId = Get-Random

Write-Title("Start Deploying Application L4")
$startTime = Get-Date

# Get AKS SP object ID
$aksServicePrincipal = az ad sp list --display-name $AksServicePrincipalName | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).id

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file ./bicep/iiot-app.bicep --parameters applicationName=$ApplicationName aksObjectId=$aksSpObjectId acrCreate=true location=$Location `
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
Write-Title("Build and Push Container Data Gateway and Workflow")
$deploymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image datagatewaymodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.DataGatewayModule/Dockerfile .
az acr build --image workflowmodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.WorkflowModule/Dockerfile .
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials for L4 layer
Write-Title("Get AKS Credentials L4 Layer")
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
$workflowmoduleimage = $acrName + ".azurecr.io/workflowmodule:" + $deploymentId
helm install iot-edge-l4 ./helm/iot-edge-l4 `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.workflowmodule="$workflowmoduleimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --namespace $appKubernetesNamespace `
    --create-namespace `
    --wait

$appConfig = [PSCustomObject]@{
    AcrName = $acrName
    AppResourceGroupName = $resourceGroupApp
  }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment: " + $runningTime.ToString())

return $appConfig