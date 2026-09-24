# 🚀 Guia de Instalação — N8N + ClickSign

Passo-a-passo completo para subir o projeto em seu ambiente.

---

## ✅ Pré-requisitos

### Sistema Operacional

- ✅ Windows 10+ com WSL2
- ✅ macOS 10.12+
- ✅ Linux (qualquer distribuição recente)

### Softwares Obrigatórios

```bash
# Verificar Docker
docker --version
# Esperado: Docker version 20.10+

# Verificar Docker Compose
docker-compose --version
# Esperado: Docker Compose version 1.29+
```

Se não tem Docker instalado:
- **Windows/Mac**: Baixe [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: `sudo apt-get install docker.io docker-compose`

---

## 📁 Passo 1: Clonar Estrutura de Pastas

```bash
# Criar diretório do projeto
mkdir n8n-assinatura
cd n8n-assinatura

# Criar subpastas
mkdir -p n8n_data
mkdir -p postgres_data
mkdir -p postgres_assinatura_data
mkdir -p documentos
mkdir -p dados
mkdir -p n8n_workflows

# Listar estrutura
ls -la
```

Resultado esperado:
```
n8n-assinatura/
├── n8n_data/
├── postgres_data/
├── postgres_assinatura_data/
├── documentos/
├── dados/
└── n8n_workflows/
```

---

## 📋 Passo 2: Criar Arquivos de Configuração

### 2.1 — docker-compose.yml

Crie arquivo `docker-compose.yml` na raiz:

```yaml
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n-assinatura
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - DATABASE_TYPE=postgresdb
      - DATABASE_HOST=postgres
      - DATABASE_NAME=n8n
      - DATABASE_USER=n8n
      - DATABASE_PASSWORD=n8n_secure_password
      - NODE_ENV=production
      - GENERIC_TIMEZONE=America/Sao_Paulo
    volumes:
      - ./n8n_data:/home/node/.n8n
    depends_on:
      - postgres
    networks:
      - n8n-network

  postgres:
    image: postgres:15-alpine
    container_name: n8n_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: n8n_secure_password
    volumes:
      - ./postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-network

  postgres_custom:
    image: postgres:15-alpine
    container_name: assinatura_db
    restart: unless-stopped
    environment:
      POSTGRES_DB: assinatura
      POSTGRES_USER: app_user
      POSTGRES_PASSWORD: app_password_secure
    volumes:
      - ./postgres_assinatura_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    networks:
      - n8n-network

networks:
  n8n-network:
    driver: bridge

volumes:
  postgres_data:
  postgres_assinatura_data:
```

### 2.2 — init-db.sql

Crie arquivo `init-db.sql` na raiz:

```sql
-- Criar tabela de assinaturas
CREATE TABLE IF NOT EXISTS assinaturas (
    id SERIAL PRIMARY KEY,
    nome_completo VARCHAR(255) NOT NULL,
    cpf VARCHAR(14) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    telefone VARCHAR(20),
    data_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_assinatura TIMESTAMP,
    local_assinatura VARCHAR(255),
    status VARCHAR(50) DEFAULT 'enviado',
    clicksign_doc_id VARCHAR(255),
    clicksign_url TEXT,
    canal_notificacao VARCHAR(50),
    retry_count INT DEFAULT 0
);

-- Criar índices
CREATE INDEX idx_cpf ON assinaturas(cpf);
CREATE INDEX idx_status ON assinaturas(status);
CREATE INDEX idx_email ON assinaturas(email);
CREATE INDEX idx_data_envio ON assinaturas(data_envio);

-- Log de auditoria (LGPD)
CREATE TABLE IF NOT EXISTS auditoria_assinaturas (
    id SERIAL PRIMARY KEY,
    assinatura_id INT REFERENCES assinaturas(id),
    acao VARCHAR(100),
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detalhes TEXT
);

CREATE INDEX idx_auditoria_assinatura ON auditoria_assinaturas(assinatura_id);
```

### 2.3 — .env

Crie arquivo `.env` na raiz:

```bash
# ========== CLICKSIGN ==========
CLICKSIGN_API_TOKEN=seu_token_clicksign_aqui
CLICKSIGN_API_URL=https://app.clicksign.com/api/v1

# ========== OUTLOOK SMTP ==========
OUTLOOK_SMTP_HOST=smtp-mail.outlook.com
OUTLOOK_SMTP_PORT=587
OUTLOOK_EMAIL=seu_email@outlook.com
OUTLOOK_PASSWORD=sua_senha_aqui
OUTLOOK_FROM_EMAIL=noreply@tchea.com.br

# ========== TWILIO (WHATSAPP) ==========
TWILIO_ACCOUNT_SID=seu_account_sid
TWILIO_AUTH_TOKEN=seu_auth_token
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

# ========== N8N CONFIG ==========
NODE_ENV=production
GENERIC_TIMEZONE=America/Sao_Paulo
N8N_HOST=localhost
N8N_PORT=5678
```

**⚠️ IMPORTANTE**: Substitua todos os `seu_*` pelas suas credenciais reais.

---

## 📄 Passo 3: Preparar Dados

### 3.1 — Documento PDF

Coloque seu documento PDF em:
```
documentos/termo-whatsapp-lgpd.pdf
```

Se não tiver, crie um exemplo:
```bash
echo "Termo de Ciência e Responsabilidade - WhatsApp Corporativo" > documentos/README.txt
```

### 3.2 — CSV de Colaboradores

Crie arquivo `dados/colaboradores.csv`:

```csv
nome,cpf,email,telefone
João Silva,123.456.789-10,joao@tchea.com.br,11987654321
Maria Santos,987.654.321-00,maria@tchea.com.br,11912345678
Carlos Oliveira,456.123.789-55,carlos@tchea.com.br,11998765432
```

**Formato obrigatório**:
- CPF: `XXX.XXX.XXX-XX` (com pontos e hífen)
- Email: válido
- Telefone: 11 dígitos (começando com +55)

---

## 🐳 Passo 4: Subir Docker

### 4.1 — Iniciar Containers

```bash
# Na raiz do projeto
docker-compose up -d
```

Você verá:
```
Creating n8n_db ... done
Creating assinatura_db ... done
Creating n8n-assinatura ... done
```

### 4.2 — Verificar Status

```bash
# Listar containers
docker-compose ps

# Esperado:
# NAME                COMMAND             STATUS
# n8n-assinatura      docker-entrypoint   Up 2 minutes
# n8n_db              docker-entrypoint   Up 2 minutes
# assinatura_db       docker-entrypoint   Up 2 minutes
```

### 4.3 — Ver Logs

```bash
# Logs do N8N
docker-compose logs -f n8n

# Logs do PostgreSQL
docker-compose logs -f postgres_custom

# Sair: Ctrl + C
```

---

## 🌐 Passo 5: Acessar N8N

### Abrir no navegador

```
http://localhost:5678
```

### Criar usuário admin

Na primeira vez, N8N pede:
- Email
- Senha
- Confirmar senha

Preencha e clique **Next**.

Dashboard carregado ✅

---

## 🔐 Passo 6: Adicionar Credenciais

### 6.1 — ClickSign

1. **Menu** → **Credentials**
2. **+ New** → **HTTP Request**
3. Nome: `ClickSign`
4. Preencha:
   ```
   Authorization: Bearer {{ $env.CLICKSIGN_API_TOKEN }}
   ```
5. **Save**

### 6.2 — Outlook SMTP

1. **Credentials** → **+ New** → **Email**
2. Nome: `Outlook`
3. Preencha:
   ```
   SMTP Host: {{ $env.OUTLOOK_SMTP_HOST }}
   SMTP Port: {{ $env.OUTLOOK_SMTP_PORT }}
   Email: {{ $env.OUTLOOK_EMAIL }}
   Password: {{ $env.OUTLOOK_PASSWORD }}
   TLS: ✅
   ```
4. **Test** → ✅ Connection successful
5. **Save**

### 6.3 — Twilio

1. **Credentials** → **+ New** → **Twilio**
2. Nome: `Twilio`
3. Preencha:
   ```
   Account SID: {{ $env.TWILIO_ACCOUNT_SID }}
   Auth Token: {{ $env.TWILIO_AUTH_TOKEN }}
   From: {{ $env.TWILIO_PHONE_FROM }}
   ```
4. **Save**

---

## 📥 Passo 7: Importar Workflows

### 7.1 — Workflow 1: Envio

1. **Workflows** → **+ New**
2. Clique 3 pontinhos (⋯) → **Import**
3. Selecione `n8n_workflows/01-workflow-envio.json`
4. Clique **Import**

### 7.2 — Workflow 2: Webhook

Repita para `02-workflow-webhook.json`

### 7.3 — Workflow 3: Relatório

Repita para `03-workflow-relatorio.json`

---

## 🧪 Passo 8: Teste Básico

### Workflow 1 (Manual)

1. Abra **Workflow 1 — Envio**
2. Clique **Execute** (botão azul)
3. Escolha um colaborador do CSV
4. Clique **Execute**

Esperado:
```
✅ Document created in ClickSign
✅ Email sent
✅ WhatsApp sent
✅ Database updated
```

### Verificar Banco de Dados

```bash
# Conectar ao PostgreSQL
docker-compose exec postgres_custom psql -U app_user -d assinatura

# Ver registros
SELECT nome_completo, status, data_envio FROM assinaturas;

# Sair: \q
```

---

## 📊 Passo 9: Configurar Agendamento

### Workflow 1 (Diariamente)

1. Abra **Workflow 1 — Envio**
2. Clique no **Trigger**
3. Mude de "HTTP" para **Schedule**
4. Configure:
   ```
   Trigger: Cron
   Cron: 0 8 * * * (08:00 todo dia)
   ```
5. **Save**

### Workflow 3 (Relatório)

1. Abra **Workflow 3 — Relatório**
2. Configure:
   ```
   Trigger: Cron
   Cron: 0 9 * * * (09:00 todo dia)
   ```

---

## 🎉 Conclusão

Seu projeto N8N está pronto! 

### Checklist Final

- [ ] Docker containers rodando
- [ ] N8N acessível em http://localhost:5678
- [ ] Credenciais ClickSign testadas
- [ ] Credenciais Outlook testadas
- [ ] Credenciais Twilio testadas
- [ ] 3 Workflows importados
- [ ] Teste manual executado
- [ ] Registro inserido no BD
- [ ] Email recebido
- [ ] WhatsApp recebido

### Próximos Passos

1. Leia **WORKFLOWS.md** para entender cada nó
2. Customize mensagens em **CONFIGURACAO.md**
3. Revise segurança em **SEGURANCA.md**
4. Configure monitoramento em **TROUBLESHOOTING.md**

---

## 🆘 Problemas Comuns

### Docker não inicia

```bash
# Ver erro
docker-compose logs n8n

# Solução: Verificar .env e permissões
chmod -R 777 n8n_data postgres_data postgres_assinatura_data
docker-compose down && docker-compose up -d
```

### Não consegue conectar PostgreSQL

```bash
# Verificar conexão
docker-compose exec postgres_custom psql -U app_user -d assinatura

# Se falhar, reiniciar container
docker-compose restart postgres_custom
```

### Página N8N não carrega

```bash
# Aguarde 30 segundos e recarregue
# Se persistir:
docker-compose logs n8n | tail -20
```

Veja **TROUBLESHOOTING.md** para mais detalhes.

---

**Próximo documento: [ARQUITETURA.md](./ARQUITETURA.md)**
