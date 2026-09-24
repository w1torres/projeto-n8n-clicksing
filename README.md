# Assinatura Digital — n8n + ClickSign

Automação para envio de documentos para assinatura via **ClickSign (API v3)**,
com registro em PostgreSQL e confirmação por Outlook + WhatsApp (Twilio) após
a assinatura.

> Os arquivos `n8n-assinatura-*.md` na raiz são a documentação original do
> projeto (arquitetura, banco de dados, troubleshooting genérico). Eles
> assumiam a API v1 do ClickSign; a implementação real neste repositório usa a
> **API v3** e diverge da doc original em vários pontos — este README reflete
> o que está realmente implementado e testado.

## Arquitetura

- O **ClickSign** cria o envelope, recebe o documento e o signatário, e
  **notifica nativamente** (convite de assinatura via WhatsApp, configurável
  para email — ver `ClickSign - Adicionar Signatário` no Workflow 1).
- O **n8n** só entra depois: escuta o webhook de confirmação de assinatura e
  manda a própria mensagem de confirmação (Outlook + Twilio WhatsApp).
- Antes de enviar, o **nome, CPF e local/data do colaborador são estampados
  na última página do PDF** (Anexo I — Termo de Ciência), usando `pdf-lib`
  dentro do próprio node "Preparar Dados".

```
CSV colaboradores
      │
      ▼
Preparar Dados (monta payload do envelope + estampa PDF com pdf-lib)
      │
      ▼
ClickSign: Criar Envelope → Adicionar Documento → Adicionar Signatário
      → Requisito Assinatura → Requisito Autenticação → Ativar Envelope
      → Notificar Envelope (dispara o convite de fato)
      │
      ▼
Postgres: Inserir Assinatura + Auditoria
      │
      ▼
(aguarda o colaborador assinar)
      │
      ▼
Webhook ClickSign → valida HMAC → Postgres UPDATE status
      → Outlook (confirmação) + Twilio WhatsApp (confirmação)
```

## Setup

1. `cp .env.example .env` e preencha as credenciais (ver comentários no
   próprio arquivo — o token do ClickSign **não** vai no `.env`, é cadastrado
   como Credential dentro do n8n).
2. Coloque o PDF real em `documentos/termo-whatsapp-lgpd.pdf` (nome definido
   por `DOCUMENTO_PATH` no `.env`). A última página do documento precisa ter
   uma seção com campos "Nome completo" / "CPF / Matrícula" / "Local e data"
   em branco — é onde o pdf-lib estampa os dados (coordenadas fixas no código
   do node "Preparar Dados"; ajuste se o layout do seu PDF for diferente).
3. `docker compose up -d --build` (o `--build` é necessário porque a imagem
   do n8n é customizada — ver `Dockerfile` — para incluir o `pdf-lib`).
4. Abra `http://localhost:5678` (usuário/senha em `N8N_BASIC_AUTH_USER` /
   `N8N_BASIC_AUTH_PASSWORD` no `.env`).
5. Crie duas credenciais no n8n:
   - **Header Auth** — nome `Authorization`, valor = token do ClickSign (sem
     `Bearer`).
   - **Postgres** — host `postgres_custom`, porta `5432`, database
     `assinatura`, usuário/senha conforme `DB_APP_USER`/`DB_APP_PASSWORD`.
6. Importe os 3 arquivos de `n8n_workflows/` (Import from File). Confira se
   cada node ClickSign/Postgres ficou vinculado às credenciais acima — o
   import não faz isso sozinho pelo nome.
7. Ative o Workflow 2 (webhook) e o Workflow 3 (relatório diário). Para
   testar o Workflow 1 manualmente: clique **Execute workflow** no editor e
   dispare
   `POST http://localhost:5678/webhook-test/assinatura/enviar`.

**Importante:** depois de qualquer alteração nos arquivos `n8n_workflows/*.json`,
é preciso **reimportar** o workflow no n8n — editar o `.json` no disco não
atualiza sozinho o que já está salvo dentro do n8n.

## Limitações / decisões conhecidas (aprendidas testando de verdade)

- **`$('NomeDoNode')` entre múltiplos itens não é confiável.** Descobrimos
  isso testando com 2+ colaboradores no CSV: a referência resolvia `undefined`
  para itens além do primeiro. Por isso o Workflow 1 processa os
  colaboradores em uma cadeia linear simples (sem `Split In Batches`) — ainda
  assim, teste com lotes grandes antes de confiar cegamente nisso em produção.
- **Resposta do ClickSign não é JSON automaticamente.** O Content-Type
  `application/vnd.api+json` não é reconhecido pelo n8n como JSON por padrão;
  todos os nodes HTTP Request para o ClickSign têm
  `options.response.response.responseFormat = "json"` forçado explicitamente.
  Sem isso, `$json.data.id` etc. vêm `undefined`.
- **Ativar o envelope não dispara o convite sozinho.** É preciso um node
  extra `POST /envelopes/{id}/notifications` depois do `PATCH status=running`
  (node "ClickSign - Notificar Envelope").
- **`content_base64` do documento precisa ser um Data URI completo**
  (`data:application/pdf;base64,...`), não só a string base64 pura.
- **Code node não pode fazer chamadas autenticadas via credential.**
  `this.helpers.httpRequestWithAuthentication` é bloqueado no sandbox do Code
  node — por isso as chamadas ao ClickSign usam nodes HTTP Request normais,
  não um único Code node.
- **`$env`, `fs` e pacotes externos (`pdf-lib`) são bloqueados por padrão** —
  liberados via `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`,
  `NODE_FUNCTION_ALLOW_BUILTIN=crypto,fs` e `NODE_FUNCTION_ALLOW_EXTERNAL=pdf-lib`
  no `docker-compose.yml`.
- **CPF é `UNIQUE`** na tabela `assinaturas` — reenviar para o mesmo CPF sem
  ter fechado o registro anterior dá erro de constraint (proposital, evita
  duplicar envio; mas atrapalha teste repetido com o mesmo colaborador).
- **Canal WhatsApp nativo do ClickSign** (`communicate_events.signature_request`,
  `document_signed` e `auth` do requisito de autenticação = `"whatsapp"`)
  depende da sua conta ClickSign ter esse canal habilitado/permitido — se não
  chegar a mensagem, confira isso antes de suspeitar do formato do telefone.

## Estrutura

```
docker-compose.yml       # n8n (build custom) + Postgres do n8n + Postgres da app
Dockerfile                # n8n + pdf-lib instalado globalmente
init-db.sql               # schema: assinaturas + auditoria_assinaturas
.env.example               # todas as variáveis, comentadas
dados/colaboradores.csv    # entrada do Workflow 1
documentos/                # PDF real (não versionado — ver .gitignore)
n8n_workflows/
  01-workflow-envio.json      # ClickSign: cria envelope + notifica
  02-workflow-webhook.json    # recebe confirmação de assinatura
  03-workflow-relatorio.json  # relatório diário por email
n8n-assinatura-*.md        # documentação original (v1, parcialmente desatualizada)
```
