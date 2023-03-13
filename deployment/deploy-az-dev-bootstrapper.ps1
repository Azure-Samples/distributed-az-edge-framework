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
Import-Module -Name .\modules\text-utils.psm1

Write-Title("Start Deploying")
$startTime = Get-Date
$ApplicationName = $ApplicationName.ToLower()

# 1. Deploy core infrastructure (AKS clusters, VNET)

# TODO - explain dev setup with new structure
# Uncomment the section below to create 3 layered AKS deployment instead of a single one for development which is the script's default further below
# Deploy 3 core infrastructure layers i.e. L4, L3, L2, replicating 3 levels of Purdue network topology.
#                         .\deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.20.0.0/16" -SubnetAddressPrefix "172.20.0.0/18" -SetupArc $false

# Comment out below line if you are choosing the above 3 layer deployment instead.

$l4LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L4") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $false -SetupProxy $true -Location $Location

Write-Title("Core infra: $l4CoreInfra ")
# deploy DNS Azure services
./deploy-private-dns.ps1 -ApplicationName $ApplicationName -VnetName $l4LevelCoreInfra.VnetName -VnetResourceGroup $l4LevelCoreInfra.VnetResourceGroup -Location $Location
# then continue other layers
# $l3LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l4LevelCoreInfra -ApplicationName ($ApplicationName + "L3") -VnetAddressPrefix "172.18.0.0/16" -SubnetAddressPrefix "172.18.0.0/18" -SetupArc $false -SetupProxy $true  -Location $Location
# # $lowestLevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l3LevelCoreInfra -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.20.0.0/16" -SubnetAddressPrefix "172.20.0.0/18" -SetupArc $false -SetupProxy $true  -Location $Location

# # 2. Deploy core platform.
# $l4CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l4LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName -MosquittoParentConfig $null
# $l3CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l3LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l3LevelCoreInfra.AksClusterResourceGroupName -DeployDapr $true -MosquittoParentConfig $l4CorePlatform
# $l2CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $lowestLevelCoreInfra.AksClusterName -AksClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName -MosquittoParentConfig $l3CorePlatform.MosquittoParentConfig

# # 3. Deploy app resources, build images and deploy helm.
# ./deploy-dev-app.ps1 -ApplicationName $ApplicationName -AksClusterResourceGroupName $l3LevelCoreInfra.AksClusterResourceGroupName -AksClusterName $l3LevelCoreInfra.AksClusterName -AksServicePrincipalName ($ApplicationName + "L3")
# ./deploy-dev-app.ps1 -ApplicationName $ApplicationName -AksClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName -AksClusterName $lowestLevelCoreInfra.AksClusterName -AksServicePrincipalName ($ApplicationName + "L2")

$runningTime = New-TimeSpan -Start $startTime

Write-Title("Running time bootstrapper: " + $runningTime.ToString())
Write-Title("Distributed Edge Accelerator is now deployed in Azure Resource Groups $ApplicationName and $ApplicationName-App.")
Write-Title("Please use the Event Hub instance in the Resource Group $ApplicationName-App to view the OPC UA and Simulated Sensor telemetry.")

