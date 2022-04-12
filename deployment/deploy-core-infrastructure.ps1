# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,
    
    [string]
    $Location = 'westeurope'
)

Function Write-Title ([string]$text) {
    $width = (Get-Host).UI.RawUI.WindowSize.Width
    $title = ""
    if($text.length -ne 0)
    {
        $title = "=[ " + $text + " ]="
    }

    Write-Host $title.PadRight($width, "=") -ForegroundColor green
}

class AKS {
    [PSCustomObject] Prepare ([string]$resourceGroupName, [string]$aksName, [PSCustomObject]$proxyConfig){    
    # ----- Get AKS Cluster Credentials
    Write-Title("Get AKS $aksName Credentials")

    az aks get-credentials --admin --name $aksName --resource-group $resourceGroupName --overwrite-existing
    
    #----- Install AKS Proxy
    # TODO: Change this to use proxy package from GH.
    if($proxyConfig)
    {
      $parentProxyIp = $proxyConfig.ProxyIp
      $parentProxyPort = $proxyConfig.ProxyPort

      Write-Title("Install Proxy with Parent Ip $parentProxyIp, Port $parentProxyPort")

      helm install squid-proxy ./helm/squid-proxy `
          --set-string parent.ipAddress="$parentProxyIp" `
          --set-string parent.port="$parentProxyPort" `
          --namespace edge-proxy `
          --create-namespace `
          --wait 
    }
    else
    {
      Write-Title("Install Proxy")
      helm install squid-proxy ./helm/squid-proxy `
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

    # ----- Enroll AKS with Arc
    Write-Title("Enroll AKS $aksName with Arc using proxy Ip $proxyIp and Port $proxyPort")
    az connectedk8s connect --name $aksName --resource-group $resourceGroupName --proxy-http $proxyUrl --proxy-https $proxyUrl --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
    az connectedk8s enable-features -n $aksName -g $resourceGroupName --features cluster-connect

    # $env:RESOURCEGROUPNAME = $resourceGroupName
    # $env:AKSCLUSTERPRINCIPALID = $aksClusterPrincipalID
    # $env:AKSCLUSTERNAME = $aksClusterName    
    
    return [PSCustomObject]@{
      ProxyIp = $proxyIp
      ProxyPort = $proxyPort
    }
  }
}

$deploymentId = Get-Random

Write-Title("Start Deploying Core Infrastructure")
$startTime = Get-Date

# ----- Retrieve Object Id of current user who is deploying solution.
$currentAzUsernameId = $(az ad signed-in-user show --query objectId | ConvertFrom-Json)

# ----- Create AKS Service Principals
Write-Title("Create AKS Service Principals")
$aks1ServicePrincipalName = $ApplicationName
# $aks2ServicePrincipalName = $ApplicationName + "-aks2-sp"

$aks1ServicePrincipal = (az ad sp create-for-rbac -n $aks1ServicePrincipalName) | ConvertFrom-Json
# $aks2ServicePrincipal = (az ad sp create-for-rbac -n $aks2ServicePrincipalName) | ConvertFrom-Json

$aks1ClientId = $aks1ServicePrincipal.appId
$aks2ClientId = $aks1ServicePrincipal.appId
$aks1ObjectId = (az ad sp show --id $aks1ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks2ObjectId = (az ad sp show --id $aks1ServicePrincipal.appId | ConvertFrom-Json).objectId
$aks1ClientSecret = $aks1ServicePrincipal.password
$aks2ClientSecret = $aks1ServicePrincipal.password

# TODO: REMOVE IT LATER
$ApplicationName = $ApplicationName + "5"

# ----- Deploy Bicep
Write-Title("Deploy Bicep files")
$r = (az deployment sub create --location $Location `
           --template-file .\bicep\core-infrastructure.bicep --parameters currentAzUsernameId=$currentAzUsernameId `
           applicationName=$ApplicationName `
           aks1ObjectId=$aks1ObjectId aks1ClientId=$aks1ClientId aks1ClientSecret=$aks1ClientSecret `
           aks2ObjectId=$aks2ObjectId aks2ClientId=$aks2ClientId aks2ClientSecret=$aks2ClientSecret `
    )| ConvertFrom-Json

$aks1Name = $r.properties.outputs.aks1Name.value
$aks2Name = $r.properties.outputs.aks2Name.value
$resourceGroupName = $r.properties.outputs.resourceGroupName.value

# ----- Install Arc CLI Extensions
Write-Title("Azure Arc CLI Extensions")
az extension add --name "connectedk8s"
az extension add --name "k8s-configuration"
az extension add --name "k8s-extension"
az extension add --name "customlocation"

# ----- Install core dependencies in AKS clusters
$aks = [AKS]::new()

$proxyConfig = $aks.Prepare($resourceGroupName, $aks1Name, $null)
$proxyConfig = $aks.Prepare($resourceGroupName, $aks2Name, $proxyConfig)

$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow