###############################################################################
# Basic Example — SNS Topic with SQS Subscription
###############################################################################

provider "aws" {
  region = "us-east-1"
}

module "messaging" {
  source = "../../"

  tags = {
    Environment = "development"
  }

  sns_topics = {
    "order-notifications" = {
      display_name = "Order Notifications"
    }
  }

  sqs_queues = {
    "order-processor" = {
      visibility_timeout_seconds = 60
      message_retention_seconds  = 345600
    }
  }

  sns_subscriptions = {
    "orders-to-processor" = {
      topic_arn            = module.messaging.sns_topic_arns["order-notifications"]
      protocol             = "sqs"
      endpoint             = module.messaging.sqs_queue_arns["order-processor"]
      raw_message_delivery = true
    }
  }
}

output "sns_topic_arns" {
  value = module.messaging.sns_topic_arns
}

output "sqs_queue_urls" {
  value = module.messaging.sqs_queue_urls
}
