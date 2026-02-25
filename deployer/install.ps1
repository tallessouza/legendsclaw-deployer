#Requires -Version 5.1
<#
.SYNOPSIS
    Legendsclaw Installer — Windows nativo (PowerShell)
.DESCRIPTION
    Equivalente ao install.sh --local para Windows.
    Executa 4 etapas: Setup Local, Bridge Local→VPS, OpenClaw Remote, AIOS Init.
.EXAMPLE
    # One-liner (download + execute)
    irm https://raw.githubusercontent.com/tallessouza/legendsclaw-deployer/main/deployer/install.ps1 | iex

    # Ou baixar e rodar
    Invoke-WebRequest -Uri .../install.ps1 -OutFile install.ps1
    .\install.ps1
.NOTES
    Compativel: Windows 10 21H2+ / Windows 11
    Requer: winget (App Installer)
#>

$ErrorActionPreference = 'Stop'

# =============================================================================
# Constantes
# =============================================================================

$INSTALL_VERSION = '1.2.0'
$REPO_URL = 'https://github.com/tallessouza/legendsclaw-deployer.git'
$TIMESTAMP = Get-Date -Format 'yyyyMMdd_HHmmss'
$LOG_DIR = Join-Path $HOME 'legendsclaw-logs'
$LOG_FILE = Join-Path $LOG_DIR "install-${TIMESTAMP}.log"
$INSTALL_DIR = Join-Path $HOME 'legendsclaw'
$STATE_DIR = Join-Path $HOME 'dados_vps'
$NODE_MIN_VERSION = 22
$TOTAL_STEPS = 12

# Contadores
$script:CURRENT_STEP = 0
$script:COUNT_OK = 0
$script:COUNT_SKIP = 0
$script:COUNT_FAIL = 0

# =============================================================================
# Logging
# =============================================================================

if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Add-Content -Path $LOG_FILE -Value $line -ErrorAction SilentlyContinue
}

# =============================================================================
# Feedback Visual (Pattern N/M - [ OK ] - mensagem)
# =============================================================================

function Feedback-OK {
    param([string]$Message)
    $script:CURRENT_STEP++
    $script:COUNT_OK++
    Write-Host "$($script:CURRENT_STEP)/$TOTAL_STEPS - [ " -NoNewline
    Write-Host "OK" -ForegroundColor Green -NoNewline
    Write-Host " ] - $Message"
    Write-Log "OK: $Message"
}

function Feedback-SKIP {
    param([string]$Message)
    $script:CURRENT_STEP++
    $script:COUNT_SKIP++
    Write-Host "$($script:CURRENT_STEP)/$TOTAL_STEPS - [ " -NoNewline
    Write-Host "SKIP" -ForegroundColor Yellow -NoNewline
    Write-Host " ] - $Message"
    Write-Log "SKIP: $Message"
}

function Feedback-FAIL {
    param([string]$Message)
    $script:CURRENT_STEP++
    $script:COUNT_FAIL++
    Write-Host "$($script:CURRENT_STEP)/$TOTAL_STEPS - [ " -NoNewline
    Write-Host "FAIL" -ForegroundColor Red -NoNewline
    Write-Host " ] - $Message"
    Write-Log "FAIL: $Message"
}

function Show-Summary {
    Write-Host ''
    Write-Host 'RESUMO' -ForegroundColor White
    Write-Host "  OK:   $($script:COUNT_OK)" -ForegroundColor Green
    Write-Host "  SKIP: $($script:COUNT_SKIP)" -ForegroundColor Yellow
    Write-Host "  FAIL: $($script:COUNT_FAIL)" -ForegroundColor Red
    Write-Host "  Log: $LOG_FILE"
}

function Read-Input {
    param(
        [string]$Prompt,
        [string]$Default = '',
        [switch]$Required,
        [switch]$Secret
    )
    $display = if ($Default) { "$Prompt[$Default]: " } else { "${Prompt}: " }
    if ($Secret) {
        $secureValue = Read-Host $display -AsSecureString
        $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
        )
    } else {
        $value = Read-Host $display
    }
    if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        while ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host '  Valor obrigatorio.' -ForegroundColor Red
            if ($Secret) {
                $secureValue = Read-Host $display -AsSecureString
                $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureValue)
                )
            } else {
                $value = Read-Host $display
            }
        }
    }
    return $value
}

function Save-StateFile {
    param(
        [string]$FilePath,
        [hashtable]$Data
    )
    if (-not (Test-Path $STATE_DIR)) { New-Item -ItemType Directory -Path $STATE_DIR -Force | Out-Null }
    $lines = @()
    foreach ($key in $Data.Keys) {
        $lines += "${key}: $($Data[$key])"
    }
    $lines | Set-Content -Path $FilePath -Encoding UTF8
}

function Read-StateValue {
    param(
        [string]$FilePath,
        [string]$Key
    )
    if (-not (Test-Path $FilePath)) { return '' }
    $line = Get-Content $FilePath -ErrorAction SilentlyContinue | Where-Object { $_ -match "^${Key}:" } | Select-Object -First 1
    if ($line) {
        return ($line -replace "^${Key}:\s*", '').Trim()
    }
    return ''
}

function Pause-BetweenSteps {
    Write-Host ''
    Write-Host 'Pressione ENTER para continuar...' -ForegroundColor Yellow
    Read-Host | Out-Null
}

# =============================================================================
# Banner
# =============================================================================

Write-Host ''
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host "  Legendsclaw Installer v${INSTALL_VERSION} (WINDOWS)" -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "User: $env:USERNAME"
Write-Host "Modo: LOCAL (PowerShell)"
Write-Host "Log: $LOG_FILE"
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host ''

Write-Log "=== Legendsclaw Installer v${INSTALL_VERSION} (WINDOWS) ==="
Write-Log "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Log "User: $env:USERNAME"

# =============================================================================
# STEP 1: Verificar Windows version + winget
# =============================================================================

$osVersion = [System.Environment]::OSVersion.Version
if ($osVersion.Build -lt 19041) {
    Feedback-FAIL "Windows version $($osVersion.ToString()) nao suportada (requer 10 20H1+ / build 19041+)"
    Show-Summary
    exit 1
}

$wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
if (-not $wingetAvailable) {
    Write-Host '  winget nao encontrado. Tentando instalar App Installer...' -ForegroundColor Yellow
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
        $wingetAvailable = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    } catch {
        # Silently continue — will install manually if needed
    }
}

if ($wingetAvailable) {
    Feedback-OK "Windows $($osVersion.ToString()) + winget disponivel"
} else {
    Feedback-SKIP "Windows $($osVersion.ToString()) — winget nao disponivel (instalar deps manualmente)"
}

# =============================================================================
# STEP 2: Conectividade
# =============================================================================

try {
    $null = Invoke-WebRequest -Uri 'https://github.com' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    Feedback-OK 'Conectividade com github.com'
} catch {
    Feedback-FAIL 'Sem conectividade com github.com'
    Show-Summary
    exit 1
}

# =============================================================================
# STEP 3: Git
# =============================================================================

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitVersion = (git --version 2>$null) -replace 'git version\s*', ''
    Feedback-SKIP "Git ja instalado (v${gitVersion})"
} else {
    if ($wingetAvailable) {
        Write-Host '  Instalando Git via winget...' -ForegroundColor Yellow
        winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements --silent 2>$null
        # Atualizar PATH para esta sessao
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    }
    if ($gitCmd) {
        Feedback-OK 'Git instalado via winget'
    } else {
        Feedback-FAIL 'Falha ao instalar Git. Baixe em: https://git-scm.com/download/win'
        Show-Summary
        exit 1
    }
}

# =============================================================================
# STEP 4: Clone / Pull repositorio
# =============================================================================

if (Test-Path (Join-Path $INSTALL_DIR '.git')) {
    try {
        git -C $INSTALL_DIR pull --ff-only 2>$null | Out-Null
        Feedback-OK 'Repositorio atualizado (git pull)'
    } catch {
        try {
            git -C $INSTALL_DIR fetch origin 2>$null | Out-Null
            git -C $INSTALL_DIR reset --hard origin/main 2>$null | Out-Null
            Feedback-OK 'Repositorio resincronizado (reset to origin/main)'
        } catch {
            Feedback-FAIL 'Falha ao atualizar repositorio'
            Show-Summary
            exit 1
        }
    }
} elseif (Test-Path $INSTALL_DIR) {
    Feedback-FAIL "${INSTALL_DIR} existe mas nao e um repositorio git"
    Show-Summary
    exit 1
} else {
    try {
        git clone $REPO_URL $INSTALL_DIR 2>$null | Out-Null
        Feedback-OK "Repositorio clonado em ${INSTALL_DIR}"
    } catch {
        Feedback-FAIL 'Falha ao clonar repositorio'
        Show-Summary
        exit 1
    }
}

# =============================================================================
# =============================================================================
#  ETAPA 1/4: SETUP LOCAL
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 1/4: Setup Local ---' -ForegroundColor Cyan
Write-Host ''

# --- Node.js 22+ ---
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$nodeMajor = 0
if ($nodeCmd) {
    $nodeVersionStr = (node --version 2>$null) -replace 'v', ''
    $nodeMajor = [int]($nodeVersionStr -split '\.' | Select-Object -First 1)
}

if ($nodeMajor -ge $NODE_MIN_VERSION) {
    $nodeVersion = $nodeVersionStr
    Write-Host "  Node.js ja instalado (v${nodeVersion})" -ForegroundColor Green
    Write-Log "Node.js v${nodeVersion} ja instalado"
} else {
    if ($wingetAvailable) {
        Write-Host '  Instalando Node.js 22 via winget...' -ForegroundColor Yellow
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements --silent 2>$null
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    }
    if ($nodeCmd) {
        $nodeVersionStr = (node --version 2>$null) -replace 'v', ''
        $nodeMajor = [int]($nodeVersionStr -split '\.' | Select-Object -First 1)
        if ($nodeMajor -ge $NODE_MIN_VERSION) {
            $nodeVersion = $nodeVersionStr
            Write-Host "  Node.js instalado (v${nodeVersion})" -ForegroundColor Green
        } else {
            Write-Host "  Node.js versao ${nodeMajor} insuficiente (requer ${NODE_MIN_VERSION}+)" -ForegroundColor Red
            Write-Host '  Baixe em: https://nodejs.org/' -ForegroundColor Yellow
            Show-Summary
            exit 1
        }
    } else {
        Write-Host '  Falha ao instalar Node.js. Baixe em: https://nodejs.org/' -ForegroundColor Red
        Show-Summary
        exit 1
    }
}

# --- Claude Code CLI ---
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    $claudeVersion = (claude --version 2>$null | Select-Object -First 1) -replace '\s+', ' '
    Write-Host "  Claude Code CLI ja instalado (${claudeVersion})" -ForegroundColor Green
    Write-Log "Claude Code CLI: ${claudeVersion}"
} else {
    Write-Host '  Instalando Claude Code CLI via npm...' -ForegroundColor Yellow
    try {
        npm install -g @anthropic-ai/claude-code 2>$null | Out-Null
        $claudeVersion = (claude --version 2>$null | Select-Object -First 1) -replace '\s+', ' '
        Write-Host "  Claude Code CLI instalado (${claudeVersion})" -ForegroundColor Green
    } catch {
        $claudeVersion = 'not_installed'
        Write-Host '  Falha ao instalar Claude Code CLI' -ForegroundColor Red
        Write-Host '  Tente manualmente: npm install -g @anthropic-ai/claude-code' -ForegroundColor Yellow
    }
}

# --- Tailscale ---
$tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
$tsInstalled = 'false'
$tsStatus = 'not_installed'

if ($tailscaleCmd) {
    $tsInstalled = 'true'
    try {
        $tsJson = tailscale status --json 2>$null | ConvertFrom-Json
        if ($tsJson.BackendState -eq 'Running') {
            $tsStatus = 'connected'
            Write-Host '  Tailscale instalado e conectado' -ForegroundColor Green
        } else {
            $tsStatus = 'disconnected'
            Write-Host "  Tailscale instalado (status: $($tsJson.BackendState))" -ForegroundColor Yellow
        }
    } catch {
        $tsStatus = 'disconnected'
        Write-Host '  Tailscale instalado (status desconhecido)' -ForegroundColor Yellow
    }
} else {
    if ($wingetAvailable) {
        Write-Host '  Instalando Tailscale via winget...' -ForegroundColor Yellow
        winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements --silent 2>$null
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        $tailscaleCmd = Get-Command tailscale -ErrorAction SilentlyContinue
    }
    if ($tailscaleCmd) {
        $tsInstalled = 'true'
        $tsStatus = 'not_connected'
        Write-Host '  Tailscale instalado' -ForegroundColor Green
    } else {
        Write-Host '  Falha ao instalar Tailscale. Baixe em: https://tailscale.com/download/windows' -ForegroundColor Red
    }
}

# --- Salvar state etapa 1 ---
$setupState = @{
    'so_detectado'          = 'windows'
    'git_version'           = if ($gitCmd) { $gitVersion } else { '' }
    'node_version'          = if ($nodeVersion) { $nodeVersion } else { '' }
    'claude_code_version'   = if ($claudeVersion) { $claudeVersion } else { '' }
    'tailscale_installed'   = $tsInstalled
    'tailscale_status'      = $tsStatus
    'setup_date'            = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}
Save-StateFile -FilePath (Join-Path $STATE_DIR 'dados_local_setup') -Data $setupState

Feedback-OK 'Setup local concluido (dependencias instaladas)'

Pause-BetweenSteps

# =============================================================================
# =============================================================================
#  ETAPA 2/4: BRIDGE LOCAL→VPS
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 2/4: Bridge Local→VPS ---' -ForegroundColor Cyan
Write-Host ''

# --- Verificar dependencias bridge ---
if (-not $nodeCmd) {
    Feedback-FAIL 'Node.js nao encontrado (requer v18+)'
    Show-Summary
    exit 1
}

if ($tsInstalled -ne 'true') {
    Write-Host ''
    Write-Host '  Tailscale nao instalado.' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  [1] Baixar e instalar manualmente (abre navegador)'
    Write-Host '  [2] Continuar sem Tailscale (bridge offline)'
    Write-Host ''
    $tsChoice = Read-Input -Prompt 'Opcao' -Default '2'

    if ($tsChoice -eq '1') {
        Start-Process 'https://tailscale.com/download/windows'
        Write-Host '  Apos instalar Tailscale, rode o install.ps1 novamente.' -ForegroundColor Yellow
        Show-Summary
        exit 0
    } else {
        Feedback-SKIP 'Continuando sem Tailscale (bridge offline)'
    }
}

$tailscaleConnected = ($tsStatus -eq 'connected')

# --- Coletar dados ---
$whitelabelFile = Join-Path $STATE_DIR 'dados_whitelabel'
$nomeAgente = Read-StateValue -FilePath $whitelabelFile -Key 'Agente'

if ([string]::IsNullOrWhiteSpace($nomeAgente)) {
    $nomeAgente = Read-Input -Prompt 'Nome do agente' -Required
}

# Hostname Tailscale da VPS — auto-detectar peers se conectado
$vpsHostname = ''
$tailnet = ''

if ($tailscaleConnected) {
    try {
        $tsStatusJson = tailscale status --json 2>$null | ConvertFrom-Json
        $tailnet = $tsStatusJson.MagicDNSSuffix

        # Listar peers online
        $peers = @()
        if ($tsStatusJson.Peer) {
            foreach ($key in $tsStatusJson.Peer.PSObject.Properties) {
                $p = $key.Value
                if ($p.Online -eq $true) {
                    $peerName = if ($p.HostName) { $p.HostName } else { ($p.DNSName -split '\.')[0] }
                    $peerIP = if ($p.TailscaleIPs -and $p.TailscaleIPs.Count -gt 0) { $p.TailscaleIPs[0] } else { '' }
                    $peerOS = if ($p.OS) { $p.OS } else { '' }
                    $peers += [PSCustomObject]@{ Name = $peerName; IP = $peerIP; OS = $peerOS }
                }
            }
        }

        if ($peers.Count -gt 0) {
            Write-Host ''
            Write-Host '  Peers Tailscale online:' -ForegroundColor White
            Write-Host ''
            for ($i = 0; $i -lt $peers.Count; $i++) {
                $p = $peers[$i]
                Write-Host ("    [{0}] {1,-25} {2,-18} {3}" -f ($i+1), $p.Name, $p.IP, $p.OS)
            }
            Write-Host '    [0] Digitar manualmente'
            Write-Host ''

            $peerChoice = Read-Input -Prompt 'Selecione a VPS' -Default '1'

            if ($peerChoice -match '^\d+$') {
                $idx = [int]$peerChoice
                if ($idx -ge 1 -and $idx -le $peers.Count) {
                    $vpsHostname = $peers[$idx - 1].Name
                    Write-Host "  Selecionado: $vpsHostname" -ForegroundColor Green
                }
            }
        }
    } catch { }
}

# Fallback: input manual
if ([string]::IsNullOrWhiteSpace($vpsHostname)) {
    $vpsHostname = Read-Input -Prompt 'Hostname Tailscale da VPS (sem .ts.net)' -Required
    while ($vpsHostname -notmatch '^[a-zA-Z0-9-]+$') {
        Write-Host '  Hostname invalido: apenas letras, numeros e hifens permitidos' -ForegroundColor Red
        $vpsHostname = Read-Input -Prompt 'Hostname Tailscale da VPS (sem .ts.net)' -Required
    }
}

# --- Detectar Tailscale Serve (HTTPS sem porta) ---
$tailscaleServeUrl = ''
$portaGateway = ''

if (-not [string]::IsNullOrWhiteSpace($tailnet)) {
    $tsServeCandidate = "https://${vpsHostname}.${tailnet}"
    Write-Host "  Testando Tailscale Serve (${tsServeCandidate})..."
    try {
        $null = Invoke-WebRequest -Uri "${tsServeCandidate}/health" -TimeoutSec 5 -SkipCertificateCheck -ErrorAction Stop
        $tailscaleServeUrl = $tsServeCandidate
        Write-Host '  Tailscale Serve detectado!' -ForegroundColor Green
    } catch {
        Write-Host '  Tailscale Serve nao respondeu — usando porta direta.' -ForegroundColor Yellow
    }
}

# Montar GATEWAY_URL
if (-not [string]::IsNullOrWhiteSpace($tailscaleServeUrl)) {
    $GATEWAY_URL = $tailscaleServeUrl
    $portaGateway = '443'
} elseif (-not [string]::IsNullOrWhiteSpace($tailnet)) {
    $portaGateway = Read-Input -Prompt 'Porta do gateway OpenClaw' -Default '18789'
    $GATEWAY_URL = "http://${vpsHostname}.${tailnet}:${portaGateway}"
} else {
    Write-Host ''
    Write-Host '  Nao foi possivel detectar o tailnet automaticamente.' -ForegroundColor Yellow
    $fqdnCompleto = Read-Input -Prompt 'FQDN completo da VPS (ex: meu-vps.tailnet-name.ts.net)' -Required

    while ($fqdnCompleto -notmatch '^[a-zA-Z0-9-]+\..+\.ts\.net$') {
        Write-Host '  Formato invalido. Esperado: hostname.tailnet-name.ts.net' -ForegroundColor Red
        $fqdnCompleto = Read-Input -Prompt 'FQDN completo da VPS' -Required
    }
    $portaGateway = Read-Input -Prompt 'Porta do gateway OpenClaw' -Default '18789'
    $GATEWAY_URL = "http://${fqdnCompleto}:${portaGateway}"
    $tailnet = $fqdnCompleto -replace "^${vpsHostname}\.", ''
}

# --- Confirmar informacoes ---
Write-Host ''
Write-Host '  Confirmacao:' -ForegroundColor White
Write-Host "    Agente:       $nomeAgente"
Write-Host "    VPS Hostname: $vpsHostname"
Write-Host "    Tailnet:      $(if ($tailnet) { $tailnet } else { 'nao detectado' })"
Write-Host "    Gateway URL:  $GATEWAY_URL"
Write-Host "    Tailscale:    $tailscaleConnected"
Write-Host ''
$confirma = Read-Host 'As informacoes estao corretas? (s/n)'
if ($confirma -notmatch '^[Ss]$') {
    Write-Host 'Cancelado pelo usuario.'
    exit 0
}

# --- Verificar conectividade Tailscale ---
if ($tailscaleConnected) {
    Write-Host ''
    Write-Host '  Verificando conectividade Tailscale...'
    try {
        $pingResult = tailscale ping --timeout 30s -c 1 $vpsHostname 2>$null
        Write-Host "  Tailscale ping para '${vpsHostname}' OK" -ForegroundColor Green
    } catch {
        Write-Host "  Tailscale ping para '${vpsHostname}' falhou" -ForegroundColor Red
        Write-Host '  Dica: Se firewall corporativo bloqueia UDP, Tailscale usa DERP relay (HTTPS).' -ForegroundColor Yellow
    }

    # Health check do gateway
    Write-Host '  Verificando saude do gateway remoto...'
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $healthResponse = Invoke-RestMethod -Uri "${GATEWAY_URL}/health" -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
        $sw.Stop()
        Write-Host "  Gateway remoto respondeu ($($sw.ElapsedMilliseconds)ms)" -ForegroundColor Green
    } catch {
        Write-Host '  Gateway remoto nao respondeu (pode estar offline — bridge sera configurada mesmo assim)' -ForegroundColor Yellow
    }
} else {
    Write-Host '  Tailscale ping — Tailscale offline (skip)' -ForegroundColor Yellow
    Write-Host '  Gateway health — Tailscale offline (skip)' -ForegroundColor Yellow
}

# --- Criar Service Index ---
$servicesDir = Join-Path $INSTALL_DIR '.aios-core' 'infrastructure' 'services'
$agentServiceDir = Join-Path $servicesDir $nomeAgente

# Limpar servicos antigos (manter apenas o agente atual)
if (Test-Path $servicesDir) {
    Get-ChildItem -Path $servicesDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -ne $nomeAgente) {
            Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Servico antigo removido: $($_.Name)"
        }
    }
}

if (-not (Test-Path $agentServiceDir)) {
    New-Item -ItemType Directory -Path $agentServiceDir -Force | Out-Null
}

$serviceIndex = @"
'use strict';

// Service: ${nomeAgente} — OpenClaw Gateway Health Check (Local→VPS via Tailscale)
// Generated by Legendsclaw Deployer (install.ps1)

const http = require('http');
const https = require('https');

const GATEWAY_URL = process.env.OPENCLAW_GATEWAY_URL
  || process.env.AGENT_GATEWAY_URL
  || '${GATEWAY_URL}';

const DEGRADED_THRESHOLD_MS = 2000;

module.exports = {
  name: '${nomeAgente}',
  description: 'OpenClaw Gateway health for ${nomeAgente}',

  health: async () => {
    const url = new URL(GATEWAY_URL + '/health');
    const mod = url.protocol === 'https:' ? https : http;

    const start = Date.now();

    return new Promise((resolve) => {
      const req = mod.get(url, { timeout: 5000, rejectUnauthorized: false }, (res) => {
        const latency_ms = Date.now() - start;
        let body = '';
        res.on('data', (chunk) => { body += chunk; });
        res.on('end', () => {
          if (res.statusCode === 200) {
            const status = latency_ms > DEGRADED_THRESHOLD_MS ? 'degraded' : 'ok';
            resolve({ status, latency_ms, details: body.slice(0, 100) });
          } else {
            resolve({ status: 'down', latency_ms, details: 'HTTP ' + res.statusCode });
          }
        });
      });

      req.on('error', (err) => {
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: err.message });
      });

      req.on('timeout', () => {
        req.destroy();
        const latency_ms = Date.now() - start;
        resolve({ status: 'down', latency_ms, error: 'timeout' });
      });
    });
  },
};
"@

Set-Content -Path (Join-Path $agentServiceDir 'index.js') -Value $serviceIndex -Encoding UTF8
Write-Host "  Service index criado: $agentServiceDir\index.js" -ForegroundColor Green

# --- Criar Session Check Script (Story 12.3) ---
$sessionCheckFile = Join-Path $servicesDir 'session-check.ps1'

$sessionCheckContent = @"
# Session check — Tailscale, Gateway, OpenClaw config, Bridge services
# Generated by install.ps1 (Story 12.3)

# 1. Tailscale
`$TS = 'offline'
try {
    `$tsJson = tailscale status --json 2>`$null | ConvertFrom-Json
    if (`$tsJson.BackendState -eq 'Running') { `$TS = 'OK' }
} catch { }

# 2. Gateway health
`$GW = 'offline'
try {
    `$null = Invoke-WebRequest -Uri '${GATEWAY_URL}/health' -TimeoutSec 5 -SkipCertificateCheck -ErrorAction Stop
    `$GW = 'OK'
} catch { }

# 3. OpenClaw config
`$OC = 'not configured'
`$ocFile = Join-Path `$HOME '.openclaw' 'openclaw.json'
if (Test-Path `$ocFile) {
    try {
        `$ocJson = Get-Content `$ocFile -Raw | ConvertFrom-Json
        if (`$ocJson.gateway.mode) { `$OC = `$ocJson.gateway.mode }
    } catch { }
}

# 4. Bridge services
`$svcCount = 0
try {
    `$listOut = node .aios-core/infrastructure/services/bridge.js list 2>`$null
    `$svcCount = (`$listOut | Where-Object { `$_ -match '^\s+[a-z]' }).Count
} catch { }

Write-Output "[Bridge] Tailscale: `$TS | Gateway: `$GW | OpenClaw: `$OC | Services: `$svcCount"
"@

Set-Content -Path $sessionCheckFile -Value $sessionCheckContent -Encoding UTF8
Write-Host "  Session check criado: $sessionCheckFile" -ForegroundColor Green

# --- Configurar Claude Code Hooks ---
$settingsFile = Join-Path $INSTALL_DIR '.claude' 'settings.json'

# Hooks no formato real do settings.json — usa session-check.ps1 no SessionStart
$hooksObj = @{
    'SessionStart' = @(
        @{
            hooks = @(
                @{
                    type    = 'command'
                    command = "powershell -ExecutionPolicy Bypass -File .aios-core/infrastructure/services/session-check.ps1 2>`$null || echo '[Bridge] Session check unavailable'"
                }
            )
        }
    )
    'PreToolUse' = @(
        @{
            matcher = 'Bash'
            hooks   = @(
                @{
                    type    = 'command'
                    command = 'node .aios-core/infrastructure/services/bridge.js validate-call 2>$null || echo ""'
                }
            )
        }
    )
    'PostToolUse' = @(
        @{
            matcher = 'Bash'
            hooks   = @(
                @{
                    type    = 'command'
                    command = 'node .aios-core/infrastructure/services/bridge.js log-execution 2>$null || echo ""'
                }
            )
        }
    )
}

if (Test-Path $settingsFile) {
    $settingsContent = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
    if ($settingsContent -match 'bridge\.js|session-check') {
        Write-Host "  Hooks ja configurados em $settingsFile" -ForegroundColor Yellow
    } else {
        # Backup
        Copy-Item $settingsFile "${settingsFile}.bak" -Force
        Write-Host "  Backup criado: ${settingsFile}.bak"

        # Merge hooks
        $settings = $settingsContent | ConvertFrom-Json
        $settings | Add-Member -MemberType NoteProperty -Name 'hooks' -Value $hooksObj -Force
        $settings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Encoding UTF8
        Write-Host "  Hooks configurados em $settingsFile (backup em .bak)" -ForegroundColor Green
    }
} else {
    # Criar novo settings.json
    $settingsDir = Split-Path $settingsFile -Parent
    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }
    $newSettings = @{
        language = 'portuguese'
        hooks    = $hooksObj
    }
    $newSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Encoding UTF8
    Write-Host "  Hooks configurados em $settingsFile (novo arquivo)" -ForegroundColor Green
}

# --- Verificar bridge.js ---
$bridgeFile = Join-Path $servicesDir 'bridge.js'
if (-not (Test-Path $bridgeFile)) {
    Write-Host "  bridge.js nao encontrado em $bridgeFile" -ForegroundColor Red
    Write-Host '  Verifique se o repositorio foi clonado corretamente.' -ForegroundColor Yellow
} else {
    Write-Host '  Testando bridge.js...'
    try {
        $listOutput = node $bridgeFile list 2>$null
        Write-Host '  bridge.js list funcional' -ForegroundColor Green
    } catch {
        Write-Host '  bridge.js list falhou' -ForegroundColor Red
    }
    try {
        $statusOutput = node $bridgeFile status 2>$null
        Write-Host '  bridge.js status funcional' -ForegroundColor Green
    } catch {
        Write-Host '  bridge.js status executou (gateway pode estar offline — normal)' -ForegroundColor Yellow
    }
}

# --- Salvar state bridge ---
$servicesCount = 0
try {
    $listOut = node $bridgeFile list 2>$null
    $servicesCount = ($listOut | Where-Object { $_ -match '^\s+[a-z]' }).Count
} catch { }

$bridgeState = @{
    'Agente'              = $nomeAgente
    'Gateway URL'         = $GATEWAY_URL
    'Bridge Status'       = 'configurado'
    'Hooks Configured'    = 'true'
    'Services Count'      = $servicesCount.ToString()
    'Tailscale'           = $tailscaleConnected.ToString().ToLower()
    'Tailscale Hostname'  = $vpsHostname
    'Tailscale Tailnet'   = if ($tailnet) { $tailnet } else { 'nao detectado' }
    'Bridge Mode'         = 'local-to-vps'
    'Bridge File'         = $bridgeFile
    'Settings File'       = $settingsFile
    'Service Dir'         = $agentServiceDir
    'Data Configuracao'   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}
Save-StateFile -FilePath (Join-Path $STATE_DIR 'dados_bridge') -Data $bridgeState

Feedback-OK 'Bridge configurado com sucesso'

Pause-BetweenSteps

# =============================================================================
# =============================================================================
#  ETAPA 3/4: OPENCLAW REMOTE (mode:remote via WSS/Tailscale)
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 3/4: OpenClaw Remote ---' -ForegroundColor Cyan
Write-Host ''

$openclawDir = Join-Path $HOME '.openclaw'
$openclawConfig = Join-Path $openclawDir 'openclaw.json'

# --- Idempotencia: skip se ja configurado ---
$skipOpenclaw = $false
if ((Test-Path $openclawConfig) -and (Test-Path (Join-Path $STATE_DIR 'dados_local_openclaw'))) {
    try {
        $existingConfig = Get-Content $openclawConfig -Raw | ConvertFrom-Json
        if ($existingConfig.gateway.mode -eq 'remote') {
            Feedback-SKIP "OpenClaw ja configurado em mode:remote (${openclawConfig})"
            Write-Host "  Para reconfigurar, remova: Remove-Item ${openclawConfig}" -ForegroundColor Yellow
            $skipOpenclaw = $true
        }
    } catch { }
}

if (-not $skipOpenclaw) {
    # --- Coletar dados para OpenClaw ---
    # Ler gateway password do dados_gateway ou perguntar
    $gatewayPassword = ''
    $gatewayStateFile = Join-Path $STATE_DIR 'dados_gateway'
    if (Test-Path $gatewayStateFile) {
        $gatewayPassword = Read-StateValue -FilePath $gatewayStateFile -Key 'Gateway Password'
    }
    if ([string]::IsNullOrWhiteSpace($gatewayPassword)) {
        $gatewayPassword = Read-Input -Prompt 'Password do gateway (WSS auth)' -Required -Secret
    }

    # Montar WSS URL
    if (-not [string]::IsNullOrWhiteSpace($tailnet)) {
        $wssUrl = "wss://${vpsHostname}.${tailnet}"
    } else {
        # Fallback: tentar construir a partir do GATEWAY_URL
        $wssUrl = "wss://${vpsHostname}.${tailnet}"
        if ([string]::IsNullOrWhiteSpace($tailnet)) {
            Write-Host '  Tailnet nao detectado — insira o FQDN para o WSS URL.' -ForegroundColor Yellow
            $wssFqdn = Read-Input -Prompt 'FQDN completo para WSS (ex: meu-vps.tailnet.ts.net)' -Required
            $wssUrl = "wss://${wssFqdn}"
        }
    }

    Write-Host ''
    Write-Host "  WSS URL: $wssUrl" -ForegroundColor White
    Write-Host ''

    # --- Instalar/verificar OpenClaw CLI ---
    $openclawVersion = 'unknown'
    $openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($openclawCmd) {
        $openclawVersion = (openclaw --version 2>$null | Select-Object -First 1) -replace '\s+', ' '
        Write-Host "  OpenClaw CLI ja instalado (${openclawVersion})" -ForegroundColor Green
    } else {
        Write-Host '  Instalando OpenClaw CLI via npm...' -ForegroundColor Yellow
        try {
            npm install -g openclaw 2>$null | Out-Null
            $openclawCmd = Get-Command openclaw -ErrorAction SilentlyContinue
            if ($openclawCmd) {
                $openclawVersion = (openclaw --version 2>$null | Select-Object -First 1) -replace '\s+', ' '
                Write-Host "  OpenClaw CLI instalado (${openclawVersion})" -ForegroundColor Green
            } else {
                Write-Host '  OpenClaw CLI nao instalado — config sera gerado mesmo assim' -ForegroundColor Yellow
                Write-Host '  Instale manualmente: npm install -g openclaw' -ForegroundColor Yellow
            }
        } catch {
            Write-Host '  OpenClaw CLI nao instalado — config sera gerado mesmo assim' -ForegroundColor Yellow
            Write-Host '  Instale manualmente: npm install -g openclaw' -ForegroundColor Yellow
        }
    }

    # --- Criar ~/.openclaw/ e gerar openclaw.json ---
    if (-not (Test-Path $openclawDir)) {
        New-Item -ItemType Directory -Path $openclawDir -Force | Out-Null
    }

    # Backup se existente
    if (Test-Path $openclawConfig) {
        Copy-Item $openclawConfig "${openclawConfig}.bak" -Force
        Write-Host "  Backup criado: ${openclawConfig}.bak"
    }

    $openclawWorkspace = Join-Path $openclawDir 'workspace'
    $openclawJsonContent = @{
        gateway = @{
            mode   = 'remote'
            remote = @{
                url      = $wssUrl
                password = $gatewayPassword
            }
        }
        agents = @{
            defaults = @{
                model     = @{ primary = 'openrouter/auto' }
                workspace = $openclawWorkspace
            }
        }
    }

    $openclawJsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $openclawConfig -Encoding UTF8
    Write-Host "  Config gerado: ${openclawConfig} (mode:remote)" -ForegroundColor Green

    # --- Testar conexao WSS (via HTTPS health check) ---
    $wssTest = 'SKIP'
    $httpsUrl = "https://${vpsHostname}.${tailnet}"
    Write-Host ''
    Write-Host "  Testando conexao ao gateway (${httpsUrl}/health)..."

    try {
        $null = Invoke-WebRequest -Uri "${httpsUrl}/health" -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
        $wssTest = 'OK'
        Write-Host '  Gateway remoto respondeu — WSS deve funcionar' -ForegroundColor Green
    } catch {
        # Tentar HTTP direto se Tailscale Serve nao ativo
        try {
            $null = Invoke-WebRequest -Uri "${GATEWAY_URL}/health" -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
            $wssTest = 'OK'
            Write-Host '  Gateway remoto respondeu via HTTP direto' -ForegroundColor Green
        } catch {
            $wssTest = 'FAIL'
            Write-Host '  Gateway nao respondeu (pode estar offline — config salvo mesmo assim)' -ForegroundColor Yellow
            Write-Host "  Teste manual: Invoke-WebRequest ${httpsUrl}/health" -ForegroundColor Yellow
        }
    }

    # --- Salvar state OpenClaw ---
    $openclawState = @{
        'OpenClaw Version'  = $openclawVersion
        'Config Path'       = $openclawConfig
        'Gateway Mode'      = 'remote'
        'Gateway URL'       = $wssUrl
        'WSS Test'          = $wssTest
        'Agente'            = $nomeAgente
        'Data Configuracao' = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    Save-StateFile -FilePath (Join-Path $STATE_DIR 'dados_local_openclaw') -Data $openclawState

    Feedback-OK 'OpenClaw configurado em mode:remote'
}

Pause-BetweenSteps

# =============================================================================
# =============================================================================
#  ETAPA 4/4: AIOS INIT + REGISTRO DE AGENTE
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 4/4: AIOS Init ---' -ForegroundColor Cyan
Write-Host ''

# --- Verificar Node.js / npm ---
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    Feedback-FAIL 'npm nao encontrado'
    Show-Summary
    exit 1
}

# --- Coletar dados do projeto ---
$defaultProjName = Split-Path $INSTALL_DIR -Leaf
$nomeProjeto = Read-Input -Prompt 'Nome do projeto' -Default $defaultProjName
$dirDestino = Read-Input -Prompt 'Diretorio destino' -Default $INSTALL_DIR

if (-not (Test-Path $dirDestino)) {
    $criarDir = Read-Host "Diretorio '${dirDestino}' nao existe. Criar? (s/n)"
    if ($criarDir -match '^[Ss]$') {
        New-Item -ItemType Directory -Path $dirDestino -Force | Out-Null
    } else {
        Write-Host 'Cancelado pelo usuario.'
        exit 0
    }
}

Write-Host ''
Write-Host '  Confirmacao:' -ForegroundColor White
Write-Host "    Projeto:    $nomeProjeto"
Write-Host "    Diretorio:  $dirDestino"
Write-Host ''
$confirma = Read-Host 'As informacoes estao corretas? (s/n)'
if ($confirma -notmatch '^[Ss]$') {
    Write-Host 'Cancelado pelo usuario.'
    exit 0
}

# --- npx aios-core init ---
$aiosDir = Join-Path $dirDestino '.aios-core'

if (Test-Path $aiosDir) {
    Write-Host "  AIOS ja inicializado em $dirDestino" -ForegroundColor Yellow
} else {
    Write-Host ''
    Write-Host "  Executando npx aios-core init ${nomeProjeto}..."
    Write-Host '  (isto pode demorar na primeira execucao)'
    Write-Host ''

    $prevDir = Get-Location
    try {
        Set-Location $dirDestino
        $initOutput = npx aios-core init $nomeProjeto 2>&1
        $initExit = $LASTEXITCODE
    } finally {
        Set-Location $prevDir
    }

    if ($initExit -ne 0) {
        Write-Host "  npx aios-core init falhou (exit code: ${initExit})" -ForegroundColor Red
        Write-Host "  Output: $initOutput" -ForegroundColor Yellow
        Write-Host ''
        Write-Host '  Tente manualmente:' -ForegroundColor Yellow
        Write-Host "    cd $dirDestino" -ForegroundColor Yellow
        Write-Host "    npx aios-core init $nomeProjeto" -ForegroundColor Yellow
        Feedback-FAIL 'npx aios-core init falhou'
        Show-Summary
        exit 1
    }

    if (-not (Test-Path $aiosDir)) {
        Write-Host '  .aios-core/ nao encontrado apos init' -ForegroundColor Red
        Feedback-FAIL '.aios-core/ nao criado'
        Show-Summary
        exit 1
    }
    Write-Host "  AIOS inicializado em $dirDestino" -ForegroundColor Green
}

# --- Ler dados whitelabel ---
$displayName = ''
$icone = ''
$persona = ''
$idioma = ''

if (Test-Path $whitelabelFile) {
    if ([string]::IsNullOrWhiteSpace($nomeAgente)) {
        $nomeAgente = Read-StateValue -FilePath $whitelabelFile -Key 'Agente'
    }
    $displayName = Read-StateValue -FilePath $whitelabelFile -Key 'Display Name'
    $icone = Read-StateValue -FilePath $whitelabelFile -Key 'Icone'
    $persona = Read-StateValue -FilePath $whitelabelFile -Key 'Persona'
    $idioma = Read-StateValue -FilePath $whitelabelFile -Key 'Idioma'
    Write-Host '  Dados do agente carregados de dados_whitelabel' -ForegroundColor Green
} else {
    # Fallback: reusar nome do agente do bridge (evita pedir 2x)
    $bridgeStateFile = Join-Path $STATE_DIR 'dados_bridge'
    if ([string]::IsNullOrWhiteSpace($nomeAgente) -and (Test-Path $bridgeStateFile)) {
        $nomeAgente = Read-StateValue -FilePath $bridgeStateFile -Key 'Agente'
        if (-not [string]::IsNullOrWhiteSpace($nomeAgente)) {
            Write-Host "  Nome do agente recuperado do bridge: $nomeAgente" -ForegroundColor Green
        }
    }

    if ([string]::IsNullOrWhiteSpace($nomeAgente)) {
        Write-Host ''
        Write-Host '  dados_whitelabel nao encontrado — coleta interativa' -ForegroundColor Yellow
        Write-Host ''
        $nomeAgente = Read-Input -Prompt 'Nome tecnico do agente (kebab-case, ex: jarvis)' -Default 'meu-agente'
    }
    while ($nomeAgente -notmatch '^[a-z][a-z0-9-]*$') {
        Write-Host '  Nome invalido: use kebab-case (a-z, 0-9, hifens, comecando com letra)' -ForegroundColor Red
        $nomeAgente = Read-Input -Prompt 'Nome tecnico do agente' -Default 'meu-agente'
    }

    $displayNameDefault = (Get-Culture).TextInfo.ToTitleCase($nomeAgente -replace '-', ' ')
    $displayName = Read-Input -Prompt 'Display name' -Default $displayNameDefault
    $icone = Read-Input -Prompt 'Icone/emoji' -Default '🤖'
    $persona = Read-Input -Prompt 'Persona/descricao curta' -Default 'Assistente IA especializado'
    $idioma = Read-Input -Prompt 'Idioma' -Default 'pt-br'
}

# --- Ler skills ---
$skillsFile = Join-Path $STATE_DIR 'dados_skills'
$skillsArray = @()
$skillsCount = 0

if (Test-Path $skillsFile) {
    $skillsLine = Read-StateValue -FilePath $skillsFile -Key 'Skills Ativas'
    if (-not [string]::IsNullOrWhiteSpace($skillsLine)) {
        $skillsArray = ($skillsLine -split '[,\s]+') | Where-Object { $_ -ne '' }
        $skillsCount = $skillsArray.Count
        Write-Host "  ${skillsCount} skills mapeadas como commands" -ForegroundColor Green
    } else {
        Write-Host '  dados_skills sem skills ativas — commands basicos' -ForegroundColor Yellow
    }
} else {
    Write-Host '  Sem dados_skills — commands basicos (help, status, chat)' -ForegroundColor Yellow
}

# --- Gerar arquivo de definicao do agente ---
$agentsDir = Join-Path $dirDestino '.aios-core' 'development' 'agents'
$agentFile = Join-Path $agentsDir "${nomeAgente}.md"

if (-not (Test-Path $agentsDir)) {
    New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
}

if (Test-Path $agentFile) {
    Copy-Item $agentFile "${agentFile}.bak" -Force
    Write-Host "  Backup criado: ${agentFile}.bak"
}

# Montar commands YAML
$commandsYaml = @"
  - name: help
    visibility: [full, quick, key]
    description: 'Show all available commands with descriptions'
  - name: status
    visibility: [full, quick, key]
    description: 'Show current agent status and health'
  - name: chat
    visibility: [full, quick, key]
    description: 'Start a conversation with the agent'
"@

foreach ($skill in $skillsArray) {
    $skill = $skill.Trim()
    if ([string]::IsNullOrWhiteSpace($skill)) { continue }
    $commandsYaml += "`n  - name: ${skill}`n    visibility: [full, quick]`n    description: 'Execute ${skill} skill'"
}

# Montar dependencies tools
$depsTools = '    - git'
foreach ($skill in $skillsArray) {
    $skill = $skill.Trim()
    if ([string]::IsNullOrWhiteSpace($skill)) { continue }
    $depsTools += "`n    - ${skill}"
}

# Quick commands markdown
$quickCommands = @"
- ``*help`` - Show all available commands
- ``*status`` - Show agent status
- ``*chat`` - Start conversation
"@

foreach ($skill in $skillsArray) {
    $skill = $skill.Trim()
    if ([string]::IsNullOrWhiteSpace($skill)) { continue }
    $quickCommands += "`n- ``*${skill}`` - Execute ${skill}"
}

$dateNow = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$agentDefinition = @"
# ${nomeAgente}

ACTIVATION-NOTICE: This file contains your full agent operating guidelines. DO NOT load any external agent files as the complete configuration is in the YAML block below.

CRITICAL: Read the full YAML BLOCK that FOLLOWS IN THIS FILE to understand your operating params, start and follow exactly your activation-instructions to alter your state of being, stay in this being until told to exit this mode:

## COMPLETE AGENT DEFINITION FOLLOWS - NO EXTERNAL FILES NEEDED

``````yaml
activation-instructions:
  - STEP 1: Read THIS ENTIRE FILE - it contains your complete persona definition
  - STEP 2: Adopt the persona defined in the 'agent' and 'persona' sections below
  - STEP 3: Display greeting and HALT to await user input
  - STAY IN CHARACTER!
agent:
  name: ${displayName}
  id: ${nomeAgente}
  title: ${displayName} Agent
  icon: ${icone}
  whenToUse: |
    ${persona}
  customization: null

persona_profile:
  archetype: Assistant
  communication:
    tone: professional
    emoji_frequency: medium
    vocabulary:
      - ajudar
      - resolver
      - executar
      - analisar
      - otimizar
    greeting_levels:
      minimal: '${icone} ${nomeAgente} Agent ready'
      named: '${icone} ${displayName} ready!'
      archetypal: '${icone} ${displayName} the Assistant ready!'
    signature_closing: '— ${displayName} ${icone}'

persona:
  role: ${persona}
  style: Professional, helpful, precise
  identity: AI assistant specialized in helping users
  focus: Executing user requests with precision and clarity

commands:
${commandsYaml}

dependencies:
  tools:
${depsTools}

autoClaude:
  version: '3.0'
``````

---

## Quick Commands

${quickCommands}

Type ``*help`` to see all commands.

---

*Generated by Legendsclaw Deployer (install.ps1) — ${dateNow}*
"@

Set-Content -Path $agentFile -Value $agentDefinition -Encoding UTF8
Write-Host "  Agente '${nomeAgente}' registrado em $agentFile" -ForegroundColor Green

# --- Copiar bridge + hooks + agent command pro projeto AIOS ---
$bridgeSrc = Join-Path $INSTALL_DIR '.aios-core' 'infrastructure' 'services'
$bridgeDst = Join-Path $dirDestino '.aios-core' 'infrastructure' 'services'
$settingsSrc = Join-Path $INSTALL_DIR '.claude' 'settings.json'
$settingsDst = Join-Path $dirDestino '.claude' 'settings.json'

$bridgeCopied = 0

# Copiar bridge.js
$bridgeSrcFile = Join-Path $bridgeSrc 'bridge.js'
if (Test-Path $bridgeSrcFile) {
    if (-not (Test-Path $bridgeDst)) { New-Item -ItemType Directory -Path $bridgeDst -Force | Out-Null }
    Copy-Item $bridgeSrcFile (Join-Path $bridgeDst 'bridge.js') -Force
    $bridgeCopied++
}

# Copiar service index do agente
$agentSvcSrc = Join-Path $bridgeSrc $nomeAgente
if (Test-Path $agentSvcSrc) {
    $agentSvcDst = Join-Path $bridgeDst $nomeAgente
    if (-not (Test-Path $agentSvcDst)) { New-Item -ItemType Directory -Path $agentSvcDst -Force | Out-Null }
    Copy-Item (Join-Path $agentSvcSrc '*') $agentSvcDst -Recurse -Force
    $bridgeCopied++
}

# Copiar session-check.ps1
$sessionCheckSrc = Join-Path $bridgeSrc 'session-check.ps1'
if (Test-Path $sessionCheckSrc) {
    Copy-Item $sessionCheckSrc (Join-Path $bridgeDst 'session-check.ps1') -Force
    $bridgeCopied++
}

# Copiar .claude/settings.json (hooks)
if (Test-Path $settingsSrc) {
    $settingsDstDir = Split-Path $settingsDst -Parent
    if (-not (Test-Path $settingsDstDir)) { New-Item -ItemType Directory -Path $settingsDstDir -Force | Out-Null }
    if (Test-Path $settingsDst) {
        # Merge: copiar hooks do source pro destino
        try {
            $srcJson = Get-Content $settingsSrc -Raw | ConvertFrom-Json
            $dstJson = Get-Content $settingsDst -Raw | ConvertFrom-Json
            $dstJson | Add-Member -MemberType NoteProperty -Name 'hooks' -Value $srcJson.hooks -Force
            $dstJson | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsDst -Encoding UTF8
        } catch {
            Copy-Item $settingsSrc $settingsDst -Force
        }
    } else {
        Copy-Item $settingsSrc $settingsDst -Force
    }
    $bridgeCopied++
}

# Registrar agente como Claude Code command (skill invocavel)
$commandsDst = Join-Path $dirDestino '.claude' 'commands' 'AIOS' 'agents'
if (-not (Test-Path $commandsDst)) { New-Item -ItemType Directory -Path $commandsDst -Force | Out-Null }
if (Test-Path $agentFile) {
    Copy-Item $agentFile (Join-Path $commandsDst "${nomeAgente}.md") -Force
    $bridgeCopied++
}

if ($bridgeCopied -gt 0) {
    Write-Host "  Bridge + hooks + agent command copiados para ${dirDestino} (${bridgeCopied} itens)" -ForegroundColor Green
} else {
    Write-Host '  Bridge nao encontrado no repo — configure manualmente com setup-local-bridge' -ForegroundColor Yellow
}

# --- Salvar state etapa 4 ---
$allCommands = 'help,status,chat'
foreach ($skill in $skillsArray) {
    $skill = $skill.Trim()
    if ([string]::IsNullOrWhiteSpace($skill)) { continue }
    $allCommands += ",${skill}"
}

$aiosState = @{
    'Projeto'             = $nomeProjeto
    'Diretorio'           = $dirDestino
    'AIOS Inicializado'   = 'true'
    'Agente Registrado'   = $nomeAgente
    'Display Name'        = $displayName
    'Icone'               = $icone
    'Idioma'              = $idioma
    'Commands'            = $allCommands
    'Skills Mapeadas'     = $skillsCount.ToString()
    'Agent File'          = ".aios-core/development/agents/${nomeAgente}.md"
    'Data Configuracao'   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
}
Save-StateFile -FilePath (Join-Path $STATE_DIR 'dados_aios_init') -Data $aiosState

Feedback-OK 'AIOS inicializado e agente registrado'

# =============================================================================
# RESULTADO FINAL
# =============================================================================

# Ler dados finais dos state files
$finalAgentName = Read-StateValue -FilePath (Join-Path $STATE_DIR 'dados_bridge') -Key 'Agente'
if ([string]::IsNullOrWhiteSpace($finalAgentName)) { $finalAgentName = $nomeAgente }
$finalAiosDir = Read-StateValue -FilePath (Join-Path $STATE_DIR 'dados_aios_init') -Key 'Diretorio'
if ([string]::IsNullOrWhiteSpace($finalAiosDir)) { $finalAiosDir = $INSTALL_DIR }

Write-Host ''
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host '  SETUP LOCAL CONCLUIDO!' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Seu ambiente local esta pronto.'
Write-Host "  Para ativar o agente no Claude Code:"
Write-Host "  cd $finalAiosDir && @${finalAgentName}" -ForegroundColor White
Write-Host ''
Write-Host '  Para verificar o bridge:'
Write-Host "  cd $finalAiosDir && node .aios-core\infrastructure\services\bridge.js status" -ForegroundColor White
Write-Host ''
Write-Host '  Para verificar o OpenClaw:'
Write-Host "  openclaw status" -ForegroundColor White
Write-Host ''

Feedback-OK 'Instrucoes exibidas'

Show-Summary
Write-Log '=== Instalacao finalizada ==='
