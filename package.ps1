<#
.SYNOPSIS
    Packages the Offhand Addon for CurseForge and the Offhand Companion for GitHub Releases.
#>
param(
    [string]$Version = "2.1.2",
    [switch]$AddonOnly
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-PortableZip {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDirectory,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [switch]$IncludeRootDirectory
    )

    $source = (Resolve-Path -LiteralPath $SourceDirectory).Path.TrimEnd('\', '/')
    $relativeBase = if ($IncludeRootDirectory) {
        Split-Path -Parent $source
    } else {
        $source
    }
    $relativeBase = $relativeBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force
    }

    $archive = [IO.Compression.ZipFile]::Open(
        $DestinationPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $source -File -Recurse | ForEach-Object {
            $entryName = $_.FullName.Substring($relativeBase.Length).Replace('\', '/')
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $_.FullName, $entryName,
                [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }

    $validationArchive = [IO.Compression.ZipFile]::OpenRead($DestinationPath)
    try {
        $invalidEntry = $validationArchive.Entries |
            Where-Object { $_.FullName.Contains('\') } |
            Select-Object -First 1
        if ($invalidEntry) {
            throw "ZIP contains a non-portable backslash entry: $($invalidEntry.FullName)"
        }
    } finally {
        $validationArchive.Dispose()
    }
}

$rootDir = $PSScriptRoot
$distDir = Join-Path $rootDir "dist"
$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("Offhand-package-" + [guid]::NewGuid().ToString())
$stepTotal = 5
if ($AddonOnly) { $stepTotal = 3 }

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Offhand Release Packager v$Version" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Ensure Companion executable is compiled for bundles that include it. An
# addon-only CurseForge build must not replace a previously accepted Companion
# binary with a fresh, differently hashed compiler output.
if (-not $AddonOnly) {
    Write-Host "
[1/$stepTotal] Compiling Companion executable..." -ForegroundColor Yellow
    & (Join-Path $rootDir "Companion\build.bat")
    if ($LASTEXITCODE -ne 0) {
        throw "Companion build failed. Close a running companion if it locks the executable, then retry."
    }
} else {
    Write-Host "
[1/$stepTotal] Addon-only mode: preserving the accepted Companion binary." -ForegroundColor Yellow
}

# 2. Reset dist directory
Write-Host "
[2/$stepTotal] Initializing output directory: $distDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

# 3. Package In-Game Addon for CurseForge / Wago
Write-Host "
[3/$stepTotal] Packaging In-Game Addon (Offhand-v$Version.zip)..." -ForegroundColor Yellow
$addonStaging = Join-Path $tempDir "Offhand"
New-Item -ItemType Directory -Path $addonStaging -Force | Out-Null

# Copy root addon files
Copy-Item (Join-Path $rootDir "Offhand.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "Offhand_Mainline.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "Offhand_Vanilla.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "Offhand_Classic.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "Offhand_Forever.toc") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "LICENSE") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "README.md") -Destination $addonStaging
Copy-Item (Join-Path $rootDir "CHANGELOG.md") -Destination $addonStaging

# Copy addon directories
Copy-Item (Join-Path $rootDir "Core") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "Locales") -Destination $addonStaging -Recurse
Copy-Item (Join-Path $rootDir "UI") -Destination $addonStaging -Recurse

# Copy Media but ONLY .blp files!
$mediaStaging = Join-Path $addonStaging "Media"
New-Item -ItemType Directory -Path $mediaStaging -Force | Out-Null
Copy-Item (Join-Path $rootDir "Media\*.blp") -Destination $mediaStaging -Force

$addonZip = Join-Path $distDir "Offhand-v$Version.zip"
New-PortableZip -SourceDirectory $addonStaging -DestinationPath $addonZip -IncludeRootDirectory
Write-Host "  -> Created: $addonZip" -ForegroundColor Green

if ($AddonOnly) {
    $checksumFile = Join-Path $distDir "checksums-addon-v$Version-sha256.txt"
    $hash = (Get-FileHash -Path $addonZip -Algorithm SHA256).Hash
    $checksumLine = "$hash  $([IO.Path]::GetFileName($addonZip))"
    $checksumLine | Set-Content -Path $checksumFile -Encoding UTF8

    Write-Host "
CurseForge Beta artifact ready:" -ForegroundColor Cyan
    Write-Host "  $checksumLine" -ForegroundColor White
    Write-Host "  $checksumFile" -ForegroundColor White
    Write-Host "
===================================================" -ForegroundColor Green
    Write-Host "  Addon-only packaging complete successfully!" -ForegroundColor Green
    Write-Host "===================================================" -ForegroundColor Green
    return
}

# 4. Package Desktop Companion for GitHub Releases
Write-Host "
[4/5] Packaging Desktop Companion (Offhand-Companion.zip)..." -ForegroundColor Yellow
$compStaging = Join-Path $tempDir "Offhand-Companion"
New-Item -ItemType Directory -Path $compStaging -Force | Out-Null

Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\LICENSE") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\README.md") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Linux.md") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\build.bat") -Destination $compStaging
Copy-Item (Join-Path $rootDir "Companion\Source") -Destination $compStaging -Recurse
Copy-Item (Join-Path $rootDir "SECURITY.md") -Destination $compStaging
$compMedia = Join-Path $compStaging "Media"
New-Item -ItemType Directory -Path $compMedia -Force | Out-Null
Copy-Item (Join-Path $rootDir "Media\offhand-logo.ico") -Destination $compMedia
Copy-Item (Join-Path $rootDir "Media\offhand-logo-small.png") -Destination $compMedia

$compZip = Join-Path $distDir "Offhand-Companion.zip"
New-PortableZip -SourceDirectory $compStaging -DestinationPath $compZip
Write-Host "  -> Created: $compZip" -ForegroundColor Green

# Copy standalone Offhand.exe directly to dist
$standaloneExe = Join-Path $distDir "Offhand.exe"
Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination $standaloneExe
Write-Host "  -> Created standalone executable: $standaloneExe" -ForegroundColor Green


# 5. Package Complete Bundle for GitHub Releases (Addon + Companion)
Write-Host "\n[5/5] Packaging Complete Bundle (Offhand-Complete-v$Version.zip)..." -ForegroundColor Yellow
$bundleStaging = Join-Path $tempDir "Offhand-Bundle"
New-Item -ItemType Directory -Path $bundleStaging -Force | Out-Null

Copy-Item $addonStaging -Destination (Join-Path $bundleStaging "Offhand") -Recurse
Copy-Item (Join-Path $rootDir "Companion\Offhand.exe") -Destination (Join-Path $bundleStaging "Offhand-Companion.exe")
Copy-Item (Join-Path $rootDir "README.md") -Destination $bundleStaging
Copy-Item (Join-Path $rootDir "SECURITY.md") -Destination $bundleStaging
$bundleCompanionDocs = Join-Path $bundleStaging "Companion"
New-Item -ItemType Directory -Path $bundleCompanionDocs -Force | Out-Null
Copy-Item (Join-Path $rootDir "Companion\Linux.md") -Destination $bundleCompanionDocs

$bundleZip = Join-Path $distDir "Offhand-Complete-v$Version.zip"
New-PortableZip -SourceDirectory $bundleStaging -DestinationPath $bundleZip
Write-Host "  -> Created: $bundleZip" -ForegroundColor Green

# Clean staging and generate SHA-256 Checksums
Write-Host "\nGenerating release checksums..." -ForegroundColor Yellow
Write-Host "Build staging retained for inspection: $tempDir"

$checksumFile = Join-Path $distDir "checksums-sha256.txt"
$distFiles = Get-Item -LiteralPath $addonZip, $compZip, $standaloneExe, $bundleZip

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

