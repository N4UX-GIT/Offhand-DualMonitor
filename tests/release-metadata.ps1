$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'scripts\New-ReleaseMetadata.ps1'
$changelog = Join-Path $root 'CHANGELOG.md'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-release-metadata-' + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp -Force | Out-Null

try {
    $betaNotes = Join-Path $temp 'beta.md'
    $betaOutput = Join-Path $temp 'beta-output.txt'
    $beta = & $script -Tag 'v2.1.2-beta.5' -ChangelogPath $changelog -OutputPath $betaNotes -GitHubOutputPath $betaOutput
    if ($beta.ReleaseName -ne 'Offhand v2.1.2 Beta 5' -or -not $beta.Prerelease) {
        throw 'Beta release metadata is not standardized.'
    }
    $betaBody = Get-Content -LiteralPath $betaNotes -Raw
    foreach ($required in @(
        '# Offhand v2.1.2 Beta 5',
        '## Changes in this build',
        '## Downloads',
        '## Test focus',
        '## Linux and Wine status',
        '## Reporting issues',
        '## Verification',
        'Offhand-Complete-v2.1.2-beta.5.zip'
    )) {
        if (-not $betaBody.Contains($required)) {
            throw "Beta release notes are missing: $required"
        }
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

    $stable = & $script -Tag 'v3.0.0' -ChangelogPath $changelog -OutputPath (Join-Path $temp 'stable.md')
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

    Write-Output 'PASS: standardized beta, release-candidate, stable, and invalid release metadata'
} finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}
