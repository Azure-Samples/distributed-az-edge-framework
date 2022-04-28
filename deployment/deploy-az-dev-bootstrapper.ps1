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

Write-Title("Start Deploying")
$startTime = Get-Date
$ApplicationName = $ApplicationName.ToLower()

# 1. Deploy core infrastructure (AKS clusters, VNET)

# Uncomment the section below to create 3 layered AKS deployment instead of a single one for development which is the script's default further below
# Deploy 3 core infrastructure layers i.e. L4, L3, L2, replicating 3 levels of Purdue network topology.
# Tip: You can split the below pipes into indivudual cmds and assign them to vars, to deploy core-platform and/or apps to those clusters.
# $lowestLevelCoreInfra = .\deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L4") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $false | `
#                         .\deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L3") -VnetAddressPrefix "172.18.0.0/16" -SubnetAddressPrefix "172.18.0.0/18" -SetupArc $false | `
#                         .\deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.20.0.0/16" -SubnetAddressPrefix "172.20.0.0/18" -SetupArc $false

# Comment out below line if you are choosing the above 3 layer deployment instead.
$lowestLevelCoreInfra = ./deploy-core-infrastructure.ps1 -ApplicationName ($ApplicationName + "L2") -VnetAddressPrefix "172.16.0.0/16" -SubnetAddressPrefix "172.16.0.0/18" -SetupArc $false

# 2. Deploy core platform.
./deploy-core-platform.ps1 -AksClusterName $lowestLevelCoreInfra.AksClusterName -AksClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName

# 3. Deploy app resources, build images and deploy helm.
./deploy-dev-app.ps1 -ApplicationName $ApplicationName -AKSClusterResourceGroupName $lowestLevelCoreInfra.AksClusterResourceGroupName -AKSClusterName $lowestLevelCoreInfra.AksClusterName -AksServicePrincipalName ($ApplicationName + "L2")

$runningTime = New-TimeSpan -Start $startTime

Write-Host "Running time bootstrapper:" $runningTime.ToString() -ForegroundColor Yellow
Write-Title("Distributed Edge Accelerator is now deployed in Azure Resource Groups $ApplicationName and $ApplicationName-App.")
Write-Title("Please use the Event Hub instance in the Resource Group $ApplicationName-App to view the OPC UA and Simulated Sensor telemetry.")

