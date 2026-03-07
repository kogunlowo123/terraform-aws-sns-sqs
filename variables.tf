###############################################################################
# General
###############################################################################

variable "tags" {
  description = "Common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

###############################################################################
# SNS Topics
###############################################################################

variable "sns_topics" {
  description = <<-EOT
    Map of SNS topics to create.
    Key is the topic name.
    EOT
  type = map(object({
    display_name                   = optional(string, "")
    fifo_topic                     = optional(bool, false)
    content_based_deduplication    = optional(bool, false)
    kms_master_key_id              = optional(string, null)
    signature_version              = optional(number, null)
    tracing_config                 = optional(string, null)
    delivery_policy                = optional(string, null)
    policy                         = optional(string, null)
    tags                           = optional(map(string), {})
    archive_policy                 = optional(string, null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.sns_topics :
      !v.content_based_deduplication || v.fifo_topic
    ])
    error_message = "content_based_deduplication can only be enabled for FIFO topics."
  }
}

###############################################################################
# SQS Queues
###############################################################################

variable "sqs_queues" {
  description = <<-EOT
    Map of SQS queues to create.
    Key is the queue name.
    EOT
  type = map(object({
    fifo_queue                     = optional(bool, false)
    content_based_deduplication    = optional(bool, false)
    delay_seconds                  = optional(number, 0)
    max_message_size               = optional(number, 262144)
    message_retention_seconds      = optional(number, 345600)
    receive_wait_time_seconds      = optional(number, 0)
    visibility_timeout_seconds     = optional(number, 30)
    kms_master_key_id              = optional(string, null)
    kms_data_key_reuse_period_seconds = optional(number, 300)
    sqs_managed_sse_enabled        = optional(bool, true)
    deduplication_scope             = optional(string, null)
    fifo_throughput_limit           = optional(string, null)
    policy                         = optional(string, null)
    tags                           = optional(map(string), {})

    redrive_policy = optional(object({
      dead_letter_target_arn = string
      max_receive_count      = optional(number, 5)
    }), null)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.sqs_queues :
      v.visibility_timeout_seconds >= 0 && v.visibility_timeout_seconds <= 43200
    ])
    error_message = "visibility_timeout_seconds must be between 0 and 43200."
  }

  validation {
    condition = alltrue([
      for k, v in var.sqs_queues :
      v.message_retention_seconds >= 60 && v.message_retention_seconds <= 1209600
    ])
    error_message = "message_retention_seconds must be between 60 and 1209600 (14 days)."
  }

  validation {
    condition = alltrue([
      for k, v in var.sqs_queues :
      v.max_message_size >= 1024 && v.max_message_size <= 262144
    ])
    error_message = "max_message_size must be between 1024 and 262144 (256 KB)."
  }
}

###############################################################################
# Dead-Letter Queues
###############################################################################

variable "dead_letter_queues" {
  description = <<-EOT
    Map of SQS dead-letter queues to create.
    Key is the queue name.
    EOT
  type = map(object({
    fifo_queue                  = optional(bool, false)
    message_retention_seconds   = optional(number, 1209600)
    kms_master_key_id           = optional(string, null)
    sqs_managed_sse_enabled     = optional(bool, true)
    visibility_timeout_seconds  = optional(number, 30)
    tags                        = optional(map(string), {})
  }))
  default = {}
}

###############################################################################
# SNS Subscriptions
###############################################################################

variable "sns_subscriptions" {
  description = <<-EOT
    Map of SNS subscriptions to create.
    Key is a logical name.
    EOT
  type = map(object({
    topic_arn             = string
    protocol              = string
    endpoint              = string
    raw_message_delivery  = optional(bool, false)
    filter_policy         = optional(string, null)
    filter_policy_scope   = optional(string, null)
    redrive_policy        = optional(string, null)
    delivery_policy       = optional(string, null)
    confirmation_timeout_in_minutes = optional(number, null)
    endpoint_auto_confirms          = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.sns_subscriptions :
      contains(["sqs", "lambda", "http", "https", "email", "email-json", "sms", "application", "firehose"], v.protocol)
    ])
    error_message = "Protocol must be one of: sqs, lambda, http, https, email, email-json, sms, application, firehose."
  }
}

###############################################################################
# SQS Queue Policies (for SNS -> SQS)
###############################################################################

variable "sqs_sns_policies" {
  description = <<-EOT
    Map of SQS queue policies that grant SNS topics permission to send messages.
    Key is a logical name.
    EOT
  type = map(object({
    queue_url       = string
    queue_arn       = string
    topic_arns      = list(string)
    source_account  = optional(string, null)
  }))
  default = {}
}

###############################################################################
# CloudWatch Alarms
###############################################################################

variable "cloudwatch_alarms" {
  description = <<-EOT
    Configuration for CloudWatch alarms on SQS queues.
    EOT
  type = object({
    enabled              = optional(bool, false)
    alarm_actions        = optional(list(string), [])
    ok_actions           = optional(list(string), [])
    queue_depth_threshold     = optional(number, 1000)
    dlq_depth_threshold       = optional(number, 1)
    oldest_message_threshold  = optional(number, 3600)
    evaluation_periods        = optional(number, 2)
    period                    = optional(number, 300)
    tags                      = optional(map(string), {})
  })
  default = {
    enabled = false
  }
}
