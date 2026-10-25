-- Analyze this QA addon's generated SavedVariables without exposing client paths.
local path=arg and arg[1]
assert(path,'Usage: lua tools/performance/Analyze-Captures.lua PATH_TO_SAVED_CAPTURE')
local environment={}
local chunk=assert(loadfile(path))
setfenv(chunk,environment)
chunk()
local captures=environment.OffhandPerformanceProbeDB
assert(type(captures)=='table','No performance capture table')
local function Stats(samples,key)
    local values,sum={},0
    for _,sample in ipairs(samples or {}) do
        local value=sample[key]
        if type(value)=='number' and value==value and value>=0 and value<math.huge then
            values[#values+1]=value;sum=sum+value
        end
    end
    table.sort(values)
    local n=#values
    if n==0 then return 'unavailable' end
    return string.format('n=%d min=%.6f sampledMean=%.6f median=%.6f p95=%.6f max=%.6f',
        n,values[1],sum/n,values[math.ceil(n*.5)],values[math.ceil(n*.95)],values[n])
end
for index,result in ipairs(captures) do
    print(string.format('Run %d: %s, %.3fs, client %s build %s, %d rendered frames',
        index,tostring(result.label),result.durationSeconds or 0,
        tostring(result.clientVersion),tostring(result.clientBuild),result.frames or 0))
    local first,last=result.modernStart or {},result.modernEnd or {}
    for _,key in ipairs({'offhandOver1Ms','offhandOver5Ms','offhandPeakMs'}) do
        local a,b=first[key],last[key]
        print(key..': start='..tostring(a)..' end='..tostring(b)..' delta='..
            tostring(type(a)=='number' and type(b)=='number' and b>=a and b-a or 'unavailable/reset'))
    end
    for _,key in ipairs({'offhandRecentMs','offhandLastMs','overallRecentMs',
        'applicationRecentMs','addonListCurrentPercent','displayProbeRecentMs'}) do
        print(key..': '..Stats(result.profilerSamples,key))
    end
    local previousCount,previousTime=first.offhandOver1Ms,nil
    local periods={}
    for _,sample in ipairs(result.profilerSamples or {}) do
        local count=sample.offhandOver1Ms
        if type(count)=='number' and type(previousCount)=='number' and count>previousCount then
            if previousTime and type(sample.elapsedSeconds)=='number' then
                periods[#periods+1]={seconds=sample.elapsedSeconds-previousTime}
            end
            previousTime=sample.elapsedSeconds
        end
        previousCount=count
    end
    print('Observed intervals between sampled >1ms counter increments: '..Stats(periods,'seconds'))
    print('Maintenance timing status: '..tostring(result.maintenanceTimingStatus or 'not captured'))
    local names={}
    for name in pairs(result.maintenancePhases or {}) do names[#names+1]=name end
    table.sort(names)
    for _,name in ipairs(names) do
        local phase=result.maintenancePhases[name]
        print(string.format('Phase %s: calls=%d mean=%.6fms max=%.6fms over1=%d',
            name,phase.calls,phase.calls>0 and phase.totalMs/phase.calls or 0,phase.maxMs,phase.over1Ms))
        print('  bounded phase samples: '..Stats(phase.samples,'callMs'))
    end
end
print('Rolling sample means are not exact whole-run CPU totals. Frame timings are client-wide; unmatched runs do not prove FPS causation.')
