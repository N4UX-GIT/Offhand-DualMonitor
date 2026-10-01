-- Retail rebuilds its bag-frame enumerators when the player converts between
-- combined and individual bags. Offhand must leave both native close entry
-- points untouched so Blizzard can fully close the old presentation first.

InCombatLockdown = function() return false end

local globalCloseCalls = 0
local nativeGlobalClose = function()
    globalCloseCalls = globalCloseCalls + 1
    return "global-native"
end
CloseAllBags = nativeGlobalClose

local containerCloseCalls = 0
local nativeContainerClose = function()
    containerCloseCalls = containerCloseCalls + 1
    return "container-native"
end
C_Container = { CloseAllBags = nativeContainerClose }

local addon = {
    isRetail = true,
    isForever = false,
    db = {
        enabled = true,
        persistentWorkspacePanels = true,
        savedWorkspacePositions = {
            ContainerFrame1 = { x = 100, y = 500 },
        },
    },
}

assert(loadfile("Core/Canvas.lua"))("Offhand", addon)

assert(CloseAllBags == nativeGlobalClose,
    "Retail global CloseAllBags must remain Blizzard-owned during bag-mode conversion")
assert(C_Container.CloseAllBags == nativeContainerClose,
    "Retail C_Container.CloseAllBags must remain Blizzard-owned during bag-mode conversion")
assert(CloseAllBags() == "global-native" and globalCloseCalls == 1,
    "Retail global close must retain its native behavior")
assert(C_Container.CloseAllBags() == "container-native" and containerCloseCalls == 1,
    "Retail container close must retain its native behavior")

-- A Retail feature panel can load on demand during its opening click. The
-- addon rescan may discover draggable frames, but it must not globally restore
-- unrelated saved visibility (especially WorldMapFrame).
local timers = {}
C_Timer = { After = function(_, callback) table.insert(timers, callback) end }
local rescans, restores = 0, 0
addon.Canvas.EnableFreeDragging = function() rescans = rescans + 1 end
addon.Canvas.UpdateMapMovementBehavior = function() end
addon.Canvas.UpdatePersistenceBehavior = function() end
addon.Canvas.ConfigureWorldMap = function() end
addon.Canvas.RestorePersistentFrames = function() restores = restores + 1 end

-- InitializeCanvas defines the production rescan method after CreateFrames.
addon.Canvas.CreateFrames = function() end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function() end }
end
addon:InitializeCanvas()
addon.Canvas:RefreshAfterAddonLoaded()
for _, callback in ipairs(timers) do callback() end
assert(rescans >= 2 and restores == 0,
    "ADDON_LOADED rescans must not reopen unrelated persistent workspace panels")

print("PASS: Retail bag conversion and load-on-demand panel visibility remain Blizzard-owned")
