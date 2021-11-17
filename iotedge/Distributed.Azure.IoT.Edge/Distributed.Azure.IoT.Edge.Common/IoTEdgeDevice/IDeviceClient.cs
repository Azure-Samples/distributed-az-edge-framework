namespace Distributed.Azure.IoT.Edge.Common.Device
{
    using global::System;
    using global::System.Threading;
    using global::System.Threading.Tasks;

    using Microsoft.Azure.Devices.Client;

    public interface IDeviceClient : IDisposable
    {
        Task SetMethodHandlerAsync(string methodName, MethodCallback methodHandler, object userContext);

        Task SendEventAsync(Message message, CancellationToken cancellationToken);
    }
}
