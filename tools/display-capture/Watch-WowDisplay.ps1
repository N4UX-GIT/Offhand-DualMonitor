param(
    [ValidateRange(1,300)][int]$DurationSeconds = 180,
    [int]$WowProcessId = 0,
    [ValidateSet('Any','Retail','Classic')][string]$Client = 'Any',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\dist\display-captures'),
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
# Standalone observer. Does not modify windows, graphics settings, Companion,
# addon files, input focus, display configuration or process state.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class OffhandWindowProbe {
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll", EntryPoint="GetWindowLongW")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern int GetWindowRgn(IntPtr hwnd, IntPtr region);
    [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int left, int top, int right, int bottom);
    [DllImport("gdi32.dll")] public static extern int GetRgnBox(IntPtr region, out Rect rect);
    [DllImport("gdi32.dll")] public static extern uint GetRegionData(IntPtr region, uint count, IntPtr data);
    [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr obj);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool GetLayeredWindowAttributes(IntPtr hwnd, out uint color, out byte alpha, out uint flags);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    public static uint RegionRectangles(IntPtr region) {
        uint size = GetRegionData(region, 0, IntPtr.Zero);
        if (size < 32 || size > 1048576) return 0;
        IntPtr memory = Marshal.AllocHGlobal((int)size);
        try { return GetRegionData(region, size, memory) == 0 ? 0 : (uint)Marshal.ReadInt32(memory, 8); }
        finally { Marshal.FreeHGlobal(memory); }
    }
}
'@
function Rect-Value($rect) {
    @{left=$rect.Left; top=$rect.Top; width=($rect.Right-$rect.Left); height=($rect.Bottom-$rect.Top)}
}
if ($SelfTest) {
    $region = [OffhandWindowProbe]::CreateRectRgn(1,2,101,202)
    try {
        $rect = New-Object OffhandWindowProbe+Rect
        if ([OffhandWindowProbe]::GetRgnBox($region,[ref]$rect) -ne 2 -or $rect.Left -ne 1 -or
            $rect.Bottom -ne 202 -or [OffhandWindowProbe]::RegionRectangles($region) -ne 1) {
            throw 'Owned-region interop self-test failed.'
        }
    } finally { [void][OffhandWindowProbe]::DeleteObject($region) }
    Write-Output 'PASS: observer compiled; owned-region bounds/count and cleanup verified. No WoW window accessed.'
    return
}
# Changes only this helper process's coordinate interpretation, not displays.
$dpiAwareRequest = [OffhandWindowProbe]::SetProcessDPIAware()
Add-Type -AssemblyName System.Windows.Forms
$candidates = @(Get-Process -Name Wow,WowClassic,WowB -ErrorAction SilentlyContinue)
if ($Client -ne 'Any') {
    $candidates = @($candidates | Where-Object {
        $leaf = ''
        try { $leaf = Split-Path (Split-Path $_.Path -Parent) -Leaf } catch { }
        if ($Client -eq 'Retail') { $leaf -eq '_retail_' }
        else { $leaf -in @('_anniversary_','_classic_era_') }
    })
}
if ($WowProcessId) { $candidates = @($candidates | Where-Object Id -eq $WowProcessId) }
if ($candidates.Count -ne 1) { throw 'Exactly one WoW process is required. Use -WowProcessId if multiple clients are running.' }
$selectedId = $candidates[0].Id
$observedProcessName = $candidates[0].ProcessName
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$logPath = Join-Path $OutputDirectory ('window-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.jsonl')
$writer = New-Object System.IO.StreamWriter($logPath, $false, (New-Object System.Text.UTF8Encoding($false)))
$writer.AutoFlush = $true
$clock = [Diagnostics.Stopwatch]::StartNew()
$last = $null
$lastWrite = -1000
try {
    # Flush a start record before monitor enumeration so an interrupted startup
    # is distinguishable from a complete recording, rather than an empty file.
    $writer.WriteLine((@{kind='start'; utc=[DateTime]::UtcNow.ToString('o'); process=$observedProcessName;
        processId=$selectedId; durationSeconds=$DurationSeconds; dpiAwareRequest=$dpiAwareRequest;
        requestedClient=$Client; note='Read-only window observer; no screenshots, titles, chat or account data'} | ConvertTo-Json -Compress))
    Write-Host "Capture file opened: $logPath"
    $monitors = @([System.Windows.Forms.Screen]::AllScreens | ForEach-Object {
        @{device=$_.DeviceName; primary=$_.Primary; left=$_.Bounds.Left; top=$_.Bounds.Top;
          width=$_.Bounds.Width; height=$_.Bounds.Height}
    })
    $writer.WriteLine((@{kind='displays'; utc=[DateTime]::UtcNow.ToString('o'); monitors=$monitors} | ConvertTo-Json -Depth 6 -Compress))
    Write-Host "Recording WoW window for $DurationSeconds seconds. Log: $logPath"
    Write-Host 'Start /ohcapture start in WoW, make ONE Graphics Options change, then /ohcapture stop before re-spanning.'
    Write-Host 'This window stops automatically. Ctrl+C stops it early.'
    while ($clock.Elapsed.TotalSeconds -lt $DurationSeconds) {
        $proc = Get-Process -Id $selectedId -ErrorAction SilentlyContinue
        if (-not $proc) { break }
        $proc.Refresh()
        $handle = $proc.MainWindowHandle
        $state = [ordered]@{hwnd=$handle.ToInt64()}
        if ($handle -ne [IntPtr]::Zero) {
            $state.hung = [OffhandWindowProbe]::IsHungAppWindow($handle)
            $rect = New-Object OffhandWindowProbe+Rect
            if ([OffhandWindowProbe]::GetWindowRect($handle,[ref]$rect)) { $state.window = Rect-Value $rect }
            if ([OffhandWindowProbe]::GetClientRect($handle,[ref]$rect)) { $state.client = Rect-Value $rect }
            $state.style = [OffhandWindowProbe]::GetWindowLong($handle,-16)
            $state.extendedStyle = [OffhandWindowProbe]::GetWindowLong($handle,-20)
            $state.visible = [OffhandWindowProbe]::IsWindowVisible($handle)
            $state.minimized = [OffhandWindowProbe]::IsIconic($handle)
            $state.foreground = [OffhandWindowProbe]::GetForegroundWindow() -eq $handle
            $region = [OffhandWindowProbe]::CreateRectRgn(0,0,0,0)
            try {
                $kind = [OffhandWindowProbe]::GetWindowRgn($handle,$region)
                $state.regionKind = $kind # 0=no readable explicit region, 1=empty, 2=simple, 3=complex.
                if ($kind -gt 0) {
                    [void][OffhandWindowProbe]::GetRgnBox($region,[ref]$rect)
                    $state.regionBox = Rect-Value $rect
                    $state.regionRectangles = [OffhandWindowProbe]::RegionRectangles($region)
                }
            } finally { [void][OffhandWindowProbe]::DeleteObject($region) }
            [uint32]$key = 0; [byte]$alpha = 0; [uint32]$flags = 0
            if ([OffhandWindowProbe]::GetLayeredWindowAttributes($handle,[ref]$key,[ref]$alpha,[ref]$flags)) {
                $state.layered = @{alpha=$alpha; flags=$flags; colorKey=$key}
            }
        }
        $payload = $state | ConvertTo-Json -Depth 6 -Compress
        if ($payload -ne $last -or $clock.ElapsedMilliseconds - $lastWrite -ge 1000) {
            $writer.WriteLine((@{kind='sample'; utc=[DateTime]::UtcNow.ToString('o'); elapsedMs=$clock.ElapsedMilliseconds;
                state=$state} | ConvertTo-Json -Depth 7 -Compress))
            $last, $lastWrite = $payload, $clock.ElapsedMilliseconds
        }
        $proc.Dispose()
        Start-Sleep -Milliseconds 250
    }
} catch {
    $writer.WriteLine((@{kind='error'; utc=[DateTime]::UtcNow.ToString('o'); message=$_.Exception.Message} | ConvertTo-Json -Compress))
    throw
} finally {
    $writer.WriteLine((@{kind='stop'; utc=[DateTime]::UtcNow.ToString('o'); elapsedMs=$clock.ElapsedMilliseconds} | ConvertTo-Json -Compress))
    $writer.Dispose()
    Write-Host "Capture saved: $logPath"
}
