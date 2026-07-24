resource "aws_dynamodb_table" "feedbacks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  global_secondary_index {
    name            = "DateIndex"
    hash_key        = "data_criacao"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  attribute {
    name = "data_criacao"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}
