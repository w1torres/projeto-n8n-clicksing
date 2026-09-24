# 📋 N8N + ClickSign — Assinatura Digital Multi-Canal (LGPD)

**Projeto de automação para envio de documentos de assinatura com dupla notificação (Email + WhatsApp)**

## 🎯 Objetivo

Criar fluxo automatizado que:

- ✅ Envia documentos para assinatura via ClickSign
- ✅ Notifica por **Email (Outlook SMTP)** com link de assinatura
- ✅ Notifica por **WhatsApp (Twilio)** com link + QR code
- ✅ Registra dados pessoais: **Nome completo, CPF, Data, Local**
- ✅ Rastreia status de assinatura em banco de dados
- ✅ Cumpre **LGPD** com audit trail completo
- ✅ Envia confirmação quando assinado

---

## 📦 Stack Tecnológico

| Componente | Tecnologia |
|-----------|-----------|
| **Orquestração** | N8N (open-source) |
| **Contêiner** | Docker + Docker Compose |
| **Banco de Dados** | PostgreSQL 15 |
| **Assinatura Digital** | ClickSign API v1 |
| **Email** | Outlook SMTP |
| **WhatsApp** | Twilio API |
| **Ambiente** | Local (docker) ou Hostinger |

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    DISPARADOR (Webhook/Cron)                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │  WORKFLOW 1: ENVIO             │
        ├────────────────────────────────┤
        │ • Ler CSV colaboradores        │
        │ • Validar CPF/Email/Telefone   │
        │ • Enviar para ClickSign        │
        │ • Registrar no BD              │
        │ • Notificar Email + WhatsApp   │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  WORKFLOW 2: WEBHOOK CLICKSIGN │
        ├────────────────────────────────┤
        │ • Receber confirmação          │
        │ • Atualizar status BD          │
        │ • Enviar confirmação           │
        └────────────┬───────────────────┘
                     │
        ┌────────────▼───────────────────┐
        │  WORKFLOW 3: RELATÓRIO DIÁRIO  │
        ├────────────────────────────────┤
        │ • Contar assinados/pendentes   │
        │ • Gerar relatório              │
        │ • Enviar para gestor           │
        └────────────────────────────────┘
```

---

## 📁 Estrutura de Arquivos

```
n8n-assinatura/
├── README.md (você está aqui)
├── INSTALACAO.md (passo-a-passo)
├── ARQUITETURA.md (detalhes técnicos)
├── WORKFLOWS.md (3 workflows explicados)
├── CONFIGURACAO.md (variáveis ambiente)
├── API.md (webhooks + endpoints)
├── BANCO-DADOS.md (SQL + tabelas)
├── TROUBLESHOOTING.md (erros comuns)
├── SEGURANCA.md (boas práticas)
│
├── docker-compose.yml
├── .env (exemplo)
├── init-db.sql
│
├── n8n_data/ (volume Docker)
├── postgres_data/ (volume Docker)
├── postgres_assinatura_data/ (volume Docker)
│
├── documentos/
│   └── termo-whatsapp-lgpd.pdf
│
├── dados/
│   └── colaboradores.csv (template)
│
└── n8n_workflows/
    ├── 01-workflow-envio.json
    ├── 02-workflow-webhook.json
    └── 03-workflow-relatorio.json
```

---

## 🚀 Quick Start

### 1. Pré-requisitos

```bash
# Verificar instalações
docker --version
docker-compose --version
```

### 2. Clonar/Preparar projeto

```bash
mkdir n8n-assinatura && cd n8n-assinatura

# Copiar arquivos (veja INSTALACAO.md)
```

### 3. Configurar ambiente

```bash
# Copiar .env.example para .env
cp .env.example .env

# Editar .env com suas credenciais
nano .env
```

### 4. Subir infraestrutura

```bash
docker-compose up -d
```

### 5. Acessar N8N

```
http://localhost:5678
```

### 6. Importar workflows

Dashboard → Workflows → Import → selecione 3 arquivos JSON

---

## 🔑 Credenciais Necessárias

| Serviço | Obrigatório | Configuração |
|---------|-----------|--------------|
| **ClickSign** | ✅ Sim | API Token |
| **Outlook** | ✅ Sim | SMTP ou OAuth |
| **Twilio** | ✅ Sim | Account SID + Auth Token |
| **PostgreSQL** | ✅ Sim | Senha (mude do padrão) |

Veja **CONFIGURACAO.md** para detalhes de cada um.

---

## 📊 Fluxo de Dados

### Caso de Uso 1: Envio Inicial

```
CSV com colaboradores
        ▼
N8N (Loop)
        ▼
POST /ClickSign (criar documento)
        ▼
Obter URL de assinatura
        ▼
├─ Email via Outlook SMTP
└─ WhatsApp via Twilio
        ▼
INSERT (PostgreSQL)
        ▼
Aguardar assinatura...
```

### Caso de Uso 2: Retorno de Assinatura

```
ClickSign (Webhook)
        ▼
N8N (Trigger Webhook)
        ▼
Parse resposta
        ▼
UPDATE (PostgreSQL)
        ▼
├─ Email confirmação
└─ WhatsApp confirmação
```

---

## 🎓 Documentação Detalhada

| Documento | Conteúdo |
|-----------|----------|
| **INSTALACAO.md** | Passo-a-passo completo (Docker + variáveis) |
| **ARQUITETURA.md** | Design técnico + diagramas |
| **WORKFLOWS.md** | 3 workflows explicados nó-a-nó |
| **CONFIGURACAO.md** | Variáveis de ambiente (.env) |
| **API.md** | Endpoints + webhooks + payloads JSON |
| **BANCO-DADOS.md** | Schema SQL + queries úteis |
| **TROUBLESHOOTING.md** | Erros comuns + soluções |
| **SEGURANCA.md** | LGPD + boas práticas + sensibilidade |

---

## 📋 Checklist de Setup

- [ ] Docker instalado
- [ ] Credenciais ClickSign (token)
- [ ] Credenciais Outlook (SMTP ou OAuth)
- [ ] Credenciais Twilio (SID + token)
- [ ] `.env` preenchido
- [ ] `docker-compose up -d` rodando
- [ ] N8N acessível em http://localhost:5678
- [ ] BD PostgreSQL criado
- [ ] 3 workflows importados
- [ ] Teste de envio executado
- [ ] Logs verificados

---

## 🆘 Suporte Rápido

**Erro ao subir Docker?**
→ Veja **TROUBLESHOOTING.md** seção "Docker"

**Não consegue conectar ClickSign?**
→ Veja **CONFIGURACAO.md** seção "ClickSign"

**Emails não chegam?**
→ Veja **TROUBLESHOOTING.md** seção "Outlook SMTP"

**WhatsApp não funciona?**
→ Veja **TROUBLESHOOTING.md** seção "Twilio"

---

## 📞 Contato / Suporte

- **Maintainer**: Wildes Torres (Tchê Agrícola)
- **Versão**: 1.0.0
- **Última atualização**: 2026-09-24
- **Status**: ✅ Pronto para produção

---

## 📜 Licença

MIT License — Livre para uso interno

---

**Comece por: [INSTALACAO.md](./INSTALACAO.md)**
