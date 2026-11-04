param([string]$PreviewDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$temporaryBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot=Join-Path $temporaryBase ('Offhand-workspace-profiles-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixtureRoot|Out-Null
try {
 foreach($arch in @('x64','x86')) {
  $framework=if($arch -eq 'x64'){'Framework64'}else{'Framework'}
  $compiler=Join-Path $env:WINDIR ('Microsoft.NET/'+$framework+'/v4.0.30319/csc.exe')
  $out=Join-Path $fixtureRoot $arch;New-Item -ItemType Directory -Path $out|Out-Null
  $exe=Join-Path $out fixture.exe
  & $compiler /nologo /target:exe "/platform:$arch" /main:Offhand.Companion.WorkspaceProfilesTest "/out:$exe" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root Companion/Source/Program.cs) (Join-Path $PSScriptRoot CompanionWorkspaceProfiles.cs)
  if($LASTEXITCODE -ne 0){throw 'Named profile fixture compilation failed'}
  & $exe $out
  if($LASTEXITCODE -ne 0){throw 'Named profile fixture failed'}
  if($PreviewDirectory){New-Item -ItemType Directory -Path $PreviewDirectory -Force|Out-Null;Copy-Item (Join-Path $out profiles-editor.png) (Join-Path $PreviewDirectory ('profiles-editor-'+$arch+'.png'))}
 }
} finally {
 $resolved=[IO.Path]::GetFullPath($fixtureRoot)
 if(-not $resolved.StartsWith($temporaryBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^Offhand-workspace-profiles-[a-f0-9]{32}$'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
