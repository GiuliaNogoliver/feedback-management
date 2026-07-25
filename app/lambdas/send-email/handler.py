from dataclasses import dataclass
import json
import logging
import os
from typing import Any, Dict, Optional
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TEMPLATE_MAPPING: Dict[str, str] = {
    "CRITICAL_ALERT": "CriticalAlertTemplate",
    "WEEKLY_REPORT": "WeeklyReportTemplate",
}


@dataclass(frozen=True)
class NotificationPayload:
    event_type: str
    recipient: str
    data: Dict[str, Any]

    @classmethod
    def from_sqs_record(cls, record: Dict[str, Any]) -> "NotificationPayload":
        raw_body = record.get("body", "{}")
        try:
            body_json = json.loads(raw_body)
        except json.JSONDecodeError:
            body_json = {}

        if isinstance(body_json, dict) and "Message" in body_json:
            try:
                inner_message = json.loads(body_json["Message"])
            except (json.JSONDecodeError, TypeError):
                inner_message = {}
        else:
            inner_message = body_json

        message_attributes = record.get("messageAttributes", {})
        event_type = (
            message_attributes.get("event_type", {}).get("stringValue")
            or inner_message.get("event_type")
            or "CRITICAL_ALERT"
        )
        recipient = (
            inner_message.get("recipient")
            or os.environ.get("SES_SOURCE_EMAIL", "noreply@feedback-platform.com")
        )
        data = inner_message.get("data", inner_message)

        return cls(
            event_type=event_type,
            recipient=recipient,
            data=data,
        )


class EmailService:
    def __init__(self) -> None:
        region = os.environ.get("AWS_REGION", "sa-east-1")
        self.ses_client = boto3.client("ses", region_name=region)
        self.ssm_client = boto3.client("ssm", region_name=region)
        self.ssm_param_name = os.environ.get(
            "SSM_PARAM_SES_SOURCE_EMAIL",
            "/feedback-management/dev/ses_source_email",
        )
        self._cached_sender_email: Optional[str] = None

    @property
    def sender_email(self) -> str:
        if not self._cached_sender_email:
            try:
                response = self.ssm_client.get_parameter(
                    Name=self.ssm_param_name, WithDecryption=False
                )
                self._cached_sender_email = response["Parameter"]["Value"]
                logger.info(
                    "E-mail remetente obtido com sucesso do SSM Parameter Store (%s): %s",
                    self.ssm_param_name,
                    self._cached_sender_email,
                )
            except Exception as exc:
                logger.warning(
                    "Falha ao buscar parâmetro no SSM Parameter Store (%s): %s. Usando fallback.",
                    self.ssm_param_name,
                    exc,
                )
                self._cached_sender_email = os.environ.get(
                    "SES_SOURCE_EMAIL", "noreply@feedback-platform.com"
                )
        return self._cached_sender_email

    def send_templated_email(self, payload: NotificationPayload) -> Dict[str, Any]:
        template_name = TEMPLATE_MAPPING.get(
            payload.event_type.upper(), "CriticalAlertTemplate"
        )
        template_data_str = json.dumps(payload.data)

        logger.info(
            "Enviando e-mail nativo SES via template '%s' para %s (Remetente: %s)",
            template_name,
            payload.recipient,
            self.sender_email,
        )

        response = self.ses_client.send_templated_email(
            Source=self.sender_email,
            Destination={"ToAddresses": [payload.recipient]},
            Template=template_name,
            TemplateData=template_data_str,
        )
        return response


email_service = EmailService()


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    records = event.get("Records", [])
    logger.info("Processando lote de mensagens SQS: %d registro(s)", len(records))
    processed_count = 0

    for record in records:
        try:
            payload = NotificationPayload.from_sqs_record(record)
            response = email_service.send_templated_email(payload)
            processed_count += 1
            logger.info(
                "E-mail enviado com sucesso! MessageId: %s",
                response.get("MessageId"),
            )
        except Exception as exc:
            logger.error("Erro ao processar registro SQS: %s", str(exc), exc_info=True)
            raise exc

    return {
        "statusCode": 200,
        "body": json.dumps({"message": f"{processed_count} e-mail(s) enviados via SES Template com sucesso."}),
    }


lambda_handler = handler
