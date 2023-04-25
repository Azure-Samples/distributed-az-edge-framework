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
    [Parameter(mandatory=$false)]
    $ScriptsBranch = "main"
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name ./modules/text-utils.psm1

$appKubernetesNamespace = "edge-app1"

Write-Title("Start Deploying Application for L2")
$startTime = Get-Date

# ----- Flux deployment
Write-Title("Install Latest Release of Helm Chart via Flux v2 and Azure Arc - L2 level")

# Deploy Flux v2 configuration to install app on kubernetes edge for L2 layer.
az k8s-configuration flux create -g $AksClusterResourceGroupName -c $AksClusterName -t connectedClusters `
  -n edge-framework-ci-config --namespace $appKubernetesNamespace --scope cluster `
  -u https://github.com/azure-samples/distributed-az-edge-framework --branch $ScriptsBranch `
  --kustomization name=flux-kustomization prune=true path=/deployment/flux/l2

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time L2 app deployment:" + $runningTime.ToString())