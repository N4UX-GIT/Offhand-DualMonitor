$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$output = Join-Path ([IO.Path]::GetTempPath()) 'CompanionDisplayPreview.exe'
& $compiler /nologo /target:exe /main:Offhand.Companion.DisplayPreviewTest "/out:$output" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot '..\Companion\Source\LayoutDocument.cs') (Join-Path $PSScriptRoot '..\Companion\Source\WorkspaceLayoutService.cs') (Join-Path $PSScriptRoot '..\Companion\Source\FlexibleWorkspaceEditor.cs') (Join-Path $PSScriptRoot 'CompanionDisplayPreview.cs')
if ($LASTEXITCODE -ne 0) { throw 'CompanionDisplayPreview compile failed' }
& $output @args
if ($LASTEXITCODE -ne 0) { throw 'CompanionDisplayPreview failed' }
