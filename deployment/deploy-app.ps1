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
    [Parameter(mandatory=$true)]
    $AksClusterNameLower,

    [string]
    [Parameter(mandatory=$true)]
    $AksClusterResourceGroupNameLower,

    [string]
    $Location = 'westeurope',

    [string]
    $ScriptsBranch = "main"
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$deploymentId = Get-Random

Write-Title("Start Deploying Application")
$startTime = Get-Date

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\iiot-app.bicep --parameters applicationName=$ApplicationName `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json

$storageName = $r.properties.outputs.storageName.value
$resourceGroupApp = $r.properties.outputs.resourceGroupName.value
$eventHubNamespace = $r.properties.outputs.eventHubNameSpaceName.value
$eventHubSendRuleName = $r.properties.outputs.eventHubSendRuleName.value
$eventHubName = $r.properties.outputs.eventHubName.value

$eventHubConnectionString = (az eventhubs eventhub authorization-rule keys list --resource-group $resourceGroupApp `
        --namespace-name $eventHubNamespace --eventhub-name $eventHubName `
        --name $eventHubSendRuleName --query primaryConnectionString) | ConvertFrom-Json

$storageKey = (az storage account keys list  --resource-group $resourceGroupApp `
                --account-name $storageName --query [0].value -o tsv)

# ----- Run Helm
Write-Title("Install Latest Release of Helm Chart via Flux v2 and Azure Arc")

# ----- Get AKS Cluster Credentials for L4 (Upper layer)
az aks get-credentials --admin --name $AKSClusterName --resource-group $AKSClusterResourceGroupName --overwrite-existing

kubectl create namespace $appKubernetesNamespace

# Create secrets' seed on Kubernetes via Arc, this is required by application to boot.
$dataGatewaySecretsSeed=@"
localPubSubModule:
  redisUri: redis-master.edge-core.svc.cluster.local:6379
dataGatewayModule:
  eventHubConnectionString: {0}
  storageAccountName: {1}
  storageAccountKey: {2}
"@ -f $eventHubConnectionString, $storageName, $storageKey

kubectl create secret generic data-gateway-module-secrets-seed --from-literal=dataGatewaySecrets=$dataGatewaySecretsSeed -n $appKubernetesNamespace

# Deploy Flux v2 configuration to install app on kubernetes edge.
az k8s-configuration flux create -g $AksClusterResourceGroupNameLower -c $AksClusterNameLower `
  -t connectedClusters -n edge-framework-ci-config --namespace $appKubernetesNamespace --scope cluster `
  -u https://github.com/katriendg/distributed-az-edge-framework --branch $ScriptsBranch `
  --kustomization name=flux-kustomization prune=true path=/deployment/flux/upper

  #-u https://github.com/azure-samples/distributed-az-edge-framework --branch $ScriptsBranch `

# ----- Get AKS Cluster Credentials for L2 (Lower layer)
az aks get-credentials --admin --name $AKSClusterName --resource-group $AKSClusterResourceGroupName `--overwrite-existing

# Deploy Flux v2 configuration to install app on kubernetes edge for lower layer.
az k8s-configuration flux create -g $AksClusterResourceGroupNameLower -c $AksClusterNameLower -t connectedClusters `
  -n edge-framework-ci-config --namespace $appKubernetesNamespace --scope cluster `
  -u https://github.com/katriendg/distributed-az-edge-framework --branch $ScriptsBranch `
  --kustomization name=flux-kustomization prune=true path=/deployment/flux/lower

  # todo move to public repo before merge to main
  # https://github.com/azure-samples/distributed-az-edge-framework 

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment:" + $runningTime.ToString())