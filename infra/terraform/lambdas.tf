data "archive_file" "receive_feedback" {
  type        = "zip"
  source_dir  = "${path.module}/../../app/lambdas/receive-feedback"
  output_path = "${path.module}/zip/receive-feedback.zip"
}

data "archive_file" "send_email" {
  type        = "zip"
  source_dir  = "${path.module}/../../app/lambdas/send-email"
  output_path = "${path.module}/zip/send-email.zip"
}

data "archive_file" "generate_report" {
  type        = "zip"
  source_dir  = "${path.module}/../../app/lambdas/generate-report"
  output_path = "${path.module}/zip/generate-report.zip"
}

data "archive_file" "critical_notification" {
  type        = "zip"
  source_dir  = "${path.module}/../../app/lambdas/critical-notification"
  output_path = "${path.module}/zip/critical-notification.zip"
}

resource "aws_lambda_function" "receive_feedback" {
  function_name    = "receive-feedback"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.receive_feedback.output_path
  source_code_hash = data.archive_file.receive_feedback.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.receive_feedback_logs
  ]
}

resource "aws_lambda_function" "send_email" {
  function_name    = "send-email"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.send_email.output_path
  source_code_hash = data.archive_file.send_email.output_base64sha256

  environment {
    variables = {
      SES_SOURCE_EMAIL           = var.ses_source_email
      SSM_PARAM_SES_SOURCE_EMAIL = aws_ssm_parameter.ses_source_email.name
    }
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_function" "generate_report" {
  function_name    = "generate-report"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 60
  filename         = data.archive_file.generate_report.output_path
  source_code_hash = data.archive_file.generate_report.output_base64sha256

  environment {
    variables = {
      TABLE_NAME                 = var.table_name
      SQS_QUEUE_URL              = aws_sqs_queue.notify_email.url
      MANAGEMENT_EMAIL           = var.ses_source_email
      SSM_PARAM_MANAGEMENT_EMAIL = aws_ssm_parameter.management_email.name
    }
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.generate_report_logs
  ]
}

resource "aws_lambda_function" "critical_notification" {
  function_name    = "critical-notification"
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.critical_notification.output_path
  source_code_hash = data.archive_file.critical_notification.output_base64sha256

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_event_source_mapping" "sqs_email_trigger" {
  event_source_arn = aws_sqs_queue.notify_email.arn
  function_name    = aws_lambda_function.send_email.arn
  batch_size       = 5
}
