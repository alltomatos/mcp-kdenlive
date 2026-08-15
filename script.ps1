<#
.SYNOPSIS
    Setup do MCP Kdenlive em uma nova maquina Windows.

.DESCRIPTION
    1. Cria C:\kdenlive
    2. Clona mcp-kdenlive e kdenlive-api dentro de C:\kdenlive (repos irmaos)
    3. Cria um virtualenv e instala as dependencias Python
    4. Verifica se ha um backend D-Bus funcional (dbus-send/qdbus/gdbus)
    5. Gera um .mcp.json de exemplo apontando para o servidor

.NOTES
    Requer: git, python 3.10+ no PATH.
    O suporte a D-Bus real no Windows depende do KDE Craft (CraftRoot) com o
    fork com patch do Kdenlive rodando (https://github.com/D-Ogi/kdenlive).
    Este script NAO instala o KDE Craft nem o Kdenlive em si -- apenas prepara
    o servidor MCP e avisa se o backend D-Bus ainda precisa ser configurado.
#>

[CmdletBinding()]
param(
    [string]$InstallRoot = "C:\kdenlive",
    [string]$McpRepo = "https://github.com/alltomatos/mcp-kdenlive.git",
    [string]$ApiRepo = "https://github.com/D-Ogi/kdenlive-api.git",
    [string]$ProjectMcpJsonPath = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Test-CommandExists($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# ---------------------------------------------------------------------------
# 0. Pre-requisitos
# ---------------------------------------------------------------------------
Write-Step "Verificando pre-requisitos"

if (-not (Test-CommandExists git)) {
    throw "git nao encontrado no PATH. Instale o Git antes de continuar."
}
if (-not (Test-CommandExists python)) {
    throw "python nao encontrado no PATH. Instale o Python 3.10+ antes de continuar."
}

$pyVersion = python --version
Write-Host "git: OK"
Write-Host "python: $pyVersion"

# ---------------------------------------------------------------------------
# 1. Criar C:\kdenlive
# ---------------------------------------------------------------------------
Write-Step "Criando pasta de instalacao: $InstallRoot"

if (-not (Test-Path $InstallRoot)) {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    Write-Host "Criado: $InstallRoot"
} else {
    Write-Host "Ja existe: $InstallRoot"
}

$mcpPath = Join-Path $InstallRoot "mcp-kdenlive"
$apiPath = Join-Path $InstallRoot "kdenlive-api"

# ---------------------------------------------------------------------------
# 2. Clonar (ou atualizar) os repositorios irmaos
# ---------------------------------------------------------------------------
Write-Step "Clonando/atualizando repositorios"

function Clone-OrPull($url, $path) {
    if (Test-Path (Join-Path $path ".git")) {
        Write-Host "Atualizando $path"
        Push-Location $path
        git pull --ff-only
        Pop-Location
    } else {
        Write-Host "Clonando $url -> $path"
        git clone $url $path
    }
}

Clone-OrPull $McpRepo $mcpPath
Clone-OrPull $ApiRepo $apiPath

# ---------------------------------------------------------------------------
# 3. Virtualenv + dependencias
# ---------------------------------------------------------------------------
Write-Step "Criando virtualenv e instalando dependencias"

$venvPath = Join-Path $mcpPath ".venv"
if (-not (Test-Path $venvPath)) {
    python -m venv $venvPath
    Write-Host "Virtualenv criado em $venvPath"
} else {
    Write-Host "Virtualenv ja existe em $venvPath"
}

$venvPython = Join-Path $venvPath "Scripts\python.exe"

& $venvPython -m pip install --upgrade pip | Out-Null

# mcp-kdenlive espera kdenlive-api como repo irmao (sys.path), entao instalamos
# so as deps do proprio mcp-kdenlive (mcp SDK) sem a linha git+ do kdenlive-api.
$reqFile = Join-Path $mcpPath "requirements.txt"
$tmpReq = Join-Path $mcpPath "requirements.mcp-only.txt"
Get-Content $reqFile | Where-Object { $_ -notmatch "^kdenlive-api" } | Set-Content $tmpReq

& $venvPython -m pip install -r $tmpReq
Remove-Item $tmpReq -Force

Write-Host "Dependencias instaladas."

# ---------------------------------------------------------------------------
# 4. Checar backend D-Bus disponivel no Windows
# ---------------------------------------------------------------------------
Write-Step "Verificando backend D-Bus (necessario para falar com o Kdenlive)"

$craftRoot = $env:CRAFT_ROOT
if (-not $craftRoot) { $craftRoot = "C:\CraftRoot" }

$dbusTools = @("dbus-send.exe", "qdbus.exe", "gdbus.exe")
$found = $null
foreach ($tool in $dbusTools) {
    $candidate = Join-Path (Join-Path $craftRoot "bin") $tool
    if (Test-Path $candidate) { $found = $candidate; break }
}
if (-not $found) {
    foreach ($tool in $dbusTools) {
        if (Test-CommandExists ($tool -replace "\.exe$", "")) { $found = $tool; break }
    }
}

if ($found) {
    Write-Host "Backend D-Bus encontrado: $found" -ForegroundColor Green
} else {
    Write-Host "NENHUM backend D-Bus encontrado (dbus-send/qdbus/gdbus)." -ForegroundColor Yellow
    Write-Host "O servidor MCP vai subir, mas nao conseguira controlar o Kdenlive de verdade." -ForegroundColor Yellow
    Write-Host "Voce precisa instalar o KDE Craft (https://community.kde.org/Craft) e" -ForegroundColor Yellow
    Write-Host "rodar o fork com patch do Kdenlive: https://github.com/D-Ogi/kdenlive" -ForegroundColor Yellow
    Write-Host "Depois, defina a variavel de ambiente CRAFT_ROOT apontando para a instalacao." -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. Gerar .mcp.json de exemplo no projeto atual
# ---------------------------------------------------------------------------
Write-Step "Gerando .mcp.json de exemplo"

$mcpJsonPath = Join-Path $ProjectMcpJsonPath ".mcp.json"
$mcpJsonContent = @{
    mcpServers = @{
        kdenlive = @{
            command = $venvPython
            args    = @("-m", "mcp_kdenlive")
            cwd     = $mcpPath
        }
    }
} | ConvertTo-Json -Depth 5

Set-Content -Path $mcpJsonPath -Value $mcpJsonContent -Encoding utf8
Write-Host "Escrito: $mcpJsonPath"

# ---------------------------------------------------------------------------
# 6. Resumo
# ---------------------------------------------------------------------------
Write-Step "Resumo"
Write-Host "mcp-kdenlive:  $mcpPath"
Write-Host "kdenlive-api:  $apiPath"
Write-Host "venv python:   $venvPython"
Write-Host ".mcp.json:     $mcpJsonPath"
if (-not $found) {
    Write-Host ""
    Write-Host "Pendente: configurar o backend D-Bus (KDE Craft + Kdenlive com patch) antes de usar de verdade." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Setup concluido." -ForegroundColor Green
