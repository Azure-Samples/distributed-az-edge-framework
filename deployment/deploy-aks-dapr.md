# Setup an developer environment

## Introduction
This environment is used to setup a fast developer environment, which means that Acr and Flux is not included
in the environment.

## How to execute it
Go to the `development` folder and run `deploy-aks-dapr.ps1 -ApplicationName <short-name>`

## The main functions in the script
1. Deploy infrastructure with Bicep
    * AKS
    * ACR

2. Use `az acr build` to build and push images to the ACR

3. Download AKS credentials

4. Install Dapr with Helm in AKS

5. Install Redis with Helm in AKS

6. Install our components with Helm in AKS
