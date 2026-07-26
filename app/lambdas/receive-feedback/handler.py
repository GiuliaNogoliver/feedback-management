from dataclasses import dataclass
from datetime import datetime, timezone
import json
import logging
import os
from typing import Any, Dict, Tuple
import uuid
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

region = os.environ.get("AWS_REGION", "sa-east-1")
dynamodb = boto3.resource("dynamodb", region_name=region)

CORS_HEADERS = {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
    "Access-Control-Allow-Methods": "OPTIONS,POST",
}


@dataclass(frozen=True)
class FeedbackInputDTO:
    descricao: str
    nota: int

    @classmethod
    def validate_and_create(cls, body: Dict[str, Any]) -> "FeedbackInputDTO":
        if not isinstance(body, dict):
            raise ValueError("O corpo da requisição deve ser um objeto JSON válido.")

        descricao = body.get("descricao")
        if not isinstance(descricao, str) or not descricao.strip():
            raise ValueError("O campo 'descricao' é obrigatório e deve ser uma string não vazia.")

        nota_raw = body.get("nota")
        if nota_raw is None or isinstance(nota_raw, bool) or not isinstance(nota_raw, (int, float)):
            raise ValueError("O campo 'nota' é obrigatório e deve ser um número inteiro entre 0 e 10.")

        try:
            nota = int(nota_raw)
        except (ValueError, TypeError):
            raise ValueError("O campo 'nota' deve ser um número inteiro válido.")

        if nota < 0 or nota > 10:
            raise ValueError("O campo 'nota' deve ser um número inteiro entre 0 e 10 (inclusive).")

        return cls(
            descricao=descricao.strip(),
            nota=nota,
        )


class FeedbackRepository:
    def __init__(self, table_name: str) -> None:
        self.table = dynamodb.Table(table_name)

    def save_feedback(self, dto: FeedbackInputDTO) -> Tuple[str, Dict[str, Any]]:
        now = datetime.now(timezone.utc)
        feedback_id = str(uuid.uuid4())
        timestamp_iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        data_criacao = now.strftime("%Y-%m-%d")

        item = {
            "id": feedback_id,
            "timestamp": timestamp_iso,
            "data_criacao": data_criacao,
            "entity_type": "FEEDBACK",
            "descricao": dto.descricao,
            "nota": dto.nota,
        }

        logger.info("Persistindo feedback ID %s no DynamoDB...", feedback_id)
        self.table.put_item(Item=item)
        logger.info("Feedback ID %s persistido com sucesso!", feedback_id)
        return feedback_id, item


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Processando requisição de ingestão de feedback...")

    raw_body = event.get("body")
    if not raw_body:
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "O corpo da requisição está vazio."}),
        }

    try:
        body_json = json.loads(raw_body) if isinstance(raw_body, str) else raw_body
    except json.JSONDecodeError:
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "JSON malformado no corpo da requisição."}),
        }

    try:
        dto = FeedbackInputDTO.validate_and_create(body_json)
    except ValueError as val_err:
        logger.warning("Falha de validação no payload: %s", str(val_err))
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": str(val_err)}),
        }

    table_name = os.environ.get("TABLE_NAME", "feedbacks_db")
    repo = FeedbackRepository(table_name=table_name)

    try:
        feedback_id, _ = repo.save_feedback(dto)
        return {
            "statusCode": 201,
            "headers": CORS_HEADERS,
            "body": json.dumps(
                {
                    "message": "Feedback recebido com sucesso!",
                    "id": feedback_id,
                }
            ),
        }
    except Exception as exc:
        logger.error("Erro inesperado ao salvar feedback no DynamoDB: %s", str(exc), exc_info=True)
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "Erro interno ao processar a avaliação."}),
        }


lambda_handler = handler
