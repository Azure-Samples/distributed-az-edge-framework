namespace Distributed.Azure.IoT.Edge.System.IoTHubModule.Controllers
{
    using Dapr;

    using Distributed.Azure.IoT.Edge.Common;
    using Distributed.Azure.IoT.Edge.Common.Device;

    using global::System.Text;
    using global::System.Text.Json;

    using Microsoft.AspNetCore.Mvc;
    using Microsoft.Azure.Devices.Client;

    [ApiController]
    [Route("[controller]")]
    public class MessageSubscriptionController : ControllerBase
    {
        private readonly ILogger<MessageSubscriptionController> _logger;
        private readonly IDeviceClient _deviceClient;

        public MessageSubscriptionController(ILogger<MessageSubscriptionController> logger, IDeviceClient deviceClient)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _deviceClient = deviceClient ?? throw new ArgumentNullException(nameof(deviceClient));
        }

        [Topic("pubsub", "telemetry")]
        [HttpPost("telemetry")]
        public async Task<ActionResult> ReceiveTelemetry(CancellationToken cancellationToken, [FromBody] JsonDocument telemetry)
        {
            var messageString = telemetry.ToJsonString();

            _logger.LogTrace($"Sending message to IoT Hub in cloud, message {messageString}.");

            using (var message = new Message(Encoding.UTF8.GetBytes(messageString)))
            {
                await _deviceClient.SendEventAsync(message, cancellationToken);
            }

            return Ok();
        }
    }
}
