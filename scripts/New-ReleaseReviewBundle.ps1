param(
    [Parameter(Mandatory=$true)][string]$CompanionSourceRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$nativeRoot = (Resolve-Path -LiteralPath $CompanionSourceRoot).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Choose a fresh review directory.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
New-Item -ItemType Directory -Path $output | Out-Null
$utf8 = [Text.UTF8Encoding]::new($false)
function Copy-ReviewFile($sourceRoot, $relative, $destinationRoot) {
    $destination = Join-Path $destinationRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $sourceRoot $relative) -Destination $destination
}
function Verify-Zip($archivePath, $sourceDirectory) {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $files = @(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File)
        if ($archive.Entries.Count -ne $files.Count) { throw 'ZIP file count mismatch.' }
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.Contains('\') -or $entry.FullName.Contains('..')) { throw 'Unsafe ZIP path.' }
            $source = Join-Path $sourceDirectory $entry.FullName
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($hash -ne (Get-FileHash -LiteralPath $source).Hash) { throw "ZIP byte mismatch: $($entry.FullName)" }
        }
    } finally { $archive.Dispose() }
}
$addonStage = Join-Path $output 'addon-staging'
$addonRoot = Join-Path $addonStage 'Offhand'
New-Item -ItemType Directory -Path $addonRoot -Force | Out-Null
$addonFiles = @('Bindings.xml','LICENSE','README.md','CHANGELOG.md')
$addonFiles += Get-ChildItem -LiteralPath $root -Filter '*.toc' -File | ForEach-Object Name
foreach ($folder in @('Core','UI','Locales')) {
    $addonFiles += Get-ChildItem -LiteralPath (Join-Path $root $folder) -File -Recurse |
        ForEach-Object { $_.FullName.Substring($root.Length+1) }
}
$addonFiles += Get-ChildItem -LiteralPath (Join-Path $root 'Media') -Filter '*.blp' -File |
    ForEach-Object { $_.FullName.Substring($root.Length+1) }
foreach ($relative in $addonFiles) { Copy-ReviewFile $root $relative $addonRoot }
# Keep published version compatibility; mark this private snapshot explicitly.
foreach ($toc in Get-ChildItem -LiteralPath $addonRoot -Filter '*.toc') {
    $content = [IO.File]::ReadAllText($toc.FullName)
    [IO.File]::WriteAllText($toc.FullName,"## X-Offhand-Candidate: release-review-20261025-rc1`r`n"+$content,$utf8)
}
if ((Get-Content -LiteralPath (Join-Path $addonRoot 'Core/CompanionTopology.lua') -Raw) -notmatch 'OffhandCompanionTopology = nil') {
    throw 'Packaged topology must be inert.'
}
$foreverSource = Get-Content -LiteralPath (Join-Path $addonRoot 'Core/ForeverState.lua') -Raw
if (($foreverSource -replace '(?s)--\[\[.*?--\]\]','').Trim().Length -ne 0) {
    throw 'Packaged recovery state must be inert.'
}
$addonZip = Join-Path $output 'Offhand-addon-review-rc1.zip'
[IO.Compression.ZipFile]::CreateFromDirectory($addonStage,$addonZip)
Verify-Zip $addonZip $addonStage

$accepted = @(
    @{Folder='companion-classic-graphics-test3'; Hash='B63EB1D09C94E0737FB0F0EEBAD017104EBCACD14EB38F8523C3DB7A89A22163'},
    @{Folder='companion-retail-graphics-test4'; Hash='142AF665566430B9B63505497FC7E1B85D852D601150AC1EE0C8DDA720BCA855'}
)
foreach ($candidate in $accepted) {
    $source = Join-Path $root ('dist/'+$candidate.Folder)
    if ((Get-FileHash -LiteralPath (Join-Path $source 'Offhand.exe')).Hash -ne $candidate.Hash) {
        throw 'Accepted live-tested binary hash changed.'
    }
    $destination = Join-Path $output ('companion/'+$candidate.Folder)
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    foreach ($name in @('Offhand.exe','LICENSE','README.md','candidate.json')) {
        Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $destination $name)
    }
    # Original candidate metadata is retained as build-time history, including
    # its original pending status. The current acceptance record is separate.
    Copy-Item -LiteralPath (Join-Path $nativeRoot $(if ($candidate.Folder -match 'retail') {
        'docs/RETAIL-GRAPHICS-TEST.md'
    } else { 'docs/CLASSIC-GRAPHICS-TEST.md' })) -Destination (Join-Path $destination 'ACCEPTANCE.md')
}
$addonSnapshot = Join-Path $output 'source/addon'
foreach ($relative in $addonFiles) { Copy-ReviewFile $root $relative $addonSnapshot }
foreach ($folder in @('tests','scripts')) {
    Get-ChildItem -LiteralPath (Join-Path $root $folder) -File | ForEach-Object {
        Copy-ReviewFile $root ($folder+'/'+$_.Name) $addonSnapshot
    }
}
foreach ($relative in @('package.ps1','docs/ISSUES.md','tests/QA-notes.md')) {
    if (-not (Test-Path -LiteralPath (Join-Path $addonSnapshot $relative))) {
        Copy-ReviewFile $root $relative $addonSnapshot
    }
}
$nativeSnapshot = Join-Path $output 'source/companion'
foreach ($relative in @('Companion/Source/Program.cs','Companion/Source/app.manifest',
    'tests/ClassicGraphicsRecovery.cs','tests/companion-graphics-recovery.ps1',
    'tests/CompanionPreferences.cs','tests/CompanionLayout.cs','tests/companion-preferences.ps1',
    'scripts/New-ClassicGraphicsCandidate.ps1','docs/CLASSIC-GRAPHICS-TEST.md',
    'docs/RETAIL-GRAPHICS-TEST.md','docs/RETAIL-DISPLAY-BASELINE.md','docs/ISSUES.md')) {
    Copy-ReviewFile $nativeRoot $relative $nativeSnapshot
}
$manifest = [ordered]@{
    candidate='release-review-20261025-rc1'; published=$false
    addonBaseCommit=(& git -C $root rev-parse HEAD).Trim()
    companionBaseCommit=(& git -C $nativeRoot rev-parse HEAD).Trim()
    sourceIncludesUncommittedChanges=$true
    companionSourceSha256=(Get-FileHash -LiteralPath (Join-Path $nativeRoot 'Companion/Source/Program.cs')).Hash
    builtUtc=[DateTime]::UtcNow.ToString('o')
    addonVersion='2.1.2-beta.22 plus private candidate marker'
    acceptedCompanionBinaries=$accepted
    gates=@('Unified public Companion configuration/build not prepared or live tested',
        'Store package and promotion pending', 'Other monitor configurations pending',
        'Full addon combat/third-party ownership and cold-start regression pending',
        'Original reported hang and excessive-error warning remain unreproduced')
}
[IO.File]::WriteAllText((Join-Path $output 'review-manifest.json'),($manifest | ConvertTo-Json -Depth 6),$utf8)
Copy-ReviewFile $root 'docs/RELEASE-REVIEW-20261025.md' $addonSnapshot
Copy-Item -LiteralPath (Join-Path $root 'docs/RELEASE-REVIEW-20261025.md') -Destination (Join-Path $output 'README.md')
$checksums = Get-ChildItem -LiteralPath $output -Recurse -File | Sort-Object FullName | ForEach-Object {
    (Get-FileHash -LiteralPath $_.FullName).Hash+'  '+$_.FullName.Substring($output.Length+1).Replace('\','/')
}
[IO.File]::WriteAllLines((Join-Path $output 'SHA256SUMS.txt'),[string[]]$checksums,$utf8)
Write-Output $output
