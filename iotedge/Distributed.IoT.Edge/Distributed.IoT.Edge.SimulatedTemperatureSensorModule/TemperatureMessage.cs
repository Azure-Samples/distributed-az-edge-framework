namespace Distributed.IoT.Edge.SimulatedTemperatureSensorModule
{
    internal record TemperatureMessage(TemperaturePressure Machine, TemperaturePressure Ambient);

    internal record TemperaturePressure(double Temperature, double Pressure);
}
