// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

@description('Name')
param vnetName string

@description('Vnet Address Prefix')
param vnetAddressPrefix string

@description('Subnet Address Range')
param subnetAddressPrefix string 

@description('Virtual network location')
@maxLength(20)
param vnetLocation string = resourceGroup().location

@description('Current Azure user name Id')
param currentAzUsernameId string

@description('AKS cluster name')
param aksName string

@description('The AKS service principal object id')
param aksObjectId string

var subnetName = aksName
var subnetNsgName = aksName

// TODO: We need to do this is nested manner e.g. use parent vnet/subnet if this is nested vnet/subnet creation.
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

// TODO: potentially remove this if going through proxy, for now setup for testing MQTT bridging
var allowMqttSslInboundSecurityRule = {
  name: 'AllowMqttSsl'
  properties: {
    priority: 1020
    access: 'Allow'
    direction: 'Inbound'
    destinationPortRange: '8883'
    protocol: 'Tcp'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'VirtualNetwork'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: subnetNsgName
  location: vnetLocation
  properties: {
    securityRules: [
      allowProxyInboundSecurityRule, allowMqttSslInboundSecurityRule
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: vnetLocation
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }   
  }
}

resource subnets 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetAddressPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

var roleNetworkContributor = '4d97b98b-1d4f-4787-a291-c67834d212e7'

resource assignNetworkContributorToAks 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vnetName, aksObjectId, 'AssignNetworkContributorToAks1')
  scope: vnet
  properties: {
    description: 'Assign Network Contributor role to AKS'
    principalId: aksObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleNetworkContributor}'
  }
}

// Add user to network contributor role at the vnet level to allow creation of AKS Services with external-Ips
// Make this conditional i.e. if user already has access, do not attempt to add again using = if (parentvnet)
resource assignNetworkContributorToCurrentAzureUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, vnetName, currentAzUsernameId, 'assignNetworkContributorToCurrentAzureUser')
  scope: vnet
  properties: {
    description: 'Assign Network Contributor role to an Azure user'
    principalId: currentAzUsernameId
    principalType: 'User'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleNetworkContributor}'
  }
}

output vnetId string = vnet.id
output subnetId string = '${vnet.id}/subnets/${subnetName}'
