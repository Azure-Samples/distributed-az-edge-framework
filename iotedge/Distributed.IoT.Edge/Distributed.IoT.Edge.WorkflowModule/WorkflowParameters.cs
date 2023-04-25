﻿using CommandLine;

namespace Distributed.IoT.Edge.WorkflowModule
{
    public class WorkflowParameters
    {
        [Option(
            "receiverPubSubName",
            Default = "local-pub-sub",
            Required = false,
            HelpText = "Dapr pubsub messaging component name for receiving messages.")]
        public string? ReceiverPubSubName { get; set; }

        [Option(
            "receiverPubSubTopicName",
            Default = "telemetry",
            Required = false,
            HelpText = "Dapr pubsub messaging topic name for receiving messages.")]
        public string? ReceiverPubSubTopicName { get; set; }

        [Option(
            "senderPubSubName",
            Default = "local-pub-sub",
            Required = false,
            HelpText = "Dapr pubsub messaging component name for sending messages.")]
        public string? SenderPubSubName { get; set; }

        [Option(
            "senderPubSubTopicName",
            Default = "enriched-telemetry",
            Required = false,
            HelpText = "Dapr workflow pubsub messaging topic name for sending messages.")]
        public string? SenderPubSubTopicName { get; set; }
    }
}
