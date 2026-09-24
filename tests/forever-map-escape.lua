-- Forever World Map Escape persistence.
-- The map is detached from both Blizzard Escape-close mechanisms, so it can
-- remain open without replacing CloseAllWindows or mutating UIPanelWindows.

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
        left = 20, bottom = 762, scripts = {},
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
    function map:SetIgnoreParentScale() end
    function map:EnableMouseWheel() end
    function map:HookScript(event, fn) self.scripts[event] = fn end
    function map:GetScript(event) return self.scripts[event] end
    function map:SetScript(event, fn) self.scripts[event] = fn end
    function map:ClearAllPoints() end
    function map:SetPoint(_, _, _, x, y)
        self.left = x or self.left
        self.bottom = (y or (self.bottom + self.height)) - self.height
    end
    return map
end

WorldMapFrame = makeMap()
UISpecialFrames = { "WorldMapFrame" }
activePanels.left = WorldMapFrame

assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
addon.Canvas:ConfigureWorldMap()

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
pressEscapeCloseSpecialFrames()
assert(WorldMapFrame:IsShown(),
    "Escape must not close a Forever map with a saved workspace position")

-- Native reopening can put the map back into a UIPanel slot. Its OnShow repair
-- must detach and restore the workspace map before the next Escape press.
activePanels.left = WorldMapFrame
WorldMapFrame:Show()
assert(GetUIPanel("left") ~= WorldMapFrame and WorldMapFrame:IsShown(),
    "Reopening a saved workspace map must not leave it in an Escape-close panel slot")

-- Other saved workspace panels must also be detached from active UIPanel slots.
-- Map panel transitions must repair CharacterFrame instead of reclaiming it on
-- Mainhand, and a hidden bag drag-stop must never resurrect the bag.
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
    "A restored workspace CharacterFrame must be detached from active UIPanel slots")
assert(CharacterFrame:GetLeft() < metrics.workspaceRight,
    "A restored CharacterFrame must remain on the workspace")

activePanels.left = CharacterFrame
CharacterFrame.left = 1800
WorldMapFrame:Hide()
assert(GetUIPanel("left") ~= CharacterFrame and CharacterFrame:GetLeft() < metrics.workspaceRight,
    "Closing the map must repair CharacterFrame instead of moving it to Mainhand")

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
local function lateToggleGameMenu()
    if GameMenuFrame:IsShown() then GameMenuFrame:Hide() else GameMenuFrame:Show() end
end
OpenAllBags = function() ContainerFrameCombinedBags:Show() end
ToggleAllBags = function()
    if ContainerFrameCombinedBags:IsShown() then
        ContainerFrameCombinedBags:Hide()
    else
        ContainerFrameCombinedBags:Show()
        -- Forever dismisses the Game Menu when the native backpack is opened.
        if GameMenuFrame and GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
    end
end
local function lateCloseAllBags()
    local shown = ContainerFrameCombinedBags:IsShown()
    ContainerFrameCombinedBags:Hide()
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

addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1600, y = 1000 }
addon.Canvas:ConfigureWorldMap()
assert(isSpecial("WorldMapFrame"),
    "A map on Mainhand must return to Blizzard's Escape-close registry")
pressEscapeCloseSpecialFrames()
assert(not WorldMapFrame:IsShown(),
    "Escape must retain native close behavior for a Mainhand map")

print("PASS: Forever workspace map remains open through Escape without global overrides")
