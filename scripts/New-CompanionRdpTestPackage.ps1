param([Parameter(Mandatory = $true)][string]$OutputDirectory)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$output = [IO.Path]::GetFullPath($OutputDirectory)
$publicDirectory = Join-Path $root 'Companion'
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh RDP test output directory.' }
if ($output.StartsWith($publicDirectory + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'RDP test output must be outside the public Companion directory.'
}

$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$source = Join-Path $publicDirectory 'Source'
$manifest = Join-Path $source 'app.manifest'
$files = 'Program.cs', 'LayoutDocument.cs', 'WorkspaceLayoutService.cs', 'FlexibleWorkspaceEditor.cs' |
    ForEach-Object { Join-Path $source $_ }
New-Item -ItemType Directory -Path $output | Out-Null
& (Join-Path $PSScriptRoot 'Test-CompanionInteractionBoundary.ps1') -OutputPath (Join-Path $output 'interaction-audit.json')
$binary = Join-Path $output 'Offhand.exe'
$compileOptions = @(
    '/nologo', '/target:winexe', '/optimize+', '/platform:anycpu', '/define:RDP_TEST',
    "/out:$binary", "/win32manifest:$manifest", "/win32icon:$root\Media\offhand-logo.ico",
    "/resource:$root\Media\offhand-logo-small.png,Offhand.Companion.Resources.offhand-logo.png",
    '/r:System.dll', '/r:System.Drawing.dll', '/r:System.Web.Extensions.dll', '/r:System.Windows.Forms.dll'
)
& $compiler @compileOptions @files
if ($LASTEXITCODE -ne 0) { throw 'RDP test executable compilation failed.' }

$identity = [Diagnostics.FileVersionInfo]::GetVersionInfo($binary)
if ($identity.FileVersion -ne '2.1.3.7001' -or $identity.ProductVersion -ne '2.1.3-beta.6') {
    throw 'Unexpected RDP test executable version.'
}
$readme = @'
Offhand Companion {{VERSION}}

This portable beta tests manual two-display spanning over Windows Remote Desktop.
Extract the ZIP into a writable folder and exit the regular Offhand Companion
through its tray menu. Run Offhand.exe in the same RDP connection as WoW.
Look for RDP Test 1 in the Companion title.

1. Start one WoW client in standard Windowed mode and log in.
2. Use Identify Displays in Companion if needed, then click Span WoW Now.
3. Choose the Mainhand (game) and Offhand (workspace) screens. Click Span WoW.
4. Use /reload once in WoW. Confirm the game and workspace land on the chosen screens.
5. Click Restore Window. Test the opposite Mainhand choice after restoring.
6. With WoW spanned, disconnect and reconnect. Verify Companion asks you to
   choose the screens again. Use Restore Window if needed, then span again.

Keep Companion open during the test. Use Restore Window before returning to the
regular Companion. The beta stores its preferences in RdpTestConfig.ini next
to Offhand.exe. RDP screen selections last for the current connection.
If a step fails, copy the relevant Activity Log lines and report which step failed.

Offhand.exe SHA-256
{{EXE_SHA256}}
'@
$archive = Join-Path $output 'Offhand-Companion-v2.1.3-beta.6-rdp-test1.zip'
& (Join-Path $PSScriptRoot 'New-CompanionTestPackage.ps1') -BinaryPath $binary -OutputPath $archive -Version '2.1.3 Beta 6 RDP Test 1' -ReadmeTemplate $readme
