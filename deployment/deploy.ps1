# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,
    [string]
    $Location = 'westeurope',
    [switch]
    $DeleteResourceGroup
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
           --template-file .\bicep\main.bicep --parameters applicationName=$ApplicationName `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$aksName = $r.properties.outputs.aksName.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value

# ----- Get Cluster Credentials
Write-Title("Get AKS Credentials")
az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

# ----- Enable Arc
Write-Title("Enable ARC")
az extension add --name connectedk8s
az provider register --namespace Microsoft.Kubernetes --wait
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.ExtendedLocation --wait

# ----- Setup GitOps
Write-Title("Setup Gitops")
$gitUrl = (git config remote.origin.url)
az extension add --name k8s-configuration
az connectedk8s connect --name $aksName --resource-group $resourceGroupName
az k8s-configuration flux create -g $resourceGroupName `
    -c $aksName -t connectedClusters `
    -n edge-framework-ci-config --namespace edge-framework-ci-ns --scope cluster `
    -u $gitUrl --branch main `
    --kustomization name=flux-kustomization prune=true path=/deployment/flux

# ----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace dapr-system `
    --create-namespace `
    --wait

# ----- Clean up
if($DeleteResourceGroup)
{
    Write-Title("Delete Resources")
    if(Remove-AzResourceGroup -Name $resourceGroupName -Force)
    {
        Write-Host "All resources deleted" -ForegroundColor Yellow
    }
}

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow