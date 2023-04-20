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
  $Location = 'westeurope',

  [Parameter(mandatory = $true)]
  [string]
  $VnetAddressPrefix,

  [Parameter(mandatory = $true)]
  [string]
  $SubnetAddressPrefix,

  [Parameter(Mandatory = $false)]
  [bool]
  $SetupArc = $true
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name ./modules/text-utils.psm1

Write-Title("Install Module powershell-yaml if not yet available")
if ($null -eq (Get-Module -ListAvailable -Name powershell-yaml)) {
  Write-Host "Installing powershell-yaml module"
  Install-Module -Name powershell-yaml -Scope CurrentUser
}

class Aks {
  [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$proxyConfig, [bool]$enableArc, [string]$arcLocation) {
    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName in $resourceGroupName Credentials")
    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing

    # ----- Prepare domain names you want to add for allow-list, DNS override to local proxy
    # Github.com and github.io required for flux and helm repos in GitOps
    # TODO make mosquitto image availalbe in allowed registry URI
    # TODO investigate using private registry for mosquitto, custom and other images to avoid proxying github uris
    $customDomainsHash = @{ 
      azure_samples_github = "azure-samples.github.io"; 
      github_com = "github.com";
      ghcr_io = "ghcr.io";
      dapr_github_io = "dapr.github.io" } 
      # set $customDomainsHash = @{} for an empty list
    # ---- Download service bus domains from URI for chosen Azure region
    $serviceBusDomains = Invoke-WebRequest -Uri "https://guestnotificationservice.azure.com/urls/allowlist?api-version=2020-01-01&location=$arcLocation" -Method Get
    $serviceBusDomains = $serviceBusDomains.Content | ConvertFrom-Json
    foreach ($domain in $serviceBusDomains) {
      $customDomainsHash.Add("sb_$($customDomainsHash.Count)", $domain)
    }
    $customDomainsHelm = $customDomainsHash.GetEnumerator() | ForEach-Object { "customDomains.$($_.Key)=$($_.Value)" }
    $customDomainsHelm = $customDomainsHelm -Join ","
    
    # ----- Install AKS Proxy 
    #TODO change this once chart is released
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
    
    $arcDomainsList = ""
    $arcregionalList = ""

    # Currently setting up all Arc domains for proxying, even if Arc agent is not installed on this cluster
    # if ($enableArc) {
    
    # --- Get the default values from Helm chart - note if you are overriding Values, load $helmValues differently
    # TODO get from chart repo instead of local folder when chart is released
    $helmValues = (helm show values ./helm/envoy) | ConvertFrom-Yaml
    $arcDomainsList = foreach ($key in $helmValues.arcDomainNames.keys) {
      "$proxyClusterIp $($helmValues.arcDomainNames[$key]) `n       "
    }
    $arcregionalList = foreach ($key in $helmValues.arcRegionalDomains.keys) {
      "$proxyClusterIp ${arcLocation}$($helmValues.arcRegionalDomains[$key]) `n       "
    }
    # }

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

    $dnsConfig = $dnsConfig.Replace("list_of_default_domains_to_replace", $arcDomainsList)
    $dnsConfig = $dnsConfig.Replace("list_of_regional_domains_to_replace", $arcregionalList)
    $dnsConfig = $dnsConfig.Replace("list_of_additional_domains_to_replace", $customDomainList)
    
    $dnsConfig | kubectl apply -f -
    # restart coredns pods to take effect
    kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

    if ($enableArc) {
      # If parent proxy config is present = this is a lower layer and we are blocking all outbound traffic
      if ($proxyConfig) {
        # ----- Close down Internet access for cluster after Infra setup, allow only AKS Azure specific outbound
        # Because using AKS managed service, some traffic cannot be blocked by NSG as described in AKS egress networking requirements
        # https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic
        $aksApiUri = (az aks show -g $resourceGroupName -n $aksName --query "fqdn" -o tsv)
        $aksApiIp = [System.Net.Dns]::GetHostAddresses("$aksApiUri")[0].IPAddressToString

        # this first rule is temporary for allowing AKS to connect to Azure Arc Infra (wildcard domains), will be removed later
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "AllowArcInfraHTTPSOutbound" --priority 1000 --source-address-prefixes VirtualNetwork --destination-address-prefixes AzureArcInfrastructure --destination-port-ranges '443' --direction Outbound --access Allow --protocol Tcp --description "Allow VirtualNetwork to ArcInfra."
        # default rules for AKS outbound connectivity to work in node pools and between nodes
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "AllowK8ApiHTTPSOutbound" --priority 1010 --source-address-prefixes VirtualNetwork --destination-address-prefixes $aksApiIp --destination-port-ranges '443' --direction Outbound --access Allow --protocol Tcp --description "Allow VirtualNetwork to AKS API."
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "AllowTagAks9000Outbound" --priority 1020 --source-address-prefixes VirtualNetwork --destination-address-prefixes AzureCloud.northeurope --destination-port-ranges '9000' --direction Outbound --access Allow --protocol Tcp --description "Allow VirtualNetwork to 9000 for node comms."
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "AllowTagMcr" --priority 1040 --source-address-prefixes VirtualNetwork --destination-address-prefixes MicrosoftContainerRegistry --destination-port-ranges '443' --direction Outbound --access Allow --protocol Tcp --description "Allow VirtualNetwork to MCR."
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "AllowTagFrontDoorFirstParty" --priority 1050 --source-address-prefixes VirtualNetwork --destination-address-prefixes AzureFrontDoor.FirstParty --destination-port-ranges '443' --direction Outbound --access Allow --protocol Tcp --description "Allow VirtualNetwork to AzFrontDoor.FirstParty."
        # # Deny all Internet outbound traffic
        az network nsg rule create -g $resourceGroupName --nsg-name "$aksName" -n "DenyAllInternetOutbound" --priority 2000 --source-address-prefixes VirtualNetwork --destination-address-prefixes Internet --destination-port-ranges '*' --direction Outbound --access Deny --protocol * --description "Deny all oubound internet."
      }

      # ----- Enroll AKS with Arc
      Write-Title("Enroll AKS $aksName with Arc")
      az connectedk8s connect --name $aksName --resource-group $resourceGroupName
      az connectedk8s enable-features -n $aksName -g $resourceGroupName --features cluster-connect
    }
    else {
      Write-Title("Not enrolling AKS $aksName with Arc, no egress restrictions applied")
    }

    return [PSCustomObject]@{
      ProxyIp   = $proxyIp
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

$ParentConfigVnetName = If ($ParentConfig -eq $null) { "" } Else { $ParentConfig.VnetName }
$ParentConfigVnetResourceGroup = If ($ParentConfig -eq $null) { "" } Else { $ParentConfig.VnetResourceGroup }

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
) | ConvertFrom-Json

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
  AksClusterName              = $aksClusterName
  AksClusterResourceGroupName = $aksClusterResourceGroupName
  ProxyIp                     = $proxyConfig.ProxyIp
  ProxyPort                   = $proxyConfig.ProxyPort
  VnetName                    = $ApplicationName
  VnetResourceGroup           = $aksClusterResourceGroupName
}

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core infra: $runningTime")

return $config