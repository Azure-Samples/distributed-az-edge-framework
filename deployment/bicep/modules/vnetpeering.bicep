// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

@description('Vnet name')
param vnetName string

@description('Remote vnet name')
param remoteVnetName string

@description('Remote vnet resource group')
param remoteVnetResourceGroupName string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
  scope: resourceGroup()
}

resource remoteVnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: remoteVnetName
  scope: resourceGroup(remoteVnetResourceGroupName)
}

resource symbolicname 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  name: '${vnetName}-${remoteVnetName}'
  parent: vnet
  properties: {
    allowForwardedTraffic: true
    allowGatewayTransit: false
    allowVirtualNetworkAccess: true
    doNotVerifyRemoteGateways: false   
    remoteVirtualNetwork: {
      id: remoteVnet.id
    }   
    useRemoteGateways: false
  }
}
