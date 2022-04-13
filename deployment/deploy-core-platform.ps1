# ------------------------------------------------------------
#  Copyright (c) Microsoft Corporation.  All rights reserved.
#  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
# ------------------------------------------------------------

Param(
    [string]
    [Parameter(mandatory=$true)]
    $ApplicationName,
    [string]
    [Parameter(mandatory=$true)]
    $AksCluster1Name,
    [string]
    [Parameter(mandatory=$true)]
    $AksCluster2Name,
    [string]
    [Parameter(mandatory=$true)]
    $ResourceGroupName,
    [string]
    $Location = 'westeurope'
)

Function Write-Title ($text) {
    $width = (Get-Host).UI.RawUI.WindowSize.Width
    $title = ""
    if($text.length -ne 0)
    {
        $title = "=[ " + $text + " ]="
    }

    Write-Host $title.PadRight($width, "=") -ForegroundColor green
}

Write-Title("Start Deploying Core Platform")
$startTime = Get-Date

# ----- Get Cluster Credentials #1
Write-Title("Get AKS #1 Credentials")
az aks get-credentials `
    --admin `
    --name $AksCluster1Name `
    --resource-group $ResourceGroupName `
    --overwrite-existing

#----- Proxy
Write-Title("Install Proxy")
helm install squid-proxy ./helm/squid-proxy `
    --namespace edge-proxy `
    --create-namespace `
    --wait

#----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace edge-core `
    --create-namespace `
    --wait

#----- Redis
Write-Title("Install Redis")
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --wait `
--namespace edge-core `
--create-namespace `
--wait

# ----- Get AKS #1 Proxy IP Address
Write-Title("Get AKS #1 Proxy IP Address")
$proxy1 = kubectl get service squid-proxy-module -n edge-proxy -o json | ConvertFrom-Json
$proxy1Ip = $proxy1.status.loadBalancer.ingress.ip
$proxy1Port = $proxy1.spec.ports.port
$proxy1Url = "http://" + $proxy1Ip + ":" + $proxy1Port

# ----- Enroll AKS #1 with Arc
Write-Title("Enroll AKS #1 with Arc")
az connectedk8s connect --name $AksCluster1Name --resource-group $ResourceGroupName --location $Location --proxy-http $proxy1Url --proxy-https $proxy1Url --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
az connectedk8s enable-features -n $AksCluster1Name -g $ResourceGroupName --features cluster-connect

# ------ AKS #2 -------------

# ----- Get Cluster Credentials #2
Write-Title("Get AKS #2 Credentials")
az aks get-credentials --admin --name $AksCluster2Name --resource-group $ResourceGroupName --overwrite-existing

#----- Proxy
Write-Title("Install Proxy")
helm install squid-proxy ./helm/squid-proxy `
    --set-string parent.ipAddress="$proxy1Ip" `
    --set-string parent.port="3128" `
    --namespace edge-proxy `
    --create-namespace `
    --wait
    
#----- Dapr
Write-Title("Install Dapr")
helm repo add dapr https://dapr.github.io/helm-charts/
helm repo update
helm upgrade --install dapr dapr/dapr `
    --version=1.5 `
    --namespace edge-core `
    --create-namespace `
    --wait

#----- Redis
Write-Title("Install Redis")
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis --wait `
--namespace edge-core `
--create-namespace `
--wait


# ----- Get AKS #2 Proxy IP Address
Write-Title("Get AKS #2 Proxy IP Address")
$proxy2 = kubectl get service squid-proxy-module -n edge-proxy -o json | ConvertFrom-Json
$proxy2Ip = $proxy2.status.loadBalancer.ingress.ip
$proxy2Port = $proxy2.spec.ports.port
$proxy2Url = "http://" + $proxy2Ip + ":" + $proxy2Port

# ----- Enroll AKS #2 with Arc
Write-Title("Enroll AKS #2 with Arc")
az connectedk8s connect --name $AksCluster2Name --resource-group $ResourceGroupName --location $Location --proxy-http $proxy2Url --proxy-https $proxy2Url --proxy-skip-range 10.0.0.0/16,kubernetes.default.svc,.svc.cluster.local,.svc
az connectedk8s enable-features -n $AksCluster2Name -g $ResourceGroupName --features cluster-connect


$runningTime = New-TimeSpan -Start $startTime
Write-Host "Running time:" $runningTime.ToString() -ForegroundColor Yellow