# 🔄 Workflows Detalhados — N8N

Explicação nó-a-nó dos 3 workflows principais.

---

## 📊 Workflow 1: ENVIO (Disparo + Processamento)

**Objetivo**: Ler colaboradores → Enviar para ClickSign → Notificar → Registrar BD

### Fluxo Visual

```
Trigger HTTP/Cron
    ↓
Read File (CSV)
    ↓
Code Node (Preparação)
    ↓
Loop: Para cada linha
    ├─ Validar dados
    ├─ ClickSign (POST)
    ├─ Email (Outlook)
    ├─ WhatsApp (Twilio)
    └─ Database (INSERT)
    ↓
Response
```

### Nós Detalhados

#### 1. Trigger (HTTP Request)

```
Type: HTTP Request
Method: POST
Path: /webhook/assinatura/enviar

Resposta esperada:
{
  "status": "success",
  "total": 3,
  "enviados": 3,
  "erros": 0
}
```

#### 2. Read File

```
File Path: /home/node/n8n/dados/colaboradores.csv

Formato esperado:
nome,cpf,email,telefone
João Silva,123.456.789-10,joao@tchea.com,11987654321
```

#### 3. Code Node — Preparar Dados

```javascript
// Validar cada linha
const data = $input.item.json;

if (!data.nome || !data.cpf || !data.email) {
    throw new Error('Dados incompletos');
}

// Formatar telefone (+55...)
const telefone = '+55' + data.telefone.replace(/\D/g, '');

return [{
    json: {
        nome_completo: data.nome,
        cpf: data.cpf,
        email: data.email,
        telefone: telefone,
        data_assinatura: new Date().toLocaleDateString('pt-BR'),
        local_assinatura: 'Matriz - Formosa/GO'
    }
}];
```

#### 4. Loop — Para Cada Linha

```
Type: Loop (Iterate over items)
```

#### 5. HTTP Request — ClickSign (POST)

```
URL: {{ $env.CLICKSIGN_API_URL }}/documents
Method: POST

Headers:
- Authorization: Bearer {{ $env.CLICKSIGN_API_TOKEN }}
- Content-Type: application/json

Body (JSON):
{
  "document": {
    "path": "{{ $env.DOCUMENTO_PATH }}",
    "signers": [
      {
        "email": "{{ $node.CodeNode.json.email }}",
        "name": "{{ $node.CodeNode.json.nome_completo }}",
        "act": "sign"
      }
    ],
    "deadline": "{{ dateAdd(now(), 30, 'days').toISOString().split('T')[0] }}",
    "message": "Prezado {{ $node.CodeNode.json.nome_completo }},\n\nPor favor, confirme recebimento e assine o Termo de Ciência e Responsabilidade de Uso do WhatsApp Corporativo.\n\nCPF: {{ $node.CodeNode.json.cpf }}\nData: {{ $node.CodeNode.json.data_assinatura }}\nLocal: {{ $node.CodeNode.json.local_assinatura }}\n\nObrigado."
  }
}
```

**Resposta esperada**:
```json
{
  "document": {
    "id": "doc_abc123",
    "url": "https://app.clicksign.com/.../sign/...",
    "signers": [...]
  }
}
```

#### 6. Send Email — Outlook

```
Credential: Outlook (SMTP)

From: {{ $env.OUTLOOK_FROM_EMAIL }}
To: {{ $node.CodeNode.json.email }}
Subject: Assinatura Digital - Termo LGPD WhatsApp

Body (HTML):
<h2>Olá {{ $node.CodeNode.json.nome_completo }}</h2>

<p><strong>Informações:</strong></p>
<ul>
  <li><strong>CPF:</strong> {{ $node.CodeNode.json.cpf }}</li>
  <li><strong>Data:</strong> {{ $node.CodeNode.json.data_assinatura }}</li>
  <li><strong>Local:</strong> {{ $node.CodeNode.json.local_assinatura }}</li>
</ul>

<p><a href="{{ $node['HTTP Request'].json.document.url }}" style="background-color: #0078d4; color: white; padding: 10px 20px; text-decoration: none; border-radius: 4px;">
  ✏️ Clique para Assinar
</a></p>

<p>Validade: 30 dias</p>

<hr>

<p><small>Tchê Agrícola - Departamento de RH</small></p>
```

#### 7. Send WhatsApp — Twilio

```
Credential: Twilio

To: {{ $node.CodeNode.json.telefone }}

Message:
Olá {{ $node.CodeNode.json.nome_completo }} 👋

Preciso que você assine um documento importante:
📄 Termo de Ciência e Responsabilidade - WhatsApp Corporativo

ℹ️ CPF: {{ $node.CodeNode.json.cpf }}
📅 Data: {{ $node.CodeNode.json.data_assinatura }}
📍 Local: {{ $node.CodeNode.json.local_assinatura }}

🔗 Assine agora:
{{ $node['HTTP Request'].json.document.url }}

Prazo: 30 dias
Dúvidas? Contate RH.
```

#### 8. Database — INSERT (PostgreSQL)

```sql
INSERT INTO assinaturas 
(nome_completo, cpf, email, telefone, clicksign_doc_id, clicksign_url, status, canal_notificacao, data_envio, local_assinatura)
VALUES
(
  '{{ $node.CodeNode.json.nome_completo }}',
  '{{ $node.CodeNode.json.cpf }}',
  '{{ $node.CodeNode.json.email }}',
  '{{ $node.CodeNode.json.telefone }}',
  '{{ $node['HTTP Request'].json.document.id }}',
  '{{ $node['HTTP Request'].json.document.url }}',
  'enviado',
  'email_whatsapp',
  NOW(),
  '{{ $node.CodeNode.json.local_assinatura }}'
)
```

#### 9. Audit Log — INSERT (LGPD)

```sql
INSERT INTO auditoria_assinaturas (assinatura_id, acao, detalhes)
SELECT id, 'notificado_email_whatsapp', 
  json_build_object(
    'email', '{{ $node.CodeNode.json.email }}',
    'telefone', '{{ $node.CodeNode.json.telefone }}',
    'timestamp', NOW()
  )::text
FROM assinaturas 
WHERE cpf = '{{ $node.CodeNode.json.cpf }}'
LIMIT 1
```

#### 10. End Node — Response

```json
{
  "status": "enviado",
  "colaborador": "{{ $node.CodeNode.json.nome_completo }}",
  "clicksign_url": "{{ $node['HTTP Request'].json.document.url }}"
}
```

---

## 🔗 Workflow 2: WEBHOOK (Retorno de Assinatura)

**Objetivo**: Receber confirmação ClickSign → Atualizar BD → Notificar confirmação

### Fluxo Visual

```
Webhook ClickSign (POST)
    ↓
Parse Response
    ↓
Database (UPDATE)
    ↓
├─ Email confirmação
├─ WhatsApp confirmação
└─ Audit Log

Response ✅
```

### Nós Detalhados

#### 1. Webhook Trigger

```
Type: Webhook
Method: POST
Path: /webhook/clicksign/assinado

Headers esperado:
X-Clicksign-Signature: {hash}

Body esperado:
{
  "document": {
    "id": "doc_abc123",
    "signers": [
      {
        "email": "joao@tchea.com",
        "signed_at": "2025-01-15T10:30:00Z"
      }
    ]
  }
}
```

#### 2. Code Node — Parse ClickSign

```javascript
const doc = $input.body.document;
const signer = doc.signers[0];

return [{
    json: {
        doc_id: doc.id,
        signer_email: signer.email,
        signed_at: signer.signed_at,
        data_assinatura: new Date(signer.signed_at).toLocaleDateString('pt-BR')
    }
}];
```

#### 3. Database — UPDATE Status

```sql
UPDATE assinaturas 
SET 
  status = 'assinado',
  data_assinatura = NOW(),
  clicksign_doc_id = '{{ $node.CodeNode.json.doc_id }}'
WHERE email = '{{ $node.CodeNode.json.signer_email }}'
LIMIT 1
```

#### 4. Database — SELECT (Recuperar dados)

```sql
SELECT nome_completo, email, telefone, cpf, local_assinatura
FROM assinaturas
WHERE email = '{{ $node.CodeNode.json.signer_email }}'
LIMIT 1
```

#### 5. Send Email — Confirmação

```
To: {{ $node.CodeNode.json.signer_email }}
Subject: ✅ Documento Assinado com Sucesso

Body (HTML):
<h2>Documento Assinado com Êxito ✅</h2>

<p>Prezado(a) {{ $node['Database'].json[0].nome_completo }},</p>

<p>Confirmamos que você assinou o Termo de Ciência e Responsabilidade.</p>

<p><strong>Detalhes:</strong></p>
<ul>
  <li>CPF: {{ $node['Database'].json[0].cpf }}</li>
  <li>Data de Assinatura: {{ $node.CodeNode.json.data_assinatura }}</li>
  <li>Local: {{ $node['Database'].json[0].local_assinatura }}</li>
</ul>

<p>Obrigado por colaborar! 🙏</p>
```

#### 6. Send WhatsApp — Confirmação

```
To: {{ $node['Database'].json[0].telefone }}

Message:
✅ Documento assinado com sucesso!

Você completou a assinatura do Termo de Ciência e Responsabilidade.

📄 Referência: {{ $node.CodeNode.json.doc_id }}
📅 Data: {{ $node.CodeNode.json.data_assinatura }}

Obrigado! 🙏
```

#### 7. Audit Log — Confirmação

```sql
INSERT INTO auditoria_assinaturas (assinatura_id, acao, detalhes)
SELECT id, 'assinado', 
  json_build_object(
    'data_assinatura', '{{ $node.CodeNode.json.signed_at }}',
    'clicksign_doc_id', '{{ $node.CodeNode.json.doc_id }}'
  )::text
FROM assinaturas 
WHERE email = '{{ $node.CodeNode.json.signer_email }}'
LIMIT 1
```

#### 8. End Node — Acknowledge

```json
{
  "status": "acknowledged",
  "message": "Assinatura registrada com sucesso"
}
```

---

## 📊 Workflow 3: RELATÓRIO (Consolidação Diária)

**Objetivo**: Contar assinados/pendentes → Gerar relatório → Enviar para gestor

### Fluxo Visual

```
Trigger Cron (09:00 todo dia)
    ↓
Database Query (Agregação)
    ↓
Code Node (Formatação)
    ↓
Send Email (Gestor RH)
    ↓
Response ✅
```

### Nós Detalhados

#### 1. Trigger — Cron

```
Type: Cron
Schedule: 0 9 * * * (09:00 todo dia)
```

#### 2. Database Query — Agregação

```sql
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END) as assinados,
  SUM(CASE WHEN status = 'enviado' THEN 1 ELSE 0 END) as pendentes,
  SUM(CASE WHEN status = 'recusado' THEN 1 ELSE 0 END) as recusados,
  ROUND(
    SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END)::numeric / 
    COUNT(*) * 100, 2
  ) as percentual_assinados
FROM assinaturas
WHERE DATE(data_envio) = CURRENT_DATE
```

#### 3. Code Node — Formatação

```javascript
const data = $input.item.json;

const today = new Date().toLocaleDateString('pt-BR');

return [{
    json: {
        data_relatorio: today,
        total: data.total,
        assinados: data.assinados,
        pendentes: data.pendentes,
        recusados: data.recusados,
        percentual: data.percentual_assinados,
        progresso_bar: '█'.repeat(Math.round(data.percentual_assinados / 5)) + 
                       '░'.repeat(20 - Math.round(data.percentual_assinados / 5))
    }
}];
```

#### 4. Send Email — Gestor RH

```
To: gestor@tchea.com.br
Subject: 📊 Relatório Diário - Assinaturas LGPD ({{ $node.CodeNode.json.data_relatorio }})

Body (HTML):
<h2>📊 Relatório Diário - Assinaturas LGPD</h2>

<p><strong>Data:</strong> {{ $node.CodeNode.json.data_relatorio }}</p>

<table style="border-collapse: collapse; width: 100%;">
  <tr style="border: 1px solid #ddd;">
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>Métrica</strong></td>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>Quantidade</strong></td>
  </tr>
  <tr style="background-color: #f9f9f9;">
    <td style="padding: 10px; border: 1px solid #ddd;">Total</td>
    <td style="padding: 10px; border: 1px solid #ddd;">{{ $node.CodeNode.json.total }}</td>
  </tr>
  <tr style="background-color: #e8f5e9;">
    <td style="padding: 10px; border: 1px solid #ddd;">✅ Assinados</td>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>{{ $node.CodeNode.json.assinados }}</strong></td>
  </tr>
  <tr style="background-color: #fff3e0;">
    <td style="padding: 10px; border: 1px solid #ddd;">⏳ Pendentes</td>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>{{ $node.CodeNode.json.pendentes }}</strong></td>
  </tr>
  <tr style="background-color: #ffebee;">
    <td style="padding: 10px; border: 1px solid #ddd;">❌ Recusados</td>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>{{ $node.CodeNode.json.recusados }}</strong></td>
  </tr>
  <tr style="background-color: #e3f2fd;">
    <td style="padding: 10px; border: 1px solid #ddd;">📈 Percentual Assinado</td>
    <td style="padding: 10px; border: 1px solid #ddd;"><strong>{{ $node.CodeNode.json.percentual }}%</strong></td>
  </tr>
</table>

<br>

<p><strong>Progresso:</strong></p>
<p style="font-family: monospace; font-size: 12px;">{{ $node.CodeNode.json.progresso_bar }}</p>

<hr>

<p><small>Relatório gerado automaticamente às 09:00</small></p>
```

#### 5. End Node

```json
{
  "relatorio_enviado": true,
  "timestamp": "{{ now() }}"
}
```

---

## 🔧 Configurar Triggers

### Webhook Trigger (Workflow 1)

1. Abra Workflow 1
2. Clique no primeiro nó
3. Copie URL: `http://localhost:5678/webhook/your-path`
4. Cadastre em ClickSign → Webhooks
5. Teste com POST manual

### Cron Trigger (Workflow 3)

1. Abra Workflow 3
2. Trigger → Cron
3. Configure: `0 9 * * *` (09:00)
4. Salve e ative

---

## 🧪 Testar Workflows

### Teste Manual (Workflow 1)

```bash
curl -X POST http://localhost:5678/webhook/assinatura/enviar \
  -H "Content-Type: application/json" \
  -d '{"teste": true}'
```

### Teste Cron (Workflow 3)

1. Abra Workflow 3
2. Clique **Execute** (botão azul)
3. Veja resultado em tempo real

---

**Próximo documento: [CONFIGURACAO.md](./CONFIGURACAO.md)**
