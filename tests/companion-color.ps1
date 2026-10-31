param([string]$PreviewPath, [switch]$DiagnosticsTest)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
foreach ($architecture in @('x64', 'x86')) {
    $testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-color-' + [guid]::NewGuid().ToString() + '.exe')
    try {
        $candidateFlags = @()
        if ($DiagnosticsTest) { $candidateFlags += '/define:HDR_DPI_DIAGNOSTICS_TEST' }
        & $compiler /nologo /target:exe @candidateFlags "/platform:$architecture" /main:Offhand.Companion.ColorTest "/out:$testExe" "/win32manifest:$(Join-Path $PSScriptRoot '..\Companion\Source\app.manifest')" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionColor.cs')
        if ($LASTEXITCODE -ne 0) { throw 'Companion color test compilation failed' }
        if ($PreviewPath -and $architecture -eq 'x64') { & $testExe $PreviewPath } else { & $testExe }
        if ($LASTEXITCODE -ne 0) { throw "Companion color tests failed ($architecture)" }
    } finally {
        if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
    }
}
