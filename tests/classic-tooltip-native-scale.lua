StaticPopupDialogs, SlashCmdList = {}, {}
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 5, 1, 2
GetBuildInfo = function() return "2.5.6", "70577", "", 20506 end
InCombatLockdown = function() return false end
local frames = {}
CreateFrame = function(_, name)
    local frame = { name = name, events = {} }
    frame.RegisterEvent = function(self, event) self.events[event] = true end
    frame.SetScript = function(self, event, callback) self[event] = callback end
    frames[#frames + 1] = frame
    return frame
end
local observed = 0
GameTooltip = {
    SetOwner = function() error("native owner must remain untouched") end,
    SetScale = function() error("native scale must remain untouched") end,
    SetIgnoreParentScale = function() error("native parent-scale policy must remain untouched") end,
    HookScript = function() error("Classic tooltip scaling observers must not be installed") end,
}
SharedTooltip_SetBackdropStyle = function() end
hooksecurefunc = function() error("Classic tooltip scaling hooks must not be installed") end
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
addon.db = { enabled = true, seamRedirect = true }
addon.Viewport = { GetMetrics = function() return { isSpanned = true } end }
addon.PopupBounds = { ObserveTooltip = function(_, frame) assert(frame == GameTooltip); observed = observed + 1 end }
for _, frame in ipairs(frames) do
    if not frame.name and frame.events.PLAYER_LOGIN then frame.OnEvent(frame, "PLAYER_LOGIN") end
end
assert(observed == 1, "read-only tooltip evidence must remain available")
print("PASS: Anniversary tooltip ownership and scaling remain native while diagnostics stay available")
