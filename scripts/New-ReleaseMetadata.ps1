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
$companionArchiveName = "Offhand-Companion-v$companionVersion.zip"
$storeUrl = 'https://apps.microsoft.com/detail/9PL4PW84Q90W'
$companionReleaseUrl = "https://github.com/$Repository/releases/tag/$Tag"

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

$changelog = Get-Content -LiteralPath $ChangelogPath -Raw -Encoding utf8
$escapedPackageVersion = [regex]::Escape($packageVersion)
$versioned = [regex]::Match(
    $changelog,
    "(?ms)^## \[$escapedPackageVersion\](?:\s+-[^\r\n]*)?\s*(?<body>.*?)(?=^## \[|\z)"
)
$unreleased = [regex]::Match(
    $changelog,
    '(?ms)^## \[Unreleased\]\s*(?<body>.*?)(?=^## \[|\z)'
)
$changes = if ($versioned.Success -and -not [string]::IsNullOrWhiteSpace($versioned.Groups['body'].Value)) {
    $versioned.Groups['body'].Value.Trim()
} elseif ($unreleased.Success -and -not [string]::IsNullOrWhiteSpace($unreleased.Groups['body'].Value)) {
    $unreleased.Groups['body'].Value.Trim()
} else {
    throw "CHANGELOG.md must contain a non-empty ## [$packageVersion] or ## [Unreleased] section."
}

$statusText = if ($isPrerelease) {
    "This is a public testing build. Back up your existing Offhand SavedVariables before installing and report regressions with the requested diagnostics."
} else {
    "This is a stable release of Offhand. Back up your existing Offhand SavedVariables before upgrading."
}

$companionDownloads = if ($CompanionChanged) {
@"
- **Companion package:** ``$companionArchiveName``: minimal portable package containing the reviewed executable, quick-start/security README, and license.
- **Standalone Companion:** ``Offhand.exe``: updated Windows executable only.
- **Source:** review the tagged repository or GitHub's automatic source archive; development files are intentionally excluded from the end-user Companion ZIP.
"@
} else {
@"
- **Companion package:** ``$companionArchiveName``: unchanged, byte-identical $companionVersion archive, named for the Companion build rather than the addon release that carries it.
- **Standalone Companion:** ``Offhand.exe``: unchanged, byte-identical $companionVersion executable.
- **Companion source release:** [$CompanionReleaseTag](https://github.com/$Repository/releases/tag/$CompanionReleaseTag).
"@
}

$testFocus = if ($Tag -eq 'v2.1.2-beta.26') {
@'
1. Back up SavedVariables, native Edit Mode layouts and UI addon profiles. Upgrade without deleting settings.
2. On Anniversary, check World Map, Spellbook, Macro and bags individually and together. Verify open-before-reload restoration and closed-before-reload intent, Escape, native NPC interactions and normal restart behavior.
3. Test default bags and each installed replacement separately. Check individual bag IDs, opening/closing layout, scale, bank and native item actions, with fresh errors and taint evidence. Recorded replacement acceptance has no exact version inventory.
4. On Retail, check normal pet-battle controls and release after topology/feature changes. Check Trading Post, native popup/toast behavior, external mover takeover and combat transitions during intended gameplay.
5. Retest setup recovery and Help & recovery for readable wrapping and scrolling. Expanded English fallback remains pending translation. Include client/build, addon/Companion versions, geometry, normal UI owners and /offhand diag.

Six Retail audit findings have assumption-based acceptance, not newly recorded live verification. Static and simulated tests do not establish taint safety. The Anniversary memory-crash report remains unresolved. Forever release-client and direct Linux/Wine checks remain pending.

Companion remains 2.1.2-beta.20. No experimental HDR/dashboard, native graphics-reset recovery or loading-art executable changes are included.
'@
} elseif ($Tag -eq 'v2.1.2-beta.25') {
@'
1. Back up SavedVariables, Blizzard Edit Mode layouts and UI addon profiles. Upgrade without deleting settings.
2. Test missing Companion geometry: apply Span WoW Now in the game world, Reload UI, then resume calibration. Check wizard centering and all text after span and restore.
3. With a full custom-layout list, click Repair HUD. Follow the guided Edit Mode recovery, delete only an unused test layout, close Edit Mode and retry. Only the reload prompt should remain after success.
4. On Retail, test real cinematic skip/cancel/resume, group confirmations, keystone and completion UI, event toasts and vehicle controls. Do not fabricate native events. Expanded candidates still require live acceptance.
5. Retest shared HUD selection across two characters, rollback, tooltips, chat persistence and normal panel behavior. Include fresh Lua and taint evidence before, during and after combat.
6. Include exact client/build, addon version, display arrangement and /offhand diag output. Other clients, translation expansion and narrow Mainhand geometry remain test targets.

Companion remains 2.1.2-beta.20. Experimental HDR/dashboard, native graphics-reset recovery and loading-art changes are not included. The Anniversary manual-span memory-crash report remains unresolved.
'@
} elseif ($Tag -eq 'v2.1.2-beta.24') {
@'
1. Back up Offhand SavedVariables, Blizzard Edit Mode layouts and UI addon profiles before upgrading. Keep existing settings for the upgrade test.
2. Move chat to the workspace, switch tabs with real incoming messages, then check placement and message separation after /reload, zoning and a normal restart. Include Ellesmere UI where used.
3. Open Spellbook and Talents on Offhand, reload with either tab open, then close them and reload again. Check the selected tab, fit and closed state.
4. Check World Map reopen, zoom and hover behavior with your normal map addon. Separate local OpenMap grain/hover patches are not included.
5. Test shared Mainhand HUD layout reuse and rollback on two characters. Check tooltips and speech bubbles near each viewport edge, particularly on stacked monitors.
6. Report fresh Lua/protected-action errors before, during and after combat, with client/build, monitor geometry, UI addons and /offhand diag output. These checks remain outstanding.

Loading artwork still uses the spanned window. Manual workaround: Restore Window before loading, then Span WoW Now after returning to the world. This is not a spanned loading-art fix.

Companion remains 2.1.2-beta.20. No Companion binary or graphics-reset recovery changes are included.
'@
} elseif ($Tag -eq 'v2.1.2-beta.23') {
@'
1. Upgrade without deleting `WTF` or Offhand SavedVariables; keep a backup for rollback.
2. Visit all five settings pages and check scrolling, sliders, typed values, profile changes and dialog fitting at your normal UI scale.
3. Check existing workspace map, bags, Character and chat placement, scaling and persistence after `/reload`.
4. Use Restore Window and Span WoW Now. Check HUD and minimap positions, XP/reputation bars, and open Options/menu usability in both modes, including after a normal restart.
5. Check normal actions before, during and after combat. Report fresh Lua/protected-action errors with the client/build, display arrangement, relevant addons and `/offhand diag` output.

This addon release retains Companion 2.1.2-beta.20. Experimental native VSync/graphics-reset recovery and graininess handling are not included.
'@
} else {
@'
1. Upgrade without deleting `WTF` or Offhand SavedVariables.
2. Trigger several simultaneous group-loot rolls before and during combat and confirm they remain visible inside Mainhand without protected-action or secret-value errors.
3. Verify floating combat, healing, damage, and XP text at the automatic scale and with the 50-150% fine-tuning control, including after `/reload` and after disabling the span.
4. Verify speech bubbles on equal-height and mixed-height layouts, including the first bubble after spanning, consecutive bubbles, the 50-150% replacement-size control, and ownership yielding when EllesmereUI customization is enabled.
5. Report the WoW client and build, display arrangement, selected Mainhand/workspace, enabled UI addons, exact Lua error, `/offhand diag` output, and before/after screenshots.
'@
}

$notes = @"
<!-- offhand-companion-version: $companionVersion -->

# $releaseName

> $statusText

## Changes in this build

$changes

## Downloads

- **Recommended Windows Companion:** [Install from Microsoft Store]($storeUrl) for a Store-signed package and Microsoft-managed updates.
- **Portable / Linux / Wine Companion:** download ``$companionArchiveName`` from the [official GitHub release]($companionReleaseUrl).
- **Complete package:** ``Offhand-Complete-v$packageVersion.zip``: addon and Companion together.
- **Addon only:** ``Offhand-v$packageVersion.zip``: install the contained ``Offhand`` folder in ``Interface/AddOns``.
$companionDownloads

## Test focus

$testFocus

## Linux and Wine status

The Companion is still a Windows WinForms application. Wine support is experimental: run WoW and the Companion as the same user in the same ``WINEPREFIX`` and with the same Wine/Proton runner version. See ``Companion/Linux.md`` in the complete package for a Lutris example and extraction checks. Native Linux, X11, and general Wayland support are not claimed by this release.

## Reporting issues

Use the [GitHub issue tracker](https://github.com/$Repository/issues) and include reproduction steps plus the diagnostics listed above.

## Verification

The Companion is unsigned. Download it only from the official release linked above. Use the attached SHA-256 checksums to verify the downloads. Locally prepared draft assets do not carry GitHub Actions build-provenance attestations; those are produced by the tagged release workflow.

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
