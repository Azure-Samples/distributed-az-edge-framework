# Build Workflow Application

In industrial environments, the importance of integration workflows and applications cannot be overstated. These workflows and applications enable the seamless orchestration and integration of various applications or microservices, which is crucial for efficient operations. The beauty of it is that these workflows can be implemented easily on the same hosting platform for K8s clusters, regardless of whether it's a local environment, virtual machines (VMs), on-premises infrastructure, or the Cloud.

In recent times, there have been exciting developments and previews that have further enhanced the development experience in this field. For example, the introduction of Arc-enabled Logic Apps and the integration of Logic Apps with dapr have made life easier for developers. These advancements offer a range of benefits, including the ability to create low-code workflows or Extract, Transform, Load (ETL) processes effortlessly. With built-in connectors and the flexibility to call your own APIs and workloads, you can extend the feature set of these applications to suit your specific requirements.

While low-code workflows and integration options cover a wide range of scenarios, there are cases where higher computational capabilities are necessary. This is where dapr workflows shine. They provide a robust solution that seamlessly integrates with existing systems, allowing you to handle high-compute loads efficiently within your workflows. The integration is smooth and doesn't impose unnecessary constraints, ensuring a streamlined experience.

In summary, the integration of workflows and applications plays a vital role in industrial settings. The ability to orchestrate and integrate applications or microservices on the same hosting platform brings significant advantages. With the latest advancements like Arc-enabled Logic Apps and Logic Apps integration with dapr, development has become even more user-friendly. Whether you opt for low-code workflows with built-in connectors or leverage your own APIs and workloads, these tools offer the flexibility and scalability required in modern industrial environments. And if your workflows demand high-compute capabilities, dapr workflows provide an ideal solution with seamless integration.

## Comparison of Workflow Engines

### Features

| | Arc-enabled Logic Apps | [Deprecated] Dapr Logic Apps | Dapr Workflow | Conductor | Apache Airflow |
| --- | --- | --- | --- | --- | --- |
| Low-code | x | x | SDK | x | Python scripts |
| Connectors | x | x | - | x | webhooks, custom connectors |
| High compute | not natively, can call external APIs | not natively, can call external APIs | C# SDKS and implementation can run high compute workload|

### Arc-enabled Logic Apps

Azure Arc-enabled Logic Apps offer a powerful and versatile platform for developing and running logic apps in a single-tenant environment. What makes it truly remarkable is the flexibility it provides in terms of deployment options. You can run your logic app workflows not only on Azure or Azure Kubernetes Service but also on-premises infrastructure and even other cloud providers. This means you have the freedom to choose the hosting environment that best suits your needs and preferences.

The Azure Arc-enabled Logic Apps offering comes with a centralized management platform that provides a single-pane-of-glass experience through Azure Arc and the Azure portal. This platform offers a wide range of capabilities that simplify the integration process and enhance your workflow development. Here are some of the key features and benefits:

1. Integration Platform: Azure Logic Apps serves as the robust integration platform for your workflows. It enables seamless connectivity and communication between your logic apps and all your services, regardless of their hosting location.
2. Workflow Flexibility: With Azure Arc-enabled Logic Apps, you have the freedom to run your integration solutions directly alongside your services. This ensures close proximity and efficient collaboration between your workflows and the resources they interact with.
3. Development Experience: The platform provides a user-friendly development experience with support for creating and editing workflows using Visual Studio Code, a popular and powerful integrated development environment (IDE).
4. Deployment Options: You have the flexibility to deploy your logic apps using your preferred pipelines for DevOps. This allows you to leverage your existing deployment processes and infrastructure, streamlining the development lifecycle.
5. Cross-Environment Control: Azure Arc-enabled Logic Apps empowers you to have full control over your infrastructure and resources in various environments. Whether it's Azure, non-Azure environments, multiple clouds, on-premises setups, or edge environments, you can manage and govern your workflows seamlessly.
6. To utilize Azure Arc-enabled Logic Apps, you will need the App Service Kubernetes environment. The installation process for this environment can be found in the [App Service Kubernetes environment](https://learn.microsoft.com/en-us/azure/app-service/manage-create-arc-environment?tabs=bash#install-the-app-service-extension) documentation.

In essence, Azure Arc-enabled Logic Apps provide a versatile and centralized platform for developing and managing logic app workflows. With the ability to deploy them anywhere Kubernetes can run and enjoy a range of integration capabilities, you can build robust, scalable, and flexible workflows that seamlessly connect your services across various hosting environments.

### [Deprecated] Dapr Logic Apps Integration

[Dapr´s Logic Apps integration initiative](https://docs.dapr.io/developing-applications/integrations/azure/workflows/) introduced a software development kit (SDK) that revolutionized the execution of workflows using JSON-based Workflow Definition Language (WDL) files. These WDL files could be created manually, leveraging the Visual Studio Code extension, or utilizing the intuitive Logic Apps Designer in the Azure Portal. This innovative approach opened up new possibilities for starting workflows and enhanced the overall development experience.

However, it is important to note that the Logic Apps integration initiative with Dapr is currently only available as a preview release. Unfortunately, the initiative is no longer actively maintained and has been marked as deprecated. While it provided valuable functionality during its active development phase, the deprecation status indicates that there will be no further updates or improvements to this particular integration.

Despite its deprecation, it is worth acknowledging the significant contributions that the Logic Apps integration initiative made to the field of workflow execution. It showcased the power and flexibility of leveraging JSON-based WDL files and demonstrated the seamless integration between Dapr and Logic Apps. Developers who had the opportunity to explore and utilize this initiative gained valuable insights and experiences in leveraging Dapr's capabilities for workflow orchestration.

Moving forward, it is recommended to explore alternative solutions and keep an eye on any future developments in the realm of workflow integration. The technology landscape is constantly evolving, and new tools and frameworks may emerge to address similar challenges and offer enhanced functionality.

### Dapr Workflow

#### Overview

Dapr Workflow is a versatile and powerful [building block](https://docs.dapr.io/concepts/building-blocks-concept/) within the Dapr ecosystem that provides a robust framework for orchestrating workflows. It offers developers the ability to create long-running, fault-tolerant, and stateful processes and applications using the programming language of their choice.

The core strength of Dapr Workflow lies in its ability to handle state management efficiently. It utilizes a sidecar and a configured state store, such as Redis, to ensure seamless state management. This capability becomes particularly valuable in scenarios that involve asynchronous flows, such as delayed approval processes, where maintaining state and tracking progress is essential.

Dapr Workflow allows you to define and execute individual activities or steps within a broader context. These activities can be easily chained together, enabling you to combine multiple steps with different subjects and tasks effortlessly. This flexibility empowers you to build complex and intricate workflows that align with your specific business needs.

One of the standout features of Dapr Workflow is its seamless integration with other Dapr components. For example, it seamlessly integrates with Dapr's PubSub system, enabling it to serve as a trigger and entry point for workflows. This integration opens up a world of possibilities, allowing you to implement custom logic, leverage the comprehensive SDK support provided by Dapr, and even publish events to other PubSub topics.

By leveraging the capabilities of Dapr Workflow, developers can create resilient and scalable workflow solutions. Regardless of the programming language you prefer, Dapr Workflow provides a consistent and flexible foundation for building workflows that span across multiple activities and integrate seamlessly with other Dapr components. Its ability to handle state management, integrate with PubSub systems, and support custom implementations makes it an invaluable tool for orchestrating complex processes and applications.

#### When to use Dapr Workflow

- requirement for huge compute workloads and custom implementations
- integration into existing dapr ecosystem
- client implementations in different programming languages required or development team don´t want to tied to a specific programming language ([Dapr Client Sdk´s](https://docs.dapr.io/developing-applications/sdks/#sdk-languages)).

#### Existing bug

[GitHub issue](https://github.com/dapr/dapr/issues/2765)

### Apache Airflow

#### Overview

Apache Airflow is a robust and flexible open-source platform that empowers developers to develop, schedule, and monitor batch-oriented workflows. With its extensible Python framework, Airflow enables you to effortlessly build workflows that connect with a wide range of technologies and systems.

One of the key strengths of Apache Airflow is its intuitive web interface, which provides a centralized hub for managing the state and execution of your workflows. This interface allows you to easily monitor and track the progress of your tasks, ensuring transparency and control over your workflow processes.

The versatility of Apache Airflow is evident in its deployment options, which can be tailored to your specific needs. Whether you require a single process running on your local machine or a distributed setup to support large-scale workflows, Airflow provides the flexibility to accommodate your requirements. This scalability makes it an ideal choice for organizations of all sizes, from small teams to enterprise-level deployments.

At the heart of Apache Airflow's workflow management lies the concept of Directed Acyclic Graphs (DAGs). A DAG is a collection of individual tasks, known as operators, that are connected to form a workflow. These operators represent specific actions or computations and can be implemented in Python or extended with custom operators. By defining the dependencies and relationships between these tasks, you can create intricate workflows that execute in a scheduled or event-triggered manner.

Apache Airflow's Python-based execution model ensures that workflows are executed reliably and efficiently. Python's extensive ecosystem and libraries provide developers with a rich set of tools and capabilities to accomplish a wide range of tasks within their workflows. This, combined with Airflow's intuitive DAG representation, simplifies the process of building complex workflows and enables developers to leverage the full power of Python to meet their unique requirements.

In summary, Apache Airflow is a versatile and powerful platform that offers developers an open-source solution for building, scheduling, and monitoring batch-oriented workflows. With its extensible Python framework, user-friendly web interface, and support for scalable deployments, Airflow provides a comprehensive workflow management solution. By utilizing Directed Acyclic Graphs and Python-based operators, developers can create sophisticated workflows that integrate seamlessly with a variety of technologies, enabling them to automate and streamline their data processing pipelines with confidence.

#### When to use Apache Airflow

- Python is programming language of your choice
- due to different hosting options it is a good fit for quick spin-up experience and bootstrapping, in particular for dev environments
- integration of existing Apache Airflows workflows with [Azure Data Factory Managed Airflow](https://learn.microsoft.com/en-us/azure/data-factory/concept-managed-airflow)

### Conductor

#### Overview

Conductor, initially developed by Netflix to streamline the orchestration of microservice-based processes, has now been made available to the open-source community as a valuable tool for workflow management.

With Conductor, you have the ability to construct workflows using Directed Acyclic Graphs (DAGs) as the underlying structure. These workflows can be designed using an editor tool that visually represents the flow as a graph, or you can define them in JSON format using the Workflow Definition Language (WDL). This flexibility empowers you to tailor your workflows to meet specific requirements and preferences.

In contrast to solutions like Arc-enabled Logic Apps, Conductor does not provide an extensive range of pre-built connectors. Instead, it offers a more limited selection, with HTTP calls playing a vital role in making requests to microservices for orchestration. This approach gives you the freedom to integrate Conductor seamlessly into your existing microservice architecture, leveraging the specific APIs and services that best suit your needs.

One standout feature of Conductor is its support for event-driven architecture. Conductor DAGs can trigger events, and event handlers can be implemented to respond to these events with external actions. This capability enables you to build dynamic and responsive workflows that can adapt to changing conditions or external stimuli, enhancing the overall flexibility and agility of your application.

Conductor comes equipped with a comprehensive API that provides all the necessary endpoints for operating and managing workflows. This API-centric approach allows for easy integration within your ecosystem and implementation. Additionally, Conductor offers Software Development Kits (SDKs) in multiple programming languages, enabling you to author workflows in a code-based manner using the language of your choice.

In summary, Conductor is a powerful open-source workflow management solution that originated from Netflix's own microservice orchestration needs. Its support for Directed Acyclic Graphs (DAGs), event-driven architecture, flexible connectors, and comprehensive API make it an invaluable tool for building and managing intricate workflows. Whether you prefer a visual or code-based approach, Conductor's versatility and ease of integration make it an excellent choice for orchestrating microservices and other processes within your ecosystem.

#### Orkes

[Orkes](https://orkes.io/) is a reputable commercial vendor that specializes in providing a cloud-hosted version of Conductor, offering a hassle-free and streamlined experience to kickstart your workflow management journey.

By leveraging Orkes, you can swiftly get started with Conductor without the need for significant operational investments. The cloud-hosted nature of Orkes ensures that you can focus on designing and managing your workflows without the burden of infrastructure management or maintenance.

One of the key strengths of Orkes lies in its robust set of APIs. These APIs empower you to execute CRUD (Create, Read, Update, Delete) operations for your workflows with ease. With these capabilities at your disposal, you have full control over the lifecycle of your workflows, enabling you to adapt and optimize them as needed.

In addition to the powerful API capabilities, Orkes also provides a user-friendly and visually appealing designer. This intuitive designer offers a low-code experience, enabling you to create workflows effortlessly. With its clean and streamlined interface, you can visually map out the flow of your workflows, making it easier to understand and manage their execution.

By leveraging Orkes' cloud-hosted platform, comprehensive APIs, and user-friendly designer, you can unlock the full potential of Conductor for your workflow management needs. Whether you are a seasoned professional or new to workflow management, Orkes simplifies the process and allows you to focus on creating efficient and robust workflows.

#### When to use Conductor

- requirement for a rich selection of SDKs for different programming languages
- need for a UI designer to define workflows and get a graph representation of the execution plan
- pure orchestration for microservices
