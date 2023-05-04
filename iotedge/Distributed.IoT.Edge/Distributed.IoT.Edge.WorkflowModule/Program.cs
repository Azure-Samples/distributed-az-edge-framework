// Local run cmd line.
// dapr run --app-id workflow-module --app-protocol grpc --app-port 5000 --resources-path=../../../deployment/helm/iot-edge-accelerator/templates/dapr -- dotnet run -- --receiverPubSubName "local-pub-sub" --receiverPubSubTopicName "telemetry" --senderPubSubName "local-pub-sub" --senderPubSubTopicName "enriched-telemetry"

using System.Collections.Immutable;
using CommandLine;
using Dapr.Client;
using Dapr.Workflow;
using Distributed.IoT.Edge.WorkflowModule;
using Distributed.IoT.Edge.WorkflowModule.Services;
using Distributed.IoT.Edge.WorkflowModule.Workflows;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection.Extensions;
using WorkflowConsoleApp.Activities;

// Environment.SetEnvironmentVariable("DAPR_GRPC_PORT", "50001");
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDaprWorkflow(options =>
{
    options.RegisterWorkflow<EnrichTelemetryWorkflow>();
    options.RegisterActivity<EnrichmentActivity>();
    options.RegisterActivity<PublishActivity>();
});

WorkflowParameters? parameters;

var result = Parser.Default.ParseArguments<WorkflowParameters>(args)
    .WithParsed(parsedParams =>
    {
        parameters = parsedParams;
        builder.Services.AddSingleton<WorkflowParameters>(sp => parameters);

        // Already registered by AddDaprWorkflow extension
        builder.Services.AddSingleton<DaprClient>(new DaprClientBuilder().Build());
        builder.Services.AddTransient<SubscriptionService>(
            sp => new SubscriptionService(
                sp.GetRequiredService<ILogger<SubscriptionService>>(),
                sp.GetRequiredService<DaprClient>(),
                sp.GetRequiredService<WorkflowEngineClient>(),
                parameters));
    })
    .WithNotParsed(errors =>
    {
        Environment.Exit(1);
    });

// builder.WebHost.ConfigureKestrel(k => k.ListenLocalhost(5001, op => op.Protocols =
//    HttpProtocols.Http2));

// Additional configuration is required to successfully run gRPC on macOS.
// For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682
builder.Services.AddGrpc();

var app = builder.Build();

// Configure the HTTP request pipeline.
// app.MapGrpcService<SubscriptionService>();

app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();

// await NewFunction(builder);
//
// async Task NewFunction(WebApplicationBuilder webApplicationBuilder)
// {
// // Add services to the container.
// #pragma warning disable ASP0000
//     var sp = webApplicationBuilder.Services.BuildServiceProvider();
// #pragma warning restore ASP0000
//
//     var logger = sp.GetRequiredService<ILogger<EnrichTelemetryWorkflow>>();
//
//     var workflowClient = sp.GetRequiredService<WorkflowEngineClient>();
//
//     var json =
//         "{\"ambient\":{\"pressure\":93.09722520833911,\"temperature\":3.6978187215073843},\"machine\":{\"pressure\":61.17983921251796,\"temperature\":75.69596780134813}}\"";
//
//     var runId = Guid.NewGuid().ToString();
//
// // starting workflow to enrich and transform the data
//     await workflowClient.ScheduleNewWorkflowAsync(
//         name: nameof(EnrichTelemetryWorkflow),
//         instanceId: runId,
//         input: json);
//
// // Wait a second to allow workflow to start
//     await Task.Delay(TimeSpan.FromSeconds(1));
//
//     WorkflowState state = await workflowClient.GetWorkflowStateAsync(
//         instanceId: runId,
//         getInputsAndOutputs: true);
//
//     logger.LogTrace($"Your workflow {runId} has started. Here is the status of the workflow: {state.RuntimeStatus}");
//
//     while (!state.IsWorkflowCompleted)
//     {
//         await Task.Delay(TimeSpan.FromSeconds(5));
//         state = await workflowClient.GetWorkflowStateAsync(
//             instanceId: runId,
//             getInputsAndOutputs: true);
//         logger.LogTrace($"State of workflow {runId} is: {state.RuntimeStatus}");
//     }
// }
