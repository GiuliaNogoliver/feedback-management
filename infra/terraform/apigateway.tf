resource "aws_api_gateway_rest_api" "feedback_api" {
  name        = "feedback-api"
  description = "API Gateway para a plataforma de feedbacks"

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

# -----------------------------------------------------------------------------
# Recurso: /avaliacao
# -----------------------------------------------------------------------------
resource "aws_api_gateway_resource" "avaliacao" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_rest_api.feedback_api.root_resource_id
  path_part   = "avaliacao"
}

# -----------------------------------------------------------------------------
# Modelo de Validação (JSON Schema)
# - descricao: string obrigatória
# - nota: integer obrigatório (0 a 10)
# -----------------------------------------------------------------------------
resource "aws_api_gateway_model" "avaliacao_model" {
  rest_api_id  = aws_api_gateway_rest_api.feedback_api.id
  name         = "AvaliacaoInputModel"
  content_type = "application/json"
  description  = "Validação do payload de avaliação"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "AvaliacaoInput"
    type      = "object"
    required  = ["descricao", "nota"]
    properties = {
      descricao = {
        type      = "string"
        minLength = 1
      }
      nota = {
        type    = "integer"
        minimum = 0
        maximum = 10
      }
    }
    additionalProperties = true
  })
}

# -----------------------------------------------------------------------------
# Request Validator (Valida o corpo da requisição contra o modelo)
# -----------------------------------------------------------------------------
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "payload-body-validator"
  rest_api_id                 = aws_api_gateway_rest_api.feedback_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

# -----------------------------------------------------------------------------
# Método POST /avaliacao
# -----------------------------------------------------------------------------
resource "aws_api_gateway_method" "post_avaliacao" {
  rest_api_id          = aws_api_gateway_rest_api.feedback_api.id
  resource_id          = aws_api_gateway_resource.avaliacao.id
  http_method          = "POST"
  authorization        = "NONE"
  request_validator_id = aws_api_gateway_request_validator.validator.id

  request_models = {
    "application/json" = aws_api_gateway_model.avaliacao_model.name
  }
}

# -----------------------------------------------------------------------------
# Integração AWS_PROXY com a Lambda receive-feedback
# -----------------------------------------------------------------------------
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.feedback_api.id
  resource_id             = aws_api_gateway_resource.avaliacao.id
  http_method             = aws_api_gateway_method.post_avaliacao.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.receive_feedback.invoke_arn
}

# -----------------------------------------------------------------------------
# Permissão para o API Gateway invocar a Lambda receive-feedback
# -----------------------------------------------------------------------------
resource "aws_lambda_permission" "apigw_lambda_receive_feedback" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receive_feedback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.feedback_api.execution_arn}/*/*/*"
}

# -----------------------------------------------------------------------------
# Deployment & Stage
# -----------------------------------------------------------------------------
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  triggers = {
    redeployment = sha256(jsonencode([
      aws_api_gateway_resource.avaliacao.id,
      aws_api_gateway_method.post_avaliacao.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_model.avaliacao_model.schema
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "dev" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  stage_name    = var.environment
}
