$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'C# compiler unavailable' }
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-preferences-' + [guid]::NewGuid().ToString() + '.exe')
try {
    & $compiler /nologo /target:exe /main:Offhand.Companion.PreferencesTest "/out:$testExe" /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionPreferences.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Companion test compilation failed' }
    & $testExe
    if ($LASTEXITCODE -ne 0) { throw 'Companion preference test failed' }
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
