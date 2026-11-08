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
foreach ($name in @('Offhand.exe', 'Offhand-Companion.zip')) {
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
if ($identity.FileVersion -ne '2.1.4.8001' -or $identity.ProductVersion -ne '2.1.4') {
    throw 'Unexpected dashboard preview identity.'
}
@('AutoSpan=False', 'DashboardCollapsed.SystemStatus=True', 'DashboardCollapsed.Configuration=False',
    'DashboardCollapsed.DisplayDiagnostics=True', 'DashboardCollapsed.ActivityLog=True') |
    Set-Content -LiteralPath (Join-Path $output 'DashboardPreviewConfig.ini') -Encoding UTF8
@'
Offhand Companion UI Preview 3, local build 2.1.4.8001. Unpublished.

Run Offhand.exe to review the updated dashboard. It can coexist with the regular
Companion. Preferences stay in DashboardPreviewConfig.ini beside this EXE;
public/Store preferences are not imported. Automatic spanning and graphics-reset
recovery are disabled. Manual Span and Restore remain available.

Review the larger primary actions, short reload guidance, collapsed status,
panel toggles, workspace editors and tray Pause/Resume background monitoring.
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
