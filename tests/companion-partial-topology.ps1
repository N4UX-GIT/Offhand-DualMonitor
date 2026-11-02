$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$lua = (Get-Command lua.exe -ErrorAction Stop).Source
$temporaryBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot = [IO.Path]::GetFullPath((Join-Path $temporaryBase ('Offhand-partial-fixture-' + [guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
try {
    $executable = Join-Path $fixtureRoot 'fixture.exe'
    & $compiler /nologo /target:exe /main:Offhand.Companion.PartialTopologyTest "/out:$executable" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'CompanionPartialTopology.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Partial topology fixture compilation failed.' }
    & $executable $fixtureRoot
    if ($LASTEXITCODE -ne 0) { throw 'Partial topology generation failed.' }
    Push-Location (Join-Path $PSScriptRoot '..')
    try {
        & $lua (Join-Path $PSScriptRoot 'support\partial-topology-bridge.lua') $fixtureRoot
        if ($LASTEXITCODE -ne 0) { throw 'Generated partial topology Lua acceptance failed.' }
    } finally { Pop-Location }
} finally {
    if (-not $fixtureRoot.StartsWith($temporaryBase, [StringComparison]::OrdinalIgnoreCase) -or
         (Split-Path -Leaf $fixtureRoot) -notmatch '^Offhand-partial-fixture-[a-f0-9]{32}$') {
        throw 'Refusing cleanup outside the dedicated temporary fixture directory.'
    }
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
