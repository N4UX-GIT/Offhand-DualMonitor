param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [string]$Repository = "N4UX-GIT/Offhand-DualMonitor",

    [string]$ChangelogPath = (Join-Path $PSScriptRoot "..\CHANGELOG.md"),

    [string]$OutputPath = (Join-Path $PSScriptRoot "..\dist\release-notes.md"),

    [string]$GitHubOutputPath
)

$ErrorActionPreference = "Stop"

$match = [regex]::Match($Tag, '^v(?<version>\d+\.\d+\.\d+)(?:-(?<channel>alpha|beta|rc)\.(?<number>\d+))?$')
if (-not $match.Success) {
    throw "Release tag '$Tag' must match vMAJOR.MINOR.PATCH, vMAJOR.MINOR.PATCH-beta.N, vMAJOR.MINOR.PATCH-alpha.N, or vMAJOR.MINOR.PATCH-rc.N."
}

$version = $match.Groups['version'].Value
$channel = $match.Groups['channel'].Value
$sequence = $match.Groups['number'].Value
$packageVersion = $Tag.Substring(1)
$isPrerelease = -not [string]::IsNullOrEmpty($channel)

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

$notes = @"
# $releaseName

> $statusText

## Changes in this build

$changes

## Downloads

- **Complete package:** ``Offhand-Complete-v$packageVersion.zip`` — addon and Companion together.
- **Addon only:** ``Offhand-v$packageVersion.zip`` — install the contained ``Offhand`` folder in ``Interface/AddOns``.
- **Companion package:** ``Offhand-Companion.zip`` — executable, source, documentation, and security guidance.
- **Standalone Companion:** ``Offhand.exe`` — Windows executable only.

## Test focus

1. Upgrade without deleting ``WTF`` or Offhand SavedVariables.
2. Test a cold login, ``/reload``, relog, and a complete client restart.
3. Verify the map, character sheet, bags, chat, Blizzard Edit Mode, and the Escape/Game Menu sequence.
4. Report the WoW client and build, display arrangement, selected Mainhand/workspace, enabled UI addons, exact Lua error, and before/after screenshots.

## Linux and Wine status

The Companion is still a Windows WinForms application. Wine support is experimental: run WoW and the Companion as the same user in the same ``WINEPREFIX``. Native Linux, X11, and general Wayland support are not claimed by this release.

## Reporting issues

Use the [GitHub issue tracker](https://github.com/$Repository/issues) and include reproduction steps plus the diagnostics listed above.

## Verification

The Companion is unsigned. Download it only from this official release and verify every downloaded asset against ``checksums-sha256.txt``. GitHub Actions also publishes build-provenance attestations for the release artifacts.

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
