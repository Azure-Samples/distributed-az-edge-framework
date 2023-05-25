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
            _logger.LogTrace($"requestPath: {request.Path}");
            _logger.LogTrace($"Sending event to workflow, object json: {topicString}");

            // starting workflow to enrich and transform the data
            await _workflowClient.ScheduleNewWorkflowAsync(
                name: nameof(EnrichTelemetryWorkflow),
                instanceId: request.Id,
                input: topicString);

            // Wait a second to allow workflow to start
            await Task.Delay(TimeSpan.FromSeconds(1));
            WorkflowState state = await _workflowClient.GetWorkflowStateAsync(
                instanceId: request.Id,
                getInputsAndOutputs: true);

            _logger.LogTrace($"Your workflow {request.Id} has started. Here is the status of the workflow: {state.RuntimeStatus}");
            while (!state.IsWorkflowCompleted)
            {
                await Task.Delay(TimeSpan.FromSeconds(5));
                state = await _workflowClient.GetWorkflowStateAsync(
                    instanceId: request.Id,
                    getInputsAndOutputs: true);
                _logger.LogTrace($"State of workflow {request.Id} is: {state.RuntimeStatus}");
            }

            // Depending on the status return dapr side will either retry or drop the message from underlying pubsub.
            return new TopicEventResponse() { Status = TopicEventResponse.Types.TopicEventResponseStatus.Success };
        }
    }
}
