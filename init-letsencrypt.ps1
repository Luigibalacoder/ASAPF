$ErrorActionPreference = "Stop"

# Configurações
$DOMAINS = @("portal.sonserina.br", "webmail.sonserina.br")
$EMAIL = "sonserina@email.com"

Write-Host "============================================="
Write-Host " Iniciando configuração do Let's Encrypt"
Write-Host "============================================="
Write-Host "Domínios: $($DOMAINS -join ', ')"
Write-Host "Email: $EMAIL"
Write-Host ""

# Criar diretórios
Write-Host "[1/6] Criando diretórios para certificados..."
New-Item -ItemType Directory -Force -Path certbot, certbot\www, certbot\conf | Out-Null
Write-Host "Diretórios criados:"
Get-ChildItem certbot
Write-Host ""

# Iniciar NGINX temporariamente
Write-Host "[2/6] Iniciando container do proxy..."
docker-compose up -d proxy
Start-Sleep -Seconds 5  # Aguardar inicialização

Write-Host "[3/6] Verificando containers em execução..."
docker ps --format "table {{.ID}}`t{{.Names}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

# Obter certificados
Write-Host "[4/6] Obtendo certificados SSL..."
foreach ($DOMAIN in $DOMAINS) {
    Write-Host "---------------------------------------------"
    Write-Host " Processando domínio: $DOMAIN"
    Write-Host "---------------------------------------------"
    
    docker-compose run --rm certbot certonly `
        --webroot `
        --webroot-path /var/www/certbot `
        --email $EMAIL `
        --agree-tos `
        --no-eff-email `
        -d $DOMAIN `
        --rsa-key-size 4096 `
        --force-renewal
        
    Write-Host "Verificando certificado gerado para $DOMAIN"
    docker-compose run --rm certbot ls -l /etc/letsencrypt/live/$DOMAIN
    Write-Host ""
}

Write-Host "[5/6] Parando todos os serviços..."
docker-compose down
Write-Host ""

# Reiniciar todos os serviços
Write-Host "[6/6] Iniciando todos os serviços..."
docker-compose up -d
Start-Sleep -Seconds 5  # Aguardar inicialização
Write-Host ""

Write-Host "============================================="
Write-Host " Configuração completa!"
Write-Host "============================================="
Write-Host "Status final dos containers:"
docker ps --format "table {{.ID}}`t{{.Names}}`t{{.Status}}`t{{.Ports}}"
Write-Host ""

Write-Host "Verificando certificados no host:"
if (Test-Path "certbot\conf\live") {
    Get-ChildItem certbot\conf\live
} else {
    Write-Host "Pasta de certificados não encontrada!"
}
Write-Host ""

Write-Host "Testando configuração do Nginx:"
docker-compose exec proxy nginx -t
Write-Host ""

Write-Host "Os seguintes endereços devem estar acessíveis via HTTPS:"
foreach ($DOMAIN in $DOMAINS) {
    Write-Host "https://$DOMAIN"
}