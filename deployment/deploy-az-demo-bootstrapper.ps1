# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,

    [string]
    $ScriptsBranch = "main",

    [string]
    [Parameter(mandatory=$false)]
    $Location = 'westeurope'    
)

# mkdir -p modules
# # Copy scripts from source location
# $baseLocation = "https://raw.githubusercontent.com/azure-samples/distributed-az-edge-framework/$ScriptsBranch"
# Invoke-WebRequest -Uri "$baseLocation/deployment/modules/text-utils.psm1" -OutFile "./modules/text-utils.psm1"
# # Import text utilities module.
# Import-Module -Name .\modules\text-utils.psm1

# Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-core-infrastructure.ps1" -OutFile "deploy-core-infrastructure.ps1"
# Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-core-platform.ps1" -OutFile "deploy-core-platform.ps1"
# Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-app.ps1" -OutFile "deploy-app.ps1"

# mkdir -p bicep/modules
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/core-infrastructure.bicep" -OutFile "./bicep/core-infrastructure.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/iiot-app.bicep" -OutFile "./bicep/iiot-app.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/acr.bicep" -OutFile "./bicep/modules/acr.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/aks.bicep" -OutFile "./bicep/modules/aks.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/azurestorage.bicep" -OutFile "./bicep/modules/azurestorage.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/eventhub.bicep" -OutFile "./bicep/modules/eventhub.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/vnet.bicep" -OutFile "./bicep/modules/vnet.bicep"
# Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/vnetpeering.bicep" -OutFile "./bicep/modules/vnetpeering.bicep"

# Deploy 3 core infrastructure layers i.e. L4, L3, L2, replicating 3 levels of Purdue network topology.
# Tip: You can split the below pipes into indivudual cmds and assign them to vars, to deploy core-platform and/or apps to those clusters.
$l4LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L4") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $true -SetupProxy $false -Location $Location
$l3LevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l4LevelCoreInfra -ApplicationName ($ApplicationName + "L3") -VnetAddressPrefix "172.18.0.0/16" -SubnetAddressPrefix "172.18.0.0/18" -SetupArc $true -SetupProxy $true  -Location $Location
$lowestLevelCoreInfra = ./deploy-core-infrastructure.ps1 -ParentConfig $l3LevelCoreInfra -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.20.0.0/16" -SubnetAddressPrefix "172.20.0.0/18" -SetupArc $true -SetupProxy $true  -Location $Location

# Deploy core platform layer (Dapr on L4 and L2, Mosquitto broker bridging on L2, L3 and L4).
$l4CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l4LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l4LevelCoreInfra.AksClusterResourceGroupName -DeployDapr $true -MosquittoParentConfig $null
$l3CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $l3LevelCoreInfra.AksClusterName -AksClusterResourceGroupName $l3LevelCoreInfra.AksClusterResourceGroupName -MosquittoParentConfig $l4CorePlatform
$l2CorePlatform = ./deploy-core-platform.ps1 -AksClusterName $lowestLevelCoreInfra.AksClusterName -AksClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName -DeployDapr $true -MosquittoParentConfig $l3CorePlatform

# Deploy app layer on the lowest infrastructure level, L2.
./deploy-app.ps1 -ApplicationName $ApplicationName -AksClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName `
    -AksClusterName $lowestLevelCoreInfra.AksClusterName `
    -AksClusterNameLower $lowestLevelCoreInfra.AksClusterName `
    -AksClusterResourceGroupNameLower $lowestLevelCoreInfra.AksClusterResourceGroupName `
    -ScriptsBranch $ScriptsBranch

Write-Title("Distributed Edge Accelerator is now deployed in Azure Resource Group with suffix -App, please use the Event Hub instance in tha Resource Group to view the OPC UA and Simulated Sensor telemetry.")
