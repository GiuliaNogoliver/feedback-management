# =============================================================================
# Amazon DynamoDB - Tabela de Feedbacks
# =============================================================================
#
# Tabela principal da plataforma de feedbacks.
#
# - Modo On-Demand (PAY_PER_REQUEST): não requer capacidade provisionada,
#   ideal para Free-Tier e cargas imprevisíveis.
#
# - DynamoDB Streams (NEW_IMAGE): cada inserção/atualização emite um evento
#   contendo o item completo após a operação. Isso permite que consumidores
#   downstream (Lambda, EventBridge Pipes, etc.) processem feedbacks em
#   tempo real sem precisar consultar a tabela novamente.
#
# - GSI "DateIndex" (entity_type + timestamp): permite consultas eficientes
#   por tipo de entidade ordenadas por data (ISO-8601). Exemplo de uso:
#   "liste todos os feedbacks do tipo 'sugestão' dos últimos 7 dias".
#   O ProjectionType ALL garante que todos os atributos do item estejam
#   disponíveis na resposta, evitando fetches adicionais à tabela base.
#
# =============================================================================

resource "aws_dynamodb_table" "feedbacks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"

  # ---------------------------------------------------------------------------
  # Chave Primária
  # ---------------------------------------------------------------------------
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # ---------------------------------------------------------------------------
  # DynamoDB Streams
  # Emite o snapshot completo do item (NEW_IMAGE) após cada escrita,
  # permitindo pipelines de eventos em tempo real.
  # ---------------------------------------------------------------------------
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  # ---------------------------------------------------------------------------
  # Global Secondary Index (GSI) - DateIndex
  # Permite consultas por entity_type (HASH) ordenadas por timestamp (RANGE).
  # Útil para listar feedbacks por tipo em ordem cronológica.
  # ---------------------------------------------------------------------------
  global_secondary_index {
    name            = "DateIndex"
    hash_key        = "entity_type"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  attribute {
    name = "entity_type"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # ---------------------------------------------------------------------------
  # Criptografia em repouso (AWS Managed KMS)
  # ---------------------------------------------------------------------------
  server_side_encryption {
    enabled = true
  }

  # ---------------------------------------------------------------------------
  # Tags de governança
  # ---------------------------------------------------------------------------
  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}
