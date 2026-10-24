param()
$ErrorActionPreference = 'Stop'
if (@(Get-Process -Name Wow,WowClassic,WowB -ErrorAction SilentlyContinue).Count) {
    throw 'Close WoW normally before installing the temporary probe.'
}
$source = Join-Path $PSScriptRoot 'OffhandDisplayProbe'
$roots = @('D:\Games\World of Warcraft\_retail_',
    'C:\Games\World of Warcraft\_classic_era_', 'C:\Games\World of Warcraft\_anniversary_')
foreach ($root in $roots) {
    $addons = Join-Path $root 'Interface\AddOns'
    if (-not (Test-Path -LiteralPath $addons)) { throw "Missing known client addon directory: $addons" }
}
foreach ($root in $roots) {
    $target = Join-Path $root 'Interface\AddOns\OffhandDisplayProbe'
    if (Test-Path -LiteralPath $target) {
        $backup = Join-Path $PSScriptRoot ('..\..\dist\display-captures\probe-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + (Split-Path $root -Leaf))
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        Copy-Item -LiteralPath $target -Destination $backup -Recurse
    }
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    foreach ($name in @('OffhandDisplayProbe.toc','Probe.lua')) {
        $original = Join-Path $source $name
        $copy = Join-Path $target $name
        Copy-Item -LiteralPath $original -Destination $copy -Force
        if ((Get-FileHash -LiteralPath $original).Hash -ne (Get-FileHash -LiteralPath $copy).Hash) {
            throw "Probe verification failed: $copy"
        }
    }
    Write-Output "Installed and verified temporary probe: $target"
}
Write-Output 'Existing Offhand, Companion, generated bridges and saved settings were not modified.'
