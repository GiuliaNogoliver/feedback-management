resource "aws_cloudwatch_log_group" "receive_feedback_logs" {
  name              = "/aws/lambda/receive-feedback"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_api_gateway_api_key" "student_api_key" {
  name        = "StudentAPIKey"
  description = "API Key para os alunos enviarem feedbacks no POST /avaliacao"
  enabled     = true

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_api_gateway_usage_plan" "student_usage_plan" {
  name        = "StudentUsagePlan"
  description = "Plano de uso para governança e limite de taxa de avaliações"

  api_stages {
    api_id = aws_api_gateway_rest_api.feedback_api.id
    stage  = aws_api_gateway_stage.dev.stage_name
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_api_gateway_usage_plan_key" "student_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.student_api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.student_usage_plan.id
}
