<#
.SYNOPSIS
    Create desktop and Start Menu shortcuts that launch this pinned copy.

.DESCRIPTION
    The original installers point their shortcuts at
    %LOCALAPPDATA%\Youdao\Dict\Application, which the auto-updater may
    delete. This script repoints them (and adds a desktop shortcut) to
    start-youdao.cmd inside this repo, so the shortcut always starts the
    pinned 8.10.8.0 build and re-applies the locks first.

    Shortcut names are built from code points because Windows PowerShell
    5.1 reads script files with the ANSI code page.

.PARAMETER RepoRoot
    Repo root. Defaults to the parent folder of this script.

.PARAMETER Remove
    Remove the shortcuts created/repaired by this script.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path

$launcher = Join-Path $RepoRoot 'start-youdao.cmd'
if (-not (Test-Path -LiteralPath $launcher)) {
    throw "start-youdao.cmd not found in $RepoRoot"
}

# "Youdao Dict 8.10.8.0" in Chinese, plus the two installers' folder name.
$nameDesktop = [string]::new([char[]]@(0x7F51,0x6613,0x6709,0x9053,0x8BCD,0x5178)) + ' 8.10.8.0'
$folderName  = [string]::new([char[]]@(0x6709,0x9053))                       # Youdao
$subFolder   = [string]::new([char[]]@(0x7F51,0x6613,0x6709,0x9053,0x8BCD,0x5178))  # Youdao Dict

$desktop = [Environment]::GetFolderPath('Desktop')
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'

$targets = @(
    (Join-Path $desktop ($nameDesktop + '.lnk')),
    (Join-Path $startMenu ($folderName + '\' + $subFolder + '\' + $nameDesktop + '.lnk'))
)

if ($Remove) {
    foreach ($t in $targets) {
        if (Test-Path -LiteralPath $t) {
            Remove-Item -LiteralPath $t -Force
            Write-Host "removed: $t"
        }
    }
    return
}

$shell = New-Object -ComObject WScript.Shell
foreach ($t in $targets) {
    $dir = Split-Path -Parent $t
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    $sc = $shell.CreateShortcut($t)
    $sc.TargetPath = $launcher
    $sc.WorkingDirectory = $RepoRoot
    $sc.IconLocation = (Join-Path $RepoRoot 'YoudaoDict.exe') + ',0'
    $sc.Description = 'Youdao Dict 8.10.8.0 (version pinned)'
    $sc.WindowStyle = 7   # minimized: keep the console window out of the way
    $sc.Save()
    Write-Host "created: $t"
}

Write-Host 'Shortcuts now launch the pinned copy in this repo.' -ForegroundColor Green
