#Requires -Version 5.1
<#
.SYNOPSIS
    Legendsclaw Installer — Windows nativo (PowerShell)
.DESCRIPTION
    Equivalente ao install.sh --local para Windows.
    Executa 3 etapas: Setup Local, Bridge Local→VPS, AIOS Init.
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

$INSTALL_VERSION = '1.1.0'
$REPO_URL = 'https://github.com/tallessouza/legendsclaw-deployer.git'
$TIMESTAMP = Get-Date -Format 'yyyyMMdd_HHmmss'
$LOG_DIR = Join-Path $HOME 'legendsclaw-logs'
$LOG_FILE = Join-Path $LOG_DIR "install-${TIMESTAMP}.log"
$INSTALL_DIR = Join-Path $HOME 'legendsclaw'
$STATE_DIR = Join-Path $HOME 'dados_vps'
$NODE_MIN_VERSION = 22
$TOTAL_STEPS = 10

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
        [switch]$Required
    )
    $display = if ($Default) { "$Prompt[$Default]: " } else { "${Prompt}: " }
    $value = Read-Host $display
    if ([string]::IsNullOrWhiteSpace($value)) { $value = $Default }
    if ($Required -and [string]::IsNullOrWhiteSpace($value)) {
        while ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host '  Valor obrigatorio.' -ForegroundColor Red
            $value = Read-Host $display
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
#  ETAPA 1/3: SETUP LOCAL
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 1/3: Setup Local ---' -ForegroundColor Cyan
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
        winget install --id tailscale.tailscale -e --accept-source-agreements --accept-package-agreements --silent 2>$null
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

# =============================================================================
# =============================================================================
#  ETAPA 2/3: BRIDGE LOCAL→VPS
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 2/3: Bridge Local→VPS ---' -ForegroundColor Cyan
Write-Host ''

# --- Verificar dependencias bridge ---
if (-not $nodeCmd) {
    Feedback-FAIL 'Node.js nao encontrado (requer v18+)'
    Show-Summary
    exit 1
}

if ($tsInstalled -ne 'true') {
    Feedback-FAIL 'Tailscale nao instalado'
    Write-Host '  Execute primeiro a etapa 1 ou instale Tailscale manualmente.' -ForegroundColor Yellow
    Show-Summary
    exit 1
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

$portaGateway = Read-Input -Prompt 'Porta do gateway OpenClaw' -Default '18789'

# Montar GATEWAY_URL
if (-not [string]::IsNullOrWhiteSpace($tailnet)) {
    $GATEWAY_URL = "http://${vpsHostname}.${tailnet}:${portaGateway}"
} else {
    Write-Host ''
    Write-Host '  Nao foi possivel detectar o tailnet automaticamente.' -ForegroundColor Yellow
    $fqdnCompleto = Read-Input -Prompt 'FQDN completo da VPS (ex: meu-vps.tailnet-name.ts.net)' -Required

    while ($fqdnCompleto -notmatch '^[a-zA-Z0-9-]+\..+\.ts\.net$') {
        Write-Host '  Formato invalido. Esperado: hostname.tailnet-name.ts.net' -ForegroundColor Red
        $fqdnCompleto = Read-Input -Prompt 'FQDN completo da VPS' -Required
    }
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
        $healthResponse = Invoke-RestMethod -Uri "${GATEWAY_URL}/health" -TimeoutSec 10 -ErrorAction Stop
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
      const req = mod.get(url, { timeout: 5000 }, (res) => {
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

# --- Configurar Claude Code Hooks ---
$settingsFile = Join-Path $INSTALL_DIR '.claude' 'settings.json'

# Hooks no formato real do settings.json (com matcher + hooks aninhados)
$hooksObj = @{
    'SessionStart' = @(
        @{
            hooks = @(
                @{
                    type    = 'command'
                    command = "node .aios-core/infrastructure/services/bridge.js status 2>/dev/null || echo '[Bridge] Offline — VPN may be disconnected'"
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
                    command = 'node .aios-core/infrastructure/services/bridge.js validate-call 2>/dev/null || true'
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
                    command = 'node .aios-core/infrastructure/services/bridge.js log-execution 2>/dev/null || true'
                }
            )
        }
    )
}

if (Test-Path $settingsFile) {
    $settingsContent = Get-Content $settingsFile -Raw -ErrorAction SilentlyContinue
    if ($settingsContent -match 'bridge\.js') {
        Write-Host "  Hooks ja configurados em $settingsFile" -ForegroundColor Yellow
    } else {
        # Backup
        Copy-Item $settingsFile "${settingsFile}.bak" -Force
        Write-Host "  Backup criado: ${settingsFile}.bak"

        # Merge hooks
        $settings = $settingsContent | ConvertFrom-Json
        # Remover hooks antigo se existir e adicionar novo
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

# =============================================================================
# =============================================================================
#  ETAPA 3/3: AIOS INIT + REGISTRO DE AGENTE
# =============================================================================
# =============================================================================

Write-Host ''
Write-Host '--- Etapa 3/3: AIOS Init ---' -ForegroundColor Cyan
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
    Write-Host ''
    Write-Host '  dados_whitelabel nao encontrado — coleta interativa' -ForegroundColor Yellow
    Write-Host ''

    if ([string]::IsNullOrWhiteSpace($nomeAgente)) {
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

# --- Salvar state etapa 3 ---
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

Write-Host ''
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host '  SETUP LOCAL CONCLUIDO!' -ForegroundColor Cyan
Write-Host '==============================================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Seu ambiente local esta pronto.'
Write-Host "  Para ativar o agente no Claude Code:"
Write-Host "  cd $INSTALL_DIR && @${nomeAgente}" -ForegroundColor White
Write-Host ''
Write-Host '  Para verificar o bridge:'
Write-Host "  cd $INSTALL_DIR\.aios-core\infrastructure && node bridge.js status" -ForegroundColor White
Write-Host ''

Feedback-OK 'Instrucoes exibidas'

Show-Summary
Write-Log '=== Instalacao finalizada ==='
