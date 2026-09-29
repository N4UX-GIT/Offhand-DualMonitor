<#
.SYNOPSIS
    Packages the Offhand addon with the frozen Beta 13 Companion unless an
    intentional Companion update is explicitly requested.
#>
param(
    [string]$Version = "2.1.2-beta.13",
    [switch]$AddonOnly,
    [switch]$CompanionChanged,
    [switch]$UseExistingCompanion
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

# The published Beta 13 executable is the default Companion for every addon-only
# release. A new Companion build must be explicitly requested.
$frozenCompanionTag = "v2.1.2-beta.13"
$frozenCompanionSha256 = "E41E043EFCBB01936155FA0C8A8634F8DF80D7A83599BB5D583F1ECF6B07AEBE"
$companionExe = Join-Path $rootDir "Companion\Offhand.exe"
if ($CompanionChanged -and $AddonOnly) {
    throw "-CompanionChanged cannot be combined with -AddonOnly."
}

if ($CompanionChanged -and -not $UseExistingCompanion) {
    Write-Host "
[1/$stepTotal] Companion change explicitly requested; compiling executable..." -ForegroundColor Yellow
    & (Join-Path $rootDir "Companion\build.bat")
    if ($LASTEXITCODE -ne 0) {
        throw "Companion build failed. Close a running companion if it locks the executable, then retry."
    }
} elseif ($AddonOnly) {
    Write-Host "
[1/$stepTotal] Addon-only mode: preserving the accepted Companion binary." -ForegroundColor Yellow
} elseif ($CompanionChanged) {
    Write-Host "
[1/$stepTotal] Companion change explicitly requested; using the prebuilt executable." -ForegroundColor Yellow
} else {
    Write-Host "
[1/$stepTotal] Using frozen Companion $frozenCompanionTag." -ForegroundColor Yellow
}

if (-not $AddonOnly -and -not (Test-Path -LiteralPath $companionExe -PathType Leaf)) {
    throw "Canonical Companion executable is missing: $companionExe"
}

if (-not $AddonOnly -and -not $CompanionChanged) {
    $actualCompanionHash = (Get-FileHash -LiteralPath $companionExe -Algorithm SHA256).Hash
    if ($actualCompanionHash -ne $frozenCompanionSha256) {
        throw "Addon-only releases require the published $frozenCompanionTag Companion (SHA-256 $frozenCompanionSha256), but $companionExe is $actualCompanionHash. Run scripts\Restore-FrozenCompanion.ps1 or use -CompanionChanged only when the Companion itself was intentionally updated."
    }
}

# 2. Reset dist directory
Write-Host "
[2/$stepTotal] Initializing output directory: $distDir" -ForegroundColor Yellow
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
if (-not $CompanionChanged) {
    # Prevent old locally generated Companion artifacts from being mistaken for
    # outputs of an addon-only release.
    foreach ($staleCompanionArtifact in @(
        (Join-Path $distDir "Offhand-Companion.zip"),
        (Join-Path $distDir "Offhand.exe")
    )) {
        if (Test-Path -LiteralPath $staleCompanionArtifact) {
            Remove-Item -LiteralPath $staleCompanionArtifact -Force
        }
    }
}

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

# 4. Companion-only artifacts exist only for an intentional Companion update.
$compZip = Join-Path $distDir "Offhand-Companion.zip"
$standaloneExe = Join-Path $distDir "Offhand.exe"
if ($CompanionChanged) {
    Write-Host "
[4/5] Packaging updated Desktop Companion (Offhand-Companion.zip)..." -ForegroundColor Yellow
    $compStaging = Join-Path $tempDir "Offhand-Companion"
    New-Item -ItemType Directory -Path $compStaging -Force | Out-Null

    Copy-Item $companionExe -Destination $compStaging
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

    New-PortableZip -SourceDirectory $compStaging -DestinationPath $compZip
    Copy-Item $companionExe -Destination $standaloneExe
    Write-Host "  -> Created: $compZip" -ForegroundColor Green
    Write-Host "  -> Created standalone executable: $standaloneExe" -ForegroundColor Green
} else {
    Write-Host "
[4/5] Skipping Companion-only artifacts; $frozenCompanionTag remains canonical." -ForegroundColor Yellow
}


# 5. Package Complete Bundle for GitHub Releases (Addon + Companion)
Write-Host "\n[5/5] Packaging Complete Bundle (Offhand-Complete-v$Version.zip)..." -ForegroundColor Yellow
$bundleStaging = Join-Path $tempDir "Offhand-Bundle"
New-Item -ItemType Directory -Path $bundleStaging -Force | Out-Null

Copy-Item $addonStaging -Destination (Join-Path $bundleStaging "Offhand") -Recurse
Copy-Item $companionExe -Destination (Join-Path $bundleStaging "Offhand.exe")
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
$artifactPaths = @($addonZip, $bundleZip)
if ($CompanionChanged) {
    $artifactPaths += @($compZip, $standaloneExe)
}
$distFiles = Get-Item -LiteralPath $artifactPaths

$checksumLines = foreach ($file in $distFiles) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash
    "$hash  $($file.Name)"
}
$checksumLines | Set-Content -Path $checksumFile -Encoding UTF8

$canonicalCompanionHash = (Get-FileHash -LiteralPath $companionExe -Algorithm SHA256).Hash
if ($CompanionChanged -and (Get-FileHash -LiteralPath $standaloneExe -Algorithm SHA256).Hash -ne $canonicalCompanionHash) {
    throw "Standalone release contains a different executable than the canonical Companion build."
}

$archiveChecks = @(@{ Path = $bundleZip; Entry = 'Offhand.exe'; Label = 'Complete archive' })
if ($CompanionChanged) {
    $archiveChecks += @{ Path = $compZip; Entry = 'Offhand.exe'; Label = 'Companion archive' }
}
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
    foreach ($check in $archiveChecks) {
        $archive = [IO.Compression.ZipFile]::OpenRead($check.Path)
        try {
            $entry = $archive.GetEntry($check.Entry)
            if ($null -eq $entry) {
                throw "$($check.Label) is missing $($check.Entry)."
            }
            $stream = $entry.Open()
            try {
                $entryHash = [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '')
            } finally {
                $stream.Dispose()
            }
            if ($entryHash -ne $canonicalCompanionHash) {
                throw "$($check.Label) contains a different executable than the canonical Companion build."
            }
        } finally {
            $archive.Dispose()
        }
    }
} finally {
    $sha256.Dispose()
}

Write-Host "  Canonical Companion SHA-256: $canonicalCompanionHash" -ForegroundColor White
if (-not $CompanionChanged) {
    Write-Host "  Companion policy: frozen at $frozenCompanionTag" -ForegroundColor White
}

Write-Host "
Release Artifacts Ready in dist/:" -ForegroundColor Cyan
foreach ($line in $checksumLines) {
    Write-Host "  $line" -ForegroundColor White
}

Write-Host "
===================================================" -ForegroundColor Green
Write-Host "  Packaging complete successfully!" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green

