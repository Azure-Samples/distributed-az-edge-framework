namespace Distributed.Azure.IoT.Edge.Common
{
    using CommandLine;

    public class IoTHubParameters
    {
        [Option(
            'p',
            "PrimaryConnectionString",
            Required = true,
            HelpText = "The primary connection string for the IoT Hub device.")]
        public string? PrimaryConnectionString { get; set; }
    }
}
