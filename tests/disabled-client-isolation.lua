-- Shared-client regression: disabled Offhand profiles must not mutate Blizzard
-- tooltips or bag anchors. Run from the project root with Lua 5.1.
StaticPopupDialogs = {}
SlashCmdList = {}
WOW_PROJECT_ID = 1
WOW_PROJECT_CLASSIC = 2
WOW_PROJECT_MAINLINE = 1
GetBuildInfo = function() return "", "", "", 121500 end
InCombatLockdown = function() return false end

local frames = {}
CreateFrame = function(_, name)
    local frame = { name = name, registered = {} }
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:SetScript(script, handler) self[script] = handler end
    frames[#frames + 1] = frame
    return frame
end

local secureHooks = {}
hooksecurefunc = function(target, method, hook)
    if type(target) == "string" then
        secureHooks[target] = method
    else
        secureHooks[target] = secureHooks[target] or {}
        secureHooks[target][method] = hook
    end
end

local ignoreWrites, scaleWrites, bagWrites = 0, 0, 0
local tooltip = {
    GetObjectType = function() return "GameTooltip" end,
    HookScript = function(self, script, handler) self[script] = handler end,
    SetOwner = function() end,
    SetIgnoreParentScale = function(self, value)
        ignoreWrites = ignoreWrites + 1
        self.ignoreParentScale = value
        local hooks = secureHooks[self]
        if hooks and hooks.SetIgnoreParentScale then hooks.SetIgnoreParentScale(self, value) end
    end,
    IsIgnoringParentScale = function(self) return self.ignoreParentScale == true end,
    GetScale = function() return 2 end,
    SetScale = function() scaleWrites = scaleWrites + 1 end,
    GetParent = function() return { GetEffectiveScale = function() return 1 end } end,
}
GameTooltip = tooltip
ContainerFrame1 = {
    ClearAllPoints = function() bagWrites = bagWrites + 1 end,
    SetPoint = function() bagWrites = bagWrites + 1 end,
    SetUserPlaced = function() bagWrites = bagWrites + 1 end,
}
UIParent = { GetEffectiveScale = function() return 1 end }
WorldFrame = { ClearAllPoints = function() end, SetAllPoints = function() end }

local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
addon.db = { enabled = false }
addon.Viewport = {
    GetMetrics = function() return { isSpanned = true } end,
    Reset = function() end,
}

local tooltipFrame, logoutFrame
for _, frame in ipairs(frames) do
    if frame.name == nil and frame.registered.PLAYER_LOGIN then tooltipFrame = frame end
    if frame.name == nil and frame.registered.PLAYER_LOGOUT then logoutFrame = frame end
end
assert(tooltipFrame and logoutFrame, "expected isolated tooltip and logout handlers")

tooltipFrame.OnEvent(tooltipFrame, "PLAYER_LOGIN")
assert(ignoreWrites == 0, "disabled Offhand changed tooltip parent-scale behavior at login")
tooltip.ignoreParentScale = true
tooltip.OnShow(tooltip)
assert(scaleWrites == 0 and tooltip.ignoreParentScale == true,
    "disabled Offhand changed tooltip scale on show")
secureHooks[tooltip].SetIgnoreParentScale(tooltip, true)
assert(ignoreWrites == 0, "disabled Offhand fought another addon's tooltip setting")

logoutFrame.OnEvent(logoutFrame, "PLAYER_LOGOUT")
assert(bagWrites == 0, "disabled Offhand rewrote Blizzard bag anchors at logout")

addon.db.enabled = true
tooltip.ignoreParentScale = true
tooltip.OnShow(tooltip)
assert(scaleWrites == 1 and tooltip.ignoreParentScale == false,
    "enabled spanned Offhand did not normalize tooltip scale")
logoutFrame.OnEvent(logoutFrame, "PLAYER_LOGOUT")
assert(bagWrites == 3, "enabled Offhand did not perform its logout bag cleanup")

addon.Viewport.GetMetrics = function() return { isSpanned = false } end
tooltip.ignoreParentScale = true
tooltip.OnShow(tooltip)
assert(scaleWrites == 1 and tooltip.ignoreParentScale == true,
    "single-screen recovery changed tooltip scaling")

print("PASS: disabled and single-screen clients leave tooltip and bag layout ownership untouched")
