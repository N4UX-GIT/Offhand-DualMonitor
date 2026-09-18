<#
.SYNOPSIS
    Packages the Offhand Addon for CurseForge and the Offhand Companion for GitHub Releases.
#>
param(
    [string]$Version = "1.0.1"
)

$ErrorActionPreference = "Stop"
$rootDir = $PSScriptRoot
$distDir = Join-Path $rootDir "dist"
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("Offhand-package-" + [guid]::NewGuid().ToString())

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Offhand Release Packager v$Version" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Ensure Companion executable is compiled
Write-Host "
[1/4] Compiling Companion executable..." -ForegroundColor Yellow
& (Join-Path $rootDir "Companion\build.bat")
if ($LASTEXITCODE -ne 0) {
    throw "Companion build failed. Close a running companion if it locks the executable, then retry."
}

# 2. Reset dist directory
Write-Host "
[2/4] Initializing output directory: $distDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 3. Package In-Game Addon for CurseForge / Wago
Write-Host "
[3/4] Packaging In-Game Addon (Offhand-v$Version.zip)..." -ForegroundColor Yellow
$addonStaging = Join-Path $tempDir "Offhand"
New-Item -ItemType Directory -Path $addonStaging -Force | Out-Null

# Copy root addon files
Copy-Item (Join-Path $rootDir "Offhand.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "Offhand_Vanilla.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "LICENSE") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "README.md") -Destination $addonStaging

# Copy addon directories
Copy-Item (Join-Path $rootDir "Core") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "Locales") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "UI") -Destination $addonStaging -Recurse

# Copy Media but ONLY .blp files!
$mediaStaging = Join-Path $addonStaging "Media"
New-Item -ItemType Directory -Path $mediaStaging -Force | Out-Null
Copy-Item (Join-Path $rootDir "Media\*.blp") -Destination $mediaStaging -Force

$addonZip = Join-Path $distDir "Offhand-v$Version.zip"
Compress-Archive -Path $addonStaging -DestinationPath $addonZip -CompressionLevel Optimal -Force
Write-Host "  -> Created: $addonZip" -ForegroundColor Green

# 4. Package Desktop Companion for GitHub Releases
Write-Host "
[4/4] Packaging Desktop Companion (Offhand-Companion-v$Version.zip)..." -ForegroundColor Yellow
$compStaging = Join-Path $tempDir "Offhand-Companion"
New-Item -ItemType Directory -Path $compStaging -Force | Out-Null

Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\LICENSE") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\README.md") -Destination $compStaging

$compZip = Join-Path $distDir "Offhand-Companion-v$Version.zip"
Compress-Archive -Path (Join-Path $compStaging "*") -DestinationPath $compZip -CompressionLevel Optimal -Force
Write-Host "  -> Created: $compZip" -ForegroundColor Green

# Copy standalone Offhand.exe directly to dist
$standaloneExe = Join-Path $distDir "Offhand.exe"
Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $standaloneExe
Write-Host "  -> Created standalone executable: $standaloneExe" -ForegroundColor Green

# Clean staging and generate SHA-256 Checksums
Write-Host "
Generating release checksums..." -ForegroundColor Yellow
Write-Host "Build staging retained for inspection: $tempDir"

$checksumFile = Join-Path $distDir "checksums-sha256.txt"
$distFiles = Get-Item -LiteralPath $addonZip, $compZip, $standaloneExe

$checksumLines = foreach ($file in $distFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    "$hash  $($file.Name)"
}
$checksumLines | Set-Content -Path $checksumFile -Encoding UTF8

Write-Host "
Release Artifacts Ready in dist/:" -ForegroundColor Cyan
foreach ($line in $checksumLines) {
    Write-Host "  $line" -ForegroundColor White
}

Write-Host "
===================================================" -ForegroundColor Green
Write-Host "  Packaging complete successfully!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
