[CmdletBinding(DefaultParameterSetName = 'Source')]
param(
    # Allows the same regression to verify the Config.lua extracted from a QA archive.
    [string]$ConfigPath,
    [Parameter(ParameterSetName = 'Source')]
    [string]$SourceDirectory,
    [Parameter(Mandatory, ParameterSetName = 'Binary')]
    [string]$CompanionPath
)
$ErrorActionPreference = 'Stop'
if (!$ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '../Core/Config.lua' }
$ConfigPath = (Resolve-Path -LiteralPath $ConfigPath -ErrorAction Stop).Path
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$lua = (Get-Command lua -ErrorAction Stop).Source
$testExe = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-recovery-' + [guid]::NewGuid().ToString('N') + '.exe')
try {
    $sources = @((Join-Path $PSScriptRoot 'CompanionForeverRecovery.cs'))
    $fixtureArgs = @($lua, $ConfigPath)
    if ($PSCmdlet.ParameterSetName -eq 'Binary') {
        $binary = (Resolve-Path -LiteralPath $CompanionPath).Path
        $sources += '/define:PACKAGED_COMPANION'
        $fixtureArgs += $binary
        Write-Output ("Testing Companion {0}, SHA-256 {1}" -f [Diagnostics.FileVersionInfo]::GetVersionInfo($binary).FileVersion, (Get-FileHash -LiteralPath $binary).Hash)
    } else {
        if (!$SourceDirectory) { $SourceDirectory = Join-Path $PSScriptRoot '../Companion/Source' }
        $source = (Resolve-Path -LiteralPath $SourceDirectory).Path
        $sources += @('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs') | ForEach-Object { Join-Path $source $_ }
    }
    & $compiler /nologo /target:exe /main:Offhand.Companion.ForeverRecoveryTest "/out:$testExe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll @sources
    if ($LASTEXITCODE -ne 0) { throw 'Companion recovery fixture compilation failed' }
    & $testExe @fixtureArgs
    if ($LASTEXITCODE -ne 0) { throw 'Companion recovery regression failed' }
} finally {
    if (Test-Path -LiteralPath $testExe) { Remove-Item -LiteralPath $testExe }
}
