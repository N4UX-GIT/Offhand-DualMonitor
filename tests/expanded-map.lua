local events, callbacks, queue = {}, {}, {}
local metrics = {isSpanned=true}
local owner, combat, workspace = "OpenMap", false, false
local addon = {
    isForever=true, db={enabled=true}, Canvas={IsFrameOnWorkspace=function() return workspace end},
    Viewport={GetMetrics=function() return metrics end},
    CanvasMapPresentation={IsNativeGamepadOwned=function() return false end},
    CanvasCompatibility={
        GetWorldMapExternalOwner=function() return owner end,
        GetOpenMapWorldMapModule=function() return true end,
        GetOpenMapWindowModule=function() return true end,
    },
    OpenMapRecovery={Run=function(_, target) workspace=target; return true end},
}
WorldMapFrame = {
    IsShown=function(self) return self.shown end,
    IsMaximized=function(self) return self.max end,
    IsForbidden=function() return false end,
    HandleUserActionMaximizeSelf=function(self) self.max=true end,
    HandleUserActionMinimizeSelf=function(self) self.max=false; callbacks.WorldMapMinimized() end,
}
local map = WorldMapFrame
function ShowUIPanel(frame) frame.shown=true end
function InCombatLockdown() return combat end
UISpecialFrames = {}
function CreateFrame(_, name)
    local frame = {RegisterEvent=function() end, SetScript=function(_, key, fn) events[key]=fn end}
    function frame:Hide()
        if self.shown then self.shown=false; if events.OnHide then events.OnHide(self) end end
    end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown=true end
    _G[name] = frame
    return frame
end
EventRegistry={RegisterCallback=function(_, key, fn) callbacks[key]=fn end}
C_Timer={After=function(_, fn) queue[#queue+1]=fn end}
local function flush()
    while #queue > 0 do table.remove(queue, 1)() end
end
local function close()
    map.shown=false
    callbacks.WorldMapOnHide()
end
assert(loadfile("Core/ExpandedMap.lua"))("Offhand", addon)
local function toggle() addon.ExpandedMap:Toggle() end
toggle()
assert(map.shown and map.max)
close(); flush()
assert(map.shown and not map.max and workspace, "close must reopen compact on Offhand")
close(); flush()
assert(not map.shown, "ordinary compact close must stay closed")
toggle(); toggle(); flush()
assert(map.shown and not map.max)
toggle(); _G[UISpecialFrames[1]]:Hide(); flush()
assert(map.shown and not map.max and #UISpecialFrames==1)
toggle(); map:HandleUserActionMinimizeSelf(); flush()
assert(map.shown and not map.max)
toggle(); close(); events.OnEvent(); flush()
assert(not map.shown, "world exit and combat cancel a pending return")
toggle(); close(); toggle(); flush()
assert(map.shown and not map.max, "superseded hide callback")
close(); combat=true; toggle(); assert(not map.shown)
combat=false; owner="MoveAny"; toggle(); assert(not map.shown)
owner="OpenMap"; metrics.isSpanned=false; toggle(); assert(not map.shown)
print("PASS: expanded map hotkey session, close and minimize, cancellation and ownership guards")
