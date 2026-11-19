param(
    # Allows the same regression to verify the Config.lua extracted from a QA archive.
    [string]$ConfigPath = (Join-Path $PSScriptRoot '../Core/Config.lua'),
    [string]$SourceDirectory = (Join-Path $PSScriptRoot '../Companion/Source')
)
$ErrorActionPreference = 'Stop'
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$lua = (Get-Command lua -ErrorAction Stop).Source
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-recovery-' + [guid]::NewGuid().ToString('N') + '.exe')
$source = (Resolve-Path -LiteralPath $SourceDirectory -ErrorAction Stop).Path
try {
    & $compiler /nologo /target:exe /main:Offhand.Companion.ForeverRecoveryTest "/out:$testExe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $source 'Program.cs') (Join-Path $source 'LayoutDocument.cs') (Join-Path $source 'WorkspaceLayoutService.cs') (Join-Path $source 'FlexibleWorkspaceEditor.cs') (Join-Path $PSScriptRoot 'CompanionForeverRecovery.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Companion recovery fixture compilation failed' }
    & $testExe $lua $ConfigPath
    if ($LASTEXITCODE -ne 0) { throw 'Companion recovery regression failed' }
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
