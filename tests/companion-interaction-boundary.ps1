$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$audit=Join-Path $root scripts/Test-CompanionInteractionBoundary.ps1
& $audit
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixture=Join-Path $tempRoot ('Offhand-interaction-boundary-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture|Out-Null
try {
 Copy-Item -LiteralPath (Join-Path $root Companion/Source/LayoutDocument.cs) -Destination $fixture
 $source=[IO.File]::ReadAllText((Join-Path $root Companion/Source/Program.cs))
 $path=Join-Path $fixture Program.cs
 $checks=0
 function Reject([string]$Changed,[string]$Expected){
  [IO.File]::WriteAllText($path,$Changed,[Text.UTF8Encoding]::new($false))
  $failed=$false
  try {& $audit -SourceDirectory $fixture|Out-Null} catch {
   if($_.Exception.Message -notmatch $Expected){throw}
   $failed=$true
  }
  if(-not $failed){throw ('Changed boundary accepted: '+$Expected)}
 }
 Reject ($source.Replace('PROCESS_QUERY_LIMITED_INFORMATION = 0x1000','PROCESS_QUERY_LIMITED_INFORMATION = 0x1F0FFF')) 'constant changed';$checks++
 Reject ($source.Replace('NativeMethods.PROCESS_QUERY_LIMITED_INFORMATION, false, process.Id','0x1F0FFF, false, process.Id')) 'access changed';$checks++
 Reject ($source+"`nvoid ExtraCall() { OpenProcess(0x1F0FFF, false, 1); }") 'access changed';$checks++
 Reject ($source.Replace('EntryPoint = "GetMonitorInfoW"','EntryPoint = "DifferentExport"')) 'entry point';$checks++
 Reject ($source+"`n[DllImport(`"user32.dll`")] private static extern void SendInput();") 'Restricted';$checks++
 Reject ($source+"`n[DllImport(`"kernel32.dll`")] private static extern void WriteProcessMemory();") 'Restricted';$checks++
 Reject ($source+"`n[DllImport(`"kernel32.dll`")] private static extern void NewUnreviewedExport();") 'Unreviewed native import';$checks++
 Reject ($source+"`n[DllImport(`"kernel32.dll`")] unrecognized-declaration") 'Unrecognized native import';$checks++
 [IO.File]::WriteAllText($path,$source,[Text.UTF8Encoding]::new($false))
 & $audit -SourceDirectory $fixture
 Write-Output ('PASS: '+$checks+' changed process/input/import boundaries rejected; baseline accepted.')
} finally {
 $resolved=[IO.Path]::GetFullPath($fixture)
 if(-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notmatch '^Offhand-interaction-boundary-[a-f0-9]{32}$'){throw 'Unexpected fixture cleanup path'}
 Remove-Item -LiteralPath $resolved -Recurse -Force
}
