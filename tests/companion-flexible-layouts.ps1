param([string]$PreviewDirectory)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $tempRoot ('Offhand-flexible-layouts-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
try {
 foreach($arch in @('x64','x86')){
  $framework=if($arch -eq 'x64'){'Framework64'}else{'Framework'}
  $compiler=Join-Path $env:WINDIR ('Microsoft.NET/'+$framework+'/v4.0.30319/csc.exe')
  $out=Join-Path $fixture $arch;New-Item -ItemType Directory -Path $out|Out-Null
  $exe=Join-Path $out flexible.exe
  & $compiler /nologo /target:exe "/platform:$arch" /main:Offhand.Companion.FlexibleLayoutsTest "/out:$exe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root Companion/Source/Program.cs) (Join-Path $root Companion/Source/LayoutDocument.cs) (Join-Path $root Companion/Source/WorkspaceLayoutService.cs) (Join-Path $root Companion/Source/FlexibleWorkspaceEditor.cs) (Join-Path $PSScriptRoot CompanionFlexibleLayouts.cs)
  if($LASTEXITCODE -ne 0){throw 'Flexible layout fixture compilation failed'}
  if($PreviewDirectory){New-Item -ItemType Directory -Path $PreviewDirectory -Force|Out-Null;& $exe $out (Join-Path ([IO.Path]::GetFullPath($PreviewDirectory)) ('flexible-'+$arch+'.png'))}else{& $exe $out}
  if($LASTEXITCODE -ne 0){throw ('Flexible layout fixture failed: '+$arch)}
  Push-Location $root
  try {foreach($name in @('centered','stacked','offset','two-displays','three-displays')){& lua tests/support/flexible-workspace-bridge.lua (Join-Path $out ('schema3-'+$name+'.lua')) $name;if($LASTEXITCODE -ne 0){throw 'Generated flexible bridge rejected by addon'}}}finally{Pop-Location}
 }
} finally {
 $resolved=[IO.Path]::GetFullPath($fixture)
 if(-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^Offhand-flexible-layouts-[a-f0-9]{32}$'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
