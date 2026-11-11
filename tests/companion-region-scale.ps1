param([string]$LuaPath)
$ErrorActionPreference='Stop'
if(-not $LuaPath) {
    $luaCommand=Get-Command lua -ErrorAction SilentlyContinue
    if($luaCommand){$LuaPath=$luaCommand.Source}
    elseif(Test-Path -LiteralPath 'C:\Program Files (x86)\Lua\5.1\lua.exe'){$LuaPath='C:\Program Files (x86)\Lua\5.1\lua.exe'}
    else{throw 'Pass -LuaPath for a working Lua 5.1 interpreter'}
}
$root=Split-Path -Parent $PSScriptRoot
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $tempBase ('Offhand-region-scale-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
try {
    foreach($arch in @('x64','x86')) {
        $framework=if($arch -eq 'x64'){'Framework64'}else{'Framework'}
        $compiler=Join-Path $env:WINDIR ('Microsoft.NET/'+$framework+'/v4.0.30319/csc.exe')
        $folder=Join-Path $fixture $arch;New-Item -ItemType Directory -Path $folder|Out-Null
        $exe=Join-Path $folder fixture.exe
        & $compiler /nologo /langversion:5 /target:exe "/platform:$arch" /main:Offhand.Companion.RegionScaleTest "/out:$exe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root Companion/Source/Program.cs) (Join-Path $root Companion/Source/LayoutDocument.cs) (Join-Path $root Companion/Source/WorkspaceLayoutService.cs) (Join-Path $root Companion/Source/FlexibleWorkspaceEditor.cs) (Join-Path $PSScriptRoot CompanionRegionScale.cs)
        if($LASTEXITCODE -ne 0){throw 'Region sizing fixture compilation failed'}
        & $exe $folder
        if($LASTEXITCODE -ne 0){throw 'Region sizing fixture failed'}
        Push-Location $root
        try {
            foreach($schema in @('schema2','schema3')) {
                & $LuaPath tests/support/region-scale-bridge.lua (Join-Path $folder ($schema+'.lua'))
                if($LASTEXITCODE -ne 0){throw 'Generated scale metadata rejected by Lua'}
            }
        } finally {Pop-Location}
    }
} finally {
    $resolved=[IO.Path]::GetFullPath($fixture)
    if(-not $resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^Offhand-region-scale-[a-f0-9]{32}$'){throw 'Unexpected cleanup path'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
