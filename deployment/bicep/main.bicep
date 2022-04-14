// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
targetScope = 'subscription'

@description('The common name for this application')
param applicationName string

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

@description('Current Azure user name Id')
param currentAzUsernameId string

@description('The AKS #1 service principal object id')
param aks1ObjectId string

@description('The AKS #1 service principal client id')
param aks1ClientId string

@description('The AKS #1 service principal client secret')
param aks1ClientSecret string

@description('The AKS #2 service principal object id')
param aks2ObjectId string

@description('The AKS #2 service principal client id')
param aks2ClientId string

@description('The AKS #2 service principal client secret')
param aks2ClientSecret string

var applicationNameWithoutDashes = '${replace(applicationName,'-','')}'
var resourceGroupName = 'rg-${applicationNameWithoutDashes}'
var vnetName = 'vnet-${applicationNameWithoutDashes}'
var aks1Name = '${take('aks1-${applicationNameWithoutDashes}',20)}'
var aks2Name = '${take('aks2-${applicationNameWithoutDashes}',20)}'
var acrName = 'acr${applicationNameWithoutDashes}'
var storageAccountName = 'st${take(applicationNameWithoutDashes,14)}'
var eventHubNameSpaceName = 'evh${take(applicationNameWithoutDashes,14)}'

resource rg 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: resourceGroupName
  location: location
}

module vnet 'modules/vnet.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'vnetDeployment'
  params: {
    vnetName: vnetName
    vnetLocation: location
    currentAzUsernameId: currentAzUsernameId
    aks1ObjectId: aks1ObjectId
    aks2ObjectId: aks2ObjectId
  }
}

module aks1 'modules/aks.bicep' = {
  name: 'aks1Deployment'
  scope: resourceGroup(rg.name)
  params: {
    aksName: aks1Name
    aksLocation: location
    aksClientId: aks1ClientId
    aksClientSecret: aks1ClientSecret
    vnetSubnetID: vnet.outputs.subnetId1
  }
}

module aks2 'modules/aks.bicep' = {
  name: 'aks2Deployment'
  scope: resourceGroup(rg.name)
  params: {
    aksName: aks2Name
    aksLocation: location
    aksClientId: aks2ClientId
    aksClientSecret: aks2ClientSecret
    vnetSubnetID: vnet.outputs.subnetId2
  }
}

module acr 'modules/acr.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'acrDeployment'
  params: {
    acrName: acrName
    acrLocation: location
    aks1PrincipalId: aks1ObjectId
    aks2PrincipalId: aks2ObjectId
  }

  dependsOn: [
    aks1
    aks2
  ]
}

module storage 'modules/azurestorage.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'storageDeployment'
  params: {
    storageAccountName: storageAccountName
    storageAccountLocation: location
  }
}

module eventhub 'modules/eventhub.bicep' = {
  scope: resourceGroup(rg.name)
  name: 'eventHubDeployment'  
  params: {
    eventHubNameSpaceName: eventHubNameSpaceName
    eventHubNamespaceLocation: location
  }
}

output acrName string = acrName
output aks1Name string = aks1.outputs.aksName
output aks2Name string = aks2.outputs.aksName
output resourceGroupName string = resourceGroupName
output storageKey string = storage.outputs.storageKey
output storageName string = storage.outputs.storageName
output eventHubConnectionString string = eventhub.outputs.eventHubConnectionString
