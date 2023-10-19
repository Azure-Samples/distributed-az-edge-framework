# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
  [Parameter(ValueFromPipeline = $true)]
  [PSCustomObject]
  $ParentConfig,

  [string]
  [Parameter(mandatory = $true)]
  $ApplicationName,  

  [string]
  [Parameter(mandatory=$false)]
  $Location = 'westeurope',

  [Parameter(mandatory = $true)]
  [string]
  $VnetAddressPrefix,

  [Parameter(mandatory = $true)]
  [string]
  $SubnetAddressPrefix,

  [Parameter(Mandatory = $false)]
  [bool]
  $SetupArc = $true,

  [Parameter(Mandatory = $false)]
  [bool]
  $SetupObservability = $true
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
Import-Module -Name ./modules/text-utils.psm1
Import-Module -Name ./modules/process-utils.psm1

Write-Title("Install Module powershell-yaml if not yet available")
if ($null -eq (Get-Module -ListAvailable -Name powershell-yaml)) {
  Write-Title("Installing powershell-yaml module")
  Install-Module -Name powershell-yaml -Scope CurrentUser
}

class Aks {
  [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$parentProxyConfig, 
    [bool]$enableArc, [string]$arcLocation, [bool]$installObservability, [string]$otelAppInsightsKey) {
    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName in $resourceGroupName Credentials")
    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

    # ----- Prepare domain names you want to add for allow-list, DNS override to local proxy
    # Github.com and github.io required for flux and helm repos in GitOps
    $customDomainsHash = @{ 
      azure_samples_github = "azure-samples.github.io"; 
      github_com = "github.com";
      ghcr_io = "ghcr.io";
      dapr_github_io = "dapr.github.io";    }
      # if you want an empty list, set $customDomainsHash = @{}
    
    if($installObservability){
      $customDomainsHash.Add("gcr_$($customDomainsHash.Count)", "gcr.io")
      $customDomainsHash.Add("jetstack_$($customDomainsHash.Count)", "charts.jetstack.io")
      $customDomainsHash.Add("otel_$($customDomainsHash.Count)", "open-telemetry.github.io")
      $customDomainsHash.Add("k8s_$($customDomainsHash.Count)", "registry.k8s.io")
      $customDomainsHash.Add("k8s_$($customDomainsHash.Count)", "cr.fluentbit.io")
    }
      
    # ---- Download service bus domains from URI for chosen Azure region
    $serviceBusDomains = Invoke-WebRequest -Uri "https://guestnotificationservice.azure.com/urls/allowlist?api-version=2020-01-01&location=$arcLocation" -Method Get
    $serviceBusDomains = $serviceBusDomains.Content | ConvertFrom-Json
    $serviceBusDomainsUnique = $serviceBusDomains | Select-Object -Unique # Sometimes the result has duplicates
    foreach ($domain in $serviceBusDomainsUnique) {
      $customDomainsHash.Add("sb_$($customDomainsHash.Count)", $domain)
    }
    $customDomainsHelm = $customDomainsHash.GetEnumerator() | ForEach-Object { "customDomains.$($_.Key)=$($_.Value)" }
    $customDomainsHelm = $customDomainsHelm -Join ","

    $observabilityString = ($installObservability -eq $true) ? "true" : "false"
    
    # ----- Install AKS reverse Proxy 
    helm repo add azdistributededge https://azure-samples.github.io/distributed-az-edge-framework --force-update
    helm repo update

    if ($null -ne $parentProxyConfig) {
      $parentProxyIp = $parentProxyConfig.ProxyIp
      $parentProxyPort = $parentProxyConfig.ProxyPort

      Write-Title("Install Envoy Reverse Proxy with Parent Ip $parentProxyIp, Port $parentProxyPort")
      helm install envoy azdistributededge/envoy-reverseproxy `
        --set parent.enabled=true `
        --set-string domainRegion="$arcLocation" `
        --set-string parent.proxyIp="$parentProxyIp" `
        --set-string parent.proxyHttpsPort="$parentProxyPort" `
        --set observability.enablePrometheusScrape=$observabilityString `
        --set-string arguments.logLevel="info" `
        --set $customDomainsHelm `
        --namespace edge-infra `
        --create-namespace `
        --wait
    }
    else {
      Write-Title("Install Envoy Reverse Proxy without Parent")
      helm install envoy azdistributededge/envoy-reverseproxy `
        --set-string domainRegion="$arcLocation" `
        --set observability.enablePrometheusScrape=$observabilityString `
        --set-string arguments.logLevel="info" `
        --set $customDomainsHelm `
        --namespace edge-infra `
        --create-namespace `
        --wait
    }

    # ----- Get AKS Proxy IP Address
    Write-Title("Get AKS $aksName Proxy Ip Address and Port")
    $proxy = kubectl get service envoy-service -n edge-infra -o json | ConvertFrom-Json
    $proxyIp = $proxy.status.loadBalancer.ingress.ip
    $proxyPort = ($proxy.spec.ports | Where-Object { $_.name -eq "https" } | Select-Object -First 1).port
    $proxyClusterIp = $proxy.spec.clusterIP
    
    # ----- Configure DNS resolution within AKS cluster via CoreDNS customization
    Write-Title("CoreDNS customization to local Envoy proxy")
    try{
      ConfigureCoreDns -customDomains $customDomainsHash -envoyProxyClusterIp $proxyClusterIp
    }catch
    {
      Write-Error $_.Exception.Message
      break
    }

    # ----- Install DNSMasq Helm chart to host DNS resolution for child cluster
    Write-Title("Installing DNSMasqAks Helm chart for DNS resolution of child cluster")
    if($installObservability){
      # Additional domains for observability
      $dnsCustomDomainsHash = @{}
      $dnsCustomDomainsHash.Add("gcr_$($dnsCustomDomainsHash.Count)", "gcr.io")
      $dnsCustomDomainsHash.Add("jetstack_$($dnsCustomDomainsHash.Count)", "charts.jetstack.io")
      $dnsCustomDomainsHash.Add("otel_$($dnsCustomDomainsHash.Count)", "open-telemetry.github.io")
      $dnsCustomDomainsHash.Add("k8s_$($dnsCustomDomainsHash.Count)", "registry.k8s.io")
      $dnsCustomDomainsHash.Add("k8s_$($dnsCustomDomainsHash.Count)", "cr.fluentbit.io")
      $dnsCustomDomainsHelm = $dnsCustomDomainsHash.GetEnumerator() | ForEach-Object { "customDomains.$($_.Key)=$($_.Value)" }
      $dnsCustomDomainsHelm = $dnsCustomDomainsHelm -Join ","

      helm install dnsmasq azdistributededge/dnsmasqaks `
        --set-string proxyDnsServer="$proxyIp" `
        --set $dnsCustomDomainsHelm `
        --namespace edge-infra `
        --wait
    }
    else {
      helm install dnsmasq azdistributededge/dnsmasqaks `
        --set-string proxyDnsServer="$proxyIp" `
        --namespace edge-infra `
        --wait
    }

    $dnsService = kubectl get service dsnmasq-service -n edge-infra -o json | ConvertFrom-Json
    $dnsMasqIp = $dnsService.status.loadBalancer.ingress.ip

    # ----- Bootstrap monitoring and observability
    if($installObservability) {

      $metadataNetworkLayer = $aksName.Substring($aksName.Length - 2, 2)
      Write-Title("Observability - install pre-req cert-manager for AKS $aksName")
      helm repo add --force-update jetstack https://charts.jetstack.io
      helm repo update

      helm upgrade cert-manager jetstack/cert-manager `
        --install `
        --namespace cert-manager --create-namespace `
        --set installCRDs=true `
        --wait
      
      helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 
      helm repo update

      helm upgrade opentelemetry-operator open-telemetry/opentelemetry-operator `
        --install `
        --version "0.36.0" `
        --namespace monitoring --create-namespace `
        --wait

      if($null -ne $parentProxyConfig) {
        Write-Title("Install Helm chart with OpenTelemetry and FluentBit for AKS $aksName with parent collector")

        $parentProxyIp = $parentProxyConfig.ProxyIp
        $parentEndpoint = "http://${parentProxyIp}:4318"
        helm upgrade otelcollection azdistributededge/otelcollection `
        --install `
        --namespace monitoring `
        --set exporters.parentOtlp.enabled=true `
        --set-string exporters.parentOtlp.endpoint="$parentEndpoint" `
        --set-string metadata.region="$arcLocation" `
        --set-string metadata.clusterName="$aksName" `
        --set-string metadata.networkLayer="$metadataNetworkLayer" `
        --wait 
      }
      else {
        Write-Title("Install Observability Helm chart with Grafana as visualization for AKS $aksName in top layer")
        helm upgrade edgeobservability azdistributededge/edgeobservability `
          --install `
          --create-namespace --namespace observability --wait

        Write-Title("Install Helm chart with OpenTelemetry and FluentBit for AKS $aksName to Az Monitor")
        helm upgrade otelcollection azdistributededge/otelcollection `
        --install `
        --namespace monitoring `
        --set exporters.azuremonitor.enabled=true `
        --set-string exporters.azuremonitor.instrumentationKey="$otelAppInsightsKey" `
        --set-string metadata.region="$arcLocation" `
        --set-string metadata.clusterName="$aksName" `
        --set-string metadata.networkLayer="$metadataNetworkLayer" `
        --set exporters.prometheus.enabled=true `
        --set exporters.loki.enabled=true `
        --set exporters.jaeger.enabled=true `
        --wait 
      }

      # Update the Envoy proxy configuration to include Otel Collector listener and cluster now it's available
      Write-Title("Update Envoy proxy configuration to include OpenTelemetry Collector listener and cluster")

      $otelService = kubectl get service otel-collector -n monitoring -o json | ConvertFrom-Json
      $otelCollectorIp = $otelService.spec.clusterIP
      
      # temporary hack - set new value for logLevel argument to trigger a restart of the Envoy pod to load cofigmap changes
      helm upgrade envoy azdistributededge/envoy-reverseproxy `
        --reuse-values `
        --set observability.enableOtelCollector=true `
        --set-string observability.otelCollectorIp="$otelCollectorIp" `
        --set-string observability.otelCollectorPort="4318" `
        --set-string arguments.logLevel="warn" `
        --namespace edge-infra `
        --wait
    }
    
    if ($enableArc) {
      # ----- Before enrolling with Arc: create Service Account, get token and store in temp folder for Arc Cluster Connect in other scripts
      Write-Title("Before enrolling AKS $aksName with Arc: create ServiceAccount and store token on disk")
      kubectl create serviceaccount arc-user
      kubectl create clusterrolebinding arc-user-binding --clusterrole cluster-admin --serviceaccount default:arc-user

      # create secret with service account token
      $serviceAccountToken=@"
      apiVersion: v1
      kind: Secret
      metadata:
        name: arc-user-secret
        annotations:
          kubernetes.io/service-account.name: arc-user
      type: kubernetes.io/service-account-token
"@
      
      $serviceAccountToken | kubectl apply -f -

      $tokenB64 = (kubectl get secret arc-user-secret -o jsonpath='{$.data.token}')
      # Store secret in base64 in ./temp/tokens folder - #TODO this should go into Key Vault instead
      $tempFolder = "./temp/tokens"
      If(!(Test-Path -PathType container -Path $tempFolder))
      {
          New-Item -ItemType Directory -Path $tempFolder
      }
      Write-Title("Writing Service Account token for $aksName to ./temp/tokens folder, required for Arc cluster connect")
      Set-Content -Path "$tempFolder/$aksName.txt" -Value "$tokenB64"

      # ----- Enroll AKS with Arc
      Write-Title("Enroll AKS $aksName with Arc. This will take a few minutes...")
      az connectedk8s connect --name $aksName --resource-group $resourceGroupName
      az connectedk8s enable-features -n $aksName -g $resourceGroupName --features cluster-connect

    }
    else {
      Write-Title("Not enrolling AKS $aksName with Arc, no egress NSG restrictions applied")
    }

    return [PSCustomObject]@{
      ProxyIp   = $proxyIp
      ProxyPort = $proxyPort   
      DnsMasqIp = $dnsMasqIp  
    }
  }
}

# ------ Begin function ConfigureCoreDns
Function ConfigureCoreDns([object]$customDomains, [string] $envoyProxyClusterIp)
{
  # ----- Prepare DNS override for local proxy
  $dnsWildcardTemplateBlock = @"

    to_replace_key.override: |
      rewrite stop {
        name regex to_replace_with_expression envoy-service.edge-infra.svc.cluster.local.
      }
"@

  $arcDomainsList = ""
  $arcregionalList = ""
  $wildcardDomainOverride = ""

  # --- Get the default values from Helm chart - note if you are overriding Values, load $helmValues differently
  $helmValues = (helm show values azdistributededge/envoy-reverseproxy) | ConvertFrom-Yaml

  $arcDomainsList = foreach ($key in $helmValues.arcDomainNames.keys) {
    "$envoyProxyClusterIp $($helmValues.arcDomainNames[$key]) `n       "
  }
  $arcregionalList = foreach ($key in $helmValues.arcRegionalDomains.keys) {
    "$envoyProxyClusterIp ${arcLocation}$($helmValues.arcRegionalDomains[$key]) `n       "
  }
  foreach ($key in $helmValues.arcWildcardSubDomains.keys) {
    $wildcardDomain = $($helmValues.arcWildcardSubDomains[$key]).Replace("*", "").Replace(".", "\.")
    $expression = "(.*)$wildcardDomain\.$"
    $wildcardDomainBlock = $dnsWildcardTemplateBlock.Replace("to_replace_key", $key).Replace("to_replace_with_expression", $expression)
    $wildcardDomainOverride += $wildcardDomainBlock
  }
  
  # Get additional custom domains if any passed in collection $customDomains
  $customDomainList = foreach ($key in $customDomains.keys) {
    "$envoyProxyClusterIp $($customDomains[$key]) `n       "
  }

  # Setup customized DNS configuration with CoreDNS for overriding a set of domain names to local proxy
  Write-Title("Setup customized DNS configuration with CoreDNS for overriding domain names to local proxy")
  $dnsConfig = @"
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: coredns-custom
    namespace: kube-system
    labels:
        addonmanager.kubernetes.io/mode: EnsureExists
  data:
    azurearc.override: | 
      hosts {
        list_of_default_domains_to_replace
        list_of_regional_domains_to_replace
        list_of_additional_domains_to_replace
        
        fallthrough
      }
    list_of_wildcard_overrides_to_replace
"@

  $dnsConfig = $dnsConfig.Replace("list_of_default_domains_to_replace", $arcDomainsList)
  $dnsConfig = $dnsConfig.Replace("list_of_regional_domains_to_replace", $arcregionalList)
  $dnsConfig = $dnsConfig.Replace("list_of_additional_domains_to_replace", $customDomainList)
  $dnsConfig = $dnsConfig.Replace("list_of_wildcard_overrides_to_replace", $wildcardDomainOverride)

  $dnsConfig | kubectl apply -f -
  # restart coredns pods to take effect
  kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

}
# ------ End function ConfigureCoreDns

# ------
# Temporary check for Linux based systems and enabling Arc - exit as not tested on Linux outside of Cloud Shell
if($SetupArc){
  if( -not (Confirm-AzEnvironment))
  {
      Write-Title("Exiting - please use the developer setup or run this in Azure Cloud Shell PowerShell")
      Exit
  }
}
# ------

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
Write-Title("Deploy Bicep files - Vnet")
$ParentConfigVnetName = If ($ParentConfig -eq $null) { "" } Else { $ParentConfig.VnetName }
$ParentConfigVnetResourceGroup = If ($ParentConfig -eq $null) { "" } Else { $ParentConfig.VnetResourceGroup }
$closeOutboundInternetAccess = If ($SetupArc -eq $true -and $ParentConfig -ne $null) { $true } Else { $false }
$provisionAzureMonitoring = If ($SetupObservability -eq $true -and $ParentConfig -eq $null) { $true } Else { $false }

$r = (az deployment sub create --location $Location `
    --template-file ./bicep/core-infra-base.bicep --parameters `
    applicationName=$ApplicationName `
    remoteVnetName=$ParentConfigVnetName `
    remoteVnetResourceGroupName=$ParentConfigVnetResourceGroup `
    vnetName=$ApplicationName `
    vnetAddressPrefix=$vnetAddressPrefix `
    subnetAddressPrefix=$subnetAddressPrefix `
    currentAzUsernameId=$currentAzUsernameId `
    aksObjectId=$aksObjectId `
    closeOutboundInternetAccess=$closeOutboundInternetAccess `
    provisionMonitoring=$provisionAzureMonitoring `
    location=$Location `
    --name "core-$deploymentId" `
) | ConvertFrom-Json

$vnetSubnetId = $r.properties.outputs.subnetId.value
$aksClusterResourceGroupName = $r.properties.outputs.aksResourceGroup.value
$aksClusterName = $r.properties.outputs.aksName.value
$appInsightsInstrumentationKey = $provisionAzureMonitoring -eq $true ? $r.properties.outputs.appInsightsInstrumentationKey.value : ""

if ($closeOutboundInternetAccess -eq $true)
{
  # ----- Set DNS server in VNET to parent peered VNET DNS server DNSMasq
  $parentDnsServer = $ParentConfig.DnsServer
  Write-Title("Setting VNET DNS server to peered parent DNS on IP ${parentDnsServer}")
  az network vnet update -g $aksClusterResourceGroupName -n $aksClusterResourceGroupName --dns-servers $parentDnsServer
}

Write-Title("Deploy Bicep - AKS cluster")
$aks = (az deployment group create `
    --resource-group $aksClusterResourceGroupName `
    --template-file ./bicep/core-infra-aks.bicep --parameters `
    aksName=$aksClusterName `
    aksLocation=$Location `
    aksClientId=$aksClientId `
    aksClientSecret=$aksClientSecret `
    vnetSubnetID=$vnetSubnetId `
    --name "aks-$deploymentId" `
) | ConvertFrom-Json

# ----- Install Arc CLI Extensions
if($SetupArc)
{
  Write-Title("Installing Azure Arc CLI Extensions")
  az extension add --name "connectedk8s"
  az extension add --name "k8s-configuration"
  az extension add --name "k8s-extension"
  az extension add --name "customlocation"
}

# ----- Install core dependencies in AKS cluster
$aks = [Aks]::new()
$proxyConfig = $aks.Prepare($aksClusterResourceGroupName, 
  $aksClusterName, 
  $ParentConfig, 
  $SetupArc, 
  $Location, 
  $SetupObservability,
  $appInsightsInstrumentationKey)

$config = [PSCustomObject]@{
  AksClusterName              = $aksClusterName
  AksClusterResourceGroupName = $aksClusterResourceGroupName
  ProxyIp                     = $proxyConfig.ProxyIp
  ProxyPort                   = $proxyConfig.ProxyPort
  VnetName                    = $ApplicationName
  VnetResourceGroup           = $aksClusterResourceGroupName
  DnsServer                   = $proxyConfig.DnsMasqIp
}

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core infra: $runningTime")

return $config