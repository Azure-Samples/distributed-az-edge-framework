# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,
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
           --template-file .\bicep\core-infrastructure.bicep --parameters applicationName=$ApplicationName `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$aksName = $r.properties.outputs.aksName.value
$aksClusterPrincipalID = $r.properties.outputs.clusterPrincipalID
$resourceGroupName = $r.properties.outputs.resourceGroupName.value

# ----- Get Cluster Credentials
Write-Title("Get AKS Credentials")
az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

$env:RESOURCEGROUPNAME=$resourceGroupName

Write-Title($aksClusterPrincipalID)

$env:AKSCLUSTERPRINCIPALID=$aksClusterPrincipalID

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow