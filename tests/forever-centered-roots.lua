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
local combatQueue = {}
addon.RunOrQueueCombat = function(_, callback)
    if combat then
        combatQueue[#combatQueue + 1] = callback
    else
        callback()
    end
end
local nativeLifecycleAttempts = 0
local function frame(...)
    local value = { points = {}, shown = false, scale = 0.7, writes = 0 }
    function value:IsShown() return self.shown end
    function value:IsForbidden() return self.forbidden == true end
    function value:IsProtected() return self.protected == true end
    function value:GetParent() return UIParent end
    function value:IsUserPlaced() return self.userPlaced == true end
    function value:GetNumPoints() return #self.points end
    function value:GetPoint(index)
        local p = self.points[index]
        if p then return unpack(p, 1, 5) end
    end
    function value:GetEffectiveScale() return self.scale end
    function value:ClearAllPoints()
        assert(not combat, "addon must not move centred roots in combat")
        assert(not addon._loggingOut, "addon must not position frames during shutdown")
        self.points = {}
        self.writes = self.writes + 1
    end
    function value:SetPoint(point, relative, relativePoint, x, y)
        assert(not combat, "addon must not move centred roots in combat")
        if relativePoint == "BOTTOMLEFT" and self.rejectPlacement then return end
        self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
    end
    local function nativeLifecycleWrite()
        nativeLifecycleAttempts = nativeLifecycleAttempts + 1
        error("native window scripts and visibility must remain untouched")
    end
    value.HookScript, value.SetScript = nativeLifecycleWrite, nativeLifecycleWrite
    value.Show, value.Hide = nativeLifecycleWrite, nativeLifecycleWrite
    value.SetParent, value.SetClampedToScreen = nativeLifecycleWrite, nativeLifecycleWrite
    for _, p in ipairs({...}) do value.points[#value.points + 1] = { p[1], p[2], p[3], p[4], p[5] } end
    return value
end

-- Native popup and panel entry points that Install hooks.
GuildInviteFrame, ChatConfigFrame, StaticPopup1, StaticPopup2 = frame(), frame(), frame(), frame()
StaticPopup_SetUpPosition = function(dialog)
    dialog.points = {{"TOP", UIParent, "TOP", 0, -135}}
end
StaticPopupSpecial_Show = function(dialog) StaticPopup_SetUpPosition(dialog) end
StaticPopupSpecial_Hide = function() end
StaticPopup_FindVisible = function() end
StaticPopup_Show = function() end
StaticPopup_Hide = function() end
ShowUIPanel = function() end
HideUIPanel = function() end
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
local function points(target, ...)
    target:ClearAllPoints()
    for _, point in ipairs({...}) do target:SetPoint(unpack(point, 1, 5)) end
end
local hud = {}
addon.HUDTransientFrames.Install(hud, {
    Points = points, Prepare = function() end,
    Anchor = function() error("centred roots must not use generic anchoring") end,
})

local function isAt(target, point, relative, relativePoint, x, y, message)
    assert(#target.points == 1, message .. ": expected one point")
    local p = target.points[1]
    assert(p[1] == point and p[2] == relative and p[3] == relativePoint
        and math.abs(p[4] - x) < 0.001 and math.abs(p[5] - y) < 0.001,
        message .. ": got " .. tostring(p[1]) .. " " .. tostring(p[3]) .. " "
        .. tostring(p[4]) .. " " .. tostring(p[5]))
end

-- 1-3: each anchor family moves onto the centre of the game display.
ReportFrame = frame({"TOP", UIParent, "TOP", 0, -70})
TutorialSingleKey_Frame = frame({"BOTTOM", UIParent, "BOTTOM", 0, 232})
QuickKeybindFrame = frame({"CENTER", UIParent, "CENTER", 0, 150})
BasicMessageDialog = frame({"CENTER", nil, "CENTER", 0, 0})
-- 4: a frame with its own scale converts UIParent units into its own.
TutorialFrame = frame({"TOP", UIParent, "TOP", 0, -70})
TutorialFrame.scale = 1.4
hud:PositionForeverCenteredRoots()
isAt(ReportFrame, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "report frame")
isAt(TutorialSingleKey_Frame, "BOTTOM", UIParent, "BOTTOMLEFT", 2925, 232, "single key tutorial")
isAt(QuickKeybindFrame, "CENTER", UIParent, "BOTTOMLEFT", 2925, 698.5, "quick keybind")
isAt(BasicMessageDialog, "CENTER", UIParent, "BOTTOMLEFT", 2925, 548.5, "nil-relative dialog")
isAt(TutorialFrame, "TOP", UIParent, "BOTTOMLEFT", 1462.5, 478.5, "scaled tutorial")

-- 5: a stable placement is a no-op.
local translated = { ReportFrame, TutorialSingleKey_Frame, QuickKeybindFrame, BasicMessageDialog, TutorialFrame }
local function totalWrites(list)
    local total = 0
    for _, target in ipairs(list) do total = total + target.writes end
    return total
end
local before = totalWrites(translated)
hud:PositionForeverCenteredRoots()
assert(totalWrites(translated) == before, "stable placement must be a no-op")

-- 6: Blizzard re-anchors a translated frame; the next pass uses the new offset.
TutorialMainFrame_Frame = frame({"TOP", UIParent, "TOP", 0, -70})
hud:PositionForeverCenteredRoots()
isAt(TutorialMainFrame_Frame, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "main tutorial")
TutorialMainFrame_Frame.points = {{"CENTER", UIParent, "CENTER", 0, 160}}
hud:PositionForeverCenteredRoots()
isAt(TutorialMainFrame_Frame, "CENTER", UIParent, "BOTTOMLEFT", 2925, 708.5, "re-anchored tutorial")

-- 7: turning the feature off restores the exact native point, then on again translates.
local function checkRestored()
    isAt(ReportFrame, "TOP", UIParent, "TOP", 0, -70, "restored report frame")
    isAt(TutorialSingleKey_Frame, "BOTTOM", UIParent, "BOTTOM", 0, 232, "restored single key tutorial")
    isAt(QuickKeybindFrame, "CENTER", UIParent, "CENTER", 0, 150, "restored quick keybind")
    isAt(BasicMessageDialog, "CENTER", nil, "CENTER", 0, 0, "restored nil-relative dialog")
    isAt(TutorialFrame, "TOP", UIParent, "TOP", 0, -70, "restored scaled tutorial")
    isAt(TutorialMainFrame_Frame, "CENTER", UIParent, "CENTER", 0, 160, "restored main tutorial")
end
local function checkTranslated()
    isAt(ReportFrame, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "report frame again")
    isAt(BasicMessageDialog, "CENTER", UIParent, "BOTTOMLEFT", 2925, 548.5, "nil-relative dialog again")
    isAt(TutorialMainFrame_Frame, "CENTER", UIParent, "BOTTOMLEFT", 2925, 708.5, "main tutorial again")
end
addon.db.seamRedirect = false
hud:PositionForeverCenteredRoots()
checkRestored()
addon.db.seamRedirect = true
hud:PositionForeverCenteredRoots()
checkTranslated()
metrics.isSpanned = false
hud:PositionForeverCenteredRoots()
checkRestored()
metrics.isSpanned = true
hud:PositionForeverCenteredRoots()
checkTranslated()

-- 8: anything outside the narrow anchor shape is never written.
local untouched = {
    CommunitiesSettingsDialog = frame({"TOP", UIParent, "TOP", 40, -70}),
    CommunitiesAvatarPickerDialog = frame({"TOP", frame(), "TOP", 0, -70}),
    CommunitiesTicketManagerDialog = frame({"TOP", UIParent, "BOTTOM", 0, 70}),
    TutorialDoubleKey_Frame = frame({"TOPLEFT", UIParent, "TOPLEFT", 0, -70}),
    TutorialWalk_Frame = frame({"TOP", UIParent, "TOP", 0, -70}, {"BOTTOM", UIParent, "BOTTOM", 0, 70}),
    TutorialKeyboardMouseFrame_Frame = frame({"TOP", UIParent, "TOP", 0, -70}),
    ObjectiveTrackerTopBannerFrame = frame({"TOP", UIParent, "TOP", 0, -70}),
    PvPObjectiveBannerFrame = frame({"TOP", UIParent, "TOP", 0, -70}),
    UnlistedCenteredFrame = frame({"TOP", UIParent, "TOP", 0, -70}),
}
untouched.TutorialKeyboardMouseFrame_Frame.userPlaced = true
untouched.ObjectiveTrackerTopBannerFrame.protected = true
untouched.PvPObjectiveBannerFrame.forbidden = true
for name, target in pairs(untouched) do _G[name] = target end
hud:PositionForeverCenteredRoots()
for name, target in pairs(untouched) do
    assert(target.writes == 0, name .. " must remain untouched")
end

-- 9: a frame the player moved after translation is not restored.
HonorLevelUpBanner = frame({"TOP", UIParent, "TOP", 0, -70})
PrestigeLevelUpBanner = frame({"TOP", UIParent, "TOP", 0, -70})
hud:PositionForeverCenteredRoots()
isAt(HonorLevelUpBanner, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "honor banner")
isAt(PrestigeLevelUpBanner, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "prestige banner")
HonorLevelUpBanner.points = {{"TOPLEFT", UIParent, "BOTTOMLEFT", 2100, 900}}
PrestigeLevelUpBanner.userPlaced = true
local movedWrites = HonorLevelUpBanner.writes + PrestigeLevelUpBanner.writes
addon.db.seamRedirect = false
hud:PositionForeverCenteredRoots()
assert(HonorLevelUpBanner.writes + PrestigeLevelUpBanner.writes == movedWrites,
    "player-moved windows must not be restored")
isAt(HonorLevelUpBanner, "TOPLEFT", UIParent, "BOTTOMLEFT", 2100, 900, "moved honor banner")
addon.db.seamRedirect = true

-- 10: combat defers placement without any write.
UIWidgetCenterDisplayFrame = frame({"TOP", UIParent, "TOP", 0, -70})
combat = true
hud:PositionForeverCenteredRoots()
assert(UIWidgetCenterDisplayFrame.writes == 0, "combat must not move centred roots")
combat = false
hud:PositionForeverCenteredRoots()
isAt(UIWidgetCenterDisplayFrame, "TOP", UIParent, "BOTTOMLEFT", 2925, 1027, "post-combat widget frame")

-- 11: shutdown and non-Forever clients never write.
local fresh = frame({"TOP", UIParent, "TOP", 0, -70})
UIWidgetCenterDisplayFrame = fresh
addon._loggingOut = true
hud:PositionForeverCenteredRoots()
assert(fresh.writes == 0, "shutdown must not move centred roots")
addon._loggingOut = nil
addon.isForever = false
hud:PositionForeverCenteredRoots()
assert(fresh.writes == 0, "non-Forever clients must not move centred roots")
addon.isForever = true

-- 12: a rejected write restores the native point and keeps no state.
local rejecting = frame({"TOP", UIParent, "TOP", 0, -70})
rejecting.rejectPlacement = true
UIWidgetCenterDisplayFrame = rejecting
hud:PositionForeverCenteredRoots()
isAt(rejecting, "TOP", UIParent, "TOP", 0, -70, "rejected placement")
rejecting.rejectPlacement = nil
rejecting.points = {{"TOP", UIParent, "BOTTOMLEFT", 2925, 1027}}
local rejectedWrites = rejecting.writes
addon.db.seamRedirect = false
hud:PositionForeverCenteredRoots()
assert(rejecting.writes == rejectedWrites, "a rejected placement must keep no ownership state")
addon.db.seamRedirect = true

-- 13: the maintenance ticker entry point runs the centred root pass.
local ticked = frame({"BOTTOM", UIParent, "BOTTOM", 0, 120})
UIWidgetCenterDisplayFrame = ticked
hud:PositionMainhandTransientFrames()
isAt(ticked, "BOTTOM", UIParent, "BOTTOMLEFT", 2925, 120, "ticker placement")

assert(nativeLifecycleAttempts == 0, "native window scripts and visibility must remain untouched")
print("PASS: Forever centred roots translate to the game display and restore exactly")
