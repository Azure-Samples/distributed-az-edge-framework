using Dapr.AppCallback.Autogen.Grpc.v1;
using Dapr.Client;
using Dapr.Client.Autogen.Grpc.v1;
using Dapr.Workflow;
using Distributed.IoT.Edge.WorkflowModule.Workflows;
using Google.Protobuf.WellKnownTypes;
using Grpc.Core;

namespace Distributed.IoT.Edge.WorkflowModule.Services
{
    public class SubscriptionService : AppCallback.AppCallbackBase
    {
        private readonly ILogger<SubscriptionService> _logger;
        private readonly DaprClient _daprClient;
        private readonly WorkflowEngineClient _workflowClient;
        private readonly string _receiverPubsubName;
        private readonly string _receiverPubsubTopicName;

        public SubscriptionService(
            ILogger<SubscriptionService> logger,
            DaprClient daprClient,
            WorkflowEngineClient workflowClient,
            WorkflowParameters parameters)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _daprClient = daprClient ?? throw new ArgumentNullException(nameof(daprClient));
            _workflowClient = workflowClient ?? throw new ArgumentNullException(nameof(workflowClient));
            if (parameters == null)
            {
                throw new ArgumentNullException(nameof(parameters));
            }

            _receiverPubsubName = parameters.ReceiverPubSubName ??
                                  throw new ArgumentNullException(
                                      nameof(parameters.ReceiverPubSubName),
                                      "Parameter cannot be null.");
            _receiverPubsubTopicName = parameters.ReceiverPubSubTopicName ??
                                       throw new ArgumentNullException(
                                           nameof(parameters.ReceiverPubSubTopicName),
                                           "Parameter cannot be null.");
        }

        public override Task<ListTopicSubscriptionsResponse> ListTopicSubscriptions(
            Empty request,
            ServerCallContext context)
        {
            _logger.LogInformation("Receiving subscription list");
            var subscriptionsResponse = new ListTopicSubscriptionsResponse
            {
                Subscriptions =
                {
                    new TopicSubscription()
                    {
                        PubsubName = _receiverPubsubName, Topic = _receiverPubsubTopicName
                    }
                }
            };

            return Task.FromResult(subscriptionsResponse);
        }

        public override async Task<TopicEventResponse> OnTopicEvent(
            TopicEventRequest request,
            ServerCallContext context)
        {
            if (request is null)
            {
                throw new ArgumentNullException(nameof(request));
            }

            var topicString = request.Data.ToStringUtf8();

            _logger.LogTrace($"Sending event to workflow, object string: {topicString}");
            await Task.Delay(30);

            // starting workflow to enrich and transform the data
            // await _workflowClient.ScheduleNewWorkflowAsync(
            //     name: nameof(EnrichTelemetryWorkflow),
            //     instanceId: request.Id,
            //     input: topicString);

            // Depending on the status return dapr side will either retry or drop the message from underlying pubsub.
            return new TopicEventResponse() { Status = TopicEventResponse.Types.TopicEventResponseStatus.Success };
        }
    }
}
