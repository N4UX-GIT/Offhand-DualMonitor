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
if ($identity.FileVersion -ne '2.1.7.8001' -or $identity.ProductVersion -ne '2.1.7') {
    throw 'Unexpected dashboard preview identity.'
}
@('AutoSpan=False', 'DashboardCollapsed.SystemStatus=True',
    'DashboardCollapsed.DisplayDiagnostics=True', 'DashboardCollapsed.ActivityLog=True') |
    Set-Content -LiteralPath (Join-Path $output 'DashboardPreviewConfig.ini') -Encoding UTF8
@'
Offhand Companion UI Preview 1, local build 2.1.7.8001. Unpublished.

Run Offhand.exe to review the updated dashboard. It can coexist with the regular
Companion. Preferences stay in DashboardPreviewConfig.ini beside this EXE;
public/Store preferences are not imported. Automatic spanning and graphics-reset
recovery are disabled. Manual Span and Restore remain available.

A first-run Companion tutorial highlights the controls and explains their use.
Next/Back navigate, Skip tour or Escape dismisses it, and Finish completes it.
The tutorial never changes selections or applies a layout. Replay it from Help
using Start Companion tutorial. Only its dismissal flag is saved.

Normal Setup has no action captions or permanent setup-instructions card.
Setup/Advanced and Span/Restore use a centered, equal-width two-column grid.
Tabs are 32px high at 100% scaling; actions remain 44px. Tab text stays the same.
Advanced contains custom layouts/profiles, standard-layout reset, Auto-span,
diagnostics and the log. Tabs keep subtle borders and a selected underline.

Tab changes and Show/Hide must keep the window size stable. This preview intentionally disables
automatic spanning; the production auto-span restrictions remain unchanged.
Use Exit Companion to close this preview; the regular installation stays open.
'@ | Set-Content -LiteralPath (Join-Path $output 'README.txt') -Encoding UTF8
$inputs = [ordered]@{}
foreach ($file in $files) { $inputs[[IO.Path]::GetFileName($file)] = (Get-FileHash -LiteralPath $file).Hash }
$record = [ordered]@{
    kind = 'local-dashboard-preview'; fileVersion = $identity.FileVersion
    sourceRevision = (& git -C $root rev-parse HEAD).Trim()
    sourceInputs = $inputs; binarySha256 = (Get-FileHash -LiteralPath $binary).Hash
    settingsFile = 'DashboardPreviewConfig.ini'; automaticSpanning = $false; graphicsRecovery = $false
    publication = 'unpublished'
}
$record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $output 'preview.json') -Encoding UTF8
foreach ($path in $frozen.Keys) {
    if ((Get-FileHash -LiteralPath $path).Hash -ne $frozen[$path]) { throw 'Frozen public artifact changed.' }
}
Write-Output "Built dashboard preview: $binary"
