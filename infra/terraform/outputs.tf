output "send_notification_topic_arn" {
  description = "ARN do tópico SNS de envio de notificações"
  value       = aws_sns_topic.send_notification.arn
}

output "feedback_notification_topic_arn" {
  description = "ARN do tópico SNS de feedback de notificações"
  value       = aws_sns_topic.feedback_notification.arn
}

output "feedbacks_table_arn" {
  description = "ARN da tabela DynamoDB de feedbacks"
  value       = aws_dynamodb_table.feedbacks.arn
}

output "feedbacks_table_name" {
  description = "Nome da tabela DynamoDB de feedbacks"
  value       = aws_dynamodb_table.feedbacks.name
}

output "feedbacks_stream_arn" {
  description = "ARN do DynamoDB Stream da tabela de feedbacks"
  value       = aws_dynamodb_table.feedbacks.stream_arn
}

output "feedbacks_gsi_name" {
  description = "Nome do Global Secondary Index (DateIndex)"
  value       = "DateIndex"
}

output "notify_email_queue_arn" {
  description = "ARN da fila SQS de notificação por email"
  value       = aws_sqs_queue.notify_email.arn
}

output "notify_email_queue_url" {
  description = "URL da fila SQS de notificação por email"
  value       = aws_sqs_queue.notify_email.url
}
