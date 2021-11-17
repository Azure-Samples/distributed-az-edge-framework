// dapr run --app-id upstream-module --app-port 5000 -- dotnet run -- -p "<your device connection string>"

using CommandLine;

using Distributed.Azure.IoT.Edge.Common;
using Distributed.Azure.IoT.Edge.Common.Device;

var builder = WebApplication.CreateBuilder(args);

IoTHubParameters? parameters = null;

ParserResult<IoTHubParameters> result = Parser.Default.ParseArguments<IoTHubParameters>(args)
                .WithParsed(parsedParams =>
                {
                    parameters = parsedParams;
                })
                .WithNotParsed(errors =>
                {
                    Environment.Exit(1);
                });

Console.WriteLine($"CONN STR: {parameters?.PrimaryConnectionString}");

// Add services to the container.
builder.Services.AddControllers().AddDapr();

builder.Services.AddControllers();

// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddSwaggerGen();

builder.Services.AddSingleton<IDeviceClient, DeviceClientWrapper>(sp => new DeviceClientWrapper(parameters?.PrimaryConnectionString));

var app = builder.Build();

app.UseCloudEvents();

app.UseRouting();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseAuthorization();

app.MapControllers();

app.UseEndpoints(endpoints =>
{
    endpoints.MapSubscribeHandler();
    endpoints.MapControllers();
});

app.Run();
