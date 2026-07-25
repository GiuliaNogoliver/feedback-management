variable "table_name" {
  description = "Nome da tabela DynamoDB de feedbacks"
  type        = string
  default     = "feedbacks_db"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "O ambiente deve ser: dev, staging ou production."
  }
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão provisionados"
  type        = string
  default     = "sa-east-1"
}

variable "lambda_generate_report_arn" {
  description = "ARN opcional da função Lambda generate-report para acoplamento externo"
  type        = string
  default     = ""
}

variable "ses_source_email" {
  description = "E-mail remetente verificado no Amazon SES para envio de notificações"
  type        = string
  default     = "noreply@feedback-platform.com"
}
