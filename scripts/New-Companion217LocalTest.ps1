param([Parameter(Mandatory=$true)][string]$CandidateDirectory,
      [Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$candidate=[IO.Path]::GetFullPath($CandidateDirectory)
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Choose a fresh local test directory.'}
$record=Get-Content -LiteralPath (Join-Path $candidate 'candidate.json') -Raw|ConvertFrom-Json
$binary=Join-Path $candidate 'Offhand.exe'
if($record.fileVersion-ne '2.1.7.3' -or (Get-FileHash -LiteralPath $binary).Hash-ne $record.binarySha256){throw 'Expected the exact 2.1.7 production candidate.'}
$runtime=Join-Path $output 'Runtime'
New-Item -ItemType Directory -Path $runtime|Out-Null
Copy-Item -LiteralPath $binary -Destination (Join-Path $runtime 'Offhand.exe')
$template=Join-Path $root 'tests/Companion217StoreUpdateReview.cs'
$hostSource=[IO.File]::ReadAllText($template).Replace('BUILD_EXE_SHA256',$record.binarySha256)
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('Offhand217Review-'+[guid]::NewGuid().ToString('N')+'.cs')
$hostBinary=Join-Path $output 'Offhand-StoreUpdate-Test.exe'
try {
    [IO.File]::WriteAllText($temporary,$hostSource,[Text.UTF8Encoding]::new($false))
    & "$env:WINDIR/Microsoft.NET/Framework64/v4.0.30319/csc.exe" /nologo /target:winexe /platform:anycpu "/out:$hostBinary" "/win32icon:$root/Media/offhand-logo.ico" /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll $temporary
    if($LASTEXITCODE-ne 0){throw 'Local review host compilation failed.'}
} finally { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
& $hostBinary --verify
if($LASTEXITCODE-ne 0){throw 'Exact payload/delegate check failed.'}
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination $output
@'
Offhand Companion 2.1.7, LOCAL STORE UPDATE TEST. Unpublished.

Run Offhand-StoreUpdate-Test.exe, choose a response and open the test dashboard.
The production 2.1.7.3 payload is included under Runtime; do not launch that EXE
directly for this isolated review. Use the test launcher above.

SIMULATION: no real Store query, download or installation occurs. Game controls
and monitoring are disabled. Your installed Companion can stay open. Preferences
and cached responses live only in LocalTestData beside the launcher.

Advanced shows the last check time. Hover Store Updates / Update available to
read the same time. Times use Windows local time. Successful checks say Last
checked; failed/incomplete attempts say Last attempted. A fresh scenario has no
invented timestamp. Store checks are quiet, at most once every six hours, with
the same delay after failure and across restarts/build changes. Store controls
still open Microsoft Store on click; installation remains under Store control.

The new What's new notice introduces the changes and offers conditional layout
recovery/calibration guidance. This test starts as an existing user so it shows
the notice once. Got it (or closing it) acknowledges this version. Replay from
Help > What's new. New installs receive only the tutorial. No calibration,
graphics setting or saved display plan is changed by the notice.

Available/No update/Unavailable appear after the normal 30-second delay. Timeout
finishes after about 45 seconds. Run the same scenario with Reset unchecked to
review the cached result and time. No extra simulated query should appear in
LocalTestData/<scenario>/test-queries.log until six hours pass. Reset clears only
that scenario's test cache. The --available argument opens that test directly.

Review Setup/Advanced, timestamp wrapping at your Windows scale, unchanged footer
alignment, available/no-update/failure text, Help and privacy wording. Close with
Exit Companion. No Store/GitHub/addon/website publication is part of this test.
The existing Beta 28 addon remains compatible. Source and native fixtures are
recorded in the 2.1.7 preparation notes; Store/WACK acceptance is still pending.
'@|Set-Content -LiteralPath (Join-Path $output 'README.txt') -Encoding UTF8
$receipt=[ordered]@{kind='isolated-store-update-simulation';version='2.1.7';runtimeFileVersion='2.1.7.3';
    sourceRevision=$record.sourceRevision;reviewSourceRevision=(& git -C $root rev-parse HEAD).Trim();runtimeSha256=$record.binarySha256;
    launcherSha256=(Get-FileHash -LiteralPath $hostBinary).Hash;templateSha256=(Get-FileHash -LiteralPath $template).Hash;
    realStoreQueries=$false;gameMonitoring=$false;settings='LocalTestData';publication='unpublished'}
$receipt|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $output 'test-build.json') -Encoding UTF8
$zip=$output+'.zip'
if(Test-Path -LiteralPath $zip){throw 'ZIP already exists.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($output,$zip)
Write-Output "Local test ZIP: $zip"
Write-Output ('SHA256: '+(Get-FileHash -LiteralPath $zip).Hash)
