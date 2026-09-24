FROM n8nio/n8n:latest

# pdf-lib eh usado pelo Code node "Preparar Dados" para estampar
# nome/CPF/local no PDF antes de enviar pro ClickSign (ver NODE_FUNCTION_ALLOW_EXTERNAL
# no docker-compose.yml). Instalado dentro do node_modules do proprio n8n para
# que o require('pdf-lib') do Code node consiga resolver o pacote.
USER root
RUN npm install -g pdf-lib
USER node
# Necessario para o Node resolver o pacote instalado globalmente a partir
# do processo do n8n (que fica em /usr/local/lib/node_modules/n8n, uma
# arvore separada gerenciada por pnpm, onde "npm install --prefix" nao
# funciona por causa da sintaxe de patch do pnpm no package.json do n8n).
ENV NODE_PATH=/usr/local/lib/node_modules
