resource "aws_sns_topic" "send_notification" {
  name = "send-notification-topic"

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic" "feedback_notification" {
  name = "feedback-notification-topic"

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "critical_alarm_email" {
  topic_arn = aws_sns_topic.send_notification.arn
  protocol  = "email"
  endpoint  = var.ses_source_email
}
