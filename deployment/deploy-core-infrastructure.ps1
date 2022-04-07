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

Write-Title("Start Deploying Core Infrastructure")
$startTime = Get-Date

# ----- Create AKS Service Principals
Write-Title("Create AKS Service Principals")
$aks1ServicePrincipalName = $ApplicationName + "-aks1-sp"
$aks2ServicePrincipalName = $ApplicationName + "-aks2-sp"

$aks1ServicePrincipal = (az ad sp create-for-rbac -n $aks1ServicePrincipalName) | ConvertFrom-Json
$aks2ServicePrincipal = (az ad sp create-for-rbac -n $aks2ServicePrincipalName) | ConvertFrom-Json


# Sleep to allow SP to be replicated across AAD instances.
# TODO: Update this to be more deterministic.
Start-Sleep -s 30

$aks1ClientId = $aks1ServicePrincipal.appId
$aks2ClientId = $aks2ServicePrincipal.appId
$aks1ObjectId = (az ad sp show --id $aks1ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks2ObjectId = (az ad sp show --id $aks2ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks1ClientSecret = $aks1ServicePrincipal.password
$aks2ClientSecret = $aks2ServicePrincipal.password

# ----- Retrieve Object Id of current user who is deploying solution.
$currentAzUsernameId = $(az ad signed-in-user show --query objectId | ConvertFrom-Json)

# ----- Deploy Bicep
Write-Title("Deploy Bicep files")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\core-infrastructure.bicep `
           --parameters currentAzUsernameId=$currentAzUsernameId applicationName=$ApplicationName `
           aks1ObjectId=$aks1ObjectId aks1ClientId=$aks1ClientId aks1ClientSecret=$aks1ClientSecret `
           aks2ObjectId=$aks2ObjectId aks2ClientId=$aks2ClientId aks2ClientSecret=$aks2ClientSecret `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$aks1Name = $r.properties.outputs.aks1Name.value
$aks2Name = $r.properties.outputs.aks2Name.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value

# ----- Connect AKS to Arc -----
Write-Host "Installing Arc providers, they may take some time to finish."
az feature register --namespace Microsoft.ContainerService --name AKS-ExtensionManager
az provider register --namespace Microsoft.ContainerService --wait
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

$env:RESOURCEGROUPNAME = $resourceGroupName
$env:AKS1NAME = $aks1Name
$env:AKS2NAME = $aks2Name

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow