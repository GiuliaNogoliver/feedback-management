# =============================================================================
# Amazon EventBridge Scheduler v2 - Agendamento Semanal
# =============================================================================
#
# Configura o agendamento automático para execução periódica da Lambda
# `generate-report`.
#
# Expressão Cron: cron(0 8 ? * MON *)
# - Minuto: 0
# - Hora: 8 (08:00 AM)
# - Dia do Mês: ? (qualquer)
# - Mês: * (todos)
# - Dia da Semana: MON (Segunda-feira)
# - Ano: * (todos)
# Frequência: Toda Segunda-feira às 08:00 AM UTC.
#
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role para o EventBridge Scheduler
# O EventBridge Scheduler necessita de uma Role com permissão para assumir o
# serviço e invocar a função Lambda de destino.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "scheduler_role" {
  name = "eventbridge-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "scheduler.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy" "scheduler_lambda_policy" {
  name = "eventbridge-scheduler-invoke-lambda-policy"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = local.target_lambda_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Permissão na Lambda (Resource-based Policy)
# Autoriza o serviço scheduler.amazonaws.com a invocar a função generate-report
# -----------------------------------------------------------------------------
resource "aws_lambda_permission" "allow_scheduler_invoke" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.generate_weekly_report.arn
}

# -----------------------------------------------------------------------------
# EventBridge Scheduler Schedule
# -----------------------------------------------------------------------------
resource "aws_scheduler_schedule" "generate_weekly_report" {
  name                         = "generate-weekly-report-schedule"
  schedule_expression          = "cron(0 8 ? * MON *)"
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = local.target_lambda_arn
    role_arn = aws_iam_role.scheduler_role.arn

    input = jsonencode({
      trigger_source = "EVENTBRIDGE_SCHEDULER"
      report_type    = "WEEKLY"
    })
  }
}

locals {
  target_lambda_arn = var.lambda_generate_report_arn != "" ? var.lambda_generate_report_arn : aws_lambda_function.generate_report.arn
}
