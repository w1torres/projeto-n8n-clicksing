# 🆘 Troubleshooting — Erros Comuns e Soluções

Guia de diagnóstico e resolução de problemas.

---

## 🐳 Docker

### Problema: Containers não iniciam

**Sintoma:** `docker-compose up` fica pendurado ou retorna erro

**Diagnóstico:**
```bash
docker-compose logs n8n | tail -30
docker-compose logs postgres_custom | tail -30
```

**Soluções:**

#### 1. Porta já em uso
```bash
# Ver processo na porta 5678
lsof -i :5678

# Matar processo (Linux/Mac)
kill -9 <PID>

# Liberar porta (Windows)
netstat -ano | findstr :5678
taskkill /PID <PID> /F
```

#### 2. Permissões de arquivo
```bash
# Linux/Mac
chmod -R 777 n8n_data postgres_data postgres_assinatura_data

# Docker Compose
docker-compose down
docker-compose up -d
```

#### 3. Memória insuficiente
```bash
# Verificar uso
docker stats

# Aumentar memória Docker Desktop:
# Settings → Resources → Memory: 4GB+
```

#### 4. Limpar tudo e recomeçar
```bash
docker-compose down -v  # Remove volumes!
docker system prune -a   # Remove images antigos
docker-compose up -d     # Recriar
```

---

## 🌐 N8N Dashboard

### Problema: Página não carrega

**Sintoma:** Branco ou "Cannot GET /"

**Diagnóstico:**
```bash
curl -v http://localhost:5678
# Esperado: 200 OK com HTML
```

**Soluções:**

#### 1. Aguardar inicialização
```bash
# N8N leva ~30s para iniciar
docker-compose logs -f n8n | grep "Server ready"
```

#### 2. Verificar conectividade BD
```bash
# Conectar ao postgres
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT 1"
# Esperado: (1 row)
```

#### 3. Verificar variáveis
```bash
# No .env, verificar:
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=n8n
DATABASE_USER=n8n
```

#### 4. Reiniciar N8N
```bash
docker-compose restart n8n
```

---

## 🔐 Credenciais ClickSign

### Problema: Autenticação falha

**Sintoma:** `Authorization Failed` ou `401 Unauthorized`

**Diagnóstico:**
```bash
# Testar token
curl -X GET https://app.clicksign.com/api/v1/documents \
  -H "Authorization: Bearer SEU_TOKEN_AQUI"
# Esperado: 200 OK (JSON com docs)
```

**Soluções:**

#### 1. Token inválido/expirado
```bash
# Ir para ClickSign
# Settings → Integrations → Gerar novo token
# Copiar e atualizar .env
CLICKSIGN_API_TOKEN=novo_token_aqui
```

#### 2. Token não configurado em N8N
```bash
# N8N → Credentials → ClickSign
# Verificar: Authorization header preenchido
# Salvar e testar HTTP node
```

#### 3. URL da API errada
```bash
# Verificar .env
CLICKSIGN_API_URL=https://app.clicksign.com/api/v1
# (não esquecer /api/v1)
```

---

## 📧 Email — Outlook SMTP

### Problema: Email não é enviado

**Sintoma:** Erro no nó "Send Email" ou emails não chegam

**Diagnóstico:**
```bash
# Testar conexão SMTP
telnet smtp-mail.outlook.com 587
# Esperado: conectado
```

**Soluções:**

#### 1. Senha errada
```bash
# Outlook → Settings → Security → App passwords
# Copiar nova senha (formato: abcd-efgh-ijkl-mnop)
# N8N → Credentials → Outlook → Preencher
# Testar com Email node
```

#### 2. 2FA habilitado
```bash
# Se tiver 2FA, usar:
# - App Password (Outlook gera) OU
# - OAuth2 (configuração mais complexa)
```

#### 3. Limite de emails excedido
```bash
# Contas pessoais: 300 emails/dia
# Solução: Usar Microsoft 365 (sem limite) ou:
#   - Distribuir envios em múltiplos dias
#   - Usar segundos email
```

#### 4. Firewall bloqueando
```bash
# Testar conectividade
ping smtp-mail.outlook.com
# Esperado: resposta

# Se falhar: Verificar firewall corporativo
# Porta 587 deve estar aberta
```

#### 5. Domínio não verificado
```bash
# Para enviar de noreply@tchea.com.br
# Verificar SPF/DKIM/DMARC em DNS
# Ou enviar de email com suporte (ex: seu-email@outlook.com)
```

---

## 💬 WhatsApp — Twilio

### Problema: WhatsApp não é entregue

**Sintoma:** Erro no nó "Send Twilio Message"

**Diagnóstico:**
```bash
# Testar credenciais
curl -X POST https://api.twilio.com/2010-04-01/Accounts/AC.../Messages.json \
  -u "ACCOUNT_SID:AUTH_TOKEN" \
  -d "To=+55..." \
  -d "From=+55..." \
  -d "Body=Teste"
# Esperado: 201 Created
```

**Soluções:**

#### 1. Credenciais inválidas
```bash
# Twilio Console → Account SID
# Twilio Console → Auth Tokens → Rotate
# N8N → Credentials → Twilio → Atualizar
# Testar
```

#### 2. WhatsApp não ativado
```bash
# Twilio → Messaging → WhatsApp
# "Send a WhatsApp message" → Ativar
# Aprovar número WhatsApp Business (requer CNPJ)
```

#### 3. Número não aprovado
```bash
# Twilio → Messaging → Senders
# Verificar status: Approved/Pending/Failed
# Se Pending: Aguardar aprovação Twilio (24-48h)
# Se Failed: Tentar número diferente
```

#### 4. Telefone destinatário inválido
```bash
# Formato esperado: +5511987654321
# Não: 11987654321 ou (11) 98765-4321
# Verificar: +55 + código área (2 dígitos) + número (8-9 dígitos)
```

#### 5. Template message não registrado
```bash
# Twilio / WhatsApp requer templates aprovados
# Se usando mensagem customizada:
#   - Testar com número na whitelist primeiro
#   - Depois expandir
```

---

## 🗄️ PostgreSQL

### Problema: Conexão recusada

**Sintoma:** `Connection refused` ao tentar conectar BD

**Diagnóstico:**
```bash
# Verificar se container rodando
docker-compose ps | grep postgres

# Ver logs
docker-compose logs postgres_custom | tail -20
```

**Soluções:**

#### 1. Container não iniciado
```bash
docker-compose start postgres_custom
# Aguardar ~10s
docker-compose exec postgres_custom psql -U app_user -d assinatura -c "SELECT 1"
```

#### 2. Senha errada
```bash
# Verificar .env
DB_PASSWORD=app_password_secure

# Se alterou, recrear container:
docker-compose down postgres_custom
# Editar .env
docker-compose up -d postgres_custom
```

#### 3. Porta bloqueada
```bash
# Testar porta 5432
telnet localhost 5432
# Esperado: conectado

# Se falhar, verificar firewall:
# Windows: Windows Defender Firewall → Regras entrada
# Linux: sudo ufw status
```

#### 4. Erro de inicialização BD
```bash
# Ver erro completo
docker-compose logs postgres_custom | grep ERROR

# Se erro de init script:
docker-compose down postgres_custom -v  # Remove volume
docker-compose up -d postgres_custom    # Recria
```

---

## 📊 Workflows N8N

### Problema: Workflow não executa

**Sintoma:** Clica "Execute" mas não faz nada

**Diagnóstico:**
```bash
# Ver erro em tempo real
docker-compose logs -f n8n | grep -i error
```

**Soluções:**

#### 1. Credentials não configuradas
```
Dashboard → Workflows → Abrir workflow
→ Procurar nós com símbolo "!" (alerta)
→ Clicar → Selecionar credential
→ Save
```

#### 2. Credencial inválida
```
Credentials → Procurar ClickSign/Outlook/Twilio
→ Test connection
→ Se falhar, atualizar (ver seções acima)
```

#### 3. Nó mal configurado
```
Procurar nós com símbolo "?" (atenção)
→ Hover e ver mensagem
→ Preencher campos obrigatórios
→ Save
```

#### 4. Arquivo CSV não encontrado
```bash
# Verificar caminho no nó "Read File"
# Formato esperado: /home/node/n8n/dados/colaboradores.csv

# Se errado, atualizar path
```

#### 5. Erro em Code Node
```javascript
// Ver erro no output
// Comum: referência a nó inexistente
// $node.NodeName.json

// Verificar nome exato do nó (case-sensitive)
```

---

## 🔗 ClickSign

### Problema: Documento não criado

**Sintoma:** Erro ao fazer POST para ClickSign

**Diagnóstico:**
```bash
# Testar manualmente
curl -X POST https://app.clicksign.com/api/v1/documents \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "document": {
      "path": "/caminho/arquivo.pdf",
      "signers": [{"email": "test@mail.com", "act": "sign"}]
    }
  }'
```

**Soluções:**

#### 1. PDF inválido ou não encontrado
```bash
# Verificar caminho documento
DOCUMENTO_PATH=/home/node/n8n/documentos/termo-whatsapp-lgpd.pdf

# Verificar se arquivo existe
docker-compose exec n8n ls -la /home/node/n8n/documentos/

# Se não existe, copiar PDF
docker cp termo-whatsapp-lgpd.pdf n8n-assinatura:/home/node/.n8n/documentos/
```

#### 2. Signers inválidos
```json
{
  "signers": [
    {
      "email": "joao@tchea.com.br",  // ✅ Válido
      "name": "João Silva",           // ✅ Recomendado
      "act": "sign"                   // ✅ Correto
    }
  ]
}
```

#### 3. Deadline inválido
```javascript
// Formato esperado: YYYY-MM-DD
// Exemplo: "2025-02-14"

// Em N8N:
dateAdd(now(), 30, 'days').toISOString().split('T')[0]
```

---

## 📋 CSV

### Problema: CSV não é lido corretamente

**Sintoma:** Valores vazios, encoding errado, ou erro de parsing

**Diagnóstico:**
```bash
# Verificar arquivo
cat dados/colaboradores.csv

# Verificar encoding
file -i dados/colaboradores.csv
# Esperado: UTF-8
```

**Soluções:**

#### 1. Encoding errado
```bash
# Converter para UTF-8 (Linux/Mac)
iconv -f ISO-8859-1 -t UTF-8 colaboradores.csv > colaboradores-utf8.csv

# Windows: Abrir no Notepad++
# File → Encoding → UTF-8 → Salvar
```

#### 2. Separador errado
```bash
# N8N → Read File → Delimiter: ","
# Se usar ponto-virgula: ";"
# Verificar formato do CSV
```

#### 3. Valores com quebra de linha
```csv
# ❌ Errado:
nome,cpf,email
João
Silva,123.456.789-10,joao@mail.com

# ✅ Correto (usar aspas):
"nome","cpf","email"
"João Silva","123.456.789-10","joao@mail.com"
```

---

## 🔄 Webhooks

### Problema: Webhook não dispara

**Sintoma:** Envia POST para N8N mas nada acontece

**Diagnóstico:**
```bash
# Testar manualmente
curl -X POST http://localhost:5678/webhook/clicksign/assinado \
  -H "Content-Type: application/json" \
  -d '{"test": true}'

# Ver execução em N8N
Dashboard → Executions → Verificar última
```

**Soluções:**

#### 1. URL webhook incorreta
```bash
# Verificar em ClickSign → Webhooks
# URL deve ser exatamente: http://seu-servidor:5678/webhook/clicksign/assinado

# Se local: http://localhost:5678/... não funciona de fora
# Usar: http://seu-ip-publico:5678/...
# Ou: ngrok para expor localhost
```

#### 2. Webhook não ativado
```bash
# N8N → Workflow → Trigger → Webhook
# Verificar: "Active" está habilitado (toggle ON)
```

#### 3. ClickSign não envia
```bash
# ClickSign → Webhooks → Verificar URL
# Clicar "Test" para enviar webhook de teste
# Se não dispara em N8N: URL pode estar errada
```

#### 4. Firewall bloqueando
```bash
# Se N8N em produção:
# Verificar: Firewall entrada porta 5678
# Whitelist: IPs ClickSign (pedir para suporte)
```

---

## 📊 Performance

### Problema: Workflows lentos

**Sintoma:** Execução leva > 5 minutos

**Diagnóstico:**
```bash
# Ver tempo de cada nó
Dashboard → Workflows → Executions → Detalhes
# Procurar nó com tempo > esperado
```

**Soluções:**

#### 1. Loop grande (muitos colaboradores)
```javascript
// Se Loop com 1000+ itens:
// N8N processa sequencial (um-a-um)
// Solução: Usar "Batch" (processar 10 por vez)
```

#### 2. Timeout na API externa
```bash
# ClickSign: aumentar timeout para 60s
# Outlook: aumentar timeout para 30s
# Twilio: aumentar timeout para 30s
```

#### 3. Banco de dados lento
```sql
-- Verificar se há queries longas
-- Dashboard → Monitoring

-- Se tabela grande (>100k linhas):
-- Criar índice:
CREATE INDEX idx_status ON assinaturas(status);
```

---

## 🔐 Segurança

### Problema: Credenciais expostas

**Sintoma:** Tokens aparecem em logs ou código

**Diagnóstico:**
```bash
# Procurar em arquivos
grep -r "CLICKSIGN_API_TOKEN" .

# Procurar nos logs
docker-compose logs n8n | grep -i token
```

**Soluções:**

#### 1. Regenerar tokens
```bash
# ClickSign: Gerar novo token
# Twilio: Rotate auth token
# Outlook: Gerar nova app password
```

#### 2. Remover de git
```bash
# Se commitou por acidente
git rm --cached .env
git commit -m "Remove .env"
git push
# + Regenerar credenciais!
```

#### 3. Mascarar logs
```bash
# N8N → Settings → Logging
# Desativar "Log credential in nodeData"
```

---

## 📈 Monitoramento

### Problema: Não consigo ver execuções

**Sintoma:** Executions vazio ou histórico apagado

**Diagnóstico:**
```bash
# Verificar retenção em BD
docker-compose exec postgres psql -U n8n -d n8n \
  -c "SELECT COUNT(*) FROM execution_entity"
```

**Soluções:**

#### 1. Limpeza automática ativa
```bash
# N8N → Settings → Execution Data
# "Data retention": Desativar ou aumentar dias
```

#### 2. Limite de armazenamento atingido
```bash
# Ver tamanho BD
docker-compose exec postgres_custom pg_size_pretty(

pg_database_size('n8n'))

# Se > 5GB: fazer backup e limpar
```

---

## 🚀 Checklist de Debug

Para qualquer problema, seguir:

```
1. ☐ Ver logs: docker-compose logs -f [container]
2. ☐ Verificar conectividade: curl/telnet/ping
3. ☐ Testar credencial: Credentials → Test connection
4. ☐ Verificar variáveis: Abrir .env
5. ☐ Reiniciar serviço: docker-compose restart [service]
6. ☐ Verificar firewall: Porta aberta?
7. ☐ Verificar arquivo: Path correto? Permissions?
8. ☐ Limpar cache: docker-compose down && up -d
9. ☐ Consultar docs oficial: clicksign.com/api, twilio.com, etc
10. ☐ Criar issue com logs completos
```

---

## 🆘 Suporte

### Se não conseguir resolver

1. **Coletar informações:**
   ```bash
   docker-compose logs > logs.txt
   docker-compose exec postgres_custom pg_dump -U app_user assinatura > backup.sql
   cat .env > config.txt  # Sem senhas!
   ```

2. **Criar issue com:**
   - Descrição exata do erro
   - Logs completos
   - Passos para reproduzir
   - Versões (Docker, N8N, PostgreSQL)

3. **Contatar suporte:**
   - ClickSign: https://clicksign.com/suporte
   - Twilio: https://twilio.com/help
   - N8N: https://community.n8n.io

---

**Voltar para: [README.md](./README.md)**
