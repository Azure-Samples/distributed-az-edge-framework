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
    $Location = 'westeurope'
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

$storageKey = $r.properties.outputs.storageKey.value
$storageName = $r.properties.outputs.storageName.value
$eventHubConnectionString = $r.properties.outputs.eventHubConnectionString.value

# ----- Run Helm
Write-Title("Install Latest Release of Helm Chart via Flux v2 and Azure Arc")

# ----- Get AKS Cluster Credentials
az aks get-credentials --admin --name $AKSClusterName --resource-group $AKSClusterResourceGroupName --overwrite-existing

kubectl create namespace $appKubernetesNamespace
# Copy Redis secret from edge-core namesapce to edge-app namespace where application is deployed.
kubectl get secret redis --namespace=edge-core -o yaml | % {$_.replace("namespace: edge-core","namespace: $appKubernetesNamespace")} | kubectl apply -f -

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
az k8s-configuration flux create -g $AKSClusterResourceGroupName -c $AKSClusterName -t connectedClusters -n edge-framework-ci-config --namespace $appKubernetesNamespace --scope cluster -u https://github.com/suneetnangia/distributed-az-edge-framework --branch readiness/azure-samples --kustomization name=flux-kustomization prune=true path=/deployment/flux

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment:" + $runningTime.ToString())