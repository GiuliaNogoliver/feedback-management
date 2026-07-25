resource "aws_api_gateway_rest_api" "feedback_api" {
  name        = "feedback-api"
  description = "API Gateway para a plataforma de feedbacks"

  tags = {
    Environment = var.environment
    Project     = "feedback-management"
    ManagedBy   = "Terraform"
  }
}

resource "aws_api_gateway_resource" "avaliacao" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_rest_api.feedback_api.root_resource_id
  path_part   = "avaliacao"
}

resource "aws_api_gateway_model" "avaliacao_model" {
  rest_api_id  = aws_api_gateway_rest_api.feedback_api.id
  name         = "AvaliacaoInputModel"
  content_type = "application/json"

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

resource "aws_api_gateway_request_validator" "validator" {
  name                        = "payload-body-validator"
  rest_api_id                 = aws_api_gateway_rest_api.feedback_api.id
  validate_request_body       = true
  validate_request_parameters = false
}

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

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.feedback_api.id
  resource_id             = aws_api_gateway_resource.avaliacao.id
  http_method             = aws_api_gateway_method.post_avaliacao.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.receive_feedback.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_receive_feedback" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.receive_feedback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.feedback_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_resource" "relatorio" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id
  parent_id   = aws_api_gateway_rest_api.feedback_api.root_resource_id
  path_part   = "relatorio"
}

resource "aws_api_gateway_method" "post_relatorio" {
  rest_api_id   = aws_api_gateway_rest_api.feedback_api.id
  resource_id   = aws_api_gateway_resource.relatorio.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_generate_report" {
  rest_api_id             = aws_api_gateway_rest_api.feedback_api.id
  resource_id             = aws_api_gateway_resource.relatorio.id
  http_method             = aws_api_gateway_method.post_relatorio.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.generate_report.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda_generate_report" {
  statement_id  = "AllowExecutionFromAPIGatewayGenerateReport"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.feedback_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.feedback_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration,
    aws_api_gateway_integration.lambda_integration_generate_report
  ]

  triggers = {
    redeployment = sha256(jsonencode([
      aws_api_gateway_resource.avaliacao.id,
      aws_api_gateway_method.post_avaliacao.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_model.avaliacao_model.schema,
      aws_api_gateway_resource.relatorio.id,
      aws_api_gateway_method.post_relatorio.id,
      aws_api_gateway_integration.lambda_integration_generate_report.id
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
