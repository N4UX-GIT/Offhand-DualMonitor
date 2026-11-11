param([switch]$HistoricalArtifactsOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'scripts/Prepare-215Publication.ps1'
$native = Join-Path $root 'Companion/Prepared/2.1.5'
& $script -ValidateOnly -HistoricalArtifactsOnly:$HistoricalArtifactsOnly
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture = Join-Path $temporaryBase ('Offhand-publication-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    function Reset-Fixture {
        foreach ($name in @('Offhand.exe', 'Offhand-Companion-v2.1.5.zip', 'release.json')) {
            Copy-Item -LiteralPath (Join-Path $native $name) -Destination (Join-Path $fixture $name) -Force
        }
    }
    function Expect-Rejection([string]$Message) {
        $rejected = $false
        try { & $script -CompanionDirectory $fixture -ValidateOnly -HistoricalArtifactsOnly:$HistoricalArtifactsOnly | Out-Null }
        catch { $rejected = $true }
        if (-not $rejected) { throw ('Publication accepted ' + $Message) }
    }
    Reset-Fixture
    & $script -CompanionDirectory $fixture -ValidateOnly -HistoricalArtifactsOnly:$HistoricalArtifactsOnly
    if ($HistoricalArtifactsOnly) {
        $blocked = $false
        try { & $script -HistoricalArtifactsOnly -OutputDirectory (Join-Path $fixture 'must-not-exist') | Out-Null }
        catch { $blocked = $_.Exception.Message -like 'Historical artifact verification cannot*' }
        if (!$blocked -or (Test-Path -LiteralPath (Join-Path $fixture 'must-not-exist'))) {
            throw 'Historical verification must not prepare packages.'
        }
        $blocked = $false
        try { & $script -ValidateOnly | Out-Null }
        catch { $blocked = $_.Exception.Message -like 'Frozen Companion source changed:*' }
        if (!$blocked) { throw 'Current source must not masquerade as the original 2.1.5 submission.' }
    }
    foreach ($sample in @('Offhand.exe', 'Offhand-Companion-v2.1.5.zip')) {
        Reset-Fixture
        $path = Join-Path $fixture $sample
        $bytes = [IO.File]::ReadAllBytes($path); $bytes[$bytes.Length - 1] = $bytes[$bytes.Length - 1] -bxor 1
        [IO.File]::WriteAllBytes($path, $bytes)
        Expect-Rejection ('modified frozen sample ' + $sample)
    }
    foreach ($property in @('version', 'companionSourceRevision', 'binarySha256', 'archiveSha256')) {
        Reset-Fixture
        $path = Join-Path $fixture 'release.json'; $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $receipt.$property = 'invalid'
        $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
        Expect-Rejection ('incorrect receipt field ' + $property)
    }
    Reset-Fixture
    $path = Join-Path $fixture 'release.json'; $receipt = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $receipt.inputs[0].sha256 = 'invalid'
    $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
    Expect-Rejection 'source that differs from the submitted Companion'
    $workflow = Get-Content -LiteralPath (Join-Path $root '.github/workflows/release.yml') -Raw
    if ($workflow -notmatch "github.ref_name == 'v2.1.5-beta.28'" -or
        $workflow -notmatch 'prerelease: true' -or $workflow -notmatch 'draft: true' -or $workflow -notmatch 'Prepare-215Publication.ps1') {
        throw 'The Beta 28 tag must use frozen Companion 2.1.5 assets, prerelease status and a draft hold.'
    }
    Write-Output 'PASS: publication identity, exact EXE/ZIP, source drift rejection and draft-release safeguards.'
} finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    if (-not $resolved.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -notmatch '^Offhand-publication-[a-f0-9]{32}$') { throw 'Unsafe fixture cleanup path.' }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
