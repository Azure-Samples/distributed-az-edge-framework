# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,

    [string]
    [Parameter(mandatory=$false)]
    $Location = 'westeurope'
)

# Import text utilities module.
Import-Module -Name ./modules/text-utils.psm1
Import-Module -Name ./modules/az-utils.psm1

Write-Title("Start Deploying")
$startTime = Get-Date
$ApplicationName = $ApplicationName.ToLower()

# --- Ensure Location is set to short name
$Location = Get-AzShortRegion($Location)

# --- Deploying 3 layers: comment below block and uncomment bottom block for single layer:

# 1. Deploy core infrastructure (AKS clusters, VNET)

$l4LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L4") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $false -Location $Location
$l3LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l4LevelCoreInfra -ApplicationName ($ApplicationName + "L3") -VnetAddressPrefix "172.18.0.0/16" -SubnetAddressPrefix "172.18.0.0/18" -SetupArc $false -Location $Location
# $l2LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l3LevelCoreInfra -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.20.0.0/16" -SubnetAddressPrefix "172.20.0.0/18" -SetupArc $false -Location $Location

# # # 2. Deploy core platform in each layer (Dapr, Mosquitto and bridging).
# $l4CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l4LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName -DeployDapr $true -MosquittoParentConfig $null
# $l3CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l3LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l3LevelCoreInfra.AksClusterResourceGroupName -MosquittoParentConfig $l4CorePlatform
# ./deploy-core-platform.ps1 -AksClusterName $l2LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l2LevelCoreInfra.AksClusterResourceGroupName -DeployDapr $true -MosquittoParentConfig $l3CorePlatform

# # 3. Deploy app resources in Azure, build images and deploy helm on level L4 and L2.
# $l4AppConfig = ./deploy-dev-app-l4.ps1 -ApplicationName $ApplicationName `
#     -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName `
#     -AksClusterName $l4LevelCoreInfra.AksClusterName -AksServicePrincipalName ($ApplicationName + "L4") `
#     -Location $Location

# # Note currently for developer flow we need Azure Ccontianer Registry deployed by L4 (via L4AppConfig). 
# ./deploy-dev-app-l2.ps1  -ApplicationName $ApplicationName `
#     -AksClusterName $l2LevelCoreInfra.AksClusterName `
#     -AksClusterResourceGroupName $l2LevelCoreInfra.AksClusterResourceGroupName `
#     -AksServicePrincipalName ($ApplicationName + "L2") `
#     -L4AppConfig $l4AppConfig

# # --- Deploying just a single layer: comment above block and uncomment below:

# $l4LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L4") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $false -Location $Location

# ./deploy-core-platform.ps1 -AksClusterName $l4LevelCoreInfra.AksClusterName `
#     -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName `
#     -DeployDapr $true -MosquittoParentConfig $null

# $l4AppConfig = ./deploy-dev-app-l4.ps1 -ApplicationName $ApplicationName `
#     -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName `
#     -AksClusterName $l4LevelCoreInfra.AksClusterName `
#     -AksServicePrincipalName ($ApplicationName + "L4") `
#     -Location $Location

# # when deploying L2 workload on single cluster in L4, passing in parameters pointing to L4 is intentional
# ./deploy-dev-app-l2.ps1  -ApplicationName $ApplicationName `
#     -AksClusterName $l4LevelCoreInfra.AksClusterName `
#     -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName `
#     -AksServicePrincipalName ($ApplicationName + "L4") `
#     -L4AppConfig $l4AppConfig
# #----------------

$runningTime = New-TimeSpan -Start $startTime

Write-Title("Running time bootstrapper: " + $runningTime.ToString())
Write-Title("Distributed Edge Accelerator is now deployed in Azure Resource Groups $ApplicationName + L2 to L4 and $ApplicationName-App.")
Write-Title("Please use the Event Hub instance in the Resource Group $ApplicationName-App to view the OPC UA and Simulated Sensor telemetry.")
Write-Title("Your kubectl current context is now set to the AKS cluster '$(kubectl config current-context)'.")

