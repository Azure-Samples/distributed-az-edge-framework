namespace Distributed.IoT.Edge.WorkflowModule.Services
{
    using Dapr.AppCallback.Autogen.Grpc.v1;
    using Dapr.Workflow;
    using Distributed.IoT.Edge.WorkflowModule.Workflows;
    using Google.Protobuf.WellKnownTypes;
    using Grpc.Core;

    public class SubscriptionService : AppCallback.AppCallbackBase
    {
        private readonly ILogger<SubscriptionService> _logger;
        private readonly DaprWorkflowClient _workflowClient;
        private readonly string _receiverPubsubName;
        private readonly string _receiverPubsubTopicName;

        public SubscriptionService(
            ILogger<SubscriptionService> logger,
            DaprWorkflowClient workflowClient,
            WorkflowParameters parameters)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _workflowClient = workflowClient ?? throw new ArgumentNullException(nameof(workflowClient));            
            if (parameters == null)
            {
                throw new ArgumentNullException(nameof(parameters));
            }

            _receiverPubsubName = parameters.ReceiverPubSubName;
            _receiverPubsubTopicName = parameters.ReceiverPubSubTopicName;

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

            var topicString = request.Extensions.ToString();
            _logger.LogTrace($"Sending event to workflow, object json: {topicString}");

            var instanceId = Guid.NewGuid().ToString();
            // starting workflow to enrich and transform the data
            await _workflowClient.ScheduleNewWorkflowAsync(
                name: nameof(EnrichTelemetryWorkflow),
                instanceId: instanceId,
                input: topicString);

            // Wait a second to allow workflow to start
            await Task.Delay(TimeSpan.FromSeconds(1));
            WorkflowState state = await _workflowClient.GetWorkflowStateAsync(
                instanceId: instanceId,
                getInputsAndOutputs: true);

            _logger.LogTrace($"Your workflow {request.Id} has started. Here is the status of the workflow: {state.RuntimeStatus}");
            while (!state.IsWorkflowCompleted)
            {
                await Task.Delay(TimeSpan.FromSeconds(5));
                state = await _workflowClient.GetWorkflowStateAsync(
                    instanceId: instanceId,
                    getInputsAndOutputs: true);
                _logger.LogTrace($"State of workflow {instanceId} is: {state.RuntimeStatus}");
            }

            // Depending on the status return dapr side will either retry or drop the message from underlying pubsub.
            return new TopicEventResponse() { Status = TopicEventResponse.Types.TopicEventResponseStatus.Success };
        }
    }
}
