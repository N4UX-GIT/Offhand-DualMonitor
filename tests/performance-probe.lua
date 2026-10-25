local scripts,clock,cpu,profile={},0,10,'1'
CreateFrame=function() return {
    SetScript=function(_,event,callback) scripts[event]=callback end,
    RegisterEvent=function() end} end
DEFAULT_CHAT_FRAME={AddMessage=function() end}
SlashCmdList={}
GetTime=function() return clock end
GetCVar=function() return profile end
GetBuildInfo=function() return 'test','123',nil,120107 end
UpdateAddOnCPUUsage=function() end
GetAddOnCPUUsage=function(name) assert(name=='Offhand');return cpu end
UpdateAddOnMemoryUsage=function() end
GetAddOnMemoryUsage=function() return 500 end
assert(loadfile('tools/performance/OffhandPerformanceProbe/Probe.lua'))()
local command=SlashCmdList.OFFHANDPERFORMANCEPROBE
assert(not scripts.OnUpdate,'observer must be inactive by default')
command('start baseline')
local tick=scripts.OnUpdate
clock=10;cpu=30;tick(nil,0.06)
command('stop')
local result=OffhandPerformanceProbeDB[1]
assert(result.cpuDeltaMs==20 and result.cpuMsPerSecond==2)
assert(result.frames==1 and result.over50ms==1 and result.maxFrameMs==60)
assert(not scripts.OnUpdate,'stop must remove the per-frame callback')
profile='0';command('start no-profile');clock=20;command('stop')
assert(OffhandPerformanceProbeDB[2].cpuUnavailable,'missing CPU data must not be reported as zero')
profile='1';command('start reset');cpu=1;clock=30;command('stop')
assert(OffhandPerformanceProbeDB[3].cpuUnavailable,'counter reset must invalidate the delta')
for i=1,8 do command('start limit');clock=clock+901;scripts.OnUpdate(nil,0.01) end
assert(#OffhandPerformanceProbeDB==6 and not scripts.OnUpdate,'bounded retention and duration')
-- Modern retail metrics are available without enabling legacy scriptProfile.
profile='0'
Enum={AddOnProfilerMetric={RecentAverageTime=1,LastTime=3,PeakTime=4,SessionAverageTime=0,CountTimeOver1Ms=5,CountTimeOver5Ms=6}}
C_AddOnProfiler={IsEnabled=function() return true end,
    GetAddOnMetric=function(name,metric)
        if name=='OffhandDisplayProbe' then return 0.001 end
        if metric==1 then return 0.08 end
        if metric==4 then return 1.2 end
        return 0
    end,
    GetOverallMetric=function() return 0.1 end,
    GetApplicationMetric=function() return 20 end}
command('start modern')
clock=clock+1;scripts.OnUpdate(nil,0.5);command('stop')
result=OffhandPerformanceProbeDB[#OffhandPerformanceProbeDB]
assert(result.modernStart and not result.cpuUnavailable and result.legacyCpuUnavailable)
assert(#result.profilerSamples==3 and result.modernEnd.offhandRecentMs==0.08)
assert(math.abs(result.modernEnd.addonListCurrentPercent-0.5)<0.00001,
    'Addon List percentage must compare all-addon recent metric with application metric')
assert(result.modernEnd.displayProbeRecentMs==0.001,'diagnostic addon must be measured separately')
C_AddOnProfiler.GetAddOnMetric=function() error('unavailable') end
C_AddOnProfiler.GetOverallMetric=function() error('unavailable') end
command('start unavailable');clock=clock+1;command('stop')
assert(OffhandPerformanceProbeDB[#OffhandPerformanceProbeDB].cpuUnavailable,
    'failed modern metrics must remain unavailable, not zero')
print('PASS: opt-in performance observer, CPU availability/reset, frame intervals and bounded capture')
