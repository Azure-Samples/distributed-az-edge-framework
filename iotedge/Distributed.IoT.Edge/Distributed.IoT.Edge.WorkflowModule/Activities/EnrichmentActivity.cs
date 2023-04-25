namespace WorkflowConsoleApp.Activities
{
    using System;
    using System.Threading.Tasks;
    using Dapr.Client;
    using Dapr.Workflow;
    using Distributed.IoT.Edge.WorkflowModule;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;

    public class EnrichmentActivity : WorkflowActivity<string, string>
    {
        private readonly ILogger<EnrichmentActivity> _logger;

        public EnrichmentActivity(ILogger<EnrichmentActivity> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        }

        public override Task<string> RunAsync(WorkflowActivityContext context, string input)
        {
            _logger.LogInformation($"Enriching data for raw input: {input}");
            input =
                "{\"ambient\":{\"temperature\":89.523494,\"pressure\":34.344628},\"machine\":{\"pressure\":85.508304,\"temperature\":16.033667}}";
            var data = JsonConvert.DeserializeObject<dynamic>(input);
            decimal.TryParse(data?.ambient.temperature.ToString(), out decimal temperature);
            string condition = temperature switch
            {
                < 0 => "Freezing",
                >= 0 and < 20 => "Cold",
                >= 20 and < 40 => "Warm",
                >= 40 and < 60 => "Hot",
                >= 60 => "Overheating"
            };

            if (data != null)
            {
                data.ambient.condition = condition;
                return Task.FromResult<string>(data?.ToString());
            }

            return Task.FromResult(string.Empty);
        }
    }
}
