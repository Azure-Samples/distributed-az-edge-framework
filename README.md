# Distributed Azure IoT Edge Workload Accelerator for K8s

This repo is developed to enable developers to build edge solutions on K8s in a scalable and resilient manner. It makes use of IoT Hub client SDKs to allow integration with IoT Hub for various features like device/module twin updates, direct methods and C2D messages.

The accelerator makes use of Distributed Application Runtime ([Dapr](https://dapr.io/)) building blocks to enable the following core IoT edge features:

1. Messaging with pub-sub functionality using standard CloudEvents.
2. Circuit-breaker for inter-service communication.
3. Service invocation using gRPC or Http RESTful mechanism using mTLS or SPIFFE.
4. Secret management.
5. Observability using OpenTelemetry.

![alt text](architecture/hld.png "Edge on K8s")

Each pod contains two containers:

1. A Dapr sidecar container which works as proxy to Dapr services and ecosystem.
2. A custom code which leverages IoT Hub Device SDKs to integrate with IoT Hub.

Apart from the above arrangement, there is a system pod which gets deployed as well, this system pod is called IoT Edge Module. The job of this pod is to route messages from pub-sub layer to IoT Hub using IoT Hub client SDKs.

## Deployment Steps

## Next Steps

1. Develop scalable module configuration and its management plane.
2. Develop multi ML model execution engine.
3. Develop capability to run Web Assembly based modules.
4. Arc based remote management.

## Disclaimer