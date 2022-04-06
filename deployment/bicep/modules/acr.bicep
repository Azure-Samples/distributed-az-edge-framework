// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@description('ACR name')
@maxLength(20)
param acrName string

@description('ACR location')
@maxLength(20)
param acrLocation string = resourceGroup().location

@description('The AKS #1 service principal client id')
param aks1PrincipalId string

@description('The AKS #2 service principal client id')
param aks2PrincipalId string

@allowed([
  'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
])
param roleAcrPull string = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource acr 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: acrName
  location: acrLocation
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource assignAcrPullToAks1 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, acrName, aks1PrincipalId, 'AssignAcrPullToAks')
  scope: acr
  properties: {
    description: 'Assign AcrPull role to AKS #1'
    principalId: aks1PrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleAcrPull}'
  }
}

resource assignAcrPullToAks2 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(resourceGroup().id, acrName, aks2PrincipalId, 'AssignAcrPullToAks')
  scope: acr
  properties: {
    description: 'Assign AcrPull role to AKS #2'
    principalId: aks2PrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${roleAcrPull}'
  }
}
