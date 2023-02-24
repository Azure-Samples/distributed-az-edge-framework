namespace Distributed.IoT.Edge.DataGatewayModule.Services
{
    using Dapr.AppCallback.Autogen.Grpc.v1;
    using Dapr.Client;
    using Dapr.Client.Autogen.Grpc.v1;
    using Google.Protobuf.WellKnownTypes;
    using Grpc.Core;

    public class SubscriptionService : AppCallback.AppCallbackBase
    {
        private readonly ILogger<SubscriptionService> _logger;
        private readonly DaprClient _daprClient;
        private readonly string _receiverPubsubName;
        private readonly string _receiverPubsubTopicName;
        private readonly string _senderPubsubName;
        private readonly string _senderPubsubTopicName;

        public SubscriptionService(
            ILogger<SubscriptionService> logger,
            DaprClient daprClient,
            string? receiverPubsubName,
            string? receiverPubsubTopicName,
            string? senderPubsubName,
            string? senderPubsubTopicName)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _daprClient = daprClient ?? throw new ArgumentNullException(nameof(daprClient));
            _receiverPubsubName = receiverPubsubName ?? throw new ArgumentNullException(nameof(receiverPubsubName));
            _receiverPubsubTopicName = receiverPubsubTopicName ?? throw new ArgumentNullException(nameof(receiverPubsubTopicName));
            _senderPubsubName = senderPubsubName ?? throw new ArgumentNullException(nameof(senderPubsubName));
            _senderPubsubTopicName = senderPubsubTopicName ?? throw new ArgumentNullException(nameof(senderPubsubTopicName));
        }

        public override Task<ListTopicSubscriptionsResponse> ListTopicSubscriptions(Empty request, ServerCallContext context)
        {
            var subscriptionsResponse = new ListTopicSubscriptionsResponse();

            subscriptionsResponse.Subscriptions.Add(new TopicSubscription
            {
                PubsubName = _receiverPubsubName,
                Topic = _receiverPubsubTopicName
            });

            return Task.FromResult(subscriptionsResponse);
        }

        public override async Task<TopicEventResponse> OnTopicEvent(TopicEventRequest request, ServerCallContext context)
        {
            if (request is null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            var topicString = request.Data.ToStringUtf8();
            _logger.LogTrace($"Sending event to message layer, pubsub name {_senderPubsubName}, topic {_senderPubsubTopicName}, object string: {topicString}");

            // TODO: Find way to specify partition key to allow ordering of messages within a defined scope, currently events are distributed evenly accross partitions.
            await _daprClient.PublishEventAsync(_senderPubsubName, _senderPubsubTopicName, topicString);

            // Depending on the status return dapr side will either retry or drop the message from underlying pubsub.
            return new TopicEventResponse() { Status = TopicEventResponse.Types.TopicEventResponseStatus.Success };
        }
    }
}
