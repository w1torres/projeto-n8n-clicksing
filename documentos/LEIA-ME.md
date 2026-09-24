# Documento a ser assinado

Coloque aqui o PDF real a ser enviado para assinatura, com o nome definido
em `DOCUMENTO_PATH` no `.env` (padrão: `termo-whatsapp-lgpd.pdf`).

Este repositório não inclui o PDF em si — apenas o placeholder da pasta,
montada como somente-leitura dentro do container do n8n
(`./documentos:/home/node/n8n/documentos:ro`, ver `docker-compose.yml`).
