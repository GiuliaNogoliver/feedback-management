from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import json
import logging
import os
from typing import Any, Dict, List
import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(logging.INFO)

region = os.environ.get("AWS_REGION", "sa-east-1")
dynamodb = boto3.resource("dynamodb", region_name=region)
sqs = boto3.client("sqs", region_name=region)


@dataclass(frozen=True)
class WeeklyReportSummary:
    media_geral: str
    total_avaliacoes: str
    avaliacoes_por_urgencia: str
    avaliacoes_por_dia: str
    data_envio: str


class ReportGenerator:
    def __init__(self, table_name: str, queue_url: str, recipient: str) -> None:
        self.table = dynamodb.Table(table_name)
        self.queue_url = queue_url
        self.recipient = recipient

    def query_last_7_days(self) -> List[Dict[str, Any]]:
        now = datetime.now(timezone.utc)
        start_date = now - timedelta(days=7)

        data_inicio = start_date.strftime("%Y-%m-%dT%H:%M:%SZ")
        data_fim = now.strftime("%Y-%m-%dT%H:%M:%SZ")

        logger.info("Executando Query GSI DateIndex de %s até %s", data_inicio, data_fim)

        response = self.table.query(
            IndexName="DateIndex",
            KeyConditionExpression=Key("entity_type").eq("FEEDBACK") & Key("timestamp").between(data_inicio, data_fim),
        )
        items = response.get("Items", [])
        logger.info("Encontrados %d feedbacks no período de 7 dias", len(items))
        return items

    def compute_summary(self, items: List[Dict[str, Any]]) -> WeeklyReportSummary:
        now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        total_avaliacoes = len(items)

        if total_avaliacoes == 0:
            return WeeklyReportSummary(
                media_geral="0.0",
                total_avaliacoes="0",
                avaliacoes_por_urgencia="Alta: 0, Média: 0, Baixa: 0",
                avaliacoes_por_dia="Sem avaliações no período",
                data_envio=now_str,
            )

        notas: List[float] = []
        urgencia_counts = {"Alta": 0, "Média": 0, "Baixa": 0}
        dia_counts: Dict[str, int] = defaultdict(int)

        for item in items:
            raw_nota = item.get("nota")
            try:
                nota = float(raw_nota) if raw_nota is not None else None
            except (ValueError, TypeError):
                nota = None

            if nota is not None:
                notas.append(nota)

            urgencia_attr = item.get("urgencia")
            if urgencia_attr:
                urg_str = str(urgencia_attr).capitalize()
                if urg_str in ("Alta", "Média", "Media"):
                    urg_key = "Média" if urg_str in ("Média", "Media") else "Alta"
                elif urg_str == "Baixa":
                    urg_key = "Baixa"
                else:
                    urg_key = "Baixa"
                urgencia_counts[urg_key] = urgencia_counts.get(urg_key, 0) + 1
            elif nota is not None:
                if nota <= 3:
                    urgencia_counts["Alta"] += 1
                elif nota <= 6:
                    urgencia_counts["Média"] += 1
                else:
                    urgencia_counts["Baixa"] += 1

            ts_str = str(item.get("timestamp", ""))
            date_part = ts_str[:10] if len(ts_str) >= 10 else now_str
            dia_counts[date_part] += 1

        media_geral = f"{(sum(notas) / len(notas)):.1f}" if notas else "0.0"

        urgencia_str = f"Alta: {urgencia_counts['Alta']}, Média: {urgencia_counts['Média']}, Baixa: {urgencia_counts['Baixa']}"

        sorted_days = sorted(dia_counts.keys())
        dia_str = ", ".join([f"{dia}: {dia_counts[dia]}" for dia in sorted_days])

        return WeeklyReportSummary(
            media_geral=media_geral,
            total_avaliacoes=str(total_avaliacoes),
            avaliacoes_por_urgencia=urgencia_str,
            avaliacoes_por_dia=dia_str,
            data_envio=now_str,
        )

    def publish_to_sqs(self, summary: WeeklyReportSummary) -> Dict[str, Any]:
        payload = {
            "event_type": "WEEKLY_REPORT",
            "recipient": self.recipient,
            "subject": "📊 Relatório Semanal de Avaliações",
            "data": {
                "media_geral": summary.media_geral,
                "total_avaliacoes": summary.total_avaliacoes,
                "avaliacoes_por_urgencia": summary.avaliacoes_por_urgencia,
                "avaliacoes_por_dia": summary.avaliacoes_por_dia,
                "data_envio": summary.data_envio,
            },
        }

        logger.info("Publicando relatório semanal na SQS queue %s", self.queue_url)
        response = sqs.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(payload),
        )
        logger.info("Mensagem publicada com sucesso! MessageId: %s", response.get("MessageId"))
        return response


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    logger.info("Iniciando geração de relatório semanal...")
    table_name = os.environ.get("TABLE_NAME", "feedbacks_db")
    queue_url = os.environ.get("SQS_QUEUE_URL", "")
    recipient = os.environ.get("MANAGEMENT_EMAIL", "giulianogoliver84@outlook.com")

    generator = ReportGenerator(table_name=table_name, queue_url=queue_url, recipient=recipient)
    items = generator.query_last_7_days()
    summary = generator.compute_summary(items)

    if queue_url:
        generator.publish_to_sqs(summary)
    else:
        logger.warning("SQS_QUEUE_URL não configurada. Mensagem não publicada na fila.")

    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "message": "Relatório semanal gerado e processado com sucesso.",
                "summary": {
                    "media_geral": summary.media_geral,
                    "total_avaliacoes": summary.total_avaliacoes,
                    "avaliacoes_por_urgencia": summary.avaliacoes_por_urgencia,
                    "avaliacoes_por_dia": summary.avaliacoes_por_dia,
                    "data_envio": summary.data_envio,
                },
            }
        ),
    }


handler = lambda_handler
