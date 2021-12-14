// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@maxLength(20)
@description('AKS Name')
param aksName string

// optional params
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@minValue(1)
@maxValue(50)
param agentCount int = 3

param agentVMSize string = 'Standard_B4ms'

resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: aksName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enableRBAC: true
    dnsPrefix: uniqueString(aksName)
    agentPoolProfiles: [
      {
        name: 'agentpool'
        enableAutoScaling: false
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
output aksName string = aks.name
output clusterPrincipalID string = aks.properties.identityProfile.kubeletidentity.objectId
