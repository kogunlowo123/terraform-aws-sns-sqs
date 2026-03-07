# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-15

### Added

- SNS topic creation for standard and FIFO topic types
- SNS topic KMS encryption with configurable master key
- SNS delivery policy configuration
- SNS topic access policy support
- SQS queue creation for standard and FIFO queue types
- SQS queue KMS encryption with data key reuse period
- SQS managed SSE encryption support
- FIFO queue deduplication scope and throughput limit configuration
- Long polling support via receive wait time
- Message delay and retention configuration
- Dead-letter queue creation with independent configuration
- Redrive policy for automatic DLQ routing with max receive count
- SNS subscription management for SQS, HTTPS, email, Lambda, and Firehose protocols
- Raw message delivery for SQS subscriptions
- Message filtering policies with attribute and body scope
- Subscription redrive policies for SNS-level dead-letter handling
- SQS queue access policies for SNS publish authorization
- CloudWatch metric alarm for queue depth monitoring
- CloudWatch metric alarm for dead-letter queue depth
- CloudWatch metric alarm for oldest message age
- Comprehensive input validation for queue parameters and protocols
- Basic, advanced, and complete usage examples
