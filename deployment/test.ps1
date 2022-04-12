$proxyConfig = [PSCustomObject]@{
      ProxyIp = "10.0.0.1"
      ProxyPort = "8080"
    }

$ip = $proxyConfig.ProxyIp

write-Host "IP: $ip"
