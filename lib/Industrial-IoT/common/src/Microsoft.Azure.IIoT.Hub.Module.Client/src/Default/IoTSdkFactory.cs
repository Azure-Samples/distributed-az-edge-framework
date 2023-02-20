// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

namespace Microsoft.Azure.IIoT.Module.Framework.Client {
    using Microsoft.Azure.IIoT.Module.Framework.Client.MqttClient;
    using Microsoft.Azure.Devices.Client;
    using Microsoft.Azure.Devices.Client.Transport.Mqtt;
    using Microsoft.Azure.IIoT.Abstractions;
    using Microsoft.Azure.IIoT.Diagnostics;
    using Microsoft.Azure.IIoT.Exceptions;
    using Microsoft.Azure.IIoT.Utils;
    using Serilog;
    using Serilog.Events;
    using System;
    using System.Collections.Generic;
    using System.Diagnostics.Tracing;
    using System.IO;
    using System.Linq;
    using System.Security.Cryptography.X509Certificates;
    using System.Threading.Tasks;
    using System.Net.Http;
    using Newtonsoft.Json;
    using Dapr.Client;
    using System.Text;
    using Newtonsoft.Json.Linq;

    /// <summary>
    /// Injectable factory that creates clients
    /// </summary>
    public sealed class IoTSdkFactory : IClientFactory, IDisposable {

        /// <inheritdoc />
        public string DeviceId { get; }

        /// <inheritdoc />
        public string ModuleId { get; }

        /// <inheritdoc />
        public string Gateway { get; }

        /// <inheritdoc />
        public IRetryPolicy RetryPolicy { get; set; }

        /// <summary>
        /// Create sdk factory
        /// </summary>
        /// <param name="config"></param>
        /// <param name="broker"></param>
        /// <param name="logger"></param>
        public IoTSdkFactory(IModuleConfig config, IEventSourceBroker broker, ILogger logger) {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _telemetryTopicTemplate = config.TelemetryTopicTemplate;

            if (broker != null) {
                _logHook = broker.Subscribe(IoTSdkLogger.EventSource, new IoTSdkLogger(logger));
            }

            // The runtime injects this as an environment variable
            var deviceId = Environment.GetEnvironmentVariable(IoTEdgeVariables.IOTEDGE_DEVICEID);
            var moduleId = Environment.GetEnvironmentVariable(IoTEdgeVariables.IOTEDGE_MODULEID);
            var ehubHost = Environment.GetEnvironmentVariable(IoTEdgeVariables.IOTEDGE_GATEWAYHOSTNAME);

            try {
                if (!string.IsNullOrEmpty(config.MqttClientConnectionString) &&
                    !string.IsNullOrEmpty(config.EdgeHubConnectionString)) {
                    throw new InvalidConfigurationException(
                        "Can't have both a mqtt client connection string and a device connection string.");
                }

                if (!string.IsNullOrEmpty(config.MqttClientConnectionString)) {
                    _mqttClientCs = MqttClientConnectionStringBuilder.Create(config.MqttClientConnectionString);

                    if (_mqttClientCs.UsingIoTHub && string.IsNullOrEmpty(_mqttClientCs.SharedAccessSignature)) {
                        throw new InvalidConfigurationException(
                            "Connection string is missing shared access key.");
                    }
                    if (_mqttClientCs.UsingIoTHub && string.IsNullOrEmpty(_mqttClientCs.DeviceId)) {
                        throw new InvalidConfigurationException(
                            "Connection string is missing device id.");
                    }

                    deviceId = _mqttClientCs.DeviceId;
                    moduleId = _mqttClientCs.ModuleId;
                    _timeout = TimeSpan.FromSeconds(15);
                }
                else if (!string.IsNullOrEmpty(config.EdgeHubConnectionString)) {
                    _deviceClientCs = IotHubConnectionStringBuilder.Create(config.EdgeHubConnectionString);

                    if (string.IsNullOrEmpty(_deviceClientCs.SharedAccessKey)) {
                        throw new InvalidConfigurationException(
                            "Connection string is missing shared access key.");
                    }
                    if (string.IsNullOrEmpty(_deviceClientCs.DeviceId)) {
                        throw new InvalidConfigurationException(
                            "Connection string is missing device id.");
                    }

                    deviceId = _deviceClientCs.DeviceId;
                    moduleId = _deviceClientCs.ModuleId;
                    ehubHost = _deviceClientCs.GatewayHostName ?? ehubHost;

                    if (string.IsNullOrWhiteSpace(_deviceClientCs.GatewayHostName) && !string.IsNullOrWhiteSpace(ehubHost)) {
                        _deviceClientCs = IotHubConnectionStringBuilder.Create(
                            config.EdgeHubConnectionString + ";GatewayHostName=" + ehubHost);

                        _logger.Information($"Details of gateway host are added to IoT Hub connection string: " +
                            $"GatewayHostName={ehubHost}");
                    }
                    _timeout = TimeSpan.FromMinutes(5);
                }
                else if (!string.IsNullOrWhiteSpace(config.DaprConnectionString)) {
                    deviceId = "dapr";
                    _daprConnectionString = DaprConnectionString.Create(config.DaprConnectionString);
                }
            }
            catch (Exception e) {
                _logger.Error(e, "Bad configuration value in connection string config.");
            }

            ModuleId = moduleId;
            DeviceId = deviceId;
            Gateway = ehubHost;

            if (string.IsNullOrEmpty(config.MqttClientConnectionString) && string.IsNullOrEmpty(DeviceId)) {
                var ex = new InvalidConfigurationException(
                    "If you are running outside of an IoT Edge context or in EdgeHubDev mode, then the " +
                    "host configuration is incomplete and missing the EdgeHubConnectionString setting." +
                    "You can run the module using the command line interface or in IoT Edge context, or " +
                    "manually set the 'EdgeHubConnectionString' environment variable.");

                _logger.Error(ex, "The sdk factory was not configured correctly. Device Id is missing.");
                throw ex;
            }

            _bypassCertValidation = config.BypassCertVerification;
            if (!_bypassCertValidation) {
                var certPath = Environment.GetEnvironmentVariable("EdgeModuleCACertificateFile");
                if (!string.IsNullOrWhiteSpace(certPath)) {
                    InstallCert(certPath);
                }
                else if (!string.IsNullOrEmpty(ehubHost)) {
                    _bypassCertValidation = true;
                }
            }
            _enableOutputRouting = config.EnableOutputRouting;

            if (!string.IsNullOrEmpty(ehubHost)) {
                // Running in edge mode
                // the configured transport (if provided) will be forced to it's OverTcp
                // variant as follows: AmqpOverTcp when Amqp, AmqpOverWebsocket or AmqpOverTcp specified
                // and MqttOverTcp otherwise. Default is MqttOverTcp
                if ((config.Transport & TransportOption.Mqtt) != 0) {
                    // prefer Mqtt over Amqp due to performance reasons
                    _transport = TransportOption.MqttOverTcp;
                }
                else {
                    _transport = TransportOption.AmqpOverTcp;
                }
                _logger.Information("Connecting all clients to {edgeHub} using {transport}.",
                    ehubHost, _transport);
            }
            else {
                _transport = config.Transport;
            }
        }

        /// <inheritdoc/>
        public void Dispose() {
            _logHook?.Dispose();
        }


        /// <inheritdoc/>
        [System.Diagnostics.CodeAnalysis.SuppressMessage("Security", "CA5359:Do Not Disable Certificate Validation",
            Justification = "<Pending>")]
        public async Task<IClient> CreateAsync(string product, IProcessControl ctrl) {

            if (_bypassCertValidation) {
                _logger.Warning("Bypassing certificate validation for client.");
            }

            // Configure transport settings
            var transportSettings = new List<ITransportSettings>();

            if ((_transport & TransportOption.MqttOverTcp) != 0) {
                var setting = new MqttTransportSettings(
                    TransportType.Mqtt_Tcp_Only);
                if (_bypassCertValidation) {
                    setting.RemoteCertificateValidationCallback =
                        (sender, certificate, chain, sslPolicyErrors) => true;
                }
                transportSettings.Add(setting);
            }
            if ((_transport & TransportOption.MqttOverWebsocket) != 0) {
                var setting = new MqttTransportSettings(
                    TransportType.Mqtt_WebSocket_Only);
                if (_bypassCertValidation) {
                    setting.RemoteCertificateValidationCallback =
                        (sender, certificate, chain, sslPolicyErrors) => true;
                }
                transportSettings.Add(setting);
            }
            if ((_transport & TransportOption.AmqpOverTcp) != 0) {
                var setting = new AmqpTransportSettings(
                    TransportType.Amqp_Tcp_Only);
                if (_bypassCertValidation) {
                    setting.RemoteCertificateValidationCallback =
                        (sender, certificate, chain, sslPolicyErrors) => true;
                }
                transportSettings.Add(setting);
            }
            if ((_transport & TransportOption.AmqpOverWebsocket) != 0) {
                var setting = new AmqpTransportSettings(
                    TransportType.Amqp_WebSocket_Only);
                if (_bypassCertValidation) {
                    setting.RemoteCertificateValidationCallback =
                        (sender, certificate, chain, sslPolicyErrors) => true;
                }
                transportSettings.Add(setting);
            }
            if (transportSettings.Count != 0) {
                return await Try.Options(transportSettings
                    .Select<ITransportSettings, Func<Task<IClient>>>(t =>
                         () => CreateAdapterAsync(product, () => ctrl?.Reset(), t))
                    .ToArray());
            }
            return await CreateAdapterAsync(product, () => ctrl?.Reset());
        }

        /// <summary>
        /// Create client adapter
        /// </summary>
        /// <param name="product"></param>
        /// <param name="onError"></param>
        /// <param name="transportSetting"></param>
        /// <returns></returns>
        private Task<IClient> CreateAdapterAsync(string product, Action onError,
            ITransportSettings transportSetting = null) {
            if (string.IsNullOrEmpty(ModuleId)) {
                if (_mqttClientCs != null) {
                    return MqttClientAdapter.CreateAsync(_mqttClientCs, DeviceId, _telemetryTopicTemplate,
                        timeout: _timeout, logger: _logger);
                }
                else if (_deviceClientCs != null) {
                    return DeviceClientAdapter.CreateAsync(product, _deviceClientCs, DeviceId,
                        transportSetting, timeout: _timeout, RetryPolicy, onError, _logger);
                }
                else if (_daprConnectionString != null)
                {
                    return DaprClientAdapter.CreateAsync(_daprConnectionString, _timeout, _logger);                    
                }
                else {
                    throw new InvalidConfigurationException(
                        "No connection string for device client specified.");
                }
            }
            return ModuleClientAdapter.CreateAsync(product, _deviceClientCs, DeviceId, ModuleId,
                _enableOutputRouting, transportSetting, timeout: _timeout, retry: RetryPolicy,
                onConnectionLost: onError, logger: _logger);
        }

        /// <summary>
        /// Add certificate in local cert store for use by client for secure connection
        /// to iotedge runtime
        /// </summary>
        private void InstallCert(string certPath) {
            if (!File.Exists(certPath)) {
                // We cannot proceed further without a proper cert file
                _logger.Error("Missing certificate file: {certPath}", certPath);
                throw new InvalidOperationException("Missing certificate file.");
            }

            var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
            store.Open(OpenFlags.ReadWrite);
            using (var cert = new X509Certificate2(X509Certificate.CreateFromCertFile(certPath))) {
                store.Add(cert);
            }
            _logger.Information("Added Cert: {certPath}", certPath);
            store.Close();
        }

        /// <summary>
        /// Sdk logger event source hook
        /// </summary>
        internal sealed class IoTSdkLogger : EventSourceSerilogSink {

            /// <inheritdoc/>
            public IoTSdkLogger(ILogger logger) :
                base(logger.ForContext("SourceContext", EventSource.Replace('-', '.'))) {
            }

            /// <inheritdoc/>
            public override void OnEvent(EventWrittenEventArgs eventData) {
                switch (eventData.EventName) {
                    case "Enter":
                    case "Exit":
                    case "Associate":
                        WriteEvent(LogEventLevel.Verbose, eventData);
                        break;
                    default:
                        WriteEvent(LogEventLevel.Debug, eventData);
                        break;
                }
            }

            // ddbee999-a79e-5050-ea3c-6d1a8a7bafdd
            public const string EventSource = "Microsoft-Azure-Devices-Device-Client";
        }

        public sealed class DaprClientAdapter : IClient {
            /// <summary>
            /// Message to be sent to the Dapr runtime.
            /// </summary>
            private sealed class DaprMessage {
                /// <summary>
                /// Body for the message.
                /// </summary>
                public string Body { get; }

                /// <summary>
                /// Metadata for the message.
                /// </summary>
                public IDictionary<string, string> Properties { get; }

                /// <summary>
                /// Constructor for the Dapr message.
                /// </summary>
                /// <param name="body"></param>
                /// <param name="properties"></param>
                public DaprMessage(string body, IDictionary<string, string> properties) {
                    Body = body ?? throw new ArgumentNullException(nameof(body));
                    Properties = properties ?? throw new ArgumentNullException(nameof(properties));
                }
            }

            private const string kContentEncodingPropertyName = "iothub-content-encoding";
            private const string kContentTypePropertyName = "iothub-content-type";

            private readonly TimeSpan _timeout;
            private readonly ILogger _logger;
            private readonly DaprClient _daprClient;
            private readonly string _pubsub;
            private readonly string _topic;

            /// <summary>
            /// Adapter ready state.
            /// </summary>
            public bool IsClosed { get; private set; } = true;

            /// <summary>
            /// Constructor for the Dapr client adapter.
            /// </summary>
            /// <param name="daprClient">Dapr client.</param>
            /// <param name="pubsub">Name of the pubsub component.</param>
            /// <param name="topic">Name of the topic.</param>
            /// <param name="timeout">Default for operations.</param>
            /// <param name="logger">Logger for the operations.</param>
            private DaprClientAdapter(DaprClient daprClient, string pubsub, string topic, TimeSpan timeout, ILogger logger) {
                _daprClient = daprClient ?? throw new ArgumentNullException(nameof(daprClient));
                _pubsub = pubsub ?? throw new ArgumentNullException(nameof(pubsub));
                _topic = topic ?? throw new ArgumentNullException(nameof(topic));
                _timeout = timeout;
                _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            }

            /// <summary>
            /// Create Dapr client adapter from a Dapr connection string.
            /// </summary>
            /// <param name="daprConnectionString">Dapr connection string.</param>
            /// <param name="timeout">Default for operations.</param>
            /// <param name="logger">Logger for the operations.</param>
            /// <returns>A Dapr client adapter.</returns>
            public static async Task<IClient> CreateAsync(DaprConnectionString daprConnectionString, TimeSpan timeout, ILogger logger) {
                var cancellationTokenSource = new CancellationTokenSource();
                cancellationTokenSource.CancelAfter(timeout);

                // Create client and check sidecar health.
                var daprClientBuilder = new DaprClientBuilder()
                    .UseHttpEndpoint(daprConnectionString.HttpEndpoint)
                    .UseGrpcEndpoint(daprConnectionString.GrpcEndpoint)
                    .UseDaprApiToken(daprConnectionString.ApiToken);
                var daprClient = daprClientBuilder.Build();
                var daprClientAdapter = new DaprClientAdapter(daprClient, daprConnectionString.PubSub, daprConnectionString.Topic, timeout, logger);

                try {
                    if (!await daprClient.CheckHealthAsync(cancellationTokenSource.Token)) {
                        throw new InvalidOperationException($"Sidecar is not available for {nameof(DaprClientAdapter)}.");
                    }

                    if (!string.IsNullOrWhiteSpace(daprConnectionString.HttpEndpoint)) {
                        logger.Information($"Configured HTTP endpoint for {nameof(DaprClientAdapter)}: {{HttpEndpoint}}.", daprConnectionString.HttpEndpoint);
                    }
                    if (!string.IsNullOrWhiteSpace(daprConnectionString.GrpcEndpoint)) {
                        logger.Information($"Configured gRPC endpoint for {nameof(DaprClientAdapter)}: {{GrpcEndpoint}}.", daprConnectionString.GrpcEndpoint);
                    }
                }
                catch (Exception ex) {
                    logger.Error($"Sidecar is not available for {nameof(DaprClientAdapter)}: {ex}.");
                    throw;
                }

                daprClientAdapter.IsClosed = false;
                return daprClientAdapter;
            }

            /// <inheritdoc />
            public Task CloseAsync() {
                lock (this) {
                    if (IsClosed) {
                        _logger.Warning($"{nameof(DaprClientAdapter)} is already closed.");
                    }
                    else {
                        IsClosed = true;
                    }
                }
                return Task.CompletedTask;
            }

            /// <inheritdoc />
            public void Dispose() {
                lock (this) {
                    if (!IsClosed) {
                        CloseAsync().Wait();
                    }
                }
            }

            /// <inheritdoc />
            public Task<Twin> GetTwinAsync() {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(GetTwinAsync)}");
                return Task.FromResult<Twin>(null);
            }

            /// <inheritdoc />
            public Task<MethodResponse> InvokeMethodAsync(string deviceId, string moduleId, MethodRequest methodRequest, CancellationToken cancellationToken = default) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(InvokeMethodAsync)}");
                return Task.FromResult<MethodResponse>(null);
            }

            /// <inheritdoc />
            public Task<MethodResponse> InvokeMethodAsync(string deviceId, MethodRequest methodRequest, CancellationToken cancellationToken = default) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(InvokeMethodAsync)}");
                return Task.FromResult<MethodResponse>(null);
            }

            /// <inheritdoc />
            public async Task SendEventAsync(Message message) {
                lock (this) {
                    if (IsClosed) {
                        _logger.Warning($"{nameof(DaprClientAdapter)} is closed.");
                        return;
                    }
                }

                try {
                    var cancellationTokenSource = new CancellationTokenSource();
                    cancellationTokenSource.CancelAfter(_timeout);

                    using var streamReader = new StreamReader(message.BodyStream, Encoding.UTF8);
                    var body = await streamReader.ReadToEndAsync();

                    var properties = new Dictionary<string, string>(message.Properties);
                    if (!string.IsNullOrWhiteSpace(message.ContentType)) {
                        properties[kContentTypePropertyName] = message.ContentType;
                    }
                    if (!string.IsNullOrWhiteSpace(message.ContentEncoding)) {
                        properties[kContentEncodingPropertyName] = message.ContentEncoding;
                    }

                    var daprMessage = new DaprMessage(body, properties);
                    await _daprClient.PublishEventAsync(_pubsub, _topic, daprMessage, cancellationTokenSource.Token);
                }
                catch (Exception ex) {
                    _logger.Error($"{nameof(DaprClientAdapter)} is unable to publish message: {ex}.");
                }
            }

            /// <inheritdoc />
            public Task SendEventBatchAsync(IEnumerable<Message> messages) {
                return Task.WhenAll(messages.Select(x => SendEventAsync(x)));
            }

            /// <inheritdoc />
            public Task SetDesiredPropertyUpdateCallbackAsync(DesiredPropertyUpdateCallback callback, object userContext) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(SetDesiredPropertyUpdateCallbackAsync)}");
                return Task.CompletedTask;
            }

            /// <inheritdoc />
            public Task SetMethodDefaultHandlerAsync(MethodCallback methodHandler, object userContext) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(SetMethodDefaultHandlerAsync)}");
                return Task.CompletedTask;
            }

            /// <inheritdoc />
            public Task SetMethodHandlerAsync(string methodName, MethodCallback methodHandler, object userContext) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(SetMethodDefaultHandlerAsync)}");
                return Task.CompletedTask;
            }

            /// <inheritdoc />
            public Task UpdateReportedPropertiesAsync(TwinCollection reportedProperties) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(UpdateReportedPropertiesAsync)}");
                return Task.CompletedTask;
            }

            /// <inheritdoc />
            public Task UploadToBlobAsync(string blobName, Stream source) {
                _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(UploadToBlobAsync)}");
                return Task.CompletedTask;
            }
        }

        private readonly TimeSpan _timeout;
        private readonly TransportOption _transport;
        private readonly IotHubConnectionStringBuilder _deviceClientCs;
        private readonly MqttClientConnectionStringBuilder _mqttClientCs;
        private readonly DaprConnectionString _daprConnectionString;
        private readonly ILogger _logger;
        private readonly string _telemetryTopicTemplate;
        private readonly IDisposable _logHook;
        private readonly bool _bypassCertValidation;
        private readonly bool _enableOutputRouting;
    }
}
