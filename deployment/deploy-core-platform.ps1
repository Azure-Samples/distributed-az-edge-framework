# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [Parameter(mandatory=$true)]
    [String]
    $AksClusterName,

    [Parameter(mandatory=$true)]
    [string]
    $AksClusterResourceGroupName,

    [Parameter(mandatory=$false)]
    [bool]
    $DeployDapr = $true,

    [Parameter(mandatory=$false)]
    [string]
    $MosquittoParentIp = $null
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

Write-Title("Start Deploying Core Platform")
$startTime = Get-Date

# ----- Get AKS Cluster Credentials
az aks get-credentials --admin --name $AksClusterName --resource-group $AksClusterResourceGroupName --overwrite-existing

# ----- Dapr
if($DeployDapr){
    Write-Title("Install Dapr")
    helm repo add dapr https://dapr.github.io/helm-charts/
    helm repo update
    helm upgrade --install dapr dapr/dapr `
        --version=1.10 `
        --namespace edge-core `
        --create-namespace `
        --wait
}

if ($MosquittoParentIp -eq ""){
    Write-Title("Install Mosquitto without bridge to parent")
    #  use default mosquitto deployment
    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --create-namespace `
    --wait
}
else {
    Write-Title("Install Mosquitto with bridge to parent IP $MosquittoParentIp")
    # If setting bridge from child to parent: create mosquitto.conf file with bridge config:
    $mosquittoConf = (Get-Content -Path ./configuration/mosquitto.conf.template -Raw)
    $mosquittoConf = $mosquittoConf.Replace('replace_with_connection_name', "$AksClusterName-parent").Replace('replace_with_parent_address', $MosquittoParentIp)
    Set-Content -Path "./temp/$AksClusterName-mosquitto.conf" -Value $mosquittoConf

    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --set-file mosquittoConfig="./temp/$AksClusterName-mosquitto.conf" `
    --create-namespace `
    --wait
}

# Get Mosquitto IP and Ports from deployment
$mosquittoSvc = kubectl get service mosquitto -n edge-core -o json | ConvertFrom-Json
$mosquittoIp = $mosquittoSvc.status.loadBalancer.ingress.ip
$mosquittoPort = $mosquittoSvc.spec.ports.port

$mosquittoConfig = [PSCustomObject]@{
    MosquittoIp = $mosquittoIp
    Port = $mosquittoPort
  }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core platform: $runningTime")

return $mosquittoConfig
