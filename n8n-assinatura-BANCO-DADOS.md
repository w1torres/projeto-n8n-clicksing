# 🗄️ Banco de Dados — Schema SQL e Queries

Documentação completa do modelo de dados e operações SQL.

---

## 📊 Schema Completo

### Tabela: assinaturas

```sql
CREATE TABLE assinaturas (
    -- Primary Key
    id SERIAL PRIMARY KEY,
    
    -- Dados Pessoais (LGPD)
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
    -- Valores permitidos:
    --   'enviado'   = Documento enviado, aguardando assinatura
    --   'assinado'  = Documento assinado
    --   'recusado'  = Colaborador recusou assinar
    --   'expirado'  = Prazo de 30 dias expirou
    --   'pendente'  = Aguardando ação
    
    -- Integração ClickSign
    clicksign_doc_id VARCHAR(255),
    clicksign_url TEXT,
    
    -- Metadados
    canal_notificacao VARCHAR(50),
    -- Valores: 'email' | 'whatsapp' | 'email_whatsapp'
    
    retry_count INT DEFAULT 0,
    -- Tentativas de reenvio
    
    -- Auditoria
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Criar índices para performance
CREATE INDEX idx_assinaturas_cpf ON assinaturas(cpf);
CREATE INDEX idx_assinaturas_status ON assinaturas(status);
CREATE INDEX idx_assinaturas_email ON assinaturas(email);
CREATE INDEX idx_assinaturas_data_envio ON assinaturas(data_envio);
CREATE INDEX idx_assinaturas_clicksign_doc_id ON assinaturas(clicksign_doc_id);
```

### Tabela: auditoria_assinaturas

```sql
CREATE TABLE auditoria_assinaturas (
    id SERIAL PRIMARY KEY,
    assinatura_id INT NOT NULL REFERENCES assinaturas(id) ON DELETE CASCADE,
    
    -- Ação realizada
    acao VARCHAR(100) NOT NULL,
    -- Valores: 'criado' | 'notificado_email' | 'notificado_whatsapp' 
    --          | 'assinado' | 'recusado' | 'expirado' | 'reenvio'
    
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Detalhe (JSON opcional)
    detalhes TEXT,
    -- JSON com informações extra:
    -- {"email": "user@mail.com", "canal": "whatsapp", "erro": "..."}
    
    usuario_acao VARCHAR(100),
    -- Quem fez a ação (sistema, admin, etc)
    
    ip_origem VARCHAR(45)
    -- Para auditoria adicional
);

-- Índices
CREATE INDEX idx_auditoria_assinatura_id ON auditoria_assinaturas(assinatura_id);
CREATE INDEX idx_auditoria_data ON auditoria_assinaturas(data_acao);
CREATE INDEX idx_auditoria_acao ON auditoria_assinaturas(acao);
```

---

## 📝 Queries Úteis

### Listar Todas as Assinaturas

```sql
SELECT 
    id,
    nome_completo,
    cpf,
    email,
    status,
    data_envio,
    data_assinatura
FROM assinaturas
ORDER BY data_envio DESC;
```

### Contar por Status

```sql
SELECT 
    status,
    COUNT(*) as quantidade,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as percentual
FROM assinaturas
GROUP BY status
ORDER BY quantidade DESC;
```

**Resultado esperado:**
```
   status    | quantidade | percentual
-------------+------------+-----------
 assinado    |    145     |  72.50
 enviado     |    55      |  27.50
 recusado    |    0       |   0.00
 expirado    |    0       |   0.00
```

### Documentos Próximos de Expirar (7 dias)

```sql
SELECT 
    id,
    nome_completo,
    email,
    telefone,
    data_envio,
    (data_envio + INTERVAL '30 days') as data_expiracao,
    EXTRACT(DAY FROM (data_envio + INTERVAL '30 days' - NOW())) as dias_restantes
FROM assinaturas
WHERE status = 'enviado'
  AND data_envio + INTERVAL '30 days' <= NOW() + INTERVAL '7 days'
ORDER BY dias_restantes ASC;
```

### Buscar por CPF

```sql
SELECT * FROM assinaturas WHERE cpf = '123.456.789-10';
```

### Histórico de Auditoria para um Colaborador

```sql
SELECT 
    au.id,
    au.acao,
    au.data_acao,
    au.detalhes,
    au.usuario_acao
FROM auditoria_assinaturas au
JOIN assinaturas a ON au.assinatura_id = a.id
WHERE a.cpf = '123.456.789-10'
ORDER BY au.data_acao DESC;
```

### Taxa de Conversão Diária

```sql
SELECT 
    DATE(data_envio) as data,
    COUNT(*) as total_enviados,
    SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END) as assinados,
    ROUND(
        SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END)::numeric / 
        COUNT(*) * 100, 2
    ) as taxa_assinatura_pct
FROM assinaturas
GROUP BY DATE(data_envio)
ORDER BY data DESC
LIMIT 30;
```

### Detectar Duplicatas

```sql
SELECT 
    cpf,
    COUNT(*) as total,
    array_agg(id) as ids
FROM assinaturas
GROUP BY cpf
HAVING COUNT(*) > 1
ORDER BY total DESC;
```

### Listar Rejeições (Recusados)

```sql
SELECT 
    nome_completo,
    cpf,
    email,
    status,
    data_envio,
    data_assinatura
FROM assinaturas
WHERE status = 'recusado'
ORDER BY data_assinatura DESC;
```

### Envios com Erro (Retry count alto)

```sql
SELECT 
    nome_completo,
    email,
    retry_count,
    data_envio,
    status
FROM assinaturas
WHERE retry_count > 3
ORDER BY retry_count DESC;
```

---

## 🔄 Operações CRUD

### CREATE — Inserir Nova Assinatura

```sql
INSERT INTO assinaturas 
(nome_completo, cpf, email, telefone, local_assinatura, status)
VALUES 
('João Silva', '123.456.789-10', 'joao@tchea.com.br', '11987654321', 'Matriz - Formosa/GO', 'enviado');
```

### READ — Consultar Assinaturas

```sql
SELECT * FROM assinaturas WHERE email = 'joao@tchea.com.br';
```

### UPDATE — Atualizar Status

```sql
UPDATE assinaturas
SET 
    status = 'assinado',
    data_assinatura = NOW(),
    clicksign_doc_id = 'doc_abc123'
WHERE cpf = '123.456.789-10';
```

### DELETE — Remover (Apenas para teste!)

```sql
-- ⚠️ CUIDADO: Registrar em auditoria antes de deletar
DELETE FROM assinaturas WHERE id = 1;
```

---

## 📊 Reports Analíticos

### Relatório Executivo

```sql
WITH stats AS (
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END) as assinados,
        SUM(CASE WHEN status = 'enviado' THEN 1 ELSE 0 END) as pendentes,
        SUM(CASE WHEN status = 'recusado' THEN 1 ELSE 0 END) as recusados,
        SUM(CASE WHEN status = 'expirado' THEN 1 ELSE 0 END) as expirados,
        AVG(EXTRACT(EPOCH FROM (data_assinatura - data_envio))) as tempo_medio_assinatura_seg
    FROM assinaturas
)
SELECT 
    total,
    assinados,
    pendentes,
    recusados,
    expirados,
    ROUND((assinados::numeric / total * 100), 2) as taxa_conversao_pct,
    ROUND(tempo_medio_assinatura_seg / 3600, 1) as tempo_medio_horas
FROM stats;
```

### Ranking de Departamentos

```sql
-- Se houver coluna departamento
SELECT 
    departamento,
    COUNT(*) as total,
    SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END) as assinados,
    ROUND(
        SUM(CASE WHEN status = 'assinado' THEN 1 ELSE 0 END)::numeric / COUNT(*) * 100, 2
    ) as taxa_pct
FROM assinaturas
GROUP BY departamento
ORDER BY taxa_pct DESC;
```

---

## 🛠️ Manutenção

### Backup Completo

```bash
# No terminal (fora do container)
docker-compose exec postgres_custom pg_dump -U app_user assinatura > backup-$(date +%Y%m%d-%H%M%S).sql

# Restaurar
docker-compose exec postgres_custom psql -U app_user assinatura < backup-20250115-093000.sql
```

### Limpeza de Dados Antigos

```sql
-- Arquivar assinaturas com mais de 1 ano
DELETE FROM assinaturas
WHERE data_envio < NOW() - INTERVAL '1 year'
  AND status IN ('recusado', 'expirado');

-- ⚠️ Fazer backup antes!
```

### Reindexar Tabelas

```sql
REINDEX TABLE assinaturas;
REINDEX TABLE auditoria_assinaturas;
```

### Verificar Integridade

```sql
-- Verificar órfãs (auditoria sem assinatura)
SELECT au.id
FROM auditoria_assinaturas au
LEFT JOIN assinaturas a ON au.assinatura_id = a.id
WHERE a.id IS NULL;
```

---

## 🔐 Segurança de Dados

### Rotular Dados Sensíveis

```sql
-- Comentário de segurança
COMMENT ON TABLE assinaturas IS 'Dados pessoais sensíveis - LGPD';
COMMENT ON COLUMN assinaturas.cpf IS 'Identificação pessoal - PII';
COMMENT ON COLUMN assinaturas.telefone IS 'Contato pessoal - PII';
```

### Controle de Acesso

```sql
-- Criar role de leitura
CREATE ROLE viewer WITH LOGIN PASSWORD 'senha_segura';
GRANT SELECT ON assinaturas TO viewer;
GRANT SELECT ON auditoria_assinaturas TO viewer;

-- Criar role de escrita
CREATE ROLE editor WITH LOGIN PASSWORD 'senha_segura';
GRANT SELECT, INSERT, UPDATE ON assinaturas TO editor;
GRANT SELECT, INSERT ON auditoria_assinaturas TO editor;
```

### Pseudonimização (GDPR)

```sql
-- Para relatórios sem PII
SELECT 
    id,
    MD5(cpf) as cpf_hash,  -- Irreversível
    status,
    data_envio
FROM assinaturas
WHERE status = 'assinado';
```

---

## 🚀 Performance

### Análise de Query

```sql
EXPLAIN ANALYZE
SELECT * FROM assinaturas
WHERE status = 'enviado'
  AND data_envio > NOW() - INTERVAL '30 days'
ORDER BY data_envio DESC;
```

### Monitorar Tamanho de Tabelas

```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as tamanho
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 📱 Conectar via Cliente SQL

### DBeaver (Recomendado)

```
Host: localhost
Port: 5432
Database: assinatura
User: app_user
Password: app_password_secure
Driver: PostgreSQL
```

### pgAdmin (Web)

```
Host: postgres_custom:5432
User: app_user
Password: app_password_secure
```

### psql (Terminal)

```bash
docker-compose exec postgres_custom psql -U app_user -d assinatura
```

---

**Próximo documento: [API.md](./API.md)**
