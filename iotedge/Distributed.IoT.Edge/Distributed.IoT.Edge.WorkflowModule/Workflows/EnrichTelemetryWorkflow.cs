namespace Distributed.IoT.Edge.WorkflowModule.Workflows;

using Dapr.Workflow;
using WorkflowConsoleApp.Activities;

public class EnrichTelemetryWorkflow : Workflow<string, bool>
{
    public override async Task<bool> RunAsync(WorkflowContext? context, string input)
    {
        if (context == null)
        {
            return false;
        }

        var enrichedData = await context.CallActivityAsync<string>(nameof(EnrichmentActivity), input);
        if (string.IsNullOrEmpty(enrichedData))
        {
            return false;
        }

        return await context.CallActivityAsync<bool>(nameof(PublishActivity), enrichedData);
    }
}
