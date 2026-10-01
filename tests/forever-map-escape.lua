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
    local handle = { parent = parent, scripts = {} }
    function handle:SetFrameStrata(value) self.strata = value end
    function handle:SetFrameLevel(value) self.level = value end
    function handle:EnableMouse(value) self.mouseEnabled = value end
    function handle:RegisterForDrag(value) self.dragButton = value end
    function handle:SetScript(event, callback) self.scripts[event] = callback end
    function handle:SetSize(width, height) self.width, self.height = width, height end
    function handle:ClearAllPoints() self.point = nil end
    function handle:SetPoint(...) self.point = { ... } end
    function handle:SetText(value) self.text = value end
    function handle:Show() self.shown = true end
    function handle:Hide() self.shown = false end
    table.insert(createdHandles, handle)
    return handle
end
UISpecialFrames = { "WorldMapFrame" }
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

assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
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
assert(PlayerMovementFrameFader.removed > 0 and PlayerMovementFrameFader.added == 0,
    "A Forever workspace map must be removed from Blizzard's movement-dimming fader")
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown(),
    "Escape must not close a Forever map with a saved workspace position")

-- Reload restoration must reopen the saved workspace map without replacing
-- Blizzard's protected scripts.
WorldMapFrame:Hide()
addon.db.openWorkspacePanels.WorldMapFrame = true
addon.Canvas:RestorePersistentFrames()
assert(WorldMapFrame:IsShown(),
    "Forever reload restoration must reopen the saved World Map")
assert(WorldMapFrame.setScriptWrites == 0,
    "Reload restoration must not replace protected World Map scripts")

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

activePanels.left = CharacterFrame
CharacterFrame.left = 1800
WorldMapFrame:Hide()
addon.Canvas:RepairShownWorkspacePanels(WorldMapFrame)
assert(GetUIPanel("left") ~= CharacterFrame and CharacterFrame:GetLeft() < metrics.workspaceRight,
    "the external map-close pass must repair CharacterFrame instead of moving it to Mainhand")

ContainerFrameCombinedBags = makePanel(
    "ContainerFrameCombinedBags", false, 120, 400, 520, 760)
addon.Canvas.OnPanelDragStop(ContainerFrameCombinedBags)
assert(not ContainerFrameCombinedBags:IsShown(),
    "A hide-triggered backpack drag stop must not reopen the backpack")

addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true
IsBagOpen = function() return true end
addon.HasCustomBagAddon = function() return true end
local nativeBagOpens = 0
OpenAllBags = function()
    nativeBagOpens = nativeBagOpens + 1
    ContainerFrameCombinedBags:Show()
end
addon.Canvas:RestorePersistentFrames()
assert(nativeBagOpens == 1 and ContainerFrameCombinedBags:IsShown(),
    "Saved native backpack restore must override early false custom-bag detection and stale IsBagOpen state")

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
WorldMapFrame._OffhandMovable = true
CharacterFrame._OffhandMovable = true
ContainerFrameCombinedBags._OffhandMovable = true
CloseAllBags = lateCloseAllBags
ToggleGameMenu = nil
addon.Canvas:EnableFreeDragging()
assert(addon.Canvas._closeAllBagsEscapeHooked
    and not addon.Canvas._toggleGameMenuEscapeHooked,
    "Each direct Forever Escape hook must install independently when available")
ToggleGameMenu = lateToggleGameMenu
CloseAllWindows = lateCloseAllWindows
addon.Canvas:EnableFreeDragging()
assert(addon.Canvas._closeAllBagsEscapeHooked
    and addon.Canvas._toggleGameMenuEscapeHooked,
    "A later addon-load pass must install both direct Forever Escape hooks")

addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true
CloseAllBags()
flushTimers()
assert(addon.db.openWorkspacePanels.ContainerFrameCombinedBags == true,
    "A standalone Forever startup CloseAllBags call must not erase the saved open request")
OpenAllBags()
CloseAllWindows()
flushTimers()
assert(ContainerFrameCombinedBags:IsShown() and GameMenuFrame:IsShown(),
    "First Escape must preserve the workspace backpack and open the Game Menu")
CloseAllWindows()
flushTimers()
assert(ContainerFrameCombinedBags:IsShown() and not GameMenuFrame:IsShown(),
    "Second Escape must preserve the workspace backpack while closing the Game Menu")
ToggleAllBags()
flushTimers()
assert(not ContainerFrameCombinedBags:IsShown(),
    "B must still close a workspace backpack explicitly")

useCombinedBags = false
ContainerFrame1:Show()
addon.Canvas:PrepareNativeBackpackFrame(ContainerFrame1)
addon.Canvas:SetWorkspacePanelOpen(ContainerFrame1, true)
CloseAllWindows()
flushTimers()
assert(ContainerFrame1:IsShown() and GameMenuFrame:IsShown(),
    "Escape must preserve the individual workspace backpack and open the Game Menu")
CloseAllWindows()
flushTimers()
assert(ContainerFrame1:IsShown() and not GameMenuFrame:IsShown(),
    "Second Escape must preserve individual bags while closing the Game Menu")
ToggleAllBags()
flushTimers()
assert(not ContainerFrame1:IsShown(),
    "B must still close individual workspace bags explicitly")

addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1600, y = 1000 }
addon.Canvas:ConfigureWorldMap()
assert(isSpecial("WorldMapFrame"),
    "A map on Mainhand must return to Blizzard's Escape-close registry")
assert(PlayerMovementFrameFader.added > 0,
    "A Mainhand map must return to Blizzard's native movement fader")
pressEscapeCloseSpecialFrames()
assert(not WorldMapFrame:IsShown(),
    "Escape must retain native close behavior for a Mainhand map")

print("PASS: Forever map persists through reload/Escape without script replacement")
