data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# 1. IAM Role & Policy: receive-feedback
# -----------------------------------------------------------------------------
resource "aws_iam_role" "receive_feedback_role" {
  name               = "feedback-receive-feedback-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "receive_feedback_basic" {
  role       = aws_iam_role.receive_feedback_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "receive_feedback_policy" {
  name = "receive-feedback-policy"
  role = aws_iam_role.receive_feedback_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.feedbacks.arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 2. IAM Role & Policy: send-email
# -----------------------------------------------------------------------------
resource "aws_iam_role" "send_email_role" {
  name               = "feedback-send-email-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "send_email_basic" {
  role       = aws_iam_role.send_email_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "send_email_policy" {
  name = "send-email-policy"
  role = aws_iam_role.send_email_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = [aws_ssm_parameter.ses_source_email.arn]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 3. IAM Role & Policy: evaluate-urgency
# -----------------------------------------------------------------------------
resource "aws_iam_role" "evaluate_urgency_role" {
  name               = "feedback-evaluate-urgency-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "evaluate_urgency_basic" {
  role       = aws_iam_role.evaluate_urgency_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "evaluate_urgency_policy" {
  name = "evaluate-urgency-policy"
  role = aws_iam_role.evaluate_urgency_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Resource = aws_dynamodb_table.feedbacks.stream_arn
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.feedbacks.arn
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.notify_email.arn
      },
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          aws_ssm_parameter.management_email.arn,
          aws_ssm_parameter.urgency_thresholds.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 4. IAM Role & Policy: generate-report
# -----------------------------------------------------------------------------
resource "aws_iam_role" "generate_report_role" {
  name               = "feedback-generate-report-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "generate_report_basic" {
  role       = aws_iam_role.generate_report_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "generate_report_policy" {
  name = "generate-report-policy"
  role = aws_iam_role.generate_report_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ]
        Resource = [
          aws_dynamodb_table.feedbacks.arn,
          "${aws_dynamodb_table.feedbacks.arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.notify_email.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = [aws_ssm_parameter.management_email.arn]
      }
    ]
  })
}
