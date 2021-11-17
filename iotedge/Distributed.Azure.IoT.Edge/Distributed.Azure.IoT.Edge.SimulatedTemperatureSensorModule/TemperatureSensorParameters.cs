namespace Distributed.Azure.IoT.Edge.SimulatedTemperatureSensorModule
{
    using CommandLine;

    internal class TemperatureSensorParameters
    {
        [Option(
           'i',
           "Interval",
           Required = false,
           HelpText = "Interval in milliseconds at which simulated sensor telemetry is generated.")]
        public string? Interval { get; set; }
    }
}
