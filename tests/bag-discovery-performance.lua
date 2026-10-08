-- Addon-bag discovery must stay constant-time when Baganator is absent.

local addon = {
    db = {
        enabled = true,
        persistentWorkspacePanels = true,
        savedWorkspacePositions = {},
        baganatorWorkspacePanels = {},
    },
    Canvas = {},
}

local nativePairs, globalScans = pairs, 0
pairs = function(value)
    if value == _G then globalScans = globalScans + 1 end
    return nativePairs(value)
end

C_AddOns = { IsAddOnLoaded = function() return false end }
InCombatLockdown = function() return false end
UIParent = {}

local onEvent, tick
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, _, callback) onEvent = callback end,
    }
end
C_Timer = {
    After = function(_, callback) callback() end,
    NewTicker = function(_, callback) tick = callback; return {} end,
}

assert(loadfile("Core/BagPersistence.lua"))("Offhand", addon)
onEvent(nil, "PLAYER_LOGIN")
for _ = 1, 30 do tick() end
assert(globalScans == 0,
    "BagPersistence must not scan globals at login or on ticks without Baganator")

local eui = { scripts = {} }
function eui:GetName() return "EUI_MainBagFrame" end
function eui:HookScript(script, callback) self.scripts[script] = callback end
EUI_MainBagFrame = eui
onEvent(nil, "ADDON_LOADED", "EllesmereUI")
assert(addon.BagPersistence.frames.EUI_MainBagFrame == eui,
    "stable EllesmereUI root discovery must use direct lookup")
assert(globalScans == 0,
    "direct EllesmereUI discovery must not scan globals")

print("PASS: addon bag discovery performs no global scans without Baganator")
