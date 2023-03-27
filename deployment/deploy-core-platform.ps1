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
    $DeployDapr = $false,

    [Parameter(mandatory=$false)]
    [PSCustomObject]
    $MosquittoParentConfig = $null,

    [Parameter(mandatory=$false)]
    [bool]
    $ArcEnabled = $true
)

# Uncomment this if you are testing this script without deploy-az-demo-bootstrapper.ps1
# Import-Module -Name ./modules/text-utils.psm1

# Import module for interacting with ps processes
Import-Module -Name ./modules/process-utils.psm1

Write-Title("Start Deploying Core Platform")
$startTime = Get-Date
$tempCertsFolder = "./temp/mosquittocerts"
$kubeConfigFile = "./temp/$AksClusterName"

function CleanHostname([string] $Hostname){
    
    $pattern = '[^a-zA-Z0-9]'
    $result = $Hostname -replace $pattern, '' 
    $result = $result.ToLower()

    return $result
}

# ----- Get AKS Cluster Credentials into kube context
if($ArcEnabled){
    # Through Arc cluster connect option
    $tokenB64 = Get-Content -Path "./temp/tokens/$AksClusterName.txt"
    $token = ([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($tokenB64))))
    # Start Arc cluster connect in separate terminal process
    Write-Host "Starting terminal Arc proxy"
    Start-ProcessInNewTerminalPW -ProcessArgs "az connectedk8s proxy -n $AksClusterName -g $AksClusterResourceGroupName --file $kubeConfigFile --token $token" -WindowTitle "ArcProxy$AksClusterName"
    
    Write-Host "Sleep for a few seconds to initialize proxy..."
    Start-Sleep -s 10

}
else {
    # in developer environment, no Arc
    az aks get-credentials --admin --name $AksClusterName --resource-group $AksClusterResourceGroupName --overwrite-existing --file $kubeConfigFile
}


# ----- Dapr
if($DeployDapr){
    Write-Title("Install Dapr")
    helm repo add dapr https://dapr.github.io/helm-charts/
    helm repo update
    helm upgrade --install dapr dapr/dapr `
        --version=1.10 `
        --namespace edge-core `
        --create-namespace `
        --wait `
        --kubeconfig $kubeConfigFile
}

# ----- Mosquitto

helm repo add azedgefx https://azure-samples.github.io/distributed-az-edge-framework --force-update
helm repo update

# TODO optimize this by leveraging Key Vault for storing certs and keys
function GenerateCerts ([string] $AksClusterName){
    
    $aksClusterNameCleaned = CleanHostname($AksClusterName)
    $RootFolder = $tempCertsFolder
    $currentServiceCN = "${aksClusterNameCleaned}.edge-core.svc.cluster.local"
    $SUBJECT_CA="/C=BE/ST=BRA/L=Brussels/O=DistributedEdgeCA/OU=CA/CN=camosquitto"
    $SUBJECT_SERVER="/C=BE/ST=BR/L=Brussels/O=DistributedEdgeServer/OU=Server/CN=$currentServiceCN"
    $SUBJECT_CLIENT="/C=BE/ST=BR/L=Brussels/O=DistributedEdgeClient/OU=Client/CN=client$AksClusterName"
    $SUBJECT_BRIDGE_CLIENT="/C=BE/ST=BRA/L=Brussels/O=DistributedEdgeBridge/OU=Client/CN=bridge$AksClusterName"
    
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

# --- Generate certs and save to disk
GenerateCerts($AksClusterName)

if ($null -eq $MosquittoParentConfig){

    Write-Title("Install Mosquitto without bridge to parent")
    #  use default mosquitto deployment
    helm install mosquitto azedgefx/mosquitto `
    --namespace edge-core `
    --set-file certs.ca.crt="$tempCertsFolder/ca.crt" `
    --set-file certs.server.crt="$tempCertsFolder/$AksClusterName.crt" `
    --set-file certs.server.key="$tempCertsFolder/$AksClusterName.key" `
    --create-namespace `
    --kubeconfig $kubeConfigFile `
    --wait

}
else {

    Write-Title("Install Mosquitto with bridge to parent")

    $parentCluster = CleanHostname($MosquittoParentConfig.ParentAksClusterName) 
    $mosquittoParentIp = $MosquittoParentConfig.MosquittoIp
    $parentHostname = "${parentCluster}.edge-core.svc.cluster.local"

    helm install mosquitto azedgefx/mosquitto `
    --namespace edge-core `
    --set-string bridge.enabled="true" `
    --set-string bridge.connectionName="$AksClusterName-parent" `
    --set-string bridge.remotename="$parentCluster" `
    --set-string bridge.ipaddress="$mosquittoParentIp" `
    --set-string bridge.hostname="$parentHostname" `
    --set-file certs.ca.crt="$tempCertsFolder/ca.crt" `
    --set-file certs.server.crt="$tempCertsFolder/$AksClusterName.crt" `
    --set-file certs.server.key="$tempCertsFolder/$AksClusterName.key" `
    --set-file certs.bridgeca.crt="$tempCertsFolder/ca.crt" `
    --create-namespace `
    --kubeconfig $kubeConfigFile `
    --wait
    
}

# Get Mosquitto IP and Ports from deployment to send to next layer (child)
$mosquittoSvc = kubectl get service mosquitto -n edge-core -o json --kubeconfig $kubeConfigFile | ConvertFrom-Json
$mosquittoIp = $mosquittoSvc.status.loadBalancer.ingress.ip
$mosquittoPort = $mosquittoSvc.spec.ports.port

$mosquittoConfig = [PSCustomObject]@{
    ParentAksClusterName = $AksClusterName
    MosquittoIp = $mosquittoIp
    Port = $mosquittoPort
  }

# If Arc connected, close the second process terminal before continuing
if($ArcEnabled){
    Write-Host "Closing terminal Arc proxy"
    Stop-ProcessInNewTerminal -WindowTitle "ArcProxy$AksClusterName"
}

$runningTime = New-TimeSpan -Start $startTime
Write-Title("Running time core platform: $runningTime")

return $mosquittoConfig
