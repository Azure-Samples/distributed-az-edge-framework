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
    $Location = 'westeurope',

    [string]
    [Parameter(mandatory=$false)]
    $ScriptsBranch = "main"
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name ./modules/text-utils.psm1
# Import-Module -Name ./modules/process-utils.psm1

$appKubernetesNamespace = "edge-app1"
$deploymentId = Get-Random
$kubeConfigFile = "./temp/$AksClusterName"

Write-Title("Start Deploying Application for L4")
$startTime = Get-Date

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\iiot-app.bicep --parameters applicationName=$ApplicationName location=$Location `
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

# ----- Prepare for Helm, out of band secret creation first
Write-Title("Connect via Arc to cluster, setup out of band config/secrets")

# ----- Create Arc cluster connect connection 
# Arc proxying is now tested on Azure Cloud Shell PW terminal. If running Linux and not in cloudshell: exit
if( -not (Confirm-AzEnvironment))
{
    Exit
}
$token = Get-DecodedToken("./temp/tokens/$AksClusterName.txt")
# Start Arc cluster connect in separate terminal process

Write-Title("Starting terminal Arc proxy")
Start-ProcessInNewTerminalPW -ProcessArgs "az connectedk8s proxy -n $AksClusterName -g $AksClusterResourceGroupName --file $kubeConfigFile --token $token" -WindowTitle "ArcProxy$AksClusterName"

Write-Title("Sleep for a few seconds to initialize proxy...")
Start-Sleep -s 10

kubectl create namespace $appKubernetesNamespace --kubeconfig $kubeConfigFile

# Create secrets' seed on Kubernetes via Arc, this is required by application to boot.
$dataGatewaySecretsSeed=@"
localPubSubModule:
  redisUri: redis-master.edge-core.svc.cluster.local:6379
dataGatewayModule:
  eventHubConnectionString: {0}
  storageAccountName: {1}
  storageAccountKey: {2}
"@ -f $eventHubConnectionString, $storageName, $storageKey

kubectl create secret generic data-gateway-module-secrets-seed `
  --from-literal=dataGatewaySecrets=$dataGatewaySecretsSeed -n $appKubernetesNamespace `
  --kubeconfig $kubeConfigFile

# --- Close Arc proxy
Write-Title("Closing Azure Arc proxy")
Stop-ProcessInNewTerminal -WindowTitle "ArcProxy$AksClusterName"

Write-Title("Install Latest Release of Helm Chart for Data Gateway via Flux v2 and Azure Arc")

# Deploy Flux v2 configuration to install app on kubernetes edge L4 layer.
az k8s-configuration flux create -g $AksClusterResourceGroupName -c $AksClusterName `
  -t connectedClusters -n edge-framework-ci-config --namespace $appKubernetesNamespace --scope cluster `
  -u https://github.com/azure-samples/distributed-az-edge-framework --branch $ScriptsBranch `
  --kustomization name=flux-kustomization prune=true path=/deployment/flux/l4

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time L4 app deployment:" + $runningTime.ToString())