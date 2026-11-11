param(
    [Parameter(Mandatory=$true)][string]$CandidateDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$candidate=(Resolve-Path -LiteralPath $CandidateDirectory).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Choose a fresh local review output directory.'}
$record=Get-Content -LiteralPath (Join-Path $candidate 'candidate.json') -Raw|ConvertFrom-Json
$binary=Join-Path $candidate 'Offhand.exe'
$expected='95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A'
if($record.fileVersion -ne '2.1.5.1' -or $record.binarySha256 -ne $expected -or (Get-FileHash -LiteralPath $binary).Hash -ne $expected){throw 'Local review requires the exact reviewed 2.1.5.1 candidate.'}
New-Item -ItemType Directory -Path $output|Out-Null
$staging=Join-Path $output 'Offhand-2.1.5-Local-Test'
New-Item -ItemType Directory -Path $staging|Out-Null
Copy-Item -LiteralPath $binary -Destination (Join-Path $staging 'Offhand.exe')
Copy-Item -LiteralPath (Join-Path $root 'Companion/LICENSE') -Destination (Join-Path $staging 'LICENSE')
$hostSource=Join-Path $root 'tests/CompanionStoreUpdateLocalReview.cs'
$hostExe=Join-Path $staging 'Test Store Update UI.exe'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu "/out:$hostExe" "/win32icon:$root/Media/offhand-logo.ico" "/win32manifest:$root/Companion/Source/app.manifest" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll $hostSource
if($LASTEXITCODE -ne 0){throw 'Local simulator compilation failed.'}
& $hostExe --verify
if($LASTEXITCODE -ne 0){throw 'Local simulator candidate/delegate verification failed.'}
@'
OFFHAND COMPANION 2.1.5 LOCAL TEST 1
Unpublished. Not a Microsoft Store release.

START HERE: TEST THE NEW UPDATE NOTIFICATION
1. Extract the complete ZIP to a writable folder. Keep the included EXEs together.
2. Run "Test Store Update UI.exe".
3. Choose a scenario and click Open test dashboard.
   - Update available: after 30 seconds, the footer should say "Update available...".
   - No update: after 30 seconds, the button stays Store Updates; hover for the result.
   - Store unavailable: after 30 seconds, no popup; hover for the unavailable explanation.
   - Timeout: after about 45 seconds, no popup; hover for the unavailable explanation.
4. Check the tray update entry agrees with the button. Panels should not resize.
5. Use Exit Companion to close the test. X minimizes to the tray.

DAILY CACHE / SHUTDOWN CHECKS
- Run the same scenario again with "Reset this scenario's test cache" unchecked.
  Cached availability should appear immediately, with no additional query after
  30 seconds. LocalTestData/<scenario>/test-queries.log records simulated attempts.
- Close the timeout scenario before 45 seconds and rerun it. There should be no
  late notification or crash. Reset the test cache if you want a fresh attempt.

WHAT THE SIMULATOR DOES
It runs the exact production controller/UI with simulated Store responses.
The title clearly says SIMULATED. It uses only LocalTestData beside these files,
pauses game monitoring and disables game/configuration actions in this process.
Your normal Companion preferences and the submitted 2.1.4 package are untouched.
No Store availability request or installation is made. Clicking the update
button opens the real public Store page; it will not install this test build.
These scenarios do not prove real Store catalog detection. That needs a
Store-associated build/flight before release. No add-on update is required.

OPTIONAL: TEST THE NORMAL PORTABLE BUILD
Exit other regular Companion instances through Exit Companion first, then run
Offhand.exe. This is the ordinary 2.1.5.1 runtime and uses your normal portable
preferences. Review selected displays before spanning. Type /reload in WoW
after applying a layout. The PORTABLE build does not run automatic Store checks;
its Check for Updates button retains the manual GitHub check. The simulator can
run separately because its settings and instance guard are isolated.

BUILD DETAILS
Production file version: 2.1.5.1. Source commit: 7bc07a6.
Production SHA-256: 95811DBB7020A20E2541AE123E69FE80721C83A0FD52D0EE5557DD6D54DCCC2A
Simulator file version: 2.1.5.9001. Not intended for public release.
checksums-sha256.txt covers every other file in this package.
These local non-Store EXEs are unsigned. Do not disable antivirus or add exclusions
for this test; report a named detection with its file/hash if one occurs.
'@|Set-Content -LiteralPath (Join-Path $staging 'README.txt') -Encoding UTF8
$manifest=[ordered]@{kind='local-review-only';version='2.1.5';productionFileVersion='2.1.5.1';productionSha256=$expected;runtimeSource=$record.sourceRevision;simulatorFileVersion='2.1.5.9001';simulatorSourceSha256=(Get-FileHash -LiteralPath $hostSource).Hash;simulatorSha256=(Get-FileHash -LiteralPath $hostExe).Hash;storeResponses='simulated';actualStoreCatalogAcceptance='pending';addonRequiredUpdate=$false;publication='unpublished'}
$manifest|ConvertTo-Json -Depth 3|Set-Content -LiteralPath (Join-Path $staging 'test-package.json') -Encoding UTF8
Get-ChildItem -LiteralPath $staging -File | Sort-Object Name | ForEach-Object { (Get-FileHash -LiteralPath $_.FullName).Hash+'  '+$_.Name } |
    Set-Content -LiteralPath (Join-Path $staging 'checksums-sha256.txt') -Encoding ASCII
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=Join-Path $output 'Offhand-Companion-2.1.5-Local-Test-1.zip'
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach($file in Get-ChildItem -LiteralPath $staging -File | Sort-Object Name){
        $entry=$zip.CreateEntry($file.Name,[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime=[DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $input=[IO.File]::OpenRead($file.FullName);$destination=$entry.Open()
        try{$input.CopyTo($destination)}finally{$destination.Dispose();$input.Dispose()}
    }
}finally{$zip.Dispose()}
$verification=[IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach($entry in $verification.Entries){
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try{$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
        if($hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $entry.FullName)).Hash){throw 'Local review ZIP parity failed.'}
    }
    if($verification.Entries.Count -ne 6){throw 'Unexpected local review ZIP contents.'}
}finally{$verification.Dispose()}
$zipHash=(Get-FileHash -LiteralPath $archive).Hash
($zipHash+'  '+[IO.Path]::GetFileName($archive))|Set-Content -LiteralPath (Join-Path $output 'checksums-sha256.txt') -Encoding ASCII
Write-Output "Local test ZIP: $archive"
Write-Output "SHA-256: $zipHash"
