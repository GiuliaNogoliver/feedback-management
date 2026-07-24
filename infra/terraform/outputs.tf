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

output "receive_feedback_lambda_arn" {
  description = "ARN da Lambda receive-feedback"
  value       = aws_lambda_function.receive_feedback.arn
}

output "send_email_lambda_arn" {
  description = "ARN da Lambda send-email"
  value       = aws_lambda_function.send_email.arn
}

output "generate_report_lambda_arn" {
  description = "ARN da Lambda generate-report"
  value       = aws_lambda_function.generate_report.arn
}

output "critical_notification_lambda_arn" {
  description = "ARN da Lambda critical-notification"
  value       = aws_lambda_function.critical_notification.arn
}

output "api_gateway_invoke_url" {
  description = "URL base do API Gateway para envio de avaliações"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/avaliacao"
}

output "eventbridge_schedule_arn" {
  description = "ARN do agendamento EventBridge Scheduler para relatório semanal"
  value       = aws_scheduler_schedule.generate_weekly_report.arn
}

output "eventbridge_schedule_name" {
  description = "Nome do agendamento EventBridge Scheduler para relatório semanal"
  value       = aws_scheduler_schedule.generate_weekly_report.name
}
