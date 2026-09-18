param([string]$Version = '1.0.0')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Check-Manifest([string]$directory) {
    foreach ($line in Get-Content -LiteralPath (Join-Path $directory 'checksums-sha256.txt')) {
        if ($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') { throw "Invalid checksum entry: $line" }
        $expected = $Matches[1]
        $path = Join-Path $directory $Matches[2]
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $expected) {
            throw "Checksum mismatch: $path"
        }
    }
}

Check-Manifest (Join-Path $root 'dist')
Check-Manifest (Join-Path $root 'Website\downloads')
$builtHash = (Get-FileHash -LiteralPath (Join-Path $root 'Companion\Offhand.exe')).Hash
foreach ($path in @('dist\Offhand.exe', 'Website\downloads\Offhand.exe')) {
    if ((Get-FileHash -LiteralPath (Join-Path $root $path)).Hash -ne $builtHash) {
        throw "Executable out of date: $path"
    }
}

$addon = [IO.Compression.ZipFile]::OpenRead((Join-Path $root "dist\Offhand-v$Version.zip"))
try {
    foreach ($entry in $addon.Entries) {
        $name = $entry.FullName.Replace('\', '/')
        if ($name -match '^Offhand/Modules/') { throw 'Unloaded legacy modules in runtime package' }
        if ($name -match '\.(lua|toc)$') {
            $relative = $name -replace '^Offhand/', ''
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($hash -ne (Get-FileHash -LiteralPath (Join-Path $root $relative)).Hash) {
                throw "Stale packaged source: $name"
            }
        }
    }
    foreach ($required in @('Offhand/Offhand.toc', 'Offhand/Offhand_Vanilla.toc', 'Offhand/UI/Minimap.lua')) {
        if (-not ($addon.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq $required })) {
            throw "Missing package entry: $required"
        }
    }
} finally { $addon.Dispose() }

$companion = [IO.Compression.ZipFile]::OpenRead((Join-Path $root "dist\Offhand-Companion-v$Version.zip"))
try {
    $entry = $companion.GetEntry('Offhand.exe')
    if (-not $entry) { throw 'Companion archive has no executable' }
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($hash -ne $builtHash) { throw 'Companion archive contains a stale executable' }
} finally { $companion.Dispose() }
if ((Get-FileHash -LiteralPath (Join-Path $root "dist\Offhand-Companion-v$Version.zip")).Hash -ne
    (Get-FileHash -LiteralPath (Join-Path $root 'Website\downloads\Offhand-Companion.zip')).Hash) {
    throw 'Website companion archive differs from the built archive'
}
Write-Output 'PASS: release and website hashes, current packaged sources, TOCs and executable parity'
