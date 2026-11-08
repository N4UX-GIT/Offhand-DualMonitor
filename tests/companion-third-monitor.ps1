$ErrorActionPreference='Stop'
$temporaryBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $temporaryBase ('Offhand-third-monitor-'+[guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $fixtureRoot|Out-Null
try {
    foreach($architecture in @('x64','x86')) {
        $framework=if($architecture -eq 'x64'){'Framework64'}else{'Framework'}
        $compiler=Join-Path $env:WINDIR ('Microsoft.NET\'+$framework+'\v4.0.30319\csc.exe')
        $output=Join-Path $fixtureRoot $architecture
        New-Item -ItemType Directory -Path $output|Out-Null
        $executable=Join-Path $output fixture.exe
        & $compiler /nologo /target:exe "/platform:$architecture" /main:Offhand.Companion.ThirdMonitorTest "/out:$executable" /r:System.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll (Join-Path $PSScriptRoot '..\Companion\Source\Program.cs') (Join-Path $PSScriptRoot '..\Companion\Source\LayoutDocument.cs') (Join-Path $PSScriptRoot '..\Companion\Source\WorkspaceLayoutService.cs') (Join-Path $PSScriptRoot CompanionThirdMonitor.cs) (Join-Path $PSScriptRoot '..\Companion\Source\FlexibleWorkspaceEditor.cs')
        if($LASTEXITCODE -ne 0){throw 'Third-monitor characterization compilation failed'}
        & $executable $output
        if($LASTEXITCODE -ne 0){throw 'Third-monitor characterization failed'}
    }
} finally {
    if(-not $fixtureRoot.StartsWith($temporaryBase,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $fixtureRoot) -notmatch '^Offhand-third-monitor-[a-f0-9]{32}$'){throw 'Unexpected fixture cleanup path'}
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}
