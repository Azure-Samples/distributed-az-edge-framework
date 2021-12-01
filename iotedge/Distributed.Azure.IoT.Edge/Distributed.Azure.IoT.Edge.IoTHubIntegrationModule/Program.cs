// Local run cmd line.
// dapr run --app-id iot-hub-integration-module --app-protocol grpc --app-port 5000 --components-path=../../../deployment/helm/iot-edge-accelerator/templates/dapr -- dotnet run -- -p "<Device Connection String>" [-m "messaging"] [-t "telemetry"]

using CommandLine;
using Distributed.Azure.IoT.Edge.Common.Device;
using Distributed.Azure.IoT.Edge.IoTHubIntegrationModule;
using Distributed.Azure.IoT.Edge.IoTHubIntegrationModule.Services;

var builder = WebApplication.CreateBuilder(args);

IoTHubIntegrationParameters? parameters = null;

ParserResult<IoTHubIntegrationParameters> result = Parser.Default.ParseArguments<IoTHubIntegrationParameters>(args)
                 .WithParsed(parsedParams =>
                 {
                     parameters = parsedParams;
                     builder.Services.AddScoped<IoTHubIntegrationParameters>(sp => parameters);
                     builder.Services.AddSingleton<IDeviceClient, DeviceClientWrapper>(sp => new DeviceClientWrapper(parameters?.PrimaryConnectionString));
                 })
                 .WithNotParsed(errors =>
                 {
                     Environment.Exit(1);
                 });

// Additional configuration is required to successfully run gRPC on macOS.
// For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682

// Add services to the container.
builder.Services.AddGrpc();

builder.Services.AddTransient<SubscriptionService>(
   sp => new SubscriptionService(
       sp.GetRequiredService<ILogger<SubscriptionService>>(),
       new DeviceClientWrapper(parameters?.PrimaryConnectionString),
       parameters?.PubSubMessagingName,
       parameters?.PubSubTopicName));

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<SubscriptionService>();

app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();
