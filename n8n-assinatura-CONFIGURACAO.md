# ⚙️ Configuração — Credenciais e Variáveis

Guia completo de como obter e configurar cada credencial.

---

## 🔑 Variáveis de Ambiente (.env)

### Arquivo .env (Exemplo Completo)

```bash
# ========== CLICKSIGN ==========
CLICKSIGN_API_TOKEN=seu_token_aqui
CLICKSIGN_API_URL=https://app.clicksign.com/api/v1

# ========== OUTLOOK SMTP ==========
OUTLOOK_SMTP_HOST=smtp-mail.outlook.com
OUTLOOK_SMTP_PORT=587
OUTLOOK_EMAIL=seu_email@outlook.com
OUTLOOK_PASSWORD=sua_senha_aplicacao_aqui
OUTLOOK_FROM_EMAIL=noreply@tchea.com.br

# ========== TWILIO ==========
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_PHONE_FROM=+55119XXXXXXXXX

# ========== BANCO DE DADOS N8N ==========
DB_N8N_HOST=postgres
DB_N8N_PORT=5432
DB_N8N_NAME=n8n
DB_N8N_USER=n8n
DB_N8N_PASSWORD=n8n_secure_password

# ========== BANCO DE DADOS ASSINATURA ==========
DB_HOST=postgres_custom
DB_PORT=5432
DB_NAME=assinatura
DB_USER=app_user
DB_PASSWORD=app_password_secure

# ========== DOCUMENTOS ==========
DOCUMENTO_PATH=/home/node/n8n/documentos/termo-whatsapp-lgpd.pdf
DOCUMENTO_TITULO=Termo de Ciência e Responsabilidade - WhatsApp Corporativo

# ========== N8N ==========
NODE_ENV=production
GENERIC_TIMEZONE=America/Sao_Paulo
N8N_HOST=localhost
N8N_PORT=5678
```

---

## 🔐 ClickSign

### 1. Obter API Token

**Passo 1**: Acessar ClickSign
```
https://app.clicksign.com
```

**Passo 2**: Menu → Configurações → Integrações

**Passo 3**: "Criar nova chave de integração"

**Passo 4**: Copiar token gerado

**Passo 5**: Adicionar em `.env`
```bash
CLICKSIGN_API_TOKEN=abc123def456...
CLICKSIGN_API_URL=https://app.clicksign.com/api/v1
```

### 2. Testar Conexão

```bash
# No N8N, criar HTTP Request node
Method: GET
URL: https://app.clicksign.com/api/v1/documents
Headers:
  Authorization: Bearer {{ $env.CLICKSIGN_API_TOKEN }}

# Se receber lista de docs = ✅ Sucesso
```

### 3. Configurar Webhook (Retorno)

**No ClickSign:**
1. Settings → Webhooks
2. Add webhook
3. URL: `http://seu-servidor:5678/webhook/clicksign/assinado`
4. Events: `document.signed`, `document.refused`
5. Salvar

---

## 📧 Outlook SMTP

### 1. Conta Pessoal (Hotmail/Outlook)

**Passo 1**: Acessar outlook.live.com

**Passo 2**: Settings → Options → Security

**Passo 3**: App passwords → Gerar

**Passo 4**: Copiar senha

**Passo 5**: Adicionar em `.env`
```bash
OUTLOOK_EMAIL=seu_email@outlook.com
OUTLOOK_PASSWORD=abcd-efgh-ijkl-mnop
OUTLOOK_SMTP_HOST=smtp-mail.outlook.com
OUTLOOK_SMTP_PORT=587
```

### 2. Microsoft 365 Business

**Passo 1**: Acessar admin.microsoft.com

**Passo 2**: Users → Active Users → Seu usuário

**Passo 3**: Mail settings → SMTP relay

**Passo 4**: Configurar em `.env`
```bash
OUTLOOK_EMAIL=seu_email@empresa.com.br
OUTLOOK_SMTP_HOST=smtp.office365.com
OUTLOOK_SMTP_PORT=587
```

**Passo 5** (Alternativa OAuth):
```bash
# Para melhor segurança, usar OAuth via Azure AD
# Requer: Application ID, Secret, Tenant ID
# Ver: https://learn.microsoft.com/en-us/exchange/client-developer/
```

### 3. Testar Envio de Email

**No N8N:**
1. Criar nó "Send Email"
2. Selecionar credential "Outlook"
3. To: seu_email@teste.com
4. Subject: Teste
5. Clique **Send**

**Esperado**: Email recebido em < 30s

---

## 📱 Twilio (WhatsApp)

### 1. Obter Credenciais

**Passo 1**: Acessar twilio.com

**Passo 2**: Sign up / Login

**Passo 3**: Console → Account SID

**Passo 4**: Settings → Auth Token

**Passo 5**: Copiar valores

**Passo 6**: Adicionar em `.env`
```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxx
TWILIO_PHONE_FROM=+55119XXXXXXXXX
```

### 2. Configurar WhatsApp Business

**Passo 1**: Twilio Console → Messaging → Try it out → WhatsApp

**Passo 2**: "Send a WhatsApp message"

**Passo 3**: Aprovar número WhatsApp Business (requer CNPJ)

**Passo 4**: Usar número atribuído em `TWILIO_PHONE_FROM`

### 3. Testar Envio WhatsApp

**No N8N:**
1. Criar nó "Send Twilio Message"
2. Credential: Twilio
3. To: +55 seu telefone
4. Message: "Teste Twilio"
5. Clique **Send**

**Esperado**: WhatsApp recebido em < 5s

---

## 🗄️ PostgreSQL

### 1. Senhas Padrão (Alterar em Produção!)

**N8N Database:**
```bash
# docker-compose.yml
POSTGRES_USER=n8n
POSTGRES_PASSWORD=n8n_secure_password  # ⚠️ MUDE ISSO
```

**Assinatura Database:**
```bash
# docker-compose.yml
POSTGRES_USER=app_user
POSTGRES_PASSWORD=app_password_secure  # ⚠️ MUDE ISSO
```

### 2. Conectar ao BD Local

```bash
# Terminal local
docker-compose exec postgres_custom psql -U app_user -d assinatura

# Dentro do PostgreSQL
\dt  # Listar tabelas
SELECT * FROM assinaturas;  # Ver dados
\q   # Sair
```

### 3. Backup Automático

```bash
# Script: backup.sh
#!/bin/bash
docker-compose exec postgres_custom pg_dump -U app_user assinatura > backup-$(date +%Y%m%d-%H%M%S).sql
echo "Backup concluído!"
```

Executar diariamente:
```bash
0 22 * * * /home/user/projeto/backup.sh  # 22:00 todo dia
```

---

## 📄 Documento PDF

### 1. Preparar Documento

**Localização:**
```
documentos/termo-whatsapp-lgpd.pdf
```

**Requisitos:**
- ✅ Formato: PDF
- ✅ Conteúdo: Termo LGPD completo
- ✅ Espaço: Campo assinatura vazio

**Exemplo de conteúdo mínimo:**
```
TERMO DE CIÊNCIA E RESPONSABILIDADE
Uso de WhatsApp Corporativo - LGPD

1. Identificação do Colaborador
   Nome: _________________________________
   CPF: __________________________________
   Data: _________________________________
   
2. Termo LGPD
   O colaborador está ciente de que...
   [Conteúdo jurídico completo]
   
3. Assinatura
   Assinado em: ____/____/______
   Local: _________________________________
   
   ____________________________________________
            (Assinatura do Colaborador)
```

### 2. Customizar Mensagens

**No Workflow 1 (Nó Email):**
```
Body (HTML) - Editar mensagem conforme necessário

Dear {{ nome }},
Please sign this document...
```

**No Workflow 1 (Nó WhatsApp):**
```
Message - Editar SMS/WhatsApp

Olá {{ nome }},
Por favor assine o documento...
```

---

## 📊 Dados — CSV Colaboradores

### Formato Esperado

```
nome,cpf,email,telefone
João Silva,123.456.789-10,joao@tchea.com.br,11987654321
Maria Santos,987.654.321-00,maria@tchea.com.br,11912345678
```

### Validações

| Campo | Validação | Exemplo |
|-------|-----------|---------|
| **nome** | 3-255 caracteres | João Silva |
| **cpf** | XXX.XXX.XXX-XX | 123.456.789-10 |
| **email** | Email válido | joao@tchea.com.br |
| **telefone** | 11 dígitos | 11987654321 |

### Importar CSV

**No N8N:**
1. Workflow 1 → Nó "Read File"
2. File Path: `/home/node/n8n/dados/colaboradores.csv`
3. Format: CSV
4. Execute

---

## 🧪 Testar Todas as Credenciais

### Checklist de Validação

```bash
# 1. ClickSign
curl -X GET https://app.clicksign.com/api/v1/documents \
  -H "Authorization: Bearer {{ CLICKSIGN_API_TOKEN }}"
# Esperado: JSON com lista de docs

# 2. Outlook
# Via N8N: Send Email node → Test
# Esperado: Email recebido

# 3. Twilio
# Via N8N: Send Twilio Message → Test
# Esperado: WhatsApp recebido

# 4. PostgreSQL
docker-compose exec postgres_custom psql -U app_user -d assinatura -c "SELECT 1"
# Esperado: (1 row)
```

---

## 🔒 Boas Práticas de Segurança

### ✅ Faça

- ✅ Armazenar `.env` fora do Git
- ✅ Usar variáveis de ambiente em produção
- ✅ Rotacionar tokens a cada 90 dias
- ✅ Usar senhas fortes (20+ caracteres)
- ✅ Ativar 2FA em ClickSign, Outlook, Twilio
- ✅ Fazer backup dos `.env` (separado do código)

### ❌ Não Faça

- ❌ Comitar `.env` no Git
- ❌ Usar senha padrão em produção
- ❌ Compartilhar tokens via Slack/Email
- ❌ Usar mesma senha para múltiplos serviços
- ❌ Deixar logs com credenciais

### 🔄 Rotação de Tokens

**ClickSign**: Settings → Gerar novo token → Atualizar → Revogar antigo

**Outlook**: Se M365 Business, revogar app password → Gerar nova

**Twilio**: Console → Auth token → Rotate → Copiar novo

---

## 📋 Ambiente de Teste vs Produção

### Teste

```bash
NODE_ENV=development
CLICKSIGN_API_URL=https://staging.clicksign.com/api/v1
OUTLOOK_EMAIL=teste@outlook.com
```

### Produção

```bash
NODE_ENV=production
CLICKSIGN_API_URL=https://app.clicksign.com/api/v1
OUTLOOK_EMAIL=noreply@tchea.com.br
```

---

**Próximo documento: [API.md](./API.md)**
