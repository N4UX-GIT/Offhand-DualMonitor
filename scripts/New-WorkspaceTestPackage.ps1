param(
    [Parameter(Mandatory=$true)][string]$NativeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$native=(Resolve-Path -LiteralPath $NativeDirectory).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Use a fresh package directory.'}
if(@(& git -C $root status --porcelain).Count){throw 'Commit the complete reviewed source before packaging.'}
$revision=(& git -C $root rev-parse HEAD).Trim()
$receipt=Get-Content (Join-Path $native candidate.json) -Raw|ConvertFrom-Json
if($receipt.trackedChanges -or $receipt.version -ne '2.1.3-beta.5' -or $receipt.fileVersion -ne '2.1.3.6'){throw 'Unexpected native candidate.'}
if($receipt.binarySha256 -ne (Get-FileHash (Join-Path $native Offhand.exe)).Hash -or
   $receipt.programSha256 -ne (Get-FileHash (Join-Path $root Companion/Source/Program.cs)).Hash -or
   $receipt.appManifestSha256 -ne (Get-FileHash (Join-Path $root Companion/Source/app.manifest)).Hash){throw 'Native source or binary receipt mismatch.'}
if((Get-FileHash (Join-Path $root Companion/Offhand.exe)).Hash -ne '81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB' -or
   (Get-FileHash (Join-Path $root Companion/Offhand-Companion.zip)).Hash -ne 'C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3'){throw 'Frozen public artifacts changed.'}
$label='custom-workspace-regions-20261104-2'
$tag='test-'+$label
$utf8=[Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $output|Out-Null
$staging=Join-Path $output staging
$addonStage=Join-Path $staging addon
$addon=Join-Path $addonStage Offhand
$companion=Join-Path $staging companion
$complete=Join-Path $staging complete
foreach($folder in @($addon,$companion,$complete)){New-Item -ItemType Directory -Path $folder -Force|Out-Null}
$paths=@(& git -C $root ls-files Core UI Locales)+@('Bindings.xml','CHANGELOG.md','LICENSE','README.md',
    'Media/OffhandLogo512x512.blp','Media/OffhandLogo64x64.blp',
    'Offhand.toc','Offhand_Classic.toc','Offhand_Forever.toc','Offhand_Mainline.toc','Offhand_Vanilla.toc','Offhand_Wrath335a.toc')
if($paths.Count -ne 80){throw 'Review the changed runtime allowlist before packaging.'}
$files=@(foreach($path in $paths|Sort-Object){
    if($path -match '(^|[\\/])\.\.' -or [IO.Path]::IsPathRooted($path)){throw 'Unsafe package path.'}
    $source=Join-Path $root $path;$target=Join-Path $addon $path
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    $metadataOnly=$path -like '*.toc'
    if($metadataOnly){
        $text=[IO.File]::ReadAllText($target)
        if($text -match 'X-Offhand-Candidate:'){throw 'Unexpected source candidate marker.'}
        $text='## X-Offhand-Candidate: '+$label+"`r`n"+([regex]::Replace($text,'(?m)^(## Title:[^\r\n]*)','$1 [Workspace Test 2]'))
        [IO.File]::WriteAllText($target,$text,$utf8)
    }
    [ordered]@{path=$path;sha256=(Get-FileHash $target).Hash;sourceSha256=(Get-FileHash $source).Hash;metadataOnlyChange=$metadataOnly}
})
if(@($files|Where-Object metadataOnlyChange).Count -ne 6){throw 'Unexpected metadata scope.'}
if(([IO.File]::ReadAllText((Join-Path $addon Core/CompanionTopology.lua)) -replace '(?m)^--[^\r\n]*','').Trim() -ne 'OffhandCompanionTopology = nil'){throw 'Topology bridge is not inert.'}
if(([IO.File]::ReadAllText((Join-Path $addon Core/ForeverState.lua)) -replace '(?s)--\[\[.*?--\]\]','').Trim()){throw 'Recovery bridge is not inert.'}
$guide=[IO.File]::ReadAllText((Join-Path $root docs/CUSTOM-WORKSPACE-DISCORD-TEST-2.md))
[IO.File]::WriteAllText((Join-Path $output README-FIRST.txt),$guide,$utf8)
Copy-Item -LiteralPath (Join-Path $native Offhand.exe) -Destination $companion
Copy-Item -LiteralPath (Join-Path $root Companion/LICENSE) -Destination $companion
[IO.File]::WriteAllText((Join-Path $companion README.txt),$guide,$utf8)
Copy-Item -LiteralPath $addon -Destination $complete -Recurse
Copy-Item -LiteralPath (Join-Path $native Offhand.exe) -Destination $complete
Copy-Item -LiteralPath (Join-Path $native candidate.json) -Destination (Join-Path $complete companion-build.json)
Copy-Item -LiteralPath (Join-Path $root Companion/LICENSE) -Destination (Join-Path $complete COMPANION-LICENSE.txt)
Copy-Item -LiteralPath (Join-Path $output README-FIRST.txt) -Destination $complete
$studio=Join-Path $output Offhand-Background-Studio.html
& node (Join-Path $PSScriptRoot New-OfflineBackgroundStudio.mjs) $studio
if($LASTEXITCODE -ne 0){throw 'Offline Studio generation failed.'}
Copy-Item -LiteralPath $studio -Destination $complete
New-Item -ItemType Directory -Path (Join-Path $complete docs)|Out-Null
foreach($name in @('WORKSPACE-TEST-2-QA-20261104.md','COMPANION-UX-QUALITY-PASS-20261104.md',
    'WORKSPACE-MEDIA-LIBRARY-PLAN.md','CUSTOM-WORKSPACE-PROFILES.md')){
    Copy-Item -LiteralPath (Join-Path $root ('docs/'+$name)) -Destination (Join-Path $complete docs)
}
$manifest=[ordered]@{
    candidate=$label;tag=$tag;unofficial=$true;prerelease=$true;packageSourceRevision=$revision;addonFiles=$files
    addonCompatibilityVersion='2.1.2-beta.24';addonMetadataChange='Six TOC candidate markers and title suffixes; remaining runtime bytes match source.'
    companionVersion=$receipt.version;companionFileVersion=$receipt.fileVersion
    companionBuildRevision=$receipt.sourceRevision;companionSha256=$receipt.binarySha256;protocol=1
    studioSha256=(Get-FileHash $studio).Hash;mediaSchemas=@(2,3);mediaLibraryMaximum=2
    evidence='90 Lua suites, six manifests and Lua 5.1 syntax; four Studio suites including 96 cross-language comparisons and offline event simulation. Retail 12.1.5.70783: both images rendered, reload/profile/fallback passed, 13 historical errors unchanged. Exact Beta 5 span and native Restore passed.'
    pending='Browser visual/export interaction, fresh Anniversary library and cold relaunch, simultaneous physical two-workspace images, mixed DPI, hotplug, combat/protected actions, remaining large panels/replacement bags, screen reader/high contrast.'
    provenance='Locally built native candidate from separately recorded clean revision; native source hashes still match. No official release, Store submission, website deployment or GitHub Actions attestation.'
}
$manifest|ConvertTo-Json -Depth 7|Set-Content (Join-Path $output TEST-BUILD.json) -Encoding UTF8
Copy-Item -LiteralPath (Join-Path $output TEST-BUILD.json) -Destination $complete
@(Get-ChildItem -LiteralPath $complete -Recurse -File|Sort-Object FullName|ForEach-Object {
    (Get-FileHash $_.FullName).Hash+'  '+$_.FullName.Substring($complete.Length+1).Replace('\','/')
})|Set-Content (Join-Path $complete contents-sha256.txt) -Encoding UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-VerifiedZip([string]$Source,[string]$Target){
    $expected=@{}
    $zip=[IO.Compression.ZipFile]::Open($Target,[IO.Compression.ZipArchiveMode]::Create)
    try{foreach($file in Get-ChildItem -LiteralPath $Source -Recurse -File|Sort-Object FullName){
        $name=$file.FullName.Substring($Source.Length+1).Replace('\','/')
        if($name -match '(^|/)(WTF|SavedVariables|Screenshots|\.git|\.cache|dist)(/|$)|\.(ini|log|bak)$'){throw 'Private or development state in package.'}
        $expected[$name]=(Get-FileHash $file.FullName).Hash
        $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime=[DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $input=[IO.File]::OpenRead($file.FullName);$destination=$entry.Open()
        try{$input.CopyTo($destination)}finally{$input.Dispose();$destination.Dispose()}
    }}finally{$zip.Dispose()}
    $zip=[IO.Compression.ZipFile]::OpenRead($Target)
    try{
        if($zip.Entries.Count -ne $expected.Count){throw 'Archive count mismatch.'}
        foreach($entry in $zip.Entries){
            if(-not $expected.ContainsKey($entry.FullName)){throw 'Unexpected archive entry.'}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try{$actual=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
            if($actual -ne $expected[$entry.FullName]){throw 'Archive byte mismatch.'}
        }
    }finally{$zip.Dispose()}
    Write-Output ('Verified '+$expected.Count+' entries: '+[IO.Path]::GetFileName($Target))
}
New-VerifiedZip $addonStage (Join-Path $output ('Offhand-Addon-'+$label+'.zip'))
New-VerifiedZip $companion (Join-Path $output ('Offhand-Companion-'+$label+'.zip'))
New-VerifiedZip $complete (Join-Path $output ('Offhand-Complete-'+$label+'.zip'))
@(Get-ChildItem -LiteralPath $output -File|Sort-Object Name|ForEach-Object {
    (Get-FileHash $_.FullName).Hash+'  '+$_.Name
})|Set-Content (Join-Path $output checksums-sha256.txt) -Encoding UTF8
Write-Output ('Unofficial package ready: '+$output)
