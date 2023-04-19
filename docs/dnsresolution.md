# DNS Entries and Resolution between MQTT brokers

Kubernetes offers native DNS services for managing Services and Pods, which allows for easy connectivity using a DNS name instead of an IP address. However, when connecting between K8S clusters that do not share DNS, an external DNS solution is needed.

One option is to use Kubernetes' [ExternalDNS](https://github.com/kubernetes-sigs/external-dns), which makes resources like services and ingresses discoverable via public and private DNS servers. ExternalDNS integrates with various DNS providers such as AzureDNS and [Azure Private DNS](https://kubernetes-sigs.github.io/external-dns/v0.13.3/tutorials/azure-private-dns/), making it a popular choice for cloud-based solutions.

For this particular sample, where we needed DNS for Mosquitto broker, the aim was to represent a layered network approach where the bottom layer does not have access to a shared resource like a DNS server. As such, a more internal and manual solution was chosen: leveraging [CoreDNS](https://coredns.io/) with built-in support in Kubernetes and creating a manual headless Service in each cluster with an Endpoint pointing to the Mosquitto load balancer of the layer above.

While this approach does work nicely and is simple to implement in an on-premises environment, it does require manual reconfiguration in case the IP Address of the above load balancer changes.

In summary, there are several options discussed for managing DNS and discoverability in Kubernetes:

1. Kubernetes CoreDNS with a headless service and endpoint resource (implemented in this sample)
2. Kubernetes CoreDNS ith the options to use plugins architecture to extend resolution of DNS, like hosts or custom forward server. See the documentation for cutomizing CoreDNS on AKS: https://learn.microsoft.com/en-us/azure/aks/coredns-custom
3. Kubernetes ExternalDNS with Azure Private DNS Zone(s) and Vnet access
4. Kubernetes ExternalDNS with another choice of DNS server in the enterprise, depending on network setup and potential restrictions.

