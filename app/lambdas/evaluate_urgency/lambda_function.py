from dataclasses import dataclass
import json
import logging
import os
from typing import Any, Dict, Optional
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

region = os.environ.get("AWS_REGION", "sa-east-1")
dynamodb = boto3.resource("dynamodb", region_name=region)
sqs = boto3.client("sqs", region_name=region)
ssm = boto3.client("ssm", region_name=region)


@dataclass(frozen=True)
class UrgencyThresholdConfig:
    critical_max_score: int = 4
    medium_max_score: int = 7


class UrgencyEvaluatorService:
    def __init__(self, table_name: str, queue_url: str, admin_email: str, ssm_param_name: str) -> None:
        self.table = dynamodb.Table(table_name)
        self.queue_url = queue_url
        self.admin_email = admin_email
        self.ssm_param_name = ssm_param_name
        self._cached_config: Optional[UrgencyThresholdConfig] = None

    @property
    def config(self) -> UrgencyThresholdConfig:
        if self._cached_config is None:
            try:
                response = ssm.get_parameter(Name=self.ssm_param_name, WithDecryption=False)
                param_value = response["Parameter"]["Value"]
                data = json.loads(param_value)
                critical_max = int(data.get("critical_max_score", 4))
                medium_max = int(data.get("medium_max_score", 7))
                self._cached_config = UrgencyThresholdConfig(
                    critical_max_score=critical_max,
                    medium_max_score=medium_max,
                )
                logger.info(
                    "Configuração de urgência carregada do SSM (%s): critical_max=%d, medium_max=%d",
                    self.ssm_param_name,
                    critical_max,
                    medium_max,
                )
            except Exception as exc:
                logger.warning(
                    "Falha ao buscar parâmetros de urgência do SSM (%s): %s. Usando fallback.",
                    self.ssm_param_name,
                    exc,
                )
                self._cached_config = UrgencyThresholdConfig()
        return self._cached_config

    def calculate_urgency(self, nota: float) -> str:
        cfg = self.config
        if nota <= cfg.critical_max_score:
            return "ALTA"
        elif nota <= cfg.medium_max_score:
            return "MEDIA"
        else:
            return "BAIXA"

    def update_dynamodb_urgency(self, item_id: str, urgencia: str) -> bool:
        try:
            logger.info("Atualização atômica do feedback %s com urgencia='%s'...", item_id, urgencia)
            self.table.update_item(
                Key={"id": item_id},
                UpdateExpression="SET urgencia = :u",
                ConditionExpression="attribute_not_exists(urgencia)",
                ExpressionAttributeValues={":u": urgencia},
            )
            logger.info("Feedback %s atualizado com sucesso!", item_id)
            return True
        except ClientError as exc:
            error_code = exc.response.get("Error", {}).get("Code")
            if error_code == "ConditionalCheckFailedException":
                logger.info("Feedback %s já possui o atributo 'urgencia'. Invocação ignorada.", item_id)
                return False
            else:
                logger.error("Erro no UpdateItem do DynamoDB para ID %s: %s", item_id, str(exc))
                raise exc

    def send_critical_sqs_alert(self, item_id: str, nota: float, descricao: str, timestamp: str) -> Optional[Dict[str, Any]]:
        payload = {
            "event_type": "CRITICAL_ALERT",
            "recipient": self.admin_email,
            "subject": "⚠️ ALERTA: Avaliação Crítica Recebida",
            "data": {
                "feedback_id": item_id,
                "nota": str(nota),
                "urgencia": "ALTA",
                "descricao": descricao,
                "data_envio": timestamp,
            },
        }

        logger.info("Publicando alerta crítico para SQS queue %s (ID: %s)", self.queue_url, item_id)
        response = sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(payload),
        )
        logger.info("Alerta crítico enviado com sucesso! MessageId: %s", response.get("MessageId"))
        return response


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Iniciando execução da Lambda evaluate-urgency (DynamoDB Stream)...")
    records = event.get("Records", [])
    logger.info("Processando lote de %d registro(s) do Stream", len(records))

    table_name = os.environ.get("TABLE_NAME", "feedbacks_db")
    queue_url = os.environ.get("SQS_QUEUE_URL", "")
    admin_email = os.environ.get("ADMIN_EMAIL", "guilherme.rosario@outlook.com.br")
    ssm_param_name = os.environ.get("SSM_PARAM_NAME", "/config/urgency_thresholds")

    evaluator = UrgencyEvaluatorService(
        table_name=table_name,
        queue_url=queue_url,
        admin_email=admin_email,
        ssm_param_name=ssm_param_name,
    )

    processed_count = 0

    for record in records:
        event_name = record.get("eventName")
        if event_name != "INSERT":
            logger.info("Ignorando registro com eventName '%s'", event_name)
            continue

        dynamodb_data = record.get("dynamodb", {})
        new_image = dynamodb_data.get("NewImage", {})

        item_id = new_image.get("id", {}).get("S")
        if not item_id:
            logger.warning("Registro sem atributo 'id'. Ignorando.")
            continue

        raw_nota = new_image.get("nota", {})
        nota_val = raw_nota.get("N") or raw_nota.get("S") or "0"
        try:
            nota = float(nota_val)
        except (ValueError, TypeError):
            nota = 0.0

        descricao = new_image.get("descricao", {}).get("S", "Sem descrição")
        timestamp = new_image.get("timestamp", {}).get("S", "")

        urgencia = evaluator.calculate_urgency(nota)
        updated = evaluator.update_dynamodb_urgency(item_id, urgencia)

        if updated and urgencia == "ALTA" and queue_url:
            evaluator.send_critical_sqs_alert(
                item_id=item_id,
                nota=nota,
                descricao=descricao,
                timestamp=timestamp,
            )

        processed_count += 1

    return {
        "statusCode": 200,
        "body": json.dumps({"message": f"{processed_count} registro(s) processados com sucesso."}),
    }


handler = lambda_handler
