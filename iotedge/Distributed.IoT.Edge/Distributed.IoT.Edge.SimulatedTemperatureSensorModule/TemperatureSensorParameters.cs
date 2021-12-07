namespace Distributed.IoT.Edge.SimulatedTemperatureSensorModule
{
    using CommandLine;

    internal class TemperatureSensorParameters
    {
        [Option(
           "feedIntervalInMilliseconds",
           Default = 1000,
           Required = false,
           HelpText = "Interval in milliseconds at which simulated sensor telemetry is generated.")]
        public int FeedIntervalInMilliseconds { get; set; }

        [Option(
         "senderPubSubName",
         Default = "local-pub-sub",
         Required = false,
         HelpText = "Dapr pubsub messaging component name.")]
        public string? SenderPubSubName { get; set; }

        [Option(
         "senderPubSubTopicName",
         Default = "telemetry",
         Required = false,
         HelpText = "Dapr pubsub messaging topic name.")]
        public string? SenderPubSubTopicName { get; set; }
    }
}
