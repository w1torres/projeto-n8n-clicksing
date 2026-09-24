-- Schema da base "assinatura" (LGPD audit trail).
-- Adaptado da doc original para os conceitos do ClickSign API v3:
-- v1 tinha um único "document id"; v3 trabalha com envelope + documento + signatário
-- como recursos separados, e não expõe uma URL de assinatura compartilhável
-- (quem envia o convite de assinatura é o próprio ClickSign).

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
    clicksign_envelope_id VARCHAR(255),
    clicksign_document_id VARCHAR(255),
    clicksign_signer_id VARCHAR(255),
    canal_notificacao VARCHAR(50),
    retry_count INT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_cpf ON assinaturas(cpf);
CREATE INDEX IF NOT EXISTS idx_status ON assinaturas(status);
CREATE INDEX IF NOT EXISTS idx_email ON assinaturas(email);
CREATE INDEX IF NOT EXISTS idx_data_envio ON assinaturas(data_envio);
CREATE INDEX IF NOT EXISTS idx_envelope_id ON assinaturas(clicksign_envelope_id);

CREATE TABLE IF NOT EXISTS auditoria_assinaturas (
    id SERIAL PRIMARY KEY,
    assinatura_id INT REFERENCES assinaturas(id),
    acao VARCHAR(100),
    data_acao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    detalhes TEXT
);

CREATE INDEX IF NOT EXISTS idx_auditoria_assinatura ON auditoria_assinaturas(assinatura_id);
