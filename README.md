# 🚀 Plataforma Serverless de Gestão de Feedbacks

[![Terraform](https://img.shields.io/badge/IaC-Terraform_v1.5+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/Cloud-AWS_Serverless-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Python](https://img.shields.io/badge/Language-Python_3.12-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)

Solução enterprise 100% **Serverless** e orientada a eventos (*Event-Driven Architecture*) desenvolvida na AWS para ingestão, avaliação de urgência em tempo real, geração automatizada de relatórios e notificação de avaliações de clientes/alunos.

Toda a infraestrutura é provisionada via **Terraform** como Código (IaC), utilizando boas práticas de arquitetura AWS, menor privilégio IAM, filas de mensagens mortas (DLQ), validação de payloads via API Gateway e observabilidade nativa com **Amazon CloudWatch Dashboards**.

---

## 📐 Arquitetura da Solução

```mermaid
graph TD
    User["👤 Aluno / Cliente"] -->|POST /avaliacao| APIGW["🌐 AWS API Gateway"]
    Admin["👨‍💼 Admin / Gestão"] -->|POST /relatorio| APIGW

    subgraph API Gateway & Security
        APIGW -->|API Key + Usage Plan| APIGW_Val["Validar Payload & Rate Limits"]
    end

    APIGW_Val -->|Ingestão| LambdaReceive["⚡ Lambda: receive-feedback"]
    APIGW_Val -->|Relatório Sob Demanda| LambdaReport["⚡ Lambda: generate-report"]

    subgraph Storage & Event Streams
        LambdaReceive -->|PutItem| DynamoDB[("🗄️ DynamoDB: feedbacks_db")]
        DynamoDB -->|DynamoDB Stream| LambdaUrgency["⚡ Lambda: evaluate-urgency"]
    end

    subgraph Event Processing & Messaging
        LambdaUrgency -->|Atualização Atômica| DynamoDB
        LambdaUrgency -->|Alerta Crítico (nota <= 4)| SQS["📩 SQS: notify-email-queue"]
        LambdaReport -->|Geração de Relatório| SQS
        SQS -->|Redrive Policy| DLQ["📬 SQS DLQ: notify-email-queue-dlq"]
        EventBridge["⏱️ EventBridge Scheduler (Semanal)"] -->|Trigger Cron| LambdaReport
    end

    subgraph Notifications & Templates
        SQS -->|Event Source Mapping| LambdaEmail["⚡ Lambda: send-email"]
        LambdaEmail -->|SES Template| SES["📧 Amazon SES"]
        SES -->|E-mail HTML| EmailDest["📬 Destinatário / Gestão"]
    end

    subgraph Observability & Config
        CloudWatch["📊 CloudWatch Dashboard & Metric Filters"]
        SSM["🔐 SSM Parameter Store (/config/urgency_thresholds)"]
    end
```

---

## 🛠️ Tecnologias e Serviços AWS Utilizados

| Serviço | Função na Arquitetura |
| :--- | :--- |
| **AWS API Gateway** | Ponto de entrada REST com validação JSON Schema, API Keys e Usage Plans (RBAC). |
| **AWS Lambda (Python 3.12)** | Processamento Serverless desacoplado (Ingestão, Urgência, Relatório e Notificação). |
| **Amazon DynamoDB** | Banco NoSQL com Global Secondary Index (`DateIndex`) e DynamoDB Streams ativado. |
| **Amazon SQS** | Desacoplamento assíncrono com Dead Letter Queue (`notify-email-queue-dlq`). |
| **Amazon SNS** | Tópicos de notificação com integração SQS e assinaturas de e-mail. |
| **Amazon SES** | Envio de e-mails estilizados via templates HTML (`CriticalAlertTemplate`, `WeeklyReportTemplate`). |
| **EventBridge Scheduler** | Disparo cronometrado para relatórios semanais consolidados. |
| **SSM Parameter Store** | Configurações dinâmicas de e-mails e regras de corte de urgência sem necessidade de redeploy. |
| **Amazon CloudWatch** | Logs estruturados, Metric Filters e Dashboard visual customizado de métricas de negócio. |
| **Terraform (HCL)** | Gerenciamento automatizado de toda a infraestrutura com estado remoto em S3. |

---

## 🔑 Segurança e Autenticação (RBAC & API Keys)

A API utiliza **API Keys** associadas a **Usage Plans** do API Gateway para aplicar controle de acesso granular baseado no perfil do solicitante:

| Perfil | Header Obrigatório | Rotas Permitidas | Limites (Throttling / Quota) |
| :--- | :--- | :--- | :--- |
| **Aluno** | `x-api-key: <STUDENT_API_KEY>` | `POST /avaliacao` | 10 req/s (Burst: 20) \| 10.000 req/mês |
| **Admin** | `x-api-key: <ADMIN_API_KEY>` | `POST /avaliacao`, `POST /relatorio` | 20 req/s (Burst: 50) \| 50.000 req/mês |

> 🚫 Tentativas de chamadas para `/relatorio` usando a API Key de Aluno são bloqueadas com `403 Forbidden` no próprio API Gateway.

---

## 🚀 Endpoints da API

### 1. Envio de Avaliação / Feedback
- **URL**: `POST /dev/avaliacao`
- **Headers**:
  - `Content-Type: application/json`
  - `x-api-key: <STUDENT_API_KEY>`
- **Payload de Exemplo**:
```json
{
  "nota": 3,
  "descricao": "O tempo de resposta do suporte foi muito longo."
}
```
- **Resposta Sucesso (`201 Created`)**:
```json
{
  "message": "Feedback recebido com sucesso!",
  "id": "e4a7b3c2-891d-4e5f-92a1-b847192305a1"
}
```

---

### 2. Geração de Relatório (Sob Demanda)
- **URL**: `POST /dev/relatorio`
- **Headers**:
  - `Content-Type: application/json`
  - `x-api-key: <ADMIN_API_KEY>`
- **Payload Opcional**:
```json
{
  "days": 7,
  "urgencia": "ALL"
}
```
- **Resposta Sucesso (`200 OK`)**:
```json
{
  "message": "Relatório gerado e enviado com sucesso.",
  "parameters": {
    "days": 7,
    "urgencia": "ALL"
  },
  "summary": {
    "media_geral": "7.5",
    "total_avaliacoes": "14",
    "avaliacoes_por_urgencia": "Alta: 2, Média: 4, Baixa: 8",
    "avaliacoes_por_dia": "2026-07-28: 14",
    "data_envio": "2026-07-28"
  }
}
```

---

## 📊 Dashboard de Observabilidade (CloudWatch)

O projeto provisiona automaticamente o Dashboard visual **`FeedbackPlatform-Business-Dashboard`** no CloudWatch com as seguintes métricas:

- **📊 Total de Feedbacks Recebidos**: Métrica extraída dos logs da Lambda `receive-feedback`.
- **🚨 Avaliações Críticas (`ALTA`)**: Métrica de feedbacks com `nota <= 4` identificados pela Lambda `evaluate-urgency`.
- **📧 E-mails Enviados via SES**: Quantidade de notificações disparadas com sucesso via SES Template.
- **📈 Relatórios Gerados**: Total de relatórios consolidados emitidos sob demanda ou via EventBridge.
- **⚡ Saúde Operacional das Lambdas**: Gráfico de invocações e erros de todas as funções Serverless.
- **📜 Tabela de Logs em Tempo Real**: Consulta estruturada das últimas execuções de ingestão.

---

## 📂 Estrutura do Repositório

```text
.
├── .github/
│   └── workflows/          # Pipelines CI/CD (PR validation e Deploy no merge)
├── app/
│   └── lambdas/            # Código-fonte das funções Python 3.12
│       ├── evaluate-urgency/
│       ├── generate-report/
│       ├── receive-feedback/
│       └── send-email/
├── collection/
│   └── Feedback.postman_collection.json  # Postman Collection pronta para testes
├── infra/
│   └── terraform/          # Arquivos de Infraestrutura como Código (HCL)
│       ├── apigateway.tf   # REST API, Models, Validators e Usage Plans
│       ├── cloudwatch.tf   # Metric Filters, Alertas e Dashboard
│       ├── dynamodb.tf     # Tabela NoSQL e GSI DateIndex
│       ├── eventbridge.tf  # Agendamento semanal cron
│       ├── iam.tf          # Papéis IAM de Menor Privilégio por Lambda
│       ├── lambdas.tf      # Definição e empacotamento das Lambdas
│       ├── provider.tf     # Provedor AWS e Backend S3 Remote State
│       ├── ses_templates.tf# Templates HTML do Amazon SES
│       ├── sns.tf          # Tópicos SNS e Assinaturas
│       ├── sqs.tf          # Fila SQS e Dead Letter Queue (DLQ)
│       ├── ssm.tf          # Parameter Store
│       └── variables.tf    # Variáveis de configuração
└── README.md
```

---

## ⚙️ Como Executar a Infraestrutura Localmente

### Pré-requisitos
- [Terraform](https://www.terraform.io/downloads) (>= 1.5.0)
- [AWS CLI](https://aws.amazon.com/cli/) configurado com credenciais válidas
- [Python](https://www.python.org/) 3.12+

### 1. Clonar o Repositório
```bash
git clone https://github.com/GiuliaNogoliver/feedback-management.git
cd feedback-management/infra/terraform
```

### 2. Inicializar o Terraform
```bash
terraform init
```

### 3. Verificar o Plano de Execução
```bash
terraform plan
```

### 4. Aplicar a Infraestrutura na AWS
```bash
terraform apply
```

Ao final da execução, o Terraform exibirá a **URL do API Gateway** e as **API Keys** geradas para os perfis `Student` e `Admin`.

---

## 🔄 Pipeline CI/CD (GitHub Actions)

O repositório possui fluxos automatizados em `.github/workflows/`:
1. **`01-pr-pipeline.yml`**: Executado em Pull Requests. Valida formatação (`terraform fmt`), sintaxe (`terraform validate`), linting e gera o resumo do `terraform plan`.
2. **`02-deploy-on-merge.yml`**: Executado automaticamente no merge com a branch `main`. Executa o `terraform apply` com auto-aprovação na conta AWS.

---

## 📄 Licença

Este projeto está sob a licença [MIT](LICENSE).
