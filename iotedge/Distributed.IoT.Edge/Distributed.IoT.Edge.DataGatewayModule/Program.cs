// Local run cmd line.
// dapr run --app-id data-gateway-module --app-protocol grpc --app-port 5000 --components-path=../../../deployment/helm/iot-edge-accelerator/templates/dapr -- dotnet run -- [--receiverPubSubName "local-pub-sub"] [--ReceiverPubSubTopicName "telemetry"] [--senderPubSubName "remote-pub-sub"] [--senderPubSubTopicName "telemetry"]

using CommandLine;

using Dapr.Client;

using Distributed.IoT.Edge.DataGatewayModule;
using Distributed.IoT.Edge.DataGatewayModule.Services;

var builder = WebApplication.CreateBuilder(args);

DataGatewayParameters? parameters = null;

var result = Parser.Default.ParseArguments<DataGatewayParameters>(args)
                 .WithParsed(parsedParams =>
                 {
                     parameters = parsedParams;
                     builder.Services.AddSingleton<DataGatewayParameters>(sp => parameters);

                     builder.Services.AddSingleton<DaprClient>(new DaprClientBuilder().Build());

                     builder.Services.AddTransient<SubscriptionService>(
                               sp => new SubscriptionService(
                               sp.GetRequiredService<ILogger<SubscriptionService>>(),
                               sp.GetRequiredService<DaprClient>(),
                               parameters?.ReceiverPubSubName,
                               parameters?.ReceiverPubSubTopicName,
                               parameters?.SenderPubSubName,
                               parameters?.SenderPubSubTopicName));
                    })
                 .WithNotParsed(errors =>
                 {
                     Environment.Exit(1);
                 });

// Additional configuration is required to successfully run gRPC on macOS.
// For instructions on how to configure Kestrel and gRPC clients on macOS, visit https://go.microsoft.com/fwlink/?linkid=2099682

// Add services to the container.
builder.Services.AddGrpc();

var app = builder.Build();

// Configure the HTTP request pipeline.
app.MapGrpcService<SubscriptionService>();

app.MapGet("/", () => "Communication with gRPC endpoints must be made through a gRPC client. To learn how to create a client, visit: https://go.microsoft.com/fwlink/?linkid=2086909");

app.Run();

