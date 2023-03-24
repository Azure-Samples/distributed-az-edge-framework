# Setup a developer environment on Azure with local application deployment

## Introduction

This flow is used to setup a developer environment in Azure without Azure Arc and Flux. By default the three Azure Kubernetes clusters and networking layers are deployed, but the script can be edited to deploy only one layer with all functionality. Everything is executed from the local developer machine.

## Prerequisites on Developer Machine

- PowerShell on Windows, or PowerShell Core on Linux/MacOS
- .NET 6.0
- .NET Core 3.1
- Azure CLI 2.40+
- Docker
- helm
- kubectl
- openssl

## How to Execute the Script

In a PowerShell environment, go to `deployment` folder and run `./deploy-az-dev-bootstrapper.ps1 -ApplicationName <short-name>`

## The Main Functions in the Script

1. Deploy infrastructure with Bicep, the script deploys three AKS clusters.
    - AKS
    - VNET
    - Squid proxy in cluster

2. Download AKS credentials.

3. Install DAPR with Helm in AKS on two of the clusters (level 4 and level 2 of the network topology).

4. Install Mosquitto with Helm in each AKS cluster, including bridging from each lower broker to the level above.

5. Provision Azure application resources (ACR, Event Hubs, Storage).

6. Use `az acr build` to build and push images to the ACR.

7. Install our components with Helm in AKS, splitting some of the application workloads to run on Level 2, and the cloud connected workload on Level 4.

## Deploy Application Updates

Subsequent deployments with new container images and Helm chart upgrades can be ran as follows:

> `<resource-group-with-acr>` refers to the Resource Group with the `<short-name>` appended with `-App`.

### Update PowerShell

In case you deployed the default developer environment with 3 layers (default):

`./build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr> -L4ResourceGroupName <resource-group-L4-cluster> -L2ResourceGroupName <resource-group-L2-cluster>`

### Update PowerShell

In case you deployed a developer environment with one single layer and cluster (you edited the `deploy-az-dev-bootstrapper.ps1` script):

`./build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr> -L4ResourceGroupName <resource-group-L4-cluster>`

## Delete all Developer Environment Azure Resources

To remove all Azure resources setup by the default script (AKS clusters, app resources and service principals), run the following from the `deployment` folder:

### Delete PowerShell

`./remove-dev-resources.ps1 -ApplicationName <short-name>`

## Optional Single Network Layer Deployment

The deployment script also has an option to deploy a single layer of AKS and networking infrastructure. To use the single deployment version, uncomment the second section in the `deploy-az-dev-bootstrapper.ps1`. Instructions can be found in the comments of the script.

Follow a similar approach for removing resources in nested deployments. `remove-dev-resources.ps1` also has commented sections to delete the single layer resources.
