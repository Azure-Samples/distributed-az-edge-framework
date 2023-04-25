// Local run cmd line.
// dapr run --app-id workflow-module --app-protocol grpc --app-port 5000 --resources-path=../../../deployment/helm/iot-edge-accelerator/templates/dapr -- dotnet run -- --receiverPubSubName "local-pub-sub" --receiverPubSubTopicName "telemetry" --senderPubSubName "local-pub-sub" --senderPubSubTopicName "enriched-telemetry"

using CommandLine;
using Dapr.Client;
using Dapr.Workflow;
using Distributed.IoT.Edge.WorkflowModule;
using Distributed.IoT.Edge.WorkflowModule.Services;
using Distributed.IoT.Edge.WorkflowModule.Workflows;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.Extensions.DependencyInjection.Extensions;
using WorkflowConsoleApp.Activities;

Environment.SetEnvironmentVariable("DAPR_GRPC_PORT", "53892");

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

builder.WebHost.ConfigureKestrel(k => k.ListenLocalhost(5001, op => op.Protocols =
    HttpProtocols.Http2));

// Additional configuration is required to successfully run gRPC on macOS.
// For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682

// Add services to the container.
builder.Services.AddGrpc();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<SubscriptionService>();

app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();
