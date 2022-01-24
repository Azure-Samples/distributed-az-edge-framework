// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@maxLength(20)
@description('Azure Event Hub Namespace.')
param eventHubNameSpaceName string

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: eventHubNameSpaceName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
  }
}

var eventHubName = '${eventHubNameSpaceName}hub'
resource eventHubNamespaceName_eventHubName 'Microsoft.EventHub/namespaces/eventhubs@2021-01-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource eventHubNamespaceName_eventHubName_Send 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2021-01-01-preview' = {
  parent: eventHubNamespaceName_eventHubName
  name: 'iot-edge'
  properties: {
    rights: [      
      'Send'
    ]
  } 
}

var eventHubConnectionString = listKeys(eventHubNamespaceName_eventHubName_Send.id, eventHubNamespaceName_eventHubName_Send.apiVersion).primaryConnectionString
output eventHubConnectionString string = eventHubConnectionString
output eventHubName string = eventHubName
