// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

@description('Name')
param vnetName string

@description('The AKS #1 service principal client id')
param aks1ClientId string

@description('The AKS #2 service principal client id')
param aks2ClientId string

var nsgName1 = 's1-${vnetName}'
var nsgName2 = 's2-${vnetName}'
var nsgName3 = 's3-${vnetName}'

var subnetName1 = 's1'
var subnetName2 = 's2'
var subnetName3 = 's2'

var vnetAddressPrefix = '172.16.0.0/16'
var subnetAddressPrefix1 = '172.16.0.0/18'
var subnetAddressPrefix2 = '172.16.64.0/18'
var subnetAddressPrefix3 = '172.16.128.0/17'

var allowProxyInboundSecurityRule = {
  name: 'AllowProxy'
  properties: {
    priority: 1010
    access: 'Allow'
    direction: 'Inbound'
    destinationPortRange: '3128'
    protocol: 'Tcp'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'VirtualNetwork'
  }
}

resource nsg1 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName1
  location: resourceGroup().location
  properties: {
    securityRules: [
      allowProxyInboundSecurityRule
    ]
  }
}

resource nsg2 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName2
  location: resourceGroup().location
  properties: {
    securityRules: [
      allowProxyInboundSecurityRule
    ]
  }
}

resource nsg3 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgName3
  location: resourceGroup().location
  properties: {
    securityRules: [
      allowProxyInboundSecurityRule
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName1
        properties: {
          addressPrefix: subnetAddressPrefix1
          networkSecurityGroup: {
            id: nsg1.id
          }
        }
      }
      {
        name: subnetName2
        properties: {
          addressPrefix: subnetAddressPrefix2
          networkSecurityGroup: {
            id: nsg2.id
          }
        }
      }
      {
        name: subnetName3
        properties: {
          addressPrefix: subnetAddressPrefix3
          networkSecurityGroup: {
            id: nsg3.id
          }
        }
      }
    ]
  }
}

var roleNetworkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource assignNetworkContributorToAks1 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vnetName, aks1ClientId, 'AssignNetworkContributorToAks1')
  scope: vnet
  properties: {
    description: 'Assign Network Contributor role to second AKS'
    principalId: aks1ClientId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleNetworkContributor}'
  }
}

resource assignNetworkContributorToAks2 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vnetName, aks2ClientId, 'AssignNetworkContributorToAks2')
  scope: vnet
  properties: {
    description: 'Assign Network Contributor role to second AKS'
    principalId: aks2ClientId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleNetworkContributor}'
  }
}

output vnetId string = vnet.id
output subnetId1 string = '${vnet.id}/subnets/${subnetName1}'
output subnetId2 string = '${vnet.id}/subnets/${subnetName2}'
