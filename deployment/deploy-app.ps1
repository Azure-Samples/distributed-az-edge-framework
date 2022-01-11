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
    $aksClusterPrincipalID,
    [string]
    $Location = 'westeurope'
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

# ----- Deploy Bicep
Write-Title("Deploy Bicep files")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\app.bicep --parameters applicationName=$ApplicationName aksClusterPrincipalID=aksClusterPrincipalID `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$acrName = $r.properties.outputs.acrName.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value
$storageKey = $r.properties.outputs.storageKey.Value
$storageName = $r.properties.outputs.storageName.Value
$eventHubConnectionString = $r.properties.outputs.eventHubConnectionString.value

# ----- Copy (System) Public Container Images and Push to Private ACR
Write-Title("Copy and Push Containers (System)")
$deploymentDir = Get-Location
az acr login -n $acrName
docker pull suneetnangia/distributed-az-iot-edge-simulatedtemperaturesensormodule:main-ci-latest -a
docker tag suneetnangia/distributed-az-iot-edge-simulatedtemperaturesensormodule:main-ci-latest $acrName/distributed-az-iot-edge-simulatedtemperaturesensormodule:main-ci-latest | docker push $acrName/distributed-az-iot-edge-simulatedtemperaturesensormodule:main-ci-latest

# ----- Copy and Push Containers (OPC Publisher) to ACR
Write-Title("Build and Push Containers (OPC Publisher)")

# ----- Run Helm
# Write-Title("Install Pod/Containers with Helm in Cluster")
# $datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
# $simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
# $opcplcimage = "mcr.microsoft.com/iotedge/opc-plc:2.2.0"
# $opcpublisherimage = $acrName + ".azurecr.io/dapr-adapter/iotedge/opc-publisher:" + $deploymentId
# helm install iot-edge-accelerator ./helm/iot-edge-accelerator `
#     --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
#     --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
#     --set-string images.opcplcmodule="$opcplcimage" `
#     --set-string images.opcpublishermodule="$opcpublisherimage" `
#     --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
#     --set-string dataGatewayModule.storageAccountName="$storageName" `
#     --set-string dataGatewayModule.storageAccountKey="$storageKey"

$env:RESOURCEGROUPNAME=$resourceGroupName

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow