// Local run cmd line.
// dapr run --app-protocol grpc --components-path=../../../deployment/helm/iot-edge-accelerator/templates/dapr --app-id simulated-temperature-sensor-module -- dotnet run -- [--feedIntervalInMilliseconds 1000] [--senderPubSubName local-pub-sub] [--senderPubSubTopicName telemetry]

using CommandLine;

using Dapr.Client;

using Distributed.IoT.Edge.SimulatedTemperatureSensorModule;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

TemperatureSensorParameters? parameters = null;

var result = Parser.Default.ParseArguments<TemperatureSensorParameters>(args)
                .WithParsed(parsedParams =>
                {
                    parameters = parsedParams;
                })
                .WithNotParsed(errors =>
                {
                    Environment.Exit(1);
                });

await CreateHostBuilder(args, parameters).Build().RunAsync();

static IHostBuilder CreateHostBuilder(string[] args, TemperatureSensorParameters? parameters) =>
Host.CreateDefaultBuilder(args)
    .ConfigureServices((_, services) =>
        services.AddHostedService<Worker>(sp =>
                new Worker(
                sp.GetRequiredService<ILogger<Worker>>(),
                sp.GetRequiredService<DaprClient>(),
                parameters?.FeedIntervalInMilliseconds,
                parameters?.SenderPubSubName,
                parameters?.SenderPubSubTopicName)).AddSingleton<DaprClient>(new DaprClientBuilder().Build()));
