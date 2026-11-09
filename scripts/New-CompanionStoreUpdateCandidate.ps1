param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($OutputDirectory)
$public=[IO.Path]::GetFullPath((Join-Path $root 'Companion'))
if(Test-Path -LiteralPath $output){throw 'Choose a fresh candidate directory.'}
if($output.Equals($public,[StringComparison]::OrdinalIgnoreCase) -or
   $output.StartsWith($public+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Candidate output must be outside the frozen Companion directory.'
}
$frozen=@{}
foreach($name in @('Offhand.exe','Offhand-Companion.zip')){
    $path=Join-Path $public $name;$frozen[$path]=(Get-FileHash -LiteralPath $path).Hash
}
New-Item -ItemType Directory -Path $output|Out-Null
& (Join-Path $PSScriptRoot 'Test-CompanionInteractionBoundary.ps1') -OutputPath (Join-Path $output 'interaction-audit.json')
$source=Join-Path $public 'Source'
$files=@('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs')|ForEach-Object{Join-Path $source $_}
$binary=Join-Path $output 'Offhand.exe'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$options=@('/nologo','/target:winexe','/optimize+','/platform:anycpu',"/out:$binary",
    "/win32icon:$root\Media\offhand-logo.ico","/win32manifest:$source\app.manifest",
    "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png",
    '/r:System.dll','/r:System.Drawing.dll','/r:System.Web.Extensions.dll','/r:System.Windows.Forms.dll')
& $compiler @options @files
if($LASTEXITCODE-ne 0){throw 'Store-update release candidate compilation failed.'}
$identity=[Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
if($identity.FileVersion-ne '2.1.5.1' -or $identity.ProductVersion-ne '2.1.5') {throw 'Unexpected candidate identity.'}
$readme=@'
Offhand Companion {{VERSION}}, unpublished release candidate (build 2.1.5.1).
SHA-256: {{EXE_SHA256}}

Extract this archive to a writable folder. Exit the regular Companion through
its tray menu before running Offhand.exe. This ordinary portable candidate uses
your existing portable preferences; it is different from the isolated UI Preview.

Changes: quiet Store update availability detection, a passive Update available
button, persistent daily throttling, bounded cancellation and graceful offline
handling. Store services manage installation after the user opens Microsoft
Store; the Companion does not download updates or restart itself. Portable
checks remain manual. This portable candidate never queries the Store.

The existing protocol-1 addon remains compatible. No new addon or WoW behavior
is introduced. Store-associated available/no-update and offline acceptance,
Windows 10 compatibility, WACK and Defender release scans remain pending.
The submitted 2.1.4.2 executable and 2.1.400.0 MSIX must remain unchanged.

This build is unpublished. Do not replace a public release or the in-flight
2.1.4 Store submission with it. Certification and rollout are separate gates.
'@
$archive=Join-Path $output 'Offhand-Companion-v2.1.5-candidate.zip'
& (Join-Path $PSScriptRoot 'New-CompanionTestPackage.ps1') -BinaryPath $binary -OutputPath $archive -Version '2.1.5' -ReadmeTemplate $readme
$inputs=[ordered]@{}
foreach($file in $files){$inputs[[IO.Path]::GetFileName($file)]=(Get-FileHash -LiteralPath $file).Hash}
$inputs['app.manifest']=(Get-FileHash -LiteralPath (Join-Path $source 'app.manifest')).Hash
$record=[ordered]@{version='2.1.5';fileVersion=$identity.FileVersion;packageVersion='2.1.500.0';
    sourceRevision=(& git -C $root rev-parse HEAD).Trim();sourceInputs=$inputs;
    trackedChanges=[bool]@(& git -C $root status --porcelain --untracked-files=no).Count;
    binarySha256=(Get-FileHash -LiteralPath $binary).Hash;archiveSha256=(Get-FileHash -LiteralPath $archive).Hash;
    publication='unpublished';addonProtocol=1}
$record|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $output 'candidate.json') -Encoding UTF8
@("$($record.binarySha256)  Offhand.exe","$($record.archiveSha256)  $([IO.Path]::GetFileName($archive))")|
    Set-Content -LiteralPath (Join-Path $output 'checksums-sha256.txt') -Encoding ASCII
foreach($path in $frozen.Keys){if((Get-FileHash -LiteralPath $path).Hash-ne $frozen[$path]){throw 'Frozen public artifact changed.'}}
Write-Output "Prepared unpublished Companion 2.1.5: $archive"
