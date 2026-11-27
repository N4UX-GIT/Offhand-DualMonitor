local combat, scale, writes, hooks = false, 1, 0, 0
local nativeRounding
InCombatLockdown = function() return combat end
UIParent = {GetWidth = function() return 4000 end, GetHeight = function() return 1600 end,
    GetEffectiveScale = function() return 0.5 end}
local metrics = {isSpanned = true, gameLeft = 1600, gameRight = 4000, gameBottom = 0, gameTop = 1400}
local addon = {db = {enabled = true, centerProcDocOnMainhand = false},
    Viewport = {GetMetrics = function() return metrics end}}
local event
CreateFrame = function() return {RegisterEvent = function() end,
    SetScript = function(_, _, callback) event = callback end} end
local point = {"CENTER", UIParent, "CENTER", 70, -30}
ProcDocAlertFrame = {
    GetParent = function() return UIParent end,
    GetNumPoints = function() return 1 end, GetPoint = function() return unpack(point) end,
    ClearAllPoints = function() assert(not combat); point = {} end,
    SetPoint = function(_, ...)
        assert(not combat); writes = writes + 1; point = {...}
        if nativeRounding then
            for i = 4, 5 do point[i] = math.floor(point[i] * 16384 + 0.5) / 16384 end
        end
    end,
    GetEffectiveScale = function() return scale end,
    ApplyCenter = function() point = {"CENTER", UIParent, "CENTER", 80, -20} end,
}
hooksecurefunc = function(frame, method, callback)
    hooks = hooks + 1
    local native = frame[method]
    frame[method] = function(...) native(...); callback(...) end
end
assert(loadfile("Core/MainhandGeometry.lua"))("Offhand", addon)
local Bridges = dofile("tests/support/core-bridges.lua").Load(addon,
    {"Bridges/ProcDoc/Data.lua", "Bridges/ProcDoc/Bridge.lua"})
local adapter = addon.API.GetBridgeNamespace("ProcDoc")
adapter:Refresh()
assert(writes == 0, "default ProcDoc compatibility must be opt-in")
addon.db.centerProcDocOnMainhand = true
adapter:Refresh()
assert(point[4] == 470 and point[5] == -80, "ProcDoc offsets or Mainhand scale conversion were lost")
adapter:Refresh()
assert(writes == 1 and hooks == 1, "unchanged center was rewritten or hooks duplicated")
ProcDocAlertFrame:ApplyCenter()
assert(point[4] == 480 and point[5] == -70, "vendor offset change did not remain relative to Mainhand")
addon.db.centerProcDocOnMainhand = false
adapter:Refresh()
assert(point[4] == 80 and point[5] == -20, "release did not restore the latest vendor placement")
addon.db.centerProcDocOnMainhand = true
adapter:Refresh()
combat = true
addon.db.enabled = false
local combatWrites = writes
adapter:Refresh()
assert(writes == combatWrites, "combat release changed geometry")
combat = false
event(nil, "PLAYER_REGEN_ENABLED")
assert(point[4] == 80 and point[5] == -20, "deferred release failed")
addon.db.enabled = true
adapter:Refresh()
point = {"TOPLEFT", UIParent, "TOPLEFT", 10, -10}
adapter:Refresh()
addon.db.centerProcDocOnMainhand = false
adapter:Refresh()
assert(point[1] == "TOPLEFT" and point[4] == 10, "release overwrote another mover's anchor")
-- A legacy version without ApplyCenter can still use its native center anchor.
point = {"CENTER", UIParent, "CENTER", 0, 0}
ProcDocAlertFrame.ApplyCenter = nil
addon.db.centerProcDocOnMainhand = true
scale = 0.5
adapter:Refresh()
assert(point[4] == 800 and point[5] == -100, "legacy ProcDoc center did not follow native UI scale")
metrics.isSpanned = false
adapter:Refresh()
assert(point[4] == 0 and point[5] == 0, "restore-window release failed")
metrics.isSpanned = true
adapter:Refresh()
local nativeSetPoint = ProcDocAlertFrame.SetPoint
ProcDocAlertFrame.SetPoint = function() error("temporary restore failure") end
addon.db.centerProcDocOnMainhand = false
adapter:Refresh()
assert(adapter.status == "release-pending", "failed release discarded its restoration state")
ProcDocAlertFrame.SetPoint = nativeSetPoint
adapter:Refresh()
assert(point[4] == 0 and point[5] == 0, "failed release could not retry")
-- Forever 70862 rounds 785.714436848958 to 785.714477539063 in GetPoint.
-- That native round trip must not be mistaken for another mover taking over.
nativeRounding = true
metrics.gameLeft, metrics.gameRight = 0, 5571.428873697916
addon.db.centerProcDocOnMainhand = true
adapter:Refresh()
local roundedWrites = writes
adapter:Refresh()
assert(adapter.status == "active" and writes == roundedWrites, "native coordinate rounding lost ownership or rewrote the anchor")
addon.db.centerProcDocOnMainhand = false
adapter:Refresh()
assert(point[4] == 0 and point[5] == 0, "native coordinate rounding prevented release")
addon.db.centerProcDocOnMainhand = true
adapter:Refresh()
point[4] = point[4] + 0.01
local externalPoint = point[4]
adapter:Refresh()
assert(adapter.status == "external-anchor", "a meaningful external adjustment was ignored")
addon.db.centerProcDocOnMainhand = false
adapter:Refresh()
assert(point[4] == externalPoint, "release overwrote external placement after rounded centering")
addon.db.centerProcDocOnMainhand = true
ProcDocAlertFrame.IsForbidden = function() return true end
ProcDocAlertFrame.GetParent = function() error("forbidden frame inspected") end
local guardedWrites = writes
adapter:Refresh()
assert(writes == guardedWrites, "forbidden ProcDoc root was moved")
ProcDocAlertFrame.IsForbidden = nil
ProcDocAlertFrame.GetParent = function() return UIParent end
ProcDocAlertFrame.IsProtected = function() return true end
adapter:Refresh()
assert(writes == guardedWrites, "protected ProcDoc root was moved")
ProcDocAlertFrame.IsProtected = nil
addon.db.centerProcDocOnMainhand = "false"
adapter:Refresh()
assert(writes == guardedWrites, "malformed opt-in value activated compatibility")

-- The bridge contract: registered without a Forever client before any
-- ProcDoc event, the opt-in stored under its old key, the alerts checkbox,
-- a layout-only refresh, its own ADDON_LOADED refresh and the diagnostics tail.
local ids = Bridges:List()
assert(#ids == 1 and ids[1] == "ProcDoc" and Bridges:Get("ProcDoc") ~= nil,
    "the bridge must register as ProcDoc on every client")
addon.db.centerProcDocOnMainhand = nil
assert(addon.API.GetBridgeSetting("ProcDoc", "centerProcDocOnMainhand") == false
    and Bridges:GetSettingDefaults().centerProcDocOnMainhand == false,
    "the opt-in must default to false under its stored key")
addon.db.centerProcDocOnMainhand = true
assert(addon.API.GetBridgeSetting("ProcDoc", "centerProcDocOnMainhand") == true,
    "a value saved under centerProcDocOnMainhand must be read back through the bridge setting")
addon.db.centerProcDocOnMainhand = false
addon.L = {PROCDOC_MAINHAND = "Center", PROCDOC_MAINHAND_DESC = "Center description"}
assert(#Bridges:GetSettingsContributions("map") == 0, "the bridge must contribute to the alerts card only")
local contributions = Bridges:GetSettingsContributions("alerts")
local check = contributions[1]
assert(#contributions == 1 and check.id == "procDocCenter" and check.kind == "check" and check.addon == "ProcDoc"
    and check.text == "Center" and check.tooltip == "Center description" and check.help == "Center description"
    and check.width == 600 and check.height == 32 and check.get() == false,
    "the alerts checkbox must keep its text, tooltip, help and size")
check.set(true)
assert(addon.db.centerProcDocOnMainhand == true and check.get() == true and adapter.status == "active",
    "the checkbox must store under the old key and refresh the adapter")
check.set(false)
assert(addon.db.centerProcDocOnMainhand == false and adapter.status == "inactive",
    "clearing the checkbox must release at once")
addon.db.centerProcDocOnMainhand = true
Bridges:Refresh("tick"); Bridges:Refresh("map"); Bridges:Refresh("persistence")
assert(adapter.status == "inactive", "only the layout refresh may reach the adapter")
Bridges:Refresh("layout")
assert(adapter.status == "active", "the layout refresh must run the adapter")
addon.db.centerProcDocOnMainhand = false
event(nil, "ADDON_LOADED", "OtherAddon")
assert(adapter.status == "active", "another addon's ADDON_LOADED must not refresh")
event(nil, "ADDON_LOADED", "ProcDoc")
assert(adapter.status == "inactive", "ProcDoc loading after Offhand must refresh the adapter")
local segments = Bridges:GetDiagnosticSegments("compat.tail")
assert(#segments == 1 and segments[1].label == "ProcDocCenter" and segments[1].value() == "inactive"
    and Bridges:GetDiagnostics() == nil, "the status must be a tail segment, not part of the bridges segment")
adapter.status = nil
assert(segments[1].value() == "inactive", "an adapter that never ran must report inactive")
assert(Bridges.errors.ProcDoc == nil, "the bridge must not raise through dispatch")
print("PASS: opt-in ProcDoc center, vendor updates, idempotence, release, legacy root and combat/external ownership through the bridge contract")
