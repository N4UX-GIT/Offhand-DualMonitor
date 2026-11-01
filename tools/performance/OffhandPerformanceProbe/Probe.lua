-- Standalone opt-in QA observer. No hooks, CVar writes, global CPU reset or
-- protected-frame changes. Optional timing uses an explicit addon-owned recorder.
-- Frame intervals describe the whole client.
local controller = CreateFrame('Frame')
local active
local maintenanceOwner,maintenanceProvider
local function Number(value)
    return type(value)=='number' and value==value and value>=0 and value<math.huge
end
local function ModernMetrics()
    local profiler=C_AddOnProfiler
    local metrics=Enum and Enum.AddOnProfilerMetric
    if not profiler or not metrics or type(profiler.GetAddOnMetric)~='function' then return nil end
    if type(profiler.IsEnabled)=='function' then
        local ok,enabled=pcall(profiler.IsEnabled)
        if not ok or not enabled then return nil end
    end
    local result={}
    local function ReadMetric(method,metric,addon)
        local fn=profiler[method]
        if type(fn)~='function' or metric==nil then return nil end
        local ok,value
        if addon then ok,value=pcall(fn,addon,metric) else ok,value=pcall(fn,metric) end
        if ok and Number(value) then return value end
    end
    result.offhandRecentMs=ReadMetric('GetAddOnMetric',metrics.RecentAverageTime,'Offhand')
    result.offhandLastMs=ReadMetric('GetAddOnMetric',metrics.LastTime,'Offhand')
    result.offhandPeakMs=ReadMetric('GetAddOnMetric',metrics.PeakTime,'Offhand')
    result.offhandSessionAverageMs=ReadMetric('GetAddOnMetric',metrics.SessionAverageTime,'Offhand')
    result.offhandOver1Ms=ReadMetric('GetAddOnMetric',metrics.CountTimeOver1Ms,'Offhand')
    result.offhandOver5Ms=ReadMetric('GetAddOnMetric',metrics.CountTimeOver5Ms,'Offhand')
    result.displayProbeRecentMs=ReadMetric('GetAddOnMetric',metrics.RecentAverageTime,'OffhandDisplayProbe')
    result.overallRecentMs=ReadMetric('GetOverallMetric',metrics.RecentAverageTime)
    result.applicationRecentMs=ReadMetric('GetApplicationMetric',metrics.RecentAverageTime)
    if result.overallRecentMs and result.applicationRecentMs and result.applicationRecentMs>0 then
        result.addonListCurrentPercent=100*result.overallRecentMs/result.applicationRecentMs
    end
    if result.offhandRecentMs==nil and result.overallRecentMs==nil then return nil end
    return result
end
local function SampleModern(result)
    local sample=ModernMetrics()
    if not sample then return end
    sample.elapsedSeconds=math.max(0,GetTime()-result.started)
    result.profilerSamples=result.profilerSamples or {}
    if #result.profilerSamples<1802 then result.profilerSamples[#result.profilerSamples+1]=sample end
    result.modernEnd=sample
end
local function Message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('[Offhand performance] '..text) end
end
local function StartMaintenanceTiming(result)
    local owner=_G.Offhand
    if type(debugprofilestop)~='function' or not owner or not owner.SeamRedirect
        or owner.SeamRedirect.PerformanceMaintenanceVersion~=1 then
        result.maintenanceTimingStatus='candidate timing capability unavailable'
        return
    end
    if owner.PerformanceMaintenanceProbe then
        result.maintenanceTimingStatus='another recorder owns maintenance timing'
        return
    end
    result.maintenanceTimingStatus='active'
    -- Capture capability shape once, without calling native layout getters or
    -- retaining any native tables. This distinguishes the scalar and copy paths.
    local inputTypes=Enum and Enum.InputDeviceInterfaceType
    local presetManager=_G.EditModePresetLayoutManager
    local presetTable=not owner.isForever and presetManager and presetManager.presetLayoutInfo
    local firstPreset=type(presetTable)=='table' and presetTable[1]
    result.controllerDetection={
        isForever=owner.isForever==true,
        gamepadEnumAvailable=inputTypes~=nil and inputTypes.Gamepad~=nil,
        presetTableType=type(presetTable),firstPresetType=type(firstPreset),
        copyMethodAvailable=presetManager~=nil and type(presetManager.GetCopyOfPresetLayouts)=='function',
        scalarAdapterAvailable=owner.MainhandCompatibility~=nil
            and type(owner.MainhandCompatibility.ReadControllerPresetMode)=='function',
    }
    result.maintenancePhases={}
    maintenanceOwner=owner
    maintenanceProvider={Run=function(_,name,fn,receiver)
        -- Do not catch/suppress errors or execute the operation twice. These
        -- maintenance operations have no consumed return values.
        if active~=result then fn(receiver);return end
        local before=debugprofilestop()
        fn(receiver)
        local elapsed=debugprofilestop()-before
        if not Number(elapsed) then return end
        local phase=result.maintenancePhases[name]
        if not phase then
            phase={calls=0,totalMs=0,maxMs=0,over1Ms=0,samples={}}
            result.maintenancePhases[name]=phase
        end
        phase.calls=phase.calls+1
        phase.totalMs=phase.totalMs+elapsed
        phase.maxMs=math.max(phase.maxMs,elapsed)
        if elapsed>1 then phase.over1Ms=phase.over1Ms+1 end
        if #phase.samples<64 then
            phase.samples[#phase.samples+1]={elapsedSeconds=GetTime()-result.started,callMs=elapsed}
        end
    end}
    owner.PerformanceMaintenanceProbe=maintenanceProvider
end
local function StopMaintenanceTiming()
    if maintenanceOwner and maintenanceOwner.PerformanceMaintenanceProbe==maintenanceProvider then
        maintenanceOwner.PerformanceMaintenanceProbe=nil
    end
    maintenanceOwner,maintenanceProvider=nil,nil
end
local function API(name)
    return _G[name] or C_AddOns and C_AddOns[name]
end
local function Read(name)
    local getter = API(name)
    if type(getter) ~= 'function' then return nil end
    local ok, value = pcall(getter, 'Offhand')
    if ok and type(value)=='number' and value==value and value>=0 and value<math.huge then return value end
end
local function CPU()
    local enabled = GetCVar and GetCVar('scriptProfile')
    if enabled~='1' then return nil end
    local update = API('UpdateAddOnCPUUsage')
    if type(update)~='function' or not pcall(update) then return nil end
    return Read('GetAddOnCPUUsage')
end
local function Memory()
    local update = API('UpdateAddOnMemoryUsage')
    if type(update)~='function' or not pcall(update) then return nil end
    return Read('GetAddOnMemoryUsage')
end
local function Stop(reason)
    if not active then Message('No capture running.'); return end
    controller:SetScript('OnUpdate',nil)
    StopMaintenanceTiming()
    local result=active
    active=nil
    SampleModern(result)
    result.durationSeconds=math.max(0,GetTime()-result.started)
    result.cpuEndMs=CPU()
    result.memoryEndKiB=Memory()
    if result.cpuStartMs and result.cpuEndMs and result.cpuEndMs>=result.cpuStartMs then
        result.cpuDeltaMs=result.cpuEndMs-result.cpuStartMs
        if result.durationSeconds>0 then result.cpuMsPerSecond=result.cpuDeltaMs/result.durationSeconds end
    else result.legacyCpuUnavailable=true end
    result.cpuUnavailable=result.legacyCpuUnavailable and not result.modernEnd or nil
    result.reason=reason
    OffhandPerformanceProbeDB=type(OffhandPerformanceProbeDB)=='table' and OffhandPerformanceProbeDB or {}
    local saved=OffhandPerformanceProbeDB
    saved[#saved+1]=result
    while #saved>6 do table.remove(saved,1) end
    Message(string.format('%s: %.1fs; Offhand CPU %s; whole-client max frame %.1fms, >50ms frames %d. Exit normally to save.',
        result.label,result.durationSeconds,
        result.modernEnd and result.modernEnd.offhandRecentMs
            and string.format('recent %.4f ms/profiler tick',result.modernEnd.offhandRecentMs)
            or result.cpuMsPerSecond and string.format('%.3f ms/s',result.cpuMsPerSecond) or 'unavailable',
        result.maxFrameMs,result.over50ms))
end
local function Start(label)
    if active then Message('Stop the current capture first.'); return end
    local version,build,_,interface
    if GetBuildInfo then version,build,_,interface=GetBuildInfo() end
    active={label=label~='' and label:sub(1,80) or 'unlabelled',started=GetTime(),
        clientVersion=version,clientBuild=build,interface=interface,
        cpuStartMs=CPU(),memoryStartKiB=Memory(),frames=0,maxFrameMs=0,
        over16ms=0,over33ms=0,over50ms=0,over100ms=0}
    SampleModern(active)
    active.modernStart=active.modernEnd
    StartMaintenanceTiming(active)
    local sampleElapsed=0
    controller:SetScript('OnUpdate',function(_,elapsed)
        if type(elapsed)~='number' or elapsed<0 or elapsed~=elapsed then return end
        local r=active
        if not r then return end
        local ms=elapsed*1000
        r.frames=r.frames+1
        r.maxFrameMs=math.max(r.maxFrameMs,ms)
        if ms>1000/60 then r.over16ms=r.over16ms+1 end
        if ms>1000/30 then r.over33ms=r.over33ms+1 end
        if ms>50 then r.over50ms=r.over50ms+1 end
        if ms>100 then r.over100ms=r.over100ms+1 end
        sampleElapsed=sampleElapsed+elapsed
        if sampleElapsed>=0.5 then sampleElapsed=0;SampleModern(r) end
        if GetTime()-r.started>=900 then Stop('15 minute limit') end
    end)
    Message('Capturing '..active.label..' for up to 15 minutes. /ohperf stop ends it. CPU '..
        (active.modernStart and 'available through C_AddOnProfiler; no scriptProfile change needed.'
            or active.cpuStartMs and 'available.' or 'unavailable on this client; check supported profiler APIs.'))
    Message('Maintenance timing: '..active.maintenanceTimingStatus..'.')
end
SLASH_OFFHANDPERFORMANCEPROBE1='/ohperf'
SlashCmdList.OFFHANDPERFORMANCEPROBE=function(message)
    local command,label=(message or ''):match('^(%S+)%s*(.*)$')
    command=command and command:lower()
    if command=='start' then Start(label)
    elseif command=='stop' then Stop('manual')
    else Message('/ohperf start LABEL | /ohperf stop. Last six captures are saved on normal logout.') end
end
controller:RegisterEvent('PLAYER_LOGOUT')
controller:SetScript('OnEvent',function() if active then Stop('logout') end end)
