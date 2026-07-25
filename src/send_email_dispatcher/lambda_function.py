from abc import ABC, abstractmethod
from dataclasses import dataclass
import json
import logging
import os
from typing import Any, Dict, Tuple
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


@dataclass(frozen=True)
class NotificationPayload:
    event_type: str
    recipient: str
    subject: str
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
        subject = inner_message.get("subject", "Notificação da Plataforma de Feedbacks")
        data = inner_message.get("data", inner_message)

        return cls(
            event_type=event_type,
            recipient=recipient,
            subject=subject,
            data=data,
        )


class BaseTemplate(ABC):
    @abstractmethod
    def render(self, payload: NotificationPayload) -> Tuple[str, str]:
        pass


class CriticalAlertTemplate(BaseTemplate):
    def render(self, payload: NotificationPayload) -> Tuple[str, str]:
        subject = f"🔴 [ALERTA CRÍTICO] {payload.subject}"
        descricao = payload.data.get("descricao", "N/A")
        nota = payload.data.get("nota", "N/A")
        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{ font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }}
        .card {{ background: #ffffff; border-radius: 8px; border-top: 6px solid #D32F2F; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 600px; margin: auto; padding: 24px; }}
        .header {{ color: #D32F2F; margin-top: 0; }}
        .badge {{ background-color: #FFEBEE; color: #C62828; padding: 6px 12px; border-radius: 4px; font-weight: bold; display: inline-block; }}
        .footer {{ font-size: 12px; color: #777777; margin-top: 24px; border-top: 1px solid #eee; padding-top: 12px; }}
    </style>
</head>
<body>
    <div class="card">
        <h2 class="header">⚠️ Alerta de Avaliação Crítica</h2>
        <p>Uma nova avaliação com nota baixa foi registrada no sistema:</p>
        <p><span class="badge">Nota: {nota} / 10</span></p>
        <p><strong>Descrição do Feedback:</strong></p>
        <blockquote style="background: #fafafa; border-left: 4px solid #D32F2F; margin: 0; padding: 10px 15px; color: #333;">
            {descricao}
        </blockquote>
        <div class="footer">
            Plataforma de Gestão de Feedbacks &bull; Notificação Automática de Alerta Crítico
        </div>
    </div>
</body>
</html>"""
        return subject, html_body


class WeeklyReportTemplate(BaseTemplate):
    def render(self, payload: NotificationPayload) -> Tuple[str, str]:
        subject = f"📊 [RELATÓRIO SEMANAL] {payload.subject}"
        total_feedbacks = payload.data.get("total_feedbacks", 0)
        media_nota = payload.data.get("media_nota", "N/A")
        periodo = payload.data.get("periodo", "Últimos 7 dias")
        html_body = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {{ font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }}
        .card {{ background: #ffffff; border-radius: 8px; border-top: 6px solid #1976D2; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 600px; margin: auto; padding: 24px; }}
        .header {{ color: #1976D2; margin-top: 0; }}
        .metric {{ background-color: #E3F2FD; color: #1565C0; padding: 12px; border-radius: 6px; margin-bottom: 12px; }}
        .footer {{ font-size: 12px; color: #777777; margin-top: 24px; border-top: 1px solid #eee; padding-top: 12px; }}
    </style>
</head>
<body>
    <div class="card">
        <h2 class="header">📈 Relatório Semanal de Feedbacks</h2>
        <p>Confira o resumo consolidado das avaliações do período (<strong>{periodo}</strong>):</p>
        <div class="metric">
            <strong>Total de Feedbacks Registrados:</strong> {total_feedbacks}
        </div>
        <div class="metric">
            <strong>Média Geral das Notas:</strong> {media_nota}
        </div>
        <div class="footer">
            Plataforma de Gestão de Feedbacks &bull; Relatório Automatizado via EventBridge Scheduler
        </div>
    </div>
</body>
</html>"""
        return subject, html_body


class TemplateFactory:
    _registry = {
        "CRITICAL_ALERT": CriticalAlertTemplate,
        "WEEKLY_REPORT": WeeklyReportTemplate,
    }

    @classmethod
    def get_template(cls, event_type: str) -> BaseTemplate:
        template_cls = cls._registry.get(event_type.upper(), CriticalAlertTemplate)
        return template_cls()


class EmailService:
    def __init__(self) -> None:
        region = os.environ.get("AWS_REGION", "sa-east-1")
        self.client = boto3.client("ses", region_name=region)

    def send_email(
        self, source: str, destination: str, subject: str, html_body: str
    ) -> Dict[str, Any]:
        response = self.client.send_email(
            Source=source,
            Destination={"ToAddresses": [destination]},
            Message={
                "Subject": {"Data": subject, "Charset": "UTF-8"},
                "Body": {"Html": {"Data": html_body, "Charset": "UTF-8"}},
            },
        )
        return response


email_service = EmailService()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Processando lote de mensagens SQS: %d registro(s)", len(event.get("Records", [])))
    source_email = os.environ.get("SES_SOURCE_EMAIL", "noreply@feedback-platform.com")
    processed_count = 0

    for record in event.get("Records", []):
        try:
            payload = NotificationPayload.from_sqs_record(record)
            template = TemplateFactory.get_template(payload.event_type)
            subject, html_body = template.render(payload)

            response = email_service.send_email(
                source=source_email,
                destination=payload.recipient,
                subject=subject,
                html_body=html_body,
            )
            processed_count += 1
            logger.info(
                "E-mail disparado com sucesso para %s! MessageId: %s",
                payload.recipient,
                response.get("MessageId"),
            )
        except Exception as exc:
            logger.error("Erro ao processar registro SQS: %s", str(exc), exc_info=True)
            raise exc

    return {
        "statusCode": 200,
        "body": json.dumps({"message": f"{processed_count} e-mail(s) processados com sucesso."}),
    }
