local addon = {
    isForever = true, db = { enabled = true, seamRedirect = true },
    HUDCompatibility = { UsesForeverEditMode = function() return true end },
}
local combat = false
InCombatLockdown = function() return combat end
UIParent = {
    GetEffectiveScale = function() return 0.7 end,
    GetWidth = function() return 3000 end,
    GetHeight = function() return 1920 end,
}
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
local combatQueue = {}
addon.RunOrQueueCombat = function(_, callback)
    if combat then
        combatQueue[#combatQueue + 1] = callback
    else
        callback()
    end
end
local function leaveCombat()
    combat = false
    local pending = combatQueue
    combatQueue = {}
    for _, callback in ipairs(pending) do callback() end
    flush()
end
local combatWriteAttempts, shutdownWriteAttempts, nativeLifecycleAttempts = 0, 0, 0
local function frame()
    local value = { points = {}, shown = false, scale = 0.7, writes = 0 }
    function value:IsShown() return self.shown end
    function value:IsForbidden() return self.forbidden == true end
    function value:IsProtected() return self.protected == true end
    function value:GetParent() return UIParent end
    function value:IsUserPlaced() return self.userPlaced end
    function value:GetNumPoints() return #self.points end
    function value:GetPoint(index)
        if self.failReadback then
            self.failReadback = nil
            error("native point readback failed")
        end
        return unpack(self.points[index])
    end
    function value:GetEffectiveScale() return self.scale end
    function value:ClearAllPoints()
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
        if addon._loggingOut then shutdownWriteAttempts = shutdownWriteAttempts + 1 end
        assert(not combat, "addon must defer combat placement")
        assert(not addon._loggingOut, "addon must not position frames during shutdown")
        self.points = {}
        self.writes = self.writes + 1
    end
    function value:SetPoint(...)
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
        if addon._loggingOut then shutdownWriteAttempts = shutdownWriteAttempts + 1 end
        if select(3, ...) == "BOTTOMLEFT" then
            if self.rejectPlacement then
                self.rejectedPlacement = true
                return
            end
            self.failReadback = self.rejectReadback
        end
        self.points[#self.points + 1] = {...}
    end
    local function nativeLifecycleWrite()
        nativeLifecycleAttempts = nativeLifecycleAttempts + 1
        error("native dialog scripts and visibility must remain untouched")
    end
    value.HookScript, value.SetScript = nativeLifecycleWrite, nativeLifecycleWrite
    value.Show, value.Hide = nativeLifecycleWrite, nativeLifecycleWrite
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
local nextNativeTradePoint
local function nativeTradeAnchor()
    return {nextNativeTradePoint or {"TOPLEFT", UIParent, "TOPLEFT", 16, -104}}
end
local function nativeTradeReflow()
    if TradeFrame and TradeFrame.shown then TradeFrame.points = nativeTradeAnchor() end
end
ShowUIPanel = function(dialog)
    dialog.points = dialog == TradeFrame and nativeTradeAnchor() or {{"TOP", UIParent, "TOP", 0, -16}}
    dialog.shown = true
    if dialog ~= TradeFrame then nativeTradeReflow() end
    return "native-panel"
end
HideUIPanel = function(dialog)
    dialog.shown = false
    if dialog ~= TradeFrame then nativeTradeReflow() end
end
UpdateUIPanelPositions = nativeTradeReflow
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
assert(loadfile("Core/MenuPlacement.lua"))("Offhand", addon)
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
local firstHookCount = hookCount
hud:HookMainhandTransientFrames()
assert(hookCount == firstHookCount, "native transaction hooks must be idempotent")
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
assert(#combatQueue == 1, "native popup work should schedule one post-combat retry")
leaveCombat()
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

metrics.isSpanned = true
ChatConfigFrame.shown = false
for _, which in ipairs({"PARTY_INVITE", "QUEST_ACCEPT"}) do
    combat = true
    local popupWrites = StaticPopup1.writes
    StaticPopup1.which = which
    for _ = 1, 2 do
        assert(StaticPopupSpecial_Show(StaticPopup1) == "native-show")
        flush()
        assert(StaticPopup1.shown and StaticPopup1.points[1][3] == "TOP"
            and StaticPopup1.writes == popupWrites, which .. " must retain native placement in combat")
        assert(#combatQueue == 1, "popup reflows in a single combat must share the retry")
    end
    leaveCombat()
    assert(StaticPopup1.shown and StaticPopup1.points[1][3] == "BOTTOMLEFT"
        and StaticPopup1.writes == popupWrites + 1, which .. " settles after combat")
    StaticPopup_Hide()
    flush()
end

-- The portrait workspace on the right leaves a physical void above Mainhand.
metrics.gameLeft, metrics.gameRight, metrics.gameTop = 0, 1920, 1080
metrics.workspaceLeft, metrics.workspaceRight = 1920, 3000
metrics.workspaceBottom, metrics.workspaceTop = 0, 1920
metrics.workspaceRegions = {{ x = 1920, y = 0, width = 1080, height = 1920 }}
TradeFrame = frame()
function TradeFrame:GetLeft() return self.points[1][4] end
function TradeFrame:GetTop()
    return self.points[1][5] + (self.points[1][3] == "TOPLEFT" and UIParent:GetHeight() or 0)
end
function TradeFrame:GetWidth() return 340 end
function TradeFrame:GetHeight() return 470 end

local function assertStockTrade(message)
    local point, relative, relativePoint, x, y = TradeFrame:GetPoint(1)
    assert(TradeFrame:GetNumPoints() == 1 and point == "TOPLEFT" and relative == UIParent
        and relativePoint == "TOPLEFT" and x == 16 and y == -104, message)
end
local function assertRecoveredTrade(message)
    local point, relative, relativePoint, x, y = TradeFrame:GetPoint(1)
    assert(TradeFrame.shown and TradeFrame:GetNumPoints() == 1 and point == "TOPLEFT"
        and relative == UIParent and relativePoint == "BOTTOMLEFT" and x == 16 and y == 976, message)
end

assert(addon.HUDTransientPolicy.IsNativeDialogRoot(TradeFrame), "generic void rescue must yield to TradeFrame recovery")
assert(ShowUIPanel(TradeFrame) == "native-panel")
assertStockTrade("trade recovery must wait for the native panel transaction")
flush()
assertRecoveredTrade("a stock trade window in the void must recover to Mainhand with native offsets")
local tradeWrites = TradeFrame.writes
addon.MenuPlacement:Refresh()
assert(TradeFrame.writes == tradeWrites, "steady trade placement must not write its anchor again")

addon.Canvas = { CanManagePanelsFromAddon = function() return false end }
metrics.isSpanned = false
addon.MenuPlacement:Refresh()
assert(TradeFrame.writes == tradeWrites, "native Gamepad ownership must also prevent restoration writes")
metrics.isSpanned = true
addon.Canvas = nil

addon.db.enabled = false
addon.MenuPlacement:Refresh()
assertStockTrade("disabling Offhand must release its trade anchor")
addon.db.enabled = true
UpdateUIPanelPositions()
flush()
assertRecoveredTrade("a later native trade reflow must recover again")
metrics.isSpanned = false
addon.MenuPlacement:Refresh()
assertStockTrade("unspanning must release Offhand's trade anchor")
metrics.isSpanned = true

TradeFrame.points = nativeTradeAnchor()
tradeWrites = TradeFrame.writes
StaticPopupSpecial_Show(GuildInviteFrame)
flush()
assert(TradeFrame.writes == tradeWrites, "unrelated popup transactions must leave the trade anchor alone")
StaticPopupSpecial_Hide(GuildInviteFrame)
UpdateUIPanelPositions()
flush()
assertRecoveredTrade("a trade reflow following a popup in the same frame must still recover")

local otherPanel = frame()
-- Native panel delegation can reflow the trade without calling the global update hook.
ShowUIPanel(otherPanel)
assertStockTrade("showing another panel must exercise the native trade reflow")
flush()
assertRecoveredTrade("showing another panel must recover the trade after its native reflow")
HideUIPanel(otherPanel)
assertStockTrade("hiding another panel must exercise the native trade reflow")
flush()
assertRecoveredTrade("hiding another panel must recover the trade after its native reflow")

nextNativeTradePoint = {"TOPLEFT", UIParent, "TOPLEFT", 2000, -104}
tradeWrites = TradeFrame.writes
UpdateUIPanelPositions()
flush()
assert(TradeFrame.writes == tradeWrites and TradeFrame:GetLeft() == 2000,
    "a fully visible trade window on the workspace must keep its native anchor")
local customPoint = {"TOPLEFT", {}, "TOPLEFT", 16, -104}
nextNativeTradePoint = customPoint
UpdateUIPanelPositions()
flush()
assert(TradeFrame.writes == tradeWrites and TradeFrame.points[1] == customPoint,
    "trade recovery must yield to a custom anchor")
nextNativeTradePoint = nil
TradeFrame.userPlaced = true
UpdateUIPanelPositions()
flush()
assert(TradeFrame.writes == tradeWrites, "trade recovery must yield to a user-placed frame")
assertStockTrade("user-placed trade anchor should remain native")
TradeFrame.userPlaced = nil

TradeFrame.rejectPlacement = true
UpdateUIPanelPositions()
flush()
assert(TradeFrame.rejectedPlacement, "exercise a native trade write that was silently refused")
assertStockTrade("a silently refused SetPoint must restore the native trade anchor")
TradeFrame.rejectPlacement = nil
TradeFrame.rejectReadback = true
UpdateUIPanelPositions()
flush()
assertStockTrade("a failed placement readback must restore the native trade anchor")
TradeFrame.rejectReadback = nil

combat = true
tradeWrites = TradeFrame.writes
for _ = 1, 2 do
    UpdateUIPanelPositions()
    flush()
    assert(TradeFrame.writes == tradeWrites and #combatQueue == 1,
        "native trade reflows must defer once per combat without writing")
    assertStockTrade("combat must retain the native trade anchor")
end
StaticPopup1.which = "PARTY_INVITE"
StaticPopupSpecial_Show(StaticPopup1)
flush()
assert(#combatQueue == 1 and StaticPopup1.points[1][3] == "TOP",
    "popup and trade work must share the existing post-combat retry")
leaveCombat()
assertRecoveredTrade("a shown trade must recover after combat ends")
assert(StaticPopup1.points[1][3] == "BOTTOMLEFT", "the same retry must also recover the visible native popup")
StaticPopup_Hide()
HideUIPanel(TradeFrame)
flush()
assert(not TradeFrame.shown, "trade close remains owned by the native panel")
assertStockTrade("closing the trade window must release Offhand's anchor")

combat = true
ShowUIPanel(TradeFrame)
flush()
assert(#combatQueue == 1, "the trade reopen should schedule a fresh combat retry")
addon._loggingOut = true
tradeWrites = TradeFrame.writes
local popupWrites = StaticPopup1.writes
leaveCombat()
StaticPopupSpecial_Show(StaticPopup1)
UpdateUIPanelPositions()
flush()
assertStockTrade("shutdown must preserve the native trade anchor")
assert(TradeFrame.writes == tradeWrites and StaticPopup1.writes == popupWrites and shutdownWriteAttempts == 0,
    "queued and new native transactions must not write anchors during shutdown")
assert(combatWriteAttempts == 0 and nativeLifecycleAttempts == 0,
    "no addon path may write combat anchors, install native scripts, or change native visibility")
print("PASS: Forever native popup and trade placement, combat deferral, ownership, and rollback")
