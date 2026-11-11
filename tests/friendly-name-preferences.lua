-- Exercise legacy preference cleanup and the production logout callback.
local logout, current, unavailable, failWrite, writes = nil, 0, false, false, 0
StaticPopupDialogs, SlashCmdList = {}, {}
CreateFrame = function()
    local events = {}
    return {
        RegisterEvent = function(_, event) events[event] = true end,
        SetScript = function(_, script, callback)
            if script == "OnEvent" and events.PLAYER_LOGOUT and not events.PLAYER_LOGIN then logout = callback end
        end,
    }
end
GetBuildInfo = function() return "12.1.5", "70783", "", 120105 end
InCombatLockdown = function() return false end
WorldFrame = {ClearAllPoints = function() end, SetAllPoints = function() end}
GetCVar = function(name)
    if name == "UnitNameFriendlyPlayerName" and not unavailable then return tostring(current) end
end
SetCVar = function(name, value)
    assert(name == "UnitNameFriendlyPlayerName", "unexpected CVar write")
    if failWrite then error("simulated unavailable setter") end
    current, writes = tonumber(value), writes + 1
end
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
addon.db = {enabled = false, originalFriendlyPlayerName = 0}
current, unavailable = 1, true
addon.Viewport:ApplyGlobalScale()
assert(addon.db.originalFriendlyPlayerName == 0 and writes == 0, "unavailable preference lost its recovery marker")
unavailable, failWrite = false, true
addon.Viewport:ApplyGlobalScale()
assert(addon.db.originalFriendlyPlayerName == 0 and writes == 0, "failed restore lost its recovery marker")
failWrite = false
addon.Viewport:ApplyGlobalScale()
assert(current == 0 and writes == 1 and addon.db.originalFriendlyPlayerName == nil, "pending restore did not finish")
addon.db.originalFriendlyPlayerName = "bad"
addon.Viewport:ApplyGlobalScale()
assert(writes == 1 and addon.db.originalFriendlyPlayerName == nil, "malformed backup changed visibility")
-- Even if combat/unavailable APIs prevented migration, logout must not replay a
-- stale backup over a newer player choice. The next safe apply can clean it up.
addon.db.originalFriendlyPlayerName = 1
current = 0
logout()
assert(current == 0 and writes == 1, "logout overwrote the player's newer visibility choice")
print("PASS: legacy friendly names retry safely, reject malformed backups and preserve logout choices")
