$ignoradas = @("virtualbox", "vmware", "hyper-v", "loopback", "vpn", "bluetooth", "tunneling")

$interface = Get-NetAdapter |
    Where-Object {
        $_.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch ($ignoradas -join "|") -and
        $_.Name -match "Ethernet"
    } |
    Sort-Object -Property InterfaceMetric |
    Select-Object -First 1

if (-not $interface) {
    Write-Host "Erro: Nenhuma interface de rede cabeada real ativa foi encontrada."
    exit 1
}

$interfaceName = $interface.Name

$ipAddress = (Get-NetIPAddress -InterfaceAlias $interfaceName -AddressFamily IPv4 | Select-Object -First 1).IPAddress

if (-not $ipAddress) {
    Write-Host "Erro: Não foi possível obter o IP da interface $interfaceName."
    exit 1
}

# Define o DNS com o IP da interface encontrada
Write-Host "Configurando DNS para $ipAddress na interface $interfaceName..."
Set-DnsClientServerAddress -InterfaceAlias $interfaceName -ServerAddresses $ipAddress

# Desativar IPv6 na interface
Write-Host "Desativando IPv6 na interface $interfaceName..."
Disable-NetAdapterBinding -Name $interfaceName -ComponentID ms_tcpip6 -Confirm:$false

# Define caminho do script e arquivo de zona
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$zoneFilePath = Join-Path -Path $scriptRoot -ChildPath "..\DNS\sonserina.br"

if (-Not (Test-Path $zoneFilePath)) {
    Write-Host "Erro: Arquivo de zona não encontrado em $zoneFilePath"
    exit 1
}

# Lê e atualiza o conteúdo do arquivo de zona
$linhas = Get-Content $zoneFilePath

for ($i = 0; $i -lt $linhas.Count; $i++) {
    if ($linhas[$i] -match "^\s*ns\s+IN\s+A\s+\d{1,3}(\.\d{1,3}){3}") {
        $linhas[$i] = ($linhas[$i] -replace "\d{1,3}(\.\d{1,3}){3}", $ipAddress)
    }
    elseif ($linhas[$i] -match "^\s*@\s+IN\s+A\s+\d{1,3}(\.\d{1,3}){3}") {
        $linhas[$i] = ($linhas[$i] -replace "\d{1,3}(\.\d{1,3}){3}", $ipAddress)
    }
    elseif ($linhas[$i] -match "^\s*www\s+IN\s+A\s+\d{1,3}(\.\d{1,3}){3}") {
        $linhas[$i] = ($linhas[$i] -replace "\d{1,3}(\.\d{1,3}){3}", $ipAddress)
    }
}

# Salva o conteúdo atualizado
$linhas | Set-Content $zoneFilePath -Encoding UTF8

Write-Host "Arquivo de zona atualizado com IP: $ipAddress"

Write-Host "Script finalizado com sucesso."
