# 🏗️ Arquitetura Técnica — N8N + ClickSign

Detalhamento técnico da arquitetura, design de sistemas e fluxos de dados.

---

## 🏛️ Visão Geral

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAMADA DE APRESENTAÇÃO                       │
│                     (N8N Dashboard)                              │
└────────────────┬────────────────────────────────────────────────┘
                 │
┌────────────────▼────────────────────────────────────────────────┐
│                    CAMADA DE ORQUESTRAÇÃO                        │
│                   (N8N Workflows × 3)                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐      │
│  │   Workflow 1 │  │   Workflow 2 │  │   Workflow 3     │      │
│  │    ENVIO     │  │   WEBHOOK    │  │   RELATÓRIO      │      │
│  └──────────────┘  └──────────────┘  └──────────────────┘      │
└────────────────┬────────────────────────────────────────────────┘
                 │
         ┌───────┴───────┬───────────────┬──────────────┐
         │               │               │              │
┌────────▼──────┐ ┌──────▼──────┐ ┌────▼────────┐ ┌───▼──────┐
│  ClickSign    │ │  Outlook    │ │   Twilio    │ │PostgreSQL│
│     API       │ │   SMTP      │ │  WhatsApp   │ │   (2x)   │
└───────────────┘ └─────────────┘ └─────────────┘ └──────────┘
```

---

## 📊 Componentes

### 1. N8N (Orquestração)

**Responsabilidade**: Automação central de workflows

| Aspecto | Detalhes |
|---------|----------|
| **Versão** | latest (sempre atualizado) |
| **Porta** | 5678 |
| **Banco de Dados** | PostgreSQL (n8n) |
| **Volume** | `/home/node/.n8n` |
| **Ambiente** | Production |
| **Timezone** | America/Sao_Paulo |

**Workflows**:
1. **Envio** — Disparar + processar + notificar
2. **Webhook** — Receber + atualizar + confirmar
3. **Relatório** — Agregação + resumo diário

---

### 2. PostgreSQL N8N

**Responsabilidade**: Armazenar configuração interna N8N

| Aspecto | Detalhes |
|---------|----------|
| **Imagem** | postgres:15-alpine |
| **Container** | n8n_db |
| **Porta** | 5432 (interno) |
| **Database** | n8n |
| **Volume** | `./postgres_data` |
| **Usuário** | n8n |

**Dados armazenados**:
- Workflows
- Credentials
- Execution history
- Nodes configuration

---

### 3. PostgreSQL Assinatura

**Responsabilidade**: Armazenar dados de assinatura

| Aspecto | Detalhes |
|---------|----------|
| **Imagem** | postgres:15-alpine |
| **Container** | assinatura_db |
| **Porta** | 5432 (exposta) |
| **Database** | assinatura |
| **Volume** | `./postgres_assinatura_data` |
| **Usuário** | app_user |

**Dados armazenados**:
- Tabela: `assinaturas` (colaboradores + status)
- Tabela: `auditoria_assinaturas` (LGPD audit trail)

---

### 4. ClickSign (API Externa)

**Responsabilidade**: Assinatura digital dos documentos

| Aspecto | Detalhes |
|---------|----------|
| **Endpoint** | https://app.clicksign.com/api/v1 |
| **Autenticação** | Bearer Token |
| **Rate Limit** | Não especificado (verificar docs) |
| **Resposta** | JSON |
| **Webhook** | POST para N8N quando assinado |

**Endpoints usados**:
- `POST /documents` — Criar documento
- `GET /documents/{id}` — Consultar status
- Webhook: `POST /webhook/clicksign/assinado`

---

### 5. Outlook SMTP (Email)

**Responsabilidade**: Notificação por email

| Aspecto | Detalhes |
|---------|----------|
| **Host** | smtp-mail.outlook.com |
| **Porta** | 587 (TLS) |
| **Autenticação** | Username + Password |
| **Limite** | 300 emails/dia (pessoal) ou ilimitado (M365) |
| **Resposta** | Confirmation receipt |

**Mensagens**:
- Email inicial com link de assinatura
- Email de confirmação após assinado

---

### 6. Twilio (WhatsApp)

**Responsabilidade**: Notificação por WhatsApp

| Aspecto | Detalhes |
|---------|----------|
| **Endpoint** | https://api.twilio.com/2010-04-01 |
| **Autenticação** | Account SID + Auth Token |
| **Rate Limit** | Depende do plano |
| **Formato** | WhatsApp Business API |

**Mensagens**:
- Notificação inicial com link + QR code
- Confirmação após assinado

---

## 🔄 Fluxo de Dados — Caso de Uso 1: Envio

```
┌──────────────┐
│ Disparador   │ (Webhook HTTP POST ou Cron diário)
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Read CSV     │ Ler arquivo colaboradores.csv
└──────┬───────┘
       │
       ▼
┌──────────────────────────┐
│ Loop (Para cada linha)   │
├──────────────────────────┤
│ • Validar CPF            │
│ • Validar email          │
│ • Validar telefone       │
└──────┬───────────────────┘
       │
       ▼
┌──────────────────────────────┐
│ ClickSign (POST /documents)  │
├──────────────────────────────┤
│ Request:                     │
│  - path: termo-whatsapp.pdf  │
│  - signer: email + nome      │
│  - deadline: +30 dias        │
│                              │
│ Response:                    │
│  - document.id               │
│  - document.url              │
└──────┬───────────────────────┘
       │
       ▼
┌─────────────────┬──────────────────┐
│                 │                  │
▼                 ▼                  ▼
Email          WhatsApp         Database
Outlook SMTP   Twilio           PostgreSQL
│               │                │
│ To:           │ To:            │ INSERT
│ subject       │ msg            │ (nome, cpf, status)
│ link          │ link + QR      │
│               │                │
└───────────────┴────────────────┴─────────────┐
                                               │
                                    ┌──────────▼──────┐
                                    │ Await signature  │
                                    │ (Up to 30 days)  │
                                    └──────────────────┘
```

---

## 🔄 Fluxo de Dados — Caso de Uso 2: Retorno de Assinatura

```
┌────────────────────────┐
│ ClickSign Webhook      │
│ (documento assinado)   │
└────────┬───────────────┘
         │
         ▼
┌──────────────────────────────┐
│ N8N Webhook Trigger          │
│ POST /webhook/clicksign/...  │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────┐
│ Code Node (Parse resposta)   │
│                              │
│ Extract:                     │
│ - document.id                │
│ - signer.email               │
│ - signed_at                  │
└────────┬─────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ Database (UPDATE)              │
│                                │
│ SET status = 'assinado'        │
│ WHERE clicksign_doc_id = {id}  │
└────────┬───────────────────────┘
         │
         ▼
    ┌────┴────┬─────────┐
    │          │         │
    ▼          ▼         ▼
  Email    WhatsApp  Audit Log
 (confirm) (confirm)  (LGPD)
```

---

## 📦 Schema Database

### Tabela: assinaturas

```sql
CREATE TABLE assinaturas (
    id SERIAL PRIMARY KEY,
    
    -- Dados pessoais (LGPD)
    nome_completo VARCHAR(255) NOT NULL,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    telefone VARCHAR(20),
    
    -- Timestamps
    data_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_assinatura TIMESTAMP,
    local_assinatura VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'enviado',
        -- Valores: enviado | assinado | recusado | expirado
    
    -- ClickSign
    clicksign_doc_id VARCHAR(255),
    clicksign_url TEXT,
    
    -- Metadados
    canal_notificacao VARCHAR(50),
        -- Valores: email | whatsapp | email_whatsapp
    retry_count INT DEFAULT 0
);

-- Índices para performance
CREATE INDEX idx_cpf ON assinaturas(cpf);
CREATE INDEX idx_status ON assinaturas(status);
CREATE INDEX idx_email ON assinaturas(email);
CREATE INDEX idx_data_envio ON assinaturas(data_envio);
```

### Tabela: auditoria_assinaturas

```sql
CREATE TABLE auditoria_assinaturas (
    id SERIAL PRIMARY KEY,
    assinatura_id INT REFERENCES assinaturas(id),
    
    -- Ação realizada
    acao VARCHAR(100),
        -- Valores: criado | notificado_email | notificado_whatsapp
        --          assinado | recusado | expirado
    
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detalhes TEXT  -- JSON com info extra
);

CREATE INDEX idx_auditoria_assinatura ON auditoria_assinaturas(assinatura_id);
```

---

## 🔐 Segurança — Camadas

### Camada 1: Credenciais (N8N Secrets)

```javascript
// Não armazenar em código!
const token = process.env.CLICKSIGN_API_TOKEN;  // ✅ Correto

// Usar em requisições
Authorization: `Bearer ${token}`
```

### Camada 2: Banco de Dados

```sql
-- Senhas hash (PostgreSQL não armazena em plain text)
POSTGRES_PASSWORD=n8n_secure_password

-- Acesso restrito a usuários
GRANT SELECT, INSERT, UPDATE ON assinaturas TO app_user;
```

### Camada 3: Webhook Validation

```javascript
// Validar origem do webhook ClickSign
if (request.headers['x-clicksign-signature'] !== expectedSignature) {
    throw new Error('Invalid webhook signature');
}
```

### Camada 4: Rate Limiting

```javascript
// Evitar abuso
const MAX_REQUESTS_PER_MINUTE = 10;
// Implementar via Node.js Rate Limit node
```

---

## 🚀 Performance & Escalabilidade

### Atual (Local)

| Métrica | Valor |
|---------|-------|
| **Max workflows paralelos** | 2-5 |
| **Max docs/dia** | 300 (Outlook limit pessoal) |
| **Latência** | < 2s por documento |
| **CPU** | ~15-20% idle |
| **RAM** | ~2GB |

### Futura (Produção)

Para escalar:

1. **Usar Microsoft 365** (sem limite Outlook)
2. **Aumentar workers N8N** (node clustering)
3. **Cache com Redis** (reqs frequentes)
4. **Load balancer** (NGINX)
5. **Monitoring** (Prometheus + Grafana)

---

## 🔌 Integrações Externas

### APIs Utilizadas

| API | Método | Autenticação | Status |
|-----|--------|--------------|--------|
| ClickSign | REST | Bearer Token | ✅ Prod |
| Outlook SMTP | SMTP | Username/Pwd | ✅ Prod |
| Twilio | REST | Account SID | ✅ Prod |
| PostgreSQL | SQL | Username/Pwd | ✅ Prod |

### Fluxo de Requisições

```
N8N Request
    ↓
[Authorization Header]
    ↓
External Service
    ↓
JSON Response
    ↓
N8N Parse & Store
```

---

## 📈 Monitoramento

### Métricas Importantes

```javascript
// N8N Dashboard
- Workflows execution time
- Success rate (%)
- Error rate (%)
- Queue depth

// Database
- Table sizes
- Slow queries
- Connection pool

// APIs
- Response times
- Rate limit usage
- Error codes
```

### Alertas Recomendados

- ⚠️ Workflow execution > 5 minutos
- ⚠️ Error rate > 5%
- ⚠️ Database size > 80%
- ⚠️ Email delivery failure > 10%

---

## 🛠️ Manutenção

### Backups

```bash
# Backup diário do banco
docker-compose exec postgres_custom pg_dump -U app_user assinatura > backup-$(date +%Y%m%d).sql

# Backup dos workflows
# Via UI: Dashboard → Workflows → Export
```

### Updates

```bash
# Atualizar N8N para última versão
docker-compose pull n8n
docker-compose up -d
```

### Logs

```bash
# Ver logs em tempo real
docker-compose logs -f n8n

# Exportar logs para arquivo
docker-compose logs n8n > logs-$(date +%Y%m%d).txt
```

---

## 📋 Decisões Arquiteturais

### Por que PostgreSQL (2x)?

- ✅ Separação: N8N config vs dados aplicação
- ✅ Independência: atualizar N8N sem perder dados
- ✅ Escalabilidade: BD de assinatura cresce independentemente
- ✅ Backup: dois backup points

### Por que N8N (vs código direto)?

- ✅ UI visual: sem código necessário
- ✅ Workflows versionáveis
- ✅ Retry automático
- ✅ Logging integrado
- ✅ Escalável horizontalmente

### Por que Docker (vs instalação direta)?

- ✅ Ambiente reproduzível
- ✅ Isolamento de dependências
- ✅ Deploy simplificado
- ✅ Fácil rollback

---

## 🔮 Roadmap Futuro

### v1.1 (Próximo)

- [ ] Rate limiting por cliente
- [ ] Integração com SAP HANA (faturamento)
- [ ] Dashboard de análise (Power BI)

### v2.0 (Médio prazo)

- [ ] Multi-idioma (EN, ES, PT)
- [ ] Integração com DocuSign
- [ ] Assinatura com certificado digital (ICP-Brasil)

### v3.0 (Longo prazo)

- [ ] Assinatura com biometria
- [ ] Integração com blockchain (verificação)
- [ ] Mobile app (iOS/Android)

---

**Próximo documento: [WORKFLOWS.md](./WORKFLOWS.md)**
