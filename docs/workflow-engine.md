# Build Workflow Application

In industrial environments integration workflows and applications become more and more important.
Orchestration and integraton of applications can be applied easily on the same hosting platform for K8s clusters - local environment, VMs, on-premises or Cloud.
Latest announcements and previews like Arc-enabled Logic Apps or Logic Apps integration with dapr make development life even easier.
Here you can create low-code workflows or ETL processes by using built-in connectors or even by calling own APIs and workloads to extend that feature set.
If low-code is not sufficient and there is a need to run high-compute load for workflows, dapr workflows offer a good fit solution and seemless integration.

## Comparison of Workflow Engines

### Features

| | Arc-enabled Logic Apps | [Deprecated] Dapr Logic Apps | Dapr Workflow | Conductor |
| --- | --- | --- | --- | --- |
| Low-code | x | x | c# SDK | x |
| Connectors | x | x | - | x |
| High compute | not natively, can call external APIs | not natively, can call external APIs | C# SDKS and implementation can run high compute workload|

### Arc-enabled Logic Apps

- requires [App Service Kubernetes environment](https://learn.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash#install-the-app-service-extension)

### [Deprecated] Dapr Logic Apps Integration

- high code overhead for bootstrap
- 

### Dapr Workflow

- features orchestration of single activities by a context
- seamless integration with dapr components, e.g. PubSub integration and subscription to a topic can be used as a trigger and entry point to a workflow with custom implementation, full sdk support and publish support to PubSub
