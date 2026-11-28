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
local combatWriteAttempts, nativeLifecycleAttempts = 0, 0
local function frame()
    local value = { points = {}, shown = false, scale = 0.7, writes = 0 }
    function value:IsShown() return self.shown end
    function value:IsForbidden() return self.forbidden == true end
    function value:IsProtected() return self.protected == true end
    function value:GetParent() return UIParent end
    function value:IsUserPlaced() return self.userPlaced == true end
    function value:CanChangeProtectedState() return false end
    function value:IsAnchoringRestricted() return false end
    function value:IsAnchoringSecret() return false end
    function value:GetNumPoints() return #self.points end
    function value:GetPoint(index)
        if self.points[index] then return unpack(self.points[index]) end
    end
    function value:GetEffectiveScale() return self.scale end
    function value:ClearAllPoints()
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
        assert(not combat, "addon must defer popup placement in combat")
        self.points = {}
        self.writes = self.writes + 1
    end
    function value:SetPoint(...)
        if combat then combatWriteAttempts = combatWriteAttempts + 1 end
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
StaticPopup1, StaticPopup2 = frame(), frame()
StaticPopup_SetUpPosition = function(dialog)
    dialog.points = {{"TOP", UIParent, "TOP", 0, -135}}
    return "native-position"
end
StaticPopupSpecial_Show = function(dialog)
    StaticPopup_SetUpPosition(dialog)
    dialog.shown = true
    return "native-show"
end
StaticPopup_FindVisible = function(which)
    for _, popup in ipairs({StaticPopup1, StaticPopup2}) do
        if popup.which == which and popup.shown then return popup end
    end
end
StaticPopup_Show = function(which)
    StaticPopup1.which = which
    StaticPopup_SetUpPosition(StaticPopup1)
    StaticPopup1.shown = true
    return StaticPopup1
end
StaticPopupSpecial_Hide = function(dialog) dialog.shown = false end
StaticPopup_Hide = function() StaticPopup1.shown = false end
ShowUIPanel = function(dialog)
    dialog.points = {{"TOP", UIParent, "TOP", 0, -16}}
    dialog.shown = true
    return "native-panel"
end
HideUIPanel = function(dialog) dialog.shown = false end
UpdateUIPanelPositions = function() end
hooksecurefunc = function(name, callback)
    local native = _G[name]
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

local function assertTranslated(dialog, message)
    local point = dialog.points[1]
    assert(#dialog.points == 1 and point[1] == "TOP" and point[2] == UIParent and point[3] == "BOTTOMLEFT"
        and point[4] == 2925 and point[5] == 962, message)
end
local function assertNative(dialog, message)
    local point = dialog.points[1]
    assert(#dialog.points == 1 and point[1] == "TOP" and point[2] == UIParent and point[3] == "TOP"
        and point[4] == 0 and point[5] == -135, message)
end

-- Every scanned special popup is a stack root that moves to Mainhand and back.
local names = addon.HUDTransientPolicy.GetForeverSpecialPopupNames()
for index = 7, #names do
    local name = names[index]
    local dialog = frame()
    _G[name] = dialog
    StaticPopupSpecial_Show(dialog)
    assertNative(dialog, name .. " must wait for the native show transaction")
    flush()
    assertTranslated(dialog, name .. " must move its stack root to Mainhand")
    local writes = dialog.writes
    hud:PositionPremadeGroupDialogs()
    assert(dialog.writes == writes, name .. " stable placement must be a no-op")
    StaticPopupSpecial_Hide(dialog)
    flush()
    assertNative(dialog, name .. " must restore the native anchor when hidden")
end

-- A visible child keeps a hidden scanned root in place until the chain ends.
StaticPopupSpecial_Show(LFGInvitePopup)
flush()
assertTranslated(LFGInvitePopup, "the invite root must move to Mainhand")
StaticPopup1.points = {{"TOP", LFGInvitePopup, "BOTTOM", 0, 0}}
StaticPopup1.shown = true
StaticPopupSpecial_Hide(LFGInvitePopup)
flush()
assertTranslated(LFGInvitePopup, "a hidden root must stay while a visible child depends on it")
assert(StaticPopup1.points[1][2] == LFGInvitePopup, "the native child link must survive")
StaticPopup_Hide()
flush()
assertNative(LFGInvitePopup, "the root must be restored once the chain is hidden")

-- Frames outside the list keep Blizzard's anchor.
SomeAddonDialog = frame()
StaticPopupSpecial_Show(SomeAddonDialog)
flush()
assertNative(SomeAddonDialog, "an unlisted popup must keep its native anchor")
assert(SomeAddonDialog.writes == 0, "an unlisted popup must never be written")
StaticPopupSpecial_Hide(SomeAddonDialog)
flush()

-- Restricted, user-placed, and externally offset roots retain ownership.
local writes = AddFriendFrame.writes
for _, field in ipairs({ "protected", "forbidden", "userPlaced" }) do
    AddFriendFrame[field] = true
    StaticPopupSpecial_Show(AddFriendFrame)
    flush()
    assertNative(AddFriendFrame, field .. " AddFriendFrame must keep its native anchor")
    assert(AddFriendFrame.writes == writes, field .. " AddFriendFrame must never be written")
    StaticPopupSpecial_Hide(AddFriendFrame)
    flush()
    AddFriendFrame[field] = nil
end
StaticPopupSpecial_Show(AddFriendFrame)
AddFriendFrame.points = {{"TOP", UIParent, "TOP", 40, -135}}
flush()
assert(AddFriendFrame.points[1][3] == "TOP" and AddFriendFrame.points[1][4] == 40
    and AddFriendFrame.writes == writes, "an offset native anchor retains external ownership")
StaticPopupSpecial_Hide(AddFriendFrame)
flush()

-- Combat defers placement to the shared post-combat retry.
combat = true
StaticPopupSpecial_Show(PVPReadyDialog)
flush()
assertNative(PVPReadyDialog, "combat must retain the native anchor")
assert(combatWriteAttempts == 0 and #combatQueue == 1, "combat placement must defer once without writing")
leaveCombat()
assertTranslated(PVPReadyDialog, "the popup must move to Mainhand after combat")
StaticPopupSpecial_Hide(PVPReadyDialog)
flush()
assertNative(PVPReadyDialog, "the popup must be restored after combat placement")

assert(combatWriteAttempts == 0 and nativeLifecycleAttempts == 0,
    "no addon path may write combat anchors, install native scripts, or change native visibility")
print("PASS: Forever scanned special popups translate, restore, keep native links, ownership, and combat deferral")
