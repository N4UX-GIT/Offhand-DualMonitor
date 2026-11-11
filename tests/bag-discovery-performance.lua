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
addon.BagPersistence.paused = false -- simulate the settled, resumed gameplay session
local oldSnapshot = addon.db.baganatorWorkspacePanels
local replacements = 0
collectgarbage('collect')
collectgarbage('stop')
local memoryStart, timeStart = collectgarbage('count'), os.clock()
for _ = 1, 4500 do
    tick()
    if addon.db.baganatorWorkspacePanels ~= oldSnapshot then
        replacements = replacements + 1
        oldSnapshot = addon.db.baganatorWorkspacePanels
    end
end
local allocated = collectgarbage('count') - memoryStart
collectgarbage('restart')
print(string.format('Synthetic 4500 idle bag polls: %.3f ms, %.1f KiB allocated, %d snapshot replacements',
    (os.clock()-timeStart)*1000,allocated,replacements))
assert(replacements == 0, 'idle bag polling must retain an already-empty snapshot')
assert(globalScans == 0,
    "BagPersistence must not scan globals at login or on ticks without Baganator")
addon.db.baganatorWorkspacePanels = {oldBag={x=1,y=2}}
tick()
assert(next(addon.db.baganatorWorkspacePanels)==nil,'closing the last bag must clear old open intent')
oldSnapshot=addon.db.baganatorWorkspacePanels
tick()
assert(addon.db.baganatorWorkspacePanels==oldSnapshot,'already-cleared intent should remain stable')

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
