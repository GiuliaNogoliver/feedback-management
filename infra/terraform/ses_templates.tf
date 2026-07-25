resource "aws_ses_template" "critical_alert" {
  name    = "CriticalAlertTemplate"
  subject = "⚠️ ALERTA: Avaliação Crítica Recebida"

  html = <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
        .card { background: #ffffff; border-radius: 8px; border-top: 6px solid #D32F2F; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 600px; margin: auto; padding: 24px; }
        .header { color: #D32F2F; margin-top: 0; }
        .badge { background-color: #FFEBEE; color: #C62828; padding: 6px 12px; border-radius: 4px; font-weight: bold; display: inline-block; }
        .item { margin-bottom: 10px; color: #333333; }
        .footer { font-size: 12px; color: #777777; margin-top: 24px; border-top: 1px solid #eee; padding-top: 12px; }
    </style>
</head>
<body>
    <div class="card">
        <h2 class="header">⚠️ Alerta de Avaliação Crítica</h2>
        <div class="item"><strong>ID do Feedback:</strong> {{feedback_id}}</div>
        <div class="item"><span class="badge">Nota: {{nota}} / 10</span></div>
        <div class="item"><strong>Urgência:</strong> {{urgencia}}</div>
        <div class="item"><strong>Data de Envio:</strong> {{data_envio}}</div>
        <p><strong>Descrição:</strong></p>
        <blockquote style="background: #fafafa; border-left: 4px solid #D32F2F; margin: 0; padding: 10px 15px; color: #333;">
            {{descricao}}
        </blockquote>
        <div class="footer">
            Plataforma de Gestão de Feedbacks &bull; Notificação Automática via AWS SES
        </div>
    </div>
</body>
</html>
EOF
}

resource "aws_ses_template" "weekly_report" {
  name    = "WeeklyReportTemplate"
  subject = "📊 Relatório Semanal de Avaliações"

  html = <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
        .card { background: #ffffff; border-radius: 8px; border-top: 6px solid #1976D2; box-shadow: 0 4px 6px rgba(0,0,0,0.1); max-width: 600px; margin: auto; padding: 24px; }
        .header { color: #1976D2; margin-top: 0; }
        .metric { background-color: #E3F2FD; color: #1565C0; padding: 12px; border-radius: 6px; margin-bottom: 12px; }
        .footer { font-size: 12px; color: #777777; margin-top: 24px; border-top: 1px solid #eee; padding-top: 12px; }
    </style>
</head>
<body>
    <div class="card">
        <h2 class="header">📈 Relatório Semanal de Avaliações</h2>
        <div class="metric"><strong>Média Geral:</strong> {{media_geral}}</div>
        <div class="metric"><strong>Total de Avaliações:</strong> {{total_avaliacoes}}</div>
        <div class="metric"><strong>Avaliações por Urgência:</strong> {{avaliacoes_por_urgencia}}</div>
        <div class="metric"><strong>Avaliações por Dia:</strong> {{avaliacoes_por_dia}}</div>
        <div class="metric"><strong>Data de Envio:</strong> {{data_envio}}</div>
        <div class="footer">
            Plataforma de Gestão de Feedbacks &bull; Relatório Automático via Amazon SES
        </div>
    </div>
</body>
</html>
EOF
}
