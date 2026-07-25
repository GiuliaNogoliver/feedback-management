data "archive_file" "send_email_dispatcher" {
  type        = "zip"
  source_file = "${path.module}/../../src/send_email_dispatcher/lambda_function.py"
  output_path = "${path.module}/zip/send_email_dispatcher.zip"
}

resource "aws_cloudwatch_log_group" "send_email_dispatcher_logs" {
  name              = "/aws/lambda/send_email_dispatcher"
  retention_in_days = 1

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role" "send_email_dispatcher_role" {
  name = "send-email-dispatcher-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
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

resource "aws_iam_role_policy" "send_email_dispatcher_policy" {
  name = "send-email-dispatcher-permissions"
  role = aws_iam_role.send_email_dispatcher_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.notify_email.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "send_email_dispatcher" {
  function_name    = "send_email_dispatcher"
  role             = aws_iam_role.send_email_dispatcher_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.send_email_dispatcher.output_path
  source_code_hash = data.archive_file.send_email_dispatcher.output_base64sha256

  environment {
    variables = {
      SES_SOURCE_EMAIL = var.ses_source_email
    }
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_cloudwatch_log_group.send_email_dispatcher_logs
  ]
}

resource "aws_lambda_event_source_mapping" "sqs_email_trigger" {
  event_source_arn = aws_sqs_queue.notify_email.arn
  function_name    = aws_lambda_function.send_email_dispatcher.arn
  batch_size       = 5
}
