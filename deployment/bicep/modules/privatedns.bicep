// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@description('Private DNS Zone name')
@maxLength(20)
param dnsZoneName string

@description('Private DNS Zone location')
@maxLength(20)
param dnsZoneLocation string = resourceGroup().location

@description('Vnet Name')
param vnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: vnetName
  scope: resourceGroup()
}

resource dnsZonePrivate 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: dnsZoneName
  location: dnsZoneLocation
}

resource dnsZonePrivateVLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'string'
  location: dnsZoneLocation
  parent: dnsZonePrivate
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet.id
    }
  }
}
