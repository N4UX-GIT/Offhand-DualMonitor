-- Forever native bag movement must be provided by an addon-owned sibling
-- without installing any script, hook, or field on the protected bag tree.

local addon = {
    isForever = true,
    modules = {},
    db = {
        enabled = true,
        savedWorkspacePositions = {
            ContainerFrameCombinedBags = {
                x = 120, y = 900,
                canvasWidth = 1440, canvasHeight = 1440,
                canvasLeft = 0, canvasBottom = 0,
            },
        },
        savedMainPositions = {},
        openWorkspacePanels = { ContainerFrameCombinedBags = true },
        nativeBackpackWorkspacePosition = {
            x = 120, y = 900,
            canvasWidth = 1440, canvasHeight = 1440,
            canvasLeft = 0, canvasBottom = 0,
        },
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
    workspaceLeft = 0, workspaceRight = 1440,
    workspaceBottom = 0, workspaceTop = 1440,
    workspaceWidth = 1440, workspaceHeight = 1440,
    gameLeft = 1440, gameRight = 4000,
    gameBottom = 0, gameTop = 1440,
}
addon.Viewport = { GetMetrics = function() return metrics end }
InCombatLockdown = function() return false end
local unitCombat = false
UnitAffectingCombat = function(unit) return unit == "player" and unitCombat end

UIParent = {
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetEffectiveScale = function() return 1 end,
}

GameMenuFrame = {
    shown = false,
    IsShown = function(self) return self.shown end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}
local mouseFoci = {}
GetMouseFoci = function() return mouseFoci end
local optionFrameOpen = false
IsOptionFrameOpen = function() return optionFrameOpen and 1 or nil end
Settings = {
    OpenToCategory = function()
        ToggleAllBags()
        optionFrameOpen = true
    end,
}
C_SettingsUtil = {
    OpenSettingsPanel = function()
        ToggleAllBags()
        optionFrameOpen = true
    end,
}

hooksecurefunc = function(target, method, callback)
    if type(target) == "string" then
        callback = method
        local original = _G[target]
        _G[target] = function(...)
            local results = { original(...) }
            callback(...)
            return unpack(results)
        end
    else
        local original = target[method]
        target[method] = function(self, ...)
            local results = { original(self, ...) }
            callback(self, ...)
            return unpack(results)
        end
    end
end

local function makeFrame(name, width, height)
    local frame = {
        name = name, width = width or 300, height = height or 500,
        shown = false, points = {}, scripts = {},
        nativeHookCalls = 0, nativeScriptCalls = 0,
        nativeMouseCalls = 0, nativeDragRegistrations = 0,
    }
    function frame:GetName() return self.name end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:GetEffectiveScale() return 1 end
    function frame:GetScale() return self.scale or 1 end
    function frame:SetScale(value) self.scale = value end
    function frame:IsShown() return self.shown end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(point, relativeTo, relativePoint, x, y)
        self.points[1] = { point, relativeTo, relativePoint, x or 0, y or 0 }
    end
    function frame:GetLeft() return self.points[1] and self.points[1][4] or nil end
    function frame:GetTop() return self.points[1] and self.points[1][5] or nil end
    function frame:GetBottom()
        local top = self:GetTop()
        return top and top - self.height or nil
    end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index or 1] or {}) end
    function frame:SetMovable() self.movableCalls = (self.movableCalls or 0) + 1 end
    function frame:StartMoving() self.startMovingCalls = (self.startMovingCalls or 0) + 1 end
    function frame:StopMovingOrSizing() self.stopMovingCalls = (self.stopMovingCalls or 0) + 1 end
    function frame:HookScript() self.nativeHookCalls = self.nativeHookCalls + 1 end
    function frame:SetScript(name, fn)
        self.nativeScriptCalls = self.nativeScriptCalls + 1
        self.scripts[name] = fn
    end
    function frame:EnableMouse() self.nativeMouseCalls = self.nativeMouseCalls + 1 end
    function frame:RegisterForDrag() self.nativeDragRegistrations = self.nativeDragRegistrations + 1 end
    return frame
end

local created = {}
CreateFrame = function(_, name, parent)
    local frame = makeFrame(name, 100, 24)
    frame.parent = parent
    function frame:SetFrameStrata() end
    function frame:SetFrameLevel() end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    created[#created + 1] = frame
    if name then _G[name] = frame end
    return frame
end

local bag = makeFrame("ContainerFrameCombinedBags", 420, 620)
bag.CloseButton = {}
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2200, 1100)
bag:Show()
_G.ContainerFrameCombinedBags = bag
CloseAllBags = function() bag:Hide() end
local nativeOpenerDeclinesHiddenLogicalState = false
local nativePanelBlocksBagAPIs = false
ToggleAllBags = function()
    if nativePanelBlocksBagAPIs then
        bag:Hide()
    elseif nativeOpenerDeclinesHiddenLogicalState then
        nativeOpenerDeclinesHiddenLogicalState = false
        bag:Hide()
    else
        CloseAllBags()
    end
end
ToggleBackpack = function()
    if bag:IsShown() then bag:Hide() else bag:Show() end
end
local targetSelected = false
UnitExists = function(unit) assert(unit == "target"); return targetSelected end
local nativeToggleGameMenuCalls = 0
ToggleGameMenu = function()
    nativeToggleGameMenuCalls = nativeToggleGameMenuCalls + 1
    if bag:IsShown() then
        CloseAllBags()
        return
    end
    if targetSelected then targetSelected = false; return end
    if GameMenuFrame:IsShown() then
        GameMenuFrame:Hide()
    else
        GameMenuFrame:Show()
    end
end

assert(loadfile("Core/MainhandGeometry.lua"))("Offhand", addon)
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
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
assert(addon.Canvas:EnableForeverNativeBagProxy(),
    "Forever bag proxy controller was not created")

local controller = _G.OffhandForeverNativeBagController
assert(controller and controller.parent == UIParent,
    "Forever bag controller must be owned by UIParent")

-- First span has no bag placement history. Blizzard's native bottom-right
-- anchor follows the entire canvas, which need not be a visible display.
local initialDB, initialMetrics = addon.db, metrics
addon.db = { enabled = true }
metrics = {
    isSpanned = true, screenWidth = 6000, screenHeight = 2032,
    gameLeft = 0, gameRight = 3440, gameBottom = 592, gameTop = 2032,
    workspaceLeft = 3440, workspaceRight = 6000,
    workspaceBottom = 0, workspaceTop = 1440,
    workspaceWidth = 2560, workspaceHeight = 1440,
}
ContainerFrameCombinedBags = nil
controller.scripts.OnUpdate(controller, 0.001)
ContainerFrameCombinedBags = bag
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 9000, 9000)
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:GetLeft() >= metrics.workspaceLeft + 12
        and bag:GetLeft() + bag:GetWidth() <= metrics.workspaceRight - 12
        and bag:GetTop() <= metrics.workspaceTop - 12
        and bag:GetBottom() >= metrics.workspaceBottom + 12,
    "first-span combined bags must open visibly without saved positions or window Restore")
assert(not addon.db.nativeBackpackWorkspacePosition,
    "a default opening must not invent a player-saved bag position")

-- Reopening after Blizzard reanchors must use the same visible default.
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 9000, 9000)
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:GetLeft() + bag:GetWidth() <= metrics.workspaceRight - 12,
    "unsaved native bag reopen must not require manually moving the bag first")

-- A bottom-right canvas void also exists with Mainhand on the right and the
-- workspace higher on the left. Use the workspace rectangle, not UIParent.
metrics.gameLeft, metrics.gameRight = 2560, 6000
metrics.gameBottom, metrics.gameTop = 592, 2032
metrics.workspaceLeft, metrics.workspaceRight = 0, 2560
metrics.workspaceBottom, metrics.workspaceTop = 592, 2032
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:GetLeft() >= 12 and bag:GetLeft() + bag:GetWidth() <= 2548
        and bag:GetBottom() >= 604,
    "first-span bags must fit a vertically offset left workspace too")

local initialHeight = bag.height
bag.height = 1800
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:GetTop() <= metrics.workspaceTop - 12,
    "an oversized combined bag must retain a reachable title on the visible display")
bag.height = initialHeight

-- Effective scales differ on a real span. Root anchor arguments are local to
-- the bag, while the display rectangles are in UIParent units.
local initialBagScale, initialParentScale = bag.GetEffectiveScale, UIParent.GetEffectiveScale
bag.GetEffectiveScale = function() return 0.75 end
UIParent.GetEffectiveScale = function() return 0.496 end
controller.scripts.OnUpdate(controller, 0.001)
local firstSpanFactor = 0.75 / 0.496
assert(bag:GetLeft() * firstSpanFactor >= metrics.workspaceLeft + 12 - 0.01
        and (bag:GetLeft() + bag:GetWidth()) * firstSpanFactor <= metrics.workspaceRight - 12 + 0.01
        and bag:GetTop() * firstSpanFactor <= metrics.workspaceTop - 12 + 0.01
        and bag:GetBottom() * firstSpanFactor >= metrics.workspaceBottom + 12 - 0.01,
    "first-span default bag placement must convert effective scales exactly once")
bag.GetEffectiveScale, UIParent.GetEffectiveScale = initialBagScale, initialParentScale

-- The same default works for the individual backpack presentation.
ContainerFrameCombinedBags, ContainerFrame1 = nil, makeFrame("ContainerFrame1", 178, 300)
ContainerFrame1:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 9000, 9000)
ContainerFrame1:Show()
controller.scripts.OnUpdate(controller, 0.001)
assert(ContainerFrame1:GetLeft() >= metrics.workspaceLeft + 12
        and ContainerFrame1:GetLeft() + ContainerFrame1:GetWidth() <= metrics.workspaceRight - 12
        and ContainerFrame1:GetBottom() >= metrics.workspaceBottom + 12,
    "individual Blizzard backpack must also open visibly on its first span")
ContainerFrame1:Hide()
controller.scripts.OnUpdate(controller, 0.001)
ContainerFrame1, ContainerFrameCombinedBags = nil, bag

local function AssertDefaultYield(label)
    bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 9000, 9000)
    controller.scripts.OnUpdate(controller, 0.001)
    assert(bag:GetLeft() == 9000 and bag:GetTop() == 9000,
        "first-span placement must yield during " .. label)
end
addon.db.enabled = false
AssertDefaultYield("disabled addon")
addon.db.enabled = true
metrics.isSpanned = false
AssertDefaultYield("single-screen layout")
metrics.isSpanned = true
InCombatLockdown = function() return true end
AssertDefaultYield("combat")
InCombatLockdown = function() return false end
Bagnon = {}
AssertDefaultYield("replacement bag ownership")
Bagnon = nil
addon.Mainhand = {IsNativeGamepadInterface = function() return true end}
AssertDefaultYield("native Gamepad ownership")
addon.Mainhand = nil
addon.db, metrics = initialDB, initialMetrics
controller.scripts.OnUpdate(controller, 0.11)

assert(bag.nativeHookCalls == 0 and bag.nativeScriptCalls == 0
        and bag.nativeMouseCalls == 0 and bag.nativeDragRegistrations == 0,
    "proxy setup must not install input or scripts on the native bag")
local restored = bag.points[1]
assert(restored and restored[1] == "TOPLEFT" and restored[2] == UIParent
        and math.abs(restored[4] - 120) < 0.01 and math.abs(restored[5] - 900) < 0.01,
    "proxy controller did not restore the saved native bag root position")

unitCombat = true
local gatherOK, gatherWhy, gatherMoved = addon.Canvas:GatherSafeUIToMainhand()
assert(not gatherOK and gatherWhy == "combat" and gatherMoved == 0,
    "Canvas recovery ignored player combat while lockdown state lagged")
unitCombat = false

-- Recovery must transfer both the visible native bag and its persistence
-- ownership to Mainhand. A raw SetPoint without this cleanup appears to work
-- until the bag is reopened, when the proxy restores the stale workspace
-- snapshot.
gatherOK, gatherWhy, gatherMoved = addon.Canvas:GatherSafeUIToMainhand()
assert(gatherOK and not gatherWhy and gatherMoved == 1,
    "Mainhand recovery did not count the tracked native bag")
assert(profileSnapshotWrites == 1,
    "Mainhand recovery must commit its ownership transfer before a reload")
assert(addon.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil
        and addon.db.nativeBackpackWorkspacePosition == nil,
    "Mainhand recovery left native bag workspace ownership behind")
assert(addon.db.savedMainPositions.ContainerFrameCombinedBags
        and addon.db.savedMainPositions.ContainerFrameCombinedBags.x >= metrics.gameLeft,
    "Mainhand recovery did not persist the native bag's recovered position")
bag:Hide()
bag:Show()
controller.scripts.OnUpdate(controller, 0.11)
assert(bag:GetLeft() >= metrics.gameLeft,
    "reopened native bag returned to its retired workspace position")

-- Forever can mark ordinary UIPanels protected. The recovery button is a
-- hardware action, so known UIPanels may move while Edit Mode/HUD frames stay
-- excluded by Canvas' stricter ownership checks.
local character = makeFrame("CharacterFrame", 430, 600)
character:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200, 1000)
character:Show()
function character:IsProtected() return true end
local map = makeFrame("WorldMapFrame", 700, 500)
map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 500, 1100)
map:Show()
function map:IsProtected() return true end
_G.CharacterFrame, _G.WorldMapFrame = character, map
local forbidden = makeFrame("ForbiddenPanel", 300, 300)
function forbidden:IsForbidden() error("forbidden object") end
_G.ForbiddenPanel = forbidden
UIPanelWindows = { CharacterFrame = {}, WorldMapFrame = {}, ForbiddenPanel = {} }
addon.db.savedWorkspacePositions.CharacterFrame = { x = 200, y = 1000 }
addon.db.savedWorkspacePositions.WorldMapFrame = { x = 500, y = 1100 }
addon.db.openWorkspacePanels.CharacterFrame = true
addon.db.openWorkspacePanels.WorldMapFrame = true

local gatherSkipped
gatherOK, gatherWhy, gatherMoved, gatherSkipped = addon.Canvas:GatherSafeUIToMainhand()
assert(gatherOK and not gatherWhy and gatherMoved == 2 and gatherSkipped == 1,
    "Mainhand recovery did not move and count protected ordinary UIPanels")
assert(profileSnapshotWrites == 2,
    "ordinary UIPanel recovery must commit the complete ownership snapshot")
assert(addon.db.savedWorkspacePositions.CharacterFrame == nil
        and addon.db.savedWorkspacePositions.WorldMapFrame == nil,
    "Mainhand recovery retained ordinary UIPanel workspace ownership")
assert(character:GetLeft() >= metrics.gameLeft and map:GetLeft() >= metrics.gameLeft,
    "Mainhand recovery did not place ordinary UIPanels inside the game viewport")
character:Hide()
character:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 200, 1000)
character:Show()
addon.Canvas:RestoreWorkspacePosition(character)
assert(character:GetLeft() >= metrics.gameLeft,
    "reopened Character frame returned to its retired workspace position")

-- Restore the workspace fixture for the proxy drag lifecycle checks below.
local workspaceBagPosition = {
    x = 120, y = 900,
    canvasWidth = 1440, canvasHeight = 1440,
    canvasLeft = 0, canvasBottom = 0,
}
addon.db.savedWorkspacePositions.ContainerFrameCombinedBags = workspaceBagPosition
addon.db.savedMainPositions.ContainerFrameCombinedBags = nil
addon.db.openWorkspacePanels.ContainerFrameCombinedBags = true
addon.db.nativeBackpackWorkspacePosition = workspaceBagPosition
addon.db.nativeBackpackWorkspaceOpen = true
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 120, 900)

local handle
for _, frame in ipairs(created) do
    if frame ~= controller and frame.parent == UIParent and frame.scripts.OnDragStart then
        handle = frame
        break
    end
end
assert(handle and handle.scripts.OnDragStart and handle.scripts.OnDragStop,
    "Forever bag proxy must expose a UIParent-owned drag grip")
local snapshotsBeforeBagDrag = profileSnapshotWrites
handle.scripts.OnDragStart(handle)
assert(bag.startMovingCalls == 1 and bag.movableCalls == 1,
    "hardware drag did not start native root movement")
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 260, 880)
handle.scripts.OnDragStop(handle)
assert(bag.stopMovingCalls == 1,
    "hardware drag did not stop native root movement")
assert(profileSnapshotWrites == snapshotsBeforeBagDrag + 1,
    "workspace bag drop must refresh the complete Forever snapshot")
local saved = addon.db.savedWorkspacePositions.ContainerFrameCombinedBags
assert(saved and math.abs(saved.x - 260) < 0.01 and math.abs(saved.y - 880) < 0.01,
    "proxy drag did not persist the new workspace position")

-- The adapter must also retire the shared workspace snapshot when the player
-- drags the bag back across the seam. Otherwise the observer immediately
-- reapplies the old Offhand anchor and makes the bag appear impossible to
-- return to Mainhand.
snapshotsBeforeBagDrag = profileSnapshotWrites
handle.scripts.OnDragStart(handle)
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1900, 1100)
handle.scripts.OnDragStop(handle)
assert(addon.db.savedWorkspacePositions.ContainerFrameCombinedBags == nil
        and addon.db.nativeBackpackWorkspacePosition == nil,
    "Mainhand drop must retire the backpack-family workspace snapshot")
assert(profileSnapshotWrites == snapshotsBeforeBagDrag + 1,
    "Mainhand bag drop must refresh the complete Forever snapshot")
local mainSaved = addon.db.savedMainPositions.ContainerFrameCombinedBags
assert(mainSaved and mainSaved.x >= metrics.gameLeft,
    "Mainhand drop must persist a Mainhand position")
controller.scripts.OnUpdate(controller, 0.11)
assert(bag:GetLeft() >= metrics.gameLeft,
    "proxy observer must not pull a Mainhand bag back to the workspace")

-- Move the bag back to Offhand, then verify the independent workspace contract:
-- Escape and system-panel cleanup preserve the open bag, while B and the native
-- close button remain explicit closers.
snapshotsBeforeBagDrag = profileSnapshotWrites
handle.scripts.OnDragStart(handle)
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 240, 860)
handle.scripts.OnDragStop(handle)
assert(profileSnapshotWrites == snapshotsBeforeBagDrag + 1,
    "returning the bag to Offhand must commit workspace ownership immediately")
local nativeOpenCalls = 0
OpenAllBags = function()
    nativeOpenCalls = nativeOpenCalls + 1
    if nativePanelBlocksBagAPIs then return end
    if nativeOpenerDeclinesHiddenLogicalState then return end
    bag:Show()
end
ToggleGameMenu()
assert(not bag:IsShown() and not GameMenuFrame:IsShown(),
    "Forever's native first Escape should be consumed by the open bag")
controller.scripts.OnUpdate(controller, 0.001)
assert(nativeOpenCalls > 0 and bag:IsShown() and GameMenuFrame:IsShown(),
    "Offhand must restore a tracked workspace bag after Escape")
assert(nativeToggleGameMenuCalls == 1,
    "bag observation must not re-enter protected ToggleGameMenu")

ToggleGameMenu()
controller.scripts.OnUpdate(controller, 0.001)
assert(not GameMenuFrame:IsShown() and bag:IsShown(),
    "second Escape must close the Game Menu while preserving the workspace bag")
assert(nativeToggleGameMenuCalls == 2,
    "bag observation must not add Game Menu toggles")

-- A selected target must remain reachable through Blizzard's Escape order.
local targetEscapePosition = addon.db.nativeBackpackWorkspacePosition
local targetEscapeOpens = nativeOpenCalls
targetSelected = true
ToggleGameMenu()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and not GameMenuFrame:IsShown()
        and addon.db.nativeBackpackWorkspaceOpen == nil,
    "targeted Escape must respect the native bag close instead of cycling the menu")
assert(nativeOpenCalls == targetEscapeOpens and targetSelected,
    "targeted Escape must not reopen bags or clear the target from addon code")
assert(addon.db.nativeBackpackWorkspacePosition == targetEscapePosition,
    "native Escape dismissal must preserve saved bag placement")
ToggleGameMenu()
controller.scripts.OnUpdate(controller, 0.001)
assert(not targetSelected and not GameMenuFrame:IsShown() and not bag:IsShown(),
    "the next native Escape must be able to clear the selected target")
OpenAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(), "player-driven reopening must retain saved workspace placement")

-- Missing or unreadable target state must yield rather than invent focus.
local unitExistsBefore = UnitExists
for _,query in ipairs({false, function() error("restricted target query") end}) do
    UnitExists = query or nil
    ToggleGameMenu()
    controller.scripts.OnUpdate(controller, 0.001)
    assert(not bag:IsShown() and not GameMenuFrame:IsShown(),
        "unknown target state must leave native Escape dismissal intact")
    UnitExists = unitExistsBefore
    OpenAllBags()
    controller.scripts.OnUpdate(controller, 0.001)
end

-- Native Gamepad UI owns both bag visibility and Game Menu focus. Its Escape
-- result must stand, while the saved position and workspace-open intent remain
-- available for a later player-driven open.
local gamepadUI = true
addon.IsGamepadUIEnabled = function() return gamepadUI end
local opensBeforeGamepadEscape = nativeOpenCalls
ToggleGameMenu()
controller.scripts.OnUpdate(controller, 0.001)
controller.scripts.OnUpdate(controller, 0.001)
assert(nativeOpenCalls == opensBeforeGamepadEscape and not bag:IsShown()
        and not GameMenuFrame:IsShown(),
    "Gamepad UI Escape must not reopen bags or toggle the Game Menu from addon code")
local trackedBefore = addon.db.nativeBackpackWorkspaceOpen
addon.db.nativeBackpackWorkspaceOpen = true
assert(addon.Canvas:RestoreTrackedWorkspaceBag() == false
        and nativeOpenCalls == opensBeforeGamepadEscape and not bag:IsShown()
        and addon.db.nativeBackpackWorkspaceOpen == true,
    "Gamepad UI must not restore a tracked bag from addon code or forget it")
addon.db.nativeBackpackWorkspaceOpen = trackedBefore
gamepadUI = false
OpenAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and math.abs(bag:GetLeft() - 240) < 0.01,
    "a player-opened bag must return to its saved workspace position")
nativeOpenCalls = opensBeforeGamepadEscape

-- Some Forever builds complete the second Escape natively: both the menu and
-- bag are hidden before the observer runs. That dismissal must restore the bag
-- without starting the three-second system-panel navigation grace period.
GameMenuFrame:Show()
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
GameMenuFrame:Hide()
bag:Hide()
addon.Canvas._foreverNativeBagCloseObserved = true
addon.Canvas._foreverNativeGameMenuToggleObserved = true
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and not GameMenuFrame:IsShown(),
    "native second Escape must restore the bag while dismissing the Game Menu")
ToggleBackpack()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown(),
    "the ToggleBackpack B binding must respond immediately after Game Menu dismissal")
ToggleBackpack()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(),
    "the ToggleBackpack B binding must reopen immediately after Game Menu dismissal")
-- No time-based grace may remain after the Escape transaction. Even an
-- otherwise unclassified native hide on the following update must be accepted
-- instead of being reopened for three seconds.
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown(),
    "no post-Game-Menu timer may override a subsequent native bag close")
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)

-- Native Chat Settings closes the workspace backpack during ShowUIPanel.
-- Preserve open intent through that navigation without borrowing its frame
-- scripts, and retain a later explicit B close while the dialog remains open.
ChatConfigFrame = makeFrame("ChatConfigFrame", 745, 605)
ChatConfigFrame:Show()
local chatConfigHooks = ChatConfigFrame.nativeHookCalls
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == true,
    "Chat Settings must restore the tracked workspace backpack")
assert(ChatConfigFrame.nativeHookCalls == chatConfigHooks,
    "bag preservation must not install Chat Settings scripts")
ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == nil,
    "explicit B close must win while Chat Settings remains open")
ChatConfigFrame:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown(), "closing Chat Settings must not undo an explicit B close")
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)

-- System panels may temporarily hide the bag, but the tracked workspace-open
-- intent must survive and recovery must use Blizzard's bag APIs.
SettingsPanel = makeFrame("SettingsPanel", 900, 700)
SettingsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 500)
SettingsPanel:Show()
local settingsNativeHooks = SettingsPanel.nativeHookCalls
addon.Mainhand = { IsNativeGamepadInterface = function() return true end }
Settings:OpenToCategory()
addon.Mainhand = nil
local settingsPoint = SettingsPanel.points[1]
assert(settingsPoint and settingsPoint[1] == "CENTER" and settingsPoint[2] == UIParent
        and settingsPoint[3] == "CENTER"
        and math.abs(settingsPoint[4] - 720) < 0.01
        and math.abs(settingsPoint[5] + 560) < 0.01,
    "native gamepad Settings must be centered on Mainhand through the external opening observer")
assert(SettingsPanel.nativeHookCalls == settingsNativeHooks
        and SettingsPanel._OffhandMainhandHooked == nil,
    "native gamepad Settings recovery must not hook or annotate the Blizzard frame")
nativeOpenerDeclinesHiddenLogicalState = true
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(),
    "Settings transition must restore the tracked workspace bag")
SettingsPanel:Hide()

AddonList = makeFrame("AddonList", 500, 600)
AddonList:Show()
nativePanelBlocksBagAPIs = true
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == true,
    "a modal API rejection must retain the workspace-open intent without showing a shell")
nativePanelBlocksBagAPIs = false
AddonList:Hide()

EditModeManagerFrame = makeFrame("EditModeManagerFrame", 600, 300)
EditModeManagerFrame:Show()
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(),
    "Edit Mode transition must restore the tracked workspace bag through Blizzard's API")

ProfessionsBookFrame = makeFrame("ProfessionsBookFrame", 700, 800)
UIPanelWindows.ProfessionsBookFrame = { area = "left", pushable = 0 }
ProfessionsBookFrame:Show()
controller.scripts.OnUpdate(controller, 0.001)
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == true,
    "opening Professions must preserve and restore the tracked workspace bag")
ProfessionsBookFrame:Hide()
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == true,
    "closing Professions must preserve and restore the tracked workspace bag")

nativeOpenerDeclinesHiddenLogicalState = false
ToggleAllBags = function()
    -- Forever may toggle the root directly without calling CloseAllBags.
    if bag:IsShown() then bag:Hide() else bag:Show() end
end
addon.Canvas._foreverNativeToggleAllBagsObserved = nil
addon.Canvas:EnableForeverNativeBagProxy()
EditModeManagerFrame:Hide()
ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown(),
    "explicit B close must remain closed without workspace restoration")

ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(),
    "B must remain able to reopen the native bag")

ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown(),
    "a second explicit B close must remain closed")

-- Teardown preserves a shown bag, but an already-observed explicit close wins.
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
assert(addon.Canvas:FinalizeForeverNativeBagStateForTransition(),
    "teardown must reconcile Forever bag-open state")
assert(addon.db.nativeBackpackWorkspaceOpen == true
        and addon.db.openWorkspacePanels.ContainerFrameCombinedBags == true,
    "shown native backpack must remain tracked for reload restoration")

bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
ToggleAllBags()
assert(addon.Canvas:FinalizeForeverNativeBagStateForTransition(),
    "explicit close must be reconciled at teardown")
assert(addon.db.nativeBackpackWorkspaceOpen == nil
        and addon.db.openWorkspacePanels.ContainerFrameCombinedBags == nil,
    "explicitly closed native backpack must remain closed after reload")

bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
mouseFoci = { bag.CloseButton }
CloseAllBags()
controller.scripts.OnUpdate(controller, 0.001)
mouseFoci = {}
assert(not bag:IsShown(),
    "native close-button click must close without workspace restoration")

-- Native X hides the root before the close post-hook, clearing GetMouseFoci.
-- The still-valid button hit rectangle identifies that same explicit close.
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
bag.CloseButton.IsForbidden = function() return false end
bag.CloseButton.IsMouseOver = function() return true end
CloseAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and addon.db.nativeBackpackWorkspaceOpen == nil,
    "native X must stay closed when hiding the root clears mouse focus")
bag.CloseButton.IsMouseOver = function() error("restricted hit test") end
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
CloseAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown(), "an unavailable hit test must retain navigation recovery")
bag.CloseButton.IsMouseOver = nil

-- A normal bag opening starts at Blizzard's bottom-right anchor. The observer
-- runs every rendered frame so the saved root is corrected before that native
-- position can be painted.
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 2200, 700)
bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
assert(math.abs(bag:GetLeft() - 240) < 0.01,
    "first observer frame must remove the default-anchor opening flash")
assert(rawget(bag, "_OffhandDragging") == nil
        and rawget(bag, "_OffhandMovable") == nil
        and rawget(bag, "_OffhandHandle") == nil,
    "proxy adapter must not store Offhand bookkeeping on the native bag")

-- Settled proxy geometry must not generate layout writes on every render frame.
local proxyWrites=0
local originalClear,originalPoint,originalSize=handle.ClearAllPoints,handle.SetPoint,handle.SetSize
handle.ClearAllPoints=function(...) proxyWrites=proxyWrites+1;return originalClear(...) end
handle.SetPoint=function(...) proxyWrites=proxyWrites+1;return originalPoint(...) end
handle.SetSize=function(...) proxyWrites=proxyWrites+1;return originalSize(...) end
for _=1,600 do controller.scripts.OnUpdate(controller,1/60) end
assert(proxyWrites==0,'settled native-bag proxy must not rewrite layout every frame')

handle.scripts.OnDragStart(handle)
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',300,850)
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites==2 and math.abs(handle:GetLeft()-344)<0.001,
    'dragging must move the proxy immediately without rewriting unchanged size')
handle.scripts.OnDragStop(handle)
controller.scripts.OnUpdate(controller,0.001)
proxyWrites=0
bag.width=bag.width+40
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites==1 and math.abs(handle:GetWidth()-(bag:GetWidth()-96))<0.001,
    'bag resize must immediately update only the changed proxy size')

local originalBagScale,originalParentScale=bag.GetEffectiveScale,UIParent.GetEffectiveScale
bag.GetEffectiveScale=function() return 1.25 end
UIParent.GetEffectiveScale=function() return 0.8 end
proxyWrites=0
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites>0 and math.abs(handle:GetHeight()-24*1.25/0.8)<0.001,
    'effective-scale changes must update the proxy in the first observer frame')
bag.GetEffectiveScale,UIParent.GetEffectiveScale=originalBagScale,originalParentScale
controller.scripts.OnUpdate(controller,0.001)

-- Inspect actual addon-owned geometry rather than trusting cached last inputs.
handle:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',1,1)
proxyWrites=0
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites==2,'displaced proxy must be repaired without rewriting its size')
handle:SetSize(1,1)
proxyWrites=0
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites==1,'changed proxy dimensions must be repaired without reanchoring')
proxyWrites=0
controller.scripts.OnUpdate(controller,0.001)
assert(proxyWrites==0,'a repaired proxy must return immediately to zero layout writes')
handle:Hide();bag:Hide()
controller.scripts.OnUpdate(controller,0.001)
bag:Show()
controller.scripts.OnUpdate(controller,0.001)
assert(handle:IsShown(),'reopening a bag must show its grip even when geometry is unchanged')
handle.ClearAllPoints,handle.SetPoint,handle.SetSize=originalClear,originalPoint,originalSize

-- Exercise the production compatibility gate with combined mode's missing
-- individual root. A false replacement owner used to disable this controller.
assert(ContainerFrame1 == nil and ContainerFrameCombinedBags == bag)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
bag:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 9000, 9000)
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:GetLeft() < metrics.workspaceRight and handle:IsShown(),
    "combined-only native bags must still restore through the production ownership gate")

-- Player combat and lockdown can disagree across the transition. Neither
-- native repositioning nor addon-driven bag opening may use that interval.
unitCombat=true
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==9000,'native bag placement must yield while player combat remains active')
local openBeforeCombat=nativeOpenCalls
bag:Hide()
assert(not addon.Canvas:RestoreTrackedWorkspaceBag(), 'combat restore must refuse native opening')
assert(nativeOpenCalls==openBeforeCombat and addon.Canvas:GetNativeBackpackWorkspacePosition(),
    'combat recovery must preserve intent without opening or toggling native bags')
unitCombat=false
bag:Show()
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()<metrics.workspaceRight,'settled combat exit must restore the existing saved position')
local originalOpen, originalToggle = OpenAllBags, ToggleAllBags
local fallbackCalls=0
bag:Hide()
OpenAllBags=function() unitCombat=true end
ToggleAllBags=function() fallbackCalls=fallbackCalls+1 end
assert(not addon.Canvas:RestoreTrackedWorkspaceBag(), 'a native callback entering combat must stop recovery')
assert(fallbackCalls==0 and addon.Canvas:GetNativeBackpackWorkspacePosition()
    and not addon.Canvas._restoringWorkspaceBagFromEscape,
    'combat entered during native opening must stop fallback toggles and retain intent')
unitCombat=false
OpenAllBags,ToggleAllBags=originalOpen,originalToggle
assert(addon.Canvas:RestoreTrackedWorkspaceBag(),'the same pending intent must recover after combat settles')

-- A previously initialized, unrestricted root can be repaired after native
-- combat reopening without opening bags or touching their content/controls.
bag.IsForbidden=function() return false end
bag.IsProtected=function() return false end
bag.CanChangeProtectedState=function() return true end
bag.IsAnchoringRestricted=function() return false end
bag.IsAnchoringSecret=function() return false end
bag.GetParent=function() return UIParent end
local savedBeforeCombat=addon.Canvas:GetNativeBackpackWorkspacePosition()
local snapshotsBeforeCombat=profileSnapshotWrites
local opensBeforeRootRepair=nativeOpenCalls
unitCombat=true
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()<metrics.workspaceRight,
    'an explicitly writable initialized bag root must return to its saved workspace position during combat')
assert(not handle:IsShown(),'combat repair must not expose a drag grip')
-- Separate native bags use Blizzard's ContainerFrameContainer parent, whereas
-- the combined root is directly under UIParent. Preserve both native trees.
ContainerFrameContainer = {
 GetParent=function() return UIParent end,
 IsForbidden=bag.IsForbidden, IsProtected=bag.IsProtected,
 CanChangeProtectedState=bag.CanChangeProtectedState,
 IsAnchoringRestricted=bag.IsAnchoringRestricted, IsAnchoringSecret=bag.IsAnchoringSecret,
}
bag.GetParent=function() return ContainerFrameContainer end
bag:Hide()
controller.scripts.OnUpdate(controller,.001)
bag:Show()
bag:SetPoint('TOPLEFT',ContainerFrameContainer,'BOTTOMLEFT',9000,9000)
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()<metrics.workspaceRight,
    'a reopened separate native bag must repair while retaining its Blizzard container parent')
local nativeContainer=ContainerFrameContainer
ContainerFrameContainer={}
bag.GetParent=function() return nativeContainer end
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==9000,'an unknown container parent must yield')
ContainerFrameContainer=nativeContainer
nativeContainer.GetParent=function() return {} end
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==9000,'a reparented native container must yield')
nativeContainer.GetParent=function() return UIParent end
nativeContainer.IsProtected=function() return true end
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==9000,'a protected native container must yield')
nativeContainer.IsProtected=bag.IsProtected
bag.GetParent=function() return UIParent end
assert(addon.Canvas:GetNativeBackpackWorkspacePosition()==savedBeforeCombat
    and profileSnapshotWrites==snapshotsBeforeCombat and nativeOpenCalls==opensBeforeRootRepair,
    'combat root repair must not persist state or invoke native openers')
local previousWorkspace,previousMain,previousCanonical=addon.db.savedWorkspacePositions,addon.db.savedMainPositions,addon.db.nativeBackpackWorkspacePosition
addon.db.savedWorkspacePositions={};addon.db.nativeBackpackWorkspacePosition=nil
addon.db.savedMainPositions={ContainerFrameCombinedBags={x=metrics.gameLeft+80,y=800}}
InCombatLockdown=function() return true end
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==metrics.gameLeft+80,'combat repair must also honor saved Mainhand placement during lockdown')
addon.db.savedWorkspacePositions,addon.db.savedMainPositions,addon.db.nativeBackpackWorkspacePosition=previousWorkspace,previousMain,previousCanonical
InCombatLockdown=function() return false end
for _,method in ipairs({'IsForbidden','IsProtected','CanChangeProtectedState','IsAnchoringRestricted','IsAnchoringSecret'}) do
 local original=bag[method]
 bag[method]=function() return method~='CanChangeProtectedState' end
 bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
 controller.scripts.OnUpdate(controller,.001)
 assert(bag:GetLeft()==9000,'restricted root must defer: '..method)
 bag[method]=nil
 controller.scripts.OnUpdate(controller,.001)
 assert(bag:GetLeft()==9000,'missing capability must defer: '..method)
 bag[method]=original
end
local secretFlag={}
issecretvalue=function(value) return value==secretFlag end
bag.CanChangeProtectedState=function() return secretFlag end
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()==9000,'secret security state must defer without truth-testing it')
bag.CanChangeProtectedState=function() return true end
issecretvalue=nil
local originalPoint=bag.SetPoint
local failedWrites=0
bag.SetPoint=function() failedWrites=failedWrites+1;error('simulated rejected root anchor') end
controller.scripts.OnUpdate(controller,.001)
controller.scripts.OnUpdate(controller,.001)
assert(failedWrites==1,'a rejected combat anchor must suspend repair until combat ends')
bag.SetPoint=originalPoint
unitCombat=false
controller.scripts.OnUpdate(controller,.001)
assert(bag:GetLeft()<metrics.workspaceRight,'ordinary recovery must resume when combat settles')
unitCombat=true
bag:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',9000,9000)
local silentWrites=0
bag.SetPoint=function() silentWrites=silentWrites+1 end
controller.scripts.OnUpdate(controller,.001)
controller.scripts.OnUpdate(controller,.001)
assert(silentWrites==1,'silent native rejection must also suspend combat repair')
bag.SetPoint=originalPoint
unitCombat=false
controller.scripts.OnUpdate(controller,.001)

bag.IsVisible = function() return false end
bag.GetEffectiveAlpha = function() return 0 end
bag.GetParent = function() return UIParent end
UIParent.GetName = function() return "UIParent" end
local diagnosticLeft, diagnosticTop = bag:GetLeft(), bag:GetTop()
local bagReport = addon.Canvas:GetForeverNativeBagDiagnostics()
assert(bagReport:find("custom=0 proxy=1", 1, true)
        and bagReport:find("ContainerFrame1=absent", 1, true)
        and bagReport:find("shown=true,visible=false,alpha=0,parent=UIParent", 1, true)
        and bagReport:find("rect=", 1, true) and bagReport:find("saved=workspace", 1, true),
    "bag diagnostics must distinguish a shown root from an invisible or transparent bag")
assert(bag:GetLeft() == diagnosticLeft and bag:GetTop() == diagnosticTop,
    "bag diagnostics must not repair or toggle the reported frame")
bag.GetBottom = function() error("unavailable geometry") end
assert(addon.Canvas:GetForeverNativeBagDiagnostics():find("ContainerFrameCombinedBags={unresolved}", 1, true),
    "unreadable native bag geometry must not abort the support report")
print("PASS: Forever native bags use an isolated sibling proxy and persist movement")
print('PASS: proxy no-op layout, immediate drag/resize/scale updates and disturbed geometry repair')
