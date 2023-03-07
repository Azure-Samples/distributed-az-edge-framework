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

# Mosquitto =============================================
function GenerateCerts ([string] $AksClusterName){
        
    $SUBJECT_CA="/C=BE/S=Belgium/L=Brussels/O=DistributedEdge/OU=CA/CN=$AksClusterName"
    $SUBJECT_SERVER="/C=BE/S=Belgium/L=Brussels/O=DistributedEdge/OU=Server/CN=$AksClusterName"
    $SUBJECT_CLIENT="/C=BE/S=Belgium/L=Brussels/O=DistributedEdge/OU=Client/CN=$AksClusterName"
    $SUBJECT_BRIDGE_CLIENT="/C=BE/S=Belgium/L=Brussels/O=DistributedEdge/OU=Client/CN=Bridge$AksClusterName"
    $RootFolder = "./temp/$AksClusterName"
    If(!(Test-Path -PathType container $RootFolder))
    {
        New-Item -ItemType Directory -Path $RootFolder
    }
    # Generate CA
    openssl req -x509 -nodes -sha256 -newkey rsa:2048 -subj "$SUBJECT_CA"  -days 365 -keyout $RootFolder/ca.key -out $RootFolder/ca.crt
    # Generate Server cert and key
    openssl req -nodes -sha256 -new -subj "$SUBJECT_SERVER" -keyout $RootFolder/server.key -out $RootFolder/server.csr
    openssl x509 -req -sha256 -in $RootFolder/server.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/server.crt -days 365
    
    openssl req -new -nodes -sha256 -subj "$SUBJECT_CLIENT" -out $RootFolder/client.csr -keyout $RootFolder/client.key 
    openssl x509 -req -sha256 -in $RootFolder/client.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/client.crt -days 365
    openssl req -new -nodes -sha256 -subj "$SUBJECT_BRIDGE_CLIENT" -out $RootFolder/bridgeclient.csr -keyout $RootFolder/bridgeclient.key 
    openssl x509 -req -sha256 -in $RootFolder/bridgeclient.csr -CA $RootFolder/ca.crt -CAkey $RootFolder/ca.key -CAcreateserial -out $RootFolder/bridgeclient.crt -days 365
}

GenerateCerts($AksClusterName)

if ($null -eq $MosquittoParentConfig){

    Write-Title("Install Mosquitto without bridge to parent")
    #  use default mosquitto deployment
    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --set-file certs.ca.crt="./temp/$AksClusterName/ca.crt" `
    --set-file certs.server.crt="./temp/$AksClusterName/server.crt" `
    --set-file certs.server.key="./temp/$AksClusterName/server.key" `
    --create-namespace `
    --wait
}
else {

    Write-Title("Install Mosquitto with bridge to parent")
    # If setting bridge from child to parent: create mosquitto.conf file with bridge config:
    $mosquittoConf = (Get-Content -Path ./configuration/mosquitto.conf.template -Raw)
    $mosquittoConf = $mosquittoConf.Replace('replace_with_connection_name', "$AksClusterName-parent").Replace('replace_with_parent_address', $MosquittoParentConfig.MosquittoIp)
    Set-Content -Path "./temp/$AksClusterName-mosquitto.conf" -Value $mosquittoConf

    $parentCluster = $MosquittoParentConfig.ParentAksClusterName;

    helm install mosquitto ./helm/mosquitto `
    --namespace edge-core `
    --set-file mosquittoConfig="./temp/$AksClusterName-mosquitto.conf" `
    --set-file certs.ca.crt="./temp/$AksClusterName/ca.crt" `
    --set-file certs.server.crt="./temp/$AksClusterName/server.crt" `
    --set-file certs.server.key="./temp/$AksClusterName/server.key" `
    --set-file certs.bridgeca.crt="./temp/$parentCluster/ca.crt" `
    --set-file certs.bridgeclient.crt="./temp/$parentCluster/bridgeclient.crt" `
    --set-file certs.bridgeclient.key="./temp/$parentCluster/bridgeclient.key" `
    --create-namespace `
    --wait
}

# Get Mosquitto IP and Ports from deployment
$mosquittoSvc = kubectl get service mosquitto -n edge-core -o json | ConvertFrom-Json
$mosquittoIp = $mosquittoSvc.status.loadBalancer.ingress.ip
$mosquittoPort = $mosquittoSvc.spec.ports.port

$mosquittoConfig = [PSCustomObject]@{
    ParentAksClusterName = $AksClusterName
    MosquittoIp = $mosquittoIp
    Port = $mosquittoPort
  }

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core platform: $runningTime")

return $mosquittoConfig
