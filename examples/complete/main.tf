###############################################################################
# Complete Example — All SNS/SQS Features with CloudWatch Alarms
###############################################################################

provider "aws" {
  region = "us-east-1"
}

module "messaging" {
  source = "../../"

  tags = {
    Environment = "production"
    Team        = "platform"
    ManagedBy   = "terraform"
  }

  # ---------- SNS Topics ----------
  sns_topics = {
    # Standard topic with KMS
    "order-notifications" = {
      display_name      = "Order Notifications"
      kms_master_key_id = "alias/sns-cmk"
      tracing_config    = "Active"
      delivery_policy = jsonencode({
        http = {
          defaultHealthyRetryPolicy = {
            minDelayTarget     = 20
            maxDelayTarget     = 20
            numRetries         = 3
            numMaxDelayRetries = 0
            numNoDelayRetries  = 0
            backoffFunction    = "linear"
          }
          disableSubscriptionOverrides = false
        }
      })
      tags = {
        Domain = "orders"
      }
    }

    # FIFO topic for ordered processing
    "payment-events" = {
      display_name                = "Payment Events"
      fifo_topic                  = true
      content_based_deduplication = true
      kms_master_key_id           = "alias/sns-cmk"
      tags = {
        Domain = "payments"
      }
    }

    # Standard topic for system alerts
    "system-alerts" = {
      display_name = "System Alerts"
      tags = {
        Domain = "operations"
      }
    }
  }

  # ---------- Dead-Letter Queues ----------
  dead_letter_queues = {
    "order-processor-dlq" = {
      message_retention_seconds = 1209600
      kms_master_key_id         = "alias/sqs-cmk"
      tags = {
        Purpose = "dead-letter"
        Domain  = "orders"
      }
    }
    "payment-processor-dlq" = {
      fifo_queue                = true
      message_retention_seconds = 1209600
      kms_master_key_id         = "alias/sqs-cmk"
      tags = {
        Purpose = "dead-letter"
        Domain  = "payments"
      }
    }
    "alert-handler-dlq" = {
      message_retention_seconds = 604800
      tags = {
        Purpose = "dead-letter"
        Domain  = "operations"
      }
    }
  }

  # ---------- SQS Queues ----------
  sqs_queues = {
    # Standard queue with DLQ and KMS
    "order-processor" = {
      visibility_timeout_seconds = 120
      message_retention_seconds  = 345600
      receive_wait_time_seconds  = 20
      kms_master_key_id          = "alias/sqs-cmk"
      kms_data_key_reuse_period_seconds = 600
      redrive_policy = {
        dead_letter_target_arn = module.messaging.dlq_arns["order-processor-dlq"]
        max_receive_count      = 5
      }
      tags = {
        Domain = "orders"
      }
    }

    # FIFO queue for payment processing
    "payment-processor" = {
      fifo_queue                  = true
      content_based_deduplication = true
      visibility_timeout_seconds  = 300
      kms_master_key_id           = "alias/sqs-cmk"
      deduplication_scope         = "messageGroup"
      fifo_throughput_limit       = "perMessageGroupId"
      redrive_policy = {
        dead_letter_target_arn = module.messaging.dlq_arns["payment-processor-dlq"]
        max_receive_count      = 3
      }
      tags = {
        Domain = "payments"
      }
    }

    # Standard queue with long polling
    "order-analytics" = {
      visibility_timeout_seconds = 60
      message_retention_seconds  = 86400
      receive_wait_time_seconds  = 20
      delay_seconds              = 10
      tags = {
        Domain = "analytics"
      }
    }

    # Alert handler queue
    "alert-handler" = {
      visibility_timeout_seconds = 30
      message_retention_seconds  = 86400
      redrive_policy = {
        dead_letter_target_arn = module.messaging.dlq_arns["alert-handler-dlq"]
        max_receive_count      = 3
      }
      tags = {
        Domain = "operations"
      }
    }
  }

  # ---------- SNS Subscriptions ----------
  sns_subscriptions = {
    # SQS subscription with filtering
    "orders-to-processor" = {
      topic_arn            = module.messaging.sns_topic_arns["order-notifications"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["order-processor"]
      raw_message_delivery = true
      filter_policy_scope  = "MessageAttributes"
      filter_policy = jsonencode({
        event_type = ["order.created", "order.updated"]
      })
      redrive_policy = jsonencode({
        deadLetterTargetArn = module.messaging.dlq_arns["order-processor-dlq"]
      })
    }

    # SQS analytics subscription — all messages
    "orders-to-analytics" = {
      topic_arn            = module.messaging.sns_topic_arns["order-notifications"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["order-analytics"]
      raw_message_delivery = true
    }

    # FIFO SQS subscription
    "payments-to-processor" = {
      topic_arn            = module.messaging.sns_topic_arns["payment-events"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["payment-processor"]
      raw_message_delivery = true
    }

    # Email subscription for alerts
    "alerts-to-email" = {
      topic_arn = module.messaging.sns_topic_arns["system-alerts"]
      protocol  = "email"
      endpoint  = "ops-team@example.com"
    }

    # HTTPS subscription for alerts
    "alerts-to-webhook" = {
      topic_arn            = module.messaging.sns_topic_arns["system-alerts"]
      protocol             = "https"
      endpoint             = "https://hooks.example.com/alerts"
      endpoint_auto_confirms = true
      filter_policy_scope  = "MessageAttributes"
      filter_policy = jsonencode({
        severity = ["critical", "high"]
      })
    }

    # SQS subscription for alert handling
    "alerts-to-handler" = {
      topic_arn            = module.messaging.sns_topic_arns["system-alerts"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["alert-handler"]
      raw_message_delivery = true
    }
  }

  # ---------- SQS Queue Policies ----------
  sqs_sns_policies = {
    "order-processor-policy" = {
      queue_url  = module.messaging.sqs_queue_urls["order-processor"]
      queue_arn  = module.messaging.sqs_queue_arns["order-processor"]
      topic_arns = [module.messaging.sns_topic_arns["order-notifications"]]
    }
    "order-analytics-policy" = {
      queue_url  = module.messaging.sqs_queue_urls["order-analytics"]
      queue_arn  = module.messaging.sqs_queue_arns["order-analytics"]
      topic_arns = [module.messaging.sns_topic_arns["order-notifications"]]
    }
    "payment-processor-policy" = {
      queue_url  = module.messaging.sqs_queue_urls["payment-processor"]
      queue_arn  = module.messaging.sqs_queue_arns["payment-processor"]
      topic_arns = [module.messaging.sns_topic_arns["payment-events"]]
    }
    "alert-handler-policy" = {
      queue_url  = module.messaging.sqs_queue_urls["alert-handler"]
      queue_arn  = module.messaging.sqs_queue_arns["alert-handler"]
      topic_arns = [module.messaging.sns_topic_arns["system-alerts"]]
    }
  }

  # ---------- CloudWatch Alarms ----------
  cloudwatch_alarms = {
    enabled                  = true
    alarm_actions            = ["arn:aws:sns:us-east-1:123456789012:ops-alerts"]
    ok_actions               = ["arn:aws:sns:us-east-1:123456789012:ops-alerts"]
    queue_depth_threshold    = 5000
    dlq_depth_threshold      = 1
    oldest_message_threshold = 1800
    evaluation_periods       = 2
    period                   = 300
    tags = {
      AlertType = "infrastructure"
    }
  }
}

# ---------- Outputs ----------
output "sns_topic_arns" {
  value = module.messaging.sns_topic_arns
}

output "sqs_queue_arns" {
  value = module.messaging.sqs_queue_arns
}

output "sqs_queue_urls" {
  value = module.messaging.sqs_queue_urls
}

output "dlq_arns" {
  value = module.messaging.dlq_arns
}

output "sns_subscription_arns" {
  value = module.messaging.sns_subscription_arns
}

output "account_id" {
  value = module.messaging.account_id
}
