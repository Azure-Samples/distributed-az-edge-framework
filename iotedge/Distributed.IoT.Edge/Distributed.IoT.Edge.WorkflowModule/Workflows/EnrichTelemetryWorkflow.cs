namespace Distributed.IoT.Edge.WorkflowModule.Workflows;

using Dapr.Workflow;

public class EnrichTelemetryWorkflow : Workflow<string, bool>
{
    public override Task<bool> RunAsync(WorkflowContext context, string input)
    {
        throw new NotImplementedException();
    }
}
