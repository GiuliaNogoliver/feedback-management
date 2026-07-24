import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Evento recebido: %s", json.dumps(event, default=str))
    return {"statusCode": 200, "body": json.dumps({"message": "Notificação crítica processada com sucesso"})}
