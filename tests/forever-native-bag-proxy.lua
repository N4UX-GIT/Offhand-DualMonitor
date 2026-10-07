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
local nativeToggleGameMenuCalls = 0
ToggleGameMenu = function()
    nativeToggleGameMenuCalls = nativeToggleGameMenuCalls + 1
    if bag:IsShown() then
        CloseAllBags()
        return
    end
    if GameMenuFrame:IsShown() then
        GameMenuFrame:Hide()
    else
        GameMenuFrame:Show()
    end
end

assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(addon.Canvas:EnableForeverNativeBagProxy(),
    "Forever bag proxy controller was not created")

local controller = _G.OffhandForeverNativeBagController
assert(controller and controller.parent == UIParent,
    "Forever bag controller must be owned by UIParent")
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
    if frame ~= controller and frame.parent == UIParent then handle = frame end
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

-- Move the bag back to Offhand, then emulate Forever's Escape sequence. This
-- build returns from ToggleGameMenu after closing the bag without showing the
-- menu, so the secure global observer must defer both operations until the
-- native stack ends, completing the menu toggle before reopening the bag.
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
assert(nativeOpenCalls == 1 and bag:IsShown() and GameMenuFrame:IsShown(),
    "Escape repair must show the Game Menu and restore the bag through Blizzard's opener")
assert(nativeToggleGameMenuCalls == 1,
    "deferred Escape repair must not re-enter protected ToggleGameMenu")
assert(math.abs(bag:GetLeft() - 240) < 0.01,
    "Escape restoration must retain the workspace bag position")

ToggleGameMenu()
controller.scripts.OnUpdate(controller, 0.001)
assert(not GameMenuFrame:IsShown() and bag:IsShown() and nativeOpenCalls == 2,
    "second Escape must hide the Game Menu and restore the tracked bag")
assert(nativeToggleGameMenuCalls == 2,
    "second deferred Escape repair must not re-enter protected ToggleGameMenu")

-- Settings, AddOns and Edit Mode may hide bags after the Game Menu transition
-- has already settled. The isolated observer must recover a tracked workspace
-- bag without installing hooks on any of those native panel trees.
SettingsPanel = makeFrame("SettingsPanel", 900, 700)
SettingsPanel:Show()
nativeOpenerDeclinesHiddenLogicalState = true
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 4
        and nativeOpenerDeclinesHiddenLogicalState == false,
    "Settings transition must normalize and restore a logically-open hidden bag")
SettingsPanel:Hide()

AddonList = makeFrame("AddonList", 500, 600)
AddonList:Show()
nativePanelBlocksBagAPIs = true
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 6,
    "AddOns transition must re-show an initialized bag when modal native APIs refuse")
nativePanelBlocksBagAPIs = false
AddonList:Hide()

-- AddOn List performs another cleanup after its visible state has ended.
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 7,
    "AddOns close transition must retain the tracked workspace bag")

EditModeManagerFrame = makeFrame("EditModeManagerFrame", 600, 300)
EditModeManagerFrame:Show()
bag:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 8,
    "Edit Mode transition must restore the tracked workspace bag")

ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and nativeOpenCalls == 8,
    "explicit bag toggle must close even while Edit Mode is visible")
EditModeManagerFrame:Hide()

bag:Show()
controller.scripts.OnUpdate(controller, 0.001)

-- Options closes bags through ToggleAllBags before its panel is observable.
-- The Settings request must classify that toggle as a panel transition rather
-- than an explicit B press and keep the initialized-root fallback eligible.
nativePanelBlocksBagAPIs = true
Settings.OpenToCategory()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 10,
    "Options transition must survive its native ToggleAllBags cleanup")
nativePanelBlocksBagAPIs = false
optionFrameOpen = false

-- Some Forever builds route the Game Menu's Options button without calling a
-- discoverable Settings API or exposing the destination frame immediately.
-- The open -> hidden Game Menu transition must still distinguish that native
-- ToggleAllBags cleanup from an ordinary B press.
GameMenuFrame:Show()
controller.scripts.OnUpdate(controller, 0.001)
nativePanelBlocksBagAPIs = true
ToggleAllBags()
GameMenuFrame:Hide()
controller.scripts.OnUpdate(controller, 0.001)
assert(bag:IsShown() and nativeOpenCalls == 12,
    "unobservable Options routing must survive the Game Menu exit cleanup")
nativePanelBlocksBagAPIs = false

-- B closes through ToggleAllBags -> CloseAllBags. Its post-hook labels the
-- already-observed close as explicit before OnUpdate consumes the transaction.
ToggleAllBags()
controller.scripts.OnUpdate(controller, 0.001)
assert(not bag:IsShown() and nativeOpenCalls == 12,
    "explicit bag toggle must close without workspace restoration")

bag:Show()
controller.scripts.OnUpdate(controller, 0.001)
mouseFoci = { bag.CloseButton }
CloseAllBags()
controller.scripts.OnUpdate(controller, 0.001)
mouseFoci = {}
assert(not bag:IsShown() and nativeOpenCalls == 12,
    "native close-button click must close without workspace restoration")

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

print("PASS: Forever native bags use an isolated sibling proxy and persist movement")
