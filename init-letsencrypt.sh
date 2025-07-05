#!/bin/bash

DOMAINS=("portal.sonserina.br" "webmail.sonserina.br")
EMAIL="sonserina@email.com"

echo "============================================="
echo " Iniciando configuração do Let's Encrypt"
echo "============================================="
echo "Domínios: ${DOMAINS[@]}"
echo "Email: $EMAIL"
echo ""

# Criar diretórios
echo "[1/6] Criando diretórios para certificados..."
mkdir -p certbot/{www,conf}
echo "Diretórios criados:"
ls -ld certbot certbot/www certbot/conf
echo ""

# Iniciar NGINX temporariamente
echo "[2/6] Iniciando container do proxy..."
docker-compose up -d proxy
echo ""

echo "[3/6] Verificando containers em execução..."
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Obter certificados
echo "[4/6] Obtendo certificados SSL..."
for DOMAIN in "${DOMAINS[@]}"; do
    echo "---------------------------------------------"
    echo " Processando domínio: $DOMAIN"
    echo "---------------------------------------------"
    
    docker-compose run --rm certbot certonly \
        --webroot \
        --webroot-path /var/www/certbot \
        --email $EMAIL \
        --agree-tos \
        --no-eff-email \
        -d $DOMAIN \
        --rsa-key-size 4096 \
        --force-renewal
        
    echo "Verificando certificado gerado para $DOMAIN:"
    docker-compose run --rm certbot ls -l /etc/letsencrypt/live/$DOMAIN
    echo ""
done

echo "[5/6] Parando todos os serviços..."
docker-compose down
echo ""

# Reiniciar todos os serviços
echo "[6/6] Iniciando todos os serviços..."
docker-compose up -d
echo ""

echo "============================================="
echo " Configuração completa!"
echo "============================================="
echo "Status final dos containers:"
docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "Verificando certificados no host:"
ls -l certbot/conf/live
echo ""

echo "Testando configuração do Nginx:"
docker-compose exec proxy nginx -t
echo ""

echo "Os seguintes endereços devem estar acessíveis via HTTPS:"
for DOMAIN in "${DOMAINS[@]}"; do
    echo "https://$DOMAIN"
done