# Setup a developer environment on Azure with local application deployment

## Introduction
This environment is used to setup a fast developer environment which means that Arc and Flux is not included in the environment and only a single layer is deployed.

## Prerequisites on developer machine

- PowerShell on Windows, or PowerShell Core on Linux/MacOS
- .NET 6.0
- .NET Core 3.1
- Azure CLI 2.37+
- Docker

## How to execute it

### Windows
Go to the `deployment` folder and run `.\deploy-az-dev-bootstrapper.ps1 -ApplicationName <short-name>`

> Disclaimer: currently there is an issue we found on Windows with Azure CLI version 2.40, which has to do with character parsing in a script used with the Industrial IoT stack (this is used to build the OPC Publisher image). A bug to the Azure CLI team has been filed, in the meantime either use Azure CLI <= 2.37, or run in bash on WSL2.

### Bash

Go to the `deployment` folder and run `pwsh ./deploy-az-dev-bootstrapper.ps1 -ApplicationName <short-name>`

## The main functions in the script
1. Deploy infrastructure with Bicep, the script deploys AKS cluster.
    * AKS
    * VNET
    * Deploy Squid proxy in each layer

3. Download AKS credentials.

4. Install Dapr with Helm in AKS.

5. Install Redis with Helm in AKS.

6. Provision Azure appplication resources (ACR, Event Hubs, Storage).

7. Use `az acr build` to build and push images to the ACR.

8. Install our components with Helm in AKS.

## Deploy application updates

Subsequent deployments can be run as follows.

> `<resource-group-with-acr>` normally refers to the Resource Group with the `<short-name>` appended with `-App`.

### Windows

`.\build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr>` 

### Bash

`pwsh ./build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr>` 

## Delete all developer environment Azure resources 

To remore all Azure resources setup by the default script (AKS clusters, app resources and service principals), run the following from the `deployment` folder:

### Windows

`.\remove-dev-resources.ps1 -ApplicationName <short-name>`

### Bash

`pwsh ./remove-dev-resources.ps1 -ApplicationName <short-name>`

## Optional three network layered deployment

The deployment script also has an option to deploy 3 layers of AKS and networking infrastructure. To use that version, uncomment the section in the `deploy-az-dev-bootstrapper.ps1`, details can be found in the comments of the script.
The same applies to removing resources, `remove-dev-resources.ps1` also has commented sections to delete the three layer resources instead.


