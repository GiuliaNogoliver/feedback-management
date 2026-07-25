resource "aws_cloudwatch_log_group" "generate_report_logs" {
  name              = "/aws/lambda/generate-report"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}
