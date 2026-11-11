param([Parameter(Mandatory=$true)][string]$WowPath)
$ErrorActionPreference = 'Stop'
$wowRoot = (Resolve-Path -LiteralPath $WowPath).Path.TrimEnd('\')
foreach ($client in @(Get-Process -Name Wow,WowClassic,WowB -ErrorAction SilentlyContinue)) {
    $clientPath = $client.Path
    if (-not $clientPath) { throw 'Cannot identify a running WoW client. Close it normally before installing.' }
    if ([IO.Path]::GetDirectoryName($clientPath).Equals($wowRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Close the selected WoW client normally before installing this private candidate.'
    }
}
$addons = [IO.Path]::GetFullPath((Join-Path $wowRoot 'Interface/AddOns'))
if ((-not $addons.StartsWith($wowRoot + '\', [StringComparison]::OrdinalIgnoreCase)) -or
    -not (Test-Path -LiteralPath $addons)) { throw 'Invalid explicit WoW addon directory.' }
$subject = Join-Path $PSScriptRoot 'validated-subject'
$record = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'verification.json') -Raw | ConvertFrom-Json
$archive = Join-Path $PSScriptRoot 'Offhand-discord-private-QA.zip'
if ((Get-FileHash -LiteralPath $archive).Hash -ne $record.archiveSha256) { throw 'Candidate archive hash mismatch.' }
$writes = @()
foreach ($entry in $record.files.PSObject.Properties) {
    if ($entry.Name -eq 'README-FIRST.md') { continue }
    if ($entry.Name -match '(^|/)\.\.(/|$)' -or $entry.Name -notmatch '^(Offhand|OffhandIssueProbe|OffhandPerformanceProbe)/') {
        throw 'Unexpected candidate install path.'
    }
    $relative = $entry.Name.Replace('/', '\')
    if ($relative.StartsWith('Offhand\')) {
        $source = Join-Path $subject $relative.Substring(8)
    } elseif ($relative.StartsWith('OffhandIssueProbe\')) {
        $source = Join-Path $subject ('tools/issue-capture/' + $relative)
    } else { $source = Join-Path $subject ('tools/performance/' + $relative) }
    $destination = [IO.Path]::GetFullPath((Join-Path $addons $relative))
    if (-not $destination.StartsWith($addons + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Install path escaped addon directory.' }
    if ((Get-FileHash -LiteralPath $source).Hash -ne $entry.Value) { throw "Changed staged candidate: $relative" }
    $preserve = $relative -in @('Offhand\Core\CompanionTopology.lua', 'Offhand\Core\ForeverState.lua')
    $writes += [pscustomobject]@{source=$source;destination=$destination;sha256=$entry.Value;preserve=$preserve}
}
$backup = Join-Path $PSScriptRoot ('installed-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup | Out-Null
foreach ($name in @('Offhand', 'OffhandIssueProbe', 'OffhandPerformanceProbe')) {
    $target = Join-Path $addons $name
    if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination $backup -Recurse }
}
$receipt = @()
foreach ($entry in $writes) {
    $exists = Test-Path -LiteralPath $entry.destination
    if ($entry.preserve -and $exists) {
        $receipt += [ordered]@{path=$entry.destination;sha256=(Get-FileHash -LiteralPath $entry.destination).Hash;preserved=$true}
        continue
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $entry.destination) -Force | Out-Null
    Copy-Item -LiteralPath $entry.source -Destination $entry.destination -Force
    $actual = (Get-FileHash -LiteralPath $entry.destination).Hash
    if ($actual -ne $entry.sha256) { throw "Installed hash mismatch: $($entry.destination)" }
    $receipt += [ordered]@{path=$entry.destination;sha256=$actual;preserved=$false}
}
$receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backup 'installed-receipt.json') -Encoding UTF8
Write-Output "Installed verified private candidate. Backup: $backup"
Write-Output 'SavedVariables and existing topology/recovery bridges were preserved. No app was launched.'
