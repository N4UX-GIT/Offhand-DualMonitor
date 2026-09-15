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
$tempDir = Join-Path $distDir "temp"

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Offhand Release Packager v$Version" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Ensure Companion executable is compiled
Write-Host "`n[1/5] Compiling Companion executable..." -ForegroundColor Yellow
$proc = Get-Process Offhand -ErrorAction SilentlyContinue
if ($proc -and (Test-Path (Join-Path $rootDir "Companion\Offhand.exe"))) {
    Write-Host "  Note: Offhand is currently running. Using existing Companion\Offhand.exe" -ForegroundColor Yellow
} else {
    & (Join-Path $rootDir "Companion\build.bat")
    if ($LASTEXITCODE -ne 0) {
        throw "Companion build failed with exit code $LASTEXITCODE"
    }
}

# 2. Reset dist directory
Write-Host "`n[2/5] Initializing output directory: $distDir" -ForegroundColor Yellow
if (Test-Path $distDir) {
    Remove-Item -Path $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 3. Package In-Game Addon for CurseForge / Wago
Write-Host "`n[3/5] Packaging In-Game Addon (Offhand-v$Version.zip)..." -ForegroundColor Yellow
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
Copy-Item (Join-Path $rootDir "Modules") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "UI") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "Media") -Destination $addonStaging -Recurse

$addonZip = Join-Path $distDir "Offhand-v$Version.zip"
Compress-Archive -Path $addonStaging -DestinationPath $addonZip -CompressionLevel Optimal
Write-Host "  -> Created: $addonZip" -ForegroundColor Green

# 4. Package Desktop Companion for GitHub Releases
Write-Host "`n[4/5] Packaging Desktop Companion (Offhand-Companion-v$Version.zip)..." -ForegroundColor Yellow
$compStaging = Join-Path $tempDir "Offhand-Companion"
New-Item -ItemType Directory -Path $compStaging -Force | Out-Null

Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Companion.ps1") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Window.ps1") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Companion.bat") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Span.bat") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Span.ps1") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Offhand-Watcher.bat") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\LICENSE") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\README.md") -Destination $compStaging

$compZip = Join-Path $distDir "Offhand-Companion-v$Version.zip"
Compress-Archive -Path (Join-Path $compStaging "*") -DestinationPath $compZip -CompressionLevel Optimal
Write-Host "  -> Created: $compZip" -ForegroundColor Green

# Copy standalone Offhand.exe directly to dist
$standaloneExe = Join-Path $distDir "Offhand.exe"
Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $standaloneExe
Write-Host "  -> Created standalone executable: $standaloneExe" -ForegroundColor Green

# 5. Clean staging and generate SHA-256 Checksums
Write-Host "`n[5/5] Generating release checksums..." -ForegroundColor Yellow
Remove-Item -Path $tempDir -Recurse -Force

$checksumFile = Join-Path $distDir "checksums-sha256.txt"
$distFiles = Get-ChildItem -Path $distDir -File | Where-Object { $_.Name -ne "checksums-sha256.txt" }

$checksumLines = foreach ($file in $distFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    "$hash  $($file.Name)"
}
$checksumLines | Set-Content -Path $checksumFile -Encoding UTF8

Write-Host "`nRelease Artifacts Ready in dist/:" -ForegroundColor Cyan
foreach ($line in $checksumLines) {
    Write-Host "  $line" -ForegroundColor White
}

# 6. Copy standalone executable and zip to Website/downloads for direct web serving
Write-Host "`n[6/6] Updating Website/downloads artifacts..." -ForegroundColor Yellow
$webDownloads = Join-Path $rootDir "Website\downloads"
if (-not (Test-Path $webDownloads)) {
    New-Item -ItemType Directory -Path $webDownloads -Force | Out-Null
}
Copy-Item $standaloneExe -Destination (Join-Path $webDownloads "Offhand.exe") -Force
Copy-Item $compZip -Destination (Join-Path $webDownloads "Offhand-Companion.zip") -Force
Copy-Item $checksumFile -Destination (Join-Path $webDownloads "checksums-sha256.txt") -Force
Write-Host "  -> Synced: Website/downloads/Offhand.exe & Offhand-Companion.zip" -ForegroundColor Green

Write-Host "`n===================================================" -ForegroundColor Green
Write-Host "  Packaging complete successfully!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
