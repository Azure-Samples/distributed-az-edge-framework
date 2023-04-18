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
# Import-Module -Name ./modules/text-utils.psm1

class Aks {
    [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$proxyConfig, [bool]$enableArc){
    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName in $resourceGroupName Credentials")
    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing
    
    #----- Install AKS Proxy #TODO change this once chart is released
    # helm repo add envoy https://azure-samples.github.io/distributed-az-edge-framework
    # helm repo update

    if ($proxyConfig) {
      $parentProxyIp = $proxyConfig.ProxyIp
      $parentProxyPort = $proxyConfig.ProxyPort

      Write-Title("Install Reverse Proxy with Parent Ip $parentProxyIp, Port $parentProxyPort")
      # TODO change to public repo once chart is released, instead of using local developer folder
      helm install envoy ./helm/envoy `
      --set parent.enabled=true `
      --set-string parent.proxyIp="$parentProxyIp" `
      --set-string parent.proxyHttpsPort="$parentProxyPort" `
      --namespace reverse-proxy `
      --create-namespace `
      --wait
    }
    else {
      Write-Title("Install envoy Reverse Proxy without Parent")
      # TODO change to public repo once chart is released, instead of using local developer folder
      helm install envoy ./helm/envoy `
        --namespace reverse-proxy `
        --create-namespace `
        --wait
    }

    # ----- Get AKS Proxy IP Address
    Write-Title("Get AKS $aksName Proxy Ip Address and Port")
    $proxy = kubectl get service envoy-service -n reverse-proxy -o json | ConvertFrom-Json
    $proxyIp = $proxy.status.loadBalancer.ingress.ip
    $proxyPort = $proxy.spec.ports.port
    $proxyClusterIp = $proxy.spec.clusterIP
    
    # Setup customized DNS configuration with CoreDNS for overriding a set of domain names to local proxy
    Write-Title("Setup customized DNS configuration with CoreDNS for overriding domain names to local proxy")
    $dnsConfig = @"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: coredns-custom
      namespace: kube-system
    data:
      azurearc.override: | 
        hosts {
          parent_ip_to_replace management.azure.com
          parent_ip_to_replace login.windows.net
          parent_ip_to_replace www.google.com
          parent_ip_to_replace mcr.microsoft.com
          parent_ip_to_replace northeurope.data.mcr.microsoft.com
          parent_ip_to_replace guestnotificationservice.azure.com
          fallthrough
        }
"@

    $dnsConfig = $dnsConfig.Replace("parent_ip_to_replace", $proxyClusterIp)
    $dnsConfig | kubectl apply -f -
    # restart coredns- pods to take effect
    kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

    if($enableArc)
    {
      # ----- Enroll AKS with Arc
      Write-Title("Enroll AKS $aksName with Arc using proxy Ip $proxyIp and Port $proxyPort")
      az connectedk8s connect --name $aksName --resource-group $resourceGroupName
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
$deploymentId = Get-Random

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
           location=$Location `
           --name "core-$deploymentId" `
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