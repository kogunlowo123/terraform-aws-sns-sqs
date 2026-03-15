module "test" {
  source = "../"

  tags = {
    Project     = "sns-sqs-test"
    Environment = "test"
  }

  # SNS Topics
  sns_topics = {
    "test-notifications" = {
      display_name = "Test Notifications"
      fifo_topic   = false
    }
    "test-orders.fifo" = {
      display_name                = "Test Orders FIFO"
      fifo_topic                  = true
      content_based_deduplication = true
    }
  }

  # Dead-Letter Queues
  dead_letter_queues = {
    "test-dlq" = {
      message_retention_seconds  = 1209600
      sqs_managed_sse_enabled    = true
      visibility_timeout_seconds = 30
    }
  }

  # SQS Queues
  sqs_queues = {
    "test-processing-queue" = {
      delay_seconds              = 0
      max_message_size           = 262144
      message_retention_seconds  = 345600
      receive_wait_time_seconds  = 10
      visibility_timeout_seconds = 60
      sqs_managed_sse_enabled    = true
    }
  }

  # CloudWatch Alarms
  cloudwatch_alarms = {
    enabled                  = false
    queue_depth_threshold    = 1000
    dlq_depth_threshold      = 1
    oldest_message_threshold = 3600
  }
}
