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

    $beta23Notes = Join-Path $temp 'beta23.md'
    & $script -Tag 'v2.1.2-beta.23' -ChangelogPath $projectChangelog -OutputPath $beta23Notes | Out-Null
    $beta23Body = Get-Content -LiteralPath $beta23Notes -Raw -Encoding utf8
    foreach ($required in @('Restore Window', 'Span WoW Now', 'Experimental native VSync/graphics-reset recovery and graininess handling are not included.', 'byte-identical 2.1.2-beta.20', 'Reorganized addon services')) {
        if (-not $beta23Body.Contains($required)) { throw "Beta 23 release scope missing: $required" }
    }
    if ($beta23Body.Contains([char]0x2014)) { throw 'Beta 23 presented release notes must not contain em dashes.' }

    $beta24Notes = Join-Path $temp 'beta24.md'
    & $script -Tag 'v2.1.2-beta.24' -ChangelogPath $projectChangelog -OutputPath $beta24Notes | Out-Null
    $beta24Body = Get-Content -LiteralPath $beta24Notes -Raw -Encoding utf8
    foreach ($required in @('Panels closed before reload now stay closed.', 'World Map native panel registration', 'Separate local OpenMap grain/hover patches are not included.', 'two characters', 'not a spanned loading-art fix', 'byte-identical 2.1.2-beta.20')) {
        if (-not $beta24Body.Contains($required)) { throw "Beta 24 release scope missing: $required" }
    }
    if ($beta24Body.Contains([char]0x2014)) { throw 'Beta 24 presented release notes must not contain em dashes.' }

    $beta25Notes = Join-Path $temp 'beta25.md'
    & $script -Tag 'v2.1.2-beta.25' -ChangelogPath $projectChangelog -OutputPath $beta25Notes | Out-Null
    $beta25Body = Get-Content -LiteralPath $beta25Notes -Raw -Encoding utf8
    foreach ($required in @('full', 'Repair HUD', 'Reload UI', 'Expanded candidates still require live acceptance.', 'byte-identical 2.1.2-beta.20', 'memory-crash report remains unresolved')) {
        if (-not $beta25Body.Contains($required)) { throw "Beta 25 release scope missing: $required" }
    }
    if ($beta25Body.Contains([char]0x2014)) { throw 'Beta 25 release notes must not contain em dashes.' }

    $beta26Notes = Join-Path $temp 'beta26.md'
    & $script -Tag 'v2.1.2-beta.26' -ChangelogPath $projectChangelog -OutputPath $beta26Notes | Out-Null
    $beta26Body = Get-Content -LiteralPath $beta26Notes -Raw -Encoding utf8
    foreach ($required in @('Anniversary panels and bags', 'pet-battle controls', 'assumption-based acceptance', 'memory-crash report remains unresolved', 'byte-identical 2.1.2-beta.20')) {
        if (-not $beta26Body.Contains($required)) { throw "Beta 26 release scope missing: $required" }
    }
    if ($beta26Body.Contains([char]0x2014)) { throw 'Beta 26 release notes must not contain em dashes.' }

    $matchedNotes = Join-Path $temp 'matched-213.md'
    $matched = & $script -Tag 'v2.1.3-beta.27' -CompanionReleaseTag 'v2.1.3' -ChangelogPath $projectChangelog -OutputPath $matchedNotes
    if (-not $matched.Prerelease -or $matched.ReleaseName -ne 'Offhand v2.1.3 Pre-Release Beta 27') {
        throw 'The add-on must retain its continuing Pre-Release Beta identity independently of Companion.'
    }
    $matchedBody = Get-Content -LiteralPath $matchedNotes -Raw -Encoding utf8
    foreach ($required in @('<!-- offhand-companion-version: 2.1.3 -->', 'Offhand-Companion-v2.1.3.zip',
        'Offhand-v2.1.3-beta.27.zip', 'Flexible Layout', 'BetterBags/RestedXP', 'manual /reload',
        'has not received a Defender review determination', 'source repository for a Lutris')) {
        if (-not $matchedBody.Contains($required)) { throw "Matched 2.1.3 release scope missing: $required" }
    }
    if ($matchedBody.Contains([char]0x2014) -or $matchedBody.Contains('byte-identical 2.1.2-beta.20')) {
        throw 'Matched 2.1.3 notes must describe the prepared Companion without historical binary claims.'
    }
    $beta28Notes = Join-Path $temp 'beta28.md'
    $beta28 = & $script -Tag 'v2.1.5-beta.28' -CompanionReleaseTag 'v2.1.5' -ChangelogPath $projectChangelog -OutputPath $beta28Notes
    if (!$beta28.Prerelease -or $beta28.ReleaseName -ne 'Offhand v2.1.5 Pre-Release Beta 28') {
        throw 'Beta 28 must remain a named prerelease, separate from clean Companion 2.1.5.'
    }
    $beta28Body = Get-Content -LiteralPath $beta28Notes -Raw -Encoding utf8
    foreach ($required in @('<!-- offhand-companion-version: 2.1.5 -->', 'Offhand-Companion-v2.1.5.zip',
        'Window is positioned', 'quiet', 'OpenMap', 'manual', 'beta.28')) {
        if (!$beta28Body.Contains($required)) { throw "Beta 28 publication scope missing: $required" }
    }
    if ($beta28Body.Contains([char]0x2014)) { throw 'Beta 28 release notes must not contain em dashes.' }
    Write-Output 'PASS: historical metadata and matching 2.1.3 publication scope'

    $packageRoot = Join-Path $temp 'package'
    New-Item -ItemType Directory -Path $packageRoot | Out-Null
    $manifests = @(Get-ChildItem -LiteralPath $root -Filter 'Offhand*.toc' -File)
    if ($manifests.Count -ne 6) { throw 'Expected six addon TOCs for candidate packaging.' }
    $inputs = @('package.ps1', 'Bindings.xml', 'LICENSE', 'README.md', 'CHANGELOG.md', 'Core', 'UI', 'Locales', 'Media', 'Bridges') + $manifests.Name
    foreach ($name in $inputs) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $packageRoot -Recurse
    }

    $candidateId = 'metadata.test1'
    & (Join-Path $packageRoot 'package.ps1') -Version '2.1.5-beta.28' -AddonOnly -CandidateId $candidateId 6>$null
    $candidateDir = Join-Path $packageRoot "dist/$candidateId"
    $zipName = "Offhand-v2.1.5-beta.28-$candidateId.zip"
    $zipPath = Join-Path $candidateDir $zipName
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
    $checksumPath = Join-Path $candidateDir "checksums-addon-v2.1.5-beta.28-$candidateId-sha256.txt"
    if ((Get-Content -LiteralPath $checksumPath).Trim() -ne "$hash  $zipName") {
        throw 'Test ZIP checksum must identify the exact candidate archive.'
    }

    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        if ($zip.Entries | Where-Object { !$_.FullName.StartsWith('Offhand/', [StringComparison]::Ordinal) }) {
            throw "The addon ZIP must contain one top-level Offhand folder."
        }
        foreach ($manifest in $manifests) {
            $source = [IO.File]::ReadAllText($manifest.FullName)
            $staged = [IO.File]::ReadAllText((Join-Path $packageRoot $manifest.Name))
            if ($staged -cne $source) { throw 'Candidate packaging modified its source TOC.' }
            $entry = $zip.GetEntry("Offhand/$($manifest.Name)")
            if (!$entry) { throw "Candidate ZIP is missing $($manifest.Name)." }
            $reader = [IO.StreamReader]::new($entry.Open())
            try { $packaged = $reader.ReadToEnd() } finally { $reader.Dispose() }
            $marker = [regex]::Escape("## X-Offhand-Candidate: $candidateId")
            $titleSuffix = [regex]::Escape(" [QA $candidateId]")
            if ([regex]::Matches($packaged, "(?m)^$marker\r?$").Count -ne 1 -or
                [regex]::Matches($packaged, "(?m)^## Title:[^\r\n]*$titleSuffix\r?$").Count -ne 1 -or
                ($packaged -creplace "(?m)^$marker\r?\n", '' -creplace "(?m)$titleSuffix(?=\r?$)", '') -cne $source) {
                throw "Candidate ZIP must label $($manifest.Name) and preserve all other metadata."
            }
        }
    } finally { $zip.Dispose() }
    Write-Output 'PASS: addon tester ZIP identity, exact checksum, and staged-only TOC labels'
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
