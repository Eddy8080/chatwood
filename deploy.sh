#!/bin/bash
# ==============================================================================
# Script de Deploy e Atualizacao Segura - Chatwoot VPS
# Executa: pull, build incremental, migracao de banco e reload suave dos servicos
# ==============================================================================

set -eo pipefail

COMPOSE_FILE="docker-compose.production.yaml"
ENV_FILE=".env"
APP_CONTAINER="chatwoot_web"
SIDEKIQ_CONTAINER="chatwoot_sidekiq"

echo "==> [1/6] Validando ambiente e arquivos de configuracao..."
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERRO: Arquivo $COMPOSE_FILE nao encontrado!"
    exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
    echo "ERRO: Arquivo $ENV_FILE de producao nao encontrado!"
    exit 1
fi

echo "==> [2/6] Executando preflight check de infraestrutura..."
if [ -f "./preflight-check.sh" ]; then
    bash ./preflight-check.sh
fi

echo "==> [3/6] Baixando ultimas imagens e subindo servicos de infraestrutura (DB / Redis)..."
docker compose -f "$COMPOSE_FILE" up -d postgres redis

echo "==> [4/6] Executando migracoes de banco de dados (Rails db:migrate)..."
docker compose -f "$COMPOSE_FILE" run --rm rails bundle exec rake db:chatwoot_prepare

echo "==> [5/6] Iniciando/Atualizando aplicacao Web e Workers Sidekiq..."
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans rails sidekiq

echo "==> [6/6] Verificando saude dos containers da stack..."
sleep 5
docker compose -f "$COMPOSE_FILE" ps

echo ""
echo "=============================================================================="
echo "  Deploy do Chatwoot concluido com sucesso em https://chatwood.digianaapp.com.br"
echo "=============================================================================="
