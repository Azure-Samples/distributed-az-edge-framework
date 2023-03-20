# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName
)

# Import text utilities module.
Import-Module -Name .\modules\text-utils.psm1

Write-Title("Start removal of Azure Resources")
$startTime = Get-Date

#=======================
# This script deletes the resource groups and service principal when choosing the single layer developer deployment

# $appResourceGroup = "$ApplicationName-App"
# $infraResourceGroup = $ApplicationName + "L4"

# # Remove App resource group

# # If you would like to wait for completion of deletion of each Resource group before continuing, simply remove the --no-wait parameter
# Write-Title("Removing $appResourceGroup without waiting for confirmation")
# az group delete --name $appResourceGroup -y --no-wait

# # Remove AKS / infra resource group
# Write-Title("Removing $infraResourceGroup no-wait")
# az group delete --name $infraResourceGroup -y --no-wait

# # Remove Service Principal

# Write-Title("Delete AKS Service Principal, app registration will be suspended for 30 days")

# $aksServicePrincipal = az ad sp list --display-name $ApplicationName | ConvertFrom-Json | Select-Object -First 1

# az ad sp delete --id $aksServicePrincipal.appId

# # also delete the corresponding app, see https://learn.microsoft.com/en-us/cli/azure/microsoft-graph-migration#az-ad-sp-delete
# az ad app delete --id $aksServicePrincipal.appId

# Service principal registration will be suspended for 30 days, but not permanently deleted.
# This means that your Azure AD quota is not released automatically. 
# If you'd like to enforce permanent deletion of suspended app registrations you can use the PowerShell script below

# Get-AzureADUser -ObjectId <your-email> |Get-AzureADUserCreatedObject -All:1| ? deletionTimestamp |% { Remove-AzureADMSDeletedDirectoryObject -Id $_.ObjectId }

#=======================

$appResourceGroup = "$ApplicationName-App"
$l4ResourceGroup = $ApplicationName + "L4"
$l3ResourceGroup = $ApplicationName + "L3"
$l2ResourceGroup = $ApplicationName + "L2"

# Remove App resource group

# If you would like to wait for completion of deletion of each Resource group before continuing, simply remove the --no-wait parameter
Write-Title("Removing $appResourceGroup without waiting for confirmation")
az group delete --name $appResourceGroup -y --no-wait

# Remove AKS 3 layers resource groups
Write-Title("Removing $l2ResourceGroup no-wait")
az group delete --name $l2ResourceGroup -y --no-wait
Write-Title("Removing $l3ResourceGroup no-wait")
az group delete --name $l3ResourceGroup -y --no-wait
Write-Title("Removing $l4ResourceGroup no-wait")
az group delete --name $l4ResourceGroup -y --no-wait

# Remove Service Principals

Write-Title("Delete AKS Service Principals, app registration will be suspended for 30 days")

$aksServicePrincipal2 = az ad sp list --display-name ($ApplicationName + "L2") | ConvertFrom-Json | Select-Object -First 1
$aksServicePrincipal3 = az ad sp list --display-name ($ApplicationName + "L3") | ConvertFrom-Json | Select-Object -First 1
$aksServicePrincipal4 = az ad sp list --display-name ($ApplicationName + "L4") | ConvertFrom-Json | Select-Object -First 1

az ad sp delete --id $aksServicePrincipal2.appId
az ad app delete --id $aksServicePrincipal2.appId
az ad sp delete --id $aksServicePrincipal3.appId
az ad app delete --id $aksServicePrincipal3.appId
az ad sp delete --id $aksServicePrincipal4.appId
az ad app delete --id $aksServicePrincipal4.appId

#=======================

Write-Title("Deletion commands have been triggered, it might take some time before all resources are deleted. ")

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time resources removal:" + $runningTime.ToString())



