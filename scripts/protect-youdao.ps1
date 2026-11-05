<#
.SYNOPSIS
    Pin Youdao Dict to the current version (8.10.x) and block auto-upgrade to 11.x.

.DESCRIPTION
    Youdao Dict spawns an updater shortly after launch. It fetches a new
    build from cidian.youdao.com, downloads YoudaoDict.exe.new into the
    install folder, and replaces itself on the next start.

    This script is idempotent and applies three locks:
      1. config.ini  ->  AUTOUPDATE=0
      2. %LOCALAPPDATA%\Yodao\DeskDict\updaters  ->  replaced by a plain
         file with the same name, so the updater cannot create its own
         download directory. This is the decisive lock.
      3. HKCU\Software\Youdao\Dict\Install  ->  this repo folder

    Everything runs inside the current user profile; no admin rights and
    no machine-wide changes are required.

    All messages are ASCII on purpose: Windows PowerShell 5.1 reads
    script files using the ANSI code page and would mangle Chinese text.

.PARAMETER RepoRoot
    Repo root. Defaults to the parent folder of this script.

.PARAMETER Quiet
    Suppress progress output; only errors are shown.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\protect-youdao.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Say([string]$msg) {
    if (-not $Quiet) { Write-Host "  $msg" }
}

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot 'YoudaoDict.exe'))) {
    throw "YoudaoDict.exe not found under $RepoRoot"
}

if (-not $Quiet) { Write-Host "Pin Youdao Dict (repo: $RepoRoot)" }

$DeskDict = Join-Path $env:LOCALAPPDATA 'Yodao\DeskDict'
New-Item -ItemType Directory -Path $DeskDict -Force | Out-Null

# ---- Lock 1: config.ini AUTOUPDATE=0 ---------------------------------
$cfg = Join-Path $DeskDict 'config.ini'
if (Test-Path -LiteralPath $cfg) {
    $raw = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8
    if ($raw -match '(?m)^AUTOUPDATE=1\s*$') {
        $new = $raw -replace '(?m)^AUTOUPDATE=1\s*$', 'AUTOUPDATE=0'
        [IO.File]::WriteAllText($cfg, $new, (New-Object Text.UTF8Encoding($false)))
        Say 'config.ini: AUTOUPDATE 1 -> 0'
    }
    elseif ($raw -notmatch '(?m)^AUTOUPDATE=') {
        $new = $raw -replace '(?m)^(\[DESKDICT\]\r?\n)', "`$1AUTOUPDATE=0`r`n"
        if ($new -ne $raw) {
            [IO.File]::WriteAllText($cfg, $new, (New-Object Text.UTF8Encoding($false)))
            Say 'config.ini: added AUTOUPDATE=0'
        }
    }
    else {
        Say 'config.ini: AUTOUPDATE already 0'
    }
}
else {
    $seed = "[DESKDICT]`r`nAUTOUPDATE=0`r`n"
    [IO.File]::WriteAllText($cfg, $seed, (New-Object Text.UTF8Encoding($false)))
    Say 'config.ini: created with AUTOUPDATE=0'
}

# ---- Lock 2: updaters directory -> same-name file --------------------
$Updaters = Join-Path $DeskDict 'updaters'
if (Test-Path -LiteralPath $Updaters) {
    $item = Get-Item -LiteralPath $Updaters -Force
    if ($item.PSIsContainer) {
        if ($item.IsReadOnly) { $item.IsReadOnly = $false }
        $park = Join-Path $DeskDict ('updaters.parked-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $Updaters -Destination $park -Force
        Set-Content -LiteralPath $Updaters -Value 'blocked by protect-youdao.ps1' -Encoding ASCII
        Say "updaters: folder moved to $(Split-Path -Leaf $park), replaced by placeholder file"
    }
    else {
        Say 'updaters: placeholder file already present'
    }
}
else {
    Set-Content -LiteralPath $Updaters -Value 'blocked by protect-youdao.ps1' -Encoding ASCII
    Say 'updaters: placeholder file created'
}

try {
    (Get-Item -LiteralPath $Updaters -Force).IsReadOnly = $true
}
catch {
    Say 'updaters: could not mark read-only (lock 2 still effective)'
}

# ---- Lock 3: registry install path -----------------------------------
$regKey = 'HKCU:\Software\Youdao\Dict'
if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
$cur = (Get-ItemProperty -Path $regKey -ErrorAction SilentlyContinue).Install
if ($cur -ne $RepoRoot) {
    Set-ItemProperty -Path $regKey -Name 'Install' -Value $RepoRoot -Force
    Say "registry Install: '$cur' -> '$RepoRoot'"
}
else {
    Say 'registry Install: already points to this repo'
}

if (-not $Quiet) {
    Write-Host 'Done. Version is pinned to 8.10.x.' -ForegroundColor Green
}
