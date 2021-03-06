# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    $ResourceGroupName
)

if(!$env:RESOURCEGROUPNAME -and !$ResourceGroupName)
{
    Write-Error "Environment variable RESOURCEGROUPNAME is not set and ResourceGroupName parameter is not set"
    Exit
}
if(!$ResourceGroupName)
{
    $ResourceGroupName = $env:RESOURCEGROUPNAME
}

# Import text utilities module.
Import-Module -Name .\modules\text-utils.psm1

$deploymentId = Get-Random
$startTime = Get-Date
$acrName = (az acr list -g $ResourceGroupName --query [].name -o tsv)
$appKubernetesNamespace = "edge-app1"

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

# ----- Run Helm
Write-Title("Upgrade Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
$opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
$opcpublisherimage = $acrName + ".azurecr.io/dapr-adapter/iotedge/opc-publisher:" + $deploymentId
helm upgrade iot-edge-accelerator ./helm/iot-edge-accelerator `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string images.opcplcmodule="$opcplcimage" `
    --set-string images.opcpublishermodule="$opcpublisherimage" `
    --reuse-values `
    --namespace $appKubernetesNamespace
$runningTime = New-TimeSpan -Start $startTime

Write-Title("Tag:  $deploymentId")
Write-Title("Running time: " + $runningTime.ToString())