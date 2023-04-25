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

    [Parameter(mandatory=$true)]
    [PSCustomObject]
    $L4AppConfig = $null,

    [string]
    $Location = 'westeurope'
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name ./modules/text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$staticBranchName = "dapr-support"
$deploymentId = Get-Random
$acrName = $L4AppConfig.AcrName
$appResourceGroupName = $L4AppConfig.AppResourceGroupName

Write-Title("Start Deploying Application L2")
$startTime = Get-Date

# Get AKS SP object ID
$aksServicePrincipal = az ad sp list --display-name $AksServicePrincipalName | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).id

# ----- Build and Push Containers
Write-Title("Build and Push Containers")
$deploymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image simulatedtemperaturesensormodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Dockerfile .
Set-Location -Path $deploymentDir

# ----- Build and Push Containers (OPC Publisher)
Write-Title("Build and Push Containers (OPC Publisher)")

# ----- Set Branch Name to Static
$Env:BUILD_SOURCEBRANCH = "refs/heads/$staticBranchName"
$Env:Version_Prefix = $deploymentId
../lib/Industrial-IoT/tools/scripts/acr-build.ps1 -Path ../lib/Industrial-IoT/modules/src/Microsoft.Azure.IIoT.Modules.OpcUa.Publisher/src -Registry $acrName
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials for L2 alyer
Write-Title("Get AKS Credentials L2 Layer")
az aks get-credentials `
    --admin `
    --name $AksClusterName `
    --resource-group $AksClusterResourceGroupName `
    --overwrite-existing

# ----- Add role assignment for AKS service pricipal L2 layer
Write-Title("L2 layer - add AKS SP role assignment to ACR")

$acrResourceId = $(az acr show -g $appResourceGroupName -n $acrName --query id | ConvertFrom-Json)

# manual role assignment - this might change to bicep when we rework some of the flow or use Azure Connected Registry
az role assignment create --assignee $aksSpObjectId `
    --role "AcrPull" `
    --scope $acrResourceId

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster L2")

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