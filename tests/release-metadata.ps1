$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'scripts\New-ReleaseMetadata.ps1'
$projectChangelog = Join-Path $root 'CHANGELOG.md'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-release-metadata-' + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    $changelog = Join-Path $temp 'CHANGELOG.md'
    @"
# Changelog

## [Unreleased]

### Fixed
- Release metadata fixture.
"@ | Set-Content -LiteralPath $changelog -Encoding utf8

    $betaNotes = Join-Path $temp 'beta.md'
    $betaOutput = Join-Path $temp 'beta-output.txt'
    $beta = & $script -Tag 'v2.1.2-beta.5' -ChangelogPath $changelog -OutputPath $betaNotes -GitHubOutputPath $betaOutput
    if ($beta.ReleaseName -ne 'Offhand v2.1.2 Beta 5' -or -not $beta.Prerelease) {
        throw 'Beta release metadata is not standardized.'
    }
    $betaBody = Get-Content -LiteralPath $betaNotes -Raw
    foreach ($required in @(
        '<!-- offhand-companion-version: 2.1.2-beta.20 -->',
        '# Offhand v2.1.2 Beta 5',
        '## Changes in this build',
        '## Downloads',
        '## Test focus',
        'group-loot rolls',
        'floating combat, healing, damage, and XP text',
        'speech bubbles on equal-height and mixed-height layouts',
        '/offhand diag',
        '## Linux and Wine status',
        '## Reporting issues',
        '## Verification',
        '**Recommended Windows Companion:**',
        'https://apps.microsoft.com/detail/9PL4PW84Q90W',
        '**Portable / Linux / Wine Companion:**',
        'Offhand-Complete-v2.1.2-beta.5.zip',
        '**Companion package:**',
        '**Standalone Companion:**',
        'byte-identical 2.1.2-beta.20',
        'Offhand-Companion-v2.1.2-beta.20.zip'
    )) {
        if (-not $betaBody.Contains($required)) {
            throw "Beta release notes are missing: $required"
        }
    }
    if ($betaBody.Contains('updated Windows executable only')) {
        throw 'Addon-only release notes must identify the attached Companion as frozen, not updated.'
    }

    $companionNotes = Join-Path $temp 'companion.md'
    & $script -Tag 'v2.1.2-beta.20' -ChangelogPath $changelog -OutputPath $companionNotes -CompanionChanged | Out-Null
    $companionBody = Get-Content -LiteralPath $companionNotes -Raw
    foreach ($required in @('<!-- offhand-companion-version: 2.1.2-beta.20 -->', '**Recommended Windows Companion:**', 'https://apps.microsoft.com/detail/9PL4PW84Q90W', '**Portable / Linux / Wine Companion:**', '**Companion package:**', 'Offhand-Companion-v2.1.2-beta.20.zip', '**Standalone Companion:**')) {
        if (-not $companionBody.Contains($required)) {
            throw "Companion release notes are missing: $required"
        }
    }
    if ($companionBody -notmatch 'minimal portable package' -or
        $companionBody -match 'updated executable, source') {
        throw 'Companion release notes must describe the minimal runtime-only archive.'
    }
    $outputs = Get-Content -LiteralPath $betaOutput -Raw
    if ($outputs -notmatch '(?m)^release_name=Offhand v2\.1\.2 Beta 5\r?$' -or
        $outputs -notmatch '(?m)^prerelease=true\r?$' -or
        $outputs -notmatch '(?m)^package_version=2\.1\.2-beta\.5\r?$') {
        throw 'GitHub Actions outputs are incorrect for beta tags.'
    }

    $rc = & $script -Tag 'v3.0.0-rc.2' -ChangelogPath $changelog -OutputPath (Join-Path $temp 'rc.md')
    if ($rc.ReleaseName -ne 'Offhand v3.0.0 Release Candidate 2' -or -not $rc.Prerelease) {
        throw 'Release-candidate metadata is not standardized.'
    }

    $stable = & $script -Tag 'v3.0.0' -ChangelogPath $changelog -OutputPath (Join-Path $temp 'stable.md') -CompanionChanged
    if ($stable.ReleaseName -ne 'Offhand v3.0.0' -or $stable.Prerelease) {
        throw 'Stable release metadata is not standardized.'
    }

    $invalidFailed = $false
    try {
        & $script -Tag '3.0.0-beta-2' -ChangelogPath $changelog -OutputPath (Join-Path $temp 'invalid.md') | Out-Null
    } catch {
        $invalidFailed = $true
    }
    if (-not $invalidFailed) {
        throw 'Invalid release tags must be rejected.'
    }

    $addonOnlyStable = & $script -Tag 'v2.1.3' -ChangelogPath $changelog -OutputPath (Join-Path $temp 'addon-only-stable.md')
    if ($addonOnlyStable.ReleaseName -ne 'Offhand v2.1.3' -or $addonOnlyStable.Prerelease) {
        throw 'Addon-only stable releases must remain independent of the Companion version.'
    }
    $futureAddonNotes = Join-Path $temp 'future-addon.md'
    & $script -Tag 'v2.1.2-beta.21' -CompanionReleaseTag 'v2.1.2-beta.20' -ChangelogPath $projectChangelog -OutputPath $futureAddonNotes | Out-Null
    $futureAddonBody = Get-Content -LiteralPath $futureAddonNotes -Raw
    if ($futureAddonBody -notmatch '<!-- offhand-companion-version: 2\.1\.2-beta\.20 -->') {
        throw 'Addon-only release metadata must advertise the frozen Companion version rather than the addon tag.'
    }
    if (-not $futureAddonBody.Contains('https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/tag/v2.1.2-beta.21')) {
        throw 'The versioned frozen Companion asset must link to the addon release that attaches it.'
    }
    if (-not $futureAddonBody.Contains('/offhand diag') -or $futureAddonBody.Contains('Release metadata fixture.')) {
        throw 'Beta 21 release metadata must use the exact versioned changelog section instead of Unreleased.'
    }
    $misdecodedEnDash = ([char]0x00e2).ToString() + [char]0x20ac + [char]0x201c
    if ($futureAddonBody.Contains($misdecodedEnDash) -or -not $futureAddonBody.Contains('50-150% fine-tuning control')) {
        throw 'Release metadata must preserve UTF-8 changelog text and keep generated test-focus text encoding-safe.'
    }

    Write-Output 'PASS: standardized beta, release-candidate, stable, and invalid release metadata'
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
