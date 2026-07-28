resource "aws_cloudwatch_log_group" "send_email_logs" {
  name              = "/aws/lambda/send-email"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_log_metric_filter" "feedbacks_recebidos" {
  name           = "feedbacks-recebidos-count"
  pattern        = "\"Persistindo feedback ID\""
  log_group_name = aws_cloudwatch_log_group.receive_feedback_logs.name

  metric_transformation {
    name          = "TotalFeedbacksRecebidos"
    namespace     = "FeedbackPlatform/Business"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "feedbacks_criticos" {
  name           = "feedbacks-criticos-count"
  pattern        = "\"urgencia='ALTA'\""
  log_group_name = aws_cloudwatch_log_group.evaluate_urgency_logs.name

  metric_transformation {
    name          = "FeedbacksCriticosAltaUrgencia"
    namespace     = "FeedbackPlatform/Business"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "relatorios_gerados" {
  name           = "relatorios-gerados-count"
  pattern        = "\"Relatório gerado e\""
  log_group_name = aws_cloudwatch_log_group.generate_report_logs.name

  metric_transformation {
    name          = "RelatoriosGerados"
    namespace     = "FeedbackPlatform/Business"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_log_metric_filter" "emails_enviados" {
  name           = "emails-enviados-count"
  pattern        = "\"E-mail enviado com sucesso!\""
  log_group_name = aws_cloudwatch_log_group.send_email_logs.name

  metric_transformation {
    name          = "EmailsEnviadosSucesso"
    namespace     = "FeedbackPlatform/Business"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "critical_feedbacks_alarm" {
  alarm_name          = "feedback-high-critical-urgency-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FeedbacksCriticosAltaUrgencia"
  namespace           = "FeedbackPlatform/Business"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_description   = "Alerta disparado quando 3 ou mais avaliacoes criticas (ALTA) sao recebidas em 5 minutos"
  alarm_actions       = [aws_sns_topic.send_notification.arn]

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_dashboard" "business_dashboard" {
  dashboard_name = "FeedbackPlatform-Business-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["FeedbackPlatform/Business", "TotalFeedbacksRecebidos", { label = "Feedbacks Recebidos (Total)" }],
            ["FeedbackPlatform/Business", "FeedbacksCriticosAltaUrgencia", { label = "Avaliações Críticas (ALTA)", color = "#d62728" }]
          ]
          period = 300
          stat   = "Sum"
          region = "sa-east-1"
          title  = "📊 Métricas de Negócio - Recebimento e Urgência de Feedbacks"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["FeedbackPlatform/Business", "EmailsEnviadosSucesso", { label = "E-mails Enviados via SES", color = "#2ca02c" }],
            ["FeedbackPlatform/Business", "RelatoriosGerados", { label = "Relatórios Gerados", color = "#1f77b4" }]
          ]
          period = 300
          stat   = "Sum"
          region = "sa-east-1"
          title  = "📧 Métricas de Notificação e Relatórios"
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "receive-feedback", { label = "receive-feedback" }],
            ["AWS/Lambda", "Invocations", "FunctionName", "evaluate-urgency", { label = "evaluate-urgency" }],
            ["AWS/Lambda", "Invocations", "FunctionName", "generate-report", { label = "generate-report" }],
            ["AWS/Lambda", "Invocations", "FunctionName", "send-email", { label = "send-email" }]
          ]
          period = 300
          stat   = "Sum"
          region = "sa-east-1"
          title  = "⚡ Saúde Operacional - Invocações de Funções Lambda"
          view   = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          query  = "SOURCE '/aws/lambda/receive-feedback' | fields @timestamp, @message | sort @timestamp desc | limit 20"
          region = "sa-east-1"
          title  = "📜 Observabilidade em Tempo Real - Últimos Logs de Feedbacks Recebidos"
          view   = "table"
        }
      }
    ]
  })
}
