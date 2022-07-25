# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
    [Parameter(ValueFromPipeline = $true)]
    [PSCustomObject]
    $ParentConfig,

    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,  

    [string]
    $Location = 'westeurope',

    [Parameter(mandatory=$true)]
    [string]
    $VnetAddressPrefix,

    [Parameter(mandatory=$true)]
    [string]
    $SubnetAddressPrefix,

    [Parameter(Mandatory = $false)]
    [bool]
    $SetupArc = $true
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

class Aks {
    [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$proxyConfig, [bool]$enableArc){
    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName in $resourceGroupName Credentials")
    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing
    
    #----- Install AKS Proxy
    helm repo add squid https://azure-samples.github.io/distributed-az-edge-framework
    helm repo update

    if($proxyConfig)
    {
      $parentProxyIp = $proxyConfig.ProxyIp
      $parentProxyPort = $proxyConfig.ProxyPort

      Write-Title("Install Proxy with Parent Ip $parentProxyIp, Port $parentProxyPort")      
      helm install squid squid/squid-proxy `
          --set-string parent.ipAddress="$parentProxyIp" `
          --set-string parent.port="$parentProxyPort" `
          --namespace edge-proxy `
          --create-namespace `
          --wait          
    }
    else
    {
      Write-Title("Install Proxy without Parent")
      helm install squid squid/squid-proxy `
          --namespace edge-proxy `
          --create-namespace `
          --wait
    }

    # ----- Get AKS Proxy IP Address
    Write-Title("Get AKS $aksName Proxy Ip Address and Port")
    $proxy = kubectl get service squid-proxy-module -n edge-proxy -o json | ConvertFrom-Json
    $proxyIp = $proxy.status.loadBalancer.ingress.ip
    $proxyPort = $proxy.spec.ports.port
    $proxyUrl = "http://" + $proxyIp + ":" + $proxyPort    

    if($enableArc)
    {
      # ----- Enroll AKS with Arc
      Write-Title("Enroll AKS $aksName with Arc using proxy Ip $proxyIp and Port $proxyPort")
      az connectedk8s connect --name $aksName --resource-group $resourceGroupName --proxy-http $proxyUrl --proxy-https $proxyUrl --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
      az connectedk8s enable-features -n $aksName -g $resourceGroupName --features cluster-connect
    }
    else
    {
      Write-Title("Not enrolling AKS $aksName with Arc")
    }

    return [PSCustomObject]@{
      ProxyIp = $proxyIp
      ProxyPort = $proxyPort     
    }
  }
}

Write-Title("Start Deploying Core Infrastructure")
$startTime = Get-Date

# ----- Retrieve Object Id of current user who is deploying solution.
$currentAzUsernameId = $(az ad signed-in-user show --query id | ConvertFrom-Json)

# ----- Create AKS Service Principals
Write-Title("Create AKS Service Principals")
$aksServicePrincipalName = $ApplicationName
$aksServicePrincipal = (az ad sp create-for-rbac -n $aksServicePrincipalName) | ConvertFrom-Json

# Sleep to allow SP to be replicated across AAD instances.
# TODO: Update this to be more deterministic.
Start-Sleep -s 30

$aksClientId = $aksServicePrincipal.appId
$aksObjectId = (az ad sp show --id $aksServicePrincipal.appId | ConvertFrom-Json).id
$aksClientSecret = $aksServicePrincipal.password

# ----- Deploy Bicep
Write-Title("Deploy Bicep files")

$ParentConfigVnetName = If ($ParentConfig -eq $null) {""} Else {$ParentConfig.VnetName}
$ParentConfigVnetResourceGroup = If ($ParentConfig -eq $null) {""} Else {$ParentConfig.VnetResourceGroup}

$r = (az deployment sub create --location $Location `
           --template-file .\bicep\core-infrastructure.bicep --parameters `
           applicationName=$ApplicationName `
           remoteVnetName=$ParentConfigVnetName `
           remoteVnetResourceGroupName=$ParentConfigVnetResourceGroup `
           vnetName=$ApplicationName `
           vnetAddressPrefix=$vnetAddressPrefix `
           subnetAddressPrefix=$subnetAddressPrefix `
           currentAzUsernameId=$currentAzUsernameId `
           aksObjectId=$aksObjectId `
           aksClientId=$aksClientId `
           aksClientSecret=$aksClientSecret `
    )| ConvertFrom-Json

$aksClusterName = $r.properties.outputs.aksName.value
$aksClusterResourceGroupName = $r.properties.outputs.aksResourceGroup.value

# ----- Install Arc CLI Extensions
Write-Title("Azure Arc CLI Extensions")
az extension add --name "connectedk8s"
az extension add --name "k8s-configuration"
az extension add --name "k8s-extension"
az extension add --name "customlocation"

# ----- Install core dependencies in AKS cluster
$aks = [Aks]::new()
$proxyConfig = $aks.Prepare($aksClusterResourceGroupName, $aksClusterName, $ParentConfig, $SetupArc)

$config = [PSCustomObject]@{
      AksClusterName = $aksClusterName
      AksClusterResourceGroupName = $aksClusterResourceGroupName
      ProxyIp = $proxyConfig.ProxyIp
      ProxyPort = $proxyConfig.ProxyPort
      VnetName = $ApplicationName
      VnetResourceGroup = $aksClusterResourceGroupName
    }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core infra: $runningTime")

return $config