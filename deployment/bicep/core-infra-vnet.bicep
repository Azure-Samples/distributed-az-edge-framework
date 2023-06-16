// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
targetScope = 'subscription'

@description('The common name for this application')
param applicationName string

@description('Remote virtual network name')
param remoteVnetName string = 'defaultvnet'

@description('Remote virtual network resource group')
param remoteVnetResourceGroupName string

@description('Virtual network name')
param vnetName string

@description('Location of resources')
@allowed([
  'eastasia'
  'southeastasia'
  'centralus'
  'eastus'
  'eastus2'
  'westus'
  'northcentralus'
  'southcentralus'
  'northeurope'
  'westeurope'
  'japanwest'
  'japaneast'
  'brazilsouth'
  'australiaeast'
  'australiasoutheast'
  'southindia'
  'centralindia'
  'westindia'
  'jioindiawest'
  'jioindiacentral'
  'canadacentral'
  'canadaeast'
  'uksouth'
  'ukwest'
  'westcentralus'
  'westus2'
  'koreacentral'
  'koreasouth'
  'francecentral'
  'francesouth'
  'australiacentral'
  'australiacentral2'
  'uaecentral'
  'uaenorth'
  'southafricanorth'
  'southafricawest'
  'switzerlandnorth'
  'switzerlandwest'
  'germanynorth'
  'germanywestcentral'
  'norwaywest'
  'norwayeast'
  'brazilsoutheast'
  'westus3'
  'swedencentral'
])
param location string = 'westeurope'

@description('Vnet Address Range')
param vnetAddressPrefix string

@description('Subnet Address Range')
param subnetAddressPrefix string

@description('Current Azure user name Id')
param currentAzUsernameId string

@description('The AKS service principal object id')
param aksObjectId string

@description('Wether to close down outbound internet access')
param closeOutboundInternetAccess bool = false

var applicationNameWithoutDashes = replace(applicationName, '-', '')
var aksName = take('aks-${applicationNameWithoutDashes}', 20)
var resourceGroupName = applicationName

resource rg 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: resourceGroupName
  location: location
}

module vnet 'modules/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetDeployment'
  params: {
    vnetName: vnetName
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    vnetLocation: location
    currentAzUsernameId: currentAzUsernameId
    aksName: aksName
    aksObjectId: aksObjectId
    closeOutboundInternetAccess: closeOutboundInternetAccess
  }
}

module upstreamvnetpeering 'modules/vnetpeering.bicep' = if (!empty(remoteVnetResourceGroupName) && !empty(remoteVnetName)) {
  scope: resourceGroup(rg.name)
  name: 'upstreamVnetPeeringDeployment'
  params: {
    vnetName: vnetName
    remoteVnetName: remoteVnetName
    remoteVnetResourceGroupName: remoteVnetResourceGroupName
  }
  dependsOn: [
    vnet
  ]
}

module downstreamvnetpeering 'modules/vnetpeering.bicep' = if (!empty(remoteVnetResourceGroupName) && !empty(remoteVnetName)) {
  scope: resourceGroup(remoteVnetResourceGroupName)
  name: 'downstreamVnetPeeringDeployment'
  params: {
    vnetName: remoteVnetName
    remoteVnetName: vnetName
    remoteVnetResourceGroupName: rg.name
  }
  dependsOn: [
    vnet
  ]
}

output aksName string = aksName
output aksResourceGroup string = resourceGroupName
output subnetId string = vnet.outputs.subnetId
