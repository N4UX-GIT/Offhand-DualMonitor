$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $tempRoot ('Offhand-layout-document-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
try {
 foreach($arch in @('x64','x86')){
  $framework=if($arch -eq 'x64'){'Framework64'}else{'Framework'}
  $compiler=Join-Path $env:WINDIR ('Microsoft.NET/'+$framework+'/v4.0.30319/csc.exe')
  $exe=Join-Path $fixture ('layout-'+$arch+'.exe')
  & $compiler /nologo /target:exe "/platform:$arch" /main:Offhand.Companion.LayoutDocumentTest "/out:$exe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $root Companion/Source/Program.cs) (Join-Path $root Companion/Source/WorkspaceLayoutService.cs) (Join-Path $root Companion/Source/LayoutDocument.cs) (Join-Path $PSScriptRoot CompanionLayoutDocument.cs) (Join-Path $root Companion/Source/FlexibleWorkspaceEditor.cs)
  if($LASTEXITCODE -ne 0){throw 'Layout document fixture compilation failed'}
  & $exe
  if($LASTEXITCODE -ne 0){throw ('Layout document fixture failed: '+$arch)}
 }
} finally {
 $resolved=[IO.Path]::GetFullPath($fixture)
 if(-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^Offhand-layout-document-[a-f0-9]{32}$'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
