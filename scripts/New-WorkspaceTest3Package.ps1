param(
    [Parameter(Mandatory=$true)][string]$NativeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [ValidateRange(4,99)][int]$Revision=4,
    [ValidatePattern('^\d{8}$')][string]$ReleaseDate='20261107'
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$native=(Resolve-Path -LiteralPath $NativeDirectory).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Use a fresh test package directory.'}
if(@(& git -C $root status --porcelain).Count){throw 'Commit the complete reviewed source before packaging.'}
$sourceRevision=(& git -C $root rev-parse HEAD).Trim()
$receipt=Get-Content (Join-Path $native candidate.json) -Raw | ConvertFrom-Json
if($receipt.trackedChanges -or $receipt.sourceRevision -ne $sourceRevision -or
    $receipt.version -ne '2.1.3-beta.6' -or $receipt.fileVersion -ne '2.1.3.7' -or
    -not $receipt.customRegionsPrototype){throw 'Unexpected native candidate provenance.'}
$sources=@{programSha256='Program.cs';layoutDocumentSha256='LayoutDocument.cs';
    flexibleEditorSha256='FlexibleWorkspaceEditor.cs';layoutServiceSha256='WorkspaceLayoutService.cs';appManifestSha256='app.manifest'}
foreach($key in $sources.Keys){
    if($receipt.$key -ne (Get-FileHash (Join-Path $root ('Companion/Source/'+$sources[$key]))).Hash){throw ('Candidate source mismatch: '+$key)}
}
if($receipt.binarySha256 -ne (Get-FileHash (Join-Path $native Offhand.exe)).Hash -or
    $receipt.archiveSha256 -ne (Get-FileHash (Join-Path $native Offhand-Companion-v2.1.3-beta.6.zip)).Hash){throw 'Candidate binary/archive mismatch.'}
if((Get-FileHash (Join-Path $root Companion/Offhand.exe)).Hash -ne '81EECE9430885CEAC178A44A42429854524279072305F9F94EE62E7CCD620CCB' -or
    (Get-FileHash (Join-Path $root Companion/Offhand-Companion.zip)).Hash -ne 'C726444612DD740BE3F923B83704D155E21BC017F7C5FE245379B19DBECC76E3'){throw 'Frozen public artifacts changed.'}
$tag='test-custom-workspace-regions-'+$ReleaseDate+'-3-r'+$Revision
$utf8=[Text.UTF8Encoding]::new($false)
$stage=Join-Path $output staging
$addon=Join-Path $stage Offhand
New-Item -ItemType Directory -Path $addon -Force | Out-Null
$paths=@(& git -C $root ls-files Core UI Locales)+@('Bindings.xml','CHANGELOG.md','LICENSE','README.md',
    'Media/OffhandLogo512x512.blp','Media/OffhandLogo64x64.blp',
    'Offhand.toc','Offhand_Classic.toc','Offhand_Forever.toc','Offhand_Mainline.toc','Offhand_Vanilla.toc','Offhand_Wrath335a.toc')
if($paths.Count -ne 83 -or @($paths | Sort-Object -Unique).Count -ne 83){throw 'Review the changed addon runtime inventory.'}
$files=@(foreach($path in $paths | Sort-Object){
    if([IO.Path]::IsPathRooted($path) -or $path -match '(^|[\\/])\.\.([\\/]|$)'){throw 'Unsafe package path.'}
    $source=Join-Path $root $path
    $target=Join-Path $addon $path
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    $metadataOnly=$path -like '*.toc'
    if($metadataOnly){
        $text=[IO.File]::ReadAllText($target)
        if($text -match 'X-Offhand-Candidate:' -or $text -notmatch 'X-Offhand-Topology-Schemas: 1,2,3' -or
            $text -notmatch 'X-Offhand-Addon-Release: beta.26'){throw 'Unexpected addon compatibility metadata.'}
        $text='## X-Offhand-Candidate: '+$tag+"`r`n"+([regex]::Replace($text,'(?m)^(## Title:[^\r\n]*)',('$1 [Workspace Test 3 r'+$Revision+']')))
        [IO.File]::WriteAllText($target,$text,$utf8)
    }
    [ordered]@{path=$path;sha256=(Get-FileHash $target).Hash;sourceSha256=(Get-FileHash $source).Hash;metadataOnlyChange=$metadataOnly}
})
if(@($files | Where-Object metadataOnlyChange).Count -ne 6){throw 'Unexpected metadata scope.'}
if(([IO.File]::ReadAllText((Join-Path $addon Core/CompanionTopology.lua)) -replace '(?m)^--[^\r\n]*','').Trim() -ne 'OffhandCompanionTopology = nil'){throw 'Topology bridge must be inert.'}
if(([IO.File]::ReadAllText((Join-Path $addon Core/ForeverState.lua)) -replace '(?s)--\[\[.*?--\]\]','').Trim()){throw 'Recovery bridge must be inert.'}
Copy-Item -LiteralPath (Join-Path $native Offhand.exe) -Destination $stage
Copy-Item -LiteralPath (Join-Path $root Companion/LICENSE) -Destination (Join-Path $stage COMPANION-LICENSE.txt)
Copy-Item -LiteralPath (Join-Path $root ('docs/CUSTOM-WORKSPACE-DISCORD-TEST-3-R'+$Revision+'.md')) -Destination (Join-Path $stage README-FIRST.txt)
$manifest=[ordered]@{
    candidate=$tag;unofficial=$true;prerelease=$true;sourceRevision=$sourceRevision
    addonRelease='2.1.2-beta.26';addonTopologySchemas=@(1,2,3);addonFiles=$files
    addonMetadataChange=('Six TOC title suffixes and candidate markers identify Workspace Test 3 r'+$Revision+'. Other addon bytes match the tagged source.')
    companionVersion=$receipt.version;companionFileVersion=$receipt.fileVersion;companionSha256=$receipt.binarySha256;companionBuild=$receipt
    verification='101 Lua suites, six manifests and Lua 5.1 syntax; Companion identity/migration, profiles, workspaces, bridges, rollback/Restore, remote planning, UI/scaling, taskbar, recovery and interaction-boundary checks. Local native active-target identity queries passed.'
    pending='Combined live WoW acceptance, affected reporter hardware, physical hotplug/third monitor/mixed DPI, Wine and full combat/protected-action coverage.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $stage TEST-BUILD.json) -Encoding UTF8
@(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName | ForEach-Object {
    (Get-FileHash $_.FullName).Hash+'  '+$_.FullName.Substring($stage.Length+1).Replace('\','/')
}) | Set-Content (Join-Path $stage contents-sha256.txt) -Encoding UTF8
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=Join-Path $output ('Offhand-Complete-custom-workspace-test3-r'+$Revision+'.zip')
$expected=@{}
$zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
try{foreach($file in Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName){
    $name=$file.FullName.Substring($stage.Length+1).Replace('\','/')
    if($name -match '(^|/)(WTF|SavedVariables|Screenshots|\.git|\.cache|dist)(/|$)|\.(ini|log|bak)$'){throw 'Private or development state in package.'}
    $expected[$name]=(Get-FileHash $file.FullName).Hash
    $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime=[DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
    $input=[IO.File]::OpenRead($file.FullName);$destination=$entry.Open()
    try{$input.CopyTo($destination)}finally{$input.Dispose();$destination.Dispose()}
}}finally{$zip.Dispose()}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{
    if($zip.Entries.Count -ne 88 -or $zip.Entries.Count -ne $expected.Count){throw 'Unexpected archive inventory.'}
    foreach($entry in $zip.Entries){
        if(-not $expected.ContainsKey($entry.FullName)){throw 'Unexpected archive entry.'}
        $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
        try{$actual=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$stream.Dispose();$sha.Dispose()}
        if($actual -ne $expected[$entry.FullName]){throw ('Archive byte mismatch: '+$entry.FullName)}
    }
}finally{$zip.Dispose()}
((Get-FileHash $archive).Hash+'  '+[IO.Path]::GetFileName($archive)) | Set-Content (Join-Path $output checksums-sha256.txt) -Encoding ASCII
Write-Output ('Verified '+$expected.Count+' entries: '+$archive)
