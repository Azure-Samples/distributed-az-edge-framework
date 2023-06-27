# MQTT Broker for Data Communication Between Workloads and Between Network Layers

A commonly used solution to exchange messages in a publish/subscribe mechanism is to leverage an MQTT Broker. There are several broker solutions available, most of them with some level of an open-source license. For this project evaluated MQTT broker for communication between workloads on the Kubernetes cluster. Additionally, because of Purdue network separation, we needed a mechanism to exchange MQTT messages securely and reliably to the network layer above in the network topology. Communication between layers is only allowed in outbound fashion: from child layer out to parent layer. Parent network only allows for specific communication over MQTT port.

MQTT is a popular standard, and Dapr, which is already used as a distributed application framework in this sample, also supports MQTT out of the box through the [PubSub MQTT component](https://docs.dapr.io/reference/components-reference/supported-pubsub/setup-mqtt/).

Due to the Purdue/ISA 95 networking topology requirements, MQTT bridging is also required. The concept of bridging between MQTT brokers allows for using out of the box features in many MQTT brokers. Bridging is not part of the MQTT standard but widely implemented and a defacto standard.
This feature allows for passing the responsibility for transferring data in the data plane to the broker solution, without workloads needing to know about data flows between networking layers.
When implementing bridging between brokers, the topic tree of a remote broker becomes part of the topic tree on the local broker. The bridge becomes a client to the MQTT broker on the layer above, which enables the client to publish and subscribe to topics.

Lastly, MQTT bridging in some of the brokers also enables persistence. This is especially useful in cases of (temporary) network loss.

> Note: at this stage MQTT broker (Kubernetes) cluster deployment is not evaluated or implemented, to simplify the sample. Several brokers have native Kubernetes support, while others like Mosquitto, rely on the bridging feature itself to setup a cluster of brokers on a single Kubernetes cluster.

## Open-Source MQTT Broker Comparison

| Name	| Bridging	| License	| Notes |
|------------|------------|-------------|------------|
| Mosquitto	| Yes	| EPL/EDL	| No native distributed K8S cluster support, clustering is typically achieved with bridging feature itself |
| HiveMQ Community	| No	| Apache v2	| HiveMQ does support bridging in Commercial licenses. Also OOB support for K8S in commercial |
| VerneMQ	| Yes	| Apache v2	| |
| RabbitMQ	| No	| MPL 1.1	| |
| JoramMQ	| Yes	| LGPL and Commercial	| | 

## Eclipse Mosquitto Broker

In this sample we have chosen to do an implementation with Mosquitto. Is has many advantages, one being the open-source licensing of the bridging feature. Customers looking at commercially supported options might want to further evaluate solutions like HiveMQ Professional or Enterprise or others.
