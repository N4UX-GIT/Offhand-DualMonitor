param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$output=[IO.Path]::GetFullPath($OutputDirectory)
$public=[IO.Path]::GetFullPath((Join-Path $root 'Companion'))
if(Test-Path -LiteralPath $output){throw 'Choose a fresh candidate directory.'}
if($output.Equals($public,[StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($public+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
    throw 'Candidate output must remain outside frozen public artifacts.'
}
$frozen=@{}
foreach($name in @('Offhand.exe','Offhand-Companion.zip','Prepared/2.1.5/Offhand.exe','Prepared/2.1.5/Offhand-Companion-v2.1.5.zip')){
    $path=Join-Path $public $name;$frozen[$path]=(Get-FileHash -LiteralPath $path).Hash
}
# Preserve exact submitted 2.1.6 bytes whenever that local candidate is present.
foreach($artifact in @(
    @('dist/companion-2.1.6-candidate-1/Offhand.exe','166C6BD750282C4EFDDE12BBE4A64DAFB1E88B2A29C826A86365FEFF741D4879'),
    @('dist/companion-2.1.6-store-submission/Offhand-Companion_2_1_600_0_x64.msix','87866739AFBA3BD6C9C73FA39F37C4E11CCE80D25A58A3E45C6B21F4234F2691')
)) {
    $path=Join-Path $root $artifact[0]
    if(Test-Path -LiteralPath $path){
        if((Get-FileHash -LiteralPath $path).Hash-ne $artifact[1]){throw 'Submitted 2.1.6 artifact changed.'}
        $frozen[$path]=$artifact[1]
    }
}
New-Item -ItemType Directory -Path $output|Out-Null
& (Join-Path $PSScriptRoot 'Test-CompanionInteractionBoundary.ps1') -OutputPath (Join-Path $output 'interaction-audit.json')
$source=Join-Path $public 'Source'
$files=@('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs')|ForEach-Object{Join-Path $source $_}
$binary=Join-Path $output 'Offhand.exe'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu "/out:$binary" "/win32icon:$root/Media/offhand-logo.ico" "/win32manifest:$source/app.manifest" "/resource:$root/Media/offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll @files
if($LASTEXITCODE-ne 0){throw 'Companion candidate compilation failed.'}
$identity=[Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
if($identity.FileVersion-ne '2.1.7.4' -or $identity.ProductVersion-ne '2.1.7'){throw 'Unexpected production candidate identity.'}
$readme=@'
Offhand Companion {{VERSION}}, unpublished release candidate (build 2.1.7.4).
SHA-256: {{EXE_SHA256}}

This production candidate uses ordinary portable preferences and supports manual
and configured automatic spanning. Exit other Companion instances before use.
Keep the published installation available for rollback. This is not UI Preview.

Setup and Advanced now separate ordinary display selection from custom layouts,
profiles, Auto-span, diagnostics and the log. The centered tabs are smaller than
the main Span/Restore actions. The branded header shows detected addon metadata.
Store installations check quietly every six hours and show their last check in
Advanced and the Store button tooltip. Failed attempts wait six hours too.
A skippable first-run tutorial introduces the controls and can be replayed from
Help > Start Companion tutorial. It does not apply layouts or change selections.
New two-monitor custom drafts use the full Offhand monitor; saved areas remain.
Saving Standard tells you when WoW still has the previous layout. After a span,
the dashboard reminds you to type /reload in WoW. Current and older Companion
previews share a single running instance with the release build.

Enable Offhand in WoW, log into a character and use Windowed mode. Select your
displays and Mainhand, then click Span WoW Now and type /reload in WoW. On first
setup, use /offhand guide and complete placement review, calibration and any
Mainhand HUD layout/reload prompts. Restore returns WoW to a normal window.

The published addon remains compatible through protocol 1. The matching
Pre-Release Beta 32 addon exposes per-workspace panel sizing. Store builds keep
package-local settings and quiet Store update detection; portable update checks
remain manual. Store delivery, certification and rollout are separate.

This candidate is not published. Do not replace the official GitHub/Store release
with it. See the preparation report for exact checks and remaining limitations.
'@
$archive=Join-Path $output 'Offhand-Companion-v2.1.7-candidate.zip'
& (Join-Path $PSScriptRoot 'New-CompanionTestPackage.ps1') -BinaryPath $binary -OutputPath $archive -Version '2.1.7' -ReadmeTemplate $readme|Out-Null
$inputs=[ordered]@{}
foreach($file in $files){$inputs[[IO.Path]::GetFileName($file)]=(Get-FileHash -LiteralPath $file).Hash}
$inputs['app.manifest']=(Get-FileHash -LiteralPath (Join-Path $source 'app.manifest')).Hash
$record=[ordered]@{version='2.1.7';fileVersion=$identity.FileVersion;packageVersion='2.1.700.0';
    sourceRevision=(& git -C $root rev-parse HEAD).Trim();sourceInputs=$inputs;
    trackedChanges=[bool]@(& git -C $root status --porcelain --untracked-files=no).Count;
    binarySha256=(Get-FileHash -LiteralPath $binary).Hash;archiveSha256=(Get-FileHash -LiteralPath $archive).Hash;
    publication='unpublished';addonProtocol=1;matchingAddon='2.1.5 Pre-Release Beta 32';
    uiPreview=$false;firstRunTutorial=$true}
$record|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $output 'candidate.json') -Encoding UTF8
@("$($record.binarySha256)  Offhand.exe","$($record.archiveSha256)  $([IO.Path]::GetFileName($archive))")|
    Set-Content -LiteralPath (Join-Path $output 'checksums-sha256.txt') -Encoding ASCII
foreach($path in $frozen.Keys){if((Get-FileHash -LiteralPath $path).Hash-ne $frozen[$path]){throw 'Frozen public artifact changed.'}}
Write-Output "Prepared unpublished Companion 2.1.7: $archive"
