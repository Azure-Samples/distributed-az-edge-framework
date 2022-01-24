// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------
@minLength(3)
@maxLength(24)
@description('Azure Stroage Account name which is not already in use.')
param storageAccountName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

// TODO: Remove keys from output.
output storageKey string = storageAccount.listKeys().keys[0].value
output storageName string = storageAccountName
