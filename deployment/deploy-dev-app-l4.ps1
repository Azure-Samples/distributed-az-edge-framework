# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    #[Parameter(mandatory=$true)]
    $ApplicationName="bindsi81nestedarc",

    [string]
    #[Parameter(mandatory=$true)]
    $AksClusterName="aks-bindsi81nestedar",

    [string]
    #[Parameter(mandatory=$true)]
    $AksClusterResourceGroupName="bindsi81nestedarcL4",

    #[string]
    #[Parameter(Mandatory=$true)]
    $AksServicePrincipalName="bindsi81nestedarcL4",

    #[string]
    $Location = 'westeurope',

    [Parameter(mandatory = $false)]
    [bool]
    $DeployLogicApp = $true
)

function DeployAppServiceEnvironment([string] $AksClusterResourceGroupName, [string] $AksClusterName, [string] $AcrName, [string] $StorageName, [string] $StorageKey, [string] $Location, [string] $DeploymentId) {
    # Install the App Service extension
    $extensionName = "appservice-ext" # Name of the App Service extension
    $kubeEnvironmentName = "appservice-env" # Name of the App Service Kubernetes environment resource
    $extensionId = $(az k8s-extension show `
            --cluster-type connectedClusters `
            --cluster-name $AksClusterName `
            --resource-group $AksClusterResourceGroupName `
            --name $extensionName `
            --query id `
            --output tsv)
    az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

    # Create a custom location
    $customLocationName = "appservice-customlocation" # Name of the custom location
    $customLocationId = $(az customlocation show `
            --resource-group $AksClusterResourceGroupName `
            --name $customLocationName `
            --query id `
            --output tsv)

    $kubeEnvironmentId = $(az appservice kube show `
        --resource-group $AksClusterResourceGroupName `
        --name $kubeEnvironmentName `
        --query id `
        --output tsv)

    # Deploy Bicep template to create the Logic App
    $acrUrl = az acr show --name $AcrName --query loginServer -o tsv
    $acrUsername = az acr credential show --name $AcrName --query username -o tsv
    $acrPassword = az acr credential show --name $AcrName --query passwords[0].value -o tsv
    $containerName = $acrName + ".azurecr.io/workflowmodule:" + $DeploymentId
    az deployment group create `
            --template-file .\bicep\logicApp.bicep --parameters `
            location=$Location `
            applicationName=$ApplicationName `
            storageName=$StorageName `
            storageKey=$StorageKey `
            customLocationId=$customLocationId `
            kubeEnvironmentId=$kubeEnvironmentId `
            use32BitWorkerProcess=$true `
            acrUrl=$acrUrl `
            acrUsername=$acrUsername `
            acrPassword=$acrPassword `
            containerName=$containerName `
            --name "logicApp-$DeploymentId" `
            --resource-group $AksClusterResourceGroupName

}

# Uncomment this if you are testing this script without deploy-az-dev-bootstrapper.ps1
Import-Module -Name ./modules/text-utils.psm1

$appKubernetesNamespace = "edge-app1"
$deploymentId = Get-Random

Write-Title("Start Deploying Application L4")
$startTime = Get-Date

# Get AKS SP object ID
$aksServicePrincipal = az ad sp list --display-name $AksServicePrincipalName | ConvertFrom-Json | Select-Object -First 1
$aksSpObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).id

# ----- Deploy Bicep
Write-Title("Deploy Bicep File")
$r = (az deployment sub create --location $Location `
           --template-file ./bicep/iiot-app.bicep --parameters applicationName=$ApplicationName aksObjectId=$aksSpObjectId acrCreate=true location=$Location `
           --name "dep-$deploymentId" -o json) | ConvertFrom-Json
 
$acrName = $r.properties.outputs.acrName.value
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

# ----- Deploy Bicep File for Logic App
Write-Title("Deploy Bicep File for Logic App")
DeployAppServiceEnvironment -AksClusterResourceGroupName $AksClusterResourceGroupName -AksClusterName $AksClusterName -AcrName $acrName -StorageName $storageName -StorageKey $storageKey -Location $Location -DeploymentId $deploymentId

# ----- Build and Push Containers
Write-Title("Build and Push Container Data Gateway and Workflow Module")
$deploymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image datagatewaymodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.DataGatewayModule/Dockerfile .
az acr build --image workflowmodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.WorkflowModule/Dockerfile .
Set-Location -Path $deploymentDir

# ----- Get Cluster Credentials for L4 layer
Write-Title("Get AKS Credentials L4 Layer")
az aks get-credentials `
    --admin `
    --name $AksClusterName `
    --resource-group $AksClusterResourceGroupName `
    --overwrite-existing

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
helm install iot-edge-l4 ./helm/iot-edge-l4 `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey" `
    --namespace $appKubernetesNamespace `
    --create-namespace `
    --wait

$appConfig = [PSCustomObject]@{
    AcrName = $acrName
    AppResourceGroupName = $resourceGroupApp
  }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time app deployment: " + $runningTime.ToString())

return $appConfig