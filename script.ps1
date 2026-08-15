<#
.SYNOPSIS
    Instalador do Kdenlive e/ou do MCP Kdenlive em uma maquina Windows.

.DESCRIPTION
    Apresenta um menu com 3 opcoes:
      1. Instalar o Kdenlive (via winget)
      2. Instalar o MCP (clona mcp-kdenlive + kdenlive-api, cria venv,
         instala dependencias e gera .mcp.json)
      3. Instalar tudo (1 + 2)

    Etapas do MCP (opcao 2/3):
      - Cria C:\kdenlive
      - Clona mcp-kdenlive e kdenlive-api dentro de C:\kdenlive (repos irmaos)
      - Cria um virtualenv e instala as dependencias Python
      - Verifica se ha um backend D-Bus funcional (dbus-send/qdbus/gdbus)
      - Gera um .mcp.json de exemplo apontando para o servidor

.NOTES
    Requer: git, python 3.10+ no PATH. winget para a opcao de instalar o Kdenlive.
    IMPORTANTE: o pacote `KDE.Kdenlive` do winget instala o Kdenlive OFICIAL,
    sem a API de scripting via D-Bus. Para o MCP controlar o Kdenlive de fato,
    ainda e necessario o fork com patch (https://github.com/D-Ogi/kdenlive) e
    o KDE Craft (CraftRoot) fornecendo dbus-send/qdbus/gdbus. Este script avisa
    quando esse backend nao e encontrado.

.PARAMETER Action
    "1" instala so o Kdenlive, "2" so o MCP, "3" os dois. Se omitido, mostra
    um menu interativo.
#>

[CmdletBinding()]
param(
    [ValidateSet("1", "2", "3")]
    [string]$Action,
    [string]$InstallRoot = "C:\kdenlive",
    [string]$McpRepo = "https://github.com/alltomatos/mcp-kdenlive.git",
    [string]$ApiRepo = "https://github.com/alltomatos/kdenlive-api.git",
    [string]$KdenliveWingetId = "KDE.Kdenlive",
    [string]$ProjectMcpJsonPath = $(if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path })
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
# Opcao 1: Instalar o Kdenlive via winget
# ---------------------------------------------------------------------------
function Install-Kdenlive {
    Write-Step "Instalando Kdenlive via winget ($KdenliveWingetId)"

    if (-not (Test-CommandExists winget)) {
        throw "winget nao encontrado no PATH. Instale o App Installer da Microsoft Store antes de continuar."
    }

    winget install --id $KdenliveWingetId -e --source winget --accept-source-agreements --accept-package-agreements

    Write-Host ""
    Write-Host "Kdenlive instalado (pacote oficial winget)." -ForegroundColor Green
    Write-Host "Este pacote NAO tem a API de scripting via D-Bus." -ForegroundColor Yellow
    Write-Host "Para o MCP controlar o Kdenlive de verdade, use o fork com patch:" -ForegroundColor Yellow
    Write-Host "  https://github.com/D-Ogi/kdenlive" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Opcao 2: Instalar o MCP (tudo que ele precisa para funcionar)
# ---------------------------------------------------------------------------
function Install-Mcp {
    Write-Step "Verificando pre-requisitos do MCP"

    if (-not (Test-CommandExists git)) {
        throw "git nao encontrado no PATH. Instale o Git antes de continuar."
    }
    if (-not (Test-CommandExists python)) {
        throw "python nao encontrado no PATH. Instale o Python 3.10+ antes de continuar."
    }

    Write-Host "git: OK"
    Write-Host "python: $(python --version)"

    # -- Criar pasta de instalacao ------------------------------------------
    Write-Step "Criando pasta de instalacao: $InstallRoot"

    if (-not (Test-Path $InstallRoot)) {
        New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
        Write-Host "Criado: $InstallRoot"
    } else {
        Write-Host "Ja existe: $InstallRoot"
    }

    $mcpPath = Join-Path $InstallRoot "mcp-kdenlive"
    $apiPath = Join-Path $InstallRoot "kdenlive-api"

    # -- Clonar/atualizar repos irmaos ---------------------------------------
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

    # -- Virtualenv + dependencias -------------------------------------------
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

    # mcp-kdenlive espera kdenlive-api como repo irmao (sys.path), entao
    # instalamos so as deps do proprio mcp-kdenlive (mcp SDK), sem a linha
    # git+ do kdenlive-api.
    $reqFile = Join-Path $mcpPath "requirements.txt"
    $tmpReq = Join-Path $mcpPath "requirements.mcp-only.txt"
    Get-Content $reqFile | Where-Object { $_ -notmatch "^kdenlive-api" } | Set-Content $tmpReq

    & $venvPython -m pip install -r $tmpReq
    Remove-Item $tmpReq -Force

    Write-Host "Dependencias instaladas."

    # -- Checar backend D-Bus -------------------------------------------------
    Write-Step "Verificando backend D-Bus (necessario para falar com o Kdenlive)"

    $craftRoot = $env:CRAFT_ROOT
    if (-not $craftRoot) { $craftRoot = "C:\CraftRoot" }

    $dbusTools = @("dbus-send.exe", "qdbus.exe", "gdbus.exe")
    $foundDbus = $null
    foreach ($tool in $dbusTools) {
        $candidate = Join-Path (Join-Path $craftRoot "bin") $tool
        if (Test-Path $candidate) { $foundDbus = $candidate; break }
    }
    if (-not $foundDbus) {
        foreach ($tool in $dbusTools) {
            if (Test-CommandExists ($tool -replace "\.exe$", "")) { $foundDbus = $tool; break }
        }
    }

    if ($foundDbus) {
        Write-Host "Backend D-Bus encontrado: $foundDbus" -ForegroundColor Green
    } else {
        Write-Host "NENHUM backend D-Bus encontrado (dbus-send/qdbus/gdbus)." -ForegroundColor Yellow
        Write-Host "O servidor MCP vai subir, mas nao conseguira controlar o Kdenlive de verdade." -ForegroundColor Yellow
        Write-Host "Voce precisa instalar o KDE Craft (https://community.kde.org/Craft) e" -ForegroundColor Yellow
        Write-Host "rodar o fork com patch do Kdenlive: https://github.com/D-Ogi/kdenlive" -ForegroundColor Yellow
        Write-Host "Depois, defina a variavel de ambiente CRAFT_ROOT apontando para a instalacao." -ForegroundColor Yellow
    }

    # -- Gerar .mcp.json de exemplo -------------------------------------------
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

    # -- Resumo -----------------------------------------------------------
    Write-Step "Resumo"
    Write-Host "mcp-kdenlive:  $mcpPath"
    Write-Host "kdenlive-api:  $apiPath"
    Write-Host "venv python:   $venvPython"
    Write-Host ".mcp.json:     $mcpJsonPath"
    if (-not $foundDbus) {
        Write-Host ""
        Write-Host "Pendente: configurar o backend D-Bus (KDE Craft + Kdenlive com patch) antes de usar de verdade." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Show-Menu {
    Write-Host ""
    Write-Host "=== Instalador mcp-kdenlive ===" -ForegroundColor Cyan
    Write-Host "1. Instalar Kdenlive (winget)"
    Write-Host "2. Instalar MCP (tudo que o MCP precisa para funcionar)"
    Write-Host "3. Instalar tudo (Kdenlive + MCP)"
    Write-Host ""
    return Read-Host "Escolha uma opcao [1-3]"
}

if (-not $Action) {
    $Action = Show-Menu
}

switch ($Action) {
    "1" { Install-Kdenlive }
    "2" { Install-Mcp }
    "3" { Install-Kdenlive; Install-Mcp }
    default { throw "Opcao invalida: '$Action'. Use 1, 2 ou 3." }
}

Write-Host ""
Write-Host "Concluido." -ForegroundColor Green
