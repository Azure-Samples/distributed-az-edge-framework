// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

namespace Microsoft.Azure.IIoT.Hub.Module.Client.Default.DaprClient {
    using Dapr.Client;
    using Microsoft.Azure.Devices.Client;
    using Microsoft.Azure.Devices.Shared;
    using Microsoft.Azure.IIoT.Module.Framework.Client;
    using System;
    using System.Collections.Generic;
    using System.IO;
    using System.Linq;
    using System.Threading;
    using System.Threading.Tasks;
    using Serilog;
    using Microsoft.Azure.IIoT.Messaging;
    
    /// <summary>
    /// Client adapter for Dapr
    /// </summary>
    public sealed class DaprClientAdapter : IClient {

        /// <inheritdoc />
        public int MaxEventBufferSize => int.MaxValue;       

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
        public async ValueTask DisposeAsync() {
            if (IsClosed) {
                return;
            }
            IsClosed = true;
            await CloseAsync();
        }

        /// <inheritdoc />
        public ITelemetryEvent CreateTelemetryEvent() {
            return new DaprClientAdapterMessage(this);
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
        public async Task SendEventAsync(ITelemetryEvent message) {
            lock (this) {
                if (IsClosed) {                   
                    return;
                }
            }

            try {

                var msg = (DaprClientAdapterMessage)message;

                var cancellationTokenSource = new CancellationTokenSource();
                cancellationTokenSource.CancelAfter(_timeout);

                var topic = msg.Topic;
                foreach (var body in msg.Buffers) {
                    if (body != null) {                        
                        await _daprClient.PublishEventAsync(_pubsub, _topic, Convert.ToString(body), cancellationTokenSource.Token);
                    }
                }              
            }
            catch (Exception ex) {
                _logger.Error($"{nameof(DaprClientAdapter)} is unable to publish message: {ex}.");
            }
        }

        /// <inheritdoc />
        public Task SendEventBatchAsync(IEnumerable<ITelemetryEvent> messages) {
            return Task.WhenAll(messages.Select(x => SendEventAsync(x)));
        }

        /// <inheritdoc />
        public Task SetDesiredPropertyUpdateCallbackAsync(DesiredPropertyUpdateCallback callback) {
            _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(SetDesiredPropertyUpdateCallbackAsync)}");
            return Task.CompletedTask;
        }

        /// <inheritdoc />
        public Task SetMethodDefaultHandlerAsync(MethodCallback methodHandler, object userContext) {
            _logger.Warning($"Unsupported call in {nameof(DaprClientAdapter)}: {nameof(SetMethodDefaultHandlerAsync)}");
            return Task.CompletedTask;
        }

        /// <inheritdoc />
        public Task SetMethodHandlerAsync(MethodCallback methodHandler) {
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

        internal sealed class DaprClientAdapterMessage : ITelemetryEvent {

            /// <summary>
            /// User properties
            /// </summary>
            internal Dictionary<string, string> UserProperties
                => _userProperties;

            /// <summary>
            /// Topic
            /// </summary>
            internal string Topic {
                get {
                    return _outer._topic;
                }
            }

            /// <inheritdoc/>
            public DateTime Timestamp { get; set; }

            /// <inheritdoc/>
            public string ContentType {
                get {
                    return _userProperties[kContentTypePropertyName];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[kContentTypePropertyName] = value;                       
                    }
                }
            }

            /// <inheritdoc/>
            public string ContentEncoding {
                get {
                    return _userProperties[kContentEncodingPropertyName];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[kContentEncodingPropertyName] = value;                        
                    }
                }
            }

            /// <inheritdoc/>
            public string MessageSchema {
                get {
                    return _userProperties[CommonProperties.EventSchemaType];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[CommonProperties.EventSchemaType] = value;
                    }
                }
            }

            /// <inheritdoc/>
            public string RoutingInfo {
                get {
                    return _userProperties[CommonProperties.RoutingInfo];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[CommonProperties.RoutingInfo] = value;
                    }
                }
            }

            /// <inheritdoc/>
            public string DeviceId {
                get {
                    return _userProperties[CommonProperties.DeviceId];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[CommonProperties.DeviceId] = value;
                    }
                }
            }

            /// <inheritdoc/>
            public string ModuleId {
                get {
                    return _userProperties[CommonProperties.ModuleId];
                }
                set {
                    if (!string.IsNullOrWhiteSpace(value)) {
                        _userProperties[CommonProperties.ModuleId] = value;
                    }
                }
            }

            /// <inheritdoc/>
            public string OutputName { get; set; }
            /// <inheritdoc/>
            public bool Retain { get; set; }
            /// <inheritdoc/>
            public TimeSpan Ttl { get; set; }
            /// <inheritdoc/>
            public IReadOnlyList<byte[]> Buffers { get; set; }

            /// <inheritdoc/>
            public void Dispose() {
                _userProperties.Clear();
            }

            /// <summary>
            /// Create message
            /// </summary>
            /// <param name="outer"></param>
            internal DaprClientAdapterMessage(DaprClientAdapter outer) {
                _outer = outer;
            }

            private readonly DaprClientAdapter _outer;
            private readonly Dictionary<string, string> _userProperties = new Dictionary<string, string>();
        }
    }
}
