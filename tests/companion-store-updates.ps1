$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'Companion/Source'
$files = @('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs') | ForEach-Object { Join-Path $source $_ }
foreach ($architecture in @('x64','x86')) {
foreach ($mode in @('production','preview')) {
    $binary = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-store-updates-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        $options = @("/platform:$architecture",'/nologo','/target:exe','/main:Offhand.Companion.StoreUpdatesTest',"/out:$binary",'/r:System.dll','/r:System.Core.dll','/r:System.Drawing.dll','/r:System.Web.Extensions.dll','/r:System.Windows.Forms.dll')
        if ($mode -eq 'preview') { $options += '/define:UI_PREVIEW' }
        & $compiler @options @files (Join-Path $PSScriptRoot 'CompanionStoreUpdates.cs')
        if ($LASTEXITCODE -ne 0) { throw 'Store update fixture did not compile.' }
        & $binary
        if ($LASTEXITCODE -ne 0) { throw 'Store update fixture failed.' }
    }
    finally { Remove-Item -LiteralPath $binary -Force -ErrorAction SilentlyContinue }
}
}
