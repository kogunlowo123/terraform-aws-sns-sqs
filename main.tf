###############################################################################
# SNS Topics
###############################################################################

resource "aws_sns_topic" "this" {
  for_each = var.sns_topics

  name                        = each.value.fifo_topic ? "${each.key}.fifo" : each.key
  display_name                = each.value.display_name
  fifo_topic                  = each.value.fifo_topic
  content_based_deduplication = each.value.content_based_deduplication
  kms_master_key_id           = each.value.kms_master_key_id
  signature_version           = each.value.signature_version
  tracing_config              = each.value.tracing_config
  delivery_policy             = each.value.delivery_policy
  policy                      = each.value.policy
  archive_policy              = each.value.archive_policy
  tags                        = local.sns_topic_tags[each.key]
}

###############################################################################
# SQS Queues
###############################################################################

resource "aws_sqs_queue" "this" {
  for_each = var.sqs_queues

  name                              = each.value.fifo_queue ? "${each.key}.fifo" : each.key
  fifo_queue                        = each.value.fifo_queue
  content_based_deduplication       = each.value.content_based_deduplication
  delay_seconds                     = each.value.delay_seconds
  max_message_size                  = each.value.max_message_size
  message_retention_seconds         = each.value.message_retention_seconds
  receive_wait_time_seconds         = each.value.receive_wait_time_seconds
  visibility_timeout_seconds        = each.value.visibility_timeout_seconds
  kms_master_key_id                 = each.value.kms_master_key_id
  kms_data_key_reuse_period_seconds = each.value.kms_master_key_id != null ? each.value.kms_data_key_reuse_period_seconds : null
  sqs_managed_sse_enabled           = each.value.kms_master_key_id == null ? each.value.sqs_managed_sse_enabled : null
  deduplication_scope               = each.value.deduplication_scope
  fifo_throughput_limit             = each.value.fifo_throughput_limit
  policy                            = each.value.policy
  tags                              = local.sqs_queue_tags[each.key]

  redrive_policy = each.value.redrive_policy != null ? jsonencode({
    deadLetterTargetArn = each.value.redrive_policy.dead_letter_target_arn
    maxReceiveCount     = each.value.redrive_policy.max_receive_count
  }) : null
}

###############################################################################
# Dead-Letter Queues
###############################################################################

resource "aws_sqs_queue" "dead_letter" {
  for_each = var.dead_letter_queues

  name                        = each.value.fifo_queue ? "${each.key}.fifo" : each.key
  fifo_queue                  = each.value.fifo_queue
  message_retention_seconds   = each.value.message_retention_seconds
  kms_master_key_id           = each.value.kms_master_key_id
  sqs_managed_sse_enabled     = each.value.kms_master_key_id == null ? each.value.sqs_managed_sse_enabled : null
  visibility_timeout_seconds  = each.value.visibility_timeout_seconds
  tags                        = local.dlq_tags[each.key]
}

###############################################################################
# SNS Subscriptions
###############################################################################

resource "aws_sns_topic_subscription" "this" {
  for_each = var.sns_subscriptions

  topic_arn                       = each.value.topic_arn
  protocol                        = each.value.protocol
  endpoint                        = each.value.endpoint
  raw_message_delivery            = each.value.raw_message_delivery
  filter_policy                   = each.value.filter_policy
  filter_policy_scope             = each.value.filter_policy_scope
  redrive_policy                  = each.value.redrive_policy
  delivery_policy                 = each.value.delivery_policy
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
}

###############################################################################
# SQS Queue Policies for SNS -> SQS
###############################################################################

resource "aws_sqs_queue_policy" "sns_to_sqs" {
  for_each = var.sqs_sns_policies

  queue_url = each.value.queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = each.value.queue_arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = each.value.topic_arns
          }
        }
      }
    ]
  })
}

###############################################################################
# CloudWatch Alarms — Queue Depth
###############################################################################

resource "aws_cloudwatch_metric_alarm" "queue_depth" {
  for_each = var.cloudwatch_alarms.enabled ? var.sqs_queues : {}

  alarm_name          = "${each.key}-queue-depth-high"
  alarm_description   = "SQS queue ${each.key} has more than ${var.cloudwatch_alarms.queue_depth_threshold} messages."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cloudwatch_alarms.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.cloudwatch_alarms.period
  statistic           = "Sum"
  threshold           = var.cloudwatch_alarms.queue_depth_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.cloudwatch_alarms.alarm_actions
  ok_actions          = var.cloudwatch_alarms.ok_actions
  tags                = merge(var.tags, var.cloudwatch_alarms.tags)

  dimensions = {
    QueueName = aws_sqs_queue.this[each.key].name
  }
}

###############################################################################
# CloudWatch Alarms — DLQ Depth
###############################################################################

resource "aws_cloudwatch_metric_alarm" "dlq_depth" {
  for_each = var.cloudwatch_alarms.enabled ? var.dead_letter_queues : {}

  alarm_name          = "${each.key}-dlq-messages"
  alarm_description   = "Dead-letter queue ${each.key} has more than ${var.cloudwatch_alarms.dlq_depth_threshold} messages."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cloudwatch_alarms.evaluation_periods
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = var.cloudwatch_alarms.period
  statistic           = "Sum"
  threshold           = var.cloudwatch_alarms.dlq_depth_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.cloudwatch_alarms.alarm_actions
  ok_actions          = var.cloudwatch_alarms.ok_actions
  tags                = merge(var.tags, var.cloudwatch_alarms.tags)

  dimensions = {
    QueueName = aws_sqs_queue.dead_letter[each.key].name
  }
}

###############################################################################
# CloudWatch Alarms — Oldest Message Age
###############################################################################

resource "aws_cloudwatch_metric_alarm" "oldest_message" {
  for_each = var.cloudwatch_alarms.enabled ? var.sqs_queues : {}

  alarm_name          = "${each.key}-oldest-message-age"
  alarm_description   = "SQS queue ${each.key} oldest message exceeds ${var.cloudwatch_alarms.oldest_message_threshold} seconds."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cloudwatch_alarms.evaluation_periods
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = var.cloudwatch_alarms.period
  statistic           = "Maximum"
  threshold           = var.cloudwatch_alarms.oldest_message_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.cloudwatch_alarms.alarm_actions
  ok_actions          = var.cloudwatch_alarms.ok_actions
  tags                = merge(var.tags, var.cloudwatch_alarms.tags)

  dimensions = {
    QueueName = aws_sqs_queue.this[each.key].name
  }
}
