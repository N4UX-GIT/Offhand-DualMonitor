<#
.SYNOPSIS
    Builds a Store-ready MSIX containing the Offhand Companion.

.DESCRIPTION
    The Microsoft Store assigns the final package Identity Name, Publisher,
    and Publisher Display Name when a product is reserved in Partner Center.
    Pass those exact values for a submission build. The defaults are suitable
    only for structural validation and local development.
#>
param(
    [ValidatePattern('^\d+\.\d+\.\d+\.0$')]
    [string]$PackageVersion = '2.1.13.0',

    [string]$IdentityName = 'N4UX.OffhandCompanion',
    [string]$Publisher = 'CN=E7BD7796-76DA-40C2-B114-9DD85609CD7F',
    [string]$PublisherDisplayName = 'N4UX',

    [string]$OutputDirectory,
    [switch]$UseExistingCompanion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$storeDir = $PSScriptRoot
$companionDir = Split-Path -Parent $storeDir
$rootDir = Split-Path -Parent $companionDir
$templatePath = Join-Path $storeDir 'Package.appxmanifest.template'
$companionExe = Join-Path $companionDir 'Offhand.exe'
$sourceLogo = Join-Path $rootDir 'Media\offhand-logo.png'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $rootDir 'dist\store'
}

function Find-WindowsSdkTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $kitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $kitsRoot)) {
        throw "Windows SDK tool '$Name' was not found. Install the Windows 10/11 SDK."
    }

    $tool = Get-ChildItem -LiteralPath $kitsRoot -Directory |
        Sort-Object { try { [version]$_.Name } catch { [version]'0.0' } } -Descending |
        ForEach-Object { Join-Path $_.FullName "x64\$Name" } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1

    if (-not $tool) {
        throw "Windows SDK tool '$Name' was not found beneath $kitsRoot."
    }
    return $tool
}

function Assert-ManifestValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Name cannot be empty."
    }
    if ($Value.Contains('@@')) {
        throw "$Name still contains a template marker."
    }
}

function New-StoreAsset {
    param(
        [Parameter(Mandatory = $true)][System.Drawing.Image]$Source,
        [Parameter(Mandatory = $true)][int]$Width,
        [Parameter(Mandatory = $true)][int]$Height,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(17, 17, 22))
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

        $padding = [Math]::Max(2, [int]([Math]::Min($Width, $Height) * 0.08))
        $availableWidth = $Width - (2 * $padding)
        $availableHeight = $Height - (2 * $padding)
        $scale = [Math]::Min($availableWidth / $Source.Width, $availableHeight / $Source.Height)
        $drawWidth = [Math]::Max(1, [int]($Source.Width * $scale))
        $drawHeight = [Math]::Max(1, [int]($Source.Height * $scale))
        $left = [int](($Width - $drawWidth) / 2)
        $top = [int](($Height - $drawHeight) / 2)
        $graphics.DrawImage($Source, $left, $top, $drawWidth, $drawHeight)
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

Assert-ManifestValue -Name 'IdentityName' -Value $IdentityName
Assert-ManifestValue -Name 'Publisher' -Value $Publisher
Assert-ManifestValue -Name 'PublisherDisplayName' -Value $PublisherDisplayName

if (-not (Test-Path -LiteralPath $sourceLogo -PathType Leaf)) {
    throw "Store artwork source is missing: $sourceLogo"
}

$makeAppx = Find-WindowsSdkTool -Name 'makeappx.exe'
$stagingDir = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-MSIX-' + [guid]::NewGuid().ToString('N'))
$assetsDir = Join-Path $stagingDir 'Assets'
New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

try {
    $packagedExe = Join-Path $stagingDir 'Offhand.exe'
    if ($UseExistingCompanion) {
        if (-not (Test-Path -LiteralPath $companionExe -PathType Leaf)) {
            throw "Companion executable is missing: $companionExe"
        }
        Copy-Item -LiteralPath $companionExe -Destination $packagedExe
    } else {
        & (Join-Path $companionDir 'build.bat') $packagedExe
        if ($LASTEXITCODE -ne 0) {
            throw "Companion build failed with exit code $LASTEXITCODE."
        }
    }

    Add-Type -AssemblyName System.Drawing
    $logo = [System.Drawing.Image]::FromFile($sourceLogo)
    try {
        New-StoreAsset -Source $logo -Width 50 -Height 50 -Path (Join-Path $assetsDir 'StoreLogo.png')
        New-StoreAsset -Source $logo -Width 44 -Height 44 -Path (Join-Path $assetsDir 'Square44x44Logo.png')
        New-StoreAsset -Source $logo -Width 150 -Height 150 -Path (Join-Path $assetsDir 'Square150x150Logo.png')
        New-StoreAsset -Source $logo -Width 310 -Height 150 -Path (Join-Path $assetsDir 'Wide310x150Logo.png')
        New-StoreAsset -Source $logo -Width 310 -Height 310 -Path (Join-Path $assetsDir 'Square310x310Logo.png')
    } finally {
        $logo.Dispose()
    }

    $manifest = Get-Content -LiteralPath $templatePath -Raw
    $manifest = $manifest.Replace('@@IDENTITY_NAME@@', [Security.SecurityElement]::Escape($IdentityName))
    $manifest = $manifest.Replace('@@PUBLISHER@@', [Security.SecurityElement]::Escape($Publisher))
    $manifest = $manifest.Replace('@@PACKAGE_VERSION@@', $PackageVersion)
    $manifest = $manifest.Replace('@@PUBLISHER_DISPLAY_NAME@@', [Security.SecurityElement]::Escape($PublisherDisplayName))
    $manifestPath = Join-Path $stagingDir 'AppxManifest.xml'
    $manifest | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    [xml](Get-Content -LiteralPath $manifestPath -Raw) | Out-Null

    $safeVersion = $PackageVersion.Replace('.', '_')
    $outputPath = Join-Path $OutputDirectory "Offhand-Companion_${safeVersion}_x64.msix"
    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Force
    }

    & $makeAppx pack /d $stagingDir /p $outputPath /o
    if ($LASTEXITCODE -ne 0) {
        throw "MakeAppx failed with exit code $LASTEXITCODE."
    }

    $hash = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    Write-Host "Store package created:" -ForegroundColor Green
    Write-Host "  $outputPath"
    Write-Host "  SHA-256: $hash"
    Write-Host "The package is intentionally unsigned; Microsoft signs the accepted Store submission."
    Write-Output $outputPath
} finally {
    if (Test-Path -LiteralPath $stagingDir) {
        Remove-Item -LiteralPath $stagingDir -Recurse -Force
    }
}
