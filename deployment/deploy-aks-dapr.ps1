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

$acrName = $r.properties.outputs.acrName.value
$aksName = $r.properties.outputs.aksName.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value
$storageKey = $r.properties.outputs.storageKey.Value
$storageName = $r.properties.outputs.storageName.Value
$eventHubConnectionString = $r.properties.outputs.eventHubConnectionString.value

# ----- Build and Push Containers
Write-Title("Build and Push Containers")
$deplymentDir = Get-Location
Set-Location -Path ../iotedge/Distributed.IoT.Edge
az acr build --image datagatewaymodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.DataGatewayModule/Dockerfile .
az acr build --image simulatedtemperaturesensormodule:$deploymentId --registry $acrName --file Distributed.IoT.Edge.SimulatedTemperatureSensorModule/Dockerfile .
Set-Location -Path $deplymentDir

# ----- Get Cluster Credentials
Write-Title("Get AKS Credentials")
az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

#----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace dapr-system `
    --create-namespace `
    --wait

#----- Redis
Write-Title("Install Redis")
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --wait

# ----- Run Helm
Write-Title("Install Pod/Containers with Helm in Cluster")
$datagatewaymoduleimage = $acrName + ".azurecr.io/datagatewaymodule:" + $deploymentId
$simtempimage = $acrName + ".azurecr.io/simulatedtemperaturesensormodule:" + $deploymentId
helm install iot-edge-accelerator ./helm/iot-edge-accelerator `
    --set-string images.datagatewaymodule="$datagatewaymoduleimage" `
    --set-string images.simulatedtemperaturesensormodule="$simtempimage" `
    --set-string dataGatewayModule.eventHubConnectionString="$eventHubConnectionString" `
    --set-string dataGatewayModule.storageAccountName="$storageName" `
    --set-string dataGatewayModule.storageAccountKey="$storageKey"

# ----- Clean up
if($DeleteResourceGroup)
{
    Write-Title("Delete Resources")
    if(Remove-AzResourceGroup -Name $resourceGroupName -Force)
    {
        Write-Host "All resources deleted" -ForegroundColor Yellow
    }
}

$env:RESOURCEGROUPNAME=$resourceGroupName

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow