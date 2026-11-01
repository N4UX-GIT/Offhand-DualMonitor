local combat, writes = false, 0
InCombatLockdown = function() return combat end
UIParent = { GetEffectiveScale = function() return 0.5 end }
local point = { "TOPRIGHT", UIParent, "TOPRIGHT", -55, -205 }
local root = {}
UIParentRightManagedFrameContainer = root
local userPlaced = false
WatchFrame = { GetParent = function() return root end, IsUserPlaced = function() return userPlaced end }
root.GetNumPoints = function() return 1 end
root.GetPoint = function() return unpack(point) end
root.GetEffectiveScale = function() return 1 end
root.IsForbidden = function() return false end
root.ClearAllPoints = function() assert(not combat); writes = writes + 1 end
root.SetPoint = function(_, ...) assert(not combat); point = {...}; writes = writes + 1 end
for _, name in ipairs({ "Show", "Hide", "SetScale", "SetParent", "SetScript", "HookScript", "SetAttribute", "SetHeight" }) do
    root[name] = function() error("unexpected container mutation: " .. name) end
    WatchFrame[name] = function() error("quest tracker child mutated: " .. name) end
end
FramePositionDelegate = { UIParentManageRightFrameContainer = function() end }
local hooked
hooksecurefunc = function(target, method, callback)
    assert(target == root and method == "SetPoint" and not hooked)
    hooked = callback
    local original = target[method]
    target[method] = function(...) original(...); callback(...) end
end
local metrics = { isSpanned = true, gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446 }
local addon = { db = { enabled = true, seamRedirect = true }, Viewport = { GetMetrics = function() return metrics end } }
local queue = {}
addon.RunOrQueueCombat = function(_, callback) queue[#queue + 1] = callback end
assert(loadfile("Core/MainhandCompatibility.lua"))("Offhand", addon)
local update = addon.MainhandCompatibility.UpdateClassicRightContainer
assert(update and update(metrics), "classic managed quest tracker must follow Mainhand instead of the full-canvas top-right")
assert(point[3] == "BOTTOMLEFT" and point[4] == 1945 and point[5] == 518,
    "container position must preserve native offsets and account for effective scale")
local before = writes
assert(update(metrics) and writes == before, "unchanged geometry must not rewrite native anchors")
root:ClearAllPoints()
root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -80, -210)
assert(point[3] == "BOTTOMLEFT" and point[4] == 1920 and point[5] == 513,
    "native layout reflows must retain their new offsets on Mainhand")
-- Minimap and managed container can have different effective scales. Preserve
-- the native horizontal inset, but clear the live minimap's lower edge.
local mapBottom, mapLeft, mapRight, mapShown = 600, 2200, 2500, true
MinimapCluster = {
    GetBottom = function() return mapBottom end,
    GetLeft = function() return mapLeft end,
    GetRight = function() return mapRight end,
    GetEffectiveScale = function() return 0.75 end,
    IsShown = function() return mapShown end,
    SetPoint = function() error("minimap must remain native") end,
}
assert(update(metrics) and point[4] == 1920 and point[5] == 444,
    "tracker must clear the minimap by 12 UIParent units without changing its native horizontal inset")
root.GetTop = function() return point[5] end
WatchFrame.GetTop = function() return point[5] * 2 + 20 end
WatchFrame.GetEffectiveScale = function() return 0.5 end
assert(update(metrics) and point[5] == 434,
    "a tracker header extending above its container must also clear the minimap")
before = writes
assert(update(metrics) and point[5] == 434 and writes == before,
    "measuring tracker header clearance must not produce cumulative downward drift")
root.GetTop, WatchFrame.GetTop, WatchFrame.GetEffectiveScale = nil, nil, nil
mapBottom = 550
assert(update(metrics) and point[5] == 406.5, "tracker clearance must follow changed minimap geometry")
mapShown = false
assert(update(metrics) and point[5] == 513, "hidden minimaps must not affect tracker positioning")
mapShown, mapLeft, mapRight = true, 100, 300
assert(update(metrics) and point[5] == 513, "a workspace minimap must not pull the Mainhand tracker down")
MinimapCluster = nil
combat = true
metrics.gameTop = 1600
before = writes
assert(not update(metrics) and writes == before, "combat must not mutate the managed container")
update(metrics)
assert(#queue == 1, "combat reflows must queue only one recovery")
combat = false
queue[1]()
queue = {}
assert(update(metrics) and point[5] == 590)
addon.db.enabled = false
assert(not update(metrics) and point[3] == "TOPRIGHT" and point[4] == -80 and point[5] == -210,
    "disable must restore the latest native anchor")
addon.db.enabled = true
-- TBC uses QuestWatchFrame, parented to UIParent and registered through the
-- template's layoutParent, rather than Wrath's direct WatchFrame child.
QuestWatchFrame, WatchFrame = WatchFrame, nil
QuestWatchFrame.GetParent = function() return UIParent end
QuestWatchFrame.layoutParent = root
assert(update(metrics), "TBC's registered QuestWatchFrame must be recognized without WatchFrame")
addon.db.enabled = false
assert(not update(metrics) and point[3] == "TOPRIGHT")
addon.db.enabled = true
addon.db.seamRedirect = false
assert(not update(metrics), "disabled HUD redirection must retain native placement")
addon.db.seamRedirect = true
ConsolePort = {}
assert(not update(metrics), "controller ownership must remain native")
ConsolePort = nil
for _, flag in ipairs({ "isRetail", "isForever", "isLegacyWrath" }) do
    addon[flag] = true
    assert(not update(metrics), "non-Classic client must remain untouched")
    addon[flag] = nil
end
metrics.isSpanned = false
assert(not update(metrics))
metrics.isSpanned = true
userPlaced = true
assert(not update(metrics), "custom tracker placement must retain ownership")
userPlaced = false
assert(update(metrics))
point = { "CENTER", UIParent, "CENTER", 40, 90 }
before = writes
assert(not update(metrics) and writes == before, "external container anchors must win")
addon.db.enabled = false
assert(not update(metrics) and point[1] == "CENTER", "disable must not overwrite another owner's placement")
print("PASS: Classic quest tracker container follows Mainhand with native reflows, scaling and ownership preserved")
