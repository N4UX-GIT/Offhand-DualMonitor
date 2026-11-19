param([string]$LuaPath)
$ErrorActionPreference = 'Stop'
if (-not $LuaPath) { $LuaPath = (Get-Command lua.exe -ErrorAction Stop).Source }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = [IO.Path]::GetFullPath((Join-Path $temporaryBase ('Offhand-four-fixture-' + [guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $executable = Join-Path $fixtureRoot 'fixture.exe'
    & $compiler /nologo /target:exe /main:Offhand.Companion.FourMonitorTest "/out:$executable" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot '..\Companion\Source\LayoutDocument.cs') (Join-Path $PSScriptRoot '..\Companion\Source\WorkspaceLayoutService.cs') (Join-Path $PSScriptRoot '..\Companion\Source\FlexibleWorkspaceEditor.cs') (Join-Path $PSScriptRoot 'CompanionFourMonitors.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Four-monitor fixture compilation failed.' }
    & $executable $fixtureRoot (Join-Path $PSScriptRoot "..")
    if ($LASTEXITCODE -ne 0) { throw 'Four-monitor checks failed.' }
    Push-Location (Join-Path $PSScriptRoot '..')
    try {
        foreach ($schema in 'schema2', 'schema3') {
            & $LuaPath tests/four-monitor-topology.lua (Join-Path $fixtureRoot ($schema + '.lua'))
            if ($LASTEXITCODE -ne 0) { throw "Companion four-monitor bridge rejected by Lua: $schema" }
        }
    } finally { Pop-Location }
} finally {
    if (-not $fixtureRoot.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase) -or
         (Split-Path -Leaf $fixtureRoot) -notmatch '^Offhand-four-fixture-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the dedicated temporary fixture directory.'
    }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
