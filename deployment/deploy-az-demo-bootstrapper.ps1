# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------
Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName
)

# ----- Copy scripts from source location
$baseLocation = "https://raw.githubusercontent.com/suneetnangia/distributed-az-edge-framework/feature/docs-update"

Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-core-infrastructure.ps1" -OutFile "deploy-core-infrastructure.ps1"
Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-core-platform.ps1" -OutFile "deploy-core-platform.ps1"
Invoke-WebRequest -Uri "$baseLocation/deployment/deploy-app.ps1" -OutFile "deploy-app.ps1"

mkdir -p bicep/modules

Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/core-infrastructure.bicep" -OutFile "./bicep/core-infrastructure.bicep"
Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/app.bicep" -OutFile "./bicep/app.bicep"
Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/aks.bicep" -OutFile "./bicep/modules/aks.bicep"
Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/azurestorage.bicep" -OutFile "./bicep/modules/azurestorage.bicep"
Invoke-WebRequest -Uri "$baseLocation/deployment/bicep/modules/eventhub.bicep" -OutFile "./bicep/modules/eventhub.bicep"

./deploy-core-infrastructure.ps1 -ApplicationName $ApplicationName
./deploy-core-platform.ps1 -ApplicationName $ApplicationName
./deploy-app.ps1 -ApplicationName $ApplicationName -AKSClusterResourceGroupName $env:RESOURCEGROUPNAME -AKSClusterName $env:AKSCLUSTERNAME

Write-Host "-------------------------------------------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host "Distributed Edge Accelerator is now deployed, please use the Event Hub instance in Azure to view the OPC UA and Simulated Sensor telemetry." -ForegroundColor Yellow
Write-Host "-------------------------------------------------------------------------------------------------------------------------------------------" -ForegroundColor Yellow