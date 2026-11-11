local clock, combat, nativeCalls, layoutReads, saves = 0, false, 0, 0, 0
local scripts, hooks = {}, {}
CreateFrame = function() return {RegisterEvent = function() end,
    SetScript = function(_, event, callback) scripts[event] = callback end} end
GetTime = function() return clock end
GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
InCombatLockdown = function() return combat end
SlashCmdList = {}
local secret = {}
issecretvalue = function(value) return value == secret end
debugstack = function() return "OtherMover/Move.lua:27 SetPoint" end
SetCVar = function() error("observer wrote CVar") end
SendChatMessage = function() error("observer sent a message") end
UIParent = {GetName = function() return "UIParent" end}
CharacterFrame = {GetName = function() return "CharacterFrame" end,
    IsForbidden = function() return false end,
    IsShown = function() return true end, GetParent = function() return UIParent end,
    GetEffectiveScale = function() return 0.7 end,
    GetLeft = function() assert(not combat); return 150 end,
    SetPoint = function() nativeCalls = nativeCalls + 1; return "native-result" end,
    ClearAllPoints = function() error("test never requests native clear") end,
    SetScale = function() error("test never requests native scale") end}
local layouts = {activeLayout = 5, layouts = {{layoutName = "private character name", layoutType = 1,
    systems = {{system = 2, systemIndex = 1, isInDefaultPosition = false,
        anchorInfo = {point = "TOP", relativeTo = "UIParent", relativePoint = "TOP", offsetX = 12, offsetY = -30}}}}}}
C_EditMode = {
    GetLayouts = function() assert(not combat); layoutReads = layoutReads + 1; return layouts end,
    SaveLayouts = function(data) assert(data == layouts); saves = saves + 1; return true end,
}
hooksecurefunc = function(target, method, callback)
    local key = target == C_EditMode and method or "frame:" .. method
    hooks[key] = (hooks[key] or 0) + 1
    local native = target[method]
    target[method] = function(...)
        local result = native(...)
        callback(...)
        return result
    end
end
assert(loadfile("tools/issue-capture/OffhandIssueProbe/Probe.lua"))()
local command = SlashCmdList.OFFHANDISSUEPROBE
assert(OffhandIssueProbeDB == nil and next(hooks) == nil, "probe was active without explicit start")
command("start panel-shift")
local run = OffhandIssueProbeDB.runs[1]
assert(run.build == "70862" and layoutReads == 1 and saves == 0)
assert(run.snapshots[1].editMode.layouts[1].layoutName == nil, "capture retained character layout names")
assert(CharacterFrame:SetPoint("CENTER", UIParent, "CENTER", 20, 30) == "native-result")
assert(run.events[1].x == 20 and run.events[1].stack:find("OtherMover", 1, true))
combat = true
scripts.OnEvent(nil, "PLAYER_REGEN_DISABLED")
assert(run.snapshots[2].state == "combat-deferred" and layoutReads == 1)
CharacterFrame:SetPoint("CENTER", UIParent, "CENTER", secret, -10)
assert(run.events[2].x == "<secret>" and nativeCalls == 2)
combat = false
scripts.OnEvent(nil, "PLAYER_REGEN_ENABLED")
C_EditMode.SaveLayouts(layouts)
assert(saves == 1 and run.snapshots[#run.snapshots].label == "SaveLayouts payload",
    "probe did not preserve the native save or record the bounded payload")
command("mark after-save")
assert(run.snapshots[#run.snapshots].editMode.layouts[1].systems[1].anchor.offsetX == 12)
scripts.OnEvent(nil, "ADDON_LOADED")
assert(hooks["frame:SetPoint"] == 1 and hooks.SaveLayouts == 1, "probe duplicated hooks")
command("stop")
local count = #run.events
CharacterFrame:SetPoint("CENTER", UIParent, "CENTER", 40, 50)
assert(#run.events == count and scripts.OnUpdate == nil, "stopped probe kept collecting")
for i = 1, 4 do command("start run" .. i); command("stop") end
assert(#OffhandIssueProbeDB.runs == 3, "capture history grew without bounds")
command("start bounded")
run = OffhandIssueProbeDB.runs[3]
for i = 1, 125 do CharacterFrame:SetPoint("CENTER", UIParent, "CENTER", i, 0) end
assert(#run.events == 120 and run.stopReason == "event-limit", "writer capture did not stop at the cap")
command("start timeout")
clock = clock + 181
scripts.OnUpdate()
assert(OffhandIssueProbeDB.runs[3].stopReason == "time-limit" and scripts.OnUpdate == nil)
assert(saves == 1, "observer invoked a native layout save")
print("PASS: opt-in read-only issue capture, writer/stack evidence, native returns, secret/combat guards and bounded history")
