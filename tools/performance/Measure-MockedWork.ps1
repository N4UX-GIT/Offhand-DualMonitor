# Characterize real addon code through existing mocks. This is not a live CPU
# benchmark and does not launch or change a game client.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$nativeMeasure = @'
local metricsCalls,handleWrites,nativeWrites=0,0,0
local priorMetrics=addon.Viewport.GetMetrics
addon.Viewport.GetMetrics=function(...) metricsCalls=metricsCalls+1;return priorMetrics(...) end
for _,method in ipairs({'ClearAllPoints','SetPoint','SetSize'}) do
    local original=handle[method]
    handle[method]=function(...) handleWrites=handleWrites+1;return original(...) end
end
local originalPoint=bag.SetPoint
bag.SetPoint=function(...) nativeWrites=nativeWrites+1;return originalPoint(...) end
for _=1,600 do controller.scripts.OnUpdate(controller,1/60) end
assert(nativeWrites==0,'steady native bag must not be repeatedly reanchored')
print(string.format('Native-bag steady 600 frames: %d metric reads, %d proxy layout writes, %d bag anchor writes',metricsCalls,handleWrites,nativeWrites))
'@
$chromeMeasure = @'
metrics.isSpanned=true
chrome:Refresh()
local alphaWrites,mouseWrites=0,0
local originalAlpha,originalMouse=mapClose.SetAlpha,mapClose.EnableMouse
mapClose.SetAlpha=function(...) alphaWrites=alphaWrites+1;return originalAlpha(...) end
mapClose.EnableMouse=function(...) mouseWrites=mouseWrites+1;return originalMouse(...) end
for _=1,600 do chrome:Refresh() end
print(string.format('Workspace chrome steady 600 refreshes, one hidden map close: %d alpha writes, %d mouse writes',alphaWrites,mouseWrites))
'@
$cases = @(
    @{File='forever-native-bag-proxy.lua';Measure=$nativeMeasure},
    @{File='workspace-close-buttons.lua';Measure=$chromeMeasure}
)
Push-Location $root
try {
    foreach ($case in $cases) {
        $temporaryFile = Join-Path ([IO.Path]::GetTempPath()) ('Offhand-work-count-'+[guid]::NewGuid().ToString()+'.lua')
        try {
            $source = [IO.File]::ReadAllText((Join-Path $root ('tests/'+$case.File)))
            [IO.File]::WriteAllText($temporaryFile,$source+"`n"+$case.Measure,[Text.UTF8Encoding]::new($false))
            & lua $temporaryFile
            if ($LASTEXITCODE -ne 0) { throw ('Mock characterization failed: '+$case.File) }
        } finally {
            if (Test-Path -LiteralPath $temporaryFile) { Remove-Item -LiteralPath $temporaryFile }
        }
    }
} finally { Pop-Location }
