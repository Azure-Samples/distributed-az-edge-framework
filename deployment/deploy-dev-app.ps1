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
    $AksClusterNameUpper,

    [string]
    [Parameter(mandatory=$true)]
    $AksClusterResourceGroupNameUpper,

    [string]
    [Parameter(Mandatory=$true)]
    $AksServicePrincipalNameUpper,

    # Note - if you want to deploy everything to same layer, use the above values also below
    [string]
    [Parameter(mandatory=$true)]
    $AksClusterNameLower,

    [string]
    [Parameter(mandatory=$true)]
    $AksClusterResourceGroupNameLower,

    [string]
    [Parameter(Mandatory=$true)]
    $AksServicePrincipalNameLower,

    [string]
    $Location = 'westeurope'
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$staticBranchName = "dapr-support"
$deploymentId = Get-Random

Write-Title("Start Deploying Application")
$startTime = Get-Date

# Get AKS SP object ID
$aksServicePrincipal = az ad sp list --display-name $AksServicePrincipalNameUpper | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).id

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file ./bicep/iiot-app.bicep --parameters applicationName=$ApplicationName aksObjectId=$aksSpObjectId acrCreate=true `
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
# ----- Set Branch Name to Static
$Env:BUILD_SOURCEBRANCH = "refs/heads/$staticBranchName"
$Env:Version_Prefix = $deploymentId
../lib/Industrial-IoT/tools/scripts/acr-build.ps1 -Path ../lib/Industrial-IoT/modules/src/Microsoft.Azure.IIoT.Modules.OpcUa.Publisher/src -Registry $acrName
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials for enterprise (upper) layer
Write-Title("Get AKS Credentials L4 Upper Layer")
az aks get-credentials `
    --admin `
    --name $AksClusterNameUpper `
    --resource-group $AksClusterResourceGroupNameUpper `
    --overwrite-existing

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
helm install iot-edge-l4 ./helm/iot-edge-l4 `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --namespace $appKubernetesNamespace `
    --create-namespace `
    --wait

# ----- Get Cluster Credentials for L2 (lower) layer - or L4 if all deployed in single cluster
Write-Title("Get AKS Credentials Lower Layer")
az aks get-credentials `
    --admin `
    --name $AksClusterNameLower `
    --resource-group $AksClusterResourceGroupNameLower `
    --overwrite-existing

# ----- Add role assignment for AKS service pricipal lower layer
Write-Title("Lower layer - add AKS SP role assignment to ACR")

# Get AKS SP object ID
$aksServicePrincipalLower = az ad sp list --display-name $AksServicePrincipalNameLower | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectIdLower = (az ad sp show --id $aksServicePrincipalLower.appId | ConvertFrom-Json).id

$acrResourceId = $(az acr show -g $resourceGroupApp -n $acrName --query id | ConvertFrom-Json)

# manual role assignment - this might change to bicep when we rework some of the flow
az role assignment create --assignee $aksSpObjectIdLower `
    --role "AcrPull" `
    --scope $acrResourceId

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster lower")

$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
$opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
$opcpublisherimage = $acrName + ".azurecr.io/$staticBranchName/iotedge/opc-publisher:" + $deploymentId + "-linux-amd64"

helm install iot-edge-l2 ./helm/iot-edge-l2 `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string images.opcplcmodule="$opcplcimage" `
    --set-string images.opcpublishermodule="$opcpublisherimage" `
    --namespace $appKubernetesNamespace `
    --create-namespace `
    --wait

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment: " + $runningTime.ToString())