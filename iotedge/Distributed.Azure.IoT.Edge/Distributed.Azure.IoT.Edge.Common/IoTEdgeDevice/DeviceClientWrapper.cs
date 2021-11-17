namespace Distributed.Azure.IoT.Edge.Common.Device
{
    using global::System;
    using global::System.Threading;
    using global::System.Threading.Tasks;

    using Microsoft.Azure.Devices.Client;

    public class DeviceClientWrapper : IDeviceClient
    {
        private const TransportType DeviceTransportType = TransportType.Amqp;
        private readonly DeviceClient deviceClient;
        private bool disposed = false;

        public DeviceClientWrapper(string? connectionString)
        {
            if (connectionString is null)
            {
                throw new ArgumentNullException(nameof(connectionString));
            }

            this.deviceClient = DeviceClient.CreateFromConnectionString(connectionString, DeviceTransportType);
        }

        ~DeviceClientWrapper()
        {
            this.Dispose(false);
        }

        public Task SetMethodHandlerAsync(string methodName, MethodCallback methodHandler, object userContext)
        {
            return this.deviceClient.SetMethodHandlerAsync(methodName, methodHandler, userContext);
        }

        public Task SendEventAsync(Message message, CancellationToken cancellationToken)
        {
            return this.deviceClient.SendEventAsync(message, cancellationToken);
        }

        public void Dispose()
        {
            this.Dispose(true);
            GC.SuppressFinalize(this);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (this.disposed)
            {
                return;
            }

            if (disposing)
            {
                this.deviceClient.Dispose();
            }

            this.disposed = true;
        }
    }
}
