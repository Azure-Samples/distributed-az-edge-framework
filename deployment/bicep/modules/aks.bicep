// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@maxLength(20)
@description('AKS Name')
param aksName string

@description('AKS location')
@maxLength(20)
param aksLocation string = resourceGroup().location

// optional params
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@minValue(1)
@maxValue(50)
param agentCount int = 3

param agentVMSize string = 'Standard_B4ms'

@description('The AKS virtual network subnet')
param vnetSubnetID string

@description('The AKS service principal client id')
param aksClientId string

@secure()
@description('The AKS service principal client secret')
param aksClientSecret string

resource aks 'Microsoft.ContainerService/managedClusters@2020-09-01' = {
  name: aksName
  location: aksLocation
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
        vnetSubnetID: vnetSubnetID
      }
    ]
    servicePrincipalProfile: {
      clientId: aksClientId
      secret: aksClientSecret
    }
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
