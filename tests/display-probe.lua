-- Read-only diagnostics must be bounded, opt-in, isolated and stoppable.
local frames, messages, values = {}, {}, {vsync="1", gxWindow="1", gxMaximize="0"}
CreateFrame = function()
    local f = {scripts={}, events={}}
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(key) self.events[key] = true end
    function f:UnregisterAllEvents() self.events = {} end
    frames[#frames+1] = f
    return f
end
print = function(message) messages[#messages+1] = message end
date = function() return "2026-10-24T18:00:00Z" end
GetBuildInfo = function() return "test", "12345", "", 120107 end
GetCVar = function(name)
    if name == "gxApi" then error("unavailable") end
    return values[name]
end
SetCVar = function() error("probe must not write CVars") end
GetPhysicalScreenSize = function() return 4000,2560 end
GetAddOnMetadata = function() return "beta.22" end
UIParent = {GetWidth=function() return 4000 end, GetHeight=function() return 2560 end,
    GetEffectiveScale=function() return 1 end}
local spanned = true
Offhand = {db={enabled=true}, Viewport={GetMetrics=function() return {isSpanned=spanned,topologyStatus="READY"} end}}
OffhandCharDB = {mainhandLayoutDeferred=true}
SlashCmdList = {}
local mapCallbacks = {}
EventRegistry = {
    RegisterCallback=function(_,key,fn,owner) assert(owner==OffhandDisplayProbe); mapCallbacks[key]=fn end,
    UnregisterCallback=function(_,key,owner) assert(owner==OffhandDisplayProbe); mapCallbacks[key]=nil end,
}
assert(loadfile("tools/display-capture/OffhandDisplayProbe/Probe.lua"))()
local frame = frames[1]
assert(not frame.scripts.OnUpdate and next(frame.events) == nil and not OffhandDisplayProbeDB,
    "loading the helper must not start capture or create SavedVariables")
SlashCmdList.OFFHANDDISPLAYPROBE("start")
local capture = OffhandDisplayProbeDB.captures[1]
assert(#capture.records == 1 and capture.records[1].cvars.vsync == "1" and frame.scripts.OnUpdate)
frame.scripts.OnUpdate(frame,0.25)
assert(#capture.records == 1, "unchanged samples must be coalesced")
values.vsync = "0"
frame.scripts.OnEvent(frame,"CVAR_UPDATE","vsync")
frame.scripts.OnEvent(frame,"CVAR_UPDATE","someUnrelatedSetting")
frame.scripts.OnUpdate(frame,0.25)
assert(#capture.events == 1 and #capture.records == 2 and capture.records[2].cvars.vsync == "0")
spanned = false
frame.scripts.OnEvent(frame,"DISPLAY_SIZE_CHANGED")
assert(capture.records[3].metrics.isSpanned == false)
SlashCmdList.OFFHANDDISPLAYPROBE("stop")
assert(not frame.scripts.OnUpdate and next(frame.events) == nil and capture.stopReason == "manual")
assert(next(mapCallbacks)==nil, 'stopping must remove map callbacks')
SlashCmdList.OFFHANDDISPLAYPROBE('start')
local mapCapture = OffhandDisplayProbeDB.captures[#OffhandDisplayProbeDB.captures]
mapCallbacks.WorldMapOnShow()
assert(mapCapture.records[#mapCapture.records].reason=='WorldMapOnShow'
    and mapCapture.records[#mapCapture.records].frames.UIParent.width==4000,
    'map lifecycle capture must include read-only frame geometry')
mapCallbacks.WorldMapOnHide()
SlashCmdList.OFFHANDDISPLAYPROBE('stop')
assert(next(mapCallbacks)==nil)
assert(OffhandCharDB.mainhandLayoutDeferred and Offhand.db.enabled,
    "diagnostics must not alter setup/profile state")
for _=1,3 do
    SlashCmdList.OFFHANDDISPLAYPROBE("start")
    frame.scripts.OnUpdate(frame,180)
end
assert(#OffhandDisplayProbeDB.captures == 2 and not frame.scripts.OnUpdate,
    "captures and lifetime must remain bounded")
SlashCmdList.OFFHANDDISPLAYPROBE("start")
frame.scripts.OnEvent(frame,"PLAYER_LOGOUT")
assert(not frame.scripts.OnUpdate and OffhandDisplayProbeDB.captures[2].stopReason == "logout")
SlashCmdList.OFFHANDDISPLAYPROBE("start")
for _=1,400 do frame.scripts.OnEvent(frame,"DISPLAY_SIZE_CHANGED") end
assert(not frame.scripts.OnUpdate and #OffhandDisplayProbeDB.captures[2].records <= 360,
    "display storms must stop at the record limit")
io.write("PASS: opt-in display probe, read-only snapshots, event filtering, retention and lifetime bounds\n")
