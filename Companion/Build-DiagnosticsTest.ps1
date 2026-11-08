param([Parameter(Mandatory = $true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$destination = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $destination) { throw "Output directory already exists: $destination. Choose a fresh test directory." }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$source = Join-Path $PSScriptRoot 'Source\Program.cs'
$manifest = Join-Path $PSScriptRoot 'Source\app.manifest'
$icon = Join-Path $root 'Media\offhand-logo.ico'
$logo = Join-Path $root 'Media\offhand-logo-small.png'
New-Item -ItemType Directory -Path $destination | Out-Null
$runtime = Join-Path $destination 'Offhand-HDR-DPI-Test3'
New-Item -ItemType Directory -Path $runtime | Out-Null
$executable = Join-Path $runtime 'Offhand.exe'
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu /define:HDR_DPI_DIAGNOSTICS_TEST "/out:$executable" "/win32icon:$icon" "/win32manifest:$manifest" "/resource:$logo,Offhand.Companion.Resources.offhand-logo.png" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll $source
if ($LASTEXITCODE -ne 0) { throw 'Diagnostics candidate compilation failed' }
$version = [Diagnostics.FileVersionInfo]::GetVersionInfo($executable)
if ($version.FileVersion -ne '2.1.2.2005' -or $version.FileDescription -notlike '*HDR DPI DIAGNOSTICS TEST 3*') {
    throw 'Candidate identity does not match Diagnostics Test 3'
}
$readme = @'
Offhand Companion: HDR / DPI DIAGNOSTICS TEST 3
Local test candidate. Not a public release or Microsoft Store update.

1. Extract the whole ZIP into a writable folder.
2. Exit your current Companion through its tray menu (Exit Companion).
   Closing its window only minimizes it. This test uses the same single-instance guard.
3. Run Offhand.exe. Confirm the title says HDR / DPI DIAGNOSTICS TEST 3.
4. Review the selected Mainhand and Offhand displays. Scroll to Display Diagnostics.
   Cards have Show/Hide buttons; Activity Log starts collapsed. The window can
   be resized, and the footer controls stay outside the scrolling content.
5. Check the HDR/SDR states and Windows scale percentages against Windows Settings.
6. Open Display Troubleshooting for HDR and scaling comparisons.
7. Click Copy Display Diagnostics and paste the result into this chat with your observations.

Detection works without WoW running. You can optionally compare HDR on/off and
different monitor scale settings. Follow Windows restart/sign-out prompts and
restore your preferred settings afterward. Unknown readings must remain unavailable.
If you test WoW spanning, use Span WoW Now manually; normal Span/Restore behavior applies.

Automatic spanning is disabled in this test. Public display preferences are used
as initial defaults; changes save only to DiagnosticsTestConfig.ini beside this EXE.
The test does not overwrite the public Companion executable or public INI.
HDR/DPI detection is read-only and never changes Windows HDR/scaling settings.
Manual Span/Restore and normal Companion addon bridge behavior remain available.
Use Exit Companion when finished, then relaunch your usual Companion.

Expected examples:
- HDR on + SDR: mixed HDR/SDR advisory; spanning remains available.
- SDR + SDR, even if HDR-capable: no mixed HDR advisory.
- 100% + 150%: differing Windows scales shown as informational, not an error.
- 150% + 150%: matching 150% scaling reported.
- Single-display split: no mixed-output or mixed-scale advisory.

Windows scale is separate from physical pixel density and WoW UI/render scale.
This build diagnoses configuration; it does not tone-map or fix blurry rendering.
The public compatibility/protocol version remains Beta 20; the candidate's file
version is 2.1.2.2005 and its title explicitly identifies Diagnostics Test 3.
'@
[IO.File]::WriteAllText((Join-Path $runtime 'README.txt'), $readme, (New-Object Text.UTF8Encoding($false)))
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $runtime 'LICENSE')
$archive = Join-Path $destination 'Offhand-Companion-v2.1.2-beta.20-hdr-dpi.test3.zip'
Compress-Archive -LiteralPath $executable, (Join-Path $runtime 'README.txt'), (Join-Path $runtime 'LICENSE') -DestinationPath $archive
# Check archive contents and the executable bytes without launching the candidate.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    if (($zip.Entries.FullName | Sort-Object) -join '|' -ne 'LICENSE|Offhand.exe|README.txt') { throw 'Unexpected test ZIP layout' }
    $stream = $zip.GetEntry('Offhand.exe').Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $archivedHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($archivedHash -ne (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash) { throw 'Archived executable mismatch' }
} finally { $zip.Dispose() }
$baseRevision = (& git -C $root rev-parse HEAD).Trim()
$information = @(
    'Local source candidate: HDR_DPI_DIAGNOSTICS_TEST',
    ('Built UTC: ' + [DateTime]::UtcNow.ToString('u')),
    ('Base revision: ' + $baseRevision),
    'Includes uncommitted HDR/DPI diagnostics source changes.',
    ('Program.cs SHA256: ' + (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash),
    ('app.manifest SHA256: ' + (Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash),
    ('Build script SHA256: ' + (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash)
)
[IO.File]::WriteAllLines((Join-Path $destination 'build-info.txt'), $information)
$checksums = @(
    ((Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash + '  Offhand-HDR-DPI-Test3/Offhand.exe'),
    ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash + '  ' + [IO.Path]::GetFileName($archive))
)
[IO.File]::WriteAllLines((Join-Path $destination 'checksums-sha256.txt'), $checksums)
Write-Output "Built and verified: $executable"
Write-Output "ZIP: $archive"
