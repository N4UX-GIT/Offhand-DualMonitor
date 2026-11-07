param(
    [Parameter(Mandatory=$true)][string]$NativeDirectory,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [Parameter(Mandatory=$true)][string]$GuidePath
)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$native=(Resolve-Path -LiteralPath $NativeDirectory).Path
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path $output){throw 'Use a fresh matched-candidate directory.'}
if(@(& git -C $root status --porcelain).Count){throw 'Commit the complete candidate source before packaging.'}
$revision=(& git -C $root rev-parse HEAD).Trim()
$receipt=Get-Content (Join-Path $native candidate.json) -Raw|ConvertFrom-Json
if($receipt.trackedChanges -or $receipt.sourceRevision -ne $revision -or -not $receipt.customRegionsPrototype){throw 'Candidate provenance mismatch.'}
$version=$receipt.version
if($version -notmatch '^(\d+\.\d+\.\d+)(?:-(beta\.\d+))?$'){throw 'Expected a release or beta version.'}
$core=$matches[1];$release=if($matches.ContainsKey(2)){$matches[2]}else{''}
$runtime='Offhand-Companion-v'+$version+'.zip'
if((Get-FileHash (Join-Path $native Offhand.exe)).Hash -ne $receipt.binarySha256 -or
    (Get-FileHash (Join-Path $native $runtime)).Hash -ne $receipt.archiveSha256){throw 'Candidate artifact drift.'}
$inputs=@{programSha256='Program.cs';layoutDocumentSha256='LayoutDocument.cs';layoutServiceSha256='WorkspaceLayoutService.cs';flexibleEditorSha256='FlexibleWorkspaceEditor.cs';appManifestSha256='app.manifest'}
foreach($key in $inputs.Keys){if((Get-FileHash (Join-Path $root ('Companion/Source/'+$inputs[$key]))).Hash -ne $receipt.$key){throw ('Source drift: '+$key)}}
$stage=Join-Path $output staging
$addon=Join-Path $stage Offhand
New-Item -ItemType Directory -Path $addon -Force|Out-Null
$paths=@(& git -C $root ls-files Core UI Locales)+@('Bindings.xml','CHANGELOG.md','LICENSE','README.md','Media/OffhandLogo512x512.blp','Media/OffhandLogo64x64.blp',
    'Offhand.toc','Offhand_Classic.toc','Offhand_Forever.toc','Offhand_Mainline.toc','Offhand_Vanilla.toc','Offhand_Wrath335a.toc')
if($paths.Count -ne 83 -or @($paths|Sort-Object -Unique).Count -ne 83){throw 'Review the changed addon inventory.'}
if(([IO.File]::ReadAllText((Join-Path $root Core/CompanionTopology.lua)) -replace '(?m)^--[^\r\n]*','').Trim() -ne 'OffhandCompanionTopology = nil'){throw 'Topology bridge must be inert.'}
if(([IO.File]::ReadAllText((Join-Path $root Core/ForeverState.lua)) -replace '(?s)--\[\[.*?--\]\]','').Trim()){throw 'Recovery bridge must be inert.'}
$files=@(foreach($path in $paths|Sort-Object){
    if([IO.Path]::IsPathRooted($path) -or $path -match '(^|[\\/])\.\.([\\/]|$)'){throw 'Unsafe package path.'}
    $source=Join-Path $root $path;$target=Join-Path $addon $path
    if($path -like '*.toc'){
        $text=[IO.File]::ReadAllText($source)
        foreach($field in @{'Version'=$core;'X-Offhand-Release'=$release;'X-Offhand-Addon-Release'=$release;'X-Offhand-Companion-Version'=$core;'X-Offhand-Companion-Release'=$release}.GetEnumerator()){
            if($text -notmatch ('(?m)^## '+[regex]::Escape($field.Key)+':[ \t]*'+[regex]::Escape($field.Value)+'[ \t]*\r?$')){throw ('Unmatched addon metadata: '+$path+' '+$field.Key)}
        }
        if($text -match 'X-Offhand-Candidate:|\[Workspace Test'){throw 'Historical tester label in clean candidate.'}
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    [ordered]@{path=$path;sha256=(Get-FileHash $source).Hash}
})
Copy-Item -LiteralPath (Join-Path $native Offhand.exe) -Destination $stage
Copy-Item -LiteralPath (Join-Path $root Companion/LICENSE) -Destination (Join-Path $stage COMPANION-LICENSE.txt)
Copy-Item -LiteralPath $GuidePath -Destination (Join-Path $stage README-FIRST.txt)
[ordered]@{version=$version;sourceRevision=$revision;unofficial=$true;published=$false;microsoftReview='not_submitted';companionBuild=$receipt;addonVersion=$version;addonTopologySchemas=@(1,2,3);addonFiles=$files}|
    ConvertTo-Json -Depth 8|Set-Content (Join-Path $stage CANDIDATE.json) -Encoding UTF8
@(Get-ChildItem $stage -Recurse -File|Sort-Object FullName|ForEach-Object {(Get-FileHash $_.FullName).Hash+'  '+$_.FullName.Substring($stage.Length+1).Replace('\','/')})|
    Set-Content (Join-Path $stage contents-sha256.txt) -Encoding ASCII
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Zip-Verified([string]$Directory,[string]$Target,[bool]$IncludeRoot){
    $files=@(Get-ChildItem $Directory -Recurse -File);$expected=@{}
    $base=if($IncludeRoot){Split-Path -Parent $Directory}else{$Directory}
    $zip=[IO.Compression.ZipFile]::Open($Target,[IO.Compression.ZipArchiveMode]::Create)
    try{foreach($file in $files){
        $name=$file.FullName.Substring($base.Length+1).Replace('\','/')
        if($name -match '(^|/)(WTF|SavedVariables|\.git|\.cache)(/|$)|\.(ini|log|bak)$'){throw 'Private state in runtime package.'}
        $expected[$name]=(Get-FileHash $file.FullName).Hash
        $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal);$entry.LastWriteTime=[DateTimeOffset]::Parse('2026-01-01T00:00:00Z')
        $input=[IO.File]::OpenRead($file.FullName);$destination=$entry.Open();try{$input.CopyTo($destination)}finally{$input.Dispose();$destination.Dispose()}
    }}finally{$zip.Dispose()}
    $zip=[IO.Compression.ZipFile]::OpenRead($Target)
    try{if($zip.Entries.Count -ne $expected.Count){throw 'Archive inventory mismatch.'};foreach($entry in $zip.Entries){
        $sha=[Security.Cryptography.SHA256]::Create();$stream=$entry.Open();try{$hash=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}
        if($expected[$entry.FullName] -ne $hash){throw 'Archive hash mismatch.'}
    }}finally{$zip.Dispose()}
    Write-Output ('Verified '+$expected.Count+' entries: '+[IO.Path]::GetFileName($Target))
}
Zip-Verified $addon (Join-Path $output ('Offhand-Addon-v'+$version+'.zip')) $true
Zip-Verified $stage (Join-Path $output ('Offhand-Complete-v'+$version+'.zip')) $false
Copy-Item -LiteralPath (Join-Path $native $runtime) -Destination $output
Copy-Item -LiteralPath (Join-Path $native Offhand.exe) -Destination $output
@(Get-ChildItem $output -File|Sort-Object Name|ForEach-Object {(Get-FileHash $_.FullName).Hash+'  '+$_.Name})|Set-Content (Join-Path $output checksums-sha256.txt) -Encoding ASCII
