# Distributed Azure IoT Edge Workload Accelerator for K8s

This repo is developed to enable developers to build edge solutions on K8s in a scalable and resilient manner. It makes use of IoT Hub client SDKs to allow integration with IoT Hub for various features like device/module twin updates, direct methods and C2D messages. Equally, it allows you do develop edge modules without integration with IoT Hub, in which case you can manage module configuration out of IoT Hub context.

The accelerator makes use of Distributed Application Runtime ([Dapr](https://dapr.io/)) building blocks to enable cross-cutting non functional features which we are common in edge scenaros, some of those are mentioned below:

1. Messaging with pub-sub functionality using standard CloudEvents.
2. Circuit-breaker for inter-service communication and external endpoints.
3. Service invocation using gRPC or Http RESTful mechanism using mTLS or SPIFFE for secure communication.
4. Configuration and secret management.
5. Observability using OpenTelemetry (if required).

![alt text](architecture/hld.png "Edge on K8s")

Each pod contains two containers:

1. A Dapr sidecar container which works as proxy to Dapr services and ecosystem.
2. A custom code which leverages IoT Hub Device SDKs (optionally) to integrate with IoT Hub.

Apart from the above arrangement, there is a system pod which gets deployed as well, this system pod is called IoT Hub Custom Module. The job of this pod is to route messages from pub-sub layer to IoT Hub using IoT Hub client SDKs.

## Deployment Steps
[Add solution deployment steps here]

## TODOs

1. Performance test accelerator components e.g. Dapr components as well as custom ones.
2. Develop scalable module configuration and its management plane.
3. Develop multi ML model execution engine.
4. Develop capability to run Web Assembly based modules.
5. Arc based remote management.

## Disclaimer
This is still in development, you are free to use this to guide your thinking to develop something similar for your own solution. Equally, we would welcome any contribution you could make to progress this work.