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

    [string]
    [Parameter(mandatory=$true)]
    $VnetName,  

    [string]
    [Parameter(mandatory=$true)]
    $VnetResourceGroup
    
)

# Import-Module -Name .\modules\text-utils.psm1

# ----- Private DNS setup - should only be done once within the top layer VNET for easiness
# Write-Title("Start Deploying Private DNS")
$startTime = Get-Date
$namespaceName = "edge-dns"

# TODO move to BICEP usage
$dnsResourceGroupName = "$ApplicationName-dns"
$dnsName = "$ApplicationName.info"
az group create -n $dnsResourceGroupName -l $Location
az network private-dns zone create -g $dnsResourceGroupName -n $dnsName 

# Add link to vnet
$vnetResourceId = (az network vnet show --name $VnetName -g $VnetResourceGroup --query id -o tsv)
az network private-dns link vnet create -g $dnsResourceGroupName -n "$dnsName-link" `
    -z $dnsName -v $vnetResourceId --registration-enabled true

$privateDnsResourceId = (az network private-dns zone show --name $dnsName -g $dnsResourceGroupName --query id -o tsv)
$privateDnsResourceGroupId = (az group show --name $dnsResourceGroupName --query id -o tsv)

$dnsServicePrincipal = (az ad sp create-for-rbac -n "http://$dnsName-sp") | ConvertFrom-Json
$dnsServicePrincipalAppId = $dnsServicePrincipal.appId

# Role assignments
# 1. as a reader to the resource group
az role assignment create --role "Reader" --assignee $dnsServicePrincipalAppId --scope $privateDnsResourceGroupId

# 2. as a contributor to DNS Zone itself
az role assignment create --role "Private DNS Zone Contributor" --assignee $dnsServicePrincipalAppId --scope $privateDnsResourceId

$tenantId = (az account show --query tenantId -o tsv)
$dnsServicePrincipalSecret = $dnsServicePrincipal.password
$subscriptionId = (az account show --query id -o tsv)

Write-Host "dnsName=$dnsName"
Write-Host "resourceGroupName=$dnsResourceGroupName"
Write-Host "tenantId=$tenantId"
Write-Host "subscriptionId=$subscriptionId"
Write-Host "aadClientId=$dnsServicePrincipalAppId"
Write-Host "aadClientSecret=$dnsServicePrincipalSecret"

# ----- Helm chart deployment

# Write-Title("Install Mosquitto without bridge to parent")
    #  use default mosquitto deployment
    helm install privatedns ./helm/azprivatedns `
    --namespace $namespaceName `
    --set-string azure.dnsZoneName="$dnsName" `
    --set-string azure.resourceGroupName="$resourceGroupName" `
    --set-string azure.tenantId="$tenantId" `
    --set-string azure.subscriptionId="$subscriptionId" `
    --set-string azure.aadClientId="$dnsServicePrincipalAppId" `
    --set-string azure.aadClientSecret="$dnsServicePrincipalSecret" `
    --create-namespace `
    --wait

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time DNS: $runningTime")

# todo review what needs to be returned
# return $dnsConfig