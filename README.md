# Distributed Azure IoT Edge Workload Accelerator for K8s

This repo is developed to enable developers to build edge solutions on K8s in a scalable and resilient manner. It makes use of IoT Hub client SDKs to allow integration with IoT Hub for various features like device/module twin updates, direct methods and D2C/C2D messages. Equally, it allows you do develop edge modules without integration with IoT Hub, in which case you can manage module configuration out of IoT Hub context.

The accelerator makes use of Distributed Application Runtime ([Dapr](https://dapr.io/)) building blocks to enable cross-cutting non functional features which we are common in edge scenarios, some of those are mentioned below:

1. Messaging with pub-sub functionality using standard [CloudEvents](https://cloudevents.io/).
2. [Circuit-breaker](https://docs.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker) for inter-service communication and external service endpoints.
3. Service invocation using [gRPC](https://grpc.io/) or Http RESTful mechanism using mTLS or [SPIFFE](https://spiffe.io/docs/latest/spiffe-about/overview/) for secure communication.
4. Configuration and secret management.
5. Observability using OpenTelemetry (if required).

![alt text](architecture/hld.png "Edge on K8s")

Each pod contains two containers:

1. A custom code container which leverages IoT Hub Device SDKs (optionally) to integrate with IoT Hub.
2. A Dapr sidecar container which works as proxy to Dapr services and ecosystem.

Apart from the above arrangement, there is a system pod which gets deployed as well, this system pod is called IoT Hub Integration Module. The job of this pod is to route messages from pub-sub layer to IoT Hub using IoT Hub client SDKs.

## Deployment Steps

### Prerequisites

    1. Kubectl client, configured to a K8s cluster.
    2. Helm client

### Steps

1. Deploy Dapr on K8s cluster if not already deployed, please refer to the guidance [here](https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-deploy/#install-with-helm-advanced).
2. Deploy Redis on K8s cluster if not already deployed:

    ```
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    helm install redis bitnami/redis
    ```

3. Deploy the accelerator via Helm as below:

    ```
   helm repo add aziotaccl 'https://https://raw.github.com/suneetnangia/distributed-az-edge-framework/tree/main/deployment/helm/'
   helm repo update
   helm install demo  aziotaccl/iot-edge-accelerator --set iothubIntegrationModuleDevicePrimaryKey="<IoTHub Device Connection String>",simulatedTemperatureSensorFeedIntervalInMilliseconds=3000
    ```

## Outstanding (Work in Progress)

### Performance

1. Evaluate gRPC instead of Http for inter-module communication performance.
2. Impact of making use of CloudEvents.
3. Performance test accelerator components e.g. Dapr components as well as custom ones.

### Management Plane

1. Arc based remote management.
2. Guidance on how to manage edge workloads in nested/ISA 95 scenarios.

### Others

1. Develop scalable/heavy (large size e.g. pn.json for OPCUA) module configuration and its management plane.
2. Message routing and service composition on edge.
3. Device Id used for IoT Hub integration module prevents sharding of data at IoT Hub Event Hub backend.
4. Develop multi ML model execution engine/design.

### Stretch

1. Develop capability to run Web Assembly based modules.

## Disclaimer

This is still in development, you are free to use this to guide your thinking to develop something similar for your own solution. Equally, we would welcome any contribution you could make to progress this work.
