resource "aws_ssm_parameter" "ses_source_email" {
  name  = "/feedback-management/${var.environment}/ses_source_email"
  type  = "String"
  value = var.ses_source_email

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "management_email" {
  name  = "/feedback-management/${var.environment}/management_email"
  type  = "String"
  value = var.ses_source_email

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}
