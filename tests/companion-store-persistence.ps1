param([switch]$InstalledStoreContext, [string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root ('dist/store-persistence-test-' + [guid]::NewGuid().ToString('N')) }
$output = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $output -Force | Out-Null
$exe = Join-Path $output 'StorePersistenceTest.exe'
$sources = @('Program.cs','LayoutDocument.cs','WorkspaceLayoutService.cs','FlexibleWorkspaceEditor.cs') | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $root "Companion/Source/$_")) }
$testSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'CompanionStorePersistence.cs'))
$manifest = [IO.Path]::GetFullPath((Join-Path $root 'Companion/Source/app.manifest'))
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe /main:Offhand.Companion.StorePersistenceTest "/out:$exe" "/win32manifest:$manifest" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll $sources $testSource
if ($LASTEXITCODE -ne 0) { throw 'Store persistence test compilation failed.' }
$result = Join-Path $output 'store-persistence-result.txt'
if (Test-Path -LiteralPath $result) { throw 'Choose a fresh test output directory.' }
if ($InstalledStoreContext) {
    $package = Get-AppxPackage -Name N4UX.OffhandCompanion
    if (!$package) { throw 'An installed Offhand Store package is required.' }
    # Launch only this isolated fixture with package identity. Never launch WoW,
    # replace/install a package, or write the real Companion preferences.
    Invoke-CommandInDesktopPackage -PackageFamilyName $package.PackageFamilyName -AppId OffhandCompanion -Command $exe -Args ('"' + $output + '"') -PreventBreakaway
    $deadline = (Get-Date).AddSeconds(30)
    while (!(Test-Path -LiteralPath $result) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
    if (!(Test-Path -LiteralPath $result)) { throw 'Packaged persistence fixture did not return a result.' }
    $text = [IO.File]::ReadAllText($result)
    Write-Output $text
    if (!$text.StartsWith('PASS:') -or !$text.Contains('package=N4UX.OffhandCompanion_')) { throw 'Packaged persistence regression failed.' }
} else {
    & $exe $output
    if ($LASTEXITCODE -ne 0) { throw 'Portable persistence regression failed.' }
}
