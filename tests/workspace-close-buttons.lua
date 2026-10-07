-- Workspace-only close button visibility must be reversible and must not hook
-- protected Blizzard controls.

local addon = {
    db = {
        enabled = true,
        hideWorkspaceCloseButtons = false,
        hideWorkspaceMapMaximizeButton = false,
        savedWorkspacePositions = {},
        baganatorWorkspacePanels = {},
    },
}
_G.Offhand = addon

local metrics = { isSpanned = true }
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Canvas = {
    IsFrameOnWorkspace = function(frame) return frame.onWorkspace == true end,
}

local inCombat = false
InCombatLockdown = function() return inCombat end

local function makeButton(alpha, mouse)
    local button = { alpha = alpha or 1, mouse = mouse ~= false, hookWrites = 0 }
    function button:SetAlpha(value) self.alpha = value end
    function button:GetAlpha() return self.alpha end
    function button:EnableMouse(value) self.mouse = value == true end
    function button:IsMouseEnabled() return self.mouse end
    function button:IsForbidden() return false end
    function button:HookScript() self.hookWrites = self.hookWrites + 1 end
    return button
end

local function makeFrame(name, workspace, button)
    local frame = { name = name, onWorkspace = workspace, shown = true, CloseButton = button }
    function frame:GetName() return self.name end
    function frame:IsVisible() return self.shown end
    function frame:IsForbidden() return false end
    return frame
end

local eventFrame
CreateFrame = function()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:SetScript(_, fn) self.handler = fn end
    return eventFrame
end
C_Timer = {
    After = function(_, fn) fn() end,
    NewTicker = function(_, fn) return { callback = fn, Cancel = function() end } end,
}

local mapClose = makeButton(0.75, true)
local mapMaximize = makeButton(1, true)
WorldMapFrame = makeFrame("WorldMapFrame", true, mapClose)
WorldMapFrame.BorderFrame = { MaximizeMinimizeFrame = { MaximizeButton = mapMaximize } }
WorldMapFrameCloseButton = mapClose
local characterClose = makeButton(1, true)
CharacterFrame = makeFrame("CharacterFrame", false, characterClose)
CharacterFrameCloseButton = characterClose

local baganatorClose = makeButton(1, true)
local baganatorName = "Baganator_SingleViewBackpackViewFrameblizzard_black"
_G[baganatorName] = makeFrame(baganatorName, true, baganatorClose)
_G[baganatorName .. "CloseButton"] = baganatorClose

local euiClose = makeButton(1, true)
function euiClose:GetObjectType() return "Button" end
local euiHeader = {}
function euiHeader:GetChildren() return euiClose end
function euiClose:GetPoint() return "RIGHT", euiHeader, "RIGHT", 0, 0 end
EUI_MainBagFrame = makeFrame("EUI_MainBagFrame", true, nil)
EUI_MainBagFrame.Header = euiHeader

assert(loadfile("Core/WorkspaceChrome.lua"))("Offhand", addon)
local chrome = addon.WorkspaceChrome

chrome:Refresh()
assert(mapClose.alpha == 0.75 and mapClose.mouse,
    "disabled option must not alter a workspace close button")
assert(mapMaximize.alpha == 1 and mapMaximize.mouse,
    "disabled map option must not alter the enlarge button")

chrome:SetEnabled(true)
assert(mapClose.alpha == 0 and not mapClose.mouse,
    "workspace World Map close button must become invisible and non-interactive")
assert(mapMaximize.alpha == 1 and mapMaximize.mouse,
    "close-button option must not implicitly hide the separate map enlarge control")
assert(baganatorClose.alpha == 0 and not baganatorClose.mouse,
    "workspace Baganator close button must be detected lazily")
assert(euiClose.alpha == 0 and not euiClose.mouse,
    "anonymous EllesmereUI header close button must be supported")
assert(characterClose.alpha == 1 and characterClose.mouse,
    "Mainhand close buttons must remain available")
assert(mapClose.hookWrites == 0,
    "workspace chrome must not attach scripts to protected native controls")
mapClose.alpha, mapClose.mouse = 1, true
chrome:Refresh()
assert(mapClose.alpha == 0 and not mapClose.mouse,
    "polling must reapply the hidden state after a native panel refresh")

chrome:SetMapMaximizeEnabled(true)
assert(mapMaximize.alpha == 0 and not mapMaximize.mouse,
    "workspace World Map enlarge button must hide when its distinct option is enabled")
assert(mapMaximize.hookWrites == 0,
    "workspace chrome must not attach scripts to the native map enlarge control")
mapMaximize.alpha, mapMaximize.mouse = 1, true
chrome:Refresh()
assert(mapMaximize.alpha == 0 and not mapMaximize.mouse,
    "polling must reapply the hidden map-enlarge state after a native map refresh")

WorldMapFrame.onWorkspace = false
CharacterFrame.onWorkspace = true
chrome:Refresh()
assert(mapClose.alpha == 0.75 and mapClose.mouse,
    "moving a frame to Mainhand must restore its original close-button state")
assert(mapMaximize.alpha == 1 and mapMaximize.mouse,
    "moving the map to Mainhand must restore its enlarge button")
assert(characterClose.alpha == 0 and not characterClose.mouse,
    "moving a supported frame into the workspace must hide its close button")

inCombat = true
CharacterFrame.onWorkspace = false
chrome:Refresh()
assert(characterClose.alpha == 0 and not characterClose.mouse,
    "combat refresh must leave protected-risk chrome unchanged")
inCombat = false
chrome:Refresh()
assert(characterClose.alpha == 1 and characterClose.mouse,
    "post-combat refresh must restore Mainhand chrome")

chrome:SetEnabled(false)
assert(baganatorClose.alpha == 1 and baganatorClose.mouse
        and euiClose.alpha == 1 and euiClose.mouse,
    "disabling the option must restore every button Offhand changed")
assert(mapMaximize.alpha == 1 and mapMaximize.mouse,
    "the independent map option must remain harmless while the map is on Mainhand")

WorldMapFrame.onWorkspace = true
chrome:Refresh()
assert(mapClose.alpha == 0.75 and mapClose.mouse,
    "map-enlarge-only mode must leave the World Map close button available")
assert(mapMaximize.alpha == 0 and not mapMaximize.mouse,
    "map-enlarge-only mode must hide only the requested control")

chrome:SetMapMaximizeEnabled(false)
assert(mapMaximize.alpha == 1 and mapMaximize.mouse,
    "disabling the map option must restore its original state")

metrics.isSpanned = false
addon.db.hideWorkspaceCloseButtons = true
chrome:Refresh()
assert(mapClose.alpha == 0.75 and mapClose.mouse,
    "single-screen recovery must keep native close buttons available")

print("PASS: workspace-only close buttons hide reversibly without native control hooks")
