param(
    [string]$OutputDirectory,
    [string]$CompanionDirectory,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addonVersion = '2.1.3-beta.27'
if (-not $CompanionDirectory) { $CompanionDirectory = Join-Path $root 'Companion/Prepared/2.1.3' }
$native = (Resolve-Path -LiteralPath $CompanionDirectory).Path
$receipt = Get-Content -LiteralPath (Join-Path $native 'release.json') -Raw | ConvertFrom-Json
$exeHash = '88916B6FBAA4FF2E81EC574F8FA248C553ED531AD7A3DC828FF4948568797443'
$zipHash = 'C277105FEFA08B8A7EC7B089151D418960FF0378B449375BBBF56B2686AB816A'
if ($receipt.version -ne '2.1.3' -or $receipt.fileVersion -ne '2.1.3.9' -or
    $receipt.binarySha256 -ne $exeHash -or $receipt.archiveSha256 -ne $zipHash -or
    $receipt.archiveName -ne 'Offhand-Companion-v2.1.3.zip' -or
    $receipt.companionSourceRevision -ne 'd2934ef802cf0c8deb62d29fd0c932658e64afa3') {
    throw 'Prepared Companion identity differs from the frozen Store submission.'
}
foreach ($sample in @(@('Offhand.exe', $exeHash), @($receipt.archiveName, $zipHash))) {
    if ((Get-FileHash -LiteralPath (Join-Path $native $sample[0]) -Algorithm SHA256).Hash -ne $sample[1]) {
        throw ('Frozen sample hash mismatch: ' + $sample[0])
    }
}
$identity = [Diagnostics.FileVersionInfo]::GetVersionInfo((Join-Path $native 'Offhand.exe'))
if ($identity.ProductVersion -ne '2.1.3' -or $identity.FileVersion -ne '2.1.3.9') {
    throw 'Frozen executable version mismatch.'
}
$inputPaths = @('Companion/Source/Program.cs', 'Companion/Source/LayoutDocument.cs',
    'Companion/Source/WorkspaceLayoutService.cs', 'Companion/Source/FlexibleWorkspaceEditor.cs',
    'Companion/Source/app.manifest', 'Media/offhand-logo.ico', 'Media/offhand-logo-small.png')
if (@($receipt.inputs).Count -ne $inputPaths.Count -or
    @(Compare-Object $inputPaths @($receipt.inputs.path)).Count) { throw 'Frozen source inventory mismatch.' }
foreach ($sourceInput in $receipt.inputs) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $root $sourceInput.path))
    if ($sourceInput.normalization -eq 'CRLF-to-LF') {
        $bytes = [Text.Encoding]::UTF8.GetBytes([Text.Encoding]::UTF8.GetString($bytes).Replace("`r`n", "`n"))
    } elseif ($sourceInput.normalization -ne 'none') { throw 'Unknown source normalization.' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') } finally { $sha.Dispose() }
    if ($hash -ne $sourceInput.sha256) { throw ('Frozen Companion source changed: ' + $sourceInput.path) }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Get-EntryHash($Entry) {
    $sha = [Security.Cryptography.SHA256]::Create(); $stream = $Entry.Open()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '') }
    finally { $stream.Dispose(); $sha.Dispose() }
}
$portable = [IO.Compression.ZipFile]::OpenRead((Join-Path $native $receipt.archiveName))
try {
    if ($portable.Entries.Count -ne 3 -or
        @(Compare-Object @('LICENSE', 'Offhand.exe', 'README.txt') @($portable.Entries.FullName)).Count -or
        (Get-EntryHash ($portable.GetEntry('Offhand.exe'))) -ne $exeHash) {
        throw 'Portable archive contents differ from the frozen runtime.'
    }
} finally { $portable.Dispose() }
$paths = @(& git -C $root ls-files Core UI Locales) + @('Bindings.xml', 'CHANGELOG.md', 'LICENSE', 'README.md',
    'Media/OffhandLogo512x512.blp', 'Media/OffhandLogo64x64.blp',
    'Offhand.toc', 'Offhand_Classic.toc', 'Offhand_Forever.toc', 'Offhand_Mainline.toc', 'Offhand_Vanilla.toc', 'Offhand_Wrath335a.toc')
if ($LASTEXITCODE -ne 0 -or $paths.Count -ne 86 -or @($paths | Sort-Object -Unique).Count -ne 86) {
    throw 'Review the changed add-on publication inventory (expected 86 files).'
}
foreach ($toc in $paths | Where-Object { $_ -like '*.toc' }) {
    $text = [IO.File]::ReadAllText((Join-Path $root $toc))
    foreach ($field in @{'Version'='2.1.3'; 'X-Offhand-Release'='beta.27'; 'X-Offhand-Addon-Release'='beta.27';
        'X-Offhand-Companion-Version'='2.1.3'; 'X-Offhand-Companion-Release'=''}.GetEnumerator()) {
        if ($text -notmatch ('(?m)^## ' + [regex]::Escape($field.Key) + ':[ \t]*' +
            [regex]::Escape($field.Value) + '[ \t]*\r?$')) { throw ('Add-on identity mismatch: ' + $toc + ' ' + $field.Key) }
    }
    if ($text -match 'X-Offhand-Candidate:|\[Workspace Test') { throw 'Historical tester label in publication source.' }
}
if (([IO.File]::ReadAllText((Join-Path $root 'Core/CompanionTopology.lua')) -replace '(?m)^--[^\r\n]*','').Trim() -ne
    'OffhandCompanionTopology = nil') { throw 'Topology bridge must be inert.' }
if (([IO.File]::ReadAllText((Join-Path $root 'Core/ForeverState.lua')) -replace '(?s)--\[\[.*?--\]\]','').Trim()) {
    throw 'Recovery bridge must be inert.'
}
if ($ValidateOnly) { Write-Output 'PASS: frozen Companion, source inputs, minimal ZIP and matching add-on inventory.'; return }
if (@(& git -C $root status --porcelain).Count) { throw 'Commit the complete publication source before packaging.' }
if (-not $OutputDirectory) { throw 'Use a fresh explicit OutputDirectory.' }
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Use a fresh publication directory; historical packages are preserved.' }
$revision = (& git -C $root rev-parse HEAD).Trim()
$stage = Join-Path $output 'staging'; $addon = Join-Path $stage 'Offhand'
New-Item -ItemType Directory -Path $addon -Force | Out-Null
$files = @(foreach ($path in $paths | Sort-Object) {
    $source = Join-Path $root $path; $target = Join-Path $addon $path
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    [ordered]@{path=$path; sha256=(Get-FileHash -LiteralPath $source).Hash}
})
Copy-Item -LiteralPath (Join-Path $native 'Offhand.exe') -Destination $stage
Copy-Item -LiteralPath (Join-Path $root 'Companion/LICENSE') -Destination (Join-Path $stage 'COMPANION-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $root 'docs/INSTALL-2.1.3.txt') -Destination (Join-Path $stage 'README-FIRST.txt')
$publication = [ordered]@{version=$addonVersion; addonVersion=$addonVersion; companionVersion='2.1.3';
    prerelease=$true; releaseName='Offhand v2.1.3 Pre-Release Beta 27'; addonSourceRevision=$revision;
    companionSourceRevision=$receipt.companionSourceRevision; companion=$receipt;
    state='prepared_not_published'; storeSubmissionId='1152921505702343609';
    certificationAtPreparation='submitted_not_yet_confirmed'; storePublishingHold='manual';
    defenderSubmitted=$false; addonFiles=$files}
$publication | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stage 'PUBLICATION.json') -Encoding UTF8
function Zip-Verified([string]$Directory, [string]$Target, [bool]$IncludeRoot) {
    $expected = @{}; $base = if ($IncludeRoot) { Split-Path -Parent $Directory } else { $Directory }
    $zip = [IO.Compression.ZipFile]::Open($Target, [IO.Compression.ZipArchiveMode]::Create)
    try { foreach ($file in Get-ChildItem -LiteralPath $Directory -Recurse -File) {
        $name = $file.FullName.Substring($base.Length + 1).Replace('\','/')
        if ($name -match '(^|/)(WTF|SavedVariables|\.git|\.cache|tests|tools|docs)(/|$)|\.(ini|log|bak)$') {
            throw ('Private or development data in runtime package: ' + $name)
        }
        $expected[$name] = (Get-FileHash -LiteralPath $file.FullName).Hash
        $entry = $zip.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $stream = [IO.File]::OpenRead($file.FullName); $destination = $entry.Open()
        try { $stream.CopyTo($destination) } finally { $destination.Dispose(); $stream.Dispose() }
    }} finally { $zip.Dispose() }
    $zip = [IO.Compression.ZipFile]::OpenRead($Target)
    try {
        if ($zip.Entries.Count -ne $expected.Count) { throw 'Archive inventory mismatch.' }
        foreach ($entry in $zip.Entries) {
            if ((Get-EntryHash $entry) -ne $expected[$entry.FullName]) { throw ('Archive hash mismatch: ' + $entry.FullName) }
        }
    } finally { $zip.Dispose() }
    Write-Output ('Verified ' + $expected.Count + ' entries: ' + [IO.Path]::GetFileName($Target))
}
Zip-Verified $addon (Join-Path $output ('Offhand-v' + $addonVersion + '.zip')) $true
Zip-Verified $stage (Join-Path $output ('Offhand-Complete-v' + $addonVersion + '.zip')) $false
Copy-Item -LiteralPath (Join-Path $native $receipt.archiveName) -Destination $output
Copy-Item -LiteralPath (Join-Path $native 'Offhand.exe') -Destination $output
$publication | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $output 'publication.json') -Encoding UTF8
@(('Offhand-v' + $addonVersion + '.zip'), ('Offhand-Complete-v' + $addonVersion + '.zip'), $receipt.archiveName, 'Offhand.exe', 'publication.json') |
    ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $output $_)).Hash + '  ' + $_ } |
    Set-Content -LiteralPath (Join-Path $output 'checksums-sha256.txt') -Encoding ASCII
$companionRelease = Join-Path $output 'companion-release'
New-Item -ItemType Directory -Path $companionRelease | Out-Null
foreach ($name in @('Offhand.exe', $receipt.archiveName)) {
    Copy-Item -LiteralPath (Join-Path $native $name) -Destination $companionRelease
}
Copy-Item -LiteralPath (Join-Path $native 'release.json') -Destination (Join-Path $companionRelease 'publication.json')
@('Offhand.exe', $receipt.archiveName, 'publication.json') |
    ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $companionRelease $_)).Hash + '  ' + $_ } |
    Set-Content -LiteralPath (Join-Path $companionRelease 'checksums-sha256.txt') -Encoding ASCII
Write-Output ('Prepared ' + $addonVersion + ' publication from add-on ' + $revision + '; frozen Companion ' + $receipt.companionSourceRevision)
