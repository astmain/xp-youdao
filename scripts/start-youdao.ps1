<#
.SYNOPSIS
    Launch Youdao Dict 8.10.8.0 with version pinning applied.

.DESCRIPTION
    On a new machine: clone the repo, then run start-youdao.cmd.

    Steps:
      1. run protect-youdao.ps1 so auto-update stays blocked
      2. remove leftover *.new upgrade packages, if any
      3. launch YoudaoDict.exe

.PARAMETER RepoRoot
    Repo root. Defaults to the parent folder of this script.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$exe = Join-Path $RepoRoot 'YoudaoDict.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw "YoudaoDict.exe not found at $exe"
}

Write-Host 'Starting Youdao Dict 8.10.8.0 ...' -ForegroundColor Cyan

# 1. pin the version
& (Join-Path $PSScriptRoot 'protect-youdao.ps1') -RepoRoot $RepoRoot

# 2. drop leftover upgrade packages
$stale = Get-ChildItem -LiteralPath $RepoRoot -Filter '*.new' -File -Force -ErrorAction SilentlyContinue
foreach ($f in $stale) {
    try {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
        Write-Host "  removed leftover upgrade package: $($f.Name)" -ForegroundColor Yellow
    }
    catch {
        Write-Host "  could not remove $($f.Name) (in use), skipped" -ForegroundColor Yellow
    }
}

# 3. launch
Start-Process -FilePath $exe -WorkingDirectory $RepoRoot

Write-Host 'Launched.' -ForegroundColor Green
