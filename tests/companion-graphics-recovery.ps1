param([switch]$Retail,[switch]$Forever)
$ErrorActionPreference = 'Stop'
if ($Retail -and $Forever) { throw 'Choose one client scope.' }
$root = Split-Path -Parent $PSScriptRoot
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$output = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-classic-recovery-' + [guid]::NewGuid().ToString() + '.exe')
try {
    $define = if ($Forever) { '/define:FOREVER_GRAPHICS_RECOVERY_TEST' } elseif ($Retail) { "/define:RETAIL_GRAPHICS_RECOVERY_TEST" } else { "/define:CLASSIC_GRAPHICS_RECOVERY_TEST" }
    & $compiler /nologo /target:exe $define /main:Offhand.Companion.ClassicGraphicsRecoveryTest "/out:$output" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root 'Companion\Source\Program.cs') (Join-Path $PSScriptRoot 'ClassicGraphicsRecovery.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Classic recovery test compilation failed' }
    & $output
    if ($LASTEXITCODE -ne 0) { throw 'Classic recovery regression failed' }
} finally { if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output } }
