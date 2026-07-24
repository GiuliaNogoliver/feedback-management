resource "aws_sns_topic" "send_notification" {
  name = "send-notification-topic"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic" "feedback_notification" {
  name = "feedback-notification-topic"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
