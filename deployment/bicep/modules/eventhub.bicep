// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@maxLength(20)
@description('Azure Event Hub Namespace.')
param eventHubNameSpaceName string

@description('Event Hub namespace location')
@maxLength(20)
param eventHubNamespaceLocation string = resourceGroup().location

var eventHubSendRuleName = 'iot-edge'

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-01-01-preview' = {
  name: eventHubNameSpaceName
  location: eventHubNamespaceLocation
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    zoneRedundant: false
  }
}

var eventHubName = 'telemetry'
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
  name: eventHubSendRuleName
  properties: {
    rights: [      
      'Send'
    ]
  } 
}

output eventHubSendRuleName string = eventHubSendRuleName
output eventHubName string = eventHubName
