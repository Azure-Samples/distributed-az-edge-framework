// See https://aka.ms/new-console-template for more information
// dapr run --log-level debug  --app-id temp-sensor-module -- dotnet run

using CommandLine;

using Dapr.Client;

using Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

Console.WriteLine("Initiating IoT edge custom module...");

TemperatureSensorParameters? parameters = null;

ParserResult<TemperatureSensorParameters> result = Parser.Default.ParseArguments<TemperatureSensorParameters>(args)
                .WithParsed(parsedParams =>
                {
                    parameters = parsedParams;
                })
                .WithNotParsed(errors =>
                {
                    Environment.Exit(1);
                });

// TODO: Check disposing resources.
await CreateHostBuilder(args, parameters).Build().RunAsync();

static IHostBuilder CreateHostBuilder(string[] args, TemperatureSensorParameters? parameters) =>
Host.CreateDefaultBuilder(args)
    .ConfigureServices((_, services) =>
        services.AddHostedService<Worker>(sp => new Worker(sp.GetRequiredService<ILogger<Worker>>(), sp.GetRequiredService<DaprClient>(), "pubsub", "telemetry"))
        .AddSingleton<DaprClient>(new DaprClientBuilder().Build()));
