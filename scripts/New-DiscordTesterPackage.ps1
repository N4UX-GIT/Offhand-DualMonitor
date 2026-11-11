param(
    [Parameter(Mandatory=$true)][string]$ReviewDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$review=(Resolve-Path -LiteralPath $ReviewDirectory).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Use a fresh tester package directory.'}
$record=Get-Content (Join-Path $review review-manifest.json) -Raw|ConvertFrom-Json
$runtime='862d32bc76bab325743c47e34bb17ca24c072f94'
$exeHash='AB022A01DEE6D5CC627A5387DFC032D1B3D02BEA22DD0D5ED7CEC22157F388A3'
$reviewAddonHash='E4C514B13E4843C6979DC8B30DA0E9DAD7A74100CF13B6049D7943C1CCCAEC8A'
if($record.addonRuntimeRevision -ne $runtime -or $record.addonArchiveSha256 -ne $reviewAddonHash){throw 'Unexpected accepted review subject.'}
if((Get-FileHash (Join-Path $review Offhand-addon-review.zip)).Hash -ne $reviewAddonHash -or (Get-FileHash (Join-Path $review Offhand.exe)).Hash -ne $exeHash){throw 'Review artifact hash mismatch.'}
$tag='test-custom-workspace-regions-20261103-1'
$label='custom-workspace-regions-20261103-1'
$utf8=[Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $output|Out-Null
$staging=Join-Path $output staging
$addonStage=Join-Path $staging addon
$addon=Join-Path $addonStage Offhand
$native=Join-Path $staging companion
$complete=Join-Path $staging complete
foreach($folder in @($addon,$native,$complete)){New-Item -ItemType Directory -Path $folder -Force|Out-Null}
$packagedFiles=@(foreach($file in $record.addonFiles){
    if($file.path -match '(^|[\\/])\.\.' -or [IO.Path]::IsPathRooted($file.path)){throw 'Unsafe addon manifest path.'}
    $source=Join-Path $review ('Offhand/'+$file.path)
    if((Get-FileHash $source).Hash -ne $file.sha256 -or (Get-FileHash (Join-Path $root $file.path)).Hash -ne $file.sha256){throw ('Reviewed source drift: '+$file.path)}
    $target=Join-Path $addon $file.path
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    $metadataOnly=$file.path -like '*.toc'
    if($metadataOnly){
        $text=[IO.File]::ReadAllText($target)
        if($text -match 'X-Offhand-Candidate:'){throw 'Unexpected existing candidate marker.'}
        $text='## X-Offhand-Candidate: '+$label+"`r`n"+([regex]::Replace($text,'(?m)^(## Title:[^\r\n]*)','$1 [Custom Regions Test 1]'))
        [IO.File]::WriteAllText($target,$text,$utf8)
    }
    [ordered]@{path=$file.path;sha256=(Get-FileHash $target).Hash;reviewedSha256=$file.sha256;metadataOnlyChange=$metadataOnly}
})
if($packagedFiles.Count -ne 77 -or @($packagedFiles|Where-Object metadataOnlyChange).Count -ne 6){throw 'Unexpected addon file/metadata scope.'}
if((Get-Content (Join-Path $addon Core/CompanionTopology.lua) -Raw) -notmatch 'OffhandCompanionTopology = nil'){throw 'Packaged topology must be inert.'}
if(((Get-Content (Join-Path $addon Core/ForeverState.lua) -Raw) -replace '(?s)--\[\[.*?--\]\]','').Trim()){throw 'Packaged recovery bridge must be inert.'}
$guide=[IO.File]::ReadAllText((Join-Path $root docs/CUSTOM-WORKSPACE-REGIONS-DISCORD-TEST-1.md))
[IO.File]::WriteAllText((Join-Path $output README-FIRST.txt),$guide,$utf8)
Copy-Item (Join-Path $review Offhand.exe) (Join-Path $native Offhand.exe)
Copy-Item (Join-Path $root Companion/LICENSE) (Join-Path $native LICENSE)
[IO.File]::WriteAllText((Join-Path $native README.txt),$guide,$utf8)
Copy-Item -LiteralPath $addon -Destination (Join-Path $complete Offhand) -Recurse
Copy-Item (Join-Path $native Offhand.exe) (Join-Path $complete Offhand.exe)
Copy-Item (Join-Path $native LICENSE) (Join-Path $complete COMPANION-LICENSE.txt)
Copy-Item (Join-Path $output README-FIRST.txt) $complete
$sourceRevision=(& git -C $root rev-parse HEAD).Trim()
$manifest=[ordered]@{
    candidate=$label;tag=$tag;unofficial=$true;prerelease=$true
    packageSourceRevision=$sourceRevision;addonRuntimeRevision=$runtime
    reviewedAddonArchiveSha256=$reviewAddonHash;addonFiles=$packagedFiles
    addonMetadataChange='Only six TOC titles and X-Offhand-Candidate markers; Lua/XML/media unchanged from reviewed runtime.'
    addonCompatibilityVersion='2.1.2-beta.24';companionVersion='2.1.3-beta.3';companionFileVersion='2.1.3.4'
    companionBuildRevision='73f2b9e69a3d8ef938b4d247d79ee26f5bb9c30f';companionSha256=$exeHash;protocol=1
    evidence='86 Lua suites and static validation; bounded Anniversary tooltip and actual schema 2 addon-owned recovery probe. Earlier exact P8 two-client/cold-start evidence has separate addon scope.'
    pending='Native large panels, replacement bags, cold fit recovery, spanned tooltip/other-client follow-up, three physical displays, mixed DPI, hotplug, combat/protected actions.'
    provenance='Locally built Companion, exact reviewed EXE reused; no GitHub Actions attestation claimed.'
}
$manifest|ConvertTo-Json -Depth 7|Set-Content (Join-Path $output TEST-BUILD.json) -Encoding UTF8
Copy-Item (Join-Path $output TEST-BUILD.json) $complete
$innerHashes=@(Get-ChildItem -LiteralPath $complete -Recurse -File|Sort-Object FullName|ForEach-Object {(Get-FileHash $_.FullName).Hash+'  '+$_.FullName.Substring($complete.Length+1).Replace('\','/')})
$innerHashes|Set-Content (Join-Path $complete contents-sha256.txt) -Encoding UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-VerifiedZip([string]$Source,[string]$Target){
    $files=@(Get-ChildItem -LiteralPath $Source -Recurse -File|Sort-Object FullName)
    $expected=@{}
    $zip=[IO.Compression.ZipFile]::Open($Target,[IO.Compression.ZipArchiveMode]::Create)
    try{foreach($file in $files){
        $name=$file.FullName.Substring($Source.Length+1).Replace('\','/')
        $expected[$name]=(Get-FileHash $file.FullName).Hash
        $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime=[DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $input=[IO.File]::OpenRead($file.FullName);$destination=$entry.Open()
        try{$input.CopyTo($destination)}finally{$input.Dispose();$destination.Dispose()}
    }}finally{$zip.Dispose()}
    $zip=[IO.Compression.ZipFile]::OpenRead($Target)
    try{
        if($zip.Entries.Count -ne $expected.Count){throw 'Archive entry count mismatch.'}
        foreach($entry in $zip.Entries){
            if($entry.FullName.Contains('\') -or $entry.FullName -match '(^|/)\.\.(/|$)' -or -not $expected.ContainsKey($entry.FullName)){throw 'Unexpected ZIP entry.'}
            $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
            try{$actual=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
            if($actual -ne $expected[$entry.FullName]){throw 'ZIP byte mismatch.'}
        }
    }finally{$zip.Dispose()}
    Write-Output ('Verified '+$expected.Count+' ZIP entries: '+[IO.Path]::GetFileName($Target))
}
New-VerifiedZip $addonStage (Join-Path $output ('Offhand-Addon-'+$label+'.zip'))
New-VerifiedZip $native (Join-Path $output ('Offhand-Companion-'+$label+'.zip'))
New-VerifiedZip $complete (Join-Path $output ('Offhand-Complete-'+$label+'.zip'))
$assets=@(Get-ChildItem -LiteralPath $output -File|Sort-Object Name)
$assets|ForEach-Object {(Get-FileHash $_.FullName).Hash+'  '+$_.Name}|Set-Content (Join-Path $output checksums-sha256.txt) -Encoding UTF8
Write-Output ('Tester package ready: '+$output)
