--[[
    Offhand: Tests for Party Frames, Edit Mode, and Void Rescue
--]]

local addon = {
    modules = {},
    db = {
        enabled = true,
        seamRedirect = true,
        independentWorkspacePanels = true,
        savedWorkspacePositions = {},
        savedMainPositions = {},
    }
}

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetAttribute = function(self, key) return self[key] or 0 end,
    SetAttribute = function(self, key, val)
        self.attributeWrites = (self.attributeWrites or 0) + 1
        self[key] = val
    end,
    children = {},
    GetChildren = function(self) return unpack(self.children) end,
}

local metrics = {
    screenWidth = 4000, screenHeight = 2560,
    physicalWidth = 4000, physicalHeight = 2560,
    deckWidth = 1440, gameWidth = 2560, gameHeight = 1440,
    gameLeft = 1440, gameBottom = 6, gameRight = 4000, gameTop = 1446,
    gamePixelLeft = 1440, gamePixelBottom = 6, gamePixelWidth = 2560, gamePixelHeight = 1440,
    hudScale = 1, bezel = 0, preset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    actualAR = 2560 / 1440, arMode = "16_9", isSpanned = true,
}

addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end

local timers = {}
local tickers = {}
C_Timer = {
    After = function(_, fn) table.insert(timers, fn) end,
    NewTicker = function(_, fn) table.insert(tickers, fn); return { Cancel = function() end } end,
}
local function flushTimers()
    local t = timers
    timers = {}
    for _, fn in ipairs(t) do fn() end
    for _, fn in ipairs(tickers) do fn() end
end

local frames = {}
local function makeMockFrame(name, w, h)
    local f = {
        name = name, w = w or 200, h = h or 100,
        shown = true, alpha = 1, points = {}, scripts = {}, scale = 1,
        userPlaced = false, movable = false, clamped = false, mouse = false,
        attributes = {},
    }
    function f:SetSize(w,h) self.w=w; self.h=h end
    function f:GetName() return self.name end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:SetHeight(h) self.h = h end
    function f:SetWidth(w) self.w = w end
    function f:GetEffectiveScale() return self.scale end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i)
        i = i or 1
        local p = self.points[i]
        if p then return p[1], p[2], p[3], p[4], p[5] end
        return nil
    end
    function f:SetPoint(pt, rel, relPt, x, y)
        table.insert(self.points, { pt, rel or UIParent, relPt or pt, x or 0, y or 0 })
    end
    function f:ClearAllPoints() self.points = {} end
    function f:GetLeft()
        local p = self.points[#self.points]
        if not p then return 0 end
        if p[3] == "CENTER" then return UIParent:GetWidth()/2 + (p[4] or 0) - self.w/2 end
        if p[1] == "BOTTOMLEFT" or p[1] == "TOPLEFT" or p[1] == "LEFT" then return p[4] or 0 end
        if p[1] == "CENTER" or p[1] == "TOP" or p[1] == "BOTTOM" then return (p[4] or 0) - (self.w / 2) end
        if p[1] == "RIGHT" or p[1] == "TOPRIGHT" or p[1] == "BOTTOMRIGHT" then return (p[4] or 0) - self.w end
        return p[4] or 0
    end
    function f:GetRight() return (self:GetLeft() or 0) + self.w end
    function f:GetTop()
        local p = self.points[#self.points]
        if not p then return self.h end
        local relTop = (p[2] and p[2].GetTop and p[2]:GetTop()) or 2560
        if p[1] == "TOP" or p[1] == "TOPLEFT" or p[1] == "TOPRIGHT" then
            if p[3] == "CENTER" then return relTop/2 + (p[5] or 0) end
            if p[3] == "BOTTOMLEFT" or p[3] == "BOTTOM" or p[3] == "BOTTOMRIGHT" then
                return (p[5] or 0)
            end
            return relTop + (p[5] or 0)
        end
        if p[1] == "BOTTOMLEFT" or p[1] == "BOTTOM" or p[1] == "BOTTOMRIGHT" then
            return (p[5] or 0) + self.h
        end
        if p[1] == "CENTER" then
            if p[3] == "BOTTOMLEFT" then
                return (p[5] or 0) + (self.h / 2)
            end
            local relCenterY = relTop / 2
            return relCenterY + (p[5] or 0) + (self.h / 2)
        end
        return self.h
    end
    function f:GetBottom() return self:GetTop() - self.h end
    function f:IsShown() return self.shown end
    function f:Show()
        self.shown = true
        if self.scripts["OnShow"] then self.scripts["OnShow"](self) end
    end
    function f:Hide()
        self.shown = false
        if self.scripts["OnHide"] then self.scripts["OnHide"](self) end
    end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetUserPlaced(up) self.userPlaced = up end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetMovable(m) self.movable = m end
    function f:SetClampedToScreen(c) self.clamped = c end
    function f:EnableMouse(m) self.mouse = m end
    function f:RegisterForDrag() end
    function f:StartMoving() end
    function f:StopMovingOrSizing() end
    function f:HookScript(event, fn)
        local orig = self.scripts[event]
        self.scripts[event] = function(...)
            if orig then orig(...) end
            fn(...)
        end
    end
    function f:GetScript(event) return self.scripts[event] end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:GetAttribute(key) return self.attributes[key] end
    function f:SetAttributeNoHandler(key, value) self.attributes[key] = value end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    frames[name] = f
    _G[name] = f
    return f
end

CreateFrame = function(frameType, name, parent)
    local f = makeMockFrame(name or ("AnonFrame_" .. tostring(#UIParent.children + 1)), 200, 100)
    table.insert(UIParent.children, f)
    return f
end

hooksecurefunc = function(arg1, arg2, arg3)
    if type(arg1) == "string" then
        local fnName = arg1
        local hookFn = arg2
        local orig = _G[fnName]
        _G[fnName] = function(...)
            local ret = orig and orig(...)
            hookFn(...)
            return ret
        end
    elseif type(arg1) == "table" then
        local tbl = arg1
        local method = arg2
        local hookFn = arg3
        local orig = tbl[method]
        tbl[method] = function(s, ...)
            local ret = orig and orig(s, ...)
            hookFn(s, ...)
            return ret
        end
    end
end

-- Initialize mock frames
PlayerFrame = makeMockFrame("PlayerFrame", 232, 100)
TargetFrame = makeMockFrame("TargetFrame", 232, 100)
PartyMemberFrame1 = makeMockFrame("PartyMemberFrame1", 180, 80)
PartyMemberFrame2 = makeMockFrame("PartyMemberFrame2", 180, 80)
GameMenuFrame = makeMockFrame("GameMenuFrame", 200, 400)
GameMenuFrame:Hide()
ExampleAddonWindow = makeMockFrame("ExampleAddonWindow", 220, 300)
table.insert(UIParent.children, ExampleAddonWindow)

ToggleGameMenu = function()
    if GameMenuFrame:IsShown() then
        GameMenuFrame:Hide()
    else
        GameMenuFrame:Show()
    end
end
ShowUIPanel = function(frame) frame:Show() end
UIPanelWindows = {
    EditModeManagerFrame = { area = "center", pushable = 0, whileDead = 1, neverAllowOtherPanels = 1 },
}
SetUIPanelAttribute = function(frame, name, value)
    frame:SetAttributeNoHandler("UIPanelLayout-" .. name, value)
end

-- Load Offhand core scripts
local seamChunk = loadfile("Core/SeamRedirect.lua")
assert(seamChunk, "Core/SeamRedirect.lua must compile cleanly")
seamChunk("Offhand", addon)

local canvasChunk = loadfile("Core/Canvas.lua")
assert(canvasChunk, "Core/Canvas.lua must compile cleanly")
canvasChunk("Offhand", addon)

addon.HUD:HookFrames()

-- ============================================================================
-- TEST 1: Party Frame Default Positioning inside the 3D Game Viewport
-- ============================================================================
addon.HUD:AlignHUDFrames(metrics)

local partyPt = PartyMemberFrame1.points[#PartyMemberFrame1.points]
assert(partyPt, "PartyMemberFrame1 must be positioned by AlignHUDFrames")
assert(partyPt[1] == "TOPLEFT", "PartyMemberFrame1 anchor point must be TOPLEFT")
-- Game view metrics: gameLeft = 1440, gameTop = 1446
-- Anchor at TOPLEFT with x=16, y=-160 -> x = 1440 + 16 = 1456, y = 1446 - 160 = 1286
assert(math.abs(partyPt[4] - 1456) < 1, string.format("PartyMemberFrame1 X must be 1456, got %s", tostring(partyPt[4])))
assert(math.abs(partyPt[5] - 1286) < 1, string.format("PartyMemberFrame1 Y must be 1286, got %s", tostring(partyPt[5])))
print("PASS: PartyMemberFrame1 defaults cleanly inside the 3D Game Viewport (x=1456, y=1286)")

-- ============================================================================
-- TEST 2: Party Frame Click-Safety (No Overlaid Blocking Handles)
-- ============================================================================
addon.Canvas:EnableFreeDragging()
assert(PartyMemberFrame1._OffhandHandle == nil, "PartyMemberFrame1 must NOT have an overlaid drag handle so unit targeting/healing is never blocked")
print("PASS: PartyMemberFrame1 click-safety confirmed (no overlaid handle)")

-- ============================================================================
-- TEST 3: Party Frame Dragging to the Workspace Monitor & Reload Persistence
-- ============================================================================
-- Simulate player dragging PartyMemberFrame1 to the secondary workspace (e.g. x = 200, y = 1500 on portrait monitor)
PartyMemberFrame1:ClearAllPoints()
PartyMemberFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 1500)
addon.Canvas.OnPanelDragStop(PartyMemberFrame1)

assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"] ~= nil, "PartyMemberFrame1 position must be saved in savedWorkspacePositions")
assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"].x == 200, "PartyMemberFrame1 saved x must match 200")
assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"].y == 1500 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 saved y must match 1500")

-- Simulate reload
PartyMemberFrame1:ClearAllPoints()
addon.HUD:AlignHUDFrames(metrics)
local reloadPt = PartyMemberFrame1.points[#PartyMemberFrame1.points]
assert(reloadPt and reloadPt[4] == 200 and reloadPt[5] == 1500 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 must restore to workspace on reload")
print("PASS: PartyMemberFrame1 dragging to secondary workspace and reload persistence verified")

-- ============================================================================
-- TEST 4: Dragging Party Frame Back to the Game View Monitor
-- ============================================================================
-- Drag back to game monitor at x = 1600, y = 1000
PartyMemberFrame1:ClearAllPoints()
PartyMemberFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1600, 1000)
addon.Canvas.OnPanelDragStop(PartyMemberFrame1)

assert(addon.db.savedWorkspacePositions["PartyMemberFrame1"] == nil, "PartyMemberFrame1 must be cleared from savedWorkspacePositions when on Game View")
assert(addon.db.savedMainPositions["PartyMemberFrame1"] ~= nil, "PartyMemberFrame1 must be saved in savedMainPositions")
assert(addon.db.savedMainPositions["PartyMemberFrame1"].x == 1600, "PartyMemberFrame1 main x must be 1600")
assert(addon.db.savedMainPositions["PartyMemberFrame1"].y == 1000 + PartyMemberFrame1:GetHeight(), "PartyMemberFrame1 main y must be 1000")
print("PASS: PartyMemberFrame1 dragged back to Game View updates savedMainPositions")

-- ============================================================================
-- TEST 5: Forever yields protected HUD placement to Blizzard Edit Mode
-- ============================================================================
addon.isForever = true
MainActionBar = makeMockFrame("MainActionBar", 500, 45)
MainActionBar.IsInDefaultPosition = function() return true end
local originalMainSetPoint = MainActionBar.SetPoint
local EditModeManagerFrame = makeMockFrame("EditModeManagerFrame", 600, 60)
local EditModeSystemSettingsDialog = makeMockFrame("EditModeSystemSettingsDialog", 400, 300)
local EditModeUnsavedChangesDialog = makeMockFrame("EditModeUnsavedChangesDialog", 350, 150)
Enum = {
    EditModeSystem = { ActionBar = 1 },
    EditModeActionBarSystemIndices = { MainBar = 1 },
}
local layoutData = {
    -- Forever exposes Modern=1 and Classic=2 as global identifiers, reserves
    -- identifier 3, then maps custom layouts from layouts[1] to identifier 4.
    activeLayout = 6,
    layouts = {
        {layoutName = "123", layoutType = 1},
        {layoutName = "432", layoutType = 1},
        {
            layoutName = "Offhand",
            layoutType = 1,
            systems = {
                {system = 1, systemIndex = 1, isInDefaultPosition = true},
            },
        },
        {layoutName = "777", layoutType = 1},
        {layoutName = "666", layoutType = 1},
    },
}
local selectedLayout
C_EditMode = {
    GetLayouts = function() return layoutData end,
    SetActiveLayout = function(index)
        selectedLayout = index
        layoutData.activeLayout = index
    end,
}

-- Simulate on-demand loading of Blizzard_EditMode
addon.HUD.editModeLoadScheduled = nil
local panelAttributeWrites = UIParent.attributeWrites or 0
addon.HUD:HookFrames()
addon.HUD:AlignHUDFrames(metrics)
assert((UIParent.attributeWrites or 0) == panelAttributeWrites,
    "Forever must not write legacy UIParent panel-layout attributes")

assert(MainActionBar.SetPoint == originalMainSetPoint,
    "Forever must not install a SetPoint repair hook on MainActionBar")
assert(#MainActionBar.points == 0,
    "Forever must not directly anchor MainActionBar")

-- Forever can load Blizzard_EditMode after Offhand's canvas initialization.
-- Protected unit frames must still be rejected when the manager did not exist
-- at the time draggable-frame discovery first ran.
local party2PointCount = #PartyMemberFrame2.points
addon.Canvas.MakePanelDraggable(PartyMemberFrame2)
addon.Canvas:TryMakeFrameDraggable(EditModeManagerFrame)
addon.Canvas.RestoreWorkspacePosition(PartyMemberFrame2)
addon.Canvas.OnPanelDragStop(PartyMemberFrame2)
assert(not PartyMemberFrame2._OffhandMovable and not PartyMemberFrame2.movable,
    "Forever must not make party frames movable")
assert(not EditModeManagerFrame._OffhandMovable and not EditModeManagerFrame.movable,
    "Forever must not make EditModeManagerFrame movable")
assert(#PartyMemberFrame2.points == party2PointCount,
    "Forever must not restore or save party-frame anchors through Canvas")

local protectedPanel = makeMockFrame("ProtectedPanel", 300, 200)
protectedPanel.TitleText = {}
protectedPanel.IsProtected = function() return true end
local forbiddenPanel = makeMockFrame("ForbiddenPanel", 300, 200)
forbiddenPanel.TitleText = {}
forbiddenPanel.IsForbidden = function() return true end
addon.Canvas:TryMakeFrameDraggable(protectedPanel)
addon.Canvas:TryMakeFrameDraggable(forbiddenPanel)
assert(not protectedPanel._OffhandMovable and not protectedPanel.movable,
    "Generic discovery must not mutate protected panels")
assert(not forbiddenPanel._OffhandMovable and not forbiddenPanel.movable,
    "Generic discovery must not mutate forbidden panels")

ShowUIPanel(EditModeManagerFrame)
flushTimers()

local editPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(EditModeManagerFrame:GetAttribute("UIPanelLayout-centerFrameSkipAnchoring") == true,
    "Forever must tell Blizzard's panel manager to retain the Edit Mode manager anchor")
assert(UIPanelWindows.EditModeManagerFrame.centerFrameSkipAnchoring == true,
    "Forever must update the Edit Mode manager's registered panel metadata")
assert(editPt and editPt[1] == "TOP" and editPt[2] == UIParent and editPt[3] == "BOTTOMLEFT"
        and editPt[4] == (metrics.gameLeft + metrics.gameRight) / 2
        and editPt[5] == metrics.gameTop - 40,
    "Forever must anchor EditModeManagerFrame inside the current game viewport")
local editPointCount = #EditModeManagerFrame.points
EditModeManagerFrame:Hide()
ShowUIPanel(EditModeManagerFrame)
flushTimers()
assert(#EditModeManagerFrame.points == editPointCount
        and EditModeManagerFrame.points[#EditModeManagerFrame.points][2] == UIParent,
    "Forever must preserve the Edit Mode manager anchor across close and reopen")

-- Companion spanning can finish after Blizzard_EditMode is prepared. A geometry
-- change must update the one retained anchor without installing an OnShow hook.
local originalGameTop = metrics.gameTop
metrics.gameTop = originalGameTop - 200
flushTimers()
local resizedEditPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(resizedEditPt and resizedEditPt[5] == metrics.gameTop - 40,
    "Forever must refresh the Edit Mode manager anchor after a late Companion span")
metrics.gameTop = originalGameTop
flushTimers()
assert(EditModeManagerFrame.points[#EditModeManagerFrame.points][5] == originalGameTop - 40,
    "Forever must follow subsequent viewport geometry changes")
assert(selectedLayout == nil,
    "Forever must not auto-select an Offhand layout whose main action bar is still in its full-canvas default position")
assert(addon.HUD.editModeGuidanceShown,
    "Forever must guide the player to configure an unpositioned Offhand Edit Mode layout")

-- A disconnected saved display must temporarily use a built-in single-screen
-- layout rather than letting Blizzard clamp the spanned Offhand HUD into a
-- malformed arrangement. Reconnecting restores Offhand, unless the player
-- manually chose a different layout during recovery.
local recoveryPrompt
addon.ShowForeverLayoutRecoveryPrompt = function(_, kind) recoveryPrompt = kind end
local originalTopologyStatus, originalCompanionTopology, originalSpanned =
    metrics.topologyStatus, metrics.companionTopology, metrics.isSpanned
metrics.topologyStatus = "MISMATCH"
metrics.companionTopology = true
metrics.isSpanned = false
layoutData.activeLayout = 6
selectedLayout = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == nil and addon.db.foreverEditModeRecovery == nil,
    "Forever must allow a normal launch grace period before declaring a display missing")
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(recoveryPrompt == nil and addon.db.foreverEditModeRecovery == nil,
    "A normal Companion span during the grace period must cancel missing-display recovery")
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6 and recoveryPrompt == "fallback",
    "Forever must request a player click before selecting a protected single-screen layout")
assert(addon.db.foreverEditModeRecovery
        and addon.db.foreverEditModeRecovery.restoreLayoutID == 6
        and addon.db.foreverEditModeRecovery.restoreLayoutName == "Offhand"
        and addon.db.foreverEditModeRecovery.fallbackLayoutID == 1
        and addon.db.foreverEditModeRecovery.fallbackLayoutName == "Modern",
    "Forever must remember the protected layout handoff")
addon.HUD:ApplyForeverRecoveryChoice("fallback")
assert(selectedLayout == 1 and layoutData.activeLayout == 1
        and addon.db.foreverEditModeRecovery,
    "The single-screen recovery button must select Modern and retain the return handoff")

selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(selectedLayout == nil and layoutData.activeLayout == 1 and recoveryPrompt == "restore",
    "Forever must request a player click before restoring its protected layout")
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(selectedLayout == 6 and layoutData.activeLayout == 6,
    "The restore button must select the remembered Offhand Edit Mode layout")
assert(addon.db.foreverEditModeRecovery == nil,
    "Forever must clear the completed protected layout handoff")

-- If Forever ignores a non-hardware or otherwise blocked selection, retain the
-- marker and clear it only after a later read-back confirms Offhand.
layoutData.activeLayout = 6
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
addon.HUD:ApplyForeverRecoveryChoice("fallback")
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
local blockedRestoreID
C_EditMode.SetActiveLayout = function(index)
    selectedLayout = index
    blockedRestoreID = index
end
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(blockedRestoreID == 6 and layoutData.activeLayout == 1
        and addon.db.foreverEditModeRecovery,
    "Forever must retain the protected layout handoff until selection is confirmed")
layoutData.activeLayout = blockedRestoreID
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(addon.db.foreverEditModeRecovery == nil and layoutData.activeLayout == 6,
    "Forever must clear the handoff after delayed Edit Mode read-back confirms Offhand")
C_EditMode.SetActiveLayout = function(index)
    selectedLayout = index
    layoutData.activeLayout = index
end

layoutData.activeLayout = 6
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
addon.HUD:ApplyForeverRecoveryChoice("fallback")
layoutData.activeLayout = 2
selectedLayout = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(selectedLayout == nil and layoutData.activeLayout == 2,
    "Forever must preserve a layout manually selected during single-screen recovery")
assert(addon.db.foreverEditModeRecovery == nil,
    "Forever must clear stale recovery state after manual layout selection")
layoutData.activeLayout = 6
selectedLayout = nil
metrics.topologyStatus = originalTopologyStatus
metrics.companionTopology = originalCompanionTopology
metrics.isSpanned = originalSpanned

-- Even after the player has configured the layout, Forever must leave profile
-- selection to Blizzard Edit Mode. A delayed switch can move or hide bars.
layoutData.layouts[3].systems[1].isInDefaultPosition = false
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6,
    "Forever must not change the active Edit Mode layout after reload")

local recoveryPanel = makeMockFrame("RecoveryWorkspacePanel", 500, 400)
local recoveryChat = makeMockFrame("ChatFrame9", 500, 300)
local recoveryCharacter = makeMockFrame("CharacterFrame", 500, 700)
local recoveryBag = makeMockFrame("ContainerFrameCombinedBags", 500, 300)
addon.db.savedWorkspacePositions.RecoveryWorkspacePanel = { x = 100, y = 900 }
addon.db.savedWorkspacePositions.ChatFrame9 = { x = 100, y = 400 }
addon.db.savedWorkspacePositions.CharacterFrame = { x = 100, y = 800 }
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = { x = 100, y = 300 }
addon.Canvas:PrepareSingleScreenRecovery({ topologyStatus = "MISMATCH", isSpanned = false })
assert(not recoveryPanel:IsShown(),
    "single-screen recovery must temporarily close visible workspace panels")
assert(recoveryChat:IsShown(),
    "single-screen recovery must keep chat available")
assert(addon.db.savedWorkspacePositions.RecoveryWorkspacePanel,
    "single-screen recovery must preserve saved workspace geometry")
recoveryPanel:Show()
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryPanel,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "a workspace panel opened during recovery must receive a temporary visible anchor")
local recoveryPoint = recoveryPanel.points[#recoveryPanel.points]
assert(recoveryPoint and recoveryPoint[1] == "CENTER" and recoveryPoint[2] == UIParent
        and recoveryPoint[3] == "CENTER" and recoveryPoint[4] == 0 and recoveryPoint[5] == 0,
    "single-screen recovery must center reopened workspace panels")
assert(addon.db.savedWorkspacePositions.RecoveryWorkspacePanel.x == 100,
    "temporary recovery anchors must not overwrite saved Offhand coordinates")
local chatPointCount = #recoveryChat.points
assert(not addon.Canvas:PlaceForSingleScreenRecovery(recoveryChat,
        { topologyStatus = "MISMATCH", isSpanned = false })
        and #recoveryChat.points == chatPointCount,
    "Modern must retain ownership of the single-screen chat anchor")
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryCharacter,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "the character sheet must receive a single-screen recovery anchor")
local characterPoint = recoveryCharacter.points[#recoveryCharacter.points]
assert(characterPoint and characterPoint[1] == "TOPLEFT" and characterPoint[3] == "TOPLEFT",
    "the character sheet must recover near the upper-left")
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryBag,
        { topologyStatus = "MISMATCH", isSpanned = false }),
    "the backpack must receive a single-screen recovery anchor")
local bagPoint = recoveryBag.points[#recoveryBag.points]
assert(bagPoint and bagPoint[1] == "BOTTOMRIGHT" and bagPoint[3] == "BOTTOMRIGHT",
    "the backpack must recover above the lower-right action UI")

-- Edit Mode dialogs also remain entirely Blizzard-owned.
EditModeUnsavedChangesDialog:Show()
flushTimers()
local dialogPt = EditModeUnsavedChangesDialog.points[#EditModeUnsavedChangesDialog.points]
assert(dialogPt == nil, "Forever must not reanchor Edit Mode dialogs")
print("PASS: Forever preserves Blizzard Edit Mode while keeping its manager inside the game viewport")

-- ============================================================================
-- TEST 6: GameMenuFrame Centering & Escape Dismissal
-- ============================================================================
ToggleGameMenu()
flushTimers()
local menuPt = GameMenuFrame.points[#GameMenuFrame.points]
assert(menuPt, "GameMenuFrame must be anchored")
assert(menuPt[1] == "CENTER", "GameMenuFrame point must be CENTER")
assert(math.abs(menuPt[4] + 2000 - 2720) < 1, "GameMenuFrame X must be centered at 2720")
assert(math.abs(menuPt[5] + 1280 - 726) < 1, "GameMenuFrame Y must be centered at 726")
ToggleGameMenu() -- Dismiss cleanly
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must dismiss cleanly on toggle")
print("PASS: GameMenuFrame centers on Game Viewport and dismisses cleanly")

-- ============================================================================
-- TEST 7: Universal Void Rescue Engine (Focused Roster Frame & Rogue Frames)
-- ============================================================================
-- Place ExampleAddonWindow high up in the black void (e.g. x = 2000, top = 2500, where gameTop is 1446)
ExampleAddonWindow:ClearAllPoints()
ExampleAddonWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2000, -50) -- y = 2510 in the void!
assert(ExampleAddonWindow:GetTop() > metrics.gameTop, "ExampleAddonWindow must initially be in the void")

-- Trigger HUD popup/void scanner
addon.HUD:HookFrames()
-- Manually invoke OnShow hook or ticker that runs RedirectExternalPopups
for _, child in ipairs(UIParent.children) do
    if child == ExampleAddonWindow then
        child:Show()
    end
end
flushTimers()

-- The Void Rescue Engine must detect GetTop() > m.gameTop and clamp it down
local rescuedPt = ExampleAddonWindow.points[#ExampleAddonWindow.points]
assert(rescuedPt, "ExampleAddonWindow must be repositioned by Void Rescue Engine")
local rescuedTop = ExampleAddonWindow:GetTop()
assert(rescuedTop <= metrics.gameTop, string.format("Rescued frame top (%s) must be <= gameTop (%s)", tostring(rescuedTop), tostring(metrics.gameTop)))
print(string.format("PASS: Void Rescue Engine successfully rescued ExampleAddonWindow from void (top=%s <= gameTop=%s)", tostring(rescuedTop), tostring(metrics.gameTop)))

-- ============================================================================
-- TEST 8: Game View Monitor Drag Clamping
-- ============================================================================
-- If user drags ExampleAddonWindow on the main game monitor, it must never exceed gameTop - height
ExampleAddonWindow:ClearAllPoints()
ExampleAddonWindow:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 2000) -- Attempt to place in void
addon.Canvas.OnPanelDragStop(ExampleAddonWindow)

local clampedTop = ExampleAddonWindow:GetTop()
assert(clampedTop <= metrics.gameTop, string.format("Clamped frame top (%s) must never exceed gameTop (%s)", tostring(clampedTop), tostring(metrics.gameTop)))
print(string.format("PASS: Game View drag clamping enforces top <= gameTop (%s <= %s)", tostring(clampedTop), tostring(metrics.gameTop)))

-- ============================================================================
-- TEST 9: Blizzard EditModeUtil remains untouched
-- ============================================================================
StanceBar = makeMockFrame("StanceBar", 120, 30)
StanceBar.IsInDefaultPosition = function() return true end
StanceBar.IsInitialized = function() return true end
StanceBar:ClearAllPoints() -- GetPoint(1) returns nil (as occurs during stance transitions)

local nativeBottomHeight = function() return 37 end
EditModeUtil = { GetBottomActionBarHeight = nativeBottomHeight }
addon.HUD:HookFrames()

local ok, height = pcall(function() return EditModeUtil:GetBottomActionBarHeight() end)
assert(ok and height == 37, "Blizzard EditModeUtil behavior must remain intact")
assert(EditModeUtil.GetBottomActionBarHeight == nativeBottomHeight,
    "Offhand must not replace EditModeUtil:GetBottomActionBarHeight")
print("PASS: Blizzard EditModeUtil remains untouched")

-- ============================================================================
-- TEST 10: Bad-self intrinsic widgets in UIParent:GetChildren()
-- ============================================================================
local badSelfWidget = {
    GetName = function(self) error("calling '?' on bad self (Usage: local name = self:GetName())") end,
    IsShown = function(self) return true end,
    IsForbidden = function(self) return false end,
    IsProtected = function(self) return false end,
}
table.insert(UIParent.children, badSelfWidget)

-- Flush timers which invokes RedirectExternalPopups() over UIParent.children
flushTimers()
print("PASS: Bad self intrinsic widgets in UIParent:GetChildren() safely handled without error")

print("\nALL PARTY FRAMES, EDIT MODE, AND VOID RESCUE TESTS PASSED!")

assert(#tickers == 1, "Repeated HUD setup installed duplicate scanners")

-- A full-height seam guide deliberately extends above the game viewport.
local guide = makeMockFrame("OffhandSeamGuideLine", 4, 2560)
table.insert(UIParent.children, guide)
guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", metrics.deckWidth - 2, 0)
guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.deckWidth - 2, 0)
local guidePoints = #guide.points
for i = 1, 3 do flushTimers() end
assert(#guide.points == guidePoints and guide.points[1][1] == "TOPLEFT",
    "Popup recovery must preserve the seam guide's full-height anchors")

