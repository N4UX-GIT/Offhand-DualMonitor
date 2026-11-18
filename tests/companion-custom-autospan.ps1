$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$output = Join-Path ([IO.Path]::GetTempPath()) 'CompanionCustomAutoSpan.exe'
& $compiler /nologo /target:exe /main:Offhand.Companion.CustomAutoSpanTest "/out:$output" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot '..\Companion\Source\LayoutDocument.cs') (Join-Path $PSScriptRoot '..\Companion\Source\WorkspaceLayoutService.cs') (Join-Path $PSScriptRoot '..\Companion\Source\FlexibleWorkspaceEditor.cs') (Join-Path $PSScriptRoot 'CompanionCustomAutoSpan.cs')
if ($LASTEXITCODE -ne 0) { throw 'CompanionCustomAutoSpan compile failed' }
& $output
if ($LASTEXITCODE -ne 0) { throw 'CompanionCustomAutoSpan failed' }
