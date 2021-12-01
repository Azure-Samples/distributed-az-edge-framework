namespace Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule
{
    using CommandLine;

    internal class TemperatureSensorParameters
    {
        [Option(
           'i',
           "FeedIntervalInMilliseconds",
           Default = 1000,
           Required = false,
           HelpText = "Interval in milliseconds at which simulated sensor telemetry is generated.")]
        public int FeedIntervalInMilliseconds { get; set; }

        [Option(
         'm',
         "MessagingPubSub",
         Default = "messaging",
         Required = false,
         HelpText = "Dapr pubsub messaging component name.")]
        public string? MessagingPubSub { get; set; }

        [Option(
         't',
         "MessagingPubSubTopic",
         Default = "telemetry",
         Required = false,
         HelpText = "Dapr pubsub messaging topic name.")]
        public string? MessagingPubSubTopic { get; set; }
    }
}
