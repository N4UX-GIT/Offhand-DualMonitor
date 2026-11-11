param([Parameter(Mandatory = $true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
$publicDirectory = [IO.Path]::GetFullPath((Join-Path $root 'Companion'))
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh dashboard preview directory.' }
if ($output.Equals($publicDirectory, [StringComparison]::OrdinalIgnoreCase) -or
    $output.StartsWith($publicDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Preview output must be outside the public Companion directory.'
}
$frozen = @{}
foreach ($name in @('Offhand.exe', 'Offhand-Companion.zip', 'Prepared/2.1.5/Offhand.exe', 'Prepared/2.1.5/Offhand-Companion-v2.1.5.zip')) {
    $path = Join-Path $publicDirectory $name
    $frozen[$path] = (Get-FileHash -LiteralPath $path).Hash
}
New-Item -ItemType Directory -Path $output | Out-Null
& (Join-Path $PSScriptRoot 'Test-CompanionInteractionBoundary.ps1') -OutputPath (Join-Path $output 'interaction-audit.json')
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$sourceDirectory = Join-Path $publicDirectory 'Source'
$files = @('Program.cs', 'LayoutDocument.cs', 'WorkspaceLayoutService.cs', 'FlexibleWorkspaceEditor.cs') |
    ForEach-Object { Join-Path $sourceDirectory $_ }
$binary = Join-Path $output 'Offhand.exe'
$options = @('/nologo', '/target:winexe', '/optimize+', '/platform:anycpu', '/define:UI_PREVIEW',
    "/out:$binary", "/win32manifest:$sourceDirectory\app.manifest", "/win32icon:$root\Media\offhand-logo.ico",
    "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png",
    '/r:System.dll', '/r:System.Drawing.dll', '/r:System.Web.Extensions.dll', '/r:System.Windows.Forms.dll')
& $compiler @options @files
if ($LASTEXITCODE -ne 0) { throw 'Dashboard preview compilation failed.' }
$identity = [Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
if ($identity.FileVersion -ne '2.1.7.8005' -or $identity.ProductVersion -ne '2.1.7') {
    throw 'Unexpected dashboard preview identity.'
}
$binaryHash = (Get-FileHash -LiteralPath $binary).Hash
@('AutoSpan=False', 'DashboardCollapsed.SystemStatus=True',
    'DashboardCollapsed.DisplayDiagnostics=True', 'DashboardCollapsed.ActivityLog=True') |
    Set-Content -LiteralPath (Join-Path $output 'DashboardPreviewConfig.ini') -Encoding UTF8
@'
Offhand Companion 2.1.7 UI Preview 5, local build 2.1.7.8005. Unpublished.
Executable SHA-256 {{EXE_SHA256}}

Extract the archive to a writable folder. Use Exit Companion in the running
Companion, if open, then run Offhand.exe. The preview shares a single running
instance with releases and older previews to protect the layout WoW reads.
Preview settings live in DashboardPreviewConfig.ini beside the EXE.
Automatic spanning and graphics-reset recovery are disabled in this preview.
Span WoW Now and Restore Window act on your real WoW window.

1. Open WoW in Windowed mode with Offhand enabled. In Advanced > Workspace
   layout, choose Flexible Layout and save a plan with the game between two
   workspaces. Click Span WoW Now and type /reload in WoW.
2. In Advanced, choose Use standard display layout and confirm. The reminder
   explains that WoW still has the previous layout and gives the next step.
3. For a two-display span, review the displays in Setup. For a one-display
   split, select one display and enable Single-display 32:9 split. Click
   Span WoW Now. The reminder below the action buttons asks you to type /reload.
4. Type /reload in WoW to load Standard, then dismiss the reminder in Companion.
   With one display and no split, use Restore Window for ordinary play.

Use Exit Companion to close the preview. You can use Help > Start Companion
tutorial to replay the first-run walkthrough.
'@ | ForEach-Object { $_.Replace('{{EXE_SHA256}}', $binaryHash) } |
    Set-Content -LiteralPath (Join-Path $output 'README.txt') -Encoding UTF8
$inputs = [ordered]@{}
foreach ($file in $files) { $inputs[[IO.Path]::GetFileName($file)] = (Get-FileHash -LiteralPath $file).Hash }
$record = [ordered]@{
    kind = 'local-dashboard-preview'; fileVersion = $identity.FileVersion
    sourceRevision = (& git -C $root rev-parse HEAD).Trim()
    sourceInputs = $inputs; binarySha256 = $binaryHash
    settingsFile = 'DashboardPreviewConfig.ini'; automaticSpanning = $false; graphicsRecovery = $false
    publication = 'unpublished'
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'preview.json') -Encoding UTF8
foreach ($path in $frozen.Keys) {
    if ((Get-FileHash -LiteralPath $path).Hash -ne $frozen[$path]) { throw 'Frozen public artifact changed.' }
}
Write-Output "Built dashboard preview: $binary"
