output "send_notification_topic_arn" {
  description = "ARN do tópico SNS de envio de notificações"
  value       = aws_sns_topic.send_notification.arn
}
