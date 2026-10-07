param(
    [string]$Version = "2.1.2-beta.19-wotlk335a-test1"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$dist = Join-Path $root "dist"
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("Offhand-wrath335a-" + [guid]::NewGuid().ToString())
$staging = Join-Path $tempRoot "Offhand"
$archivePath = Join-Path $dist ("Offhand-v" + $Version + ".zip")
$checksumPath = Join-Path $dist ("checksums-v" + $Version + "-sha256.txt")

New-Item -ItemType Directory -Path $staging -Force | Out-Null
New-Item -ItemType Directory -Path $dist -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $root "Offhand_Wrath335a.toc") `
    -Destination (Join-Path $staging "Offhand.toc")
foreach ($directory in @("Core", "Locales", "UI")) {
    Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $staging -Recurse
}

$media = Join-Path $staging "Media"
New-Item -ItemType Directory -Path $media -Force | Out-Null
Copy-Item -Path (Join-Path $root "Media\*.blp") -Destination $media

foreach ($file in @("LICENSE", "README.md", "CHANGELOG.md")) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $staging
}
$docs = Join-Path $staging "docs"
New-Item -ItemType Directory -Path $docs -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root "docs\WOTLK-335A-TESTING.md") -Destination $docs

$tocPath = Join-Path $staging "Offhand.toc"
$tocLines = Get-Content -LiteralPath $tocPath
if ($tocLines[0].Trim() -ne "## Interface: 30300") {
    throw "The staged legacy manifest is not exclusively Interface 30300."
}

$runtimeEntries = $tocLines | ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("#") }
foreach ($entry in $runtimeEntries) {
    $target = Join-Path $staging ($entry -replace '/', '\')
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Staged TOC entry is missing: $target"
    }
}

$luaCompiler = Get-Command luac -ErrorAction SilentlyContinue
if ($luaCompiler) {
    foreach ($entry in $runtimeEntries | Where-Object { $_ -like '*.lua' }) {
        & $luaCompiler.Source -p (Join-Path $staging ($entry -replace '/', '\'))
        if ($LASTEXITCODE -ne 0) { throw "Lua 5.1 syntax failed: $entry" }
    }
}

if (Test-Path -LiteralPath $archivePath) {
    throw "Refusing to overwrite existing test package: $archivePath"
}

$base = $tempRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
try {
    Get-ChildItem -LiteralPath $staging -File -Recurse | Sort-Object FullName | ForEach-Object {
        $entryName = $_.FullName.Substring($base.Length).Replace('\', '/')
        $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $inputStream = [IO.File]::OpenRead($_.FullName)
        $outputStream = $entry.Open()
        try {
            $inputStream.CopyTo($outputStream)
        } finally {
            $outputStream.Dispose()
            $inputStream.Dispose()
        }
    }
} finally {
    $archive.Dispose()
}

$validationArchive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    $names = @($validationArchive.Entries | ForEach-Object { $_.FullName })
    if ($names -notcontains "Offhand/Offhand.toc") {
        throw "Archive is missing Offhand/Offhand.toc."
    }
    if ($names | Where-Object { -not $_.StartsWith("Offhand/") -or $_.Contains('\') }) {
        throw "Archive contains an invalid root or non-portable path."
    }
    if ($names | Where-Object { $_ -match '(^|/)(tests|\.git|dist)/' }) {
        throw "Archive contains development-only files."
    }

    $tocEntry = $validationArchive.GetEntry("Offhand/Offhand.toc")
    $reader = New-Object IO.StreamReader($tocEntry.Open())
    try {
        $firstLine = $reader.ReadLine()
    } finally {
        $reader.Dispose()
    }
    if ($firstLine -ne "## Interface: 30300") {
        throw "Packaged manifest does not target Interface 30300 exclusively."
    }
} finally {
    $validationArchive.Dispose()
}

$hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
"$hash  $([IO.Path]::GetFileName($archivePath))" |
    Set-Content -LiteralPath $checksumPath -Encoding UTF8

Write-Output "Package=$archivePath"
Write-Output "SHA256=$hash"
Write-Output "Checksum=$checksumPath"
Write-Output "Staging=$tempRoot"
