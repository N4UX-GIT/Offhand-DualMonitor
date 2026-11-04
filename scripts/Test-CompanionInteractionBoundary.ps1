param([string]$SourceDirectory = (Join-Path $PSScriptRoot '../Companion/Source'), [string]$OutputPath)
$ErrorActionPreference='Stop'
$allowed=@(
 'kernel32.dll!GetCurrentPackageFullName','user32.dll!GetDisplayConfigBufferSizes','user32.dll!QueryDisplayConfig',
 'user32.dll!GetSourceName','user32.dll!GetColorInfo','user32.dll!MonitorFromRect','user32.dll!GetMonitorInfo',
 'shcore.dll!GetScaleFactorForMonitor','user32.dll!GetWindowPlacement','user32.dll!SetWindowPlacement',
 'user32.dll!EnumWindows','user32.dll!GetWindowThreadProcessId','user32.dll!IsWindowVisible','user32.dll!IsZoomed',
 'user32.dll!IsIconic','user32.dll!ShowWindow','user32.dll!SetForegroundWindow','user32.dll!GetWindowLong',
 'user32.dll!SetWindowLong','kernel32.dll!SetLastError','kernel32.dll!OpenProcess',
 'kernel32.dll!QueryFullProcessImageName','kernel32.dll!CloseHandle','user32.dll!SetWindowPos',
 'user32.dll!SetWindowRgn','user32.dll!GetWindowRgn','user32.dll!GetClientRect','user32.dll!IsHungAppWindow',
 'gdi32.dll!GetRgnBox','gdi32.dll!CreateRectRgn','gdi32.dll!CombineRgn','gdi32.dll!DeleteObject',
 'user32.dll!GetWindowRect','user32.dll!GetSystemMetrics','user32.dll!EnumDisplayDevices',
 'user32.dll!SetThreadDpiAwarenessContext'
)
$pattern='\[DllImport\("(?<dll>[^"]+)"(?<args>[^\]]*)\)\]\s*(?:\[return:[^\]]+\]\s*)*(?:public|private|internal)\s+static\s+extern\s+\S+\s+(?<name>\w+)\s*\('
$denied='\b(ReadProcessMemory|WriteProcessMemory|VirtualAllocEx|CreateRemoteThread|NtReadVirtualMemory|NtWriteVirtualMemory|SetWindowsHookEx|SendInput|SendMessage|PostMessage|SendKeys|keybd_event|mouse_event|GetProcAddress|LoadLibrary|PROCESS_ALL_ACCESS|PROCESS_VM_READ|PROCESS_VM_WRITE)\b'
$aliases=@{GetSourceName='DisplayConfigGetDeviceInfo';GetColorInfo='DisplayConfigGetDeviceInfo';GetMonitorInfo='GetMonitorInfoW'}
$found=@();$files=@();$excluded=@();$allSource=''
foreach($file in Get-ChildItem -LiteralPath $SourceDirectory -Filter '*.cs' -File){
 $source=[IO.File]::ReadAllText($file.FullName);$allSource+=$source+"`n"
 if($source -match $denied){throw ('Restricted native/process/input symbol in '+$file.Name+': '+$matches[0])}
 # This existing experiment has a different build entry point and is not
 # compiled by the ordinary candidate builder. Never count it as shipped code.
 if($file.Name -eq 'SpanPresentationTest.cs'){$excluded+=$file.Name;continue}
 $imports=[regex]::Matches($source,$pattern)
 if($imports.Count -ne [regex]::Matches($source,'\[DllImport\(').Count){throw 'Unrecognized native import declaration requires review.'}
 foreach($import in $imports){
  $key=$import.Groups['dll'].Value+'!'+$import.Groups['name'].Value
  if($allowed -cnotcontains $key){throw ('Unreviewed native import: '+$key)}
  $entry=[regex]::Match($import.Groups['args'].Value,'EntryPoint\s*=\s*"([^"]+)"')
  $expected=if($aliases.ContainsKey($import.Groups['name'].Value)){$aliases[$import.Groups['name'].Value]}else{$import.Groups['name'].Value}
  if($entry.Success -and $entry.Groups[1].Value -cne $expected){throw ('Unreviewed native entry point: '+$key)}
  $found+=$key
 }
 $files+=[ordered]@{path=$file.Name;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash}
}
if(-not $files.Count){throw 'No Companion source found.'}
$calls=[regex]::Matches($allSource,'NativeMethods\.OpenProcess\(').Count
$allProcessReferences=[regex]::Matches($allSource,'\bOpenProcess\s*\(').Count
$limited=[regex]::Matches($allSource,'NativeMethods\.OpenProcess\(\s*NativeMethods\.PROCESS_QUERY_LIMITED_INFORMATION\s*,\s*false\s*,\s*process\.Id\s*\)').Count
if($calls -ne 1 -or $limited -ne 1 -or $allProcessReferences -ne 2){throw 'Process-path query access changed and requires review.'}
$constant=[regex]::Matches($allSource,'const\s+uint\s+PROCESS_QUERY_LIMITED_INFORMATION\s*=\s*0x1000\s*;').Count
if($constant -ne 1){throw 'Process query access constant changed.'}
if($found.Count -ne $allowed.Count -or @($found|Select-Object -Unique).Count -ne $allowed.Count){throw 'Native import surface changed and requires review.'}
$receipt=[ordered]@{kind='bounded-source-interaction-audit';files=$files;excludedExperimentalSources=$excluded;nativeImports=$found.Count;
 processPathQuery='PROCESS_QUERY_LIMITED_INFORMATION, executable path only';
 limitations='Textual source tripwire, not a full security audit, runtime policy approval, Warden result or antivirus verdict.'}
if($OutputPath){$receipt|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $OutputPath -Encoding UTF8}
Write-Output ('PASS: '+$files.Count+' source files; '+$found.Count+' reviewed native declarations; restricted process/input symbols absent.')
