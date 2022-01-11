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
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suneetnangia/distributed-az-edge-framework/feature/docs-update/deployment/deploy-az-demo-aks.ps1" -OutFile "deploy-az-demo-aks.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suneetnangia/distributed-az-edge-framework/feature/docs-update/deployment/deploy-core-platform.ps1" -OutFile "deploy-core-platform.ps1"

mkdir -p bicep/modules

Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suneetnangia/distributed-az-edge-framework/feature/docs-update/deployment/bicep/az-demo-aks.bicep" -OutFile "./bicep/az-demo-aks.bicep"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/suneetnangia/distributed-az-edge-framework/main/deployment/bicep/modules/aks.bicep" -OutFile "./bicep/modules/aks.bicep"

./deploy-az-demo-aks.ps1 -ApplicationName $ApplicationName
./deploy-core-platform.ps1 -ApplicationName $ApplicationName