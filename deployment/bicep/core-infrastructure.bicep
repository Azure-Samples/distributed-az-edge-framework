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

var applicationNameWithoutDashes = '${replace(applicationName,'-','')}'
var resourceGroupName = 'rg-${applicationNameWithoutDashes}'
var aksName = '${take('aks-${applicationNameWithoutDashes}',20)}'

resource rg 'Microsoft.Resources/resourceGroups@2020-10-01' = {
  name: resourceGroupName
  location: location
}

module aks 'modules/aks.bicep' = {
  name: 'aksDeployment'
  scope: resourceGroup(rg.name)
  params: {
    aksName: aksName
  }
}

output aksName string = aks.outputs.aksName
output clusterPrincipalID string = aks.outputs.clusterPrincipalID
output resourceGroupName string = rg.name
