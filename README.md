# distributed-az-edge-framework
This repo is developed to enable developers to build edge solutions on any compute infrastructure but in a scalable and resilient manner.

Key principles on which this framework is builts are:

1. SDKs are independent of compute layer they run on e.g. K8s, Bare-metal.
2. SDKs make use of provider model to allow swapping of external resources e.g. message stacks like MQTT broker.
3. SDKs are not dependent on IoT Edge runtime.
4. SDKs are not dependent on any container ecosystem, they can be hosted in container if required by infrastructure or packaging requirements.
5. SDKs are designed to make use of Azure IoT Hub and related services out of the box.
