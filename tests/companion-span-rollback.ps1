$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
foreach ($architecture in @('x64','x86')) {
    $output = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-span-rollback-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        & $compiler /nologo /target:exe "/platform:$architecture" /main:Offhand.Companion.SpanRollbackTest "/out:$output" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionSpanRollback.cs')
        if ($LASTEXITCODE -ne 0) { throw 'Span rollback test compilation failed.' }
        & $output
        if ($LASTEXITCODE -ne 0) { throw "Span rollback checks failed ($architecture)." }
    } finally { if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output } }
}
