-- Standalone opt-in QA observer. No hooks, CVar writes, global CPU reset or
-- Offhand runtime mutation. Frame intervals describe the whole client.
local controller = CreateFrame('Frame')
local active
local function Message(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('[Offhand performance] '..text) end
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
    local result=active
    active=nil
    result.durationSeconds=math.max(0,GetTime()-result.started)
    result.cpuEndMs=CPU()
    result.memoryEndKiB=Memory()
    if result.cpuStartMs and result.cpuEndMs and result.cpuEndMs>=result.cpuStartMs then
        result.cpuDeltaMs=result.cpuEndMs-result.cpuStartMs
        if result.durationSeconds>0 then result.cpuMsPerSecond=result.cpuDeltaMs/result.durationSeconds end
    else result.cpuUnavailable=true end
    result.reason=reason
    OffhandPerformanceProbeDB=type(OffhandPerformanceProbeDB)=='table' and OffhandPerformanceProbeDB or {}
    local saved=OffhandPerformanceProbeDB
    saved[#saved+1]=result
    while #saved>6 do table.remove(saved,1) end
    Message(string.format('%s: %.1fs; Offhand CPU %s; whole-client max frame %.1fms, >50ms frames %d. Exit normally to save.',
        result.label,result.durationSeconds,
        result.cpuMsPerSecond and string.format('%.3f ms/s',result.cpuMsPerSecond) or 'unavailable',
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
        if GetTime()-r.started>=900 then Stop('15 minute limit') end
    end)
    Message('Capturing '..active.label..' for up to 15 minutes. /ohperf stop ends it. CPU '..
        (active.cpuStartMs and 'available.' or 'unavailable; enable scriptProfile manually before a reload if supported.'))
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
