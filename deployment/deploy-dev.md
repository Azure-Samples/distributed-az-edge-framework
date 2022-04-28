# Setup a developer environment on Azure with local application deployment

## Introduction
This environment is used to setup a fast developer environment, which means that Arc and Flux is not included in the environment.

## How to execute it
Go to the `deployment` folder and run `deploy-az-dev-bootstrapper.ps1 -ApplicationName <short-name>`

## The main functions in the script
1. Deploy infrastructure with Bicep, the script deploys AKS cluster.
    * AKS
    * VNET
    * Deploy Squid proxy in each layer

3. Download AKS credentials

4. Install Dapr with Helm in AKS in lowest layer

5. Install Redis with Helm in AKS in lowest layer

6. Provision Azure appplication resources for lowest layer.

7. Use `az acr build` to build and push images to the ACR

8. Install our components with Helm in AKS in lowest layer

## Deploy application updates

Subsequent deployments can be ran by calling 

`build-and-deploy-images.ps1 -ResourceGroupName <resource-group-with-acr>` 

## Delete all developer environment Azure resources 

To remore all Azure resources setup by the default script (AKS clusters, app resources and service principals), run the following from the `deployment` folder:

`remove-dev-resources.ps1 -ApplicationName <short-name>`

## Optional three network layered deployment

The deployment script also has an option to deploy 3 layers of AKS and networking infrastructure. To use that version, uncomment the section in the `deploy-az-dev-bootstrapper.ps1`, details can be found in the comments of the script.
The same applies to removing resources, `remove-dev-resources.ps1` also has commented sections to delete the three layer resources instead.


