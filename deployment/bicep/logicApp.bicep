@description('The datacenter to use for the deployment.')
param location string
param applicationName string
param storageName string
param storageKey string
param customLocationId string
param kubeEnvironmentId string
param use32BitWorkerProcess bool
param acrUrl string
param acrUsername string
@secure()
param acrPassword string
param containerName string

var logicAppName = 'la-${applicationName}'
var appServicePlanName = 'asp-${logicAppName}'
var username = acrUsername
var password = acrPassword

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  location: location
  name: appServicePlanName
  kind: 'kubernetes,linux'
  extendedLocation: {
    name: customLocationId
    type: 'CustomLocation'
  }
  sku: {
    name: 'K1'
    tier: 'Kubernetes'
    capacity: 1
  }
  properties: {
    kubeEnvironmentProfile: {
      id: kubeEnvironmentId
    }
  }
}

resource logicApp 'Microsoft.Web/sites@2022-03-01' = {
  name: logicAppName
  location: location
  kind: 'kubernetes,functionapp,workflowapp,container'
  extendedLocation: {
    name: customLocationId
    type: 'CustomLocation'
  }
  properties: {
    //name: logicAppName
    clientAffinityEnabled: false
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageName};AccountKey=${storageKey};EndpointSuffix=core.windows.net'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowapp'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrUrl}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrUsername
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acrPassword
        }
      ]
      use32BitWorkerProcess: use32BitWorkerProcess
      linuxFxVersion: 'DOCKER|${containerName}'
    }
  }
}
