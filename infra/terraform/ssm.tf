resource "aws_ssm_parameter" "ses_source_email" {
  name  = "/feedback-management/${var.environment}/ses_source_email"
  type  = "String"
  value = var.ses_source_email

  lifecycle {
    ignore_changes = [value]
  }

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

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_ssm_parameter" "urgency_thresholds" {
  name = "/config/urgency_thresholds"
  type = "String"
  value = jsonencode({
    critical_max_score = 4
    medium_max_score   = 7
  })

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}
