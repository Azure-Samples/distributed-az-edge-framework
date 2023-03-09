# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [Parameter(mandatory=$true)]
    [String]
    $AksClusterName,

    [Parameter(mandatory=$true)]
    [string]
    $AksClusterResourceGroupName,

    [Parameter(mandatory=$false)]
    [bool]
    $DeployDapr = $true,

    [Parameter(mandatory=$false)]
    [PSCustomObject]
    $MosquittoParentConfig = $null
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name .\modules\text-utils.psm1

Write-Title("Start Deploying Core Platform")
$startTime = Get-Date
$tempCertsFolder = "./temp/mosquittocerts"

# ----- Get AKS Cluster Credentials
az aks get-credentials --admin --name $AksClusterName --resource-group $AksClusterResourceGroupName --overwrite-existing

# ----- Dapr
if($DeployDapr){
    Write-Title("Install Dapr")
    helm repo add dapr https://dapr.github.io/helm-charts/
    helm repo update
    helm upgrade --install dapr dapr/dapr `
        --version=1.10 `
        --namespace edge-core `
        --create-namespace `
        --wait
}

# ----- Mosquitto

# TODO optimize this by leveraging Key Vault for storing certs and keys
function GenerateCerts ([string] $AksClusterName){
        
    $SUBJECT_CA="/C=BE/ST=BRA/L=Brussels/O=DistributedEdgeCA/OU=CA/CN=camosquitto"
    $SUBJECT_SERVER="/C=BE/ST=BR/L=Brussels/O=DistributedEdgeServer/OU=Server/CN=$AksClusterName"
    $SUBJECT_CLIENT="/C=BE/ST=BR/L=Brussels/O=DistributedEdgeClient/OU=Client/CN=client$AksClusterName"
    $SUBJECT_BRIDGE_CLIENT="/C=BE/ST=BRA/L=Brussels/O=DistributedEdgeBridge/OU=Client/CN=Bridge$AksClusterName"
    $RootFolder = "./temp/$AksClusterName"
    $RootFolder = $tempCertsFolder

    If(!(Test-Path -PathType container -Path $RootFolder))
    {
        New-Item -ItemType Directory -Path $RootFolder
    }

    # Generate CA only if not yet found
    If(!(Test-Path "$RootFolder/ca.key" -PathType leaf))
    {
        openssl req -x509 -nodes -sha256 -newkey rsa:2048 -subj "$SUBJECT_CA"  -days 600 -keyout $RootFolder/ca.key -out $RootFolder/ca.crt
    }
   
    # Generate Server cert and key
    openssl req -nodes -sha256 -new -subj "$SUBJECT_SERVER" -keyout $RootFolder/$AksClusterName.key -out $RootFolder/$AksClusterName.csr

    openssl x509 -req -sha256 -in $RootFolder/$AksClusterName.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/$AksClusterName.crt -days 365
    
    openssl req -new -nodes -sha256 -subj "$SUBJECT_CLIENT" -out $RootFolder/client$AksClusterName.csr -keyout $RootFolder/client$AksClusterName.key 
    openssl x509 -req -sha256 -in $RootFolder/client$AksClusterName.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/client$AksClusterName.crt -days 365
    openssl req -new -nodes -sha256 -subj "$SUBJECT_BRIDGE_CLIENT" -out $RootFolder/bridge$AksClusterName.csr -keyout $RootFolder/bridge$AksClusterName.key 
    openssl x509 -req -sha256 -in $RootFolder/bridge$AksClusterName.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/bridge$AksClusterName.crt -days 365
}

GenerateCerts($AksClusterName)

# $MosquittoParentConfig = [PSCustomObject]@{
#     ParentAksClusterName = "aks-mosq39L4"
#     MosquittoIp = "172.16.0.8"
#     Port = "8883"
#   }

if ($null -eq $MosquittoParentConfig){

    Write-Title("Install Mosquitto without bridge to parent")
    #  use default mosquitto deployment
    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --set-file certs.ca.crt="$tempCertsFolder/ca.crt" `
    --set-file certs.server.crt="$tempCertsFolder/$AksClusterName.crt" `
    --set-file certs.server.key="$tempCertsFolder/$AksClusterName.key" `
    --create-namespace `
    --wait
}
else {

    # Temporary deploy to namespace l4
    # Write-Title("Install Mosquitto l4 with bridge to parent")
    # helm install mosquittol4 ./helm/mosquitto `
    # --namespace l4 `
    
    # --set-file certs.ca.crt="./temp/$AksClusterName/ca.crt" `
    # --set-file certs.server.crt="./temp/$AksClusterName/serverl4.crt" `
    # --set-file certs.server.key="./temp/$AksClusterName/serverl4.key" `
    # --create-namespace `
    # --wait

    Write-Title("Install Mosquitto with bridge to parent")

    # $parentCluster = $MosquittoParentConfig.ParentAksClusterName # todo review if still needed
    $mosquittoParentIp = $MosquittoParentConfig.MosquittoIp

    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --set-string bridge.enabled="true" `
    --set-string bridge.connectionName="$AksClusterName-parent" `
    --set-string bridge.address="$mosquittoParentIp" `
    --set-file certs.ca.crt="$tempCertsFolder/ca.crt" `
    --set-file certs.server.crt="$tempCertsFolder/$AksClusterName.crt" `
    --set-file certs.server.key="$tempCertsFolder/$AksClusterName.key" `
    --set-file certs.bridgeca.crt="$tempCertsFolder/ca.crt" `
    --create-namespace `
    --wait
    
}

# Get Mosquitto IP and Ports from deployment
$mosquittoSvc = kubectl get service mosquitto -n edge-core -o json | ConvertFrom-Json
$mosquittoIp = $mosquittoSvc.status.loadBalancer.ingress.ip
$mosquittoPort = $mosquittoSvc.spec.ports.port

$mosquittoConfig = [PSCustomObject]@{
    ParentAksClusterName = $AksClusterName # todo review if still needed
    MosquittoIp = $mosquittoIp
    Port = $mosquittoPort
  }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core platform: $runningTime")

return $mosquittoConfig
