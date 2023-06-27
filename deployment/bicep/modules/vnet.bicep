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

@description('Wether to close down outbound internet access')
param closeOutboundInternetAccess bool = false

var subnetName = aksName
var subnetNsgName = aksName

var arrayBasicRules = [ allowProxyInboundSecurityRule, allowMqttSslInboundSecurityRule ]
var arrayBaseAndLockRules = [ allowProxyInboundSecurityRule, allowMqttSslInboundSecurityRule, allowK8ApiHTTPSOutbound, allowK8ApiUdpOutbound, allowTagAks9000Outbound, allowTagFrontDoorFirstParty, allowTagMcr, denyOutboundInternetAccessSecurityRule ]

// TODO: We need to do this is nested manner e.g. use parent vnet/subnet if this is nested vnet/subnet creation.
var allowProxyInboundSecurityRule = {
  name: 'AllowProxy'
  properties: {
    priority: 1010
    access: 'Allow'
    direction: 'Inbound'
    destinationPortRange: '443'
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

var allowK8ApiHTTPSOutbound = {
  name: 'AllowK8ApiHTTPSOutbound'
  properties: {
    priority: 1010
    access: 'Allow'
    direction: 'Outbound'
    destinationPortRange: '443'
    protocol: 'Tcp'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'AzureCloud'
  }
}

var allowTagAks9000Outbound = {
  name: 'AllowTagAks9000Outbound'
  properties: {
    priority: 1020
    access: 'Allow'
    direction: 'Outbound'
    destinationPortRange: '9000'
    protocol: 'TCP'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'AzureCloud'
  }
}

var allowTagMcr = {
  name: 'AllowTagMcr'
  properties: {
    priority: 1040
    access: 'Allow'
    direction: 'Outbound'
    destinationPortRange: '443'
    protocol: 'TCP'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'MicrosoftContainerRegistry'
  }
}

var allowTagFrontDoorFirstParty = {
  name: 'AllowTagFrontDoorFirstParty'
  properties: {
    priority: 1050
    access: 'Allow'
    direction: 'Outbound'
    destinationPortRange: '443'
    protocol: 'TCP'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'AzureFrontDoor.FirstParty'
  }
}

var allowK8ApiUdpOutbound = {
  name: 'AllowK8ApiUdpOutbound'
  properties: {
    priority: 1060
    access: 'Allow'
    direction: 'Outbound'
    destinationPortRange: '1194'
    protocol: 'UDP'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'AzureCloud'
  }
}  

var denyOutboundInternetAccessSecurityRule = {
  name: 'DenyOutboundInternetAccess'
  properties: {
    priority: 2000
    access: 'Deny'
    direction: 'Outbound'
    destinationPortRange: '*'
    protocol: '*'
    sourcePortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: 'Internet'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: subnetNsgName
  location: vnetLocation
  properties: {
    securityRules: closeOutboundInternetAccess ? arrayBaseAndLockRules : arrayBasicRules 
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
