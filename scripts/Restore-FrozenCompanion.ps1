param(
    [string]$Tag = "v2.1.2-beta.13",
    [string]$ExpectedSha256 = "E41E043EFCBB01936155FA0C8A8634F8DF80D7A83599BB5D583F1ECF6B07AEBE",
    [string]$ArchiveDestination,
    [string]$ExpectedArchiveSha256 = "A308ACF1B117B08B2912A77079168C40E32535DFEB66425F541BD7518581818D"
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
