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
           --template-file .\bicep\app.bicep --parameters applicationName=$ApplicationName aksClusterPrincipalID=$aksClusterPrincipalID `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$acrName = $r.properties.outputs.acrName.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value
$storageKey = $r.properties.outputs.storageKey.Value
$storageName = $r.properties.outputs.storageName.Value
$eventHubConnectionString = $r.properties.outputs.eventHubConnectionString.value

# ----- Copy (System) Public Container Images and Push to Private ACR
# Write-Title("Copy and Push Containers (System)")

# ----- Copy and Push Containers (OPC Publisher) to Private ACR
# Write-Title("Build and Push Containers (OPC Publisher)")

# ----- Run Helm
# Write-Title("Install latest release of helm chart (not using ARC).")

helm repo add aziotaccl 'https://suneetnangia.github.io/distributed-az-edge-framework'
helm repo update
helm install az-edge-accelerator aziotaccl/iot-edge-accelerator `
--namespace edge-app `
--wait `
--set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
--set-string dataGatewayModule.storageAccountName="$storageName" `
--set-string dataGatewayModule.storageAccountKey="$storageKey"

$env:RESOURCEGROUPNAME=$resourceGroupName

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow