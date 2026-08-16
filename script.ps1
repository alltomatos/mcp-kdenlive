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
      3. Cria um atalho "Kdenlive (MCP)" na area de trabalho que ja abre
         com as variaveis de ambiente do D-Bus configuradas.

    Etapas do MCP:
      - Cria C:\kdenlive
      - Clona mcp-kdenlive e kdenlive-api dentro de C:\kdenlive (repos irmaos)
      - Cria um virtualenv e instala as dependencias Python
      - Gera um .mcp.json de exemplo apontando para o servidor

    Etapas do Kdenlive (portatil, caminho padrao):
      - Instala o 7-Zip via winget, se ainda nao estiver presente (usado so
        para extrair; um SFX 7zCon.sfx foi testado antes mas corrompe
        arquivos silenciosamente neste pacote -- ver nota no codigo)
      - Baixa o .7z do release mais recente em
        https://github.com/alltomatos/kdenlive/releases
      - Extrai com 7z.exe em C:\kdenlive\kdenlive-portable

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
    Pre-requisitos: nenhum precisa estar pre-instalado. git e python 3.10+
    sao instalados automaticamente via winget se nao estiverem no PATH (ou
    se "python" for so o stub da Microsoft Store). winget em si (App
    Installer) normalmente ja vem no Windows 10 21H2+/11; se nao existir,
    o script para com instrucoes -- nao ha como instala-lo via script sem
    interacao com a Microsoft Store.
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
    [string]$KdenlivePortableUrl = "https://github.com/alltomatos/kdenlive/releases/latest/download/kdenlive-dbus-windows-x86_64.7z",
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

function Update-SessionPath {
    # Depois de instalar algo via winget, o PATH so e atualizado em sessoes
    # NOVAS do shell. Reler do registro (Machine + User) evita ter que
    # reiniciar o PowerShell no meio do script.
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Install-Git {
    Write-Step "Verificando o Git"

    if (Test-CommandExists git) {
        Write-Host "git: OK ($(git --version))" -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists winget)) {
        throw "git nao encontrado no PATH, e winget tambem nao esta disponivel para instala-lo. Instale o Git manualmente antes de continuar."
    }

    Write-Host "git nao encontrado -- instalando via winget (Git.Git)..." -ForegroundColor Yellow
    # winget e um exe nativo: sua saida nao capturada vira parte do "return"
    # da funcao PowerShell que o chama, corrompendo qualquer $x = Funcao(...)
    # mais adiante. Out-Host imprime ao vivo sem poluir o pipeline.
    winget install --id Git.Git -e --silent --source winget --accept-source-agreements --accept-package-agreements | Out-Host

    Update-SessionPath
    if (-not (Test-CommandExists git)) {
        throw "Git instalado via winget mas 'git' ainda nao esta no PATH desta sessao. Feche e reabra o PowerShell e rode o script de novo."
    }
    Write-Host "git instalado: $(git --version)" -ForegroundColor Green
}

function Test-PythonWorks {
    # No Windows, "python" pode existir no PATH como um App Execution Alias
    # da Microsoft Store que so imprime um aviso e nao roda nada -- Get-Command
    # acha esse stub e mente que "python existe". Confirma checando a saida.
    if (-not (Test-CommandExists python)) { return $false }
    try {
        $out = & python --version 2>&1
        return ($LASTEXITCODE -eq 0) -and ($out -match "^Python \d")
    } catch {
        return $false
    }
}

function Install-Python {
    Write-Step "Verificando o Python"

    if (Test-PythonWorks) {
        Write-Host "python: OK ($(python --version))" -ForegroundColor Green
        return
    }

    if (-not (Test-CommandExists winget)) {
        throw "python nao encontrado no PATH, e winget tambem nao esta disponivel para instala-lo. Instale o Python 3.10+ manualmente antes de continuar."
    }

    Write-Host "python nao encontrado (ou e so o stub da Microsoft Store) -- instalando via winget (Python.Python.3.11)..." -ForegroundColor Yellow
    winget install --id Python.Python.3.11 -e --silent --source winget --accept-source-agreements --accept-package-agreements | Out-Host

    Update-SessionPath
    if (-not (Test-PythonWorks)) {
        throw "Python instalado via winget mas 'python' ainda nao funciona nesta sessao (pode ser o alias da Microsoft Store tomando prioridade no PATH). Feche e reabra o PowerShell e rode o script de novo, ou desative o alias em Configuracoes > Aplicativos > Aliases de execucao de aplicativos avancados."
    }
    Write-Host "python instalado: $(python --version)" -ForegroundColor Green
}

function Get-7ZipExe {
    $candidates = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $onPath = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    return $null
}

function Install-7Zip {
    Write-Step "Verificando o 7-Zip"

    $existing = Get-7ZipExe
    if ($existing) {
        Write-Host "7-Zip: OK ($existing)" -ForegroundColor Green
        return $existing
    }

    if (-not (Test-CommandExists winget)) {
        throw "7-Zip nao encontrado, e winget tambem nao esta disponivel para instala-lo. Instale o 7-Zip manualmente antes de continuar."
    }

    Write-Host "7-Zip nao encontrado -- instalando via winget (7zip.7zip)..." -ForegroundColor Yellow
    winget install --id 7zip.7zip -e --silent --source winget --accept-source-agreements --accept-package-agreements | Out-Host

    Update-SessionPath
    $installed = Get-7ZipExe
    if (-not $installed) {
        throw "7-Zip instalado via winget mas 7z.exe nao foi encontrado. Feche e reabra o PowerShell e rode o script de novo."
    }
    Write-Host "7-Zip instalado: $installed" -ForegroundColor Green
    return $installed
}

# ---------------------------------------------------------------------------
# Instalar o MCP (tudo que ele precisa para funcionar)
# ---------------------------------------------------------------------------
function Install-Mcp {
    Write-Step "Verificando pre-requisitos do MCP"

    Install-Git
    Install-Python

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

    $sevenZip = Install-7Zip

    New-Item -ItemType Directory -Force -Path $KdenlivePortableRoot | Out-Null
    $archivePath = Join-Path $env:TEMP "kdenlive-dbus-windows-x86_64.7z"

    Write-Host "Baixando de $KdenlivePortableUrl ..."
    try {
        Invoke-WebRequest -Uri $KdenlivePortableUrl -OutFile $archivePath
    } catch {
        throw "Falha ao baixar o pacote portatil: $($_.Exception.Message)`n`nBaixe manualmente em: $KdenlivePortableUrl`nSalve como: $archivePath`nExtraia com 7-Zip para: $KdenlivePortableRoot"
    }

    Write-Host "Extraindo para $KdenlivePortableRoot ..."
    # Um SFX 7zCon.sfx (auto-extraivel) foi testado antes deste pacote --
    # corrompeu arquivos silenciosamente sem erro no exit code nem no log
    # (tamanhos batiam, alguns bytes nao). 7z.exe direto e o metodo
    # validado como confiavel.
    $out = & $sevenZip x -y -o"$KdenlivePortableRoot" $archivePath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao extrair o pacote portatil (codigo $LASTEXITCODE): $out`n`nO arquivo baixado ficou em: $archivePath`nExtraia manualmente com 7-Zip para: $KdenlivePortableRoot"
    }
    Remove-Item $archivePath -Force

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
        --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended" | Out-Host

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
# Atalho na area de trabalho
# ---------------------------------------------------------------------------
function New-KdenliveDesktopShortcut($kdenliveExePath, $kdenliveBinPath) {
    Write-Step "Criando atalho na area de trabalho"

    # kdenlive.exe sozinho nao tem as variaveis de ambiente do D-Bus. O
    # atalho aponta para um .cmd lancador que configura o ambiente e so
    # entao abre o Kdenlive.
    #
    # NAO usamos "DBUS_SESSION_BUS_ADDRESS=autolaunch:scope=*install-path":
    # o autolaunch do libdbus no Windows tem uma race condition -- kdenlive.exe
    # e ferramentas de linha de comando (dbus-send/qdbus) podem acabar cada um
    # autolancando/conectando a um dbus-daemon DIFERENTE, mesmo com o mesmo
    # scope, dependendo do timing. Em vez disso, subimos um dbus-daemon
    # explicito aqui e usamos o MESMO endereco concreto (tcp:host=...) para
    # tudo, o que elimina a ambiguidade.
    $launcherPath = Join-Path (Split-Path $kdenliveBinPath -Parent) "Launch-Kdenlive.cmd"
    $launcherContent = @"
@echo off
set "BIN=$kdenliveBinPath"
set "PATH=%BIN%;%PATH%"
set "DBUS_ADDR_FILE=%TEMP%\kdenlive_dbus_addr_%RANDOM%.txt"
start "" /B cmd /c ""%BIN%\dbus-daemon.exe" --session --print-address > "%DBUS_ADDR_FILE%" 2>&1"
timeout /t 2 /nobreak >nul
set /p DBUS_SESSION_BUS_ADDRESS=<"%DBUS_ADDR_FILE%"
del "%DBUS_ADDR_FILE%" >nul 2>&1
start "" "$kdenliveExePath"
"@
    Set-ContentNoBom $launcherPath $launcherContent

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "Kdenlive (MCP).lnk"

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $launcherPath
    $shortcut.WorkingDirectory = Split-Path $kdenliveExePath -Parent
    $shortcut.IconLocation = $kdenliveExePath
    $shortcut.Description = "Kdenlive com API de scripting D-Bus (para o MCP)"
    $shortcut.Save()

    Write-Host "Atalho criado: $shortcutPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Instalacao completa, sem menu -- MCP + Kdenlive com D-Bus
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "=== Instalador mcp-kdenlive ===" -ForegroundColor Cyan

Install-Mcp

if ($ForceBuild) {
    Write-Host "Compilando o Kdenlive via KDE Craft. Isso pode levar 30-60+ minutos na primeira vez." -ForegroundColor Cyan
    $kdenliveExe = Build-KdenliveWithDbus
    $kdenliveBinDir = Join-Path $CraftRoot "bin"
} else {
    # Sem fallback silencioso para o build via Craft: se o portatil falhar,
    # o script para aqui e mostra onde esta o arquivo para instalar na mao,
    # em vez de embarcar numa compilacao de 30-60min sem o usuario pedir.
    $kdenliveExe = Install-KdenlivePortable
    $kdenliveBinDir = Split-Path $kdenliveExe -Parent
}

New-KdenliveDesktopShortcut $kdenliveExe $kdenliveBinDir

Write-Step "Resumo"
Write-Host "kdenlive.exe:  $kdenliveExe" -ForegroundColor Green
Write-Host "Atalho:        Kdenlive (MCP) na area de trabalho" -ForegroundColor Green
Write-Host "Use sempre o atalho (ou o Launch-Kdenlive.cmd na mesma pasta do exe) para" -ForegroundColor Cyan
Write-Host "abrir o Kdenlive -- ele sobe um dbus-daemon dedicado com endereco explicito," -ForegroundColor Cyan
Write-Host "necessario porque o autolaunch do D-Bus no Windows e' instavel (race condition)." -ForegroundColor Cyan

Write-Host ""
Write-Host "Concluido." -ForegroundColor Green
