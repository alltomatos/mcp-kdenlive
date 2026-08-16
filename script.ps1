<#
.SYNOPSIS
    Instalador unico do mcp-kdenlive: MCP + Kdenlive com suporte a D-Bus.

.DESCRIPTION
    Roda tudo em sequencia, sem menu nem opcoes -- como um pacote unico:
      1. Instala o MCP (clona mcp-kdenlive + kdenlive-api, cria venv,
         instala dependencias e gera .mcp.json)
      2. Baixa o build portatil pronto do Kdenlive com D-Bus (release do
         fork alltomatos/kdenlive) e extrai -- rapido, poucos minutos.
         Se o download/extracao falhar por qualquer motivo, cai para
         compilar do zero via KDE Craft (processo longo, ~30-60min).

    Etapas do MCP:
      - Cria C:\kdenlive
      - Clona mcp-kdenlive e kdenlive-api dentro de C:\kdenlive (repos irmaos)
      - Cria um virtualenv e instala as dependencias Python
      - Gera um .mcp.json de exemplo apontando para o servidor

    Etapas do Kdenlive (portatil, caminho padrao):
      - Baixa o .zip do release mais recente em
        https://github.com/alltomatos/kdenlive/releases
      - Extrai em C:\kdenlive\kdenlive-portable

    Etapas do build com D-Bus (fallback, ou com -ForceBuild):
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
    Requer: git, python 3.10+ no PATH. winget so e necessario se cair no
    fallback de build (Visual Studio Build Tools).
    Nao ha instalacao do Kdenlive "oficial" via winget -- o pacote oficial nao
    tem a API de scripting via D-Bus, entao seria inutil para o MCP.

.PARAMETER ForceBuild
    Pula o download do portatil e compila direto via KDE Craft.
#>

[CmdletBinding()]
param(
    [string]$InstallRoot = "C:\kdenlive",
    [string]$McpRepo = "https://github.com/alltomatos/mcp-kdenlive.git",
    [string]$ApiRepo = "https://github.com/alltomatos/kdenlive-api.git",
    [string]$ProjectMcpJsonPath = $(if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }),
    [string]$CraftRoot = "C:\CraftRoot",
    [string]$KdenliveForkRepo = "https://github.com/alltomatos/kdenlive.git",
    [string]$KdenliveForkBranch = "dbus-scripting-windows",
    [string]$KdenlivePortableUrl = "https://github.com/alltomatos/kdenlive/releases/latest/download/kdenlive-dbus-windows-x86_64.zip",
    [string]$KdenlivePortableRoot = "C:\kdenlive\kdenlive-portable",
    [switch]$ForceBuild
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
# Instalar o MCP (tudo que ele precisa para funcionar)
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
}

# ---------------------------------------------------------------------------
# Kdenlive portatil (caminho padrao -- baixa o release ja pronto)
# ---------------------------------------------------------------------------
function Install-KdenlivePortable {
    Write-Step "Baixando o Kdenlive portatil com D-Bus (release do fork)"

    $exePath = Join-Path $KdenlivePortableRoot "bin\kdenlive.exe"
    if (Test-Path $exePath) {
        Write-Host "Ja existe em $KdenlivePortableRoot." -ForegroundColor Green
        return $exePath
    }

    New-Item -ItemType Directory -Force -Path $KdenlivePortableRoot | Out-Null
    $zipPath = Join-Path $env:TEMP "kdenlive-dbus-windows-x86_64.zip"

    Write-Host "Baixando de $KdenlivePortableUrl ..."
    Invoke-WebRequest -Uri $KdenlivePortableUrl -OutFile $zipPath

    Write-Host "Extraindo para $KdenlivePortableRoot ..."
    # Expand-Archive e absurdamente lento com milhares de arquivos pequenos no
    # PowerShell 5.1 (>20min para este pacote). ZipFile.ExtractToDirectory faz
    # o mesmo em segundos.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $KdenlivePortableRoot)
    Remove-Item $zipPath -Force

    if (-not (Test-Path $exePath)) {
        throw "kdenlive.exe nao encontrado em $exePath apos extrair o pacote portatil."
    }

    Write-Host "Kdenlive portatil pronto em $KdenlivePortableRoot." -ForegroundColor Green
    return $exePath
}

# ---------------------------------------------------------------------------
# Compilar o Kdenlive com suporte a D-Bus via KDE Craft (fallback)
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

    Write-Host "kdenlive.exe:  $exePath" -ForegroundColor Green
    return $exePath
}

# ---------------------------------------------------------------------------
# Instalacao completa, sem menu -- MCP + Kdenlive com D-Bus
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Instalador mcp-kdenlive ===" -ForegroundColor Cyan

Install-Mcp

$kdenliveExe = $null
if (-not $ForceBuild) {
    try {
        $kdenliveExe = Install-KdenlivePortable
        $kdenliveBinDir = Split-Path $kdenliveExe -Parent
    } catch {
        Write-Host ""
        Write-Host "Download do portatil falhou ($($_.Exception.Message)) -- caindo para build via KDE Craft (~30-60min)." -ForegroundColor Yellow
    }
}

if (-not $kdenliveExe) {
    Write-Host "Compilando o Kdenlive via KDE Craft. Isso pode levar 30-60+ minutos na primeira vez." -ForegroundColor Cyan
    $kdenliveExe = Build-KdenliveWithDbus
    $kdenliveBinDir = Join-Path $CraftRoot "bin"
}

Write-Step "Resumo"
Write-Host "kdenlive.exe:  $kdenliveExe" -ForegroundColor Green
Write-Host "Para rodar com D-Bus, defina antes de abrir o Kdenlive:" -ForegroundColor Cyan
Write-Host "  `$env:PATH = `"$kdenliveBinDir;`" + `$env:PATH"
Write-Host "  `$env:DBUS_SESSION_BUS_ADDRESS = `"autolaunch:scope=*install-path`""
Write-Host "  & `"$kdenliveExe`""

Write-Host ""
Write-Host "Concluido." -ForegroundColor Green
