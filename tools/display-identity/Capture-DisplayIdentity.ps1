[CmdletBinding()]
param(
    [string]$Label,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 does not initialize $PSScriptRoot for this parameter
# default during a -File launch. Resolve paths after parameter binding instead.
$probeDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($probeDirectory)) {
    $probeDirectory = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
if ([string]::IsNullOrWhiteSpace($probeDirectory)) { throw 'Cannot locate the diagnostic script folder.' }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $probeDirectory 'captures'
}
if ([string]::IsNullOrWhiteSpace($Label)) {
    $Label = Read-Host 'Capture label (for example: 1-wow-closed)'
}
if ([string]::IsNullOrWhiteSpace($Label)) { throw 'A capture label is required.' }

# No application is started, no settings are read or changed, and no window is
# controlled. The active-path query is independent of the two monitor-child calls.
Add-Type -AssemblyName System.Windows.Forms
$nativeSources = @('DisplayIdentityNative.cs', 'DisplayPathNative.cs' | ForEach-Object { Join-Path $probeDirectory $_ })
Add-Type -Path $nativeSources -ReferencedAssemblies System.Windows.Forms, System.Drawing
$displays = @([OffhandIdentityDiagnostic.NativeCapture]::Read())
$activePaths = [OffhandIdentityDiagnostic.DisplayPathNative]::Read()
$windowsVersion = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$windowsBuild = if ($windowsVersion.CurrentBuildNumber -and $null -ne $windowsVersion.UBR) {
    '{0}.{1}' -f $windowsVersion.CurrentBuildNumber, $windowsVersion.UBR
}

function Get-IdentitySummary([object[]]$Records, [string]$Property) {
    $present = @($Records | Where-Object { -not [string]::IsNullOrWhiteSpace($_.$Property) })
    $groups = @($present | Group-Object -Property $Property)
    [ordered]@{
        PresentCount = $present.Count
        MissingCount = $Records.Count - $present.Count
        DistinctCount = $groups.Count
        DuplicateGroups = @($groups | Where-Object Count -gt 1 | ForEach-Object {
            [ordered]@{ Devices = @($_.Group | ForEach-Object DeviceName) }
        })
    }
}

$companions = @(Get-Process -Name Offhand -ErrorAction SilentlyContinue | ForEach-Object {
    $record = [ordered]@{ ProcessId = $_.Id; ProductVersion = $null; Sha256 = $null; MatchesCanonicalBeta20 = $null; ReadStatus = 'unavailable' }
    try {
        $binaryPath = $_.Path
        if (-not [string]::IsNullOrWhiteSpace($binaryPath)) {
            $record.ProductVersion = [Diagnostics.FileVersionInfo]::GetVersionInfo($binaryPath).ProductVersion
            $record.Sha256 = (Get-FileHash -LiteralPath $binaryPath -Algorithm SHA256).Hash
            $record.MatchesCanonicalBeta20 = $record.Sha256 -eq '81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB'
            $record.ReadStatus = 'read'
        }
    } catch {
        # Access errors may contain account/install paths. Do not emit those.
        $record.ReadStatus = 'could-not-read-binary'
    }
    $record
})

$wowNames = @('WowClassic', 'Wow', 'WowClassicEra', 'WowForever', 'WowT', 'WowB', 'WowClassicT', 'WowClassicB')
$wow = @(Get-Process -Name $wowNames -ErrorAction SilentlyContinue | ForEach-Object {
    [ordered]@{ Name = $_.ProcessName; ProcessId = $_.Id }
})

$report = [ordered]@{
    SchemaVersion = 2
    ProbeVersion = '2026-11-06.3'
    Label = $Label
    CapturedAtUtc = [DateTime]::UtcNow.ToString('o')
    ReadOnlyObservation = $true
    WindowsBuild = $windowsBuild
    TerminalServerSession = [System.Windows.Forms.SystemInformation]::TerminalServerSession
    DisplayCount = $displays.Count
    LegacyIdentitySummary = Get-IdentitySummary $displays 'LegacyId'
    InterfaceIdentitySummary = Get-IdentitySummary $displays 'InterfaceId'
    Displays = $displays
    ActiveDisplayPaths = $activePaths
    CompanionProcesses = $companions
    WowProcesses = $wow
}

[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($OutputDirectory)) | Out-Null
$safeLabel = ($Label -replace '[^A-Za-z0-9_-]', '_').Trim('_')
if ([string]::IsNullOrWhiteSpace($safeLabel)) { $safeLabel = 'capture' }
if ($safeLabel.Length -gt 60) { $safeLabel = $safeLabel.Substring(0, 60) }
$filename = 'display-identity-{0}-{1}-{2}.json' -f ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')), $safeLabel, ([guid]::NewGuid().ToString('N').Substring(0, 8))
$destination = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) $filename
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($destination, ($report | ConvertTo-Json -Depth 8), $utf8)

Write-Host ''
Write-Host ('Connected displays: {0}' -f $displays.Count)
Write-Host ('Beta 20 ID method: {0} distinct, {1} missing' -f $report.LegacyIdentitySummary.DistinctCount, $report.LegacyIdentitySummary.MissingCount)
Write-Host ('Per-monitor interface method: {0} distinct, {1} missing' -f $report.InterfaceIdentitySummary.DistinctCount, $report.InterfaceIdentitySummary.MissingCount)
if ($activePaths.BufferSizeResult -eq 0 -and $activePaths.QueryResult -eq 0) {
    Write-Host ('Active Windows display paths: {0}' -f $activePaths.Paths.Count)
} else {
    Write-Host ('Active Windows display paths unavailable. Buffer result: {0}; query result: {1}' -f $activePaths.BufferSizeResult, $activePaths.QueryResult)
}
Write-Host ('Saved: {0}' -f $destination)
Write-Host 'Keep the JSON private; it contains monitor identifiers.'
