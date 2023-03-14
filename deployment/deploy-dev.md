# Setup a developer environment on Azure with local application deployment

## Introduction

This flow is used to setup a developer environment in Azure without Azure Arc and Flux. Additionally, only one single level (single AKS cluster) is deployed. Everything is executed from the local developer machine.

## Prerequisites on developer machine

- PowerShell on Windows, or PowerShell Core on Linux/MacOS
- .NET 6.0
- .NET Core 3.1
- Azure CLI 2.40+
- Docker
- helm
- kubectl

## How to execute it

In a PowerShell environment, go to `deployment` folder and run `./deploy-az-dev-bootstrapper.ps1 -ApplicationName <short-name>`

## The main functions in the script

1. Deploy infrastructure with Bicep, the script deploys AKS cluster.
    - AKS
    - VNET
    - Squid proxy in cluster

2. Download AKS credentials.

3. Install DAPR with Helm in AKS.

4. Install Redis with Helm in AKS.

5. Provision Azure application resources (ACR, Event Hubs, Storage).

6. Use `az acr build` to build and push images to the ACR.

7. Install components for AKS with Helm.

## Deploy application updates

Subsequent deployments can be run as follows:

> `<resource-group-with-acr>` refers to the Resource Group with the `<short-name>` appended with `-App`.

### Update PowerShell

`./build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr>`

## Delete all developer environment Azure resources

To remove all Azure resources setup by the default script (AKS clusters, app resources and service principals), run the following from the `deployment` folder:

### Delete PowerShell

`./remove-dev-resources.ps1 -ApplicationName <short-name>`

## Optional three network layered deployment

The deployment script also has an option to deploy three (3) nested layers of AKS and networking infrastructure. To use the nested deployment version, uncomment the first section in the `deploy-az-dev-bootstrapper.ps1`. Instructions can be found in the comments of the script.

Follow a similar approach for removing resources in nested deployments. `remove-dev-resources.ps1` also has commented sections to delete the three layer resources.
