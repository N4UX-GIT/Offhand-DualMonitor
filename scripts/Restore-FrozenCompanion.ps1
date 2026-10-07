param(
    [string]$Tag = "v2.1.2-beta.19",
    [string]$ExpectedSha256 = "89C065D28D5EB37A3CCBF868DA006C64E7FD403A50417E8799806DF92E46BF52",
    [string]$ArchiveDestination,
    [string]$ExpectedArchiveSha256 = "83EEDFE4DFE96EA4A34E6414E55797CAD4E02181604DAAA2F6E6B3EC57F1576B"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $root "Companion\Offhand.exe"
$download = Join-Path ([IO.Path]::GetTempPath()) ("Offhand-frozen-" + [guid]::NewGuid() + ".exe")
$url = "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/$Tag/Offhand.exe"
$archiveDownload = Join-Path ([IO.Path]::GetTempPath()) ("Offhand-frozen-" + [guid]::NewGuid() + ".zip")
$archiveUrl = "https://github.com/N4UX-GIT/Offhand-DualMonitor/releases/download/$Tag/Offhand-Companion.zip"

try {
    Write-Host "Downloading frozen Companion $Tag..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $download -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSha256) {
        throw "Downloaded Companion hash $actual does not match expected $ExpectedSha256."
    }
    Copy-Item -LiteralPath $download -Destination $destination -Force
    Write-Host "Restored $destination" -ForegroundColor Green
    Write-Host "SHA-256: $actual" -ForegroundColor White

    if (-not [string]::IsNullOrWhiteSpace($ArchiveDestination)) {
        if ([string]::IsNullOrWhiteSpace($ExpectedArchiveSha256)) {
            throw "ExpectedArchiveSha256 is required when restoring the frozen Companion archive."
        }
        $archiveParent = Split-Path -Parent $ArchiveDestination
        if ($archiveParent) {
            New-Item -ItemType Directory -Path $archiveParent -Force | Out-Null
        }
        Invoke-WebRequest -Uri $archiveUrl -OutFile $archiveDownload -UseBasicParsing
        $actualArchive = (Get-FileHash -LiteralPath $archiveDownload -Algorithm SHA256).Hash
        if ($actualArchive -ne $ExpectedArchiveSha256) {
            throw "Downloaded Companion archive hash $actualArchive does not match expected $ExpectedArchiveSha256."
        }
        Copy-Item -LiteralPath $archiveDownload -Destination $ArchiveDestination -Force
        Write-Host "Restored $ArchiveDestination" -ForegroundColor Green
        Write-Host "Archive SHA-256: $actualArchive" -ForegroundColor White
    }
} finally {
    if (Test-Path -LiteralPath $download) {
        Remove-Item -LiteralPath $download -Force
    }
    if (Test-Path -LiteralPath $archiveDownload) {
        Remove-Item -LiteralPath $archiveDownload -Force
    }
}
