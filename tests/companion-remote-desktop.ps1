$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$source = Join-Path $PSScriptRoot '..\Companion\Source'
$files = 'Program.cs', 'LayoutDocument.cs', 'WorkspaceLayoutService.cs', 'FlexibleWorkspaceEditor.cs' |
    ForEach-Object { Join-Path $source $_ }
foreach ($architecture in 'x64', 'x86') {
    $output = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-rdp-test-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        & $compiler /nologo /target:exe "/platform:$architecture" /main:Offhand.Companion.CompanionRemoteDesktopTest "/out:$output" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll $files (Join-Path $PSScriptRoot 'CompanionRemoteDesktop.cs')
        if ($LASTEXITCODE -ne 0) { throw "Remote Desktop tests did not compile ($architecture)." }
        & $output
        if ($LASTEXITCODE -ne 0) { throw "Remote Desktop tests failed ($architecture)." }
    } finally {
        if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output }
    }
}
