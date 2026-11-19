$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$source=Join-Path $root 'Companion/Source'
$files=@('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs')|ForEach-Object{Join-Path $source $_}
foreach($architecture in @('x64','x86')) {
    $binary=Join-Path ([IO.Path]::GetTempPath()) ('Offhand-notices-'+[guid]::NewGuid().ToString('N')+'.exe')
    try {
        & "$env:WINDIR/Microsoft.NET/Framework64/v4.0.30319/csc.exe" /nologo /target:exe /main:Offhand.Companion.UpdateNoticesTest "/platform:$architecture" "/out:$binary" /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll @files (Join-Path $PSScriptRoot 'CompanionUpdateNotices.cs')
        if($LASTEXITCODE-ne 0){throw 'Notice fixture compilation failed.'}
        & $binary
        if($LASTEXITCODE-ne 0){throw 'Notice lifecycle fixture failed.'}
    } finally { Remove-Item -LiteralPath $binary -Force -ErrorAction SilentlyContinue }
}
