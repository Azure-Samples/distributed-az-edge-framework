# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    $AppResourceGroupName,

    [string]
    [Parameter(mandatory=$true)]
    $L4ResourceGroupName,

    # leave empty if both workloads are deployed on single cluster L4
    [string]
    [Parameter(mandatory=$false)]
    $L2ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [bool]
    $SetupObservability = $true
)

if(!$env:RESOURCEGROUPNAME -and !$AppResourceGroupName)
{
    Write-Error "Environment variable RESOURCEGROUPNAME is not set and AppResourceGroupName parameter is not set"
    Exit
}
if(!$AppResourceGroupName)
{
    $AppResourceGroupName = $env:RESOURCEGROUPNAME
}

# Import text utilities module.
Import-Module -Name ./modules/text-utils.psm1

$deploymentId = Get-Random
$startTime = Get-Date
$acrName = (az acr list -g $AppResourceGroupName --query [].name -o tsv)
$appKubernetesNamespace = "edge-app1"
$staticBranchName = "dapr-support"

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

# ----- Run Helm for L4

Write-Title("Upgrade/Install Pod/Containers with Helm charts in Cluster L4")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$observabilityString = ($SetupObservability -eq $true) ? "true" : "false"
$samplingRate = ($SetupObservability -eq $true) ? "1" : "0" # in development we set to 1, in prod should be 0.0001 or similar, 0 turns off observability

# ----- Get Cluster Credentials for L4 layer
Write-Title("Get AKS Credentials L4 Layer")
$aksClusterL4 = (az aks list --resource-group $L4ResourceGroupName --query [].name -o tsv)
az aks get-credentials `
    --admin `
    --name $aksClusterL4 `
    --resource-group $L4ResourceGroupName `
    --overwrite-existing

helm upgrade iot-edge-l4 ./helm/iot-edge-l4 `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string observability.samplingRate="$samplingRate" `
    --set observability.enabled=$observabilityString `
    --namespace $appKubernetesNamespace `
    --reuse-values `
    --install

# ----- Run Helm for L2

# check if L2 resource group supplied: if not, use L4 for second Helm chart deployment, if means single cluster dev deployment
if($L2ResourceGroupName)
{
    Write-Title("Get AKS Credentials L2 Layer")
    $aksClusterL2 = (az aks list --resource-group $L2ResourceGroupName --query [].name -o tsv)
    az aks get-credentials `
        --admin `
        --name $aksClusterL2 `
        --resource-group $L2ResourceGroupName `
    --overwrite-existing
}
#else - use above loaded kubeconfig for L4, no need to get credentials

Write-Title("Upgrade/Install Pod/Containers with Helm charts in Cluster L2")
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
$opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
$opcpublisherimage = $acrName + ".azurecr.io/$staticBranchName/iotedge/opc-publisher:" + $deploymentId + "-linux-amd64"

helm upgrade iot-edge-l2 ./helm/iot-edge-l2 `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string images.opcplcmodule="$opcplcimage" `
    --set-string images.opcpublishermodule="$opcpublisherimage" `
    --set observability.enabled=$observabilityString `
    --set-string observability.samplingRate="$samplingRate" `
    --reuse-values `
    --namespace $appKubernetesNamespace `
    --install

$runningTime = New-TimeSpan -Start $startTime

Write-Title("Tag:  $deploymentId")
Write-Title("Your kubectl current context is now set to the AKS cluster '$(kubectl config current-context)'.")
Write-Title("Running time: " + $runningTime.ToString())