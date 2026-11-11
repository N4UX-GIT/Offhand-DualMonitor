local addon = {
    isForever = true, db = { enabled = true, seamRedirect = true },
    HUDCompatibility = { UsesForeverEditMode = function() return true end },
}
local combat = false
InCombatLockdown = function() return combat end
UIParent = { GetEffectiveScale = function() return 0.7 end }
local metrics = { isSpanned = true, gameLeft = 1950, gameRight = 3900,
    gameBottom = 0, gameTop = 1097, hudScale = 1 }
addon.Viewport = { GetMetrics = function() return metrics end }
local queued = {}
C_Timer = { After = function(_, callback) queued[#queued + 1] = callback end }
local function flush()
    local pending = queued
    queued = {}
    for _, callback in ipairs(pending) do callback() end
end
local function frame()
    local value = { points = {}, shown = false, scale = 0.7, writes = 0 }
    function value:IsShown() return self.shown end
    function value:IsForbidden() return self.forbidden end
    function value:IsProtected() return self.protected end
    function value:IsUserPlaced() return self.userPlaced end
    function value:GetNumPoints() return #self.points end
    function value:GetPoint(index) return unpack(self.points[index]) end
    function value:GetEffectiveScale() return self.scale end
    function value:ClearAllPoints()
        assert(not combat, "addon must defer combat placement")
        self.points = {}
        self.writes = self.writes + 1
    end
    function value:SetPoint(...) self.points[#self.points + 1] = {...} end
    function value:HookScript() error("native dialog scripts must remain untouched") end
    function value:Show() error("native visibility must remain untouched") end
    function value:Hide() error("native visibility must remain untouched") end
    return value
end
GuildInviteFrame, ChatConfigFrame, StaticPopup1 = frame(), frame(), frame()
StaticPopup_SetUpPosition = function(dialog)
    dialog.points = {{"TOP", UIParent, "TOP", 0, -135}}
    return "native-position"
end
StaticPopupSpecial_Show = function(dialog)
    StaticPopup_SetUpPosition(dialog)
    dialog.shown = true
    return "native-show"
end
StaticPopupSpecial_Hide = function(dialog) dialog.shown = false end
StaticPopup_Hide = function() StaticPopup1.shown = false end
ShowUIPanel = function(dialog)
    dialog.points = {{"TOP", UIParent, "TOP", 0, -16}}
    dialog.shown = true
    return "native-panel"
end
HideUIPanel = function(dialog) dialog.shown = false end
local hookCount = 0
hooksecurefunc = function(name, callback)
    local native = _G[name]
    hookCount = hookCount + 1
    _G[name] = function(...)
        local result = native(...)
        callback(...)
        return result
    end
end
assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
assert(loadfile("Core/HUDTransientFrames.lua"))("Offhand", addon)
local function points(target, ...)
    local desired = {...}
    local same = #desired == #target.points
    for index, point in ipairs(desired) do
        for field = 1, 5 do
            if not target.points[index] or target.points[index][field] ~= point[field] then same = false end
        end
    end
    if same then return end
    target:ClearAllPoints()
    for _, point in ipairs(desired) do target:SetPoint(unpack(point)) end
end
local hud = {}
addon.HUDTransientFrames.Install(hud, {
    Points = points, Prepare = function() end,
    Anchor = function() error("native popup stack must retain its links") end,
})
hud:HookMainhandTransientFrames()
hud:HookMainhandTransientFrames()
assert(hookCount == 6, "native transaction hooks must be idempotent")
assert(StaticPopupSpecial_Show(GuildInviteFrame) == "native-show")
assert(GuildInviteFrame.points[1][3] == "TOP", "wait for native focus handling")
flush()
assert(GuildInviteFrame.points[1][4] == 2925 and GuildInviteFrame.points[1][5] == 962)
assert(ShowUIPanel(ChatConfigFrame) == "native-panel")
flush()
assert(ChatConfigFrame.points[1][4] == 2925 and ChatConfigFrame.points[1][5] == 1081)
local writes = GuildInviteFrame.writes + ChatConfigFrame.writes
hud:PositionMainhandTransientFrames()
assert(writes == GuildInviteFrame.writes + ChatConfigFrame.writes, "stable placement must be a no-op")

-- Native shared-stack links survive either close order, including a hidden root.
StaticPopup1.points = {{"TOP", GuildInviteFrame, "BOTTOM", 0, 0}}
StaticPopup1.shown = true
StaticPopupSpecial_Hide(GuildInviteFrame)
flush()
assert(GuildInviteFrame.points[1][3] == "BOTTOMLEFT")
assert(StaticPopup1.points[1][2] == GuildInviteFrame)
StaticPopup_Hide()
flush()
assert(GuildInviteFrame.points[1][3] == "TOP")
assert(GuildInviteFrame.points[1][5] == -135)
HideUIPanel(ChatConfigFrame)
flush()
assert(ChatConfigFrame.points[1][3] == "TOP")

ShowUIPanel(ChatConfigFrame)
combat = true
flush()
assert(ChatConfigFrame.points[1][3] == "TOP")
combat = false
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][3] == "BOTTOMLEFT")
addon.db.seamRedirect = false
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][3] == "TOP")
addon.db.seamRedirect = true
ChatConfigFrame.userPlaced = true
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][3] == "TOP")
ChatConfigFrame.userPlaced = false
ChatConfigFrame.points = {{"TOP", UIParent, "TOP", 40, -20}}
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][4] == 40, "offset UIParent anchors retain external ownership")
ChatConfigFrame.points = {{"TOP", {}, "TOP", 40, 0}}
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][4] == 40, "external anchors retain ownership")
ChatConfigFrame.points = {{"TOP", UIParent, "TOP", 0, -16}}
ChatConfigFrame.protected = true
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][3] == "TOP")
ChatConfigFrame.protected = false
metrics.isSpanned = false
hud:PositionPremadeGroupDialogs()
assert(ChatConfigFrame.points[1][3] == "TOP")
print("PASS: Forever guild invite and Chat Settings native placement, stack, restoration and ownership")
