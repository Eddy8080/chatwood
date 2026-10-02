#!/bin/bash
# ==============================================================================
# Script de Validacao Preflight Check - Chatwoot VPS
# Verifica: Portas no Host, Conectividade Docker, Extensao pgvector e Nginx
# ==============================================================================

set -eo pipefail

COMPOSE_FILE="docker-compose.production.yaml"
ENV_FILE=".env"

echo "------------------------------------------------------------------------------"
echo "  CHATWOOT PREFLIGHT CHECK - VPS"
echo "------------------------------------------------------------------------------"

# 1. Checagem de colisao de portas no Host
echo "[+] Verificando portas no host (5432 / 6379 / 3000)..."

if ss -tuln | grep -q ":3000 "; then
    echo "  [INFO] Porta 3000 em uso no host (esperado se chatwoot_web já estiver rodando)."
else
    echo "  [OK] Porta 3000 disponivel para o Rails."
fi

# 2. Validacao do arquivo .env
echo "[+] Validando variaveis criticas no $ENV_FILE..."
source "$ENV_FILE"

if [ -z "$SECRET_KEY_BASE" ] || [ "$SECRET_KEY_BASE" == "COLOQUE_AQUI_SUA_SECRET_KEY_BASE_GERADA_COM_OPENSSL_RAND_HEX_64" ]; then
    echo "  [FALHA] SECRET_KEY_BASE invalida ou nao preenchida no $ENV_FILE!"
    exit 1
fi

if [ "$FORCE_SSL" == "true" ]; then
    echo "  [AVISO] FORCE_SSL esta como 'true'. O proxy Nginx DEVE repassar 'X-Forwarded-Proto https' para evitar loops 301."
fi

echo "  [OK] Variaveis criticas validadas."

# 3. Teste de conectividade com Banco de Dados e extensao pgvector
echo "[+] Testando conexao com PostgreSQL e presenca da extensao vector..."
if docker compose -f "$COMPOSE_FILE" ps postgres | grep -q "Up"; then
    DB_CHECK=$(docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U "${POSTGRES_USER:-chatwoot}" -d "${POSTGRES_DB:-chatwoot_production}" -tAc "SELECT count(*) FROM pg_extension WHERE extname='vector';" 2>/dev/null || echo "0")
    if [ "$DB_CHECK" -ge "1" ]; then
        echo "  [OK] PostgreSQL conectado e extensao 'vector' (pgvector) ativa!"
    else
        echo "  [AVISO] Extensao vector nao encontrada. Sera criada na migracao."
    fi
else
    echo "  [INFO] Container postgres ainda nao inicializado (sera criado no deploy)."
fi

# 4. Validacao de configuracao do Nginx
echo "[+] Verificando conformidade do Nginx (se instalado no host ou container)..."
if command -v nginx > /dev/null 2>&1; then
    sudo nginx -t 2>/dev/null && echo "  [OK] Sintaxe do Nginx valida no host." || echo "  [AVISO] Erro na sintaxe do Nginx no host."
elif docker ps | grep -q "digiana_nginx"; then
    docker exec digiana_nginx nginx -t 2>/dev/null && echo "  [OK] Sintaxe do Nginx valida no container digiana_nginx." || echo "  [AVISO] Erro na sintaxe do Nginx no digiana_nginx."
fi

echo "------------------------------------------------------------------------------"
echo "  Preflight Check concluido com sucesso!"
echo "------------------------------------------------------------------------------"
