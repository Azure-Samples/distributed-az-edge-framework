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

Write-Title("Install Module powershell-yaml if not yet available")
if ($null -eq (Get-Module -ListAvailable -Name powershell-yaml)) 
{
    Write-Host "Installing powershell-yaml module"
    Install-Module -Name powershell-yaml -Scope CurrentUser
}

class Aks {
    [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$proxyConfig, [bool]$enableArc, [string]$arcLocation){
    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName in $resourceGroupName Credentials")
    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

    # ----- Prepare domain names you want to add for allow-list and override to local proxy
    $customDomainsHash = @{ www_google_com = "www.google.com"; www_envoy_proxy = "www.envoyproxy.io"} # to set to @{} if empty
    # ---- Download service bus domains from URI
    $serviceBusDomains = Invoke-WebRequest -Uri "https://guestnotificationservice.azure.com/urls/allowlist?api-version=2020-01-01&location=northeurope" -Method Get
    $serviceBusDomains = $serviceBusDomains.Content | ConvertFrom-Json
    foreach ($domain in $serviceBusDomains) {
        $customDomainsHash.Add("key_$($customDomainsHash.Count)", $domain)
    }
    $customDomainsHelm = $customDomainsHash.GetEnumerator() | ForEach-Object { "customDomains.$($_.Key)=$($_.Value)" }
    $customDomainsHelm = $customDomainsHelm -Join ","
    
    # ----- Install AKS Proxy #TODO change this once chart is released
    # helm repo add envoy https://azure-samples.github.io/distributed-az-edge-framework
    # helm repo update

    if ($proxyConfig) {
      $parentProxyIp = $proxyConfig.ProxyIp
      $parentProxyPort = $proxyConfig.ProxyPort

      Write-Title("Install Reverse Proxy with Parent Ip $parentProxyIp, Port $parentProxyPort")
      helm install envoy ./helm/envoy `
      --set parent.enabled=true `
      --set-string domainRegion="$arcLocation" `
      --set-string parent.proxyIp="$parentProxyIp" `
      --set-string parent.proxyHttpsPort="$parentProxyPort" `
      --set $customDomainsHelm `
      --namespace reverse-proxy `
      --create-namespace `
      --wait
    }
    else {
      Write-Title("Install envoy Reverse Proxy without Parent")
      helm install envoy ./helm/envoy `
        --set-string domainRegion="$arcLocation" `
        --set $customDomainsHelm `
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
    
    # --- Get the default values from Helm chart - note if you are overriding Values, load $helmValues differently
    $helmValues = (helm show values ./helm/envoy) | ConvertFrom-Yaml

    $domainsList = foreach ($key in $helmValues.domainNames.keys) {
        "$proxyClusterIp $($helmValues.domainNames[$key]) `n       "
    }
    $regionalList = foreach ($key in $helmValues.regionalDomains.keys) {
        "$proxyClusterIp ${arcLocation}$($helmValues.regionalDomains[$key]) `n       "
    }
    # Get additional custom domains if any defined above
    $customDomainList = foreach ($key in $customDomainsHash.keys) {
        "$proxyClusterIp $($customDomainsHash[$key]) `n       "
    }

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
          list_of_default_domains_to_replace
          list_of_regional_domains_to_replace
          list_of_additional_domains_to_replace
          fallthrough
        }
"@

    $dnsConfig = $dnsConfig.Replace("list_of_default_domains_to_replace", $domainsList)
    $dnsConfig = $dnsConfig.Replace("list_of_regional_domains_to_replace", $regionalList)
    $dnsConfig = $dnsConfig.Replace("list_of_additional_domains_to_replace", $customDomainList)
    
    $dnsConfig | kubectl apply -f -
    # restart kube-dns pods to take effect
    kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

    if($enableArc)
    {
      # ----- Enroll AKS with Arc
      # TODO at this stage should remove NSG permissions for outgoing traffice for L2/L3
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
$proxyConfig = $aks.Prepare($aksClusterResourceGroupName, $aksClusterName, $ParentConfig, $SetupArc, $Location)

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