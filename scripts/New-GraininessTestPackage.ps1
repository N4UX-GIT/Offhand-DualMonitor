param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$version = '2.1.2-beta.20-graininess.test2'
$output = Join-Path $OutputDirectory "Offhand-Companion-v$version.zip"
if (Test-Path -LiteralPath $output) { throw "Refusing to overwrite candidate: $output" }
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'C# compiler unavailable' }
$canonical = Join-Path $root 'Companion\Offhand.exe'
$beforeHash = (Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash
$staging = Join-Path $OutputDirectory ('graininess-staging-' + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $staging | Out-Null
$binary = Join-Path $staging 'Offhand.exe'
$source = Join-Path $root 'Companion\Source\Program.cs'
$testSource = Join-Path $root 'Companion\Source\SpanPresentationTest.cs'
& $compiler /nologo /target:winexe /optimize+ /platform:anycpu /define:GRAININESS_TEST "/out:$binary" `
    "/win32icon:$(Join-Path $root 'Media\offhand-logo.ico')" `
    "/win32manifest:$(Join-Path $root 'Companion\Source\app.manifest')" `
    "/resource:$(Join-Path $root 'Media\offhand-logo-small.png'),Offhand.Companion.Resources.offhand-logo.png" `
    /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll $source $testSource
if ($LASTEXITCODE -ne 0) { throw 'Candidate compilation failed' }
$testExe = Join-Path $staging 'GraininessChecks.exe'
& $compiler /nologo /target:exe /define:GRAININESS_TEST /main:Offhand.Companion.GraininessTest "/out:$testExe" `
    /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll `
    $source $testSource (Join-Path $root 'Tests\CompanionGraininess.cs')
if ($LASTEXITCODE -ne 0) { throw 'Candidate test compilation failed' }
& $testExe
if ($LASTEXITCODE -ne 0) { throw 'Candidate checks failed' }
Remove-Item -LiteralPath $testExe
Copy-Item -LiteralPath (Join-Path $root 'Companion\LICENSE') -Destination $staging
Copy-Item -LiteralPath (Join-Path $root 'docs\COMPANION-GRAININESS-TEST2.txt') -Destination (Join-Path $staging 'README.txt')
$launchers = @{
    '01-Baseline.cmd' = 'baseline'
    '02-Extra-Resize.cmd' = 'resize'
    '03-No-Clipping.cmd' = 'no-clip'
    '04-Keep-Borders.cmd' = 'bordered'
}
foreach ($name in $launchers.Keys) {
    $text = '@echo off' + "`r`n" + 'start "" "%~dp0Offhand.exe" --span-test=' + $launchers[$name] + "`r`n"
    [IO.File]::WriteAllText((Join-Path $staging $name), $text, [Text.Encoding]::ASCII)
}
$exeHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$testSourceHash = (Get-FileHash -LiteralPath $testSource -Algorithm SHA256).Hash
$identity = "Version=$version`r`nSourceBranch=companion/graininess-test`r`nBase=4ae9d3861b1bda5a1bbedbd5ef5d5748fdfe6eb3`r`nProgram.cs SHA256=$sourceHash`r`nSpanPresentationTest.cs SHA256=$testSourceHash`r`nOffhand.exe SHA256=$exeHash`r`n"
[IO.File]::WriteAllText((Join-Path $staging 'BUILD.txt'), $identity, [Text.UTF8Encoding]::new($false))
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::Open($output, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $staging -File | Sort-Object Name) {
        $entry = $zip.CreateEntry($file.Name, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $input = [IO.File]::OpenRead($file.FullName)
        $destination = $entry.Open()
        try { $input.CopyTo($destination) } finally { $destination.Dispose(); $input.Dispose() }
    }
} finally { $zip.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead($output)
try {
    $expected = @('01-Baseline.cmd','02-Extra-Resize.cmd','03-No-Clipping.cmd','04-Keep-Borders.cmd',
        'BUILD.txt','LICENSE','Offhand.exe','README.txt') | Sort-Object
    $actual = @($zip.Entries | ForEach-Object FullName | Sort-Object)
    if (($actual -join '|') -ne ($expected -join '|')) { throw 'Unexpected candidate archive contents' }
    foreach ($entry in $zip.Entries) {
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose(); $stream.Dispose() }
        if ($hash -ne (Get-FileHash -LiteralPath (Join-Path $staging $entry.FullName) -Algorithm SHA256).Hash) {
            throw "Archive verification failed: $($entry.FullName)"
        }
    }
} finally { $zip.Dispose() }
if ((Get-FileHash -LiteralPath $canonical -Algorithm SHA256).Hash -ne $beforeHash) { throw 'Canonical binary changed' }
$archiveHash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
[IO.File]::WriteAllText((Join-Path $OutputDirectory "checksums-companion-$version-sha256.txt"),
    "$archiveHash  $([IO.Path]::GetFileName($output))`r`n$exeHash  Offhand.exe`r`n", [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $staging 'README.txt') -Destination (Join-Path $OutputDirectory "Offhand-Companion-v$version-README.txt")
Write-Output "Verified all 8 archive files; canonical Companion hash retained: $beforeHash"
Write-Output "Candidate: $output"
Write-Output "Archive SHA256: $archiveHash"
Write-Output "Executable SHA256: $exeHash"
# This directory was uniquely created under the explicit output directory above.
$resolvedStaging = (Resolve-Path -LiteralPath $staging).Path
if ((Split-Path -Parent $resolvedStaging) -ne $OutputDirectory -or
    (Split-Path -Leaf $resolvedStaging) -notlike 'graininess-staging-*') { throw 'Unexpected cleanup path' }
Remove-Item -LiteralPath $resolvedStaging -Recurse -Force
