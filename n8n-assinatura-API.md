# 🔌 API — Endpoints e Webhooks

Documentação completa de endpoints N8N e webhooks externos.

---

## 🎯 Base URL

```
N8N Local: http://localhost:5678
N8N Remote: https://seu-dominio.com
```

---

## 📤 Workflow 1: Envio (HTTP Trigger)

### Request

```http
POST /webhook/assinatura/enviar HTTP/1.1
Host: localhost:5678
Content-Type: application/json

{
  "teste": false,
  "disparado_por": "webhook_manual"
}
```

### Response (200 OK)

```json
{
  "status": "sucesso",
  "total_enviados": 3,
  "detalhes": [
    {
      "colaborador": "João Silva",
      "email": "joao@tchea.com.br",
      "clicksign_url": "https://app.clicksign.com/.../sign/...",
      "status": "enviado"
    },
    {
      "colaborador": "Maria Santos",
      "email": "maria@tchea.com.br",
      "clicksign_url": "https://app.clicksign.com/.../sign/...",
      "status": "enviado"
    },
    {
      "colaborador": "Carlos Oliveira",
      "email": "carlos@tchea.com.br",
      "clicksign_url": "https://app.clicksign.com/.../sign/...",
      "status": "enviado"
    }
  ],
  "timestamp": "2025-01-15T08:30:45.123Z"
}
```

### Error Response (400 Bad Request)

```json
{
  "status": "erro",
  "mensagem": "Arquivo CSV não encontrado",
  "codigo_erro": "FILE_NOT_FOUND",
  "timestamp": "2025-01-15T08:30:45.123Z"
}
```

---

## 📨 ClickSign API

### Criar Documento (via N8N)

**Requisição interna (N8N → ClickSign):**

```http
POST https://app.clicksign.com/api/v1/documents HTTP/1.1
Authorization: Bearer {{ CLICKSIGN_API_TOKEN }}
Content-Type: application/json

{
  "document": {
    "path": "/home/node/n8n/documentos/termo-whatsapp-lgpd.pdf",
    "signers": [
      {
        "email": "joao@tchea.com.br",
        "name": "João Silva",
        "act": "sign"
      }
    ],
    "deadline": "2025-02-14",
    "message": "Prezado João Silva,\n\nPor favor, confirme recebimento e assine o Termo de Ciência e Responsabilidade.\n\nCPF: 123.456.789-10\nData: 15/01/2025\nLocal: Matriz - Formosa/GO"
  }
}
```

**Resposta ClickSign:**

```json
{
  "document": {
    "id": "doc_abc123def456",
    "url": "https://app.clicksign.com/a/documents/abc123/show",
    "signers": [
      {
        "id": "sig_123",
        "email": "joao@tchea.com.br",
        "name": "João Silva",
        "act": "sign",
        "signed_at": null,
        "refused_at": null
      }
    ],
    "created_at": "2025-01-15T08:30:45Z",
    "deadline": "2025-02-14"
  }
}
```

### Consultar Documento

```http
GET https://app.clicksign.com/api/v1/documents/doc_abc123def456 HTTP/1.1
Authorization: Bearer {{ CLICKSIGN_API_TOKEN }}
```

**Resposta:**

```json
{
  "document": {
    "id": "doc_abc123def456",
    "status": "signed",
    "signers": [
      {
        "email": "joao@tchea.com.br",
        "signed_at": "2025-01-15T10:30:00Z"
      }
    ]
  }
}
```

---

## 🔗 Webhook ClickSign → N8N

### Quando Documento é Assinado

**ClickSign envia POST para N8N:**

```http
POST /webhook/clicksign/assinado HTTP/1.1
Host: seu-servidor.com:5678
Content-Type: application/json
X-Clicksign-Signature: sha256=abc123...

{
  "document": {
    "id": "doc_abc123def456",
    "url": "https://app.clicksign.com/a/documents/abc123/show",
    "status": "signed",
    "signers": [
      {
        "id": "sig_123",
        "email": "joao@tchea.com.br",
        "name": "João Silva",
        "act": "sign",
        "signed_at": "2025-01-15T10:30:00Z",
        "refused_at": null
      }
    ],
    "created_at": "2025-01-15T08:30:45Z",
    "deadline": "2025-02-14"
  }
}
```

### Resposta Esperada do N8N

```json
{
  "status": "acknowledged",
  "message": "Assinatura registrada com sucesso",
  "timestamp": "2025-01-15T10:30:05.123Z"
}
```

---

## 📧 Email via Outlook SMTP

### Envio (via N8N)

**Configuração N8N:**

```javascript
{
  "to": "joao@tchea.com.br",
  "from": "noreply@tchea.com.br",
  "subject": "Assinatura Digital - Termo LGPD WhatsApp",
  "html": "<h2>Olá João Silva</h2><p><a href='https://app.clicksign.com/...'>Assinar</a></p>",
  "text": "Clique no link para assinar: https://app.clicksign.com/..."
}
```

**Protocolo:** SMTP TLS
**Host:** smtp-mail.outlook.com
**Porta:** 587
**Timeout:** 30s

### Confirmação

```json
{
  "status": "enviado",
  "message_id": "abc123@outlook.com",
  "timestamp": "2025-01-15T08:31:00Z"
}
```

---

## 📱 WhatsApp via Twilio

### Envio (via N8N)

**Configuração N8N:**

```javascript
{
  "to": "+5511987654321",
  "from": "+55119XXXXXXXXX",
  "body": "Olá João Silva 👋\n\nAssine agora: https://app.clicksign.com/.../sign/...\n\nPrazo: 30 dias"
}
```

**Tipo:** WhatsApp Business
**Timeout:** 10s

### Confirmação

```json
{
  "status": "enviado",
  "message_sid": "SMxxx123xxx",
  "to": "+5511987654321",
  "timestamp": "2025-01-15T08:31:05Z"
}
```

---

## 🗄️ Database PostgreSQL

### Inserção de Dados

**N8N → PostgreSQL:**

```javascript
{
  "nome_completo": "João Silva",
  "cpf": "123.456.789-10",
  "email": "joao@tchea.com.br",
  "telefone": "+5511987654321",
  "clicksign_doc_id": "doc_abc123def456",
  "clicksign_url": "https://app.clicksign.com/.../sign/...",
  "status": "enviado",
  "canal_notificacao": "email_whatsapp",
  "data_envio": "2025-01-15T08:30:45Z",
  "local_assinatura": "Matriz - Formosa/GO"
}
```

### Consulta de Status

```sql
SELECT nome_completo, email, status, data_assinatura
FROM assinaturas
WHERE cpf = '123.456.789-10';
```

---

## 🔄 Workflow 3: Relatório (Cron Daily)

### Trigger

```
Cron: 0 9 * * *  (09:00 todo dia)
```

### Dados Agregados

```json
{
  "data_relatorio": "15/01/2025",
  "total": 10,
  "assinados": 7,
  "pendentes": 3,
  "recusados": 0,
  "percentual_assinados": 70.0,
  "taxa_media_horas": 14.5
}
```

### Email Destino

```
To: gestor@tchea.com.br
Subject: 📊 Relatório Diário - Assinaturas LGPD (15/01/2025)
```

---

## 🧪 Exemplos de Testes

### 1. Teste com cURL (Envio Manual)

```bash
curl -X POST http://localhost:5678/webhook/assinatura/enviar \
  -H "Content-Type: application/json" \
  -d '{"teste": false}'
```

### 2. Teste de Email (Outlook)

```bash
# Via N8N: Send Email node
# Credential: Outlook
# To: seu-email-teste@outlook.com
# Subject: Teste Outlook
# Clique: Send
```

### 3. Teste de WhatsApp (Twilio)

```bash
# Via N8N: Send Twilio Message node
# Credential: Twilio
# To: +55 seu telefone
# Message: Teste Twilio
# Clique: Send
```

### 4. Teste de Webhook ClickSign

```bash
curl -X POST http://localhost:5678/webhook/clicksign/assinado \
  -H "Content-Type: application/json" \
  -H "X-Clicksign-Signature: sha256=test" \
  -d '{
    "document": {
      "id": "doc_test123",
      "signers": [
        {
          "email": "teste@mail.com",
          "signed_at": "2025-01-15T10:30:00Z"
        }
      ]
    }
  }'
```

---

## 🔐 Autenticação

### N8N (Local)

```
Nenhuma autenticação necessária (localhost)
Em produção, usar OAuth2 ou API Key
```

### ClickSign

```
Authorization: Bearer {{ CLICKSIGN_API_TOKEN }}
```

### Twilio

```
Authorization: Basic {{ base64(ACCOUNT_SID:AUTH_TOKEN) }}
```

### PostgreSQL

```
Username: app_user
Password: app_password_secure
```

---

## 📊 Rate Limiting

| Serviço | Limite | Período |
|---------|--------|---------|
| **ClickSign** | Não especificado | - |
| **Outlook** | 300 emails/dia (pessoal) | 24h |
| **Twilio** | Depende do plano | - |
| **N8N** | Sem limite (local) | - |

---

## ❌ Códigos de Erro

### ClickSign

| Código | Mensagem | Solução |
|--------|----------|---------|
| 401 | Unauthorized | Verificar API token |
| 404 | Document not found | Verificar ID do documento |
| 422 | Invalid document | Verificar formato PDF |

### Outlook SMTP

| Código | Mensagem | Solução |
|--------|----------|---------|
| 550 | User not found | Verificar email |
| 535 | Authentication failed | Verificar senha/token |
| 552 | Too many recipients | Aguardar próximo ciclo |

### Twilio

| Código | Mensagem | Solução |
|--------|----------|---------|
| 20003 | Invalid phone number | Verificar formato +55... |
| 20005 | Invalid auth token | Regenerar token |
| 20006 | Account not authorized | Ativar WhatsApp Business |

---

## 📝 Logging

### N8N Execution Logs

```
Dashboard → Workflows → Executions → Ver detalhe
```

### Database Audit Trail

```sql
SELECT acao, data_acao, detalhes
FROM auditoria_assinaturas
WHERE assinatura_id = 1
ORDER BY data_acao DESC;
```

### System Logs

```bash
docker-compose logs -f n8n | head -50
```

---

**Próximo (e último) documento: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)**
