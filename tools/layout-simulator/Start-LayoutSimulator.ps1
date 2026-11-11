[CmdletBinding()]
param(
    [switch]$SelfTest,
    [switch]$ListPresets,
    [string]$AddonRoot = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
if ([string]::IsNullOrWhiteSpace($AddonRoot)) {
    $AddonRoot = $repoRoot
}

$sourceFile = Join-Path $scriptDir "LayoutSimulator.cs"
if (-not (Test-Path -LiteralPath $sourceFile)) {
    throw "Simulator source not found: $sourceFile"
}

$cscPath = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path -LiteralPath $cscPath)) {
    throw ".NET Framework C# compiler not found at $cscPath"
}

$buildDir = Join-Path $env:TEMP "OffhandLayoutSimulator"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$exePath = Join-Path $buildDir "OffhandLayoutSimulator.exe"

$targetType = if ($SelfTest -or $ListPresets) { "exe" } else { "winexe" }

& $cscPath /nologo /target:$targetType /optimize+ `
    /r:System.dll `
    /r:System.Drawing.dll `
    /r:System.Windows.Forms.dll `
    /out:$exePath `
    $sourceFile

if ($LASTEXITCODE -ne 0) {
    throw "Failed to compile OffhandLayoutSimulator.exe (exit code $LASTEXITCODE)."
}

if ($ListPresets) {
    & $exePath --list-presets --addon-root $AddonRoot
    exit $LASTEXITCODE
}

if ($SelfTest) {
    & $exePath --self-test --addon-root $AddonRoot
    exit $LASTEXITCODE
}

Write-Host "Launching Offhand Virtual Monitor & Layout Simulator..." -ForegroundColor Cyan
Start-Process -FilePath $exePath -ArgumentList @("--addon-root", "`"$AddonRoot`"") -WorkingDirectory $repoRoot
