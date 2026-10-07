param(
    [Parameter(Mandatory = $true)][string]$BinaryPath,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$Version = '2.1.2-beta.19'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$binary = (Resolve-Path -LiteralPath $BinaryPath).Path
$output = [IO.Path]::GetFullPath($OutputPath)
$hash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
$temp = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-companion-test-' + [guid]::NewGuid().ToString())

try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $temp 'Offhand.exe')
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $temp 'LICENSE')
    $readme = (Get-Content -LiteralPath (Join-Path $root 'Companion\PORTABLE-README.txt') -Raw).
        Replace('{{VERSION}}', $Version).
        Replace('{{EXE_SHA256}}', $hash)
    [IO.File]::WriteAllText((Join-Path $temp 'README.txt'), $readme, [Text.UTF8Encoding]::new($false))

    $outputDirectory = Split-Path -Parent $output
    if ($outputDirectory) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
    if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Force }

    $archive = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in Get-ChildItem -LiteralPath $temp -File | Sort-Object Name) {
            $entry = $archive.CreateEntry($file.Name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
            $input = [IO.File]::OpenRead($file.FullName)
            $destination = $entry.Open()
            try { $input.CopyTo($destination) }
            finally { $destination.Dispose(); $input.Dispose() }
        }
    } finally { $archive.Dispose() }

    $verification = [IO.Compression.ZipFile]::OpenRead($output)
    try {
        $entries = @($verification.Entries | ForEach-Object FullName | Sort-Object)
        $expected = @('LICENSE', 'Offhand.exe', 'README.txt')
        if (($entries -join '|') -ne ($expected -join '|')) {
            throw 'Test archive does not contain exactly LICENSE, Offhand.exe, and README.txt.'
        }
        $exeEntry = $verification.GetEntry('Offhand.exe')
        $stream = $exeEntry.Open()
        try {
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $embeddedHash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
            finally { $sha.Dispose() }
        } finally { $stream.Dispose() }
        if ($embeddedHash -ne $hash) { throw 'Embedded executable differs from the supplied candidate.' }
    } finally { $verification.Dispose() }

    [pscustomobject]@{
        Binary = $binary
        BinarySha256 = $hash
        Archive = $output
        ArchiveSha256 = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
    }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
