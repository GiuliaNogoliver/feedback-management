resource "aws_sqs_queue" "notify_email_dlq" {
  name                      = "notify-email-queue-dlq"
  message_retention_seconds = 1209600

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue" "notify_email" {
  name                       = "notify-email-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notify_email_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue_policy" "notify_email_policy" {
  queue_url = aws_sqs_queue.notify_email.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.notify_email.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.send_notification.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "email_queue_subscription" {
  topic_arn = aws_sns_topic.send_notification.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notify_email.arn

  filter_policy = jsonencode({
    type_notification = ["EMAIL"]
  })

  filter_policy_scope = "MessageAttributes"
}
