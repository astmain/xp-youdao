[CmdletBinding()]
param([string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
$name = 'YoudaoDict-8.10.8.0-Portable-Windows'
$zipPath = Join-Path $output ($name + '.zip')

if ((Get-Item -LiteralPath (Join-Path $root 'YoudaoDict.exe')).VersionInfo.FileVersion -ne '8.10.8.0') {
    throw 'Expected YoudaoDict.exe version 8.10.8.0.'
}
$cef = Join-Path $root '8.10.8.0\libcef.dll'
if ((Get-Item -LiteralPath $cef).Length -ne 143979576 -or
    (Get-FileHash -LiteralPath $cef -Algorithm SHA256).Hash -ne '3a4aa37af4df59a232cdeac25f45f9c7f2ba18d34fce6ea30ead5032df58ad69') {
    throw 'libcef.dll is missing, changed, or an LFS pointer. Run git lfs pull.'
}

$dirty = @(git -C $root status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw 'Commit tracked changes before building a release.' }
$commit = git -C $root rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git revision.' }
$tracked = @(git -C $root -c core.quotepath=false ls-files)
if ($LASTEXITCODE -ne 0) { throw 'Cannot list tracked files.' }

# Allowlist payload files: never copy the working directory recursively.
$files = @($tracked | Where-Object {
    $_ -match '^(8\.10\.8\.0|Stable)/' -or
    $_ -in @('YoudaoDict.exe','YodaoDict.exe','InstallHelper.exe','uninst.exe',
             'start-youdao.cmd','README.md','THIRD-PARTY-NOTICE.md',
             'scripts/start-youdao.ps1','scripts/protect-youdao.ps1','scripts/install-shortcuts.ps1')
} | Sort-Object)
foreach ($required in @('start-youdao.cmd','scripts/protect-youdao.ps1','README.md','THIRD-PARTY-NOTICE.md','8.10.8.0/libcef.dll')) {
    if ($required -notin $files) { throw "Missing tracked release file: $required" }
}
foreach ($file in $files) {
    if ($file -match '(^|/)(guid\.dat|vendor\.dat|cookies\.dat|config\.ini)$|\.(lnk|log|new|ydtmp)$') {
        throw "Private or runtime file in release: $file"
    }
}

New-Item -ItemType Directory -Path $output -Force | Out-Null
if (Test-Path -LiteralPath $zipPath) { throw "Output already exists: $zipPath (choose another output folder)." }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
$sums = New-Object 'System.Collections.Generic.List[string]'
try {
    foreach ($file in $files) {
        $source = Join-Path $root $file
        $hash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
        $sums.Add("$hash  $file")
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $source, "$name/$file", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    foreach ($meta in @(
        @{ Name='SHA256SUMS.txt'; Text=($sums -join "`n") + "`n" },
        @{ Name='BUILD.txt'; Text="Application: 8.10.8.0`nSource commit: $commit`n" }
    )) {
        $entry = $zip.CreateEntry("$name/$($meta.Name)")
        $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
        try { $writer.Write($meta.Text) } finally { $writer.Dispose() }
    }
} finally { $zip.Dispose() }

$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'), "$zipHash  $name.zip`n", (New-Object Text.UTF8Encoding($false)))
Write-Host "Built: $zipPath"
Write-Host "Payload files: $($files.Count); SHA256: $zipHash"
