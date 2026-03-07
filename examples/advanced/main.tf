###############################################################################
# Advanced Example — FIFO, DLQ, KMS, Message Filtering
###############################################################################

provider "aws" {
  region = "us-east-1"
}

module "messaging" {
  source = "../../"

  tags = {
    Environment = "staging"
    Team        = "platform"
  }

  # FIFO SNS Topic with KMS encryption
  sns_topics = {
    "order-events" = {
      display_name                = "Order Events"
      fifo_topic                  = true
      content_based_deduplication = true
      kms_master_key_id           = "alias/sns-key"
    }
  }

  # Dead-letter queues
  dead_letter_queues = {
    "order-processor-dlq" = {
      fifo_queue                = true
      message_retention_seconds = 1209600
      kms_master_key_id         = "alias/sqs-key"
    }
  }

  # FIFO SQS queues with DLQ and KMS
  sqs_queues = {
    "order-processor" = {
      fifo_queue                 = true
      content_based_deduplication = true
      visibility_timeout_seconds = 120
      kms_master_key_id          = "alias/sqs-key"
      deduplication_scope        = "messageGroup"
      fifo_throughput_limit      = "perMessageGroupId"
      redrive_policy = {
        dead_letter_target_arn = module.messaging.dlq_arns["order-processor-dlq"]
        max_receive_count      = 3
      }
    }
  }

  # Subscriptions with message filtering
  sns_subscriptions = {
    "high-priority-orders" = {
      topic_arn            = module.messaging.sns_topic_arns["order-events"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["order-processor"]
      raw_message_delivery = true
      filter_policy_scope  = "MessageAttributes"
      filter_policy = jsonencode({
        priority = ["high", "critical"]
        type     = [{ prefix = "order." }]
      })
    }
  }

  # Queue policy for SNS -> SQS
  sqs_sns_policies = {
    "order-processor-policy" = {
      queue_url  = module.messaging.sqs_queue_urls["order-processor"]
      queue_arn  = module.messaging.sqs_queue_arns["order-processor"]
      topic_arns = [module.messaging.sns_topic_arns["order-events"]]
    }
  }
}

output "sns_topic_arns" {
  value = module.messaging.sns_topic_arns
}

output "sqs_queue_arns" {
  value = module.messaging.sqs_queue_arns
}

output "dlq_arns" {
  value = module.messaging.dlq_arns
}
