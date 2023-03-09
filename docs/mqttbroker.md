# MQTT Broker for data communication between workloads, and between network layers

A commonly used solution to exchange messages in a publish/subscribe mechanism is to leverage an MQTT Broker. There are several brokers available, most with some sort of an open source license. For this project we are looking to utilize MQTT broker for communication between workloads on the Kubernetes cluster. Additionally, because of ISA 95 network separation, we need a mechanism to securely and reliably broker this information further to the level above/below in the network topology.

MQTT is a popular standard, and DAPR, which is already used as a distributed application framework here, also supports MQTT out of the box through the PubSub MQTT component.

Due to the ISA 95 networking topology requirements, MQTT bridging is also required. The concept of bridging between MQTT brokers allows for using out of the box features and not having to manually develop workloads that will pass the data from one networking layer to the other. With bridging between brokers, the topic tree of a remote broker becomes part of the topic tree on the local broker.

Lastly, MQTT bridging in some of the brokers also enables persistence. This is especially useful in cases of (temporary) network loss.

> Note: at this stage MQTT broker cluster deployment is not evaluated, to simplify the sample. Several brokers have native Kubernetes support, while others, like Mosquitto rely on the same bridging feature to setup a cluster of brokers on a single Kubernetes cluster.

## Open source broker comparisons

| Name	| Bridging	| License	| Notes |
|------------|------------|-------------|------------|
| Mosquitto	| Yes	| EPL/EDL	| No native distributed K8S cluster support, clustering is typically achieved with bridging feature itself |
| HiveMQ Community	| No	| Apache v2	| HiveMQ does support bridging in Commercial licenses. Also OOB support for K8S in commercial |
| VerneMQ	| Yes	| Apache v2	| |
| RabbitMQ	| No	| MPL 1.1	| |
| JoramMQ	| Yes	| LGPL and Commercial	| | 
| | | | |

## Mosquitto broker

In this sample we have chosen to do an implmentation with Mosquitto. Is has many advantages, one being the open source licensing of the bridging feature. Customers looking at commercially supported options might want to further evaluate solutions like HiveMQ Professional or Enterprise.
