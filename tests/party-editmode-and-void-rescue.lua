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
    workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1440, workspaceTop = 2560,
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
RegisterUIPanel = function(frame)
    local name = frame and frame.GetName and frame:GetName()
    if name then UIPanelWindows[name] = UIPanelWindows[name] or { area = "left", pushable = 0 } end
end
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
PlayerFrame = makeMockFrame("PlayerFrame", 232, 100)
local originalPlayerSetPoint = PlayerFrame.SetPoint
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
assert(PlayerFrame.SetPoint == originalPlayerSetPoint,
    "Forever must not install a SetPoint repair hook on PlayerFrame")
assert(#PlayerFrame.points == 0,
    "Forever must not directly anchor PlayerFrame")

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
assert(EditModeManagerFrame:GetAttribute("UIPanelLayout-centerFrameSkipAnchoring") == nil,
    "Forever must not write Edit Mode panel-layout attributes")
assert(UIPanelWindows.EditModeManagerFrame.centerFrameSkipAnchoring == nil,
    "Forever must not mutate Edit Mode panel metadata")
assert(editPt == nil,
    "Forever must leave EditModeManagerFrame anchors entirely Blizzard-owned")
local editPointCount = #EditModeManagerFrame.points
EditModeManagerFrame:Hide()
ShowUIPanel(EditModeManagerFrame)
flushTimers()
assert(#EditModeManagerFrame.points == editPointCount,
    "Forever must not alter the Edit Mode manager when it reopens")

-- Companion geometry changes must not cause addon writes to the manager.
local originalGameTop = metrics.gameTop
metrics.gameTop = originalGameTop - 200
flushTimers()
local resizedEditPt = EditModeManagerFrame.points[#EditModeManagerFrame.points]
assert(resizedEditPt == nil,
    "Forever must not reanchor Edit Mode after a late Companion span")
metrics.gameTop = originalGameTop
flushTimers()
assert(#EditModeManagerFrame.points == 0,
    "Forever must preserve native Edit Mode ownership across geometry changes")
assert(selectedLayout == nil,
    "Forever must not auto-select an Offhand layout whose main action bar is still in its full-canvas default position")
assert(addon.HUD.editModeGuidanceShown,
    "Forever must guide the player to configure an unpositioned Offhand Edit Mode layout")

-- A mixed-height span can place only the Edit Mode control window in the
-- physical void. Detection must not attach handlers or mutate Blizzard state;
-- the explicit player-click recovery moves only the unprotected manager.
local editModePromptCount, editModePromptHidden = 0, 0
addon.ShowForeverEditModeControlsPrompt = function() editModePromptCount = editModePromptCount + 1 end
addon.HideForeverEditModeControlsPrompt = function() editModePromptHidden = editModePromptHidden + 1 end
EditModeManagerFrame:ClearAllPoints()
EditModeManagerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1268, 1586)
local voidManagerPointCount = #EditModeManagerFrame.points
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptCount == 1, "Forever must offer recovery when Edit Mode controls are in the void")
assert(#EditModeManagerFrame.points == voidManagerPointCount
        and EditModeManagerFrame.points[1][1] == "BOTTOMLEFT",
    "Edit Mode void detection must remain read-only")
assert(next(EditModeManagerFrame.scripts) == nil,
    "Edit Mode recovery must not attach scripts to Blizzard's manager")
assert(addon.HUD:BringForeverEditModeControlsToMainhand(),
    "Player-click recovery must bring the unprotected manager to Mainhand")
assert(editModePromptHidden == 0,
    "The Accept callback must let Blizzard close its popup without a re-entrant hide")
local recoveredManagerPoint = EditModeManagerFrame.points[1]
assert(recoveredManagerPoint and recoveredManagerPoint[1] == "CENTER"
        and recoveredManagerPoint[2] == UIParent,
    "Edit Mode recovery must center the manager without changing panel metadata")
assert(UIPanelWindows.EditModeManagerFrame.area == "center"
        and EditModeManagerFrame:GetAttribute("UIPanelLayout-centerFrameSkipAnchoring") == nil,
    "Edit Mode recovery must not mutate Blizzard panel metadata or attributes")
EditModeManagerFrame:Hide()
addon.HUD:UpdateForeverEditModeControlsRecovery(metrics)
assert(editModePromptHidden >= 1 and addon.HUD.foreverEditModeManagerWasShown == nil,
    "Closing Edit Mode must reset control-window recovery for its next opening")
EditModeManagerFrame:Show()

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

-- Restore Window can shrink WoW before the running addon has loaded any exact
-- topology. Forever must treat ABSENT like a missing-display recovery instead
-- of leaving protected HUD frames at their old spanned coordinates.
layoutData.activeLayout = 6
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "ABSENT"
metrics.companionTopology = false
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(selectedLayout == nil and layoutData.activeLayout == 6 and recoveryPrompt == "fallback",
    "Forever absent topology must request the player-click single-screen layout")
assert(addon.db.foreverEditModeRecovery
        and addon.db.foreverEditModeRecovery.restoreLayoutID == 6,
    "Forever absent topology must retain the protected Offhand layout handoff")
addon.HUD:ApplyForeverRecoveryChoice("fallback")
metrics.topologyStatus = "READY"
metrics.companionTopology = true
metrics.isSpanned = true
recoveryPrompt = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == "restore",
    "Forever must offer to restore Offhand after exact topology returns")
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(layoutData.activeLayout == 6 and addon.db.foreverEditModeRecovery == nil,
    "Forever must complete the absent-topology recovery round trip")

-- Layout names are case-insensitive, and a recovery snapshot must follow the
-- named layout if its custom slot differs from the ID remembered at disconnect.
layoutData.layouts[3].layoutName = "OFFHAND"
layoutData.activeLayout = 6
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "MISMATCH"
metrics.isSpanned = false
addon.HUD:UpdateForeverRecoveryLayout(metrics)
flushTimers()
assert(recoveryPrompt == "fallback" and addon.db.foreverEditModeRecovery
        and addon.db.foreverEditModeRecovery.restoreLayoutName == "OFFHAND",
    "Forever recovery must recognize Offhand layout names without case sensitivity")
addon.HUD:ApplyForeverRecoveryChoice("fallback")
local movedOffhand = layoutData.layouts[3]
layoutData.layouts[3] = layoutData.layouts[2]
layoutData.layouts[2] = movedOffhand
selectedLayout = nil
recoveryPrompt = nil
metrics.topologyStatus = "READY"
metrics.isSpanned = true
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(recoveryPrompt == "restore" and addon.db.foreverEditModeRecovery.restoreLayoutID == 5,
    "Forever recovery must re-resolve a named Offhand layout after its custom slot changes")
addon.HUD:ApplyForeverRecoveryChoice("restore")
assert(selectedLayout == 5 and layoutData.activeLayout == 5
        and addon.db.foreverEditModeRecovery == nil,
    "Forever restore must select the current slot for the remembered Offhand layout name")

-- Never trust a stale numeric slot when the remembered named layout no longer
-- exists; the slot may now belong to an unrelated custom profile.
addon.db.foreverEditModeRecovery = {
    restoreLayoutID = 6,
    restoreLayoutName = "Missing Offhand",
    fallbackLayoutID = 1,
}
layoutData.activeLayout = 1
selectedLayout = nil
recoveryPrompt = nil
addon.HUD:UpdateForeverRecoveryLayout(metrics)
assert(addon.db.foreverEditModeRecovery == nil and selectedLayout == nil
        and layoutData.activeLayout == 1,
    "Forever must not select an unrelated stale slot when the named layout is missing")

layoutData.layouts[2] = layoutData.layouts[3]
layoutData.layouts[3] = movedOffhand
layoutData.layouts[3].layoutName = "Offhand"
layoutData.activeLayout = 6

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

-- Anniversary exposes an active global ID that does not share the custom
-- layout array's index namespace. Compare by active name, and use only the
-- C_EditMode array-index API when a change is actually required.
addon.isForever = false
local anniversaryActiveName = "Offhand"
local managerSelection
EditModeManagerFrame.GetActiveLayoutInfo = function()
    return { layoutName = anniversaryActiveName }
end
EditModeManagerFrame.SelectLayout = function(_, index)
    managerSelection = index
end
layoutData.activeLayout = 5
selectedLayout = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == nil and managerSelection == nil,
    "Anniversary reload must preserve an already-active Offhand layout despite a different numeric ID")

anniversaryActiveName = "Modern"
selectedLayout = nil
managerSelection = nil
addon.HUD.editModeLoadScheduled = nil
addon.HUD:HookFrames()
flushTimers()
assert(selectedLayout == 3 and managerSelection == nil,
    "Anniversary must select Offhand through C_EditMode's layout-array index, not a manager row ID")
addon.isForever = true
layoutData.activeLayout = 6
selectedLayout = nil

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
recoveryPanel:Show()
addon.Canvas:PrepareSingleScreenRecovery({ topologyStatus = "ABSENT", isSpanned = false })
assert(not recoveryPanel:IsShown(),
    "Forever absent topology must temporarily close visible workspace panels")
recoveryPanel:Show()
assert(addon.Canvas:PlaceForSingleScreenRecovery(recoveryPanel,
        { topologyStatus = "ABSENT", isSpanned = false }),
    "Forever absent topology must give reopened workspace panels a visible anchor")

-- Edit Mode dialogs also remain entirely Blizzard-owned.
EditModeUnsavedChangesDialog:Show()
flushTimers()
local dialogPt = EditModeUnsavedChangesDialog.points[#EditModeUnsavedChangesDialog.points]
assert(dialogPt == nil, "Forever must not reanchor Edit Mode dialogs")
print("PASS: Forever preserves Blizzard ownership of Edit Mode and its manager")

-- ============================================================================
-- TEST 6: GameMenuFrame Centering & Escape Dismissal
-- ============================================================================
ToggleGameMenu()
flushTimers()
local menuPt = GameMenuFrame.points[#GameMenuFrame.points]
assert(menuPt == nil, "Forever must leave GameMenuFrame anchors Blizzard-owned")
ToggleGameMenu() -- Dismiss cleanly
assert(not GameMenuFrame:IsShown(), "GameMenuFrame must dismiss cleanly on toggle")
print("PASS: Forever leaves GameMenuFrame native and it dismisses cleanly")

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

-- A workspace stacked directly above Mainhand shares the same horizontal
-- range. The void scanner must use the complete workspace rectangle instead
-- of treating every frame above gameTop as lost.
local originalMetrics = {}
for key, value in pairs(metrics) do originalMetrics[key] = value end
metrics.screenWidth, metrics.screenHeight = 2560, 2880
metrics.physicalWidth, metrics.physicalHeight = 2560, 2880
metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 0, 0, 2560, 1440
metrics.workspaceLeft, metrics.workspaceBottom = 0, 1440
metrics.workspaceRight, metrics.workspaceTop = 2560, 2880
metrics.workspaceWidth, metrics.workspaceHeight = 2560, 1440

local stackedWorkspaceFrame = makeMockFrame("StackedWorkspaceFrame", 500, 400)
stackedWorkspaceFrame:ClearAllPoints()
stackedWorkspaceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 700, 2500)
table.insert(UIParent.children, stackedWorkspaceFrame)

-- Exercise the complete Forever drag/save/reload path, not only the popup
-- scanner. A saved frame on an upper monitor shares Mainhand's X range and
-- must retain its absolute workspace Y coordinate.
addon.Canvas.OnPanelDragStop(stackedWorkspaceFrame)
local stackedSaved = addon.db.savedWorkspacePositions.StackedWorkspaceFrame
assert(stackedSaved and stackedSaved.canvasBottom == 1440
        and stackedSaved.y > metrics.gameTop,
    "Forever must save upper-workspace drag coordinates against the workspace rectangle")
stackedWorkspaceFrame:ClearAllPoints()
stackedWorkspaceFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
addon.Canvas.RestoreWorkspacePosition(stackedWorkspaceFrame)
assert(addon.Canvas.IsFrameOnWorkspace(stackedWorkspaceFrame),
    "Forever reload restoration must return a saved frame to the upper workspace")

local stackedPointCount = #stackedWorkspaceFrame.points
flushTimers()
assert(#stackedWorkspaceFrame.points == stackedPointCount
        and stackedWorkspaceFrame.points[#stackedWorkspaceFrame.points][1] == "TOPLEFT",
    "void rescue must not return a valid upper-workspace frame to Mainhand")
assert(addon.Canvas.IsFrameOnWorkspace(stackedWorkspaceFrame),
    "upper stacked workspace must be recognized by its full rectangle")
for key in pairs(metrics) do metrics[key] = nil end
for key, value in pairs(originalMetrics) do metrics[key] = value end
print("PASS: upper stacked workspace frames are not mistaken for Mainhand void")

-- Load-on-demand panels are not a stable name list. A newly registered spell
-- book with no explicit Offhand placement must be discovered, made draggable,
-- and moved from Blizzard's UIParent-relative workspace anchor to Mainhand.
local playerSpellsFrame = makeMockFrame("PlayerSpellsFrame", 600, 700)
local playerSpellsTitle = makeMockFrame("PlayerSpellsFrameTitleContainer", 500, 20)
playerSpellsFrame.TitleContainer = playerSpellsTitle
playerSpellsFrame.IsProtected = function() return true end
playerSpellsTitle.IsProtected = function() return true end
playerSpellsFrame.StartMoving = function(self) self.startMovingCalls = (self.startMovingCalls or 0) + 1 end
playerSpellsFrame.SetUserPlaced = function(self, value)
    self.setUserPlacedFalseCalls = (self.setUserPlacedFalseCalls or 0) + (value == false and 1 or 0)
    if value == false then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 2720, 720)
    end
end
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1000, 2500)
UIPanelWindows.PlayerSpellsFrame = { area = "left", pushable = 0 }
addon.Canvas:DiscoverUIPanels()
flushTimers()
assert(playerSpellsFrame._OffhandMovable and playerSpellsFrame.movable,
    "dynamic UIPanel discovery must make registered out-of-combat protected panels draggable")
assert(playerSpellsFrame._OffhandHandle == playerSpellsTitle
        and playerSpellsTitle._OffhandPanelDragTarget == playerSpellsFrame,
    "modern Blizzard panels must use their elevated native TitleContainer as the drag surface")
playerSpellsTitle.scripts.OnDragStart(playerSpellsTitle)
assert(playerSpellsFrame.startMovingCalls == 1,
    "dragging the native title container must start moving its owning panel")
assert(playerSpellsFrame:GetLeft() >= metrics.gameLeft + 12
        and playerSpellsFrame:GetRight() <= metrics.gameRight - 12,
    "an unsaved Blizzard panel must default inside the Mainhand viewport")
assert(playerSpellsFrame:GetTop() <= metrics.gameTop - 12
        and playerSpellsFrame:GetBottom() >= metrics.gameBottom + 12,
    "default Blizzard panels must remain vertically contained in Mainhand")

playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 260, 1900)
playerSpellsTitle.scripts.OnDragStop(playerSpellsTitle)
assert(addon.db.savedWorkspacePositions.PlayerSpellsFrame,
    "a dynamically discovered panel drag must persist its workspace position")
assert((playerSpellsFrame.setUserPlacedFalseCalls or 0) == 0,
    "Forever drag stop must not clear user-placed state and trigger a native center reset")
assert(addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame),
    "a Forever panel dropped on the left workspace must not snap back to Mainhand")

-- Moving the same panel back to Mainhand is also an explicit placement. It
-- must survive a native close/reopen instead of falling back to the workspace
-- anchor, and it must rejoin normal Escape ownership there.
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1900, 1100)
playerSpellsTitle.scripts.OnDragStop(playerSpellsTitle)
local spellMain = addon.db.savedMainPositions.PlayerSpellsFrame
assert(not addon.db.savedWorkspacePositions.PlayerSpellsFrame and spellMain
        and spellMain.x == 1900 and spellMain.y == 1100,
    "a Blizzard panel dragged back to Mainhand must save its Mainhand position")
assert(not addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame),
    "a Blizzard panel dragged to Mainhand must remain there immediately")

playerSpellsFrame:Hide()
playerSpellsFrame:ClearAllPoints()
playerSpellsFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 160, 2300)
playerSpellsFrame:Show()
flushTimers()
assert(not addon.Canvas.IsFrameOnWorkspace(playerSpellsFrame)
        and playerSpellsFrame:GetLeft() == 1900 and playerSpellsFrame:GetTop() == 1100,
    "closing and reopening a Mainhand panel must restore its saved Mainhand anchor")

local professionsFrame = makeMockFrame("ProfessionsFrame", 700, 800)
UIPanelWindows.ProfessionsFrame = { area = "left", pushable = 0 }
addon.db.savedMainPositions.ProfessionsFrame = { x = 9000, y = -500 }
addon.Canvas.RestoreWorkspacePosition(professionsFrame)
assert(professionsFrame:GetLeft() >= metrics.gameLeft + 12
        and professionsFrame:GetRight() <= metrics.gameRight - 12
        and professionsFrame:GetTop() <= metrics.gameTop - 12
        and professionsFrame:GetBottom() >= metrics.gameBottom + 12,
    "stale Mainhand panel coordinates must be clamped back onto the visible game monitor")
print("PASS: dynamic Blizzard panels default to Mainhand and persist explicit monitor placements")

-- A panel whose Blizzard addon loads after login did not exist during the
-- initial persistence pass. RegisterUIPanel must reopen it when Offhand has an
-- explicit saved/open workspace record (the live Professions failure).
local lateProfessionsFrame = makeMockFrame("ProfessionsBookFrame", 700, 800)
lateProfessionsFrame:Hide()
addon.db.savedWorkspacePositions.ProfessionsBookFrame = {
    x = 180, y = 1500, canvasLeft = 0, canvasBottom = 0,
    canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
}
addon.db.openWorkspacePanels = addon.db.openWorkspacePanels or {}
addon.db.openWorkspacePanels.ProfessionsBookFrame = true
RegisterUIPanel(lateProfessionsFrame)
flushTimers()
assert(lateProfessionsFrame:IsShown() and addon.Canvas.IsFrameOnWorkspace(lateProfessionsFrame),
    "a persisted Professions panel must reopen when its load-on-demand addon registers late")
print("PASS: late load-on-demand Professions panels honor saved open workspace state")

-- Horizontal layouts also need explicit coverage when the workspace is to the
-- right of Mainhand. Emulate the live client behavior where clearing
-- userPlaced synchronously restores the frame to Mainhand center.
for key in pairs(metrics) do metrics[key] = nil end
metrics.isSpanned = true
metrics.screenWidth, metrics.screenHeight = 4000, 1440
metrics.physicalWidth, metrics.physicalHeight = 4000, 1440
metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 0, 0, 2560, 1440
metrics.gameWidth, metrics.gameHeight = 2560, 1440
metrics.workspaceLeft, metrics.workspaceBottom = 2560, 0
metrics.workspaceRight, metrics.workspaceTop = 4000, 1440
metrics.workspaceWidth, metrics.workspaceHeight = 1440, 1440

local rightWorkspaceFrame = makeMockFrame("RightWorkspaceFrame", 500, 400)
rightWorkspaceFrame.SetUserPlaced = function(self, value)
    self.setUserPlacedFalseCalls = (self.setUserPlacedFalseCalls or 0) + (value == false and 1 or 0)
    if value == false then
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 1280, 720)
    end
end
rightWorkspaceFrame:ClearAllPoints()
rightWorkspaceFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2850, 1100)
addon.Canvas.OnPanelDragStop(rightWorkspaceFrame)
local rightSaved = addon.db.savedWorkspacePositions.RightWorkspaceFrame
assert(rightSaved and rightSaved.canvasLeft == 2560,
    "Forever must save right-workspace drag coordinates against the workspace rectangle")
assert((rightWorkspaceFrame.setUserPlacedFalseCalls or 0) == 0
        and addon.Canvas.IsFrameOnWorkspace(rightWorkspaceFrame),
    "a Forever panel dropped on the right workspace must not snap back to Mainhand")
rightWorkspaceFrame:ClearAllPoints()
rightWorkspaceFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 1280, 720)
addon.Canvas.RestoreWorkspacePosition(rightWorkspaceFrame)
assert(addon.Canvas.IsFrameOnWorkspace(rightWorkspaceFrame),
    "Forever reload restoration must return a saved frame to the right workspace")

for key in pairs(metrics) do metrics[key] = nil end
for key, value in pairs(originalMetrics) do metrics[key] = value end
print("PASS: Forever horizontal left/right workspace drops survive native userPlaced resets")

-- Forever Cooldown Viewer systems are Blizzard Edit Mode-managed even though
-- they are not protected frames. The generic rescue scanner must never move,
-- hook or make them movable; doing so taints aura tables used by Blizzard.
local cooldownViewer = makeMockFrame("EssentialCooldownViewer", 420, 90)
cooldownViewer.isManagedFrame = true
cooldownViewer.Selection = {}
cooldownViewer.system = 20
cooldownViewer:ClearAllPoints()
cooldownViewer:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 2100, -40)
table.insert(UIParent.children, cooldownViewer)
local cooldownPointCount = #cooldownViewer.points
addon.Canvas:TryMakeFrameDraggable(cooldownViewer)
flushTimers()
assert(not cooldownViewer._OffhandMovable and not cooldownViewer.movable,
    "Forever must not make Cooldown Viewer systems movable")
assert(#cooldownViewer.points == cooldownPointCount
        and cooldownViewer.points[#cooldownViewer.points][1] == "TOPLEFT",
    "Forever void rescue must not reanchor Cooldown Viewer systems")
assert(next(cooldownViewer.scripts) == nil,
    "Forever must not attach scripts to Cooldown Viewer systems")
print("PASS: Forever leaves Blizzard Cooldown Viewer systems entirely native")

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

