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

resource "aws_lambda_permission" "allow_scheduler_invoke" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.generate_weekly_report.arn
}

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
