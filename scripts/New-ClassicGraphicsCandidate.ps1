param([string]$OutputDirectory,[switch]$Retail,[switch]$Forever)
$ErrorActionPreference = 'Stop'
if ($Retail -and $Forever) { throw 'Choose one client scope.' }
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root $(if ($Forever) { 'dist\forever-graphics-test5' } elseif ($Retail) { 'dist\retail-graphics-test4' } else { 'dist\classic-graphics-test3' }) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if ($output -eq (Join-Path $root 'Companion')) { throw 'Candidate must not replace the public Companion directory.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
$publicBinary = Join-Path $root 'Companion\Offhand.exe'
$publicHash = (Get-FileHash -LiteralPath $publicBinary).Hash
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$binary = Join-Path $output 'Offhand.exe'
if (Test-Path -LiteralPath $binary) { throw 'Use a fresh candidate directory; an existing candidate will not be overwritten.' }
$define = if ($Forever) { 'FOREVER_GRAPHICS_RECOVERY_TEST' } elseif ($Retail) { 'RETAIL_GRAPHICS_RECOVERY_TEST' } else { 'CLASSIC_GRAPHICS_RECOVERY_TEST' }
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu "/define:$define" "/out:$binary" "/win32icon:$root\Media\offhand-logo.ico" "/win32manifest:$root\Companion\Source\app.manifest" "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root 'Companion\Source\Program.cs')
if ($LASTEXITCODE -ne 0) { throw 'Candidate compilation failed' }
if ((Get-FileHash -LiteralPath $publicBinary).Hash -ne $publicHash) { throw 'Frozen Companion changed unexpectedly' }
Copy-Item -LiteralPath (Join-Path $root 'Companion\LICENSE') -Destination (Join-Path $output 'LICENSE')
Copy-Item -LiteralPath (Join-Path $root $(if ($Forever) { 'docs\FOREVER-GRAPHICS-TEST.md' } elseif ($Retail) { 'docs\RETAIL-GRAPHICS-TEST.md' } else { 'docs\CLASSIC-GRAPHICS-TEST.md' })) -Destination (Join-Path $output 'README.md')
$manifest = [ordered]@{
    candidate=$(if ($Forever) { 'Beta 20 FOREVER GRAPHICS TEST 5' } elseif ($Retail) { 'Beta 20 RETAIL GRAPHICS TEST 4' } else { 'Beta 20 CLASSIC GRAPHICS TEST 3' }); buildDefine=$define;
    sourceSha256=(Get-FileHash -LiteralPath (Join-Path $root 'Companion\Source\Program.cs')).Hash;
    binarySha256=(Get-FileHash -LiteralPath $binary).Hash; frozenPublicSha256=$publicHash;
    builtUtc=[DateTime]::UtcNow.ToString('o'); retailRecoveryEnabled=[bool]$Retail; foreverRecoveryEnabled=[bool]$Forever; liveVerification='pending'
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'candidate.json') -Encoding UTF8
$archive = $output + '.zip'
if (Test-Path -LiteralPath $archive) { throw 'Candidate archive already exists; use a new output directory.' }
Compress-Archive -LiteralPath $binary,(Join-Path $output 'LICENSE'),(Join-Path $output 'README.md'),(Join-Path $output 'candidate.json') -DestinationPath $archive
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    $entry = $zip.GetEntry('Offhand.exe')
    if (-not $entry) { throw 'Packaged executable missing' }
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $packagedHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($packagedHash -ne $manifest.binarySha256) { throw 'Candidate archive byte verification failed' }
} finally { $zip.Dispose() }
[pscustomobject]@{Binary=$binary;Archive=$archive;Sha256=$manifest.binarySha256;FrozenPublicUnchanged=$true}
