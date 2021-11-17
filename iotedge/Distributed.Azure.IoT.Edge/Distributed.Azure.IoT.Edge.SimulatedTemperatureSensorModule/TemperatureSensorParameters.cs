namespace Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule
{
    using CommandLine;

    internal class TemperatureSensorParameters
    {
        [Option(
           'i',
           "FeedIntervalInMilliseconds",
           Required = false,
           HelpText = "Interval in milliseconds at which simulated sensor telemetry is generated.")]
        public int FeedIntervalInMilliseconds { get; set; }
    }
}
