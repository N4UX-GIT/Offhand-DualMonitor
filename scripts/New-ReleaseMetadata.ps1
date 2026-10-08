param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [string]$Repository = "N4UX-GIT/Offhand-DualMonitor",

    [string]$ChangelogPath,

    [string]$OutputPath,

    [string]$GitHubOutputPath,

    [string]$CompanionReleaseTag = 'v2.1.2-beta.20',

    [switch]$CompanionChanged
)

$ErrorActionPreference = "Stop"

# Windows PowerShell evaluates parameter default expressions before it reliably
# exposes $PSScriptRoot. Resolve script-relative defaults after binding so the
# same release metadata command works locally and in GitHub's powershell shell.
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ChangelogPath)) {
    $ChangelogPath = Join-Path $scriptRoot "..\CHANGELOG.md"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $scriptRoot "..\dist\release-notes.md"
}

$match = [regex]::Match($Tag, '^v(?<version>\d+\.\d+\.\d+)(?:-(?<channel>alpha|beta|rc)\.(?<number>\d+))?$')
if (-not $match.Success) {
    throw "Release tag '$Tag' must match vMAJOR.MINOR.PATCH, vMAJOR.MINOR.PATCH-beta.N, vMAJOR.MINOR.PATCH-alpha.N, or vMAJOR.MINOR.PATCH-rc.N."
}

$version = $match.Groups['version'].Value
$channel = $match.Groups['channel'].Value
$sequence = $match.Groups['number'].Value
$packageVersion = $Tag.Substring(1)
$isPrerelease = -not [string]::IsNullOrEmpty($channel)

$companionTagMatch = [regex]::Match($CompanionReleaseTag, '^v(?<version>\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?)$')
if (-not $companionTagMatch.Success) {
    throw "Companion release tag '$CompanionReleaseTag' is invalid."
}
$companionVersion = if ($CompanionChanged) { $packageVersion } else { $companionTagMatch.Groups['version'].Value }

$channelName = switch ($channel) {
    'alpha' { 'Alpha' }
    'beta' { 'Beta' }
    'rc' { 'Release Candidate' }
    default { $null }
}

$releaseName = if ($isPrerelease) {
    "Offhand v$version $channelName $sequence"
} else {
    "Offhand v$version"
}

if (-not (Test-Path -LiteralPath $ChangelogPath)) {
    throw "Changelog not found: $ChangelogPath"
}

$changelog = Get-Content -LiteralPath $ChangelogPath -Raw
$unreleased = [regex]::Match(
    $changelog,
    '(?ms)^## \[Unreleased\]\s*(?<body>.*?)(?=^## \[|\z)'
)
if (-not $unreleased.Success -or [string]::IsNullOrWhiteSpace($unreleased.Groups['body'].Value)) {
    throw "CHANGELOG.md must contain a non-empty ## [Unreleased] section."
}
$changes = $unreleased.Groups['body'].Value.Trim()

$statusText = if ($isPrerelease) {
    "This is a public testing build. Back up your existing Offhand SavedVariables before installing and report regressions with the requested diagnostics."
} else {
    "This is a stable release of Offhand. Back up your existing Offhand SavedVariables before upgrading."
}

$companionDownloads = if ($CompanionChanged) {
@"
- **Companion package:** ``Offhand-Companion.zip`` — minimal portable package containing the reviewed executable, quick-start/security README, and license.
- **Standalone Companion:** ``Offhand.exe`` — updated Windows executable only.
- **Source:** review the tagged repository or GitHub's automatic source archive; development files are intentionally excluded from the end-user Companion ZIP.
"@
} else {
@"
- **Companion package:** ``Offhand-Companion.zip`` — unchanged, byte-identical $companionVersion archive retained so the permanent ``releases/latest/download`` link continues to work.
- **Standalone Companion:** ``Offhand.exe`` — unchanged, byte-identical $companionVersion executable.
- **Companion source release:** [$CompanionReleaseTag](https://github.com/$Repository/releases/tag/$CompanionReleaseTag).
"@
}

$notes = @"
<!-- offhand-companion-version: $companionVersion -->

# $releaseName

> $statusText

## Changes in this build

$changes

## Downloads

- **Complete package:** ``Offhand-Complete-v$packageVersion.zip`` — addon and Companion together.
- **Addon only:** ``Offhand-v$packageVersion.zip`` — install the contained ``Offhand`` folder in ``Interface/AddOns``.
$companionDownloads

## Test focus

1. Upgrade without deleting ``WTF`` or Offhand SavedVariables.
2. Test a cold login, ``/reload``, relog, and a complete client restart.
3. Verify the map, character sheet, bags, chat, Blizzard Edit Mode, and the Escape/Game Menu sequence.
4. Report the WoW client and build, display arrangement, selected Mainhand/workspace, enabled UI addons, exact Lua error, and before/after screenshots.

## Linux and Wine status

The Companion is still a Windows WinForms application. Wine support is experimental: run WoW and the Companion as the same user in the same ``WINEPREFIX`` and with the same Wine/Proton runner version. See ``Companion/Linux.md`` in the complete package for a Lutris example and extraction checks. Native Linux, X11, and general Wayland support are not claimed by this release.

## Reporting issues

Use the [GitHub issue tracker](https://github.com/$Repository/issues) and include reproduction steps plus the diagnostics listed above.

## Verification

The Companion is unsigned. Download it only from the official release linked above. GitHub Actions publishes build-provenance attestations and SHA-256 checksums for newly packaged release artifacts.

[Full changelog](https://github.com/$Repository/blob/$Tag/CHANGELOG.md)
"@

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$notes | Set-Content -LiteralPath $OutputPath -Encoding utf8

if ($GitHubOutputPath) {
    @(
        "release_name=$releaseName"
        "prerelease=$($isPrerelease.ToString().ToLowerInvariant())"
        "package_version=$packageVersion"
    ) | Add-Content -LiteralPath $GitHubOutputPath -Encoding utf8
}

[pscustomobject]@{
    Tag = $Tag
    ReleaseName = $releaseName
    Prerelease = $isPrerelease
    PackageVersion = $packageVersion
    NotesPath = (Resolve-Path -LiteralPath $OutputPath).Path
}
