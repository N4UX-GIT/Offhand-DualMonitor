param([Parameter(Mandatory = $true)][string]$OutputDirectory, [switch]$CustomRegionsPrototype)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh candidate directory.' }
# A candidate must never replace canonical public artifacts.
$companionRoot = [IO.Path]::GetFullPath((Join-Path $root 'Companion'))
if ($output.Equals($companionRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($companionRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Candidate output must be outside the public Companion directory.'
}
$publicBinary = Join-Path $companionRoot 'Offhand.exe'
$publicArchive = Join-Path $companionRoot 'Offhand-Companion.zip'
$publicHash = (Get-FileHash -LiteralPath $publicBinary).Hash
$publicArchiveHash = (Get-FileHash -LiteralPath $publicArchive).Hash
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$source = Join-Path $companionRoot 'Source\Program.cs'
$appManifest = Join-Path $companionRoot 'Source\app.manifest'
New-Item -ItemType Directory -Path $output | Out-Null
$interactionAudit = Join-Path $output 'interaction-audit.json'
& (Join-Path $PSScriptRoot 'Test-CompanionInteractionBoundary.ps1') -OutputPath $interactionAudit
$binary = Join-Path $output 'Offhand.exe'
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu "/out:$binary" "/win32icon:$root\Media\offhand-logo.ico" "/win32manifest:$appManifest" "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll $source (Join-Path (Split-Path -Parent $source) LayoutDocument.cs) (Join-Path (Split-Path -Parent $source) WorkspaceLayoutService.cs) (Join-Path (Split-Path -Parent $source) FlexibleWorkspaceEditor.cs)
if ($LASTEXITCODE -ne 0) { throw 'Candidate compilation failed.' }
$identity = [Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
if ($identity.FileVersion -ne '2.1.3.7' -or $identity.ProductVersion -ne '2.1.3-beta.6') {
    throw 'Candidate executable version does not match the planned release.'
}
$archive = Join-Path $output 'Offhand-Companion-v2.1.3-beta.6.zip'
& (Join-Path $PSScriptRoot 'New-CompanionTestPackage.ps1') -BinaryPath $binary -OutputPath $archive -Version '2.1.3-beta.6' | Out-Null
$readme = @'
Offhand Companion 2.1.3 Beta 6: local release candidate, live QA pending.

Exit any other Companion through its tray menu before testing this build.
This ordinary runtime uses your existing Companion preferences. Preserve your
known-good public installation and configuration for rollback. Nothing in this
build has been published to GitHub or the Microsoft Store.

Graphics-reset recovery is enabled only for Retail and Anniversary directories.
A manual or delayed automatic span must first remain stable to arm it. Restore
Window, Pause Monitor and display edits cancel recovery. Restarting Companion
does not infer a recovery arm from an existing span. Three attempts per five
minutes are allowed; failure or unstable recovery stops automatic retries.
Other clients retain ordinary Span/Restore without graphics-reset recovery.
The graininess resize sequence is disabled. Custom regions are not included.

After spanning with a loaded character UI, use /reload once. Test initial span,
graphics Apply, repeated recovery, Restore, Pause/Resume, display changes and
cold launch using the source checkout's COMPANION-PRODUCTION-RECOVERY-QA.md.
Forever graphics recovery remains outside this production candidate's scope.
'@
if ($CustomRegionsPrototype) {
    $readme = $readme.Replace('local release candidate, live QA pending.', 'CUSTOM WORKSPACE REGIONS PROTOTYPE, unpublished.')
    $readme = $readme.Replace('Custom regions are not included.', @'
Custom region opens a layout chooser showing the currently saved mode.
Choose one monitor or two monitors to open the corresponding editor. The saved
custom mode is the default keyboard choice. Cancel leaves the plan unchanged.
Save plan changes settings only; Span WoW Now applies it. For one monitor, set occupied width,
workspace width, monitor edge and game side. Reserved pixels remain outside WoW.
Select area on monitor opens a visual overlay. Drag its dividers to resize,
drag the occupied area to snap between monitor edges, or swap the two sides.
Use selection returns to the editor; Save plan commits settings. Escape cancels.
Two-monitor workspace keeps the full game monitor and selects one rectangular
workspace on a second monitor. Move or resize its overlay, or enter its offsets
and dimensions. Unused secondary pixels and physical gaps are clipped. The
preview reports the backing surface, which can include clipped pixels.
Custom regions are manual-only; graphics-reset recovery is not armed for them.
Use Restore Window to return to the ordinary window. Disable the custom mode's
checkbox in its editor to return to the existing two-display or equal-half modes.
Narrow panels may not fit or remain readable; use Mainhand for those panels.
Flexible layout prototype adds an explicit single-display editor with centered,
stacked and one-side presets plus numeric rectangles. Enable its checkbox, review
the preview and Save plan. Span WoW Now and a manual /reload apply the layout.
The new topology schema 3 requires the matching addon. Schema 1/2 behavior stays
available. Flexible plans use a version 2 profile store copied from version 1;
the original version 1 store is retained. Disable flexible mode and save to
restore the prior geometry settings before using an older Companion. Restore
Window remains the native recovery action. Automatic apply/reload is disabled.
This prototype is not the complete future grid/freeform editor.
Multiple workspaces opens an experimental editor for one full game monitor and
one or two workspaces on different monitors. Choose Workspace A/B and a primary,
then move or resize each area's visual overlay. Existing one-monitor and
two-monitor custom modes retain schema 1. Multiple workspaces requires the new
addon's declared topology capability and uses schema 2. Missing or ambiguous
selected displays refuse apply. The initial outer-surface budget is 16384 pixels
per axis and four times the game area; this is not a renderer support guarantee.
Multiple workspaces can be disabled even when a required display is missing.
Saved region definitions are retained. Choose connected span displays in the
main window before applying a standard layout. Re-enabling a saved custom plan
still requires every configured display. Inactive area controls are disabled.
Physical three-display, combat and mixed-DPI acceptance remain pending.
Workspace profiles saves named Multiple workspaces plans, with stable identities.
Loading selects settings only. Span WoW Now applies the plan; /reload selects its
matching addon workspace layout. Missing monitors or changed resolutions refuse
loading. Save, update, rename and delete leave launcher/update preferences intact.
Addon Profiles offers independent workspace layout presets. Workspace offers
opt-in routing for Map, Character, Spells, Collections, Achievements and Journal.
Manual moves take precedence; Use routing again explicitly clears those moves.
Themes offers a separate preset per custom region, or global theme inheritance.
The current addon also supports independent image/theme and image-fit preferences
per region, with an optional two-image code-free Background Studio library.
Beta 6 gives the layout editors consistent dark fields, readable disabled
actions, display numbering, sticky validation feedback and a visual plan preview.
Workspace B is hidden when unused. Save is disabled while a plan is invalid;
disabling custom mode remains possible after monitor loss. Profile changes are
clearly staged until Save changes, and empty/duplicate actions are disabled.
In the rectangular selection overlay, arrows move 10 pixels, Ctrl+arrows move
one pixel, and Shift+arrows resize (Ctrl+Shift uses one-pixel steps). Enter uses
the selection and Escape cancels it. Overlay edits do not save the plan directly.
Native UI and regression checks do not replace physical mixed-DPI, third-monitor,
hotplug, protected-action/combat or full supported-client acceptance.
After a successful span, Companion notifies the Windows Shell that the actual
WoW window is fullscreen. Restore clears that notification. Shell notification
failure is nonfatal and logged. Global taskbar preferences are unchanged.
'@)
}
# Replace only the generated README, retaining the same verified executable.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($archive, [IO.Compression.ZipArchiveMode]::Update)
try {
    $zip.GetEntry('README.txt').Delete()
    $entry = $zip.CreateEntry('README.txt')
    $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
    try { $writer.Write($readme) } finally { $writer.Dispose() }
} finally { $zip.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    if ((@($zip.Entries.FullName | Sort-Object) -join '|') -ne 'LICENSE|Offhand.exe|README.txt') { throw 'Unexpected runtime archive entries.' }
    $stream = $zip.GetEntry('Offhand.exe').Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $embeddedHash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
    if ($embeddedHash -ne (Get-FileHash -LiteralPath $binary).Hash) { throw 'Archived candidate executable mismatch.' }
} finally { $zip.Dispose() }
if ((Get-FileHash -LiteralPath $publicBinary).Hash -ne $publicHash -or
    (Get-FileHash -LiteralPath $publicArchive).Hash -ne $publicArchiveHash) { throw 'Canonical public artifacts changed.' }
$dirty = @(& git -C $root status --porcelain --untracked-files=no)
$record = [ordered]@{
    version='2.1.3-beta.6'; fileVersion=$identity.FileVersion
    sourceRevision=(& git -C $root rev-parse HEAD).Trim(); trackedChanges=[bool]$dirty.Count
    programSha256=(Get-FileHash -LiteralPath $source).Hash
    interactionAuditSha256=(Get-FileHash -LiteralPath $interactionAudit).Hash
    layoutDocumentSha256=(Get-FileHash -LiteralPath (Join-Path (Split-Path -Parent $source) LayoutDocument.cs)).Hash
    flexibleEditorSha256=(Get-FileHash -LiteralPath (Join-Path (Split-Path -Parent $source) FlexibleWorkspaceEditor.cs)).Hash
    layoutServiceSha256=(Get-FileHash -LiteralPath (Join-Path (Split-Path -Parent $source) WorkspaceLayoutService.cs)).Hash
    appManifestSha256=(Get-FileHash -LiteralPath $appManifest).Hash
    binarySha256=(Get-FileHash -LiteralPath $binary).Hash
    archiveSha256=(Get-FileHash -LiteralPath $archive).Hash
    frozenPublicSha256=$publicHash; frozenArchiveSha256=$publicArchiveHash
    recoveryClients=@('_retail_', '_anniversary_'); liveVerification='pending'
    customRegionsPrototype=[bool]$CustomRegionsPrototype
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'candidate.json') -Encoding UTF8
@("$($record.binarySha256)  Offhand.exe", "$($record.archiveSha256)  $([IO.Path]::GetFileName($archive))") |
    Set-Content -LiteralPath (Join-Path $output 'checksums-sha256.txt') -Encoding ASCII
Write-Output "Built and verified: $archive"
