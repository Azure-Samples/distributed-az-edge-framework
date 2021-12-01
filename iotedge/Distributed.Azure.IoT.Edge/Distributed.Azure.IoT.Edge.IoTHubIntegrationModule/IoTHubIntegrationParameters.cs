namespace Distributed.Azure.IoT.Edge.IoTHubIntegrationModule
{
    using CommandLine;

    internal class IoTHubIntegrationParameters
    {
        [Option(
        'p',
        "PrimaryConnectionString",
        Required = true,
        HelpText = "The primary connection string for the IoT Hub device.")]
        public string? PrimaryConnectionString { get; set; }

        [Option(
        'm',
        "PubSubMessagingName",
        Default = "messaging",
        Required = false,
        HelpText = "Dapr pubsub messaging component name.")]
        public string? PubSubMessagingName { get; set; }

        [Option(
        't',
        "PubSubTopicName",
        Default = "telemetry",
        Required = false,
        HelpText = "Dapr pubsub messaging topic name.")]
        public string? PubSubTopicName { get; set; }
    }
}
