$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-selection-' + [guid]::NewGuid().ToString() + '.exe')
try {
    & $compiler /nologo /target:exe /main:Offhand.Companion.DisplaySelectionTest "/out:$testExe" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionDisplaySelection.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Display selection test compilation failed' }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw 'Display selection regression failed' }
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
