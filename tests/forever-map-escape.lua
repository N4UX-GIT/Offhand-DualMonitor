-- Forever World Map Escape persistence and taint boundary.
-- The map is detached from both Blizzard Escape-close mechanisms without
-- replacing its protected OnShow/OnHide scripts.

local addon = {
    isForever = true,
    modules = {},
    db = {
        enabled = true,
        persistentWorkspacePanels = true,
        independentWorkspacePanels = true,
        preventMapCloseOnMove = true,
        savedWorkspacePositions = {
            WorldMapFrame = { x = 20, y = 1200, canvasWidth = 1440, canvasHeight = 2560 },
        },
        savedMainPositions = {},
        openWorkspacePanels = {},
    },
}
local profileSnapshotWrites = 0
addon.ForeverPersistence = {
    SaveWorkspacePosition = function() end,
    ClearPosition = function() end,
    SaveOpenPanels = function() end,
    SaveProfileSnapshot = function(_, incrementRevision)
        assert(incrementRevision == true,
            "panel ownership snapshots must advance the Forever revision")
        profileSnapshotWrites = profileSnapshotWrites + 1
        return true
    end,
}

local metrics = {
    isSpanned = true,
    screenWidth = 4000, screenHeight = 2560,
    gameLeft = 1440, gameBottom = 6, gameRight = 4000, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440,
    workspaceLeft = 0, workspaceBottom = 0,
    workspaceRight = 1440, workspaceTop = 2560,
    workspaceWidth = 1440, workspaceHeight = 2560,
}
addon.Viewport = { GetMetrics = function() return metrics end }

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
}
InCombatLockdown = function() return false end
GetCVar = function() return "1" end
C_Timer = { After = function(_, fn) fn() end }

local activePanels = { left = nil, center = nil, right = nil, doublewide = nil }
GetUIPanel = function(area) return activePanels[area] end
HideUIPanel = function(frame)
    for area, panel in pairs(activePanels) do
        if panel == frame then activePanels[area] = nil end
    end
    frame:Hide()
end

local function makeMap()
    local map = {
        shown = true, width = 610, height = 438, scale = 1,
        left = 20, bottom = 762, scripts = {}, setScriptWrites = 0,
        hookScriptWrites = 0, registeredEvents = {}, maximized = false,
    }
    function map:GetName() return "WorldMapFrame" end
    function map:IsShown() return self.shown end
    function map:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function map:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function map:GetWidth() return self.width end
    function map:GetHeight() return self.height end
    function map:GetScale() return self.scale end
    function map:SetScale(value) self.scale = value end
    function map:GetEffectiveScale() return self.scale end
    function map:GetLeft() return self.left end
    function map:GetBottom() return self.bottom end
    function map:GetTop() return self.bottom + self.height end
    function map:IsMaximized() return self.maximized end
    function map:HandleUserActionMinimizeSelf()
        self.minimizeUserActions = (self.minimizeUserActions or 0) + 1
        self.maximized = false
    end
    function map:SetMovable(value) self.movable = value end
    function map:SetClampedToScreen(value) self.clamped = value end
    function map:StartMoving() self.startedMoving = true end
    function map:StopMovingOrSizing() self.startedMoving = false end
    function map:SetIgnoreParentScale() self.ignoreParentScaleWrites = (self.ignoreParentScaleWrites or 0) + 1 end
    function map:EnableMouseWheel() end
    function map:HookScript(event, fn)
        self.hookScriptWrites = self.hookScriptWrites + 1
        self.scripts[event] = fn
    end
    function map:RegisterEvent(event) self.registeredEvents[event] = true end
    function map:UnregisterEvent(event) self.registeredEvents[event] = nil end
    function map:GetScript(event) return self.scripts[event] end
    function map:SetScript(event, fn)
        self.setScriptWrites = self.setScriptWrites + 1
        self.scripts[event] = fn
    end
    function map:ClearAllPoints() end
    function map:SetPoint(_, _, _, x, y)
        self.left = x or self.left
        self.bottom = (y or (self.bottom + self.height)) - self.height
    end
    return map
end

WorldMapFrame = makeMap()
local function makeNativeControl()
    local control = { hookScriptWrites = 0 }
    function control:HookScript()
        self.hookScriptWrites = self.hookScriptWrites + 1
    end
    function control:EnableMouse() self.enableMouseWrites = (self.enableMouseWrites or 0) + 1 end
    function control:RegisterForDrag() self.dragRegistrationWrites = (self.dragRegistrationWrites or 0) + 1 end
    return control
end
WorldMapFrame.TitleContainer = makeNativeControl()
WorldMapFrame.CloseButton = makeNativeControl()
WorldMapTitleButton = makeNativeControl()
WorldMapFrameCloseButton = WorldMapFrame.CloseButton

local createdHandles = {}
CreateFrame = function(_, _, parent)
    local handle = { parent = parent, scripts = {}, layoutWrites = 0 }
    function handle:SetFrameStrata(value) self.strata = value end
    function handle:SetFrameLevel(value) self.level = value end
    function handle:EnableMouse(value) self.mouseEnabled = value; self.layoutWrites = self.layoutWrites + 1 end
    function handle:RegisterForDrag(value) self.dragButton = value end
    function handle:SetScript(event, callback) self.scripts[event] = callback end
    function handle:SetSize(width, height) self.width, self.height = width, height; self.layoutWrites = self.layoutWrites + 1 end
    function handle:ClearAllPoints() self.point = nil; self.layoutWrites = self.layoutWrites + 1 end
    function handle:SetPoint(...) self.point = { ... }; self.layoutWrites = self.layoutWrites + 1 end
    function handle:SetText(value) self.text = value end
    function handle:Show() self.shown = true; self.layoutWrites = self.layoutWrites + 1 end
    function handle:Hide() self.shown = false; self.layoutWrites = self.layoutWrites + 1 end
    table.insert(createdHandles, handle)
    return handle
end
UISpecialFrames = { "WorldMapFrame" }
UIPanelWindows = { WorldMapFrame = { area = "left", pushable = 0 } }
activePanels.left = WorldMapFrame
PlayerMovementFrameFader = {
    removed = 0,
    added = 0,
    RemoveFrame = function(frame)
        assert(frame == WorldMapFrame, "movement fader must remove only the World Map")
        PlayerMovementFrameFader.removed = PlayerMovementFrameFader.removed + 1
    end,
    AddDeferredFrame = function(frame)
        assert(frame == WorldMapFrame, "movement fader must restore only the World Map")
        PlayerMovementFrameFader.added = PlayerMovementFrameFader.added + 1
    end,
}

assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
-- Capture the real dispatcher used by the ShowUIPanel, HideUIPanel and
-- UpdateUIPanelPositions post-hooks, without copying its implementation.
local mapTransactions
local installForeverMap = addon.CanvasForeverMap.Install
addon.CanvasForeverMap.Install = function(...)
    mapTransactions = installForeverMap(...)
    return mapTransactions
end
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
dofile("tests/support/core-bridges.lua").Load(addon, { "Bridges/ClassicUIForever/Bridge.lua", "Bridges/Leatrix/Maps.lua",
    "Bridges/MapWise/Data.lua", "Bridges/MapWise/Bridge.lua", "Bridges/MoveAny/Bridge.lua", "Bridges/OpenMap/Data.lua" })
addon.Canvas:ConfigureWorldMap()
addon.Canvas.MakePanelDraggable(WorldMapFrame)

assert(#createdHandles == 2 and createdHandles[1].parent == UIParent
        and createdHandles[2].parent == UIParent,
    "Forever World Map dragging and recovery must use Offhand-owned UIParent controls")
assert(createdHandles[2].text == "Return to Windowed Map",
    "Forever's full-map recovery control must clearly describe its action")
assert(WorldMapFrame.hookScriptWrites == 0,
    "Forever World Map dragging must not hook the native map frame")
assert(WorldMapFrame.TitleContainer.hookScriptWrites == 0
        and not WorldMapFrame.TitleContainer.enableMouseWrites
        and not WorldMapFrame.TitleContainer.dragRegistrationWrites,
    "Forever World Map dragging must not mutate its native title container")
assert(WorldMapTitleButton.hookScriptWrites == 0
        and not WorldMapTitleButton.enableMouseWrites
        and not WorldMapTitleButton.dragRegistrationWrites,
    "Forever World Map dragging must not mutate its native title button")
assert(WorldMapFrame.CloseButton.hookScriptWrites == 0,
    "Forever World Map dragging must not hook its native close button")
assert(WorldMapFrame._OffhandMovable == nil and WorldMapFrame._OffhandHandle == nil
        and WorldMapFrame._OffhandDragging == nil,
    "Forever World Map bookkeeping must not be written onto the Blizzard frame")

local function AssertStableMapControls(state)
    local handle, button = createdHandles[1], createdHandles[2]
    local writes = handle.layoutWrites + button.layoutWrites
    for _ = 1, 60 do handle.scripts.OnUpdate(nil, .1) end
    assert(handle.layoutWrites + button.layoutWrites == writes,
        state .. " map repeated unchanged drag-handle or button writes")
end
AssertStableMapControls("stationary windowed")
do
    local function attachment(visible)
        local f = {insets={0,0,0,0}, clamped=false, writes=0, visible=visible}
        function f:IsForbidden() return false end
        function f:IsProtected() return false end
        function f:IsVisible() return self.visible end
        local edge = {GetHeight=function() return 4000 end, GetEffectiveScale=function() return .8 end}
        function f:GetPoint(i)
            if i == 1 then return "TOPLEFT", edge, "TOPRIGHT", 2, 0 end
            return "BOTTOMLEFT", edge, "BOTTOMRIGHT", 2, self.bottomY or 0
        end
        function f:SetPoint(_, _, _, _, y) self.bottomY = y end
        function f:GetFrameStrata() return self.strata or "MEDIUM" end
        function f:SetFrameStrata(strata) self.strata = strata end
        function f:GetLeft() return 300 end
        function f:GetParent() return WorldMapFrame end
        function f:GetEffectiveScale() return .8 end
        function f:GetClampRectInsets() return unpack(self.insets) end
        function f:SetClampRectInsets(...) self.insets={...}; self.writes=self.writes+1 end
        function f:IsClampedToScreen() return self.clamped end
        function f:SetClampedToScreen(value) self.clamped=value end
        return f
    end
    local panel, tab = attachment(true), attachment(false)
    local stage = attachment(true)
    stage.strata, stage.level = "HIGH", 1
    function stage:GetFrameLevel() return self.level end
    function stage:SetFrameLevel(level) self.level = level end
    function panel:GetFrameLevel() return 11 end
    panel.stage = stage
    SpokenPlacesPanel, SpokenPlacesPanelToggle = panel, tab
    function WorldMapFrame:IsForbidden() return false end
    function WorldMapFrame:GetRight() return self.left + self.width end
    local function tick() createdHandles[1].scripts.OnUpdate(nil, .1) end
    tick()
    assert(panel.clamped and panel.insets[2] == 3200 and not tab.clamped)
    assert(stage.strata == "DIALOG" and stage.level == 12, "keep the independent model visible")
    tick()
    assert(panel.writes == 1 and panel.bottomY == 800 and panel.strata == "DIALOG",
        "keep a stable clamp and readable Places panel on a short workspace")
    panel.visible, tab.visible = false, true
    tick()
    assert(not panel.clamped and panel.insets[2] == 0 and tab.clamped
        and panel.bottomY == 0 and panel.strata == "MEDIUM")
    assert(stage.strata == "HIGH" and stage.level == 1, "restore the provider's model layer")
    local left = WorldMapFrame.left
    WorldMapFrame.left = 2200
    tick()
    assert(not tab.clamped and tab.insets[2] == 0, "Mainhand should release the reopen tab")
    WorldMapFrame.left = left
    tick()
    tab.insets[2] = 18
    tick()
    tab.visible = false
    tick()
    assert(tab.insets[2] == 18, "leave a subsequent provider clamp intact")
    SpokenPlacesPanel, SpokenPlacesPanelToggle = nil, nil
end
do
    local originalBottom = metrics.workspaceBottom
    metrics.workspaceBottom = WorldMapFrame.bottom * WorldMapFrame:GetEffectiveScale() + 80
    local list = {offset=3, visible=true, writes=0}
    function list:IsForbidden() return false end
    function list:IsProtected() return false end
    function list:IsVisible() return self.visible end
    function list:GetNumPoints() return 2 end
    function list:GetTop() return WorldMapFrame:GetTop()-25 end
    function list:GetEffectiveScale() return 1 end
    function list:GetPoint(i)
        if i==1 then return "TOPRIGHT", WorldMapFrame, "TOPRIGHT", -3, -25 end
        return "BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -3, self.offset
    end
    function list:SetPoint(_,_,_,_,y) self.offset=y; self.writes=self.writes+1 end
    QuestMapFrame, WorldMapFrame.QuestLog = list, list
    local function tick() createdHandles[1].scripts.OnUpdate(nil,.1) end
    tick(); tick()
    assert(math.abs(list.offset-83)<.001 and list.writes==1, "fit the quest list without rewriting its settled anchor")
    list.visible=false; tick()
    assert(list.offset==3, "folding restores the provider's original bottom offset")
    QuestMapFrame, WorldMapFrame.QuestLog, metrics.workspaceBottom = nil, nil, originalBottom
end
do
    local left = WorldMapFrame.left
    local handle = createdHandles[1]
    local x = handle.point[4]
    WorldMapFrame.left = left + 20
    handle.scripts.OnUpdate(nil, .1)
    assert(math.abs(handle.point[4] - x - 20 * WorldMapFrame.scale) < .00001 and handle.mouseEnabled,
        "the active handle must follow changed map geometry")
    WorldMapFrame.left = left
    handle.scripts.OnUpdate(nil, .1)
end

-- A maximized Forever map is Blizzard-owned. Configure and the external
-- controls' OnUpdate may read that state, but must not apply the saved windowed
-- scale or position. The explicit hardware click minimizes and then restores
-- the normal workspace map in one step.
WorldMapFrame.maximized = true
WorldMapFrame.scale = 0.37
WorldMapFrame.left = 900
WorldMapFrame.bottom = 300
addon.Canvas:ConfigureWorldMap()
assert(WorldMapFrame.scale == 0.37 and WorldMapFrame.left == 900
        and WorldMapFrame.bottom == 300,
    "Forever configuration must leave Blizzard's maximized map geometry untouched")
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(createdHandles[2].shown == true,
    "The Return to Windowed Map control must be visible while Full Map is active")
AssertStableMapControls("stationary full")
assert(WorldMapFrame.scale == 0.37 and WorldMapFrame.left == 900
        and WorldMapFrame.bottom == 300,
    "The independent control update must never mutate the protected World Map")
createdHandles[2].scripts.OnClick()
assert(WorldMapFrame.maximized == false and WorldMapFrame.minimizeUserActions == 1,
    "The recovery button must use Blizzard's user-action minimize route")
assert(WorldMapFrame.scale ~= 0.37 and WorldMapFrame:GetLeft() < metrics.workspaceRight,
    "The recovery click must immediately restore the normal workspace map scale and position")
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(createdHandles[2].shown == false,
    "The recovery button must hide after the map returns to windowed mode")

createdHandles[1].scripts.OnDragStart()
assert(WorldMapFrame.startedMoving == true,
    "the isolated Forever World Map handle must retain map dragging")
createdHandles[1].scripts.OnDragStop()
assert(WorldMapFrame.startedMoving == false,
    "the isolated Forever World Map handle must stop and save the drag")
assert(WorldMapFrame._OffhandMovable == nil and WorldMapFrame._OffhandHandle == nil
        and WorldMapFrame._OffhandDragging == nil
        and WorldMapFrame._OffhandEvictingPanelSlot == nil,
    "Forever World Map drag and panel-slot state must remain addon-owned")

-- The first Mainhand-to-workspace drop after reload can receive a later
-- native TOPLEFT anchor even though the saved workspace coordinates are valid.
do
    local handle = createdHandles[1]
    local drop = assert(addon.db.savedWorkspacePositions.WorldMapFrame)
    local function putTitleAboveWorkspace()
        WorldMapFrame.bottom = metrics.workspaceTop / WorldMapFrame.scale + 100 - WorldMapFrame.height
    end
    handle.scripts.OnUpdate(nil, .016) -- the drop is initially correct
    putTitleAboveWorkspace()
    handle.scripts.OnUpdate(nil, .016)
    assert(math.abs(WorldMapFrame:GetTop() * WorldMapFrame.scale - drop.y) < .01,
        "a post-release native anchor must not strand the title until the next reopen")
    handle.scripts.OnUpdate(nil, .11) -- finish the release check
    putTitleAboveWorkspace()
    handle.scripts.OnUpdate(nil, .11)
    assert(WorldMapFrame:GetTop() * WorldMapFrame.scale > metrics.workspaceTop,
        "a completed drag must not permanently lock the map to its saved position")
    addon.Canvas.RestoreWorkspacePosition(WorldMapFrame)
end

local function isSpecial(name)
    for _, value in ipairs(UISpecialFrames) do
        if value == name then return true end
    end
    return false
end

local function pressEscapeCloseSpecialFrames()
    for _, name in ipairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end

assert(not isSpecial("WorldMapFrame"),
    "A Forever workspace map must be removed from the Escape-close registry")
assert(GetUIPanel("left") ~= WorldMapFrame,
    "A Forever workspace map must be detached from Blizzard's active panel slot")
assert(WorldMapFrame.setScriptWrites == 0,
    "Forever must not replace the World Map OnShow or OnHide scripts")
assert(WorldMapFrame.hookScriptWrites == 0,
    "Forever must not attach addon handlers to the native World Map frame")
assert((WorldMapFrame.ignoreParentScaleWrites or 0) == 0,
    "Forever must preserve the World Map's native parent-scale behavior")
addon.Canvas:UpdateMapMovementBehavior()
assert(next(WorldMapFrame.registeredEvents) == nil,
    "Forever must preserve the World Map's native event registration")
assert(PlayerMovementFrameFader.removed == 0 and PlayerMovementFrameFader.added == 0,
    "Forever keyboard UI must leave the native movement fader untouched before a switch to Gamepad UI")
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown(),
    "Escape must not close a Forever map with a saved workspace position")

-- Native Gamepad UI announces addon-originated panel lifecycle changes to its
-- protected FrameControlsManager. Only the dedicated Gamepad adapter may
-- position the map; Canvas must not configure, drag, refocus or reopen it.
WorldMapFrame:Hide()
addon.db.openWorkspacePanels.WorldMapFrame = true
local gamepadUI = true
addon.IsGamepadUIEnabled = function() return gamepadUI end
local gamepadMapToggles = 0
local previousToggleWorldMap = ToggleWorldMap
ToggleWorldMap = function()
    gamepadMapToggles = gamepadMapToggles + 1
    WorldMapFrame:Show()
end
addon.Canvas:RestorePersistentFrames()
assert(gamepadMapToggles == 0 and not WorldMapFrame:IsShown()
        and addon.db.openWorkspacePanels.WorldMapFrame == true,
    "Gamepad UI reload restoration must not open panels from addon code")

local gamepadHides = 0
local previousHideUIPanel = HideUIPanel
HideUIPanel = function(frame, ...)
    gamepadHides = gamepadHides + 1
    return previousHideUIPanel(frame, ...)
end
table.insert(UISpecialFrames, "WorldMapFrame")
local specialBefore = table.concat(UISpecialFrames, ",")
WorldMapFrame:Show()
activePanels.left = WorldMapFrame
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
assert(gamepadHides == 0 and GetUIPanel("left") == WorldMapFrame
        and WorldMapFrame:IsShown(),
    "Gamepad UI must not evict a player-opened panel from its UIPanel slot")
assert(table.concat(UISpecialFrames, ",") == specialBefore,
    "Gamepad UI must not mutate UISpecialFrames")

-- A keyboard-mode settlement can already be queued when Gamepad is enabled.
-- Exercise callbacks before the observer notices the switch, then its own grip
-- and direct entry points. Count attempts even if an outer pcall swallows errors.
local savedAfter = C_Timer.After
local queuedMapWork = {}
C_Timer.After = function(_, callback) queuedMapWork[#queuedMapWork + 1] = callback end
gamepadUI = false
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
WorldMapFrame:Show()
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(#queuedMapWork > 0, "test must schedule real keyboard map settlement")
gamepadUI = true
local mapMutations, oldMethods = 0, {}
for _, name in ipairs({ "SetScale", "ClearAllPoints", "SetPoint", "SetMovable",
    "SetClampedToScreen", "StartMoving", "StopMovingOrSizing", "SetMapID",
    "ResetZoom", "HandleUserActionMinimizeSelf" }) do
    oldMethods[name] = WorldMapFrame[name]
    WorldMapFrame[name] = function() mapMutations = mapMutations + 1 end
end
local removedBefore, addedBefore = PlayerMovementFrameFader.removed, PlayerMovementFrameFader.added
while #queuedMapWork > 0 do table.remove(queuedMapWork, 1)() end
addon.Canvas:ConfigureWorldMap()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
addon.Canvas:RefocusPersistentWorldMap()
createdHandles[1].scripts.OnUpdate(nil, 1)
createdHandles[1].scripts.OnDragStart()
createdHandles[1].scripts.OnDragStop()
AssertStableMapControls("Gamepad-owned")
WorldMapFrame.maximized = true
createdHandles[2].scripts.OnClick()
WorldMapFrame.maximized = false
assert(mapMutations == 0 and PlayerMovementFrameFader.removed == removedBefore
        and PlayerMovementFrameFader.added == addedBefore,
    "Gamepad UI must receive no Canvas map geometry, drag, content or fader writes")
assert(createdHandles[1].shown and not createdHandles[1].mouseEnabled
        and not createdHandles[2].shown,
    "keyboard map observer must remain alive with inactive controls in Gamepad mode")

-- Discord 2026-11-06: a 5120x1440 Mainhand below a 2560x1440 workspace.
-- The reporter's upper-display x offset and DPI are unknown. Exercise several
-- plausible offsets/scales, not an asserted measurement of their desktop.
-- These are simulated native panel transactions, not native focus/taint proof.
do
    local previousMetrics = metrics
    local oldWidth, oldHeight = WorldMapFrame.width, WorldMapFrame.height
    local oldScale, oldLeft, oldBottom = WorldMapFrame.scale, WorldMapFrame.left, WorldMapFrame.bottom
    local previousParentScale = UIParent.GetEffectiveScale
    local previousSlot, hidesBefore = activePanels.left, gamepadHides
    activePanels.left = WorldMapFrame
    local previousSpecial = table.concat(UISpecialFrames, ",")
    local previousRegistration = UIPanelWindows.WorldMapFrame
    local spellbook = { GetName = function() return "PlayerSpellsFrame" end }
    local cases = 0
    for _, upperLeft in ipairs({ 0, 1280, 2560 }) do
        for _, parentScale in ipairs({ 0.7, 1, 1.25 }) do
            metrics = {
                isSpanned = true, screenWidth = 5120, screenHeight = 2880,
                gameLeft = 0, gameBottom = 0, gameRight = 5120, gameTop = 1440,
                gameWidth = 5120, gameHeight = 1440,
                workspaceLeft = upperLeft, workspaceBottom = 1440,
                workspaceRight = upperLeft + 2560, workspaceTop = 2880,
                workspaceWidth = 2560, workspaceHeight = 1440,
            }
            UIParent.GetEffectiveScale = function() return parentScale end
            WorldMapFrame.left, WorldMapFrame.bottom = upperLeft + 40, 1500
            WorldMapFrame.scale = 0.73
            -- Quest-only and combined map widths can differ. Offhand must not
            -- turn that native size change into a new auto-fit scale in Gamepad.
            for _, size in ipairs({ {333, 534}, {702, 534}, {610, 438} }) do
                WorldMapFrame.width, WorldMapFrame.height = unpack(size)
                for _ = 1, 3 do
                    mapTransactions.RepairUIPanelTransaction(spellbook, true)
                    mapTransactions.RepairUIPanelTransaction(nil, true)
                    addon.Canvas:ConfigureWorldMap()
                    createdHandles[1].scripts.OnUpdate(nil, 1)
                    addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
                    while #queuedMapWork > 0 do table.remove(queuedMapWork, 1)() end
                end
                assert(mapMutations == 0 and WorldMapFrame.scale == 0.73
                    and WorldMapFrame.width == size[1] and WorldMapFrame.height == size[2],
                    "stacked Gamepad map/spellbook transactions must leave native map geometry unchanged")
                assert(gamepadHides == hidesBefore and GetUIPanel("left") == WorldMapFrame
                    and WorldMapFrame:IsShown()
                    and UIPanelWindows.WorldMapFrame == previousRegistration
                    and table.concat(UISpecialFrames, ",") == previousSpecial
                    and PlayerMovementFrameFader.removed == removedBefore
                    and PlayerMovementFrameFader.added == addedBefore,
                    "stacked Gamepad transactions must preserve native close, slot and fader ownership")
                cases = cases + 1
            end
        end
    end
    assert(cases == 27)
    metrics = previousMetrics
    activePanels.left = previousSlot
    UIParent.GetEffectiveScale = previousParentScale
    WorldMapFrame.width, WorldMapFrame.height = oldWidth, oldHeight
    WorldMapFrame.scale, WorldMapFrame.left, WorldMapFrame.bottom = oldScale, oldLeft, oldBottom
end
for _, name in ipairs({ "SetScale", "ClearAllPoints", "SetPoint", "SetMovable",
    "SetClampedToScreen", "StartMoving", "StopMovingOrSizing", "SetMapID",
    "ResetZoom", "HandleUserActionMinimizeSelf" }) do
    WorldMapFrame[name] = oldMethods[name]
end
C_Timer.After = savedAfter
gamepadUI = false
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(createdHandles[1].mouseEnabled,
    "keyboard map grip must resume after Gamepad mode without a reload")
gamepadUI = true
HideUIPanel = previousHideUIPanel
activePanels.left = nil
for i = #UISpecialFrames, 1, -1 do
    if UISpecialFrames[i] == "WorldMapFrame" then table.remove(UISpecialFrames, i) end
end
WorldMapFrame:Hide()
ToggleWorldMap = previousToggleWorldMap
gamepadUI = false

-- Ordinary restore and late registration cannot toggle the native map.
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(not createdHandles[1].mouseEnabled and createdHandles[1].point[4] == -100,
    "closing the map must park its handle outside the window")
AssertStableMapControls("closed")
addon.db.openWorkspacePanels.WorldMapFrame = true
local savedMapPosition = addon.db.savedWorkspacePositions.WorldMapFrame
local savedMapScale = WorldMapFrame:GetScale()
addon.Canvas:RestorePersistentFrames()
assert(not WorldMapFrame:IsShown() and not addon.Canvas:QueuePersistentPanelRestore(WorldMapFrame, "WorldMapFrame"),
    "neither ordinary restore nor a late panel registration may open the saved Forever map")
assert(savedMapPosition and savedMapPosition == addon.db.savedWorkspacePositions.WorldMapFrame
    and WorldMapFrame:GetScale() == savedMapScale, "restore must preserve the closed map's geometry")
assert(WorldMapFrame.setScriptWrites == 0,
    "Reload restoration must not replace protected World Map scripts")

do
    local originalMapAPI = C_Map
    local requests = 0
    C_Map = { OpenWorldMap = function() requests = requests + 1 end }
    addon.db.openWorkspacePanels.WorldMapFrame = nil
    addon.Canvas:RestorePersistentFrames("reload")
    assert(requests == 0, "a closed map stays closed after reload")
    addon.db.openWorkspacePanels.WorldMapFrame = true
    gamepadUI = true
    addon.Canvas:RestorePersistentFrames("reload")
    gamepadUI = false
    assert(requests == 0, "Gamepad UI owns its native panels")
    addon.Canvas:RestorePersistentFrames("reload")
    addon.Canvas:RestorePersistentFrames()
    assert(requests == 1 and not WorldMapFrame:IsShown(),
        "request one native open on reload without directly showing or toggling the frame")
    addon.Canvas.workspaceRestorePending = true
    addon.Canvas:RestorePersistentFrames()
    addon.Canvas:RestorePersistentFrames()
    assert(requests == 2 and not addon.Canvas.workspaceRestorePending,
        "a fresh login into a ready workspace requests its saved map exactly once")
    local originalMetrics = metrics
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    metrics = { isSpanned = false, topologyStatus = "MISMATCH" }
    addon.Canvas:SetWorkspacePanelOpen(WorldMapFrame, false)
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    addon.Canvas:RestorePersistentFrames()
    assert(addon.db.openWorkspacePanels.WorldMapFrame and requests == 2,
        "a missing workspace must retain the map without opening it on Mainhand")
    metrics = originalMetrics
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    addon.Canvas:RestorePersistentFrames()
    addon.Canvas:RestorePersistentFrames()
    assert(requests == 3, "returning the workspace must reopen the map exactly once")
    addon.Canvas:SetWorkspacePanelOpen(WorldMapFrame, false)
    metrics = { isSpanned = false, topologyStatus = "MISMATCH" }
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    metrics = originalMetrics
    addon.Canvas:RestorePersistentFrames()
    assert(requests == 3, "a map deliberately closed on Offhand stays closed on re-span")
    C_Map = originalMapAPI
end

-- Native reopening can put the map back into a UIPanel slot. Forever must not
-- repair that from a handler attached to the protected map itself. The external
-- post-toggle path performs the same restoration after Blizzard's open turn.
activePanels.left = WorldMapFrame
WorldMapFrame:Show()
assert(GetUIPanel("left") == WorldMapFrame,
    "a raw native map Show must not invoke an addon handler on Forever")
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
assert(GetUIPanel("left") ~= WorldMapFrame and WorldMapFrame:IsShown(),
    "the external post-toggle pass must detach the restored workspace map")
assert(WorldMapFrame:GetLeft() < metrics.workspaceRight,
    "the external post-toggle pass must restore workspace geometry")
assert(WorldMapFrame.setScriptWrites == 0 and WorldMapFrame.hookScriptWrites == 0,
    "map reopening and restoration must preserve protected World Map scripts")

-- Other saved workspace panels must also detach from active UIPanel slots,
-- while a hidden bag drag-stop must never resurrect the bag.
local function makePanel(name, shown, left, bottom, width, height)
    local frame = {
        shown = shown, left = left, bottom = bottom,
        width = width, height = height, scale = 1, scripts = {},
    }
    function frame:GetName() return name end
    function frame:IsShown() return self.shown end
    function frame:Show()
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetScale() return self.scale end
    function frame:GetEffectiveScale() return self.scale end
    function frame:GetLeft() return self.left end
    function frame:GetBottom() return self.bottom end
    function frame:GetTop() return self.bottom + self.height end
    function frame:ClearAllPoints() end
    function frame:SetPoint(_, _, _, x, y)
        self.left = x or self.left
        self.bottom = (y or (self.bottom + self.height)) - self.height
    end
    function frame:SetClampedToScreen() end
    function frame:SetUserPlaced() end
    function frame:StopMovingOrSizing() end
    function frame:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = function(...)
            if old then old(...) end
            fn(...)
        end
    end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:SetScript(event, fn) self.scripts[event] = fn end
    _G[name] = frame
    return frame
end

CharacterFrame = makePanel("CharacterFrame", true, 1700, 700, 520, 720)
addon.db.savedWorkspacePositions.CharacterFrame = {
    x = 80, y = 2100, canvasWidth = 1440, canvasHeight = 2560,
}
activePanels.left = CharacterFrame
addon.Canvas:RestoreWorkspacePosition(CharacterFrame)
assert(GetUIPanel("left") ~= CharacterFrame and CharacterFrame:IsShown(),
    "A restored workspace CharacterFrame must detach from active UIPanel slots")
assert(CharacterFrame:GetLeft() < metrics.workspaceRight,
    "A restored CharacterFrame must remain on the workspace")

do
    local previousTaxi, previousTimer, pending = TaxiFrame, C_Timer, {}
    TaxiFrame = makePanel("TaxiFrame", false, 0, 0, 400, 400)
    C_Timer = {After=function(_, callback) pending[#pending + 1] = callback end}
    activePanels.left = CharacterFrame
    CharacterFrame.left = 1800
    mapTransactions.RepairAfterPanelHide(TaxiFrame)
    assert(activePanels.left == CharacterFrame and #pending == 2, "taxi close must defer peer repair")
    addon._openPanelsCapturedForTransition = true
    for _, callback in ipairs(pending) do callback() end
    assert(activePanels.left == CharacterFrame and CharacterFrame:IsShown(),
        "a taxi close during exit must not evict or re-show the paper doll")
    addon._openPanelsCapturedForTransition = false
    pending = {}
    mapTransactions.RepairAfterPanelHide(TaxiFrame)
    for _, callback in ipairs(pending) do callback() end
    assert(activePanels.left ~= CharacterFrame and CharacterFrame:IsShown(),
        "an ordinary taxi close must still settle peers in the active world")
    TaxiFrame, C_Timer = previousTaxi, previousTimer
end

activePanels.left = CharacterFrame
CharacterFrame.left = 1800
WorldMapFrame:Hide()
addon.Canvas:RepairShownWorkspacePanels(WorldMapFrame)
assert(GetUIPanel("left") ~= CharacterFrame and CharacterFrame:GetLeft() < metrics.workspaceRight,
    "the external map-close pass must repair CharacterFrame instead of moving it to Mainhand")

-- Blizzard's left-panel manager reflows the already-open panel whenever a
-- second panel opens. Mainhand ownership must be reasserted for every shown
-- peer, not only for workspace panels, so opening order cannot strand one at
-- the full-canvas origin or in the Offhand workspace.
local savedWorkspaceMap = addon.db.savedWorkspacePositions.WorldMapFrame
local savedWorkspaceCharacter = addon.db.savedWorkspacePositions.CharacterFrame
addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedWorkspacePositions.CharacterFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1700, y = 1100 }
addon.db.savedMainPositions.CharacterFrame = { x = 1900, y = 1050 }
WorldMapFrame:Show()
CharacterFrame:Show()
WorldMapFrame.left, WorldMapFrame.bottom = 200, 400
CharacterFrame.left, CharacterFrame.bottom = 300, 330
addon.Canvas:RepairShownWorkspacePanels()
assert(WorldMapFrame:GetLeft() == 200
        and CharacterFrame:GetLeft() >= metrics.gameLeft,
    "generic peer repair must restore ordinary Mainhand panels without writing the dedicated World Map anchor")
assert(addon.Canvas:GetPanelController("WorldMapFrame") == "forever-world-map"
        and addon.Canvas:GetPanelController("CharacterFrame") == "generic",
    "Forever World Map and ordinary UIPanels must use separate position controllers")
addon.db.savedMainPositions.WorldMapFrame = nil
addon.db.savedMainPositions.CharacterFrame = nil
addon.db.savedWorkspacePositions.WorldMapFrame = savedWorkspaceMap
addon.db.savedWorkspacePositions.CharacterFrame = savedWorkspaceCharacter
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
addon.Canvas:RestoreWorkspacePosition(CharacterFrame)

ContainerFrameCombinedBags = makePanel(
    "ContainerFrameCombinedBags", false, 120, 400, 520, 760)
local snapshotsBeforePanelDrop = profileSnapshotWrites
addon.Canvas.OnPanelDragStop(ContainerFrameCombinedBags)
assert(not ContainerFrameCombinedBags:IsShown(),
    "A hide-triggered backpack drag stop must not reopen the backpack")
assert(profileSnapshotWrites == snapshotsBeforePanelDrop + 1,
    "ordinary Forever panel drops must commit the complete ownership snapshot")

addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true
IsBagOpen = function() return true end
addon.HasCustomBagAddon = function() return false end
local nativeBagOpens = 0
OpenAllBags = function()
    nativeBagOpens = nativeBagOpens + 1
    ContainerFrameCombinedBags:Show()
end
gamepadUI = true
addon.Canvas:RestorePersistentFrames()
assert(nativeBagOpens == 0 and addon.db.openWorkspacePanels.ContainerFrameCombinedBags == true,
    "Gamepad UI reload restoration must not open bags from addon code")
gamepadUI = false
ContainerFrameSettingsManager = { IsUsingCombinedBags = function() return true end }
addon.Canvas:ResetSeparateBagVisibilityAtLogin()
addon.Canvas:RestorePersistentFrames()
assert(nativeBagOpens > 0 and ContainerFrameCombinedBags:IsShown()
        and addon.db.savedWorkspacePositions.ContainerFrameCombinedBags ~= nil
        and addon.db.openWorkspacePanels.ContainerFrameCombinedBags == true,
    "Forever must restore an explicitly tracked native workspace backpack")

ContainerFrameCombinedBags:Hide()
do
    ContainerFrameSettingsManager.IsUsingCombinedBags = function() return false end
    local positions = addon.db.savedWorkspacePositions
    local backpack, satchel = { x = 145, y = 840 }, { x = 380, y = 840 }
    positions.ContainerFrame1, positions.ContainerFrame2 = backpack, satchel
    addon.db.nativeBackpackWorkspacePosition = backpack
    local open = addon.db.openWorkspacePanels
    open.ContainerFrame1, open.ContainerFrame2, open.SomeOtherPanel = true, true, true
    addon.HasCustomBagAddon = function() return true end
    addon.Canvas:ResetSeparateBagVisibilityAtLogin()
    assert(open.ContainerFrame1 and open.ContainerFrame2, "custom bag owners retain their visibility")
    addon.HasCustomBagAddon = function() return false end
    addon.Canvas:ResetSeparateBagVisibilityAtLogin()
    local previousOpens = nativeBagOpens
    addon.Canvas:RestorePersistentFrames("reload")
    addon.Canvas:RestorePersistentFrames()
    assert(nativeBagOpens == previousOpens and not addon.db.nativeBackpackWorkspaceOpen
        and not open.ContainerFrameCombinedBags and not open.ContainerFrame1 and not open.ContainerFrame2
        and open.SomeOtherPanel, "startup and delayed restores must leave separate bags closed")
    assert(positions.ContainerFrame1 == backpack and positions.ContainerFrame2 == satchel
        and addon.db.nativeBackpackWorkspacePosition == backpack, "separate bags retain saved positions")
    local oldChar, oldBackpack, oldSatchel = OffhandCharDB, ContainerFrame1, ContainerFrame2
    local oldToggle, oldIsOpen = ToggleBag, IsBagOpen
    OffhandCharDB = {}
    ContainerFrame1 = makePanel("ContainerFrame1", true, 145, 840, 180, 305)
    ContainerFrame2 = makePanel("ContainerFrame2", true, 380, 840, 180, 305)
    ContainerFrame1.GetID = function() return 0 end
    ContainerFrame2.GetID = function() return 3 end
    addon.CanvasBackpackState.CaptureSeparateBagsForReload(addon.Canvas)
    assert(table.concat(OffhandCharDB.separateWorkspaceBagIDs, ",") == "0,3",
        "reload must capture equipped IDs independently of their frame numbers")
    ContainerFrame1:Hide()
    ContainerFrame2:Hide()
    local toggled = {}
    IsBagOpen = function(id) return id == 3 end
    ToggleBag = function(id) toggled[#toggled + 1] = id end
    addon.Canvas.workspaceRestorePending = true
    addon.Canvas:RestorePersistentFrames()
    addon.Canvas:RestorePersistentFrames()
    assert(table.concat(toggled, ",") == "0" and nativeBagOpens == previousOpens,
        "session startup must open only missing saved bags and consume the request once")
    addon.CanvasBackpackState.CaptureSeparateBagsForReload(addon.Canvas)
    assert(#OffhandCharDB.separateWorkspaceBagIDs == 0, "closed bags must replace the old snapshot")
    ContainerFrame1:Show()
    ContainerFrame2:Show()
    local originalMetrics = metrics
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    metrics = { isSpanned = false, topologyStatus = "MISMATCH" }
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    addon.Canvas:PrepareSingleScreenRecovery(metrics)
    assert(table.concat(OffhandCharDB.separateWorkspaceBagIDs, ",") == "0,3",
        "repeated single-window layout passes must preserve the IDs captured before hiding bags")
    metrics = originalMetrics
    toggled = {}
    IsBagOpen = function() return false end
    addon.Canvas:RestorePersistentFrames()
    addon.Canvas:RestorePersistentFrames()
    assert(table.concat(toggled, ",") == "0,3", "re-span must reopen both separate bags once")
    OffhandCharDB, ContainerFrame1, ContainerFrame2 = oldChar, oldBackpack, oldSatchel
    ToggleBag, IsBagOpen = oldToggle, oldIsOpen
    positions.ContainerFrame1, positions.ContainerFrame2, open.SomeOtherPanel = nil, nil, nil
    addon.db.nativeBackpackWorkspacePosition = positions.ContainerFrameCombinedBags
    ContainerFrameSettingsManager = nil
end
addon.db.nativeBackpackWorkspaceOpen = nil
addon.db.openWorkspacePanels.ContainerFrameCombinedBags = nil
addon.db.openWorkspacePanels.EUI_MainBagFrame = true
addon.db.savedWorkspacePositions.EUI_MainBagFrame = { x = 100, y = 850 }
local nativeBagOpensBeforeStaleAddon = nativeBagOpens
addon.Canvas:RestorePersistentFrames()
assert(nativeBagOpens == nativeBagOpensBeforeStaleAddon
        and not ContainerFrameCombinedBags:IsShown(),
    "stale bag-addon open state must not resurrect a Forever workspace backpack")

addon.db.nativeBackpackWorkspaceOpen = true
addon.HasCustomBagAddon = function() return true end
local replacementToggles = 0
local nativeToggleBeforeReplacement = ToggleAllBags
ToggleAllBags = function() replacementToggles = replacementToggles + 1 end
addon.Canvas:RestorePersistentFrames()
assert(replacementToggles == 0 and nativeBagOpens == nativeBagOpensBeforeStaleAddon,
    "an old native open snapshot must not invoke a replacement provider's shared toggle")
ToggleAllBags = nativeToggleBeforeReplacement
addon.HasCustomBagAddon = function() return false end
addon.db.nativeBackpackWorkspaceOpen = nil

-- Child-frame names left by an unrelated or disabled bag addon are not native
-- backpack ownership. They must never cause Offhand to open Blizzard's bag on
-- login when the native root is explicitly saved on Mainhand.
local trackedBagWorkspace = addon.db.savedWorkspacePositions.ContainerFrameCombinedBags
ContainerFrameCombinedBags:Hide()
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = nil
addon.db.savedMainPositions.ContainerFrameCombinedBags = { x = 2100, y = 900 }
addon.db.openWorkspacePanels.ContainerFrameCombinedBags = nil
addon.db.openWorkspacePanels.Baganator_StaleChild = true
addon.db.savedWorkspacePositions.Baganator_StaleChild = { x = 80, y = 900 }
addon.db.openWorkspacePanels.EUI_MainBagFrame = true
addon.db.savedWorkspacePositions.EUI_MainBagFrame = { x = 100, y = 850 }
local bagOpensBeforeStaleRestore = nativeBagOpens
addon.Canvas:RestorePersistentFrames()
assert(nativeBagOpens == bagOpensBeforeStaleRestore
        and not ContainerFrameCombinedBags:IsShown(),
    "stale bag-addon ownership must not override an explicit Mainhand backpack")
addon.db.openWorkspacePanels.Baganator_StaleChild = nil
addon.db.savedWorkspacePositions.Baganator_StaleChild = nil
addon.db.openWorkspacePanels.EUI_MainBagFrame = nil
addon.db.savedWorkspacePositions.EUI_MainBagFrame = nil
addon.db.savedMainPositions.ContainerFrameCombinedBags = nil
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = trackedBagWorkspace
addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true

-- Forever must not replace CloseAllWindows, but its secure post-hook can repair
-- the workspace backpack after Escape and open the Game Menu. Explicit B
-- toggles must retain native close behavior.
local timers = {}
C_Timer.After = function(_, fn) table.insert(timers, fn) end
local function flushTimers()
    while #timers > 0 do table.remove(timers, 1)() end
end
hooksecurefunc = function(name, callback)
    local original = _G[name]
    _G[name] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end
GameMenuFrame = makePanel("GameMenuFrame", false, 1800, 500, 220, 420)
ContainerFrame1 = makePanel("ContainerFrame1", false, 120, 400, 260, 520)
local useCombinedBags = true
local function lateToggleGameMenu()
    if GameMenuFrame:IsShown() then GameMenuFrame:Hide() else GameMenuFrame:Show() end
end
OpenAllBags = function()
    if useCombinedBags then ContainerFrameCombinedBags:Show() else ContainerFrame1:Show() end
end
ToggleAllBags = function()
    local bag = useCombinedBags and ContainerFrameCombinedBags or ContainerFrame1
    if bag:IsShown() then
        bag:Hide()
    else
        bag:Show()
        -- Forever dismisses the Game Menu when the native backpack is opened.
        if GameMenuFrame and GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
    end
end
local function lateCloseAllBags()
    local shown = ContainerFrameCombinedBags:IsShown() or ContainerFrame1:IsShown()
    ContainerFrameCombinedBags:Hide()
    ContainerFrame1:Hide()
    return shown
end
local function lateCloseAllWindows()
    local closed = CloseAllBags()
    ToggleGameMenu()
    return closed
end
CharacterFrame._OffhandMovable = true
ContainerFrameCombinedBags._OffhandMovable = true
CloseAllBags = lateCloseAllBags
ToggleGameMenu = nil
ToggleWorldMap = function()
    if WorldMapFrame:IsShown() then
        WorldMapFrame:Hide()
    else
        -- Blizzard's full-canvas TOPLEFT default lands entirely above a
        -- bottom-aligned 1080p workspace beside a 2160p Mainhand.
        WorldMapFrame.left = 200
        WorldMapFrame.bottom = 1300
        WorldMapFrame:Show()
    end
end
ToggleQuestLog = function()
    -- Forever's L binding reaches the same map root through a different native
    -- entry point and can apply its own default anchor before post-hooks run.
    if WorldMapFrame:IsShown() then
        WorldMapFrame:Hide()
    else
        WorldMapFrame.left = 760
        WorldMapFrame.bottom = 420
        WorldMapFrame:Show()
    end
end
ToggleCharacter = function()
    if CharacterFrame:IsShown() then
        CharacterFrame:Hide()
    else
        -- Reproduce Blizzard's left-slot reflow: opening Character moves the
        -- already-visible map back toward the full-canvas origin.
        if WorldMapFrame:IsShown() then WorldMapFrame.left = 180 end
        CharacterFrame.left, CharacterFrame.bottom = 260, 320
        CharacterFrame:Show()
    end
end
addon.Canvas:EnableFreeDragging()
assert(not addon.Canvas._closeAllBagsEscapeHooked
    and not addon.Canvas._toggleGameMenuEscapeHooked,
    "Forever must not hook native bag-close or Game Menu paths")
ToggleGameMenu = lateToggleGameMenu
CloseAllWindows = lateCloseAllWindows
addon.Canvas:EnableFreeDragging()
assert(not addon.Canvas._closeAllBagsEscapeHooked
    and not addon.Canvas._toggleGameMenuEscapeHooked,
    "Later setup passes must keep native bag and Game Menu paths unhooked")
assert(not addon.Canvas._toggleQuestLogPersistenceHooked,
    "Forever's L-key path must stay outside Blizzard's protected toggle stack")

local toggleWorkspaceMap = addon.db.savedWorkspacePositions.WorldMapFrame
local toggleWorkspaceCharacter = addon.db.savedWorkspacePositions.CharacterFrame
addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedWorkspacePositions.CharacterFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1700, y = 1100 }
addon.db.savedMainPositions.CharacterFrame = { x = 1950, y = 1050 }
WorldMapFrame:Show()
CharacterFrame:Hide()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
ToggleCharacter()
assert(WorldMapFrame:GetLeft() >= metrics.gameLeft
        and CharacterFrame:GetLeft() >= metrics.gameLeft,
    "the character toggle must repair Mainhand peers before the next rendered frame")
flushTimers()
assert(WorldMapFrame:GetLeft() >= metrics.gameLeft
        and CharacterFrame:GetLeft() >= metrics.gameLeft,
    "the character toggle must repair both newly opened and reflowed Mainhand panels")
addon.db.savedMainPositions.WorldMapFrame = nil
addon.db.savedMainPositions.CharacterFrame = nil
addon.db.savedWorkspacePositions.WorldMapFrame = toggleWorkspaceMap
addon.db.savedWorkspacePositions.CharacterFrame = toggleWorkspaceCharacter
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
addon.Canvas:RestoreWorkspacePosition(CharacterFrame)

-- M and L open the same protected WorldMapFrame through different globals.
-- Both must settle at the one saved workspace anchor without native hooks.
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
ToggleQuestLog()
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetLeft() == 760,
    "the native L-key action must finish before Offhand changes map geometry")
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
assert(WorldMapFrame:IsShown() and WorldMapFrame:GetLeft() < 100,
    "the independent observer must restore L to the saved World Map location")
assert(rawget(WorldMapFrame, "_OffhandPersistentRestoreQueued") == nil
        and rawget(WorldMapFrame, "_OffhandRecoveryGeneration") == nil
        and rawget(WorldMapFrame, "_OffhandRescueGeneration") == nil
        and rawget(WorldMapFrame, "_OffhandRestoreGeneration") == nil,
    "Forever map restore bookkeeping must remain outside the native MapCanvas root")
WorldMapFrame:Hide()

-- An unsaved Forever map cannot receive a native OnShow hook without tainting
-- MapCanvas. Its external M-key post-hook must still rescue Blizzard's default
-- anchor from the non-physical area above a shorter workspace.
local originalMetrics = {}
for key, value in pairs(metrics) do originalMetrics[key] = value end
metrics.screenWidth, metrics.screenHeight = 5760, 2160
metrics.gameLeft, metrics.gameBottom = 1920, 0
metrics.gameRight, metrics.gameTop = 5760, 2160
metrics.gameWidth, metrics.gameHeight = 3840, 2160
metrics.workspaceLeft, metrics.workspaceBottom = 0, 0
metrics.workspaceRight, metrics.workspaceTop = 1920, 1080
metrics.workspaceWidth, metrics.workspaceHeight = 1920, 1080
local savedWorkspaceMap = addon.db.savedWorkspacePositions.WorldMapFrame
local savedMainMap = addon.db.savedMainPositions.WorldMapFrame
addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedMainPositions.WorldMapFrame = nil
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
ToggleWorldMap()
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
local mapLeft, mapBottom = WorldMapFrame:GetLeft(), WorldMapFrame:GetBottom()
local mapRight = mapLeft + WorldMapFrame:GetWidth() * WorldMapFrame:GetEffectiveScale()
local mapTop = mapBottom + WorldMapFrame:GetHeight() * WorldMapFrame:GetEffectiveScale()
local mapOnWorkspace = mapLeft >= metrics.workspaceLeft and mapRight <= metrics.workspaceRight
    and mapBottom >= metrics.workspaceBottom and mapTop <= metrics.workspaceTop
local mapOnMainhand = mapLeft >= metrics.gameLeft and mapRight <= metrics.gameRight
    and mapBottom >= metrics.gameBottom and mapTop <= metrics.gameTop
assert(mapOnWorkspace or mapOnMainhand,
    "the external Forever map toggle must rescue an unsaved map from mixed-height dead space")
assert(WorldMapFrame.setScriptWrites == 0 and WorldMapFrame.hookScriptWrites == 0,
    "unsaved map rescue must preserve the native Forever MapCanvas script boundary")

-- On equal-height landscape displays, Blizzard's default anchor can already
-- land entirely on Offhand. Escape protection should work before any drag.
metrics.screenWidth, metrics.screenHeight = 5120, 1440
metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 2560, 0, 5120, 1440
metrics.gameWidth, metrics.gameHeight = 2560, 1440
metrics.workspaceLeft, metrics.workspaceBottom, metrics.workspaceRight, metrics.workspaceTop = 0, 0, 2560, 1440
metrics.workspaceWidth, metrics.workspaceHeight = 2560, 1440
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
WorldMapFrame.left, WorldMapFrame.bottom = 40, 400
WorldMapFrame:Show()
activePanels.left = WorldMapFrame
table.insert(UISpecialFrames, "WorldMapFrame")
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
assert(WorldMapFrame:IsShown() and activePanels.left == nil
        and not table.concat(UISpecialFrames, ","):find("WorldMapFrame", 1, true),
    "a windowed map already on Offhand must survive Escape before its first drag")
assert(addon.db.savedWorkspacePositions.WorldMapFrame == nil,
    "protecting the visible map must not create a saved placement")

addon.db.persistentWorkspacePanels = false
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
assert(isSpecial("WorldMapFrame"),
    "turning off Escape protection must restore the close path for the detached map")
addon.db.persistentWorkspacePanels = true
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown() and not isSpecial("WorldMapFrame"),
    "turning Escape protection back on must protect the same open map")
addon.db.persistentWorkspacePanels = false
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
pressEscapeCloseSpecialFrames()
assert(not WorldMapFrame:IsShown(),
    "the windowed map must close on Escape after protection is turned off")
addon.db.persistentWorkspacePanels = true

for key in pairs(metrics) do metrics[key] = nil end
for key, value in pairs(originalMetrics) do metrics[key] = value end
addon.db.savedWorkspacePositions.WorldMapFrame = savedWorkspaceMap
addon.db.savedMainPositions.WorldMapFrame = savedMainMap

OpenAllBags()
CloseAllWindows()
flushTimers()
assert(not ContainerFrameCombinedBags:IsShown() and GameMenuFrame:IsShown(),
    "Forever Escape must retain Blizzard's native bag-close and Game Menu behavior")

-- Escape and Edit Mode transitions remain Blizzard-owned. A tracked generic
-- panel must not be reopened from ToggleGameMenu's post-hook.
addon.db.openWorkspacePanels.CharacterFrame = true
CharacterFrame:Hide()
ToggleGameMenu()
flushTimers()
assert(not CharacterFrame:IsShown(),
    "Escape must not auto-open a tracked generic Blizzard workspace panel")
GameMenuFrame:Hide()

useCombinedBags = false
ContainerFrame1:Show()
CloseAllWindows()
flushTimers()
assert(not ContainerFrame1:IsShown(),
    "Forever must leave individual native-bag Escape behavior to Blizzard")

-- MoveAny cannot observe Offhand's deliberately script-free Forever map drag
-- adapter, so the two addons would otherwise both restore WorldMapFrame after
-- M/L. MoveAny owns placement while Offhand handles Escape for the visible
-- workspace map. The saved Offhand position remains dormant.
local moveAnyWorkspacePosition = addon.db.savedWorkspacePositions.WorldMapFrame
local moveAnyOpenState = addon.db.openWorkspacePanels.WorldMapFrame
addon.db.openWorkspacePanels.WorldMapFrame = true
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
MoveAny = {}
assert(addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Forever must yield WorldMapFrame ownership when MoveAny is loaded")
assert(addon.Canvas:GetCompatibilityDiagnostics()
        == "MoveAny=loaded | WorldMapOwner=MoveAny",
    "diagnostics must identify MoveAny as the live Forever map owner")

local savedScale, savedLeft, savedBottom = 0.73, 811, 477
WorldMapFrame.scale = savedScale
WorldMapFrame.left = savedLeft
WorldMapFrame.bottom = savedBottom
addon.Canvas:ConfigureWorldMap()
addon.Canvas:RestoreWorkspacePosition(WorldMapFrame)
assert(WorldMapFrame.scale == savedScale and WorldMapFrame.left == savedLeft
        and WorldMapFrame.bottom == savedBottom,
    "Offhand must not scale or anchor MoveAny's Forever World Map")
addon.Canvas:RestorePersistentFrames()
flushTimers()
assert(not WorldMapFrame:IsShown(),
    "Offhand reload restoration must not open a World Map owned by MoveAny")

createdHandles[1].scripts.OnUpdate(nil, 1)
assert(createdHandles[1].shown and not createdHandles[1].mouseEnabled
        and createdHandles[1].point[4] == -100,
    "MoveAny's map must keep its noninteractive observer for the next opening")

table.insert(UISpecialFrames, "WorldMapFrame")
ToggleWorldMap()
activePanels.left = WorldMapFrame
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(WorldMapFrame:IsShown() and WorldMapFrame.left == 200
        and WorldMapFrame.bottom == 1300,
    "M must retain MoveAny/native map geometry before deferred compatibility hooks")
flushTimers()
assert(WorldMapFrame:IsShown() and WorldMapFrame.left == 200
        and WorldMapFrame.bottom == 1300,
    "Offhand's installed M post-hook must stay inert while MoveAny owns the map")
assert(GetUIPanel("left") ~= WorldMapFrame,
    "a MoveAny workspace map must free the panel slot used by NPC windows")
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown(), "a MoveAny workspace map must survive Escape")
addon.db.persistentWorkspacePanels = false
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(isSpecial("WorldMapFrame"), "turning Escape protection off must return the map to native Escape")
addon.db.persistentWorkspacePanels = true
createdHandles[1].scripts.OnUpdate(nil, 1)
WorldMapFrame:Hide()
createdHandles[1].scripts.OnUpdate(nil, 1)
ToggleQuestLog()
createdHandles[1].scripts.OnUpdate(nil, 1)
flushTimers()
assert(WorldMapFrame:IsShown() and WorldMapFrame.left == 760
        and WorldMapFrame.bottom == 420,
    "Offhand's installed L post-hook must stay inert while MoveAny owns the map")
assert(addon.db.savedWorkspacePositions.WorldMapFrame == moveAnyWorkspacePosition,
    "yielding to MoveAny must preserve the user's dormant Offhand map position")

do
    local previousMap = WorldMapFrame
    local observerIndex = #createdHandles + 1
    WorldMapFrame = makeMap()
    WorldMapFrame:Hide()
    addon.db.savedWorkspacePositions.WorldMapFrame = nil
    addon.Canvas:EnableFreeDragging()
    local observer = assert(createdHandles[observerIndex], "MoveAny already loaded must receive a map observer")
    assert(observer.shown and not observer.mouseEnabled, "the observer must park while MoveAny positions the map")
    table.insert(UISpecialFrames, "WorldMapFrame")
    ToggleWorldMap()
    activePanels.left = WorldMapFrame
    observer.scripts.OnUpdate(nil, 1)
    assert(not isSpecial("WorldMapFrame") and activePanels.left ~= WorldMapFrame,
        "a vendor-positioned workspace map needs Escape protection without a saved Offhand anchor")
    ToggleWorldMap()
    assert(not WorldMapFrame:IsShown(), "the map binding must still close a MoveAny workspace map")
    assert(not addon.db.savedWorkspacePositions.WorldMapFrame
        and WorldMapFrame.hookScriptWrites == 0 and WorldMapFrame.setScriptWrites == 0,
        "the compatibility path must leave placement and native map scripts with their owners")
    WorldMapFrame = previousMap
    addon.db.savedWorkspacePositions.WorldMapFrame = moveAnyWorkspacePosition
end

MoveAny = nil
local originalAddOns = C_AddOns
for _, externalOwner in ipairs({"OpenMap", "Leatrix_Maps"}) do
C_AddOns = { IsAddOnLoaded = function(name) return name == externalOwner end }
createdHandles[1]:Show()
WorldMapFrame:Hide()
-- A hidden frame never receives OnUpdate in the client. Do not manually call a
-- hidden observer, which previously concealed this closed-at-start failure.
if createdHandles[1].shown then createdHandles[1].scripts.OnUpdate(nil, 1) end
WorldMapFrame.left, WorldMapFrame.bottom, WorldMapFrame.scale = 200, 1300, 0.83
table.insert(UISpecialFrames, "WorldMapFrame")
activePanels.left = WorldMapFrame
WorldMapFrame:Show()
if createdHandles[1].shown then createdHandles[1].scripts.OnUpdate(nil, 1) end
flushTimers()
assert(createdHandles[1].shown == true and createdHandles[1].mouseEnabled == false
        and createdHandles[1].width == 1 and createdHandles[1].point[4] == -100,
    externalOwner .. " must keep an invisible noninteractive observer alive while retaining native dragging")
assert(not isSpecial("WorldMapFrame") and GetUIPanel("left") ~= WorldMapFrame,
    externalOwner .. " opening after a hidden map must detach both Escape close paths")
assert(addon.db.openWorkspacePanels.WorldMapFrame,
    "Forever's external observer must retain external-map workspace open intent")
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown(), externalOwner .. " workspace map must survive Escape")
if externalOwner == "OpenMap" then
    -- Native panel layout can register the visible map again after the first
    -- protection pass. OpenMap retains the same geometry across the reflow.
    activePanels.left = WorldMapFrame
    table.insert(UISpecialFrames, "WorldMapFrame")
    createdHandles[1].scripts.OnUpdate(nil, 1)
    assert(activePanels.left ~= WorldMapFrame and not isSpecial("WorldMapFrame"),
        "OpenMap must recover Escape protection after native registration changes at the same position")
    pressEscapeCloseSpecialFrames()
    assert(WorldMapFrame:IsShown() and WorldMapFrame.left == 200
        and WorldMapFrame.bottom == 1300 and WorldMapFrame.scale == 0.83,
        "restoring Escape protection must preserve OpenMap's visible placement")
    local originalHide, attempts = HideUIPanel, 0
    HideUIPanel = function(frame)
        assert(frame == WorldMapFrame)
        attempts = attempts + 1
    end
    activePanels.left = WorldMapFrame
    createdHandles[1].scripts.OnUpdate(nil, 1)
    createdHandles[1].scripts.OnUpdate(nil, 1)
    assert(attempts == 1 and activePanels.left == WorldMapFrame,
        "a refused native detach must not trigger another write on every observation")
    HideUIPanel = originalHide
    activePanels.left = nil
    createdHandles[1].scripts.OnUpdate(nil, 1)
    activePanels.left = WorldMapFrame
    createdHandles[1].scripts.OnUpdate(nil, 1)
    assert(activePanels.left ~= WorldMapFrame, "a new close path must permit another detach attempt")
end
WorldMapFrame.left = 2000
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(isSpecial("WorldMapFrame"), externalOwner .. " dragging to Mainhand must restore native Escape closure")
WorldMapFrame.left = 200
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(not isSpecial("WorldMapFrame"), externalOwner .. " dragging back without closing must restore persistence")
addon.db.persistentWorkspacePanels = false
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(isSpecial("WorldMapFrame"), "turning external-map persistence off must restore Escape closure")
addon.db.persistentWorkspacePanels = true
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(not isSpecial("WorldMapFrame"), "turning external-map persistence on must not require reopening the map")
local stableFaderWrites = PlayerMovementFrameFader.removed
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(PlayerMovementFrameFader.removed == stableFaderWrites,
    "unchanged external-map observations must not repeatedly rewrite persistence state")
local originalCombatCheck = InCombatLockdown
InCombatLockdown = function() return true end
WorldMapFrame.left = 2000
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(not isSpecial("WorldMapFrame"), "external drag persistence changes must defer during combat")
InCombatLockdown = originalCombatCheck
createdHandles[1].scripts.OnUpdate(nil, 1)
assert(isSpecial("WorldMapFrame"), "external drag persistence must settle after combat without another show edge")
WorldMapFrame.left = 200
createdHandles[1].scripts.OnUpdate(nil, 1)
WorldMapFrame:Hide()
local originalMapAPI = C_Map
local openRequests = 0
C_Map = { OpenWorldMap = function()
    openRequests = openRequests + 1
    WorldMapFrame:Show()
end }
addon.Canvas:RestorePersistentFrames()
assert(openRequests == 0, "ordinary layout repairs must not open an external map")
addon.Canvas:RestorePersistentFrames("reload")
flushTimers()
assert(openRequests == 1 and WorldMapFrame:IsShown() and WorldMapFrame.left == 200
    and WorldMapFrame.bottom == 1300 and WorldMapFrame.scale == 0.83,
    "Forever reload must request visibility once and preserve the external owner's geometry")
C_Map = originalMapAPI
assert(WorldMapFrame.hookScriptWrites == 0 and WorldMapFrame.setScriptWrites == 0,
    "external map observation must not add or replace protected map scripts")
end
C_AddOns = originalAddOns
addon.db.openWorkspacePanels.WorldMapFrame = moveAnyOpenState
assert(not addon.Canvas:ShouldYieldWorldMap(WorldMapFrame),
    "Offhand must resume Forever map ownership when MoveAny is absent")
WorldMapFrame:Hide()

addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1600, y = 1000 }
addon.Canvas:ConfigureWorldMap()
assert(isSpecial("WorldMapFrame"),
    "A map on Mainhand must return to Blizzard's Escape-close registry")
assert(PlayerMovementFrameFader.removed == 0 and PlayerMovementFrameFader.added == 0,
    "Forever map placement and persistence must leave the native movement fader untouched")
pressEscapeCloseSpecialFrames()
assert(not WorldMapFrame:IsShown(),
    "Escape must retain native close behavior for a Mainhand map")

do
    local inCombat, pending, timers = true, {}, {}
    local previousCombat, previousAfter = InCombatLockdown, C_Timer.After
    InCombatLockdown = function() return inCombat end
    addon.RunOrQueueCombat = function(_, fn) pending[#pending + 1] = fn end
    C_Timer.After = function(_, fn) timers[#timers + 1] = fn end
    WorldMapFrame:Show()
    local previousRepair = addon.Canvas.RepairCombatWorldMapAnchor
    addon.db.keepMapToggleOpen = true
    local repairs = 0
    addon.Canvas.RepairCombatWorldMapAnchor = function(_, map)
        repairs = repairs + 1
        map.left = 12
    end
    local observe = createdHandles[1].scripts.OnUpdate
    observe(nil, 0.016)
    WorldMapFrame.left = 260 -- Blizzard's second layout after the native open
    observe(nil, 0.016)
    assert(WorldMapFrame.left == 12 and repairs == 2, "repair the opening and reflow on consecutive rendered frames")
    observe(nil, 1)
    assert(repairs == 2, "stop repairing once the initial combat layout has settled")
    addon.Canvas.RepairCombatWorldMapAnchor = previousRepair
    addon.db.keepMapToggleOpen = nil
    for _ = 1, 12 do
        mapTransactions.RepairUIPanelTransaction(nil, true)
        while #timers > 0 do table.remove(timers, 1)() end
    end
    assert(#pending == 1, "repeated panel transactions must retain only one combat map retry")
    inCombat = false
    pending[1]()
    assert(#timers == 1, "regeneration must settle after the native frame handlers")
    table.remove(timers, 1)()
    assert(#timers > 0, "the native post-combat reflow needs the same bounded retries as a panel transaction")
    while #timers > 0 do table.remove(timers, 1)() end
    assert(WorldMapFrame:IsShown(), "combat settlement must preserve the latest map visibility")
    WorldMapFrame:Hide()
    InCombatLockdown, C_Timer.After, addon.RunOrQueueCombat = previousCombat, previousAfter, nil
end

do
    -- A keyboard map can grow once when dropped onto a larger workspace. AUTO
    -- must settle, while a numeric preference must retain the chosen size.
    addon.db.savedMainPositions.WorldMapFrame = nil
    addon.db.savedWorkspacePositions.WorldMapFrame = {x=20,y=1200}
    addon.db.workspaceMapScale = "AUTO"
    addon.Canvas:ConfigureWorldMap()
    local fitted = WorldMapFrame:GetScale()
    for _ = 1, 5 do
        addon.Canvas:ConfigureWorldMap()
        assert(WorldMapFrame:GetScale() == fitted, "workspace auto-fit grew repeatedly")
    end
    addon.db.workspaceMapScale = .83
    addon.Canvas:ConfigureWorldMap()
    assert(WorldMapFrame:GetScale() == .83, "explicit keyboard map scale was replaced by auto-fit")
end
do
    assert(loadfile("Core/MapScale.lua"))("Offhand", addon)
    local settings = addon.MapScale
    assert(settings:Set(.70) and WorldMapFrame:GetScale() == .70,
        "settings did not resize the native workspace map")
    assert(addon.db.workspaceMapScale == .70)
    assert(settings:Set("AUTO") and addon.db.workspaceMapScale == "AUTO",
        "Auto Fit was overwritten by numeric display synchronization")
    addon.db.savedWorkspacePositions.WorldMapFrame = nil
    addon.db.savedMainPositions.WorldMapFrame = {x=1800,y=1000}
    assert(settings:Set(.85) and WorldMapFrame:GetScale() == .85,
        "Mainhand settings wrote the workspace preference instead")
    assert(addon.db.mainMapScale == .85 and addon.db.workspaceMapScale == "AUTO")
    assert(settings:Set("AUTO") and addon.db.mainMapScale == "AUTO")
    local fitted = WorldMapFrame:GetScale()
    assert(fitted > 1)
    addon.Canvas:ConfigureWorldMap()
    assert(WorldMapFrame:GetScale() == fitted, "Mainhand AUTO failed to settle")
end
do
    -- MapWise can replay its canvas-relative anchor during any compact layout.
    -- The workspace is a 1080 x 1920 portrait monitor below Mainhand.
    metrics.screenWidth, metrics.screenHeight = 2560, 3360
    metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop = 0, 1920, 2560, 3360
    metrics.gameWidth, metrics.gameHeight = 2560, 1440
    metrics.workspaceLeft, metrics.workspaceBottom = 700, 0
    metrics.workspaceRight, metrics.workspaceTop = 1780, 1920
    metrics.workspaceWidth, metrics.workspaceHeight = 1080, 1920
    local oldUIWidth, oldUIHeight = UIParent.GetWidth, UIParent.GetHeight
    UIParent.GetWidth = function() return metrics.screenWidth end
    UIParent.GetHeight = function() return metrics.screenHeight end

    local map = WorldMapFrame
    local observer = createdHandles[1].scripts.OnUpdate
    local elapsed, pending = 0, {}
    local oldAfter, oldAddOns = C_Timer.After, C_AddOns
    C_Timer.After = function(delay, callback)
        pending[#pending + 1] = { due = elapsed + delay, callback = callback }
    end
    local function advanceMap(ticks)
        for _ = 1, ticks do
            elapsed = elapsed + .11
            observer(nil, .11)
            while true do
                local nextIndex
                for index, entry in ipairs(pending) do
                    if entry.due <= elapsed and (not nextIndex or entry.due < pending[nextIndex].due) then
                        nextIndex = index
                    end
                end
                if not nextIndex then break end
                table.remove(pending, nextIndex).callback()
            end
        end
    end
    local function moveMap(left, top)
        map.left = left / map.scale
        map.bottom = top / map.scale - map.height
    end
    local function mapBounds()
        local scale = map:GetEffectiveScale()
        local left, top = map:GetLeft() * scale, map:GetTop() * scale
        return left, top, left + map:GetWidth() * scale, top - map:GetHeight() * scale
    end
    local function assertMapFits(message)
        local left, top, right, bottom = mapBounds()
        assert(map:IsShown() and left >= metrics.workspaceLeft - .001
            and right <= metrics.workspaceRight + .001 and top <= metrics.workspaceTop + .001
            and bottom >= metrics.workspaceBottom - .001, message)
    end

    local compactPosition = { x = .32, y = .18 }
    local passiveVendorWrites = 0
    local vendor = { windowOrigin = {} }
    function vendor:Compact() return not map:IsMaximized() end
    function vendor:UpdateWindowResetIcon() end
    function vendor:PlaceWindow(left, fromTop)
        moveMap(left, UIParent:GetHeight() - fromTop)
    end
    function vendor:ApplyWindowPosition()
        local position = MapWiseAtlasDB.compactPosition
        if not position then return end
        passiveVendorWrites = passiveVendorWrites + 1
        self:PlaceWindow(position.x * UIParent:GetWidth(), position.y * UIParent:GetHeight())
    end
    local function assertPassiveReplayBlocked(message)
        local left, top = mapBounds()
        local writes = passiveVendorWrites
        vendor:ApplyWindowPosition()
        local afterLeft, afterTop = mapBounds()
        assert(left == afterLeft and top == afterTop and passiveVendorWrites == writes, message)
    end
    local function assertVendorReplay(message)
        local writes = passiveVendorWrites
        vendor:ApplyWindowPosition()
        local left, top = mapBounds()
        assert(passiveVendorWrites == writes + 1
            and math.abs(left - compactPosition.x * metrics.screenWidth) < .001
            and math.abs(top - (1 - compactPosition.y) * metrics.screenHeight) < .001, message)
    end
    MapWiseAtlasDB = { rightClosed = true, compactPosition = compactPosition }
    MapWiseAPI = { version = "2.3.98", db = MapWiseAtlasDB, Integration = { native = map }, MapWiseUI = vendor }
    C_AddOns = { IsAddOnLoaded = function(name) return name == "MapWise" end }
    local savedPosition = { x = 1080, y = 1200 }
    addon.db.savedMainPositions.WorldMapFrame = nil
    addon.db.savedWorkspacePositions.WorldMapFrame = savedPosition
    addon.db.workspaceMapScale = 1
    map:Hide()
    advanceMap(4)
    map.width, map.height, map.scale = 664, 470, 1
    moveMap(savedPosition.x, savedPosition.y)
    map:Show()
    assertPassiveReplayBlocked("first-open MapWise layout must not replay its anchor over saved Offhand placement")
    advanceMap(4)
    assertMapFits("the compact MapWise map must begin on the saved portrait workspace")

    MapWiseAtlasDB.rightClosed = false
    map.width = 1087
    assertPassiveReplayBlocked("expanding the sidebar must not synchronously move the map to MapWise's stale anchor")
    advanceMap(1)
    assertMapFits("MapWise sidebar expansion must fit even if the saved anchor did not move")
    assert(map.width == 1087 and map:GetScale() < addon.db.workspaceMapScale,
        "Offhand must fit the expanded map without changing MapWise's native dimensions")
    moveMap(savedPosition.x, metrics.workspaceTop + 90)
    assertPassiveReplayBlocked("a follow-up MapWise layout must defer even after a native anchor write")
    advanceMap(8)
    assertMapFits("a deferred native anchor write must not pull the expanded map off the workspace")

    for _, tab in ipairs({"environment", "search", "quests", "route"}) do
        MapWiseAtlasDB.modernTab = tab
        assertPassiveReplayBlocked("switching to MapWise tab " .. tab .. " must preserve the saved Offhand position immediately")
        advanceMap(1)
    end
    pressEscapeCloseSpecialFrames()
    assertPassiveReplayBlocked("a MapWise layout after Escape must not flash at the stale anchor")
    advanceMap(8)
    assertMapFits("the persistent map must stay on its saved workspace after Escape")

    MapWiseAtlasDB.rightClosed = true
    map.width = 664
    assertPassiveReplayBlocked("closing the sidebar must not move the map through its stale anchor")
    advanceMap(8)
    local restoredLeft, restoredTop = mapBounds()
    assert(math.abs(restoredLeft - savedPosition.x) < .001 and math.abs(restoredTop - savedPosition.y) < .001
        and map:GetScale() == 1, "closing the sidebar must recover the saved anchor and preferred scale")
    assert(addon.db.savedWorkspacePositions.WorldMapFrame == savedPosition
        and savedPosition.x == 1080 and savedPosition.y == 1200 and addon.db.workspaceMapScale == 1,
        "sidebar fits must not rewrite the saved Offhand position or scale preference")

    map:Hide()
    advanceMap(4)
    addon.db.savedWorkspacePositions.WorldMapFrame = nil
    map.width, map.scale = 664, 1
    moveMap(1080, 1200)
    map:Show()
    MapWiseAtlasDB.compactPosition = nil
    vendor:ApplyWindowPosition()
    MapWiseAtlasDB.compactPosition = compactPosition
    advanceMap(4)
    assertMapFits("MapWise's own drag can place a compact map on Offhand without an Offhand record")
    assertPassiveReplayBlocked("same-size tab layout must preserve an already-visible unsaved workspace placement")

    MapWiseAtlasDB.rightClosed = false
    map.width = 1087
    assertPassiveReplayBlocked("sidebar expansion must preserve an unsaved workspace placement before the next frame")
    advanceMap(8)
    assertMapFits("MapWise sidebar expansion must preserve an unsaved workspace placement")
    local _, unsavedTop = mapBounds()
    assert(math.abs(unsavedTop - 1200) < .001,
        "MapWise's spanned anchor must not replace the previous workspace height")
    assert(addon.db.savedWorkspacePositions.WorldMapFrame == nil
        and addon.db.savedMainPositions.WorldMapFrame == nil
        and addon.db.openWorkspacePanels.WorldMapFrame == nil
        and MapWiseAtlasDB.compactPosition == compactPosition
        and compactPosition.x == .32 and compactPosition.y == .18,
        "sidebar recovery must not invent a saved placement or change MapWise's position")

    local idleAnchorWrites, idleScaleWrites = 0, 0
    local setPoint, setScale = map.SetPoint, map.SetScale
    map.SetPoint = function(self, ...)
        idleAnchorWrites = idleAnchorWrites + 1
        setPoint(self, ...)
    end
    map.SetScale = function(self, ...)
        idleScaleWrites = idleScaleWrites + 1
        setScale(self, ...)
    end
    advanceMap(12)
    assert(idleAnchorWrites == 0 and idleScaleWrites == 0 and #pending == 0,
        "MapWise sidebar recovery must settle without ongoing map writes or timers")
    assert(map.setScriptWrites == 0 and map.hookScriptWrites == 0,
        "MapWise sidebar recovery must retain the native map's script boundary")
    map.SetPoint, map.SetScale = setPoint, setScale

    vendor.dragging = true
    vendor:PlaceWindow(1300, 400)
    advanceMap(8)
    local draggedLeft, draggedTop = mapBounds()
    assert(math.abs(draggedLeft - 1300) < .001 and math.abs(draggedTop - 2960) < .001,
        "the adapter must allow an explicit MapWise drag while preserving passive-layout ownership")
    vendor.dragging = nil

    map:Hide()
    advanceMap(4)
    local mainPosition = { x = 1500, y = 3000 }
    addon.db.savedMainPositions.WorldMapFrame = mainPosition
    addon.db.mainMapScale = 1
    map.width, map.scale = 664, 1
    moveMap(mainPosition.x, mainPosition.y)
    map:Show()
    assertPassiveReplayBlocked("reopening the map must not flash at the stale MapWise anchor on Mainhand")
    advanceMap(4)
    assertPassiveReplayBlocked("same-size tab layout must preserve an Offhand-saved Mainhand anchor")
    MapWiseAtlasDB.rightClosed = true
    assertPassiveReplayBlocked("Mainhand sidebar layout must retain the saved Mainhand anchor")
    advanceMap(8)
    local mainLeft, mainTop = mapBounds()
    assert(mainLeft == mainPosition.x and mainTop == mainPosition.y and map:GetScale() == 1
        and addon.db.savedMainPositions.WorldMapFrame == mainPosition,
        "MapWise layout must preserve the Mainhand position and its saved record")

    addon.db.enabled = false
    assertVendorReplay("disabled Offhand must let MapWise replay its own position")
    addon.db.enabled = true
    map:Hide()
    advanceMap(4)
    addon.db.savedMainPositions.WorldMapFrame = nil
    map:Show()
    assertVendorReplay("a fresh unsaved Mainhand map must retain MapWise's native placement")
    advanceMap(4)
    MapWiseAtlasDB.rightClosed = false
    map.width = 1087
    assertPassiveReplayBlocked("an already-visible unsaved Mainhand map must retain its current anchor")
    advanceMap(8)

    C_Timer.After, C_AddOns = oldAfter, oldAddOns
    UIParent.GetWidth, UIParent.GetHeight = oldUIWidth, oldUIHeight
    MapWiseAtlasDB, MapWiseAPI = nil, nil
end
do
    local selected, reserved, combat = true, false, false
    local panel, binding, owner
    local baseBinding = "TOGGLEGAMEMENU"
    local previousShowUIPanel = ShowUIPanel
    ShowUIPanel = function(frame)
        if frame == GameMenuFrame then ContainerFrameCombinedBags:Hide() end
        frame:Show()
    end
    RegisterGameMenuEscHandler = function() error("must retain Blizzard's secure Escape handler list") end
    GetUIPanel = function() return panel end
    UnitExists = function() return selected end
    InCombatLockdown = function() return combat end
    GetBindingAction = function() return binding or baseBinding end
    SetOverrideBindingClick = function(frame, priority, key, name, button)
        assert(priority and key == "ESCAPE" and name == frame:GetName() and button == "LeftButton")
        owner, binding = frame, "CLICK " .. name .. ":" .. button
    end
    ClearOverrideBindings = function(frame) assert(frame == owner); binding = nil end
    RegisterStateDriver = function(frame, state, condition)
        assert(state == "combat" and condition == "[combat] combat; nocombat")
        assert(frame.attributes["_onstate-combat"]:find("self:ClearBindings()",1,true))
    end
    CreateFrame = function(kind, name, parent, template)
        assert(kind == "Button" and parent == UIParent
            and (template == "SecureActionButtonTemplate,SecureHandlerStateTemplate"
                or template == "SecureHandlerStateTemplate"))
        return {
            attributes={}, scripts={},
            GetName=function() return name end,
            SetAttribute=function(self,key,value) self.attributes[key]=value end,
            SetScript=function(self,key,value) self.scripts[key]=value end,
            RegisterForClicks=function(_,clicks) assert(clicks == "AnyUp") end,
        }
    end
    addon.IsBlizzardInputReserved = function() return reserved end
    addon.HasCustomBagAddon = function() return false end
    addon.Mainhand, addon.IsGamepadUIEnabled = nil, nil
    addon.Viewport.GetMetrics = function() return metrics end
    addon.db.enabled, addon.db.persistentWorkspacePanels = true, true
    UISpecialFrames = {}
    GameMenuFrame.shown = false
    ContainerFrame1:Hide()
    ContainerFrameCombinedBags.left, ContainerFrameCombinedBags.bottom = metrics.workspaceLeft + 20, 400
    function ContainerFrameCombinedBags:IsForbidden() return false end
    function ContainerFrameCombinedBags:IsVisible() return self.shown end
    ContainerFrameCombinedBags:Show()
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape() and binding,
        "an Offhand native bag with a target must offer the secure target-clear action")
    assert(owner.attributes.type == "target" and owner.attributes.unit == "none"
        and owner.attributes.useOnKeyDown == false, "Blizzard's secure action must clear the target on key release")
    selected = false
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape()
        and binding == "CLICK OffhandForeverBagWindowEscape:LeftButton",
        "with just the bag open, Escape must be able to open the menu without closing bags")
    selected, panel = true, CharacterFrame
    panel:Show()
    local priorProfession = ProfessionsFrame
    local priorPosition = addon.db.savedWorkspacePositions.ProfessionsFrame
    ProfessionsFrame = makePanel("ProfessionsFrame", true, metrics.workspaceLeft + 20, 400, 180, 240)
    addon.db.savedWorkspacePositions.ProfessionsFrame = {x=20, y=400}
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape() and not binding,
        "a visible crafting session must retain its native Escape handler with the backpack open")
    ProfessionsFrame = priorProfession
    addon.db.savedWorkspacePositions.ProfessionsFrame = priorPosition
    local closes = 0
    CloseWindows = function()
        closes = closes + 1
        if panel then panel:Hide() end
        for _, name in pairs(UISpecialFrames) do _G[name]:Hide() end
    end
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape()
        and binding == "CLICK OffhandForeverBagWindowEscape:LeftButton",
        "Escape must dismiss a native panel before clearing the target")
    owner.scripts.OnClick()
    assert(closes == 1 and not panel:IsShown() and selected and ContainerFrameCombinedBags:IsShown(),
        "native panel dismissal must keep the bag visible and retain the target")
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape()
        and binding == "CLICK OffhandForeverBagTargetEscape:LeftButton",
        "the next Escape must reach the secure target action")
    panel = nil
    UISpecialFrames = {"CharacterFrame"}
    CharacterFrame:Show()
    selected = false
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape()
        and binding == "CLICK OffhandForeverBagWindowEscape:LeftButton",
        "special windows must close without closing Offhand bags even without a target")
    local windowOwner = owner
    windowOwner.scripts.OnClick()
    assert(closes == 2 and not CharacterFrame:IsShown() and ContainerFrameCombinedBags:IsShown(),
        "special-window dismissal must not flash the native bag")
    windowOwner.scripts.OnClick()
    assert(closes == 2, "a stale window binding must not run another native close transaction")
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape(), "the next Escape should open the menu")
    windowOwner.scripts.OnClick()
    assert(GameMenuFrame:IsShown() and ContainerFrameCombinedBags:IsVisible() and closes == 2,
        "opening the menu must not run a close-and-reopen transaction on bags")
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape() and not binding,
        "an open Game Menu must retain its native dismissal")
    GameMenuFrame:Hide()
    -- Inspect may already be visible when INSPECT_READY calls ShowUIPanel.
    -- Blizzard then skips slot registration and CloseWindows cannot find it.
    local priorInspect = InspectFrame
    InspectFrame = makePanel("InspectFrame", true, metrics.gameLeft + 20, 400, 240, 320)
    function InspectFrame:IsForbidden() return false end
    function InspectFrame:IsVisible() return self.shown end
    selected = true
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape() and owner == windowOwner,
        "visible slotless Inspect must have priority over target clearing")
    windowOwner.scripts.OnClick()
    assert(not InspectFrame:IsShown() and selected and ContainerFrameCombinedBags:IsVisible()
        and closes == 2, "close just the detached inspection through its native dismissal")
    assert(addon.Canvas:RefreshForeverNativeBagTargetEscape()
        and binding == "CLICK OffhandForeverBagTargetEscape:LeftButton",
        "the target must remain reachable on the next Escape")
    InspectFrame = priorInspect
    selected = true
    UISpecialFrames = {}
    GetCurrentKeyBoardFocus = function() return true end
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "text input must retain Escape priority")
    GetCurrentKeyBoardFocus = nil
    CharacterFrame:Show()
    panel = CharacterFrame
    StaticPopup1 = makePanel("StaticPopup1", true, 1800, 400, 260, 520)
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "a popup must retain priority over panel dismissal")
    StaticPopup1 = nil
    combat = true
    windowOwner.scripts.OnClick()
    assert(closes == 2 and panel:IsShown(), "an outstanding window click must yield in combat")
    combat, panel = false, nil
    CharacterFrame:Hide()
    reserved = true
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "reserved input must retain native handling")
    reserved = false
    baseBinding = "SCREENSHOT"
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "a custom Escape binding must be respected")
    baseBinding = "TOGGLEGAMEMENU"
    ContainerFrame2 = makePanel("ContainerFrame2", true, 1800, 400, 260, 520)
    function ContainerFrame2:IsForbidden() return false end
    function ContainerFrame2:IsVisible() return self.shown end
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "a Mainhand bag must retain native dismissal")
    ContainerFrame2:Hide()
    ContainerFrameCombinedBags.left = 1800
    assert(not addon.Canvas:RefreshForeverNativeBagTargetEscape(), "Mainhand must retain native Escape handling")
    ShowUIPanel = previousShowUIPanel
end
print("PASS: Forever map placement, Escape persistence, and native bag secure target binding")
