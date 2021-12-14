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
$startTime = Get-Date
$acrName = (az acr list -g $ResourceGroupName --query [].name -o tsv)

# ----- Build and Push Containers
Write-Title("Build and Push Containers")
$deplymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image datagatewaymodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.DataGatewayModule/Dockerfile .
az acr build --image simulatedtemperaturesensormodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Dockerfile .
Set-Location -Path $deplymentDir

# ----- Run Helm
Write-Title("Upgrade Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
helm upgrade iot-edge-accelerator ./helm/iot-edge-accelerator `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `

$runningTime = New-TimeSpan -Start $startTime

Write-Host "Tag: " $deploymentId -ForegroundColor Green
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow