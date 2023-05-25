# Build Workflow Application

In industrial environments integration workflows and applications become more and more important.
Orchestration and integraton of applications or microservices can be applied easily on the same hosting platform for K8s clusters - local environment, VMs, on-premises or Cloud.
Latest announcements and previews like Arc-enabled Logic Apps or Logic Apps integration with dapr make development life even easier.
Here you can create low-code workflows or ETL processes by using built-in connectors or even by calling own APIs and workloads to extend that feature set.
If low-code is not sufficient and there is a need to run high-compute load for workflows, dapr workflows offer a good fit solution and seemless integration.

## Comparison of Workflow Engines

### Features

| | Arc-enabled Logic Apps | [Deprecated] Dapr Logic Apps | Dapr Workflow | Conductor | Apache Airflow |
| --- | --- | --- | --- | --- | --- |
| Low-code | x | x | SDK | x | Python scripts |
| Connectors | x | x | - | x | webhooks, custom connectors |
| High compute | not natively, can call external APIs | not natively, can call external APIs | C# SDKS and implementation can run high compute workload|

### Arc-enabled Logic Apps

With Azure Arc-enabled Logic Apps, you can develop and run single-tenant based logic apps anywhere that Kubernetes can run. For example, you can run your logic app workflows on Azure, Azure Kubernetes Service, on premises, and even other cloud providers. This offering provides a centralized single-pane-of-glass management platform through Azure Arc and the Azure portal for the following capabilities:

- use Azure Logic Apps as your integration platform.
- connect your workflows to all your services no matter where they're hosted.
- run your integration solutions directly alongside your services.
- create and edit workflows using Visual Studio Code.
- deploy using your choice of pipelines for DevOps.
- control your infrastructure and resources in Azure, non-Azure, multiple clouds, on premises, and edge environments.
- requires [App Service Kubernetes environment](https://learn.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash#install-the-app-service-extension)

### [Deprecated] Dapr Logic Apps Integration

[Dapr´s Logic Apps integration initiative](https://docs.dapr.io/developing-applications/integrations/azure/workflows/) came up with a SDK that supported executing JSON-based WDL files (created manually, with Visual Studio Code extension or with Logic Apps Designer in Azure Portal) to start the workflows.

It is available in a preview release but not maintained furthermore and deprecated.

### Dapr Workflow

#### Overview

Dapr Workflow is one of the [dapr building blocks](https://docs.dapr.io/concepts/building-blocks-concept/) and can be used to orchestrate workflows.
It enables you to create long-running, fault-tolerant and stateful processes and applications implemented in any language of your choice.
State managegement is provided by the sidecar and the configured state store, e.g. Redis, which can be used for aynchronous flows like delayed approval processes.
Single activities/steps or started and orchestrated by a context so that you can chain and combine several activities with different subjects and tasks.
Due to its seamless integration with dapr components, e.g. PubSub integration and subscription to a topic, it can be used as a trigger and entry point to a workflow with custom implementation, full sdk support and publish event support to another PubSub topic.

#### When to use Dapr Workflow

- requirement for huge compute workloads and custom implementations
- integration into existing dapr ecosystem
- client implementations in different programming languages required or development team don´t want to tied to a specific programming language ([Dapr Client Sdk´s](https://docs.dapr.io/developing-applications/sdks/#sdk-languages)).

#### Existing bug

[GitHub issue](https://github.com/dapr/dapr/issues/2765)

### Apache Airflow

#### Overview

Apache Airflow is an open-source platform for developing, scheduling, and monitoring batch-oriented workflows. Airflow’s extensible Python framework enables you to build workflows connecting with virtually any technology. A web interface helps manage the state of your workflows. Airflow is deployable in many ways, varying from a single process on your laptop to a distributed setup to support even the biggest workflows. It aggregates single tasks, callec operators, into DAGs (directed acyclic graphs) that are implemented and executed in Python on a scheduled or event-triggered way.

#### When to use Apache Airflow

- Python is programming language of your choice
- due to different hosting options it is a good fit for quick spin-up experience and bootstrapping, in particular for dev environments
- integration of existing Apache Airflows workflows with [Azure Data Factory Managed Airflow](https://learn.microsoft.com/en-us/azure/data-factory/concept-managed-airflow)

### Conductor

#### Overview

Conductor was actually built to help Netflix orchestrate microservice based processes and then published as a side-product for the open-source community.

Conductor enables you to build workflows using DAG (directed acyclic graphs) based workflow definitions that can be designed by an editor tool representing the flow as a graph or by defining the json via WDL (workflow definition language).
In opposite to Arc-enabled Logic Apps for instance it doesn´t provide a bunch of predefined connectors, they are quite limited and http calls are an essential piece and used to make calls to microservices for orchestration.
Additionally, Conductor DAGs fire events and respective event handlers provide to functionality to react on events by external actions
Conductor comes with an API providing all the endpoints you need to operate workflows. Besides, it is very easy to integrate in your own ecosystem and implementation because SDKs are available in various programming languages that also allow you to author workflows code-based.

#### Orkes

[Orkes](https://orkes.io/) is a commercial vendor that offers a cloud hosted version of Conductor requiring minimal operational investment to get started.
Orkes provides a strong set of APIs to execute CRUD operations for workflows. It also provides a beautified designer to create them via low-code experience.

#### When to use Conductor

- requirement for a rich selection of SDKs for different programming languages
- need for a UI designer to define workflows and get a graph representation of the execution plan
- pure orchestration for microservices
