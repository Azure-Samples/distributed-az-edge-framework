namespace WorkflowConsoleApp.Activities
{
    using System;
    using System.Threading.Tasks;
    using Dapr.Workflow;
    using Microsoft.Extensions.Logging;
    using Newtonsoft.Json;

    public class EnrichmentActivity : WorkflowActivity<string, string>
    {
        private readonly ILogger<EnrichmentActivity> _logger;

        public EnrichmentActivity(ILogger<EnrichmentActivity> logger)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _logger.LogTrace($"Entering: {nameof(EnrichmentActivity)}");
        }

        public override Task<string> RunAsync(WorkflowActivityContext context, string input)
        {
            _logger.LogTrace($"Enriching data for raw input: {input}");
            var data = JsonConvert.DeserializeObject<dynamic>(input);
            if (data == null)
            {
                return Task.FromResult(string.Empty);
            }

            decimal.TryParse(data?.ambient?.temperature?.ToString(), out decimal temperature);
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
            }

            return Task.FromResult<string>(data?.ToString());
       }
    }
}
