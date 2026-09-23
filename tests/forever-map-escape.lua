-- Forever World Map Escape persistence.
-- The map is detached from both Blizzard Escape-close mechanisms, so it can
-- remain open without replacing CloseAllWindows or mutating UIPanelWindows.

local addon = {
    isForever = true,
    modules = {},
    db = {
        enabled = true,
        persistentWorkspacePanels = true,
        preventMapCloseOnMove = true,
        savedWorkspacePositions = {
            WorldMapFrame = { x = 20, y = 1200, canvasWidth = 1440, canvasHeight = 2560 },
        },
        savedMainPositions = {},
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

addon.db.savedWorkspacePositions.WorldMapFrame = nil
addon.db.savedMainPositions.WorldMapFrame = { x = 1600, y = 1000 }
addon.Canvas:ConfigureWorldMap()
assert(isSpecial("WorldMapFrame"),
    "A map on Mainhand must return to Blizzard's Escape-close registry")
pressEscapeCloseSpecialFrames()
assert(not WorldMapFrame:IsShown(),
    "Escape must retain native close behavior for a Mainhand map")

print("PASS: Forever workspace map remains open through Escape without global overrides")
