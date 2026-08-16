<#
.SYNOPSIS
    Instalador do Kdenlive e/ou do MCP Kdenlive em uma maquina Windows.

.DESCRIPTION
    Apresenta um menu com 5 opcoes:
      1. Instalar o Kdenlive oficial (via winget) -- SEM API de scripting D-Bus
      2. Instalar o MCP (clona mcp-kdenlive + kdenlive-api, cria venv,
         instala dependencias e gera .mcp.json)
      3. Instalar tudo (1 + 2)
      4. Compilar o Kdenlive com suporte a D-Bus (fork alltomatos/kdenlive)
         via KDE Craft -- processo longo (~30-60min), mas deixa o MCP
         funcional de verdade
      5. Instalar tudo (2 + 4) -- MCP + Kdenlive com D-Bus compilado

    Etapas do MCP (opcao 2/3/5):
      - Cria C:\kdenlive
      - Clona mcp-kdenlive e kdenlive-api dentro de C:\kdenlive (repos irmaos)
      - Cria um virtualenv e instala as dependencias Python
      - Verifica se ha um backend D-Bus funcional (dbus-send/qdbus/gdbus)
      - Gera um .mcp.json de exemplo apontando para o servidor

    Etapas do build com D-Bus (opcao 4/5):
      - Instala o Visual Studio Build Tools (workload C++) via winget, se
        o compilador MSVC ainda nao estiver presente
      - Instala o KDE Craft em C:\CraftRoot (bootstrap oficial)
      - Registra um blueprint customizado apontando para
        https://github.com/alltomatos/kdenlive (branch dbus-scripting-windows),
        que ja contem os patches necessarios para compilar no MSVC e a API
        D-Bus expandida
      - Roda "craft kdenlive" (baixa Qt/KF6/MLT pre-compilados do cache do
        KDE e compila so o Kdenlive)

.NOTES
    Requer: git, python 3.10+ no PATH. winget para as opcoes 1 e 4.
    IMPORTANTE: o pacote `KDE.Kdenlive` do winget instala o Kdenlive OFICIAL,
    sem a API de scripting via D-Bus. Para o MCP controlar o Kdenlive de fato,
    use a opcao 4 (ou 5), que compila o fork com patch
    (https://github.com/alltomatos/kdenlive, branch dbus-scripting-windows).

.PARAMETER Action
    "1" a "5" conforme o menu. Se omitido, mostra um menu interativo.
#>

[CmdletBinding()]
param(
    [ValidateSet("1", "2", "3", "4", "5")]
    [string]$Action,
    [string]$InstallRoot = "C:\kdenlive",
    [string]$McpRepo = "https://github.com/alltomatos/mcp-kdenlive.git",
    [string]$ApiRepo = "https://github.com/alltomatos/kdenlive-api.git",
    [string]$KdenliveWingetId = "KDE.Kdenlive",
    [string]$ProjectMcpJsonPath = $(if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }),
    [string]$CraftRoot = "C:\CraftRoot",
    [string]$KdenliveForkRepo = "https://github.com/alltomatos/kdenlive.git",
    [string]$KdenliveForkBranch = "dbus-scripting-windows"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

function Test-CommandExists($name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

function Set-ContentNoBom($path, $content) {
    # Windows PowerShell 5.1's Set-Content -Encoding utf8 always writes a BOM,
    # which breaks tools (like Python) that don't expect one on this file type.
    [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-VsWhereDir {
    return "C:\Program Files (x86)\Microsoft Visual Studio\Installer"
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
    Write-Host "Para o MCP controlar o Kdenlive de verdade, use a opcao 4 (build com D-Bus)." -ForegroundColor Yellow
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

    $dbusTools = @("dbus-send.exe", "qdbus.exe", "gdbus.exe")
    $foundDbus = $null
    foreach ($tool in $dbusTools) {
        $candidate = Join-Path (Join-Path $CraftRoot "bin") $tool
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
        Write-Host "Rode este script com a opcao 4 (ou 5) para compilar o Kdenlive com suporte D-Bus." -ForegroundColor Yellow
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
        Write-Host "Pendente: rode a opcao 4 (ou 5) para compilar o Kdenlive com D-Bus." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Opcao 4: Compilar o Kdenlive com suporte a D-Bus via KDE Craft
# ---------------------------------------------------------------------------
function Install-VSBuildTools {
    Write-Step "Verificando o compilador MSVC (Visual Studio Build Tools)"

    $vswhere = Join-Path (Get-VsWhereDir) "vswhere.exe"
    $hasCl = $false
    if (Test-Path $vswhere) {
        $vcToolsPath = & $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($vcToolsPath) { $hasCl = $true }
    }

    if ($hasCl) {
        Write-Host "MSVC (workload C++) ja instalado." -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists winget)) {
        throw "winget nao encontrado no PATH. Instale o App Installer da Microsoft Store antes de continuar."
    }

    Write-Host "Instalando Visual Studio Build Tools (workload C++). Isso baixa varios GB, pode demorar." -ForegroundColor Yellow
    winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget `
        --accept-source-agreements --accept-package-agreements --force `
        --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"

    $vcToolsPath = & $vswhere -all -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (-not $vcToolsPath) {
        throw "Falha ao instalar o Visual Studio Build Tools (workload C++ nao encontrado apos a instalacao)."
    }
    Write-Host "Visual Studio Build Tools instalado." -ForegroundColor Green
}

function Install-KdeCraft {
    Write-Step "Instalando o KDE Craft em $CraftRoot"

    # O vcvarsall.bat da Microsoft chama "vswhere.exe" assumindo que esta no
    # PATH, mas ele so existe em Get-VsWhereDir. Sem isso, o bootstrap do
    # Craft falha ao capturar as variaveis de ambiente do MSVC.
    $vsWhereDir = Get-VsWhereDir
    if ($env:PATH -notlike "*$vsWhereDir*") {
        $env:PATH = "$vsWhereDir;" + $env:PATH
    }

    if (Test-Path (Join-Path $CraftRoot "craft\craftenv.ps1")) {
        Write-Host "KDE Craft ja instalado em $CraftRoot." -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists python)) {
        throw "python nao encontrado no PATH. Instale o Python 3.10+ antes de continuar."
    }

    New-Item -ItemType Directory -Force -Path (Join-Path $CraftRoot "download") | Out-Null
    $bootstrapScript = Join-Path $CraftRoot "download\CraftBootstrap.py"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/KDE/craft/master/setup/CraftBootstrap.py" -OutFile $bootstrapScript

    $pythonExe = (Get-Command python).Source
    & $pythonExe $bootstrapScript --prefix $CraftRoot --branch master --use-defaults

    if (-not (Test-Path (Join-Path $CraftRoot "craft\craftenv.ps1"))) {
        throw "Falha ao instalar o KDE Craft."
    }
    Write-Host "KDE Craft instalado em $CraftRoot." -ForegroundColor Green
}

function Set-KdenliveBlueprintOverride {
    Write-Step "Configurando blueprint customizado do Kdenlive (fork com D-Bus)"

    $blueprintDir = Join-Path $CraftRoot "etc\blueprints\locations\craft-blueprints-kde\kde\kdemultimedia\kdenlive"
    if (-not (Test-Path $blueprintDir)) {
        throw "Blueprint do kdenlive nao encontrado em $blueprintDir. O Craft foi instalado corretamente?"
    }

    # version.ini: aponta a origem git para o fork com os patches de build
    # Windows/MSVC e a API D-Bus expandida.
    $versionIni = Join-Path $blueprintDir "version.ini"
    $versionIniContent = @"
[General]
name = kdenlive-dbus-fork

branches = $KdenliveForkBranch
defaulttarget = $KdenliveForkBranch

gitUrl = $KdenliveForkRepo
gitUpdatedRepoUrl = $KdenliveForkRepo
"@
    Set-ContentNoBom $versionIni $versionIniContent

    # kdenlive.py: forca -DUSE_DBUS=ON em qualquer plataforma (o blueprint
    # padrao so habilita no Linux). Sem efeito se o fork ja tiver isso fixo.
    # Precisa ficar sem BOM -- e um arquivo Python, e o Craft o importa com
    # o interpretador Python puro, que nao tolera um BOM UTF-8 no topo.
    $blueprintPy = Join-Path $blueprintDir "kdenlive.py"
    $content = Get-Content $blueprintPy -Raw
    $content = $content -replace 'f"-DUSE_DBUS=\{CraftCore\.compiler\.isLinux\.asOnOff\}"', '"-DUSE_DBUS=ON"'
    Set-ContentNoBom $blueprintPy $content

    Write-Host "Blueprint configurado: $KdenliveForkRepo ($KdenliveForkBranch)" -ForegroundColor Green
}

function Build-KdenliveWithDbus {
    Install-VSBuildTools
    Install-KdeCraft
    Set-KdenliveBlueprintOverride

    Write-Step "Compilando o Kdenlive via Craft (pode levar 30-60+ minutos na primeira vez)"

    $vsWhereDir = Get-VsWhereDir
    if ($env:PATH -notlike "*$vsWhereDir*") {
        $env:PATH = "$vsWhereDir;" + $env:PATH
    }

    $exePath = Join-Path $CraftRoot "bin\kdenlive.exe"
    $exeExistedBefore = Test-Path $exePath
    $beforeTimestamp = if ($exeExistedBefore) { (Get-Item $exePath).LastWriteTimeUtc } else { $null }

    # craftenv.ps1 e "craft" imprimem avisos informativos no stderr (ex:
    # "Found gcc in your PATH"). Com $ErrorActionPreference = "Stop" isso
    # vira um NativeCommandError fatal mesmo quando o comando teve sucesso
    # (limitacao conhecida do PowerShell 5.1 ao redirecionar stderr de exes
    # nativos). Relaxamos a preferencia so para esta secao.
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        . (Join-Path $CraftRoot "craft\craftenv.ps1")
        craft kdenlive
    } finally {
        $ErrorActionPreference = $previousEap
    }

    if (-not (Test-Path $exePath)) {
        throw "Build concluido mas kdenlive.exe nao foi encontrado em $exePath."
    }
    # kdenlive.exe pode ja existir de um build anterior -- so declarar
    # sucesso se ele realmente foi (re)gerado agora.
    $afterTimestamp = (Get-Item $exePath).LastWriteTimeUtc
    if ($exeExistedBefore -and $afterTimestamp -eq $beforeTimestamp) {
        throw "craft kdenlive nao atualizou kdenlive.exe -- o build provavelmente falhou. Veja a saida acima para o erro real."
    }

    Write-Step "Resumo do build"
    Write-Host "kdenlive.exe:  $exePath" -ForegroundColor Green
    Write-Host "Para rodar com D-Bus, defina antes de abrir o Kdenlive:" -ForegroundColor Cyan
    Write-Host "  `$env:PATH = `"$CraftRoot\bin;`" + `$env:PATH"
    Write-Host "  `$env:DBUS_SESSION_BUS_ADDRESS = `"autolaunch:scope=*install-path`""
    Write-Host "  & `"$exePath`""
}

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------
function Show-Menu {
    Write-Host ""
    Write-Host "=== Instalador mcp-kdenlive ===" -ForegroundColor Cyan
    Write-Host "1. Instalar Kdenlive oficial (winget, sem D-Bus)"
    Write-Host "2. Instalar MCP (tudo que o MCP precisa para funcionar)"
    Write-Host "3. Instalar tudo (Kdenlive oficial + MCP)"
    Write-Host "4. Compilar Kdenlive com suporte D-Bus (fork, via KDE Craft)"
    Write-Host "5. Instalar tudo com D-Bus (MCP + build do fork) [Recomendado]"
    Write-Host ""
    return Read-Host "Escolha uma opcao [1-5]"
}

if (-not $Action) {
    $Action = Show-Menu
}

switch ($Action) {
    "1" { Install-Kdenlive }
    "2" { Install-Mcp }
    "3" { Install-Kdenlive; Install-Mcp }
    "4" { Build-KdenliveWithDbus }
    "5" { Install-Mcp; Build-KdenliveWithDbus }
    default { throw "Opcao invalida: '$Action'. Use 1 a 5." }
}

Write-Host ""
Write-Host "Concluido." -ForegroundColor Green
