output "sns_topic_arns" {
  description = "Map of SNS topic names to their ARNs."
  value       = { for k, v in aws_sns_topic.this : k => v.arn }
}

output "sns_topic_ids" {
  description = "Map of SNS topic names to their IDs."
  value       = { for k, v in aws_sns_topic.this : k => v.id }
}

output "sns_topic_names" {
  description = "Map of SNS topic logical names to their actual names."
  value       = { for k, v in aws_sns_topic.this : k => v.name }
}

output "sns_topic_owners" {
  description = "Map of SNS topic names to their owner account IDs."
  value       = { for k, v in aws_sns_topic.this : k => v.owner }
}

output "sqs_queue_arns" {
  description = "Map of SQS queue names to their ARNs."
  value       = { for k, v in aws_sqs_queue.this : k => v.arn }
}

output "sqs_queue_ids" {
  description = "Map of SQS queue names to their IDs (URLs)."
  value       = { for k, v in aws_sqs_queue.this : k => v.id }
}

output "sqs_queue_urls" {
  description = "Map of SQS queue names to their URLs."
  value       = { for k, v in aws_sqs_queue.this : k => v.url }
}

output "sqs_queue_names" {
  description = "Map of SQS queue logical names to their actual names."
  value       = { for k, v in aws_sqs_queue.this : k => v.name }
}

output "dlq_arns" {
  description = "Map of dead-letter queue names to their ARNs."
  value       = { for k, v in aws_sqs_queue.dead_letter : k => v.arn }
}

output "dlq_ids" {
  description = "Map of dead-letter queue names to their IDs (URLs)."
  value       = { for k, v in aws_sqs_queue.dead_letter : k => v.id }
}

output "dlq_urls" {
  description = "Map of dead-letter queue names to their URLs."
  value       = { for k, v in aws_sqs_queue.dead_letter : k => v.url }
}

output "sns_subscription_arns" {
  description = "Map of SNS subscription logical names to their ARNs."
  value       = { for k, v in aws_sns_topic_subscription.this : k => v.arn }
}

output "sns_subscription_ids" {
  description = "Map of SNS subscription logical names to their IDs."
  value       = { for k, v in aws_sns_topic_subscription.this : k => v.id }
}

output "account_id" {
  description = "The AWS account ID."
  value       = data.aws_caller_identity.this.account_id
}

output "region" {
  description = "The AWS region."
  value       = data.aws_region.this.name
}
