$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$output=Join-Path $root ('dist/beta29-notes-test-'+[guid]::NewGuid().ToString('N')+'.md')
$metadata=& (Join-Path $root 'scripts/New-ReleaseMetadata.ps1') -Tag v2.1.5-beta.29 -CompanionReleaseTag v2.1.5 -ChangelogPath (Join-Path $root 'docs/RELEASE-CHANGELOG-BETA29.md') -OutputPath $output
if(-not $metadata.Prerelease -or $metadata.ReleaseName -ne 'Offhand v2.1.5 Pre-Release Beta 29'){throw 'Beta 29 identity must remain a prerelease'}
$text=[IO.File]::ReadAllText($output)
foreach($required in @('offhand-companion-version: 2.1.5','Offhand-Complete-v2.1.5-beta.29.zip','Offhand-v2.1.5-beta.29.zip','Offhand-Companion-v2.1.5.zip','Real simultaneous loot rolls','DaylightUI','ProcDoc','Retail friendly-name correction is deferred')){
 if(-not $text.Contains($required)){throw ('Beta 29 notes missing '+$required)}
}
if($text.Contains('Companion-v2.1.2-beta.20') -or $text.Contains('This is a stable release')){throw 'Beta 29 notes contain stale release identity'}
Write-Output 'PASS: Beta 29 metadata, friendly changes, accepted testing limits and frozen Companion links'
