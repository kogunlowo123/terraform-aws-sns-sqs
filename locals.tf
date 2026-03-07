locals {
  # Merge common tags with per-resource tags
  sns_topic_tags = {
    for k, v in var.sns_topics : k => merge(var.tags, v.tags)
  }

  sqs_queue_tags = {
    for k, v in var.sqs_queues : k => merge(var.tags, v.tags)
  }

  dlq_tags = {
    for k, v in var.dead_letter_queues : k => merge(var.tags, v.tags)
  }

  # Build ARN maps for outputs
  sns_topic_arns = {
    for k, v in aws_sns_topic.this : k => v.arn
  }

  sqs_queue_arns = {
    for k, v in aws_sqs_queue.this : k => v.arn
  }

  sqs_queue_urls = {
    for k, v in aws_sqs_queue.this : k => v.url
  }

  dlq_arns = {
    for k, v in aws_sqs_queue.dead_letter : k => v.arn
  }

  dlq_urls = {
    for k, v in aws_sqs_queue.dead_letter : k => v.url
  }
}
