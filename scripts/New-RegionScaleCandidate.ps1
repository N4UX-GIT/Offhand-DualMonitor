param(
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$ExpectedVersion='2.1.6',
    [string]$SourceProvenanceFile
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($OutputDirectory)
$public=[IO.Path]::GetFullPath((Join-Path $root Companion))
if(Test-Path -LiteralPath $output){throw 'Choose a fresh candidate directory.'}
if($output.Equals($public,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($public+'\',[StringComparison]::OrdinalIgnoreCase)){
    throw 'Candidate output must be outside the frozen Companion directory.'
}
$frozen=@{}
foreach($name in @('Offhand.exe','Offhand-Companion.zip')){
    $path=Join-Path $public $name;$frozen[$path]=(Get-FileHash -LiteralPath $path).Hash
}
$inputs=@('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs','app.manifest')
$hashes=[ordered]@{}
foreach($name in $inputs){$hashes[$name]=(Get-FileHash -LiteralPath (Join-Path $public ('Source/'+$name))).Hash}
New-Item -ItemType Directory -Path $output|Out-Null
$snapshot=Join-Path $output source-snapshot
New-Item -ItemType Directory -Path $snapshot|Out-Null
foreach($name in $inputs){Copy-Item -LiteralPath (Join-Path $public ('Source/'+$name)) -Destination $snapshot}
& (Join-Path $PSScriptRoot Test-CompanionInteractionBoundary.ps1) -OutputPath (Join-Path $output interaction-audit.json)
$binary=Join-Path $output Offhand.exe
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$sources=$inputs|Where-Object{$_ -like '*.cs'}|ForEach-Object{Join-Path $snapshot $_}
& $compiler /nologo /langversion:5 /target:winexe /optimize+ /platform:anycpu "/out:$binary" "/win32icon:$root\Media\offhand-logo.ico" "/win32manifest:$snapshot\app.manifest" "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll @sources
if($LASTEXITCODE -ne 0){throw 'Region scale candidate compilation failed.'}
$identity=[Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
$version=$identity.ProductVersion
if($version -ne $ExpectedVersion){throw "Stale Companion base: expected $ExpectedVersion, compiled $version. Do not use this candidate."}
$provenance=$null
if($SourceProvenanceFile){
    $provenance=Get-Content -LiteralPath $SourceProvenanceFile -Raw|ConvertFrom-Json
    foreach($name in $inputs){
        if($provenance.rebasedSourceInputs.$name -ne $hashes[$name]){throw ('Rebased source provenance mismatch: '+$name)}
    }
    Copy-Item -LiteralPath $SourceProvenanceFile -Destination (Join-Path $output source-provenance.json)
}
$guide=@'
Offhand Companion {{VERSION}}: unpublished region panel sizing QA candidate.
SHA-256: {{EXE_SHA256}}

This candidate adds panelScaleMetadata version 1 for every workspace region.
Use the matching reviewed addon source. Existing sizes remain 100% until the
user chooses and applies a size in calibration or Workspace settings. Manual
sizes do not require Windows scaling metadata. Auto is a bounded estimate.

Exit other ordinary Companions through their tray menu before running this
candidate. It uses the normal portable preferences. Back them up before changing
a layout. Span WoW Now applies a reviewed plan; reload reads its new topology.
Use Restore Window for recovery. Do not change Windows display scaling for QA.

Test preview/discard, Apply, independent regions, native bags and map fitting,
reload and existing-size preservation. The player enters/exits combat manually.
Capture current errors/taint; a successful resize is not protected-action proof.

This build is not published, Store-submitted, signed or release-approved. The
canonical Companion executable and public archives have not been replaced.
'@
$archive=Join-Path $output ('Offhand-Companion-v'+$version+'-region-scale-candidate.zip')
& (Join-Path $PSScriptRoot New-CompanionTestPackage.ps1) -BinaryPath $binary -OutputPath $archive -Version $version -ReadmeTemplate $guide|Out-Null
foreach($name in $inputs){
    if((Get-FileHash -LiteralPath (Join-Path $public ('Source/'+$name))).Hash -ne $hashes[$name] -or
       (Get-FileHash -LiteralPath (Join-Path $snapshot $name)).Hash -ne $hashes[$name]){throw ('Candidate source drift: '+$name)}
}
foreach($path in $frozen.Keys){if((Get-FileHash -LiteralPath $path).Hash -ne $frozen[$path]){throw 'Frozen public artifact changed.'}}
$record=[ordered]@{purpose='region-panel-scale';publication='unpublished';builtUtc=[DateTime]::UtcNow.ToString('o');
    version=$version;fileVersion=$identity.FileVersion;sourceRevision=(& git -C $root rev-parse HEAD).Trim();
    dirtyCheckout=[bool]@(& git -C $root status --porcelain).Count;sourceInputs=$hashes;metadataVersion=1;
    expectedVersion=$ExpectedVersion;sourceBase=$provenance;
    binarySha256=(Get-FileHash -LiteralPath $binary).Hash;archiveSha256=(Get-FileHash -LiteralPath $archive).Hash;
    frozenPublic=$frozen;liveVerification='pending'}
$record|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $output candidate.json) -Encoding UTF8
@(($record.binarySha256+'  Offhand.exe'),($record.archiveSha256+'  '+[IO.Path]::GetFileName($archive)))|
    Set-Content -LiteralPath (Join-Path $output checksums-sha256.txt) -Encoding ASCII
[pscustomobject]@{Binary=$binary;Archive=$archive;SHA256=$record.binarySha256;Version=$version;FrozenPublicUnchanged=$true}
