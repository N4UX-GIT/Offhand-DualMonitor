local combat, scaleWrites, scale = false, 0, 1
InCombatLockdown = function() return combat end
UIParent = {GetWidth = function() return 1800 end, GetHeight = function() return 1200 end,
    GetEffectiveScale = function() return 1 end}
local metrics = {isSpanned = true, hudScale = 1, gameLeft = 800, gameRight = 1800,
    gameBottom = 0, gameTop = 700, workspaceLeft = 0, workspaceRight = 800,
    workspaceBottom = 0, workspaceTop = 1200}
local addon = {modules = {}, isForever = true, db = {enabled = true, seamRedirect = true},
    Viewport = {GetMetrics = function() return metrics end}}
StaticPopupDialogs, SlashCmdList = {}, {}
GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
local controllers = {}
CreateFrame = function(_, name)
    local frame = {name = name, events = {}}
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, callback) self[event] = callback end
    controllers[#controllers + 1] = frame
    return frame
end
hooksecurefunc = function() end
assert(loadfile("Core/Init.lua"))("Offhand", addon)
local owner = {GetEffectiveScale = function() return 1 end,
    GetLeft = function() return 1100 end, GetRight = function() return 1150 end,
    GetTop = function() return 500 end, GetBottom = function() return 450 end,
    IsShown = function() return true end, IsObjectType = function() return false end,
    ClearAllPoints = function() error("owner anchor changed") end, SetPoint = function() error("owner anchor changed") end}
local height, shown, clamped, insets, scripts = 600, true, false, {0,0,0,0}, {}
GameTooltip = {
    GetParent = function() return UIParent end,
    GetScale = function() return scale end, GetEffectiveScale = function() return scale end,
    SetScale = function(_, value)
        assert(not combat, "tooltip scale changed in combat")
        scaleWrites, scale = scaleWrites + 1, value
        if scripts.OnSizeChanged then scripts.OnSizeChanged(GameTooltip) end
    end,
    GetOwner = function() return owner end, IsShown = function() return shown end,
    GetLeft = function() return 1200 / scale end, GetRight = function() return 1200 / scale + 300 end,
    GetTop = function() return 1000 / scale end, GetBottom = function() return 1000 / scale - height end,
    GetClampRectInsets = function() return unpack(insets) end,
    SetClampRectInsets = function(_, ...) assert(not combat); insets = {...} end,
    IsClampedToScreen = function() return clamped end,
    SetClampedToScreen = function(_, value) clamped = value end,
    HookScript = function(_, event, callback)
        local previous = scripts[event]
        scripts[event] = function(...)
            if previous then previous(...) end
            callback(...)
        end
    end,
    ClearAllPoints = function() error("native tooltip anchor changed") end,
    SetPoint = function() error("native tooltip anchor changed") end,
}
assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
addon.PopupBounds:ObserveTooltip(GameTooltip)
-- Include Init's actual normalization callbacks. Native SetScale can invoke
-- OnSizeChanged before the fitting call has stored its final ownership record.
for _, frame in ipairs(controllers) do
    if not frame.name and frame.events.PLAYER_LOGIN then frame.OnEvent(frame, "PLAYER_LOGIN") end
end
scripts.OnShow(GameTooltip)
assert(clamped and insets[1] == -812 and insets[3] == 512,
    "loot/item owner on Mainhand retained the full-span tooltip bounds")
assert(scaleWrites == 0, "fitting tooltip was scaled unnecessarily")
height = 1000
scripts.OnSizeChanged(GameTooltip)
assert(math.abs(scale - 0.676) < 0.00001 and scaleWrites == 1,
    "oversized native item tooltip did not fit the physical Mainhand height")
scripts.OnSizeChanged(GameTooltip)
assert(scaleWrites == 1, "unchanged tooltip fitting churned or recursed")
height = 300
scripts.OnSizeChanged(GameTooltip)
assert(scale == 1 and scaleWrites == 2, "shorter item retained the prior item's reduced scale")
height = 1000
scripts.OnSizeChanged(GameTooltip)
shown = false
scripts.OnHide(GameTooltip)
assert(scale == 1 and not clamped and insets[3] == 0,
    "hide did not restore the native scale and clamp")
shown = true
scripts.OnShow(GameTooltip)
scale = 0.9 -- a different addon takes ownership
scripts.OnSizeChanged(GameTooltip)
local externalWrites = scaleWrites
scripts.OnSizeChanged(GameTooltip)
shown = false
scripts.OnHide(GameTooltip)
assert(scale == 0.9 and scaleWrites == externalWrites, "fitting overwrote another scale owner")
shown, scale = true, 1
TipTac = {}
scripts.OnShow(GameTooltip)
assert(scaleWrites == externalWrites, "external tooltip addon was not respected")
TipTac = nil
combat = true
scripts.OnShow(GameTooltip)
assert(scaleWrites == externalWrites, "combat tooltip was mutated")
combat = false
addon.db.enabled = false
scripts.OnShow(GameTooltip)
assert(scaleWrites == externalWrites, "disabled Offhand fitted tooltips")
addon.db.enabled = true
scale = 1
scripts.OnShow(GameTooltip)
local queued
addon.RunOrQueueCombat = function(_, callback) queued = callback end
combat, shown = true, false
scripts.OnHide(GameTooltip)
assert(scale < 1 and queued, "combat hide failed to defer owned scale restoration")
combat = false
queued()
assert(scale == 1 and not clamped, "deferred hide did not restore the tooltip")
print("PASS: native tooltip fit survives Init normalization, restores scale and respects external ownership/combat")
