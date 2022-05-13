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

@description('The AKS service principal object id')
param aksObjectId string = ''

@description('Whether to create Azure Container registry with Service Principal role assignment')
param acrCreate bool = false

var applicationNameWithoutDashes = replace(applicationName, '-', '')
var resourceGroupName = '${applicationName}-App'
var storageAccountName = 'st${take(toLower(applicationNameWithoutDashes),22)}'
var eventHubNameSpaceName = 'evh${take(toLower(applicationNameWithoutDashes),14)}'
var acrName = 'acr${applicationNameWithoutDashes}'

resource rg 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: resourceGroupName
  location: location
}

module acr 'modules/acr.bicep' = if(acrCreate && aksObjectId!='') {
  scope: resourceGroup(rg.name)
  name: 'acrDeployment'
  params: {
    acrName: acrName
    acrLocation: location
    aksPrincipalId: aksObjectId
  }
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

output resourceGroupName string = resourceGroupName
output storageName string = storage.outputs.storageName
output eventHubNameSpaceName string = eventHubNameSpaceName
output eventHubSendRuleName string = eventhub.outputs.eventHubSendRuleName
output eventHubName string = eventhub.outputs.eventHubName
output acrName string = acrName
