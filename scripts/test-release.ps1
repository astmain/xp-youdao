[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ZipPath)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
try {
    $prefix = 'YoudaoDict-8.10.8.0-Portable-Windows/'
    $entries = @{}
    foreach ($entry in $zip.Entries) {
        if (-not $entry.FullName.StartsWith($prefix) -or $entry.FullName -match '(^|/)\.\.(/|$)|\\') {
            throw "Unsafe or unexpected ZIP path: $($entry.FullName)"
        }
        $name = $entry.FullName.Substring($prefix.Length)
        if ($entries.ContainsKey($name)) { throw "Duplicate ZIP entry: $name" }
        if ($name -match '(^|/)(\.git|guid\.dat|vendor\.dat|cookies\.dat|config\.ini)$|\.(log|lnk|new|ydtmp)$') {
            throw "Runtime or private data in ZIP: $name"
        }
        $entries[$name] = $entry
    }
    foreach ($required in @('YoudaoDict.exe','start-youdao.cmd','8.10.8.0/libcef.dll',
            'scripts/start-youdao.ps1','scripts/protect-youdao.ps1','scripts/install-shortcuts.ps1',
            'THIRD-PARTY-NOTICE.md','SHA256SUMS.txt','BUILD.txt')) {
        if (-not $entries.ContainsKey($required)) { throw "Missing: $required" }
    }
    if ($entries['8.10.8.0/libcef.dll'].Length -ne 143979576) { throw 'LFS payload is not hydrated.' }
    $reader = New-Object IO.StreamReader($entries['SHA256SUMS.txt'].Open())
    try { $lines = $reader.ReadToEnd() -split "`n" | Where-Object { $_ } } finally { $reader.Dispose() }
    $checked = @{}
    foreach ($line in $lines) {
        if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw "Bad manifest line: $line" }
        $expected = $Matches[1]; $name = $Matches[2]
        if ($checked.ContainsKey($name) -or -not $entries.ContainsKey($name)) { throw "Invalid manifest entry: $name" }
        $stream = $entries[$name].Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($actual -ne $expected) { throw "Hash mismatch: $name" }
        $checked[$name] = $true
    }
    if ($checked.Count -ne ($entries.Count - 2)) { throw 'Manifest does not cover the full payload.' }
    Write-Host "PASS: $($checked.Count) payload hashes verified; no runtime data; full LFS payload included."
} finally { $zip.Dispose() }
