-- Native Mainhand geometry, safe gathering, and generated Edit Mode layouts.

local children = {}
local function frame(name)
    local f = { name = name, points = {}, shown = true, movable = false, scale = 1 }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children or {}) end
    function f:GetRegions() return unpack(self.regions or {}) end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetFrameLevel(value) self.level = value end
    function f:EnableMouse(value) self.mouse = value end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetMovable(value) self.movable = value end
    function f:SetClampedToScreen(value) self.clamped = value end
    function f:IsClampedToScreen() return self.clamped end
    function f:RegisterForDrag(button) self.dragButton = button end
    function f:StartMoving() self.startMovingCalls = (self.startMovingCalls or 0) + 1 end
    function f:StopMovingOrSizing() self.stopMovingCalls = (self.stopMovingCalls or 0) + 1 end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetCenter() return self.centerX, self.centerY end
    function f:SetAllPoints(relative) self.allPoints = relative end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
    function f:SetScript(script, callback) self[script] = callback end
    function f:IsForbidden() return self.forbidden == true end
    function f:IsProtected() return self.protected == true end
    function f:IsShown() return self.shown end
    function f:IsMovable() return self.movable end
    function f:IsObjectType(kind) return self.kind == kind end
    function f:GetEffectiveScale() return self.scale end
    function f:GetWidth() return self.w end
    function f:GetHeight() return self.h end
    function f:GetPoint(index)
        local point = self.points[index or 1]
        if point then return unpack(point) end
    end
    function f:GetNumPoints() return #self.points end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.right end
    function f:GetBottom() return self.bottom end
    function f:GetTop() return self.top end
    return f
end


UIParent = frame("UIParent")
function UIParent:GetWidth() return 4000 end
function UIParent:GetHeight() return 2560 end
function UIParent:GetEffectiveScale() return 1 end
function UIParent:GetChildren() return unpack(children) end
WorldFrame = frame("WorldFrame")

local created = {}
CreateFrame = function(_, name, parent)
    local f = frame(name)
    f.parent = parent
    created[#created + 1] = f
    if name then _G[name] = f end
    return f
end
InCombatLockdown = function() return false end
local unitCombat = false
UnitAffectingCombat = function(unit) return unit == "player" and unitCombat end
C_Timer = { After = function(_, callback) callback() end }
StaticPopupDialogs = {}
StaticPopup_Show = function() end
local reloadCalls = 0
ReloadUI = function() reloadCalls = reloadCalls + 1 end
RELOADUI, LATER = "Reload", "Later"
UnitName = function() return "Tester" end

local metrics = {
    gameLeft = 1440, gameBottom = 0, gameRight = 4000, gameTop = 1440,
    isSpanned = true,
}
local addon = {
    db = { enabled = true }, isForever = true, isRetail = false,
    L = setmetatable({}, { __index = function(_, key) return key end }),
    Viewport = { GetMetrics = function() return metrics end },
    RunOrQueueCombat = function(_, callback) callback() end,
}
local customBagAddon = false
addon.HasCustomBagAddon = function() return customBagAddon end
OffhandCharDB = {}
-- This partial addon fixture needs only the reload capability; keep its
-- existing client/input ownership doubles independent of other runtime APIs.
local reloadRuntime = {}
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", reloadRuntime)
addon.GetReloadUIFunction = reloadRuntime.GetReloadUIFunction
assert(loadfile("Core/MainhandGeometry.lua"))("Offhand", addon)
assert(loadfile("Core/MainhandCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/MainhandGamepad.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", addon)
assert(loadfile("Core/Mainhand.lua"))("Offhand", addon)

local callbackRect, callbackRevision
assert(addon.API.RegisterGeometryCallback("test", function(rect, _, revision)
    callbackRect, callbackRevision = rect, revision
end))
assert(addon.Mainhand:Update("test"), "initial geometry was not applied")
local anchor = addon.API.GetMainhandFrame()
assert(anchor.points[1][1] == "BOTTOMLEFT" and anchor.points[1][4] == 1440
        and anchor.points[2][1] == "TOPRIGHT" and anchor.points[2][4] == 4000
        and anchor.points[2][5] == 1440,
    "Mainhand anchor did not use Viewport metrics")
assert(callbackRect.left == 1440 and callbackRect.right == 4000 and callbackRevision == 1,
    "geometry callback did not receive the committed rectangle")

local cooperative = frame("CooperativeAddonFrame")
assert(addon.API.AnchorToMainhand(cooperative, "CENTER", "CENTER", 4, -3))
assert(cooperative.points[1][2] == anchor, "cooperating frame did not anchor to Mainhand")
cooperative.protected = true
assert(not addon.API.AnchorToMainhand(cooperative), "protected frames must be rejected")

local safe = frame("SafeWindow")
safe.movable, safe.left, safe.right, safe.bottom, safe.top = true, 50, 450, 1900, 2200
local protected = frame("ProtectedWindow")
protected.movable, protected.protected = true, true
protected.left, protected.right, protected.bottom, protected.top = 50, 450, 1900, 2200
local managed = frame("EditModeManaged")
managed.movable, managed.isManagedFrame = true, true
managed.left, managed.right, managed.bottom, managed.top = 50, 450, 1900, 2200
children = { safe, protected, managed }
local ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(ok and not why and moved == 1, "safe gather did not move exactly one eligible frame")
assert(safe.points[1] and safe.points[1][1] == "CENTER", "safe window was not gathered")
assert(#protected.points == 0 and #managed.points == 0,
    "safe gather touched a protected or Edit Mode-owned frame")

local canvasGathered = false
addon.Canvas = {
    GatherSafeUIToMainhand = function()
        canvasGathered = true
        return true, nil, 3, 0
    end,
}
unitCombat = true
ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(not ok and why == "combat" and moved == 0 and not canvasGathered,
    "player combat state did not block safe gather when lockdown lagged")
unitCombat = false
local activeRect = addon.Mainhand.rect
addon.Mainhand.rect = {
    left = 0, bottom = 0, right = 4000, top = 2560,
    width = 4000, height = 2560, isSpanned = false,
}
ok, why, moved = addon.Mainhand:GatherSafeUI()
assert(ok and not why and moved == 3 and canvasGathered,
    "safe gather let a stale anchor block live Canvas recovery")
addon.Mainhand.rect = activeRect
addon.Canvas = nil

Enum = {
    EditModeLayoutType = { Account = 1 },
    InputDeviceInterfaceType = { Gamepad = 2 },
    EditModeSystem = {
        ActionBar = 10, StatusTrackingBar = 20,
        ExtraAbilities = 30, VehicleLeaveButton = 40,
        EncounterBar = 50, LossOfControl = 60,
        Minimap = 70, BuffFrame = 71, DamageMeter = 72,
    },
    EditModeActionBarSystemIndices = {
        MainBar = 1, StanceBar = 8, PetActionBar = 9,
        PossessActionBar = 10, ClassBar = 11,
    },
    EditModeUnitFrameSystemIndices = { Party = 7, Raid = 8 },
}
local currentInterfaceStyle = 1
C_InputInterfaceStyle = {
    GetCurrentStyle = function() return currentInterfaceStyle end,
}
MainMenuBar = frame("MainMenuBar")
MainMenuBar.w, MainMenuBar.h = 1000, 40
MainMenuBar.left, MainMenuBar.right = 2000, 3000
MainMenuBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
ActionButton1 = frame("ActionButton1")
ActionButton1.left = 2050
MainMenuBarBackpackButton = frame("MainMenuBarBackpackButton")
MainMenuBarBackpackButton.right = 3100
StatusTrackingBarManager = frame("StatusTrackingBarManager")
StatusTrackingBarManager.w, StatusTrackingBarManager.h = 1000, 12
StatusTrackingBarManager:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
StanceBar = frame("StanceBar")
StanceBar.w, StanceBar.h = 240, 36
StanceBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 0, 0)
PetActionBar = frame("PetActionBar")
PetActionBar.w, PetActionBar.h = 400, 36
PetActionBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 0, 0)
ExtraAbilityContainer = frame("ExtraAbilityContainer")
ExtraAbilityContainer.w, ExtraAbilityContainer.h = 240, 80
ExtraAbilityContainer:SetPoint("CENTER", UIParent, "BOTTOM", 0, 0)
MainMenuBarVehicleLeaveButton = frame("MainMenuBarVehicleLeaveButton")
MainMenuBarVehicleLeaveButton.w, MainMenuBarVehicleLeaveButton.h = 50, 50
MainMenuBarVehicleLeaveButton:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 0, 0)
PossessActionBar = frame("PossessActionBar")
PossessActionBar.w, PossessActionBar.h = 400, 36
PossessActionBar:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", 0, 0)
LossOfControlFrame = frame("LossOfControlFrame")
LossOfControlFrame.w, LossOfControlFrame.h = 300, 90
LossOfControlFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
EncounterBar = frame("EncounterBar")
EncounterBar.w, EncounterBar.h = 280, 40
EncounterBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
Constants = { EditModeConsts = { EditModeMaxLayoutsPerType = 10 } }
local preset = {
    layoutName = "Modern", layoutIndex = 0, layoutType = 1, interfaceStyle = 1,
    systems = {
        { system = 72, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { system = 20, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = -20, offsetY = -30 } },
        { system = 10, systemIndex = 8, isInDefaultPosition = false,
          anchorInfo = { point = "LEFT", relativeTo = "OtherSystem", relativePoint = "RIGHT", offsetX = 5, offsetY = 0 } },
        { system = 10, systemIndex = 8, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = 0 } },
        { system = 10, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } },
        { system = 10, systemIndex = 9, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } },
        { system = 30, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { system = 40, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = 0 } },
        { system = 10, systemIndex = 10, isInDefaultPosition = true,
          anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } },
        { system = 60, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { system = 50, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { system = 10, systemIndex = 11, isInDefaultPosition = true,
          anchorInfo = { point = "CENTER", relativeTo = "UIParent", relativePoint = "CENTER", offsetX = 0, offsetY = 0 } },
        { system = 70, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "TOPRIGHT", offsetX = 0, offsetY = 0 } },
        { system = 71, systemIndex = 1, isInDefaultPosition = true,
          anchorInfo = { point = "TOPRIGHT", relativeTo = "MinimapCluster", relativePoint = "TOPLEFT", offsetX = -8, offsetY = 0 } },
    },
}
local function copyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, entry in pairs(value) do result[copyTable(key, seen)] = copyTable(entry, seen) end
    return result
end
local presetLayouts = {
    preset,
    { layoutName = "Classic", layoutIndex = 1, systems = {} },
    { layoutName = "Internal", layoutIndex = 2, systems = {} },
}
EditModePresetLayoutManager = {
    presetLayoutInfo = presetLayouts,
    GetCopyOfPresetLayouts = function() return copyTable(presetLayouts) end,
}
local layoutData = { activeLayout = 1, layouts = {} }
local saved, activated, layoutAdded, saveCount
C_EditMode = {
    GetLayouts = function() return layoutData end,
    SaveLayouts = function(data) saved = data; layoutData = data; saveCount = (saveCount or 0) + 1 end,
    SetActiveLayout = function(id) activated = id; layoutData.activeLayout = id end,
    OnLayoutAdded = function(index, activate, imported)
        assert(imported == false, "generated layouts must use Blizzard's new-layout transaction")
        layoutAdded = index
        if activate then layoutData.activeLayout = index end
    end,
}
EditModeManagerFrame = {
    UpdateLayoutInfo = function(self, data)
        self.layoutInfo = { activeLayout = data.activeLayout, layouts = EditModePresetLayoutManager:GetCopyOfPresetLayouts() }
        for _, layout in ipairs(data.layouts or {}) do
            self.layoutInfo.layouts[#self.layoutInfo.layouts + 1] = copyTable(layout)
        end
    end,
    GetActiveLayoutInfo = function(self)
        return self.layoutInfo and self.layoutInfo.layouts[self.layoutInfo.activeLayout]
    end,
}
EditModeManagerFrame:UpdateLayoutInfo(layoutData)

local previousRecoveryHUD = addon.HUD
local completedRecoveries = 0
addon.HUD = {CompleteProtectedHUDLayoutRecovery = function() completedRecoveries = completedRecoveries + 1 end}
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(completedRecoveries == 1, 'successful layout creation must retire stale HUD recovery prompts')
addon.HUD = previousRecoveryHUD
assert(ok and localName == "Offhand" and moved == 11,
    "Mainhand Edit Mode layout was not generated from the active preset")
assert(layoutAdded == 4 and activated == nil and #saved.layouts == 1 and saveCount == 1,
    "generated custom layout did not use Blizzard's one-save layout-added transaction")
local generated = saved.layouts[1]
assert(generated.systems[1].anchorInfo.offsetX == 720
        and generated.systems[1].anchorInfo.offsetY == -560,
    "the default Damage Meter must keep its preset offset from Mainhand's top region")
assert(generated.systems[2].anchorInfo.point == "BOTTOM"
        and generated.systems[2].anchorInfo.offsetX == 820
        and generated.systems[2].anchorInfo.offsetY == 43,
    "the default XP/status bar was not stacked directly above the Mainhand action bar")
assert(generated.systems[3].anchorInfo.offsetX == 5,
    "a system-relative anchor was unexpectedly changed")
assert(generated.systems[4].anchorInfo.point == "BOTTOMLEFT"
        and generated.systems[4].anchorInfo.offsetX == 270
        and generated.systems[4].anchorInfo.offsetY == 60,
    "the default stance bar was not placed above the first Mainhand action button")
assert(generated.systems[5].anchorInfo.offsetX == 720
        and generated.systems[5].anchorInfo.offsetY == 0,
    "the default Mainhand action bar anchor was not translated")
assert(generated.systems[6].anchorInfo.point == "BOTTOMLEFT"
        and generated.systems[6].anchorInfo.offsetX == 270
        and generated.systems[6].anchorInfo.offsetY == 60,
    "the default pet bar was not placed beside the stance bar")
assert(generated.systems[7].anchorInfo.point == "CENTER"
        and generated.systems[7].anchorInfo.offsetX == 720
        and generated.systems[7].anchorInfo.offsetY == 110,
    "the default extra-abilities frame was not placed above the XP bar")
assert(generated.systems[8].anchorInfo.point == "BOTTOMLEFT"
        and generated.systems[8].anchorInfo.offsetX == 270
        and generated.systems[8].anchorInfo.offsetY == 104,
    "the default vehicle-exit frame was not placed above the stance bar")
assert(generated.systems[9].anchorInfo.point == "BOTTOMLEFT"
        and generated.systems[9].anchorInfo.offsetX == 270
        and generated.systems[9].anchorInfo.offsetY == 60,
    "the default possess bar was not placed above the XP bar")
assert(generated.systems[11].anchorInfo.point == "CENTER"
        and generated.systems[11].anchorInfo.offsetX == 720
        and generated.systems[11].anchorInfo.offsetY == -487,
    "the default encounter bar was not placed above Loss of Control")
assert(generated.systems[12].anchorInfo.offsetX == 0
        and generated.systems[12].anchorInfo.offsetY == 0
        and generated.systems[12].isInDefaultPosition == true,
    "the Forever MultiCast/Class bar was moved away from its safe source position")
assert(generated.systems[13].anchorInfo.offsetX == 0
        and generated.systems[13].anchorInfo.offsetY == -1120,
    "the default Minimap must keep its preset offset from Mainhand's top edge")
assert(generated.systems[14].anchorInfo.relativeTo == "MinimapCluster"
        and generated.systems[14].anchorInfo.offsetX == -8
        and generated.systems[14].anchorInfo.offsetY == 0,
    "the default keyboard Buff Frame must retain its native relationship")
assert(preset.systems[1].anchorInfo.offsetX == 0 and preset.systems[1].anchorInfo.offsetY == 0,
    "the source preset was mutated")
assert(OffhandCharDB.mainhandLayout.sourcePreset
        and OffhandCharDB.mainhandLayout.sourceID == 1
        and OffhandCharDB.foreverEditModeLayoutID == 4,
    "per-character layout provenance was not recorded")

-- Retail/Anniversary login restores a character's layout by name. Repairing
-- A second character adopts the existing account layout at capacity without
-- rewriting customizations or using the first character's rollback source.
local firstCharacterRecord = OffhandCharDB
local originalUnitName = UnitName
local priorMaximum = Constants.EditModeConsts.EditModeMaxLayoutsPerType
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 1
UnitName = function() return "SecondCharacter" end
OffhandCharDB = copyTable(firstCharacterRecord) -- Stale cross-character fallback must not steal rollback provenance.
layoutData.activeLayout = 2
generated.systems[1].anchorInfo.offsetX = 731
local savesBeforeAdoption = saveCount
local adopted, adoptedName = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(adopted and adoptedName == "Offhand" and #layoutData.layouts == 1
        and saveCount == savesBeforeAdoption and layoutData.activeLayout == 4
        and layoutData.layouts[1].systems[1].anchorInfo.offsetX == 731,
    "second-character setup must select the shared layout at capacity without rewriting its edits")
assert(OffhandCharDB.mainhandLayout.sourceName == "Classic"
        and OffhandCharDB.mainhandLayout.sourceID == 2
        and OffhandCharDB.mainhandLayout.ownerName == "SecondCharacter",
    "shared-layout adoption must keep the adopting character's rollback source")
generated.systems[1].anchorInfo.offsetX = 720
Constants.EditModeConsts.EditModeMaxLayoutsPerType = priorMaximum
OffhandCharDB, UnitName = firstCharacterRecord, originalUnitName

-- Retail/Anniversary login restores a character's layout by name. Repairing
-- the HUD must replace any stale remembered layout in the same successful
-- transaction, otherwise /reload immediately undoes the repair.
addon.isForever = false
addon.isRetail = true
OffhandDB.sharedMainhandLayouts.Offhand.client = "retail" -- Same layout fixture, different client adapter.
OffhandCharDB.editModeLayoutName = "1234"
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and OffhandCharDB.editModeLayoutName == localName
        and localName == "Offhand",
    "Retail HUD repair did not persist the generated layout as the character preference")
addon.isForever = true
addon.isRetail = false
OffhandDB.sharedMainhandLayouts.Offhand.client = "forever"

-- Updating for another topology must rebuild from the original preset, not
-- translate the generated layout a second time.
metrics = { gameLeft = 0, gameBottom = 0, gameRight = 2560, gameTop = 1440, isSpanned = true }
addon.Mainhand:Update("topology")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and #saved.layouts == 2 and layoutData.activeLayout == 5 and moved == 11,
    "different geometry must preserve the original shared layout and create a compatible variant")
assert(saveCount == 3,
    "layout updates must save once and must not resubmit the payload after activation")
generated = saved.layouts[2]
assert(generated.systems[1].anchorInfo.offsetX == -720
        and generated.systems[1].anchorInfo.offsetY == -560,
    "layout update drifted instead of rebuilding from its source")

-- Forever may expose the native post-save layout-added transaction without a
-- directly callable SetActiveLayout. Creation must still activate the new
-- custom layout, while subsequent updates work because it is already active.
OffhandCharDB = {}
layoutData = { activeLayout = 1, layouts = {} }
saved, activated = nil, nil
C_EditMode.SetActiveLayout = nil
C_EditMode.OnLayoutAdded = function(index, activate, imported)
    assert(index == 4 and activate, "layout-added fallback received the wrong manager index")
    assert(imported == false, "layout-added fallback was incorrectly marked as an import")
    layoutAdded = index
    layoutData.activeLayout = index
end
metrics = { gameLeft = 1440, gameBottom = 0, gameRight = 4000, gameTop = 1440, isSpanned = true }
addon.Mainhand:Update("forever-layout-added")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and layoutData.activeLayout == 4 and #saved.layouts == 1,
    "Forever layout-added fallback did not activate the generated layout")

-- The Options action must preserve every return value from Mainhand. Wrapping
-- this call in an `and` expression collapses the layout name and moved count.
assert(loadfile("UI/Controls.lua"))("Offhand", addon)
assert(loadfile("Core/TopologyDetection.lua"))("Offhand", addon)
assert(loadfile("UI/OptionsActions.lua"))("Offhand", addon)
assert(loadfile("UI/Options.lua"))("Offhand", addon)
local createLayout = addon.Mainhand.CreateOrUpdateEditModeLayout
addon.Mainhand.CreateOrUpdateEditModeLayout = function()
    return true, "Offhand - Mainhand - Return Contract", 7
end
local actionOK, actionName, actionMoved = addon.Options:CreateMainhandHUDLayout()
assert(actionOK and actionName == "Offhand - Mainhand - Return Contract" and actionMoved == 7,
    "Options collapsed the Mainhand layout result values")
addon.Mainhand.CreateOrUpdateEditModeLayout = createLayout

local gatherAction = addon.Mainhand.GatherSafeUI
addon.Mainhand.GatherSafeUI = function()
    return false, "combat", 4, 5
end
local gatherActionOK, gatherActionWhy, gatherActionMoved, gatherActionSkipped =
    addon.Options:GatherSafeUIToMainhand()
assert(not gatherActionOK and gatherActionWhy == "combat"
        and gatherActionMoved == 4 and gatherActionSkipped == 5,
    "Options collapsed the safe gather result values")
addon.Mainhand.GatherSafeUI = gatherAction

-- Forever profiles created before mainhandLayout provenance was recorded may
-- already have the Offhand layout selected at Blizzard's custom-layout cap.
-- Reuse that exact Offhand-owned layout instead of trying to allocate one more.
local existingOffhand = saved.layouts[1]
existingOffhand.layoutName = "Offhand - Mainhand - Tester"
layoutData = {
    activeLayout = 1,
    layouts = {
        existingOffhand,
        { layoutName = "Custom 2", systems = {} },
        { layoutName = "Custom 3", systems = {} },
        { layoutName = "Custom 4", systems = {} },
        { layoutName = "Custom 5", systems = {} },
    },
}
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 5
OffhandCharDB = { foreverEditModeLayoutName = "Offhand - Mainhand - Tester" }
C_EditMode.SetActiveLayout = function(id) activated = id; layoutData.activeLayout = id end
saved, activated = nil, nil
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand - Mainhand - Tester" and #saved.layouts == 5,
    "existing Forever Offhand layout was not reused at Blizzard's layout cap")
assert(OffhandCharDB.mainhandLayout
        and OffhandCharDB.mainhandLayout.generatedName == "Offhand - Mainhand - Tester",
    "recovered Forever layout did not rebuild generator provenance")

-- A former account-global Forever fallback could copy another character's
-- generated layout record into this character. Reuse its safe preset source,
-- but create and activate a distinct current-character target.
local foreignLayout = saved.layouts[1]
foreignLayout.layoutName = "Offhand - Mainhand - OtherCharacter"
layoutData = { activeLayout = 4, layouts = { foreignLayout } }
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 5
OffhandCharDB = {
    foreverEditModeLayoutName = foreignLayout.layoutName,
    foreverEditModeLayoutID = 4,
    mainhandLayout = {
        sourcePreset = true,
        sourceID = 1,
        sourceName = "Modern",
        generatedName = foreignLayout.layoutName,
        generatedID = 4,
    },
}
saved, activated = nil, nil
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand"
        and #saved.layouts == 2 and saved.layouts[1].layoutName == foreignLayout.layoutName
        and saved.layouts[2].layoutName == "Offhand",
    "foreign character layout provenance was reused as this character's target")
assert(saved.layouts[2].systems[1].anchorInfo.offsetX == 720
        and OffhandCharDB.mainhandLayout.sourcePreset
        and OffhandCharDB.mainhandLayout.sourceID == 1,
    "foreign character recovery copied a custom layout instead of the safe source preset")

-- Existing profiles can predate the generated-layout setup step. Anniversary
-- and Retail should offer a repair only when the record is absent or belongs
-- to a different span; Forever retains its separate protected-HUD flow.
addon.isForever = false
addon.isRetail = false
addon.HasBlizzardEditMode = function() return true end
OffhandCharDB = {}
layoutData = { activeLayout = 1, layouts = {} }
local attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(attention and attentionReason == "missing",
    "a completed pre-layout Anniversary profile must be offered Mainhand HUD repair")
OffhandCharDB.mainhandLayout = {
    generatedName = "Offhand - Mainhand - Tester",
    geometrySignature = addon.Mainhand:GetGeometrySignature(),
}
attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(not attention and attentionReason == "ready",
    "a current generated Mainhand layout must not produce a repair prompt")
OffhandCharDB.mainhandLayout.geometrySignature = "old-topology"
attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(attention and attentionReason == "stale"
        and addon.Mainhand:GetEditModeDiagnostics():find("Attention=yes/stale", 1, true),
    "a topology-stale Mainhand layout must be diagnosable and offered repair")
assert(addon.Mainhand:SetEditModeLayoutDeferred(true)
        and addon.Mainhand:GetLayoutStatus().deferred,
    "the wizard skip choice must persist as per-character deferred state")
attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(not attention and attentionReason == "deferred"
        and addon.Mainhand:GetEditModeDiagnostics():find("Attention=no/deferred", 1, true),
    "a deliberately deferred HUD layout must not immediately reopen the repair prompt")
assert(addon.Mainhand:SetEditModeLayoutDeferred(false)
        and not addon.Mainhand:GetLayoutStatus().deferred,
    "explicit repair must be able to clear deferred HUD state")

preset.interfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
assert(addon.Mainhand:IsControllerLayout(),
    "Gamepad Edit Mode presets must be detected without changing their layout")
attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(not attention and attentionReason == "gamepad",
    "controller layouts must not trigger keyboard-layout repair prompts")
ok, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not ok and why == "gamepad",
    "a stale Gamepad preset must not be cloned while keyboard UI is active")
addon.isForever = true
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
assert(addon.Mainhand:IsNativeGamepadInterface()
        and addon.Mainhand:IsControllerLayout(),
    "Forever's live native gamepad interface must be detected independently of Edit Mode presets")
assert(addon.Mainhand:CanCreateControllerLayout(),
    "Forever native Gamepad UI must expose the supported custom-layout action")

-- The native radial Main Menu is outside Edit Mode. Locate its protected
-- visual container from localized labels and move only that root, leaving its
-- gamepad controls and scripts untouched.
FRAME_LABEL_MAIN_MENU = "Main Menu"
RADIAL_LABEL_GAME_MENU = "Game Menu"
local radial = frame("NativeGamepadMainMenu")
-- Forever's visual radial can live under a full-screen protected overlay.
-- Discovery must accept that root instead of requiring panel-sized bounds.
radial.w, radial.h, radial.parent = 4000, 2560, UIParent
radial:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
local titleOwner = frame()
-- The heading may be a UIParent sibling while the option owner is nested in
-- the movable radial visual root.
titleOwner.w, titleOwner.h, titleOwner.parent = 600, 40, UIParent
titleOwner.regions = { { GetText = function() return FRAME_LABEL_MAIN_MENU end } }
local optionOwner = frame()
optionOwner.w, optionOwner.h, optionOwner.parent = 220, 80, radial
optionOwner.regions = { { GetText = function() return RADIAL_LABEL_GAME_MENU end } }
radial.children = { titleOwner, optionOwner }
local enumeratedRadialFrames = { radial, titleOwner, optionOwner }
EnumerateFrames = function(previous)
    if not previous then return enumeratedRadialFrames[1] end
    for index, candidate in ipairs(enumeratedRadialFrames) do
        if candidate == previous then return enumeratedRadialFrames[index + 1] end
    end
end
radial.protected = true
local centered, centerWhy = addon.Mainhand:CenterForeverGamepadMainMenu()
assert(centered and not centerWhy and radial.points[1][1] == "CENTER"
        and radial.points[1][2] == UIParent and radial.points[1][3] == "CENTER"
        and radial.points[1][4] == 720 and radial.points[1][5] == -560,
    "protected native Gamepad radial menu was not centered directly on Mainhand")
assert(radial.OnShow == nil and radial.OnUpdate == nil,
    "radial centering must not install scripts on Blizzard's menu tree")
assert(addon.Mainhand:GetForeverGamepadMainMenuDiagnostics()
        == "centered:NativeGamepadMainMenu",
    "radial Main Menu centering was not diagnosable")
assert(addon.Mainhand:EnableForeverGamepadMainMenuAdapter()
        and _G.OffhandForeverGamepadMainMenuController.OnUpdate,
    "addon-owned radial Main Menu observer was not created")
radial:ClearAllPoints()
radial:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -40)
_G.OffhandForeverGamepadMainMenuController.OnUpdate(
    _G.OffhandForeverGamepadMainMenuController, 0.50)
assert(radial.points[1][1] == "TOPLEFT",
    "Gamepad adapter touched a protected radial during initial settlement")
_G.OffhandForeverGamepadMainMenuController.OnUpdate(
    _G.OffhandForeverGamepadMainMenuController, 0.60)
assert(radial.points[1][1] == "CENTER" and radial.points[1][4] == 720,
    "Gamepad adapter did not resume after the stable interface interval")
currentInterfaceStyle = 1
_G.OffhandForeverGamepadMainMenuController.OnUpdate(
    _G.OffhandForeverGamepadMainMenuController, 0.10)
assert(radial.points[1][1] == "CENTER",
    "Gamepad adapter restored a protected radial inside the mode transition")
_G.OffhandForeverGamepadMainMenuController.OnUpdate(
    _G.OffhandForeverGamepadMainMenuController, 1.00)
assert(radial.points[1][1] == "CENTER" and radial.points[1][4] == 0,
    "Gamepad adapter did not restore the radial after keyboard mode settled")
centered, centerWhy = addon.Mainhand:CenterForeverGamepadMainMenu()
assert(not centered and centerWhy == "inactive" and radial.points[1][2] == UIParent,
    "leaving native Gamepad mode did not restore Blizzard's radial menu anchor")
assert(radial.points[1][4] == 0 and radial.points[1][5] == 0,
    "leaving native Gamepad mode did not restore the radial menu's native offsets")
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
local gamepadObserver = _G.OffhandForeverGamepadMainMenuController
gamepadObserver:OnUpdate(0.01)
gamepadObserver:OnUpdate(1.00)
WorldMapFrame = frame("WorldMapFrame")
WorldMapFrame.shown = true
WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
OffhandCharDB.foreverGamepadPanelOffsets = { WorldMapFrame = { x = -85, y = 110 } }
gamepadObserver:OnUpdate(0.01)
local mapPoint = WorldMapFrame.points[1]
assert(mapPoint[1] == "CENTER" and mapPoint[4] == 635 and mapPoint[5] == -450,
    "the first update after opening the map must apply its saved position before the 50 ms poll")
gamepadObserver:OnUpdate(0.01)
assert(WorldMapFrame.points[1] == mapPoint,
    "an already placed map must not receive repeated anchor writes")
WorldMapFrame.shown = false
gamepadObserver:OnUpdate(0.01)
WorldMapFrame:ClearAllPoints()
WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
WorldMapFrame.shown = true
gamepadObserver:OnUpdate(0.01)
mapPoint = WorldMapFrame.points[1]
assert(mapPoint[1] == "CENTER" and mapPoint[4] == 635 and mapPoint[5] == -450,
    "reopening must promptly restore the saved map position after the native reset")
assert(WorldMapFrame.OnShow == nil and WorldMapFrame.OnUpdate == nil,
    "prompt map placement must leave the native frame's scripts alone")

local map = WorldMapFrame
WorldMapMixin = { Maximize = function() end }
map.Maximize = WorldMapMixin.Maximize
map.parent = UIParent
function map:IsMaximized() return self.maximized == true end
map.BlackoutFrame = frame()
map.BlackoutFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
map.BlackoutFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
map.ScrollContainer = frame()
map.ScrollContainer:SetSize(2826, 1881)
map:SetSize(2831, 1950)
map:ClearAllPoints()
map:SetPoint("TOP", UIParent, "TOP", 0, 0)
map.maximized = true
gamepadObserver:OnUpdate(0.01)
assert(map.points[1][1] == "BOTTOMLEFT" and map.points[1][2] == anchor
        and map.points[1][4] > 0 and map.points[1][5] == 8
        and map.points[2][1] == "TOPRIGHT" and map.points[2][2] == anchor
        and map.BlackoutFrame.points[1][2] == anchor and map.BlackoutFrame.points[2][2] == anchor,
    "maximizing must fit the native map and its blackout to Mainhand on the first update")
assert(map:GetWidth() == 2831 and map:GetHeight() == 1950
        and not OffhandForeverGamepadPanelMover_WorldMapFrame.shown,
    "fullscreen placement must preserve the native size and hide the windowed mover")
local fullscreenPoint = map.points[1]
gamepadObserver:OnUpdate(0.06)
assert(map.points[1] == fullscreenPoint, "a fitted map should retain its anchors without writes")

map.maximized = false
map:ClearAllPoints()
map:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
gamepadObserver:OnUpdate(0.01)
assert(map.points[1][1] == "CENTER" and map.points[1][4] == 635 and map.points[1][5] == -450
        and map.BlackoutFrame.points[1][1] == "TOPLEFT" and map.BlackoutFrame.points[1][2] == UIParent,
    "minimizing must restore the saved window position and release the fullscreen blackout")

local workspaceMap, faderCalls = true, 0
local savedCanvas = addon.Canvas
addon.Canvas = { IsFrameOnWorkspace = function(candidate) return candidate == map and workspaceMap end }
local externalMapOwner
addon.CanvasCompatibility = { GetWorldMapExternalOwner = function() return externalMapOwner end }
PlayerMovementFrameFader = {
    RemoveFrame = function() faderCalls = faderCalls + 1 end,
    AddDeferredFrame = function() faderCalls = faderCalls + 1 end,
}
addon.Mainhand:CenterForeverGamepadDestinationPanels()
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(faderCalls == 0,
    "the Gamepad observer must leave the native movement fader untouched for a workspace map")
externalMapOwner = "OpenMap"
OpenMapAPI = {}
map.shown = false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
map.shown = true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
workspaceMap = false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(faderCalls == 0,
    "closing, reopening or moving the Gamepad map must leave the native movement fader untouched")
PlayerMovementFrameFader = nil
addon.Canvas = savedCanvas

map.Maximize = function() end -- OpenMap post-hooks the native method.
currentInterfaceStyle = 1
local openMapCanvas = addon.Canvas
addon.Canvas = { IsFrameOnWorkspace = function(candidate)
    return candidate == map and map.points[1][1] == "TOPLEFT" and map.points[1][4] == 120
end }
map:ClearAllPoints()
map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 120, 1800)
map:SetSize(880, 610)
gamepadObserver:OnUpdate(0.01)
gamepadObserver:OnUpdate(1.00)
map.maximized = true
map:SetSize(2831, 1950)
map:ClearAllPoints()
map:SetPoint("TOP", UIParent, "TOP", 0, 0)
gamepadObserver:OnUpdate(0.01)
assert(map.points[1][2] == anchor and map.BlackoutFrame.points[1][2] == anchor,
    "standard UI must fit an OpenMap fullscreen transaction on the first update")
map.maximized = false
map:ClearAllPoints()
map:SetPoint("TOP", UIParent, "TOP", 0, 0)
map:SetSize(1035, 534)
gamepadObserver:OnUpdate(0.01)
assert(map.points[1][1] == "TOPLEFT" and map.points[1][4] == 120 and map.points[1][5] == 1800
        and map:GetWidth() == 880 and map:GetHeight() == 610
        and map.BlackoutFrame.points[1][2] == UIParent,
    "minimizing OpenMap must recover its prior Offhand layout when the native transaction leaves it on Mainhand")
map.maximized = true
map:SetSize(2831, 1950)
map:ClearAllPoints()
map:SetPoint("TOP", UIParent, "TOP", 0, 0)
gamepadObserver:OnUpdate(0.01)
externalMapOwner = "MoveAny"
gamepadObserver:OnUpdate(0.20)
assert(map.points[1][1] == "TOP" and map.points[1][2] == UIParent
        and map.BlackoutFrame.points[1][2] == UIParent,
    "a competing geometry owner must receive the native fullscreen anchors back")
externalMapOwner = nil
map.Maximize = WorldMapMixin.Maximize
gamepadObserver:OnUpdate(0.20)
assert(map.points[1][2] == anchor and map.BlackoutFrame.points[1][2] == anchor,
    "the stock fullscreen map must fit Mainhand in standard UI")
map.shown = false
gamepadObserver:OnUpdate(0.20)
assert(map.points[1][2] == UIParent and map.BlackoutFrame.points[1][2] == UIParent,
    "closing the standard fullscreen map must release both fitted anchors")
addon.CanvasCompatibility = nil
addon.Canvas = openMapCanvas
OpenMapAPI = nil
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
WorldMapFrame = nil
WorldMapMixin = nil
OffhandCharDB.foreverGamepadPanelOffsets = nil

do
    local savedMap, savedCanvas, savedCVars = WorldMapFrame, addon.Canvas, C_CVar
    local loadedAddons, spanned, workspace = {}, true, true
    local savedAddOns, getRect = C_AddOns, addon.Mainhand.GetRect
    addon.Mainhand.GetRect = function(self)
        local rect = getRect(self)
        rect.isSpanned = spanned
        return rect
    end
    local map = frame("WorldMapFrame")
    map.IsMaximized = function(self) return self.maximized == true end
    map.SetAlpha = function() error("Offhand must not write map opacity") end
    WorldMapFrame = map
    addon.Canvas = { IsFrameOnWorkspace = function(candidate) return candidate == map and workspace end }
    C_AddOns = {
        IsAddOnLoaded = function(name) return loadedAddons[name] ~= nil end,
        GetAddOnMetadata = function(name) return loadedAddons[name] end,
    }
    PlayerMovementFrameFader = {
        RemoveFrame = function() error("Offhand must not remove the map from Blizzard's fader") end,
        AddDeferredFrame = function() error("Offhand must not register the map with Blizzard's fader") end,
    }
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
    local persisted, override, writes, canOverride = true, nil, 0, true
    C_CVar = {
        GetCVarBool = function(name)
            assert(name == "mapFade")
            if override ~= nil then return override end
            return persisted
        end,
        SetTempCVar = function(name, value)
            assert(name == "mapFade" and value == "0")
            if canOverride then override = false end
        end,
        RemoveTempCVar = function(name)
            assert(name == "mapFade")
            override = nil
        end,
        SetCVar = function(name, value)
            assert(name == "mapFade" and (value == "0" or value == "1"))
            persisted = value == "1"
            writes = writes + 1
            return true
        end,
    }
    local function Update()
        gamepadObserver:OnUpdate(0.21)
    end
    local function CanFade()
        return C_CVar.GetCVarBool("mapFade") and not map:IsMouseOver()
    end
    map.IsMouseOver = function() return false end
    gamepadObserver:OnUpdate(0.01)
    gamepadObserver:OnUpdate(1.0)
    Update()
    assert(not CanFade() and persisted and writes == 0,
        "the spanned Offhand map must suppress native movement fade by default")
    currentInterfaceStyle = 1
    gamepadObserver:OnUpdate(0.01)
    gamepadObserver:OnUpdate(1.0)
    assert(not CanFade(), "switching to keyboard UI must keep the workspace map opaque")
    workspace = false
    Update()
    assert(CanFade(), "Mainhand must use the player's fade preference")
    workspace = true
    Update()
    assert(not CanFade())
    map.maximized = true
    Update()
    assert(CanFade(), "maximizing must restore the player's fade preference")
    map.maximized, spanned = false, false
    Update()
    assert(CanFade(), "an unspanned map must use the player's fade preference")
    spanned = true
    Update()
    assert(not CanFade())
    addon.db.enabled = false
    Update()
    assert(CanFade(), "disabling Offhand must release the override")
    addon.db.enabled = true
    Update()
    assert(not CanFade())
    map:Hide()
    gamepadObserver:OnUpdate(0.01)
    assert(CanFade(), "closing the map must release the override on the first observation")
    map:Show()

    local openMapDB, refreshes = {moveFade = 0.5}, 0
    local openMapModule = {enabled = true, db = openMapDB, RefreshExtras = function() refreshes = refreshes + 1 end}
    OpenMap = {version = "v0.8.7", GetModule = function(_, name) assert(name == "worldmap"); return openMapModule end}
    OpenMapAPI = {major = 1, version = 4, IsStitched = function() return false end}
    OpenMapDB = {worldmap = openMapDB}
    loadedAddons.OpenMap = "v0.8.7"
    persisted = false -- OpenMap holds Blizzard's CVar itself.
    Update()
    assert(openMapDB.moveFade == 0 and not CanFade() and writes == 0)
    workspace = false
    Update()
    assert(openMapDB.moveFade == 0.5 and refreshes == 1,
        "OpenMap must resume its saved fade even when the same map stays open")
    workspace = true
    Update()
    openMapDB.moveFade = 0.7
    Update()
    assert(openMapDB.moveFade == 0)
    map:Hide()
    Update()
    assert(openMapDB.moveFade == 0.7 and refreshes == 1,
        "preserve the newer OpenMap setting and leave reopening to OpenMap")
    map:Show()
    Update()
    local previousCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    workspace = false
    Update()
    assert(openMapDB.moveFade == 0.7 and refreshes == 1)
    InCombatLockdown = previousCombat
    Update()
    assert(refreshes == 2, "resume the visible OpenMap fader after combat")
    workspace = true
    openMapModule.enabled = false
    persisted = true
    Update()
    assert(not CanFade() and openMapDB.moveFade == 0.7,
        "OpenMap's controller fallback uses Blizzard's map")
    loadedAddons.OpenMap = nil
    OpenMap, OpenMapAPI, OpenMapDB = nil, nil, nil

    MAUTTAB = {}
    loadedAddons.MapUtils = "1.7.0"
    Update()
    assert(MAUTTAB.WORLDMAPFADE == false and not CanFade())
    workspace = false
    Update()
    assert(MAUTTAB.WORLDMAPFADE == nil and CanFade(), "restore the unset MapUtils preference")
    workspace = true
    loadedAddons.MapUtils = "99.0.0"
    Update()
    assert(MAUTTAB.WORLDMAPFADE == nil, "unknown MapUtils versions must keep their settings")
    loadedAddons.MapUtils = nil
    MAUTTAB = nil

    MapWiseAtlasDB = {fadeMapWhileMoving = true}
    MapWiseAPI = {version = "2.3.98", db = MapWiseAtlasDB, Integration = {native = map}}
    loadedAddons.MapWise = "2.3.98"
    Update()
    assert(MapWiseAtlasDB.fadeMapWhileMoving == false and not CanFade())
    MapWiseAPI.Integration.native = nil
    Update()
    assert(MapWiseAtlasDB.fadeMapWhileMoving == true and not CanFade(),
        "restore MapWise when it yields the native map")
    MapWiseAPI.Integration.native = map
    Update()
    assert(MapWiseAtlasDB.fadeMapWhileMoving == false)
    map:Hide()
    Update()
    assert(MapWiseAtlasDB.fadeMapWhileMoving == true,
        "restore the value read by the already-registered MapWise fade predicate")
    map:Show()
    loadedAddons.MapWise = nil
    MapWiseAtlasDB, MapWiseAPI = nil, nil
    loadedAddons.Leatrix_Maps = true
    Update()
    assert(not CanFade() and persisted, "Leatrix uses the same native fade preference")
    map:Hide()
    Update()
    assert(CanFade())
    map:Show()
    persisted = false
    Update()
    map:Hide()
    Update()
    assert(not CanFade() and writes == 0, "must preserve a player preference that already disables fade")

    persisted, canOverride = true, false
    map:Show()
    Update()
    assert(not CanFade() and writes == 1, "use the verified CVar path when the temporary API has no effect")
    assert(gamepadObserver.events.PLAYER_LOGOUT)
    addon.CanvasForeverMap.ReleaseMovementFade()
    assert(CanFade() and writes == 2, "restore fallback writes when leaving the workspace")
    Update()
    assert(not CanFade() and writes == 3)
    persisted = true  -- a newer user or addon write supersedes the fallback
    map:Hide()
    Update()
    assert(CanFade() and writes == 3, "release must respect the newer CVar value")
    map:Show()
    Update()
    assert(not CanFade() and writes == 4)
    MAUTTAB = {WORLDMAPFADE = true}
    loadedAddons.MapUtils = "1.7.0"
    Update()
    assert(MAUTTAB.WORLDMAPFADE == false)
    gamepadObserver:OnEvent("PLAYER_LOGOUT")
    Update()
    assert(CanFade() and writes == 5 and MAUTTAB.WORLDMAPFADE == true,
        "logout must restore both preferences and stop reacquiring them")
    MAUTTAB = nil
    WorldMapFrame, addon.Canvas, C_CVar, C_AddOns = savedMap, savedCanvas, savedCVars, savedAddOns
    addon.Mainhand.GetRect = getRect
    addon.CanvasForeverMap, addon.CanvasCompatibility, PlayerMovementFrameFader = nil, nil, nil
    currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
end

-- Native open can assign the upper-left point even when an existing mover
-- position is saved. Exercise a root and a load-on-demand alias between polls.
local openingDestinations = {
    "CharacterFrame", "PlayerSpellsFrame", "CalendarFrame", "CommunitiesFrame",
    "SocialUIFrame", "CollectionsJournal", "ContainerFrameCombinedBags",
    "TaxiFrame", "MailFrame", "OpenMailFrame", "AuctionHouseFrame", "AuctionFrame",
    "CooldownViewerSettings",
}
local previousDragHandles = addon.db.showGamepadPanelDragHandles
addon.db.showGamepadPanelDragHandles = false
for _, name in ipairs(openingDestinations) do
    local destination = frame(name)
    destination.shown = false
    destination.protected = name == "PlayerSpellsFrame" or name == "SocialUIFrame"
    destination:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
    _G[name] = destination
end
gamepadObserver:OnUpdate(0.01)
gamepadObserver:OnUpdate(1.00)
OffhandCharDB.foreverGamepadPanelOffsets = { CharacterFrame = { x = -85, y = 110 } }
for _, name in ipairs(openingDestinations) do _G[name].shown = true end
gamepadObserver:OnUpdate(0.01)
for _, name in ipairs(openingDestinations) do
    local destination = _G[name]
    assert(destination.points[1][1] == "CENTER" and not destination.OnShow and not destination.OnUpdate,
        name .. " must reach its destination on the first observed update using the addon observer")
end
assert(CharacterFrame.points[1][4] == 635 and CharacterFrame.points[1][5] == -450,
    "prompt opening placement must use the saved position")
local calendar = CalendarFrame
calendar.shown = false
-- Blizzard slides surviving panels to the vacated slot during native close.
CharacterFrame:ClearAllPoints()
CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
gamepadObserver:OnUpdate(0.01)
assert(CharacterFrame.points[1][1] == "CENTER" and CharacterFrame.points[1][4] == 635
        and CharacterFrame.points[1][5] == -450 and not calendar:IsShown(),
    "a close must restore surviving panels before the next 50 ms poll and keep the closed panel hidden")
calendar:ClearAllPoints()
calendar:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -36)
calendar.shown = true
gamepadObserver:OnUpdate(0.01)
assert(calendar.points[1][1] == "CENTER", "reopened destinations must also bypass the regular poll")
for _, name in ipairs(openingDestinations) do _G[name] = nil end
OffhandCharDB.foreverGamepadPanelOffsets = nil
addon.db.showGamepadPanelDragHandles = previousDragHandles

local shownPopup
addon.ShowPopup = function(_, key) shownPopup = key end
assert(addon.Mainhand:PromptReload()
        and shownPopup == "OFFHAND_MAINHAND_LAYOUT_RELOAD"
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept == nil
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.button2 == nil,
    "native Gamepad reload prompt retained a protected ReloadUI callback")
currentInterfaceStyle = 1
assert(addon.Mainhand:PromptReload(true)
        and type(StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept) == "function"
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.offhandAcceptBeforeHide == true
        and reloadCalls == 0,
    "Forever keyboard HUD reload must use the visible-parent callback path")
assert(StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.text:find(addon.L.SETUP_REVIEW_HUD, 1, true),
    "the calibration reload prompt must show the final HUD review")
addon.isForever = false
assert(addon.Mainhand:PromptReload()
        and type(StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept) == "function"
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.offhandAcceptBeforeHide == true
        and reloadCalls == 0,
    "Forever keyboard HUD reload must use the visible-parent callback path")
addon.isForever = false
assert(addon.Mainhand:PromptReload()
        and type(StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept) == "function",
    "keyboard reload prompt did not retain its normal reload action")
assert(not StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.text:find(addon.L.SETUP_REVIEW_HUD, 1, true),
    "standalone reload reused an earlier calibration's guidance")
StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept()
assert(reloadCalls == 1, "keyboard reload prompt did not call ReloadUI")
do
    local previousUI, previousReload, previousCombat = C_UI, ReloadUI, InCombatLockdown
    local modernReloads = 0
    C_UI, ReloadUI = { Reload = function() modernReloads = modernReloads + 1 end }, nil
    addon.Mainhand:PromptReload()
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept()
    assert(modernReloads == 1, "HUD reload must support the namespaced API without ReloadUI")
    addon.Mainhand:PromptReload()
    local click = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept
    addon.isForever = true
    currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
    click()
    assert(modernReloads == 1 and not StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept,
        "a stale reload button must recheck controller ownership and show manual guidance")
    currentInterfaceStyle = 1
    addon.isForever = false
    addon.Mainhand:PromptReload()
    click = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept
    InCombatLockdown = function() return true end
    click()
    assert(modernReloads == 1 and not StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept,
        "a stale reload button must recheck combat and show manual guidance")
    C_UI, ReloadUI, InCombatLockdown = previousUI, previousReload, previousCombat
end
addon.isForever = true
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad

CharacterFrame = frame("CharacterFrame")
CharacterFrame.w, CharacterFrame.h, CharacterFrame.parent = 520, 700, UIParent
CharacterFrame.left, CharacterFrame.top = 2460, 1070
CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
SpellBookFrame = frame("SpellBookFrame")
SpellBookFrame.w, SpellBookFrame.h, SpellBookFrame.parent = 700, 820, UIParent
SpellBookFrame.protected = true
SpellBookFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -120)
PlayerSpellsFrame = frame("PlayerSpellsFrame")
PlayerSpellsFrame.w, PlayerSpellsFrame.h, PlayerSpellsFrame.parent = 1000, 820, UIParent
PlayerSpellsFrame.left, PlayerSpellsFrame.top = 2200, 1100
PlayerSpellsFrame.protected = true
PlayerSpellsFrame.shown = false
PlayerSpellsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -120)
ProfessionsBookFrame = frame("ProfessionsBookFrame")
ProfessionsBookFrame.w, ProfessionsBookFrame.h, ProfessionsBookFrame.parent = 550, 525, UIParent
ProfessionsBookFrame.left, ProfessionsBookFrame.top = 2350, 1150
ProfessionsBookFrame.protected = true
ProfessionsBookFrame.shown = false
ProfessionsBookFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -125)
ProfessionsFrame = frame("ProfessionsFrame")
ProfessionsFrame.w, ProfessionsFrame.h, ProfessionsFrame.parent = 700, 800, UIParent
ProfessionsFrame.left, ProfessionsFrame.top = 2350, 1150
ProfessionsFrame.protected = true
ProfessionsFrame.shown = false
ProfessionsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 25, -125)
QuestFrame = frame("QuestFrame")
QuestFrame.w, QuestFrame.h, QuestFrame.parent = 390, 520, UIParent
QuestFrame.left, QuestFrame.top = 2400, 1080
QuestFrame.protected = true
QuestFrame.shown = false
QuestFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -130)
SettingsPanel = frame("SettingsPanel")
SettingsPanel.w, SettingsPanel.h, SettingsPanel.parent = 980, 760, UIParent
SettingsPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
AddonList = frame("AddonList")
AddonList.w, AddonList.h, AddonList.parent = 500, 600, UIParent
AddonList:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
HelpFrame = frame("HelpFrame")
HelpFrame.w, HelpFrame.h, HelpFrame.parent = 1024, 768, UIParent
HelpFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
LegacySystemFrame = frame("LegacySystemFrame")
LegacySystemFrame.w, LegacySystemFrame.h, LegacySystemFrame.parent = 900, 650, UIParent
LegacySystemFrame.protected = true
LegacySystemFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
FriendsFrame = frame("FriendsFrame")
FriendsFrame.w, FriendsFrame.h, FriendsFrame.parent = 430, 700, UIParent
FriendsFrame.left, FriendsFrame.top = 2500, 1080
FriendsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
CommunitiesFrame = frame("CommunitiesFrame")
CommunitiesFrame.w, CommunitiesFrame.h, CommunitiesFrame.parent = 850, 600, UIParent
CommunitiesFrame.protected = true
CommunitiesFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
CollectionsJournal = frame("CollectionsJournal")
CollectionsJournal.w, CollectionsJournal.h, CollectionsJournal.parent = 760, 650, UIParent
CollectionsJournal.protected = true
CollectionsJournal:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
LootFrame = frame("LootFrame")
LootFrame.w, LootFrame.h, LootFrame.parent = 220, 290, UIParent
LootFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 30, -140)
ContainerFrameCombinedBags = frame("ContainerFrameCombinedBags")
ContainerFrameCombinedBags.w, ContainerFrameCombinedBags.h = 520, 620
ContainerFrameCombinedBags.parent, ContainerFrameCombinedBags.shown = UIParent, false
ContainerFrameCombinedBags:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -150)
ContainerFrame1 = frame("ContainerFrame1")
ContainerFrame1.w, ContainerFrame1.h = 260, 520
ContainerFrame1.parent, ContainerFrame1.shown = UIParent, false
ContainerFrame1:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -160)
local centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 8 and CharacterFrame.points[1][1] == "CENTER"
        and CharacterFrame.points[1][2] == UIParent
        and CharacterFrame.points[1][3] == "CENTER"
        and CharacterFrame.points[1][4] == 720
        and CharacterFrame.points[1][5] == -560,
    "native Gamepad destination panel was not centered on Mainhand")
assert(SettingsPanel.points[1][4] == 720 and SettingsPanel.points[1][5] == -560
        and AddonList.points[1][4] == 720 and AddonList.points[1][5] == -560
        and HelpFrame.points[1][4] == 720 and HelpFrame.points[1][5] == -560,
    "Gamepad Options, AddOns, and Customer Support were not centered on Mainhand")
assert(LegacySystemFrame.points[1][4] == 720 and LegacySystemFrame.points[1][5] == -560
        and FriendsFrame.points[1][4] == 720 and FriendsFrame.points[1][5] == -560
        and CommunitiesFrame.points[1][4] == 720 and CommunitiesFrame.points[1][5] == -560
        and CollectionsJournal.points[1][4] == 720 and CollectionsJournal.points[1][5] == -560,
    "Legacy, Social, Communities, and Collections were not centered on Mainhand")
assert(SpellBookFrame.points[1][1] == "TOPLEFT",
    "the protected Spellbook child must remain untouched")
assert(LootFrame.points[1][1] == "TOPLEFT",
    "LootFrame must remain entirely outside the destination-panel adapter")
assert(CharacterFrame.OnShow == nil and CharacterFrame.OnUpdate == nil,
    "destination centering must not install scripts on Blizzard panel trees")
local destinationMover = _G.OffhandForeverGamepadPanelMover
assert(destinationMover and destinationMover.parent == UIParent
        and destinationMover.shown and destinationMover.dragButton == "LeftButton",
    "native Gamepad destination movement must use an addon-owned UIParent sibling")
assert(addon.Mainhand:AreForeverGamepadDragHandlesShown(),
    "Forever Gamepad destination drag handles must default to visible")
assert(not CharacterFrame.movable and CharacterFrame.startMovingCalls == nil,
    "destination movement must not adopt or directly drag the Blizzard panel")
assert(_G.OffhandForeverGamepadPanelMover_FriendsFrame
        and _G.OffhandForeverGamepadPanelMover_FriendsFrame.shown,
    "an unprotected allowlisted destination did not receive a safe independent mover")
assert(_G.OffhandForeverGamepadPanelMover_LegacySystemFrame
        and _G.OffhandForeverGamepadPanelMover_CommunitiesFrame
        and _G.OffhandForeverGamepadPanelMover_CollectionsJournal,
    "explicit protected destination roots did not receive independent movers")

customBagAddon = true
ContainerFrameCombinedBags.shown = true
ContainerFrame1.shown = true
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 8
        and ContainerFrameCombinedBags.points[1][1] == "TOPLEFT"
        and ContainerFrame1.points[1][1] == "TOPLEFT"
        and _G.OffhandForeverGamepadPanelMover_ContainerFrameCombinedBags == nil
        and _G.OffhandForeverGamepadPanelMover_ContainerFrame1 == nil,
    "replacement bag ownership leaked native bag placement or drag handles")
assert(addon.Mainhand:GetForeverGamepadDestinationPanelDiagnostics()
        :find("ContainerFrame1:replacement-owned", 1, true),
    "replacement bag ownership was not diagnosable")
ContainerFrameCombinedBags.shown = false
ContainerFrame1.shown = false
customBagAddon = false

local nativeBackpack = ContainerFrameCombinedBags
nativeBackpack.left, nativeBackpack.top, nativeBackpack.scale = 2350, 1000, 0.75
nativeBackpack.shown = true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
local backpackMover = _G.OffhandForeverGamepadPanelMover_ContainerFrameCombinedBags
assert(backpackMover and backpackMover.shown, "the stock combined backpack must expose its independent mover")
backpackMover.centerX, backpackMover.centerY = 2720, 800
backpackMover:OnDragStart()
backpackMover.centerX, backpackMover.centerY = 720, 980
backpackMover:OnDragStop()
local backpackOffset = OffhandCharDB.foreverGamepadPanelOffsets.ContainerFrameCombinedBags
local backpackPoint = nativeBackpack.points[1]
assert(backpackOffset.x == -2000 and backpackOffset.y == 180
        and math.abs(2000 + backpackPoint[4] * nativeBackpack.scale - 720) < 0.01,
    "dragging the stock backpack across the seam must save an Offhand position at native bag scale")
nativeBackpack.shown = false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(not nativeBackpack:IsShown() and not backpackMover.shown,
    "closing the stock backpack must hide the independent mover")
nativeBackpack:ClearAllPoints()
nativeBackpack:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -32, 60)
nativeBackpack.shown = true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1] == "CENTER" and nativeBackpack.points[1][4] == backpackPoint[4]
        and nativeBackpack.points[1][5] == backpackPoint[5],
    "reopening the backpack must restore the saved Offhand position after Blizzard resets the anchor")

-- Controller mode owns a different observer and position store from keyboard
-- bags. Its native reopening path must preserve the last permitted root anchor.
local function PermitCombatBag(f)
    f.CanChangeProtectedState=function() return true end
    f.IsAnchoringRestricted=function() return false end
    f.IsAnchoringSecret=function() return false end
end
PermitCombatBag(nativeBackpack)
local originalClamp=nativeBackpack.SetClampedToScreen
nativeBackpack.SetClampedToScreen=function(self,value)
    assert(not unitCombat,'combat bag repair must not alter native clamping')
    return originalClamp(self,value)
end
local savedControllerOffset=OffhandCharDB.foreverGamepadPanelOffsets.ContainerFrameCombinedBags
unitCombat=true
nativeBackpack.shown=false
gamepadObserver:OnUpdate(.1)
nativeBackpack:ClearAllPoints()
nativeBackpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
nativeBackpack.shown=true
gamepadObserver:OnUpdate(.1)
assert(nativeBackpack.points[1][1]=='CENTER'
    and nativeBackpack.points[1][4]==backpackPoint[4]
    and nativeBackpack.points[1][5]==backpackPoint[5],
    'controller combat reopening must preserve the saved Offhand bag anchor')
assert(not backpackMover.shown and OffhandCharDB.foreverGamepadPanelOffsets.ContainerFrameCombinedBags==savedControllerOffset,
    'combat repair must hide the mover and preserve the controller position store')
ContainerFrame1.shown=true
ContainerFrame1:ClearAllPoints()
ContainerFrame1:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(ContainerFrame1.points[1][1]=='BOTTOMRIGHT',
    'a controller bag first seen during combat must defer')
ContainerFrame1.shown=false
unitCombat=false
OffhandCharDB.foreverGamepadPanelOffsets.ContainerFrameCombinedBags={x=40,y=30}
addon.Mainhand:CenterForeverGamepadDestinationPanels()
local mainBagPoint={nativeBackpack:GetPoint(1)}
unitCombat=true
InCombatLockdown=function() return true end
nativeBackpack:ClearAllPoints()
nativeBackpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1]=='CENTER' and nativeBackpack.points[1][4]==mainBagPoint[4],
    'controller combat reopening must also preserve Mainhand placement during lockdown')
InCombatLockdown=function() return false end
for _,method in ipairs({'IsForbidden','IsProtected','CanChangeProtectedState','IsAnchoringRestricted','IsAnchoringSecret'}) do
    local original=nativeBackpack[method]
    nativeBackpack[method]=function() return method~='CanChangeProtectedState' end
    nativeBackpack:ClearAllPoints()
    nativeBackpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
    addon.Mainhand:CenterForeverGamepadDestinationPanels()
    assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','restricted controller root must yield: '..method)
    nativeBackpack[method]=nil
    addon.Mainhand:CenterForeverGamepadDestinationPanels()
    assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','missing controller capability must yield: '..method)
    nativeBackpack[method]=original
end
local secret={}
issecretvalue=function(value) return value==secret end
nativeBackpack.CanChangeProtectedState=function() return secret end
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','secret controller capabilities must yield')
nativeBackpack.CanChangeProtectedState=function() return true end
local originalReadPoint=nativeBackpack.GetPoint
nativeBackpack.GetPoint=function() return secret,UIParent,'BOTTOMRIGHT',-32,60 end
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','secret controller anchor reads must yield')
nativeBackpack.GetPoint=nil
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','missing controller anchor reads must yield')
nativeBackpack.GetPoint=originalReadPoint
issecretvalue=nil
local originalBagPoint=nativeBackpack.SetPoint
local attemptedWrites=0
nativeBackpack.SetPoint=function() attemptedWrites=attemptedWrites+1;error('simulated protected write rejection') end
addon.Mainhand:CenterForeverGamepadDestinationPanels()
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(attemptedWrites==1,'failed controller combat anchor must suspend until combat ends')
nativeBackpack.SetPoint=originalBagPoint
unitCombat=false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
unitCombat=true
nativeBackpack:ClearAllPoints()
nativeBackpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
attemptedWrites=0
nativeBackpack.SetPoint=function() attemptedWrites=attemptedWrites+1 end
addon.Mainhand:CenterForeverGamepadDestinationPanels()
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(attemptedWrites==1,'silent controller anchor rejection must also suspend')
nativeBackpack.SetPoint=originalBagPoint
unitCombat=false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
unitCombat=true
customBagAddon=true
nativeBackpack:ClearAllPoints()
nativeBackpack:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-32,60)
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(nativeBackpack.points[1][1]=='BOTTOMRIGHT','replacement bags must retain controller combat ownership')
customBagAddon=false
unitCombat=false
OffhandCharDB.foreverGamepadPanelOffsets.ContainerFrameCombinedBags=savedControllerOffset
nativeBackpack.SetClampedToScreen=originalClamp
nativeBackpack.shown = false

-- Separate controller bags keep Blizzard's container ancestry too.
ContainerFrameContainer=frame('ContainerFrameContainer')
ContainerFrameContainer.parent=UIParent
PermitCombatBag(ContainerFrameContainer)
PermitCombatBag(ContainerFrame1)
ContainerFrame1.parent=ContainerFrameContainer
ContainerFrame1.shown=true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
local separatePoint={ContainerFrame1:GetPoint(1)}
unitCombat=true
ContainerFrame1.shown=false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
ContainerFrame1:ClearAllPoints()
ContainerFrame1:SetPoint('BOTTOMRIGHT',ContainerFrameContainer,'BOTTOMRIGHT',-32,60)
ContainerFrame1.shown=true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(ContainerFrame1.points[1][1]=='CENTER' and ContainerFrame1.points[1][4]==separatePoint[4]
    and ContainerFrame1.parent==ContainerFrameContainer,
    'separate controller bags must repair the root anchor without reparenting')
unitCombat=false
ContainerFrame1.shown=false

nativeBackpack.shown = false

FriendsFrame.shown = false
SocialUIFrame = frame("SocialUIFrame")
SocialUIFrame.w, SocialUIFrame.h, SocialUIFrame.parent = 430, 700, UIParent
SocialUIFrame.centerX, SocialUIFrame.centerY = 2720, 720
SocialUIFrame.protected = true
SocialUIFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 15, -105)
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 8 and SocialUIFrame.points[1][1] == "CENTER"
        and _G.OffhandForeverGamepadPanelMover_SocialUIFrame
        and _G.OffhandForeverGamepadPanelMover_SocialUIFrame.shown
        and _G.OffhandForeverGamepadPanelMover_SocialUIFrame._OffhandPanelName
            == "FriendsFrame",
    "Forever's live SocialUIFrame root did not receive the canonical safe mover: moved="
        .. tostring(centeredPanels) .. " point="
        .. tostring(SocialUIFrame.points[1] and SocialUIFrame.points[1][1])
        .. " mover=" .. tostring(_G.OffhandForeverGamepadPanelMover_SocialUIFrame)
        .. " shown=" .. tostring(_G.OffhandForeverGamepadPanelMover_SocialUIFrame
            and _G.OffhandForeverGamepadPanelMover_SocialUIFrame.shown)
        .. " canonical=" .. tostring(_G.OffhandForeverGamepadPanelMover_SocialUIFrame
            and _G.OffhandForeverGamepadPanelMover_SocialUIFrame._OffhandPanelName))
SocialUIFrame.shown = false
FriendsFrame.shown = true
assert(addon.Mainhand:SetForeverGamepadDragHandlesShown(false)
        and addon.db.showGamepadPanelDragHandles == false,
    "the Forever Gamepad drag-handle setting was not disabled")
assert(not destinationMover.shown
        and not _G.OffhandForeverGamepadPanelMover_FriendsFrame.shown,
    "disabling Gamepad drag handles did not hide existing movers")
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 8 and CharacterFrame.points[1][1] == "CENTER"
        and not destinationMover.shown,
    "hidden Gamepad drag handles changed placement or reappeared during centering")
assert(addon.Mainhand:SetForeverGamepadDragHandlesShown(true)
        and addon.db.showGamepadPanelDragHandles == true
        and destinationMover.shown
        and _G.OffhandForeverGamepadPanelMover_FriendsFrame.shown,
    "re-enabling Gamepad drag handles did not restore visible movers")
destinationMover.centerX, destinationMover.centerY = 2720, 760
assert(destinationMover._OffhandTarget == CharacterFrame
        and destinationMover:GetCenter() == 2720,
    "the independent Gamepad mover did not retain its active target")
destinationMover.OnDragStart(destinationMover)
assert(destinationMover._OffhandDragging
        and destinationMover._OffhandDragStartX == 2720,
    "the independent Gamepad mover did not begin its addon-owned gesture")
destinationMover.centerX, destinationMover.centerY = 2820, 710
destinationMover.OnDragStop(destinationMover)
local movedOffset = OffhandCharDB.foreverGamepadPanelOffsets
    and OffhandCharDB.foreverGamepadPanelOffsets.CharacterFrame
assert(CharacterFrame.points[1][4] == 820 and CharacterFrame.points[1][5] == -610,
    "the independent Gamepad mover did not persist and apply its completed delta: "
        .. tostring(CharacterFrame.points[1][4]) .. ","
        .. tostring(CharacterFrame.points[1][5]) .. " offset="
        .. tostring(movedOffset and movedOffset.x) .. ","
        .. tostring(movedOffset and movedOffset.y))
assert(OffhandCharDB.foreverGamepadPanelOffsets.CharacterFrame.x == 100
        and OffhandCharDB.foreverGamepadPanelOffsets.CharacterFrame.y == -50,
    "the Gamepad panel offset was not saved per character")
-- Native focus can show the first spell tooltip while the panel is still
-- at Blizzard's workspace anchor. The item follows the panel's next anchor.
addon.modules = addon.modules or {}
assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
addon.db.seamRedirect = true
metrics.workspaceLeft, metrics.workspaceRight = 0, 1440
metrics.workspaceBottom, metrics.workspaceTop = 0, 2560
PlayerSpellsFrame.SpellBookFrame = SpellBookFrame
SpellBookFrame.parent = PlayerSpellsFrame
local spellEntry = frame()
spellEntry.parent = SpellBookFrame
spellEntry.top, spellEntry.bottom = 650, 610
local mainhandSpellLeft = 1700
function spellEntry:GetLeft()
    return PlayerSpellsFrame.points[1][1] == "CENTER" and mainhandSpellLeft or 320
end
function spellEntry:GetRight() return self:GetLeft() + 40 end
local spellTooltip = frame("GameTooltip")
local spellInsets, spellClampWrites = {0, 0, 0, 0}, 0
spellTooltip.left, spellTooltip.right = 250, 320
spellTooltip.top, spellTooltip.bottom = 700, 650
function spellTooltip:GetOwner() return spellEntry end
function spellTooltip:GetClampRectInsets() return unpack(spellInsets) end
function spellTooltip:SetClampRectInsets(...)
    spellInsets = {...}
    spellClampWrites = spellClampWrites + 1
end
-- Match the live 70888 trace: changing clamp insets alone leaves the
-- tooltip's rendered rectangle at the old clamp until its point is reapplied.
local spellAnchorWrites, setSpellTooltipPoint = 0, spellTooltip.SetPoint
function spellTooltip:SetPoint(point, relative, relativePoint, x, y)
    spellAnchorWrites = spellAnchorWrites + 1
    setSpellTooltipPoint(self, point, relative, relativePoint, x, y)
    if spellInsets[1] == -1452 then
        if point == "BOTTOMLEFT" then
            self.left = relative:GetRight() + x
            self.right = self.left + 70
        else
            self.right = relative:GetLeft() + x
            self.left = self.right - 70
        end
    end
end
spellTooltip:SetPoint("BOTTOMRIGHT", spellEntry, "TOPLEFT", 0, 0)
GameTooltip = spellTooltip
assert(addon.PopupBounds:UpdateClassicTooltipClamp(spellTooltip))
assert(spellInsets[1] == -12 and spellInsets[2] == 2572,
    "the fixture must initially clamp to the workspace")
PlayerSpellsFrame.shown = true
ProfessionsBookFrame.shown = true
ProfessionsFrame.shown = true
QuestFrame.shown = true
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 12 and PlayerSpellsFrame.points[1][1] == "CENTER"
        and PlayerSpellsFrame.points[1][2] == UIParent
        and PlayerSpellsFrame.points[1][3] == "CENTER"
        and PlayerSpellsFrame.points[1][4] == 720
        and PlayerSpellsFrame.points[1][5] == -560
        and ProfessionsBookFrame.points[1][1] == "CENTER"
        and ProfessionsBookFrame.points[1][2] == UIParent
        and ProfessionsBookFrame.points[1][3] == "CENTER"
        and ProfessionsBookFrame.points[1][4] == 720
        and ProfessionsBookFrame.points[1][5] == -560
        and ProfessionsFrame.points[1][1] == "CENTER"
        and ProfessionsFrame.points[1][2] == UIParent
        and ProfessionsFrame.points[1][3] == "CENTER"
        and ProfessionsFrame.points[1][4] == 720
        and ProfessionsFrame.points[1][5] == -560
        and QuestFrame.points[1][1] == "CENTER"
        and QuestFrame.points[1][4] == 720
        and QuestFrame.points[1][5] == -560,
    "the narrow protected Gamepad placement exception was not applied safely")
assert(spellInsets[1] == -1452 and spellInsets[2] == 12 and spellClampWrites == 2,
    "the Spellbook tooltip must adopt Mainhand's clamp after the move")
local spellPoint, spellRelative, spellRelativePoint, spellX, spellY = spellTooltip:GetPoint(1)
assert(spellTooltip:GetLeft() == spellEntry:GetRight() and spellAnchorWrites == 2
        and spellPoint == "BOTTOMLEFT" and spellRelative == spellEntry
        and spellRelativePoint == "TOPRIGHT" and spellX == 0 and spellY == 0,
    "the first spell tooltip must reflow to the right of its owner when it fits")
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(spellClampWrites == 2 and spellAnchorWrites == 2,
    "an already positioned spellbook must not rewrite tooltip bounds or its anchor")

-- Reopen at the native workspace anchor with a saved panel near Mainhand's
-- right edge. Keep the valid native left anchor if the tooltip would overflow.
addon.PopupBounds:RestoreClassicTooltipClamp(spellTooltip)
mainhandSpellLeft = 3940
PlayerSpellsFrame:ClearAllPoints()
PlayerSpellsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -120)
spellTooltip.left, spellTooltip.right = 250, 320
spellTooltip:ClearAllPoints()
spellTooltip:SetPoint("BOTTOMRIGHT", spellEntry, "TOPLEFT", 0, 0)
assert(addon.PopupBounds:UpdateClassicTooltipClamp(spellTooltip))
addon.Mainhand:CenterForeverGamepadDestinationPanels()
spellPoint, spellRelative, spellRelativePoint = spellTooltip:GetPoint(1)
assert(spellTooltip:GetRight() == spellEntry:GetLeft() and spellAnchorWrites == 4
        and spellPoint == "BOTTOMRIGHT" and spellRelative == spellEntry and spellRelativePoint == "TOPLEFT",
    "an opening spell tooltip must keep the native left anchor when it cannot fit on the right")
addon.PopupBounds:RestoreClassicTooltipClamp(spellTooltip)
GameTooltip = nil
addon.db.seamRedirect = nil

local spellsMover = _G.OffhandForeverGamepadPanelMover_PlayerSpellsFrame
local professionsMover = _G.OffhandForeverGamepadPanelMover_ProfessionsBookFrame
local professionsFrameMover = _G.OffhandForeverGamepadPanelMover_ProfessionsFrame
local questMover = _G.OffhandForeverGamepadPanelMover_QuestFrame
assert(spellsMover and professionsMover and professionsFrameMover and questMover,
    "explicit protected Gamepad destinations did not receive isolated movers")
assert(SpellBookFrame.points[1][1] == "TOPLEFT",
    "centering PlayerSpellsFrame must not mutate its SpellBook child")
assert(PlayerSpellsFrame.OnShow == nil and PlayerSpellsFrame.OnUpdate == nil
        and ProfessionsBookFrame.OnShow == nil and ProfessionsBookFrame.OnUpdate == nil
        and ProfessionsFrame.OnShow == nil and ProfessionsFrame.OnUpdate == nil,
    "protected Gamepad placement must not install scripts on Blizzard panel trees")
assert(PlayerSpellsFrame.clamped == nil and ProfessionsBookFrame.clamped == nil
        and ProfessionsFrame.clamped == nil,
    "protected Gamepad placement must change only the root anchor")
assert(addon.Mainhand:GetForeverGamepadDestinationPanelDiagnostics()
        :find("CharacterFrame:centered", 1, true),
    "native Gamepad destination centering was not diagnosable")
OffhandCharDB.mainhandLayout = nil
currentInterfaceStyle = 1
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 0 and CharacterFrame.points[1][1] == "TOPLEFT"
        and CharacterFrame.points[1][2] == UIParent
        and PlayerSpellsFrame.points[1][1] == "CENTER"
        and ProfessionsBookFrame.points[1][1] == "CENTER"
        and ProfessionsFrame.points[1][1] == "CENTER",
    "keyboard transition rewrote a visible protected destination panel")
PlayerSpellsFrame.shown = false
ProfessionsBookFrame.shown = false
ProfessionsFrame.shown = false
QuestFrame.shown = false
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 0 and PlayerSpellsFrame.points[1][1] == "TOPLEFT"
        and ProfessionsBookFrame.points[1][1] == "TOPLEFT"
        and ProfessionsFrame.points[1][1] == "TOPLEFT",
    "hidden protected destinations did not restore after keyboard mode settled")
OffhandCharDB.mainhandLayout = { controllerLayout = true }
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 0 and FriendsFrame.points[1][1] == "TOPLEFT"
        and not _G.OffhandForeverGamepadPanelMover_FriendsFrame.shown,
    "a recorded Gamepad HUD leaked Social placement or its mover into keyboard mode")
OffhandCharDB.mainhandLayout = {
    generatedID = 6,
    generatedName = "Offhand - Mainhand - Legacy Tester",
}
FriendsFrame:ClearAllPoints()
FriendsFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10, -100)
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 0 and FriendsFrame.points[1][1] == "TOPLEFT"
        and FriendsFrame.points[1][4] == 10 and FriendsFrame.points[1][5] == -100
        and not _G.OffhandForeverGamepadPanelMover_FriendsFrame.shown,
    "a legacy Mainhand layout leaked Social placement or its mover into keyboard mode")
centeredPanels = addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(centeredPanels == 0 and FriendsFrame.points[1][1] == "TOPLEFT"
        and FriendsFrame.points[1][4] == 10 and FriendsFrame.points[1][5] == -100,
    "the inactive Gamepad panel observer rewrote a keyboard-mode anchor")
OffhandCharDB.mainhandLayout = nil
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad

-- The Merchant opens through an NPC interaction, not the radial menu. It must
-- use the same shown-root geometry path without acquiring visibility or item
-- action handlers, and a saved offset must never synthesize an interaction.
MerchantFrame = frame("MerchantFrame")
MerchantFrame.w, MerchantFrame.h, MerchantFrame.parent = 336, 444, UIParent
MerchantFrame.shown = false
MerchantFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
local nativeMerchantShow, nativeMerchantHide = function() end, function() end
MerchantFrame.OnShow, MerchantFrame.OnHide = nativeMerchantShow, nativeMerchantHide
MerchantFrame.Show = function() error("Offhand must not open an NPC interaction") end
MerchantFrame.Hide = function() error("Offhand must not close an NPC interaction") end
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1][1] == "TOPLEFT"
        and not _G.OffhandForeverGamepadPanelMover_MerchantFrame,
    "a hidden merchant must remain native and must not acquire a visible mover")
unitCombat, MerchantFrame.shown = true, true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1][1] == "TOPLEFT",
    "Merchant placement must remain unchanged while the player is in combat")
unitCombat = false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
local merchantAnchor = MerchantFrame.points[1]
assert(merchantAnchor[1] == "CENTER" and merchantAnchor[2] == UIParent
        and merchantAnchor[4] == 720 and merchantAnchor[5] == -560,
    "the player-opened Gamepad Merchant must center inside physical Mainhand")
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1] == merchantAnchor,
    "an unchanged Merchant anchor must not be rewritten by every observer pass")
assert(MerchantFrame.OnShow == nativeMerchantShow and MerchantFrame.OnHide == nativeMerchantHide
        and MerchantFrame.OnUpdate == nil and MerchantFrame._OffhandMovable == nil
        and not MerchantFrame.movable and MerchantFrame.startMovingCalls == nil,
    "Merchant positioning must preserve native scripts, bookkeeping and drag ownership")
OffhandCharDB.foreverGamepadPanelOffsets.MerchantFrame = { x = 80, y = -20 }
MerchantFrame.shown = false
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(not MerchantFrame.shown and not _G.OffhandForeverGamepadPanelMover_MerchantFrame.shown,
    "closing the merchant must hide its independent mover without reopening it")
MerchantFrame.shown = true
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1][4] == 800 and MerchantFrame.points[1][5] == -580,
    "a later native Merchant opening must retain the saved Gamepad offset")
currentInterfaceStyle = 1
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1][1] == "TOPLEFT" and MerchantFrame.points[1][5] == -104,
    "keyboard mode must restore the captured native Merchant anchor")
MerchantFrame.protected = true
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
addon.Mainhand:CenterForeverGamepadDestinationPanels()
assert(MerchantFrame.points[1][1] == "TOPLEFT",
    "Merchant support must not silently expand the protected-position allowlist")
MerchantFrame.shown = false

GamepadReticle = frame("GamepadReticle")
GamepadReticle:SetPoint("CENTER", UIParent, "BOTTOM", 0, 1280)
local nativeReticleUpdate = function() end
GamepadReticle.OnUpdate = nativeReticleUpdate
assert(addon.Mainhand:CenterForeverGamepadReticle())
assert(GamepadReticle.points[1][4] == 720 and GamepadReticle.points[1][5] == -560,
    "the Gamepad reticle must use physical Mainhand center, not span center")
local reticleAnchor = GamepadReticle.points[1]
assert(addon.Mainhand:CenterForeverGamepadReticle()
        and GamepadReticle.points[1] == reticleAnchor,
    "an already-centered reticle must not receive repeated writes")
assert(GamepadReticle.OnUpdate == nativeReticleUpdate and not GamepadReticle.movable
        and not _G.OffhandForeverGamepadPanelMover_GamepadReticle,
    "reticle placement must not acquire scripts, a mover or targeting ownership")
currentInterfaceStyle = 1
assert(addon.Mainhand:CenterForeverGamepadReticle())
assert(GamepadReticle.points[1][3] == "BOTTOM" and GamepadReticle.points[1][5] == 1280,
    "keyboard mode must restore the reticle's captured native anchor")
currentInterfaceStyle = Enum.InputDeviceInterfaceType.Gamepad
GamepadReticle.scale = 0.5
assert(addon.Mainhand:CenterForeverGamepadReticle())
assert(GamepadReticle.points[1][4] == 1440 and GamepadReticle.points[1][5] == -1120,
    "reticle placement must convert the root's effective scale")
unitCombat = true
GamepadReticle:ClearAllPoints()
GamepadReticle:SetPoint("CENTER", UIParent, "BOTTOM", 0, 1280)
assert(not addon.Mainhand:CenterForeverGamepadReticle()
        and GamepadReticle.points[1][5] == 1280,
    "the reticle adapter must defer during combat")
unitCombat = false
GamepadReticle.protected = true
assert(not addon.Mainhand:CenterForeverGamepadReticle(),
    "the cosmetic reticle must not gain a protected-frame exception")
GamepadReticle = nil

addon.Canvas = { IsFrameOnWorkspace = function(frame)
    return frame == CharacterFrame or frame == FriendsFrame
end }
local shownWorkspacePanels = addon.Mainhand:GetShownForeverGamepadWorkspacePanels()
assert(#shownWorkspacePanels == 2,
    "Back/Escape policy must discover actual visible workspace placement rather than saved intent")
addon.Canvas = nil

Enum.EditModeStatusTrackingBarSystemIndices = { StatusTrackingBar1 = 1, StatusTrackingBar2 = 2 }
local gamepadPresetSystems = EditModePresetLayoutManager.presetLayoutInfo[1].systems
gamepadPresetSystems[#gamepadPresetSystems + 1] = {
    system = Enum.EditModeSystem.StatusTrackingBar, systemIndex = 2, isInDefaultPosition = true,
    anchorInfo = { point = "BOTTOMLEFT", relativeTo = "MainActionBar",
        relativePoint = "BOTTOMRIGHT", offsetX = 40, offsetY = 0 },
}
layoutData = { activeLayout = 1, layouts = {} }
saved, activated, layoutAdded, saveCount = nil, nil, nil, 0
OffhandCharDB.mainhandLayout = {
    controllerLayout = true,
    sourcePreset = true,
    sourceID = 2,
    sourceName = "Classic",
    generatedName = "Offhand - Mainhand - Gamepad - Tester",
}
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand - Mainhand - Gamepad - Tester" and moved == 11,
    "the native Gamepad preset was not copied into a custom Mainhand layout")
assert(layoutAdded == 4 and activated == nil and saved ~= nil and saveCount == 1
        and #layoutData.layouts == 1 and layoutData.activeLayout == 4,
    "the native Gamepad custom layout was not saved and selected")
generated = EditModePresetLayoutManager.presetLayoutInfo[1]
assert(generated.systems[5].anchorInfo.offsetX == 0
        and generated.systems[5].anchorInfo.offsetY == 0,
    "the source Gamepad preset was mutated")
assert(generated.systems[2].anchorInfo.point == "TOPRIGHT"
        and generated.systems[2].anchorInfo.offsetX == -20
        and generated.systems[2].anchorInfo.offsetY == -30,
    "the source Gamepad preset was incorrectly refined in place")
assert(OffhandCharDB.mainhandLayout.controllerLayout == true
        and OffhandCharDB.mainhandLayout.sourceID == 1
        and OffhandCharDB.mainhandLayout.presetApplied == nil,
    "the Gamepad custom layout retained stale keyboard-preset provenance")
assert(layoutData.activeLayout == 4 and OffhandCharDB.foreverEditModeLayoutID == 4,
    "the native Gamepad path did not record its selected custom layout")
assert(saved.layouts[1].systems[1].anchorInfo.offsetY == -560
        and saved.layouts[1].systems[14].anchorInfo.offsetY == 0,
    "keyboard-only Damage Meter or Buff Frame insets leaked into the Gamepad layout")
local gamepadXP = saved.layouts[1].systems[2].anchorInfo
local gamepadStatus = saved.layouts[1].systems[#gamepadPresetSystems].anchorInfo
assert(gamepadXP.point == "BOTTOM" and gamepadXP.relativePoint == "BOTTOM"
        and gamepadXP.relativeTo == "UIParent" and gamepadXP.offsetX == 720
        and gamepadXP.offsetY == 12,
    "Gamepad XP must be centered within Mainhand and raised above its bottom edge")
assert(gamepadStatus.point == "BOTTOM" and gamepadStatus.relativeTo == "UIParent"
        and gamepadStatus.offsetX == 720 and gamepadStatus.offsetY == 30,
    "the secondary Gamepad status bar must be centered and stacked above XP")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand - Mainhand - Gamepad - Tester"
        and #layoutData.layouts == 1 and saveCount == 2
        and EditModePresetLayoutManager.presetLayoutInfo[1].systems[5].anchorInfo.offsetX == 0,
    "repeating the Gamepad action duplicated a layout or mutated the preset")

local originalGamepadRect = addon.Mainhand.rect
addon.Mainhand.rect = { left = 0, right = 2560, bottom = 1120, top = 2560,
    width = 2560, height = 1440, isSpanned = true }
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(saved.layouts[1].systems[2].anchorInfo.offsetX == -720
        and saved.layouts[1].systems[2].anchorInfo.offsetY == 1132
        and saved.layouts[1].systems[#gamepadPresetSystems].anchorInfo.offsetX == -720
        and saved.layouts[1].systems[#gamepadPresetSystems].anchorInfo.offsetY == 1150,
    "both Gamepad status bars must follow an upper-left Mainhand viewport")
addon.Mainhand.rect = originalGamepadRect
local secondarySource = gamepadPresetSystems[#gamepadPresetSystems]
secondarySource.isInDefaultPosition = false
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(saved.layouts[1].systems[#gamepadPresetSystems].anchorInfo.relativeTo == "MainActionBar"
        and saved.layouts[1].systems[#gamepadPresetSystems].anchorInfo.offsetX == 40,
    "an explicitly customized source status anchor must remain untouched")
secondarySource.isInDefaultPosition = true

-- Native Forever Gamepad has a dedicated main-action system, not ActionBar
-- MainBar. Its status entries are manager-relative, so neither the generic
-- UIParent transform nor keyboard-bar refinement can position them.
local syntheticGamepadSystems = gamepadPresetSystems
local nativeGamepadSystems = copyTable(syntheticGamepadSystems)
Enum.EditModeSystem.GamepadMainActionBar = 81
nativeGamepadSystems[5].system = Enum.EditModeSystem.GamepadMainActionBar
nativeGamepadSystems[5].systemIndex = nil
nativeGamepadSystems[5].anchorInfo = {
    point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 110,
}
for _, systemIndex in ipairs({ 2, #nativeGamepadSystems }) do
    nativeGamepadSystems[systemIndex].anchorInfo = {
        point = "BOTTOMLEFT", relativeTo = "StatusTrackingBarManager",
        relativePoint = "BOTTOMLEFT", offsetX = 0, offsetY = 0,
    }
end
EditModePresetLayoutManager.presetLayoutInfo[1].systems = nativeGamepadSystems
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(saved.layouts[1].systems[2].anchorInfo.relativeTo == "UIParent"
        and saved.layouts[1].systems[2].anchorInfo.offsetX == 720
        and saved.layouts[1].systems[2].anchorInfo.offsetY == 12
        and saved.layouts[1].systems[#nativeGamepadSystems].anchorInfo.offsetX == 720
        and saved.layouts[1].systems[#nativeGamepadSystems].anchorInfo.offsetY == 30,
    "native Gamepad status bars must update without a keyboard ActionBar MainBar entry")
assert(nativeGamepadSystems[2].anchorInfo.relativeTo == "StatusTrackingBarManager"
        and nativeGamepadSystems[5].anchorInfo.offsetX == 0,
    "native Gamepad source preset must remain unchanged")

-- The actual Gamepad preset lacks the keyboard MainBar entry, so minimap
-- and unit-frame placement must run without the keyboard refinement path.
local oldUnits, oldUnitSystem = Enum.EditModeUnitFrameSystemIndices, Enum.EditModeSystem.UnitFrame
Enum.EditModeSystem.UnitFrame = 80
Enum.EditModeUnitFrameSystemIndices = {Player = 0, Target = 1, Focus = 2}
local firstUnit = #nativeGamepadSystems + 1
for index, anchor in ipairs({
    {point = "BOTTOMRIGHT", offsetX = -185, offsetY = 295},
    {point = "BOTTOMLEFT", offsetX = 185, offsetY = 295},
    {point = "BOTTOMLEFT", offsetX = 386, offsetY = 316},
}) do
    anchor.relativeTo, anchor.relativePoint = "UIParent", "BOTTOM"
    nativeGamepadSystems[firstUnit + index - 1] = {
        system = Enum.EditModeSystem.UnitFrame, systemIndex = index - 1, isInDefaultPosition = true,
        anchorInfo = anchor,
    }
end
local mapIndex
for index, entry in ipairs(nativeGamepadSystems) do
    if entry.system == Enum.EditModeSystem.Minimap then mapIndex = index; break end
end
assert(mapIndex, "the Gamepad fixture needs a default minimap system")
nativeGamepadSystems[mapIndex].anchorInfo.offsetX, nativeGamepadSystems[mapIndex].anchorInfo.offsetY = 0, 0
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
local gamepadGenerated = saved.layouts[1].systems
local gamepadRect = addon.Mainhand.rect
assert(gamepadGenerated[mapIndex].anchorInfo.offsetX == gamepadRect.right - UIParent:GetWidth()
    and gamepadGenerated[mapIndex].anchorInfo.offsetY == gamepadRect.top - UIParent:GetHeight(),
    "the native Gamepad minimap must use the top-right of Mainhand")
local player, target, focus = gamepadGenerated[firstUnit].anchorInfo,
    gamepadGenerated[firstUnit + 1].anchorInfo, gamepadGenerated[firstUnit + 2].anchorInfo
local centerShift = (gamepadRect.left + gamepadRect.right - UIParent:GetWidth()) / 2
assert(player.point == "BOTTOMRIGHT" and target.point == "BOTTOMLEFT" and focus.point == "BOTTOMLEFT"
    and player.offsetX == centerShift - 185 and target.offsetX == centerShift + 185
    and focus.offsetX == centerShift + 386 and player.offsetY == gamepadRect.bottom + 295
    and target.offsetY == player.offsetY and focus.offsetY == gamepadRect.bottom + 316,
    "the native Gamepad unit frames must retain the preset's spacing and focus beside target")
assert(nativeGamepadSystems[firstUnit].anchorInfo.offsetY == 295,
    "generating a Gamepad layout must not write the built-in unit-frame anchors")
Enum.EditModeUnitFrameSystemIndices, Enum.EditModeSystem.UnitFrame = oldUnits, oldUnitSystem
EditModePresetLayoutManager.presetLayoutInfo[1].systems = syntheticGamepadSystems

-- A customized Forever Party entry can be relative to another Edit Mode
-- system and is therefore intentionally skipped by the generic translation.
-- The player's explicit Repair HUD action must rebase that exact protected
-- system through layout data, and must report failure if the payload has no
-- corresponding Party entry.
Enum.EditModeSystem.UnitFrame = 80
preset.systems[#preset.systems + 1] = {
    system = Enum.EditModeSystem.UnitFrame, systemIndex = Enum.EditModeUnitFrameSystemIndices.Party,
    isInDefaultPosition = false,
    anchorInfo = {
        point = "TOPLEFT", relativeTo = "OtherUnitFrame",
        relativePoint = "BOTTOMLEFT", offsetX = 17, offsetY = -23,
    },
}
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout({
    repairFrameName = "PartyFrame",
})
local repairedParty = saved.layouts[1].systems[#preset.systems]
assert(ok and moved == 12 and repairedParty.anchorInfo.relativeTo == "UIParent"
        and repairedParty.anchorInfo.relativePoint == "BOTTOMLEFT"
        and repairedParty.anchorInfo.offsetX == metrics.gameLeft + 24
        and repairedParty.anchorInfo.offsetY == metrics.gameTop - 180,
    "Repair HUD did not rebase the customized Party system into Mainhand")
preset.systems[#preset.systems] = nil
local unitSystem = Enum.EditModeSystem.UnitFrame
Enum.EditModeSystem.UnitFrame = nil
ok, localName = addon.Mainhand:CreateOrUpdateEditModeLayout({
    repairFrameName = "PartyFrame",
})
assert(not ok and localName == "repair-system",
    "Repair HUD claimed success without a Party system in the layout payload")
Enum.EditModeSystem.UnitFrame = unitSystem

ok, why = addon.Mainhand:RestoreForeverGamepadPreset()
assert(not ok and why == "gamepad"
        and EditModePresetLayoutManager.presetLayoutInfo[1].systems[5].anchorInfo.offsetX == 0,
    "legacy Gamepad preset restoration did not fail closed")
currentInterfaceStyle = 1
preset.interfaceStyle = 1
assert(not addon.Mainhand:IsNativeGamepadInterface(),
    "returning to the keyboard interface must clear native gamepad detection")
ConsolePort = {}
assert(addon.Mainhand:IsControllerLayout(),
    "ConsolePort must retain ownership even when Blizzard reports a keyboard preset")
ok, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not ok and why == "gamepad",
    "Offhand must not clone a protected HUD while ConsolePort owns controller bars")
ConsolePort = nil

attention, attentionReason = addon.Mainhand:NeedsEditModeLayoutAttention()
assert(not attention and attentionReason == "forever",
    "Forever must retain its dedicated protected-HUD recovery workflow")

C_EditMode.SaveLayouts = nil
ok, why = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not ok and why == "save-api",
    "missing Edit Mode save capability must report its exact failure")

print("PASS: Mainhand anchor, public API, safe gather, layout transform, and provenance")

-- Returning from the discarded Classic artwork experiment must rebuild the
-- same generated slot from its recorded source, including native art settings.
addon.isForever = false
OffhandCharDB = {}
Enum.EditModeActionBarSetting = { HideBarArt = 9001 }
Enum.EditModeSystem.MicroMenu, Enum.EditModeSystem.Bags = 1001, 1002
local classicSource = copyTable(preset)
classicSource.systems = {
    {system=Enum.EditModeSystem.ActionBar, systemIndex=Enum.EditModeActionBarSystemIndices.MainBar,
        isInDefaultPosition=true, settings={{setting=9001,value=0}},
        anchorInfo={point='BOTTOMLEFT',relativeTo='MainMenuBarArtFrame',relativePoint='BOTTOMLEFT',offsetX=8,offsetY=4}},
    {system=1001,isInDefaultPosition=true,
        anchorInfo={point='BOTTOMLEFT',relativeTo='MainMenuBarArtFrame',relativePoint='BOTTOM',offsetX=40,offsetY=2}},
    {system=1002,isInDefaultPosition=true,
        anchorInfo={point='BOTTOMRIGHT',relativeTo='MainMenuBarArtFrame',relativePoint='BOTTOMRIGHT',offsetX=-9,offsetY=2}},
    {system=9999,isInDefaultPosition=true,
        anchorInfo={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',offsetX=0,offsetY=0}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=1,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='StatusTrackingBarManager',relativePoint='BOTTOM',offsetX=0,offsetY=0}},
}
presetLayouts={classicSource,{layoutName='Classic',layoutIndex=1,systems={}}}
layoutData={activeLayout=1,layouts={}}
C_EditMode.SaveLayouts=function(data) saved=data; layoutData=data end
ok = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok)
local generatedName=OffhandCharDB.mainhandLayout.generatedName
local damaged=saved.layouts[1].systems
damaged[1].settings[1].value=1
for index=1,3 do damaged[index].anchorInfo.relativeTo='UIParent'; damaged[index].isInDefaultPosition=false end
OffhandCharDB.mainhandLayout.classicArtwork=true
OffhandCharDB.mainhandLayout.classicEndCaps=true
OffhandCharDB.mainhandLayout.classicNativeArtwork=true
ok = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and #saved.layouts==1 and OffhandCharDB.mainhandLayout.generatedName==generatedName,
    'explicit rebuild must repair the existing generated slot, not consume a new one')
for index=1,3 do
    local entry=saved.layouts[1].systems[index]
    assert(entry.anchorInfo.relativeTo=='MainMenuBarArtFrame' and entry.isInDefaultPosition==true,
        'Beta 22 preserves native artwork-relative relationships and default-position flags')
end
assert(saved.layouts[1].systems[1].settings[1].value==0
    and classicSource.systems[1].settings[1].value==0,
    'source artwork choice must restore the generated Hide Bar Art setting without changing the source')
local classicXP=saved.layouts[1].systems[5]
assert(classicXP.anchorInfo.relativeTo=='StatusTrackingBarManager'
    and classicXP.anchorInfo.relativePoint=='BOTTOM' and classicXP.anchorInfo.offsetX==0
    and classicXP.anchorInfo.offsetY==0 and classicXP.isInDefaultPosition==true,
    'native Classic XP must retain its original manager anchor, not inherit action-bar geometry')
assert(not OffhandCharDB.mainhandLayout.classicArtwork and not OffhandCharDB.mainhandLayout.classicEndCaps
    and not OffhandCharDB.mainhandLayout.classicNativeArtwork,
    'successful explicit rebuild must discard experimental provenance')
ok = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and #saved.layouts==1 and saved.layouts[1].systems[1].settings[1].value==0)
print('PASS: Beta 22 native Classic anchors and explicit artwork-experiment recovery')

-- Retail status systems use their own containers, not the legacy manager or
-- independently docked bags. Their generated anchors must ignore stale edges.
addon.isRetail=true; addon.isForever=false
OffhandCharDB={}
metrics={gameLeft=1097,gameRight=3047,gameBottom=5,gameTop=1102,isSpanned=true}
addon.Mainhand:Update('retail-status-test')
Enum.EditModeStatusTrackingBarSystemIndices={StatusTrackingBar1=1,StatusTrackingBar2=2}
MainActionBar=frame('MainActionBar'); MainActionBar:SetSize(570,40)
MainActionBar:SetPoint('BOTTOM',UIParent,'BOTTOM',0,32)
MainActionBar.left,MainActionBar.right=-9000,9000
MainStatusTrackingBarContainer=frame('MainStatusTrackingBarContainer')
MainStatusTrackingBarContainer:SetSize(571,17); MainStatusTrackingBarContainer.scale=0.8
MainStatusTrackingBarContainer:SetPoint('BOTTOM',UIParent,'BOTTOM',5000,0)
SecondaryStatusTrackingBarContainer=frame('SecondaryStatusTrackingBarContainer')
SecondaryStatusTrackingBarContainer:SetSize(500,19); SecondaryStatusTrackingBarContainer.scale=1.1
SecondaryStatusTrackingBarContainer:SetPoint('TOPLEFT',UIParent,'BOTTOM',-9000,0)
for _,native in ipairs({MainActionBar,MainStatusTrackingBarContainer,SecondaryStatusTrackingBarContainer}) do
    native.SetPoint=function() error('Retail generation must not mutate native points') end
    native.ClearAllPoints=function() error('Retail generation must not mutate native points') end
    native.SetScale=function() error('Retail generation must not mutate native scale') end
end
StatusTrackingBarManager=frame('StatusTrackingBarManager'); StatusTrackingBarManager:SetSize(9999,900)
MainMenuBarBackpackButton=frame('MainMenuBarBackpackButton'); MainMenuBarBackpackButton.right=99999
ActionButton1=frame('ActionButton1'); ActionButton1.left=-99999
local retailSource=copyTable(preset)
retailSource.systems={
    {system=Enum.EditModeSystem.ActionBar,systemIndex=Enum.EditModeActionBarSystemIndices.MainBar,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='UIParent',relativePoint='BOTTOM',offsetX=0,offsetY=32}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=1,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='StatusTrackingBarManager',relativePoint='BOTTOM',offsetX=0,offsetY=0}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=2,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='StatusTrackingBarManager',relativePoint='BOTTOM',offsetX=0,offsetY=10}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=1,isInDefaultPosition=false,
        anchorInfo={point='LEFT',relativeTo='OtherSystem',relativePoint='RIGHT',offsetX=77,offsetY=88}},
    {system=Enum.EditModeSystem.ActionBar,systemIndex=Enum.EditModeActionBarSystemIndices.StanceBar,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='UIParent',relativePoint='BOTTOM',offsetX=0,offsetY=32}},
}
presetLayouts={retailSource,{layoutName='Classic',layoutIndex=1,systems={}}}
layoutData={activeLayout=1,layouts={}}
ok=addon.Mainhand:CreateOrUpdateEditModeLayout(); assert(ok)
local rows=saved.layouts[1].systems
local function near(a,b) assert(math.abs(a-b)<0.01,tostring(a)..' ~= '..tostring(b)) end
near(rows[2].anchorInfo.offsetX*0.8,2072)
near(rows[2].anchorInfo.offsetY*0.8,80)
near(rows[3].anchorInfo.offsetX*1.1+500*1.1/2,2072)
near(rows[3].anchorInfo.offsetY*1.1-19*1.1,80+17*0.8+4)
assert(rows[2].anchorInfo.relativeTo=='UIParent' and rows[2].anchorInfo.relativePoint=='BOTTOMLEFT'
    and rows[3].anchorInfo.point=='TOPLEFT','use each status container self point and scaled dimensions')
assert(rows[4].anchorInfo.relativeTo=='OtherSystem' and rows[4].anchorInfo.offsetX==77
    and rows[4].anchorInfo.offsetY==88,'customized source status anchors must remain untouched')
local xpX,xpY,stanceX=rows[2].anchorInfo.offsetX,rows[2].anchorInfo.offsetY,rows[5].anchorInfo.offsetX
MainActionBar.left,MainActionBar.right=123456,234567
MainMenuBarBackpackButton.right=-99999; ActionButton1.left=99999
ok=addon.Mainhand:CreateOrUpdateEditModeLayout(); assert(ok and #saved.layouts==1)
near(saved.layouts[1].systems[2].anchorInfo.offsetX,xpX)
near(saved.layouts[1].systems[2].anchorInfo.offsetY,xpY)
near(saved.layouts[1].systems[5].anchorInfo.offsetX,stanceX)
assert(retailSource.systems[2].anchorInfo.relativeTo=='StatusTrackingBarManager'
    and retailSource.systems[2].anchorInfo.offsetX==0,'source presets must not be mutated')
MainStatusTrackingBarContainer.w=4000
ok=addon.Mainhand:CreateOrUpdateEditModeLayout(); assert(ok)
assert(saved.layouts[1].systems[2].anchorInfo.relativeTo=='StatusTrackingBarManager',
    'oversized status bar must retain its source anchor rather than overflow or be shrunk')
MainStatusTrackingBarContainer.w=571
MainStatusTrackingBarContainer=nil
ok=addon.Mainhand:CreateOrUpdateEditModeLayout(); assert(ok)
assert(saved.layouts[1].systems[2].anchorInfo.relativeTo=='StatusTrackingBarManager',
    'missing Retail container must retain source relationship, not fall back to the bags')
print('PASS: Retail status centering, separate containers, scaled points, secondary stacking and stale-edge isolation')

do
    local originalMetrics = metrics
    local originalCharacter = OffhandCharDB
    local originalPresets, originalLayoutData = presetLayouts, layoutData
    local originalManager, originalAccount = EditModeManagerFrame, OffhandDB
    local originalPrimary = MainStatusTrackingBarContainer
    local originalBar2, originalBar3 = MultiBarBottomLeft, MultiBarBottomRight
    local actionIndices = Enum.EditModeActionBarSystemIndices
    local originalIndex2, originalIndex3 = actionIndices.Bar2, actionIndices.Bar3
    actionIndices.Bar2, actionIndices.Bar3 = 2, 3
    MultiBarBottomLeft = frame('MultiBarBottomLeft')
    MultiBarBottomRight = frame('MultiBarBottomRight')
    for _, bar in ipairs({MultiBarBottomLeft, MultiBarBottomRight}) do
        bar:SetSize(562, 40)
        bar.SetPoint = function() error('Retail repair must use serialized anchors') end
    end
    MainStatusTrackingBarContainer = frame('MainStatusTrackingBarContainer')
    MainStatusTrackingBarContainer:SetSize(571,17)
    MainStatusTrackingBarContainer.scale = 0.8
    MainStatusTrackingBarContainer:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, 0)
    MainStatusTrackingBarContainer.SetPoint = function() error('Retail repair must not move live status bars') end

    metrics = {gameLeft=0, gameRight=1920.094, gameBottom=515.047, gameTop=1595, isSpanned=true}
    addon.Mainhand:Update('retail-status-chain-test')
    local source = copyTable(retailSource)
    source.layoutName = 'Custom Retail status chain'
    source.systems[4].systemIndex = 99
    local main = source.systems[1]
    main.isInDefaultPosition = false
    source.systems[5].isInDefaultPosition = false
    main.anchorInfo = {point='BOTTOMLEFT', relativeTo='MainStatusTrackingBarContainer',
        relativePoint='TOPLEFT', offsetX=0, offsetY=4}
    for _, index in ipairs({actionIndices.Bar2, actionIndices.Bar3}) do
        table.insert(source.systems, {system=Enum.EditModeSystem.ActionBar, systemIndex=index,
            isInDefaultPosition=true,
            anchorInfo={point='BOTTOM', relativeTo='UIParent', relativePoint='BOTTOM', offsetX=0, offsetY=32}})
    end
    layoutData = {activeLayout=3, layouts={source}}
    OffhandCharDB = {}
    local repaired, reason = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName='MainActionBar'})
    assert(repaired, reason)
    local repairedRows = saved.layouts[2].systems
    assert(repairedRows[1].anchorInfo.relativeTo == 'MainStatusTrackingBarContainer'
        and repairedRows[1].anchorInfo.offsetY == 4, 'preserve the custom Action Bar 1 attachment')
    assert(repairedRows[2].anchorInfo.relativeTo == 'UIParent'
        and repairedRows[2].isInDefaultPosition == false, 'repair the default XP root of the chain')
    near(repairedRows[2].anchorInfo.offsetX * 0.8, metrics.gameRight / 2)
    near(repairedRows[2].anchorInfo.offsetY * 0.8, metrics.gameBottom + 8)
    near(repairedRows[3].anchorInfo.offsetX * 1.1 + 500 * 1.1 / 2, metrics.gameRight / 2)
    near(repairedRows[3].anchorInfo.offsetY * 1.1 - 19 * 1.1, metrics.gameBottom + 8 + 17 * 0.8 + 4)
    assert(repairedRows[4].anchorInfo.relativeTo == 'OtherSystem',
        'leave customized status anchors intact')
    assert(repairedRows[6].anchorInfo.relativeTo == 'MainActionBar'
        and repairedRows[6].anchorInfo.relativePoint == 'TOP' and repairedRows[6].anchorInfo.offsetY == 4
        and repairedRows[7].anchorInfo.relativeTo == 'MultiBarBottomLeft',
        'stack the default secondary rows above the recovered Action Bar 1')
    assert(saved.layouts[1].systems[2].anchorInfo.relativeTo == 'StatusTrackingBarManager',
        'leave the original account layout intact')

    -- Recreate the exact translated Beta 32 row anchors in the active Offhand
    -- layout. The upgrade uses the same no-options action as the Settings UI.
    EditModeManagerFrame = {GetRegisteredSystemFrame = function() end}
    local function SetBeta32Rows()
        OffhandDB, OffhandCharDB = {}, {}
        layoutData = {activeLayout=3, layouts={source}}
        assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
        local generatedID = layoutData.activeLayout
        local activeRows = layoutData.layouts[generatedID - #presetLayouts].systems
        for index = 6, 7 do
            local anchor = copyTable(source.systems[index].anchorInfo)
            anchor.offsetX = tonumber(("%.1f"):format((metrics.gameLeft + metrics.gameRight - UIParent:GetWidth()) / 2))
            anchor.offsetY = tonumber(("%.1f"):format(anchor.offsetY + metrics.gameBottom))
            activeRows[index].anchorInfo = anchor
        end
        return activeRows, generatedID
    end
    local beta32Rows, generatedID = SetBeta32Rows()
    local statusX, statusY = beta32Rows[2].anchorInfo.offsetX, beta32Rows[2].anchorInfo.offsetY
    beta32Rows[6].settings = {{setting=1,value=73}}
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(#layoutData.layouts == 2 and layoutData.activeLayout == generatedID,
        'upgrade must reuse the active Beta 32 layout')
    local upgraded = layoutData.layouts[generatedID - #presetLayouts].systems
    assert(upgraded[6].anchorInfo.relativeTo == 'MainActionBar'
        and upgraded[7].anchorInfo.relativeTo == 'MultiBarBottomLeft',
        'ordinary rebuild must clear both default rows in an active Beta 32 layout')
    assert(upgraded[6].settings[1].value == 73 and upgraded[2].anchorInfo.offsetX == statusX
        and upgraded[2].anchorInfo.offsetY == statusY,
        'upgrade must preserve the row settings and existing status anchor')
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(layoutData.layouts[generatedID - #presetLayouts].systems[7].anchorInfo.relativeTo == 'MultiBarBottomLeft',
        'repeating the upgrade must retain the installed chain')

    beta32Rows, generatedID = SetBeta32Rows()
    beta32Rows[7].anchorInfo.offsetY = 717
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    upgraded = layoutData.layouts[generatedID - #presetLayouts].systems
    assert(upgraded[6].anchorInfo.relativeTo == 'MainActionBar'
        and upgraded[7].anchorInfo.relativeTo == 'UIParent' and upgraded[7].anchorInfo.offsetY == 717,
        'upgrade must leave a manually moved Action Bar 3 in place')
    beta32Rows, generatedID = SetBeta32Rows()
    beta32Rows[6].anchorInfo.offsetX = -310
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    upgraded = layoutData.layouts[generatedID - #presetLayouts].systems
    assert(upgraded[6].anchorInfo.offsetX == -310 and upgraded[7].anchorInfo.relativeTo == 'UIParent',
        'upgrade must not attach Action Bar 3 to a manually moved Action Bar 2')

    beta32Rows, generatedID = SetBeta32Rows()
    MultiBarBottomRight:SetSize(562, metrics.gameTop - metrics.gameBottom)
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    upgraded = layoutData.layouts[generatedID - #presetLayouts].systems
    assert(upgraded[6].anchorInfo.relativeTo == 'MainActionBar' and upgraded[7].anchorInfo.relativeTo == 'UIParent',
        'upgrade must leave a row in place if the new stack cannot fit it')
    MultiBarBottomRight:SetSize(562, 40)
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(layoutData.layouts[generatedID - #presetLayouts].systems[7].anchorInfo.relativeTo == 'MultiBarBottomLeft',
        'a later rebuild can reuse an upgraded Action Bar 2 once Action Bar 3 fits')
    EditModeManagerFrame, OffhandDB = originalManager, originalAccount

    source.systems[6].isInDefaultPosition = false
    source.systems[6].anchorInfo.offsetY = 160
    layoutData = {activeLayout=3, layouts={source}}
    OffhandCharDB = {}
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(saved.layouts[2].systems[6].anchorInfo.offsetY == 160
        and saved.layouts[2].systems[7].anchorInfo.relativeTo == 'UIParent',
        'leave custom Action Bar 2 and its existing secondary-row placement alone')

    main.anchorInfo.relativeTo = 'OtherSystem'
    source.systems[5].isInDefaultPosition = true
    layoutData = {activeLayout=3, layouts={source}}
    OffhandCharDB = {}
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(saved.layouts[2].systems[2].anchorInfo.relativeTo == 'StatusTrackingBarManager',
        'an unrelated custom main bar must keep the status layout intact')

    metrics, OffhandCharDB = originalMetrics, originalCharacter
    presetLayouts, layoutData = originalPresets, originalLayoutData
    MainStatusTrackingBarContainer = originalPrimary
    MultiBarBottomLeft, MultiBarBottomRight = originalBar2, originalBar3
    actionIndices.Bar2, actionIndices.Bar3 = originalIndex2, originalIndex3
    addon.Mainhand:Update('restore-retail-status-test')
    print('PASS: Retail repair moves a default status chain without modifying the custom action bar')
end

do
-- Retail can expose preset layouts without the input-style Gamepad enum.
-- The existing result is false; no full layout copies are needed to decide it.
currentInterfaceStyle=1
local originalPresetManager=EditModePresetLayoutManager
local originalInputTypes=Enum.InputDeviceInterfaceType
local controllerCopies=0
EditModePresetLayoutManager={GetCopyOfPresetLayouts=function()
    controllerCopies=controllerCopies+1
    return {{interfaceStyle=originalInputTypes.Gamepad}}
end}
Enum.InputDeviceInterfaceType=nil
for _=1,450 do assert(not addon.Mainhand:IsControllerLayout()) end
Enum.InputDeviceInterfaceType={}
assert(not addon.Mainhand:IsControllerLayout())
assert(controllerCopies==0,'missing Gamepad enum must not copy unused preset trees')
ConsolePort={}
assert(addon.Mainhand:IsControllerLayout(),'ConsolePort detection must remain first')
ConsolePort=nil
Enum.InputDeviceInterfaceType=originalInputTypes
assert(addon.Mainhand:IsControllerLayout() and controllerCopies==1,
    'available enum must preserve the existing preset-copy compatibility path')
EditModePresetLayoutManager=originalPresetManager
print('PASS: missing controller enum avoids preset copies and preserves compatibility fallbacks')
end
do
-- Read-only controller detection must not deep-copy every preset/system tree.
currentInterfaceStyle=1
addon.isForever=false
local originalPresetManager=EditModePresetLayoutManager
local detectionPreset={interfaceStyle=1,systems={}}
local copies=0
EditModePresetLayoutManager={presetLayoutInfo={detectionPreset},GetCopyOfPresetLayouts=function()
    copies=copies+1
    return {{interfaceStyle=detectionPreset.interfaceStyle}}
end}
local inputTypes=Enum.InputDeviceInterfaceType
Enum.InputDeviceInterfaceType=nil
for _=1,450 do assert(not addon.Mainhand:IsControllerLayout()) end
assert(copies==0,'missing input enum must not copy presets that cannot affect the result')
Enum.InputDeviceInterfaceType={}
assert(not addon.Mainhand:IsControllerLayout() and copies==0,
    'missing Gamepad member must retain the false result without copying')
Enum.InputDeviceInterfaceType=inputTypes
for _=1,450 do assert(not addon.Mainhand:IsControllerLayout()) end
assert(copies==0,'periodic controller checks must not copy complete preset layouts')
detectionPreset.interfaceStyle=Enum.InputDeviceInterfaceType.Gamepad
assert(addon.Mainhand:IsControllerLayout(),'read-only detection must notice live preset changes immediately')
detectionPreset.interfaceStyle=1
assert(not addon.Mainhand:IsControllerLayout(),'keyboard mode must not be stuck in a cached Gamepad result')
EditModePresetLayoutManager.presetLayoutInfo=nil
detectionPreset.interfaceStyle=Enum.InputDeviceInterfaceType.Gamepad
assert(addon.Mainhand:IsControllerLayout() and copies==1,
    'clients without the preset table must retain the copy-based compatibility fallback')
addon.isForever=true
EditModePresetLayoutManager=setmetatable({GetCopyOfPresetLayouts=function()
    copies=copies+1;return {{interfaceStyle=detectionPreset.interfaceStyle}}
end},{__index=function(_,key)
    assert(key~='presetLayoutInfo','Forever must not read the native preset table')
end})
assert(addon.Mainhand:IsControllerLayout() and copies==2,
    'Forever must retain its existing compatibility path without native table access')
addon.isForever=false
EditModePresetLayoutManager=originalPresetManager
print('PASS: controller detection reads preset style without copying layouts and preserves fallback')
end

do
-- Explicit extra-action recovery must replace custom system-relative anchors
-- and preserve the other already-generated systems without translating twice.
addon.isForever, addon.isRetail = false, true
currentInterfaceStyle = 1
OffhandCharDB = {}
layoutData = {activeLayout=1, layouts={}}
EditModePresetLayoutManager.presetLayoutInfo = {copyTable(retailSource), {layoutName='Classic',systems={}}}
table.insert(EditModePresetLayoutManager.presetLayoutInfo[1].systems, {
    system=Enum.EditModeSystem.ExtraAbilities, systemIndex=1, isInDefaultPosition=true,
    anchorInfo={point='CENTER',relativeTo='UIParent',relativePoint='CENTER',offsetX=0,offsetY=0},
})
EditModePresetLayoutManager.GetCopyOfPresetLayouts = function(self) return copyTable(self.presetLayoutInfo) end
C_EditMode.SaveLayouts = function(data) saved=data; layoutData=data; saveCount=(saveCount or 0)+1 end
EditModeManagerFrame.editModeActive = false
EditModeManagerFrame.IsShown = function() return false end
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
local generatedBefore = copyTable(saved.layouts[1])
local extraIndex
for index, entry in ipairs(saved.layouts[1].systems) do
    if entry.system == Enum.EditModeSystem.ExtraAbilities then extraIndex = index end
end
assert(extraIndex, 'test source has no Extra Abilities system')
local custom = {point='LEFT',relativeTo='OtherSystem',relativePoint='RIGHT',offsetX=9000,offsetY=9000}
saved.layouts[1].systems[extraIndex].anchorInfo = copyTable(custom)
saved.layouts[1].systems[extraIndex].isInDefaultPosition = false
saved.layouts[1].systems[1].anchorInfo.offsetX = 4321
assert(addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName='ExtraAbilityContainer'}))
local repaired = saved.layouts[1].systems[extraIndex]
assert(repaired.anchorInfo.relativeTo == 'UIParent' and repaired.anchorInfo.point == 'BOTTOM'
    and repaired.anchorInfo.offsetX == (metrics.gameLeft + metrics.gameRight) / 2
    and repaired.anchorInfo.offsetY > metrics.gameBottom
    and repaired.anchorInfo.offsetY < metrics.gameTop,
    'targeted recovery did not replace the custom extra-ability relationship')
assert(saved.layouts[1].systems[1].anchorInfo.offsetX == 4321,
    'targeted extra-ability recovery overwrote another customized generated system')
for index, entry in ipairs(generatedBefore.systems) do
    if index ~= 1 and index ~= extraIndex then
        local actual = saved.layouts[1].systems[index].anchorInfo
        for key, value in pairs(entry.anchorInfo or {}) do
            assert(actual[key] == value, 'targeted repair changed an unrelated system')
        end
    end
end
local repeatWrites = saveCount
local repeatSuccess, repeatReason = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName='ExtraActionBarFrame'})
assert(not repeatSuccess and repeatReason == 'repair-system' and saveCount == repeatWrites,
    'an unchanged Extra Abilities repair must not request another reload')
assert(saved.layouts[1].systems[1].anchorInfo.offsetX == 4321, 'repeated repair drifted another system')
local selectiveRequest = {system=Enum.EditModeSystem.ExtraAbilities,
    anchorInfo={point='BOTTOM',relativeTo='UIParent',relativePoint='BOTTOMLEFT',offsetX=2000,offsetY=150}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout({repairSystems={selectiveRequest}}))
assert(saved.layouts[1].systems[1].anchorInfo.offsetX == 4321
    and saved.layouts[1].systems[extraIndex].anchorInfo.offsetX == 2000,
    'missing-only repair must copy the current layout and change just the requested system')
table.remove(saved.layouts[1].systems, extraIndex)
local writes = saveCount
local success, why = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName='ZoneAbilityFrame'})
assert(not success and why == 'repair-system' and saveCount == writes,
    'missing extra-ability system must fail without writing a layout')
print('PASS: targeted Extra Abilities recovery repairs custom anchors and preserves unrelated layout edits')
end

do
-- Shared layouts retain source provenance and frame-owner boundaries through
-- topology changes and retries, including a full native custom-layout list.
addon.isForever, addon.isRetail = false, true
GetCVar = function() return "Keyboard" end
C_CVar, ConsolePort = nil, nil
local owners = {EllesmereUIActionBars=true,EllesmereUIMinimap=true,EllesmereUIChat=true}
C_AddOns = {IsAddOnLoaded=function(name) return owners[name] == true end}
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand",addon)
OffhandCharDB, OffhandDB = {}, {}
presetLayouts = {copyTable(preset), {layoutName="Classic",layoutIndex=1,systems={}}}
EditModePresetLayoutManager = {GetCopyOfPresetLayouts=function() return copyTable(presetLayouts) end}
layoutData = {activeLayout=1,layouts={}}
local writes = 0
C_EditMode.SaveLayouts = function(data) writes=writes+1; saved=data; layoutData=data end
C_EditMode.OnLayoutAdded = function(index) layoutData.activeLayout=index end
C_EditMode.SetActiveLayout = function(index) layoutData.activeLayout=index end
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 5
local success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(success and name == "Offhand")
local ownedCount = 0
for index, entry in ipairs(presetLayouts[1].systems) do
    if addon.HUDCompatibility.IsExternallyOwnedEditModeSystem(entry) then
        ownedCount = ownedCount + 1
        local result = saved.layouts[1].systems[index]
        assert(result.isInDefaultPosition == entry.isInDefaultPosition)
        for key,value in pairs(entry.anchorInfo) do
            assert(result.anchorInfo[key] == value, "HUD generation changed an external owner's source anchor")
        end
    end
end
assert(ownedCount > 0, "fixture must contain externally owned systems")
saved.layouts[1].systems[1].anchorInfo.offsetX = 99
metrics = {gameLeft=100,gameBottom=0,gameRight=2500,gameTop=1400,isSpanned=true}
addon.Mainhand:Update("shared-geometry")
OffhandCharDB = {}
success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(success and name == "Offhand (2)" and #saved.layouts == 2
        and saved.layouts[1].systems[1].anchorInfo.offsetX == 99
        and OffhandCharDB.mainhandLayout.sourceName == presetLayouts[1].layoutName
        and OffhandCharDB.mainhandLayout.sourcePreset,
    "a fresh character on incompatible shared geometry must rebuild from the original source without overwriting it")
-- A saved row whose activation failed is still owned. Retry selects it, even
-- at capacity, without another SaveLayouts call or another generated row.
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
C_EditMode.OnLayoutAdded = function() return false end
C_EditMode.SetActiveLayout = function() return false end
success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not success and name == "activate-api" and #layoutData.layouts == 1)
local writesAfterFailure = writes
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 1
C_EditMode.SetActiveLayout = function(index) layoutData.activeLayout=index end
success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(success and name == "Offhand" and writes == writesAfterFailure
        and #layoutData.layouts == 1, "activation retry must adopt the previously saved account row at capacity")
-- A coincidentally named user row has no ownership metadata and must survive.
OffhandCharDB, OffhandDB = {}, {}
layoutData.activeLayout = 1
local protectedOffset = layoutData.layouts[1].systems[1].anchorInfo.offsetX
success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(not success and name == "maximum" and writes == writesAfterFailure
        and layoutData.layouts[1].systems[1].anchorInfo.offsetX == protectedOffset,
    "an unknown row named Offhand must not be overwritten or adopted on name alone")
print("PASS: shared HUD ownership, source provenance, geometry variants, capacity and activation retries")

-- Retail can keep reporting the old numeric active ID after inserting an
-- account layout before the active character layout.
local characterType = Enum.EditModeLayoutType.Character
Enum.EditModeLayoutType.Character = 2
local characterLayout = copyTable(presetLayouts[1])
characterLayout.layoutName, characterLayout.layoutType = "Personal HUD", 2
layoutData = {activeLayout=3, layouts={characterLayout}}
OffhandCharDB, OffhandDB = {}, {}
local appliedLayout = characterLayout.layoutName
C_EditMode.SaveLayouts = function(data)
    assert(data.activeLayout == 4 and data.layouts[2].layoutName == characterLayout.layoutName,
        "the save must preserve the active character layout's shifted index")
    layoutData = {activeLayout=3, layouts=data.layouts}
end
C_EditMode.OnLayoutAdded = function(id, activate)
    if activate then appliedLayout = layoutData.layouts[id - #presetLayouts].layoutName end
end
success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(success and name == "Offhand" and appliedLayout == name,
    "a reused active index must not skip native registration and activation of the new layout")
Enum.EditModeLayoutType.Character = characterType
print("PASS: Retail registers a new account HUD at the active character layout's former index")
end



do
-- Forever's preset offsets are automatic-stack placeholders. Generated
-- Mainhand layouts must give secondary bars real rows even with empty anchors.
addon.isForever, addon.isRetail = true, false
GetCVar = function() return "Keyboard" end
C_CVar, ConsolePort = nil, nil
currentInterfaceStyle = 1
C_AddOns = {IsAddOnLoaded=function() return false end}
Enum.EditModeActionBarSystemIndices.Bar2, Enum.EditModeActionBarSystemIndices.Bar3 = 2, 3
MainActionBar = frame("MainActionBar"); MainActionBar:SetSize(570, 40)
MainActionBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
MultiBarBottomLeft = frame("MultiBarBottomLeft"); MultiBarBottomLeft:SetSize(454, 35)
MultiBarBottomRight = frame("MultiBarBottomRight"); MultiBarBottomRight:SetSize(454, 35)
MultiBarBottomLeft.scale, MultiBarBottomRight.scale = 0.8, 1.1
MultiBarBottomLeft.shown, MultiBarBottomRight.shown = false, false
StatusTrackingBarManager = frame("StatusTrackingBarManager"); StatusTrackingBarManager:SetSize(570, 14)
for _, native in ipairs({MainActionBar, MultiBarBottomLeft, MultiBarBottomRight}) do
    native.SetPoint = function() error("layout generation must not move native action bars") end
    native.ClearAllPoints = native.SetPoint
    native.SetScale = native.SetPoint
end
local secondarySource = copyTable(preset)
secondarySource.systems = {
    {system=10, systemIndex=1, isInDefaultPosition=true,
        anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=0,offsetY=0}},
    {system=10, systemIndex=2, isInDefaultPosition=true, anchorInfo={}},
    {system=10, systemIndex=3, isInDefaultPosition=true, anchorInfo={}},
    {system=10, systemIndex=8, isInDefaultPosition=true,
        anchorInfo={point="BOTTOMLEFT",relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=0,offsetY=0}},
}
presetLayouts = {secondarySource, {layoutName="Classic",layoutIndex=1,systems={}}}
EditModePresetLayoutManager = {GetCopyOfPresetLayouts=function() return copyTable(presetLayouts) end}
Constants.EditModeConsts.EditModeMaxLayoutsPerType = 10
C_EditMode.SaveLayouts = function(data) saved=data; layoutData=data end
C_EditMode.OnLayoutAdded = function(index) layoutData.activeLayout=index end
C_EditMode.SetActiveLayout = function(index) layoutData.activeLayout=index end
for _, area in ipairs({
    {gameLeft=0,gameRight=2560,gameBottom=592,gameTop=2032,isSpanned=true},
    {gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440,isSpanned=true},
}) do
    metrics = area
    addon.Mainhand:Update("secondary-bar-rows")
    OffhandCharDB, OffhandDB = {}, {}
    layoutData = {activeLayout=1,layouts={}}
    local success = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success)
    local generated = saved.layouts[1].systems
    local row2, row3 = generated[2], generated[3]
    assert(row2.anchorInfo.relativeTo == "UIParent" and row3.anchorInfo.relativeTo == "UIParent"
            and row2.isInDefaultPosition == false and row3.isInDefaultPosition == false,
        "generated bars 2 and 3 need explicit rows outside Blizzard's automatic stack")
    local y2, y3 = row2.anchorInfo.offsetY, row3.anchorInfo.offsetY
    assert(row2.anchorInfo.relativePoint == "BOTTOMLEFT" and row2.anchorInfo.point == "BOTTOM"
            and y2 >= area.gameBottom + 40 + 8
            and y3 >= y2 + 35*0.8 + 8
            and generated[4].anchorInfo.offsetY >= y3 + 35*1.1 + 8,
        "secondary bars must clear the main bar, each other and the stance row")
    for index, scale in ipairs({0.8,1.1}) do
        local info = generated[index+1].anchorInfo
        assert(info.offsetX - 454*scale/2 >= area.gameLeft
                and info.offsetX + 454*scale/2 <= area.gameRight
                and info.offsetY + 35*scale <= area.gameTop,
            "scaled secondary bar bounds must remain inside Mainhand")
    end
    assert(next(secondarySource.systems[2].anchorInfo) == nil
            and next(secondarySource.systems[3].anchorInfo) == nil
            and not MultiBarBottomLeft:IsShown() and not MultiBarBottomRight:IsShown(),
        "generation must not mutate native presets or force hidden bars visible")
end
-- Exact Forever default relationship: main bar follows MicroMenuContainer;
-- bars 2 and 3 have zero-offset UIParent anchors overridden by the native stack.
Enum.EditModeSystem.MicroMenu = 1001
MicroMenuContainer = frame("MicroMenuContainer"); MicroMenuContainer:SetSize(200, 40)
secondarySource.systems[1].anchorInfo = {point="BOTTOMRIGHT",relativeTo="MicroMenuContainer",
    relativePoint="BOTTOMLEFT",offsetX=-4.5,offsetY=-4}
for index=2,3 do
    secondarySource.systems[index].anchorInfo = {point="BOTTOM",relativeTo="UIParent",
        relativePoint="BOTTOM",offsetX=0,offsetY=0}
end
secondarySource.systems[5] = {system=1001,isInDefaultPosition=true,
    anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=116.5,offsetY=6}}
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(saved.layouts[1].systems[2].anchorInfo.offsetY >= metrics.gameBottom + 42 + 14 + 8
        and saved.layouts[1].systems[3].anchorInfo.offsetY
            > saved.layouts[1].systems[2].anchorInfo.offsetY + 35*0.8,
    "native MicroMenu-relative main bar must also produce secondary rows above the main bar")
local firstRowX = saved.layouts[1].systems[2].anchorInfo.offsetX
local firstRowY = saved.layouts[1].systems[2].anchorInfo.offsetY
MainActionBar.left, MainActionBar.bottom = -90000, -90000
MicroMenuContainer.left, MicroMenuContainer.bottom = 90000, 90000
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(#saved.layouts == 1 and saved.layouts[1].systems[2].anchorInfo.offsetX == firstRowX
        and saved.layouts[1].systems[2].anchorInfo.offsetY == firstRowY,
    "rebuilds must use serialized relationships and must not drift with stale live anchors")
secondarySource.systems[2].anchorInfo.bottomBarOffsetX = 22
secondarySource.systems[3].anchorInfo.bottomBarOffsetX = 606
secondarySource.systems[3].anchorInfo.bottomBarExcludeFromStackIncrement = true
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
local stockRow2, stockRow3 = saved.layouts[1].systems[2].anchorInfo, saved.layouts[1].systems[3].anchorInfo
assert(stockRow2.offsetY == stockRow3.offsetY
        and math.abs((stockRow3.offsetX - 454*1.1/2) - (stockRow2.offsetX - 454*0.8/2) - (606 - 22)) < 0.01,
    "the default secondary bars must retain Blizzard's side-by-side offsets when they fit")
local wideMetrics = metrics
metrics = {gameLeft=0,gameRight=900,gameBottom=0,gameTop=1440,isSpanned=true}
addon.Mainhand:Update("narrow-secondary-bars")
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
local narrowRow2, narrowRow3 = saved.layouts[1].systems[2].anchorInfo, saved.layouts[1].systems[3].anchorInfo
assert(narrowRow3.offsetY > narrowRow2.offsetY + 35*0.8
        and narrowRow3.offsetX + 454*1.1/2 <= metrics.gameRight,
    "a narrow Mainhand must stack the secondary bar without clipping it")
metrics = wideMetrics
addon.Mainhand:Update("restore-secondary-bar-fixture")
secondarySource.systems[2].isInDefaultPosition = false
secondarySource.systems[2].anchorInfo = {point="LEFT",relativeTo="OtherSystem",
    relativePoint="RIGHT",offsetX=77,offsetY=88}
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(saved.layouts[1].systems[2].anchorInfo.relativeTo == "OtherSystem"
        and saved.layouts[1].systems[2].anchorInfo.offsetX == 77
        and saved.layouts[1].systems[2].anchorInfo.offsetY == 88,
    "default-row correction must preserve a customized source secondary bar")
C_AddOns = {IsAddOnLoaded=function(name) return name == "EllesmereUIActionBars" end}
OffhandCharDB, OffhandDB = {}, {}
layoutData = {activeLayout=1,layouts={}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
for index=1,3 do
    for key,value in pairs(secondarySource.systems[index].anchorInfo) do
        assert(saved.layouts[1].systems[index].anchorInfo[key] == value,
            "replacement action-bar owners must retain their source anchors")
    end
end
print("PASS: Forever generated secondary action-bar rows, scale, bounds and native ownership")
end

do
    addon.isForever, addon.isRetail = true, false
    Enum.EditModeLayoutType.Character, Enum.EditModeLayoutType.Override = 2, 3
    Enum.InputDeviceInterfaceType = {Gamepad = 1}
    local gamepad, eui = false, false
    addon.IsGamepadUIEnabled = function() return gamepad end
    C_AddOns = {IsAddOnLoaded = function(name) return eui and name == "EllesmereUIActionBars" end}
    ConsolePort, EditModeManagerFrame = nil, nil
    UnitName = function() return "Tester" end
    UnitGUID = function() return "Player-test-1" end
    metrics = {gameLeft=1440, gameBottom=0, gameRight=4000, gameTop=1440, isSpanned=true}
    addon.Mainhand:Update("character-layout")
    local geometry = addon.Mainhand:GetGeometrySignature()
    local gamepadPreset = copyTable(preset)
    gamepadPreset.layoutName, gamepadPreset.interfaceStyle = "Gamepad", 1
    presetLayouts = {copyTable(preset), {layoutName="Classic", systems={}}, gamepadPreset}
    presetLayouts[1].interfaceStyle = 0
    local legacy = copyTable(preset)
    legacy.layoutType, legacy.layoutName = 1, "Offhand (3)"
    legacy.systems[1].anchorInfo.offsetX = 71
    local accountRows = {}
    for i = 1, 4 do accountRows[i] = {layoutType=1, layoutName="Account " .. i, systems={}} end
    accountRows[5] = legacy
    layoutData = {activeLayout=8, layouts=copyTable(accountRows)}
    OffhandDB = {sharedMainhandLayouts = {["Offhand (3)"] = {
        version=1, client="forever", geometrySignature=geometry, ownershipSignature="",
        sourceName=preset.layoutName, sourceID=1, sourcePreset=true, movedSystems=9,
    }}}
    OffhandCharDB = {mainhandLayout = {
        version=1, generatedName="Offhand (3)", generatedID=8, geometrySignature=geometry,
        sourceName=preset.layoutName, sourceID=1, sourcePreset=true, movedSystems=9,
        ownerName="Tester", ownerGUID="Player-test-1",
    }}
    local writes, additions = 0, 0
    C_EditMode.SaveLayouts = function(data) writes=writes+1; layoutData=data end
    C_EditMode.OnLayoutAdded = function(id, activate)
        additions = additions + 1
        if activate then layoutData.activeLayout = id end
    end
    C_EditMode.SetActiveLayout = function(id) layoutData.activeLayout=id end
    Constants.EditModeConsts.EditModeMaxLayoutsPerType = 5

    local legacyContext = addon.Mainhand:GetEllesmereLayoutSource()
    assert(legacyContext.generatedActive and legacyContext.characterOwned == false,
        "a shared layout remains available for preview, but must not skip character HUD creation")
    local registry = OffhandDB.sharedMainhandLayouts["Offhand (3)"]
    local character = OffhandCharDB
    registry.ownershipSignature, OffhandCharDB = "old-owner", {}
    assert(not addon.Mainhand:GetEllesmereLayoutSource().generated,
        "the shared preview fallback must reject a mismatched ownership signature")
    registry.ownershipSignature, OffhandCharDB = "", character
    local success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Main - Tester" and #layoutData.layouts == 6 and additions == 1
        and layoutData.layouts[6].layoutType == 2 and layoutData.activeLayout == 9,
        "a full account quota must still permit a native character layout: " .. tostring(name))
    assert(layoutData.layouts[5].layoutType == 1 and layoutData.layouts[5].layoutName == "Offhand (3)"
        and layoutData.layouts[5].systems[1].anchorInfo.offsetX == 71
        and layoutData.layouts[6].systems[1].anchorInfo.offsetX == 71,
        "compatible legacy placements must copy into the character layout and leave the shared layout intact")

    eui = true
    layoutData.activeLayout = 1
    assert(not addon.Mainhand:GetEllesmereLayoutSource().generated,
        "the EllesmereUI review must require the saved character layout to be active")
    layoutData.activeLayout = 9
    local review = addon.Mainhand:GetEllesmereLayoutSource()
    local reviewStatus = addon.Mainhand:GetCharacterSetupLayoutStatus()
    assert(review.generatedActive and review.characterOwned and review.ellesmereReview
        and reviewStatus.ellesmereReview and not reviewStatus.ready,
        "enabling EllesmereUI alone should offer review of the active character layout")
    local accepted, refusal = addon.Mainhand:UseExistingEditModeLayout()
    assert(not accepted and refusal == "review", "review should be explicit")
    local confirmed, confirmedName, _, selectionChanged =
        addon.Mainhand:UseExistingEditModeLayout("Offhand Main - Tester")
    assert(confirmed and confirmedName == "Offhand Main - Tester" and not selectionChanged
        and addon.Mainhand:GetLayoutStatus().currentOwnership and writes == 1,
        "finishing review should record ownership without rewriting or activating Blizzard's layout")
    local nativeStatus = false
    _G.EllesmereUI = {Lite = {GetAddon = function()
        return {db = {profile = {useBlizzardDataBars = nativeStatus}}}
    end}}
    assert(addon.Mainhand:GetLayoutStatus().currentOwnership)
    nativeStatus = true
    assert(not addon.Mainhand:GetLayoutStatus().currentOwnership
        and not addon.Mainhand:GetEllesmereLayoutSource().generated
        and addon.Mainhand:GetCharacterSetupLayoutStatus().reason == "ownership",
        "switching to Blizzard XP/Rep must invalidate a layout even with the same loaded addons")
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Main - Tester" and #layoutData.layouts == 6 and writes == 2,
        "a native HUD ownership change must refresh the same character slot")
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and writes == 2 and additions == 1, "an unchanged repeat must not write or add another row")

    gamepad = true
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Pad - Tester" and #layoutData.layouts == 7
        and layoutData.layouts[7].layoutType == 2 and layoutData.activeLayout == 10,
        "Gamepad uses its own character layout")
    gamepad = false
    Constants.EditModeConsts.EditModeMaxLayoutsPerType = 2
    local standardStatus = addon.Mainhand:GetCharacterSetupLayoutStatus()
    assert(standardStatus.available and not standardStatus.ready and standardStatus.name == "Offhand Main - Tester",
        "reuse must discover the current mode's saved layout after the other mode was used")
    assert(not addon.Mainhand:UseExistingEditModeLayout("Offhand Pad - Tester") and layoutData.activeLayout == 10,
        "a caller expecting a specific layout must never select a different candidate")
    local reused, reusedName, _, changed = addon.Mainhand:UseExistingEditModeLayout("Offhand Main - Tester")
    assert(reused and changed and reusedName == standardStatus.name and layoutData.activeLayout == 9
        and OffhandCharDB.mainhandLayout == OffhandCharDB.mainhandLayoutsByMode.standard,
        "reusing the Standard row must restore its native selection and record")
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Main - Tester" and #layoutData.layouts == 7
        and layoutData.activeLayout == 9 and writes == 3 and additions == 2,
        "switching input mode must recover the existing slot even at character capacity")
    _G.EllesmereUI = nil

    local otherCharacter = {activeLayout=1, layouts=copyTable(accountRows)}
    layoutData, OffhandCharDB = otherCharacter, {}
    UnitName = function() return "Other" end
    UnitGUID = function() return "Player-test-2" end
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Main - Other" and #layoutData.layouts == 6
        and not addon.Mainhand:IsCharacterEditModeLayoutAllowed("Offhand Main - Tester"),
        "a different character must receive its own row without adopting the first character's layout")

    local pending
    layoutData, OffhandCharDB = {activeLayout=1, layouts=copyTable(accountRows)}, {}
    C_EditMode.SaveLayouts = function(data) pending = data end
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(not success and name == "save" and pending and not OffhandCharDB.mainhandLayout,
        "a deferred native save must not claim an active character layout")
    layoutData, pending = pending, nil
    success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(success and name == "Offhand Main - Other" and #layoutData.layouts == 6 and not pending,
        "retry must adopt the late native row without appending or saving again")

    for _, retail in ipairs({true, false}) do
        addon.isForever, addon.isRetail = false, retail
        OffhandDB, OffhandCharDB = {}, {}
        layoutData = {activeLayout = #presetLayouts + 5, layouts = copyTable(accountRows)}
        layoutData.layouts[5] = copyTable(preset)
        layoutData.layouts[5].layoutName, layoutData.layouts[5].layoutType = "Personal", 2
        Constants.EditModeConsts.EditModeMaxLayoutsPerType = 5
        local selectedBeforeActivation
        C_EditMode.SaveLayouts = function(data) layoutData=data end
        C_EditMode.OnLayoutAdded = function(id)
            selectedBeforeActivation = layoutData.layouts[layoutData.activeLayout - #presetLayouts].layoutName
            layoutData.activeLayout = id
        end
        success, name = addon.Mainhand:CreateOrUpdateEditModeLayout()
        assert(success and name == "Offhand" and layoutData.layouts[5].layoutType == 1
            and layoutData.layouts[6].layoutName == "Personal" and selectedBeforeActivation == "Personal",
            "Retail and Classic must count only account layouts and keep the existing native selection during insertion")
        OffhandDB, OffhandCharDB = {}, {}
        layoutData.activeLayout = 1
        local full, reason = addon.Mainhand:CreateOrUpdateEditModeLayout()
        assert(not full and reason == "maximum", "five account layouts must still exhaust the account quota")
    end
    print("PASS: Forever character layout scope, legacy migration, capacity, owner changes and input-mode reuse")
end

do
-- A repaired EncounterBar must stop retaining a custom system-relative anchor.
-- Exercise both native layout scopes and repeat the transaction after reload.
for _, forever in ipairs({false, true}) do
    addon.isForever, addon.isRetail = forever, not forever
    currentInterfaceStyle = 1
    Enum.InputDeviceInterfaceType = {Gamepad=2}
    addon.IsGamepadUIEnabled = function() return false end
    C_AddOns = {IsAddOnLoaded=function() return false end}
    OffhandDB, OffhandCharDB = {}, {}
    Constants.EditModeConsts.EditModeMaxLayoutsPerType = 10
    local encounter = Enum.EditModeSystem.EncounterBar
    local original = {
        layoutName = 'Personal encounter test', layoutType = Enum.EditModeLayoutType.Account,
        systems = {
            {system=9876, systemIndex=1, isInDefaultPosition=false,
             anchorInfo={point='LEFT',relativeTo='OtherSystem',relativePoint='RIGHT',offsetX=123,offsetY=456},
             settings={{setting=1,value=42}}},
            {system=encounter, systemIndex=1, isInDefaultPosition=false,
             anchorInfo={point='TOP',relativeTo='LossOfControlFrame',relativePoint='BOTTOM',offsetX=-9000,offsetY=9000},
             anchorInfo2={point='BOTTOM',relativeTo='OtherSystem',relativePoint='TOP',offsetX=9000,offsetY=-9000},
             settings={{setting=2,value=17}}},
        },
    }
    presetLayouts = {copyTable(preset), {layoutName='Classic',systems={}}, {layoutName='Gamepad',interfaceStyle=2,systems={}}}
    EditModePresetLayoutManager.GetCopyOfPresetLayouts = function() return copyTable(presetLayouts) end
    layoutData = {activeLayout=4,layouts={copyTable(original)}}
    C_EditMode.GetLayouts = function() return copyTable(layoutData) end
    C_EditMode.SaveLayouts = function(data) saved=data; layoutData=data; saveCount=saveCount+1 end
    C_EditMode.OnLayoutAdded = function(id) layoutData.activeLayout=id end
    C_EditMode.SetActiveLayout = function(id) layoutData.activeLayout=id end
    EditModeManagerFrame = {IsShown=function() return false end, editModeActive=false}
    EncounterBar.scale = 0.5
    local oldClear, oldPoint = EncounterBar.ClearAllPoints, EncounterBar.SetPoint
    EncounterBar.ClearAllPoints = function() error('repair must only change serialized layout data') end
    EncounterBar.SetPoint = EncounterBar.ClearAllPoints
    for _, name in ipairs({'EncounterBar','UIWidgetPowerBarContainerFrame'}) do
        local success, why = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName=name})
        assert(success, tostring(why))
        local index = layoutData.activeLayout - 3
        local rows = layoutData.layouts[index].systems
        assert(rows[2].anchorInfo.relativeTo == 'UIParent',
            'EncounterBar repair retained the unreachable system-relative anchor')
        -- Model native ApplySystemAnchor's division before frame-local SetPoint.
        local appliedX, appliedY = rows[2].anchorInfo.offsetX/0.5, rows[2].anchorInfo.offsetY/0.5
        near(appliedX * 0.5, (metrics.gameLeft + metrics.gameRight)/2)
        near(appliedY * 0.5, metrics.gameBottom + (metrics.gameTop-metrics.gameBottom)*0.6)
        assert(rows[1].anchorInfo.offsetX == 123 and rows[1].settings[1].value == 42
            and rows[2].settings[1].value == 17 and rows[2].isInDefaultPosition == false
            and rows[2].anchorInfo2 == nil,
            'EncounterBar repair changed unrelated layout edits or target settings')
        assert(layoutData.layouts[1].systems[2].anchorInfo.relativeTo == 'LossOfControlFrame',
            'repair overwrote the source personal layout')
        -- The next call sees the saved native row, as it would after reload.
        layoutData = copyTable(layoutData)
        local writes = saveCount
        success, why = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName=name})
        assert(not success and why == 'repair-system' and saveCount == writes,
            'an unchanged EncounterBar repair must not save or report that a reload is needed')
        if name == 'EncounterBar' then
            layoutData.layouts[index].systems[2] = copyTable(original.systems[2])
        end
    end
    local active = layoutData.layouts[layoutData.activeLayout-3]
    table.remove(active.systems, 2)
    local writes = saveCount
    local success, why = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName='EncounterBar'})
    assert(not success and why == 'repair-system' and saveCount == writes,
        'missing EncounterBar must fail without reporting a successful repair')
    EncounterBar.ClearAllPoints, EncounterBar.SetPoint = oldClear, oldPoint
    EncounterBar.scale = 1
end
print('PASS: EncounterBar targeted repair, alias, scale, reload retry and missing-system failure')
end

do
-- Source-derived test inputs. This executes Offhand only, never upstream Lua.
addon.isForever, addon.isRetail = true, false
ConsolePort, C_CVar, EllesmereUI = nil, nil, nil
C_AddOns = {IsAddOnLoaded = function() return false end}
GetCVar = function() return "Keyboard" end
currentInterfaceStyle = 0
Enum.InputDeviceInterfaceType = {Gamepad=1}
UnitName = function() return "GeometryProbe" end
UnitGUID = function() return "Player-geometry-probe" end
local action = Enum.EditModeSystem.ActionBar
local indices = Enum.EditModeActionBarSystemIndices
indices.MainBar, indices.RightBar1, indices.RightBar2 = 1,4,5
local menu = Enum.EditModeSystem.MicroMenu or 1001
Enum.EditModeSystem.MicroMenu = menu
local function row(kind, index, default, point, relative, relativePoint, x, y)
 return {system=kind,systemIndex=index,isInDefaultPosition=default,anchorInfo={
  point=point,relativeTo=relative,relativePoint=relativePoint,offsetX=x,offsetY=y}}
end
local source = {layoutName="Modern",layoutIndex=0,interfaceStyle=0,systems={
 row(action,1,true,"BOTTOMRIGHT","MicroMenuContainer","BOTTOMLEFT",-4.5,-4),
 row(menu,nil,true,"BOTTOM","UIParent","BOTTOM",116.5,6),
 row(action,4,true,"RIGHT","UIParent","RIGHT",-5,-77),
 row(action,5,true,"RIGHT","UIParent","RIGHT",-5,-77),
 row(9000,nil,false,"BOTTOMLEFT","UIParent","BOTTOMLEFT",100,100),
 row(9001,nil,true,"TOPLEFT","UIParent","TOPLEFT",24,-100),
}}
source.systems[6].anchorInfo2={point="BOTTOMRIGHT",relativeTo="UIParent",relativePoint="BOTTOMRIGHT",offsetX=-24,offsetY=100}
presetLayouts={source,{layoutName="Classic",systems={}},{layoutName="Gamepad",interfaceStyle=1,systems={}}}
EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return copyTable(presetLayouts) end}
MainActionBar=frame("MainActionBar");MainActionBar:SetSize(570,40)
MainActionBar:SetPoint("BOTTOMRIGHT",UIParent,"BOTTOM",-4.5,-4)
MicroMenuContainer=frame("MicroMenuContainer");MicroMenuContainer:SetSize(200,40)
MultiBarRight=frame("MultiBarRight");MultiBarRight:SetSize(40,480)
MultiBarLeft=frame("MultiBarLeft");MultiBarLeft:SetSize(40,480)
RIGHT_ACTION_BAR_DEFAULT_OFFSET_X, RIGHT_ACTION_BAR_DEFAULT_OFFSET_Y, RIGHT_ACTION_BAR_DEFAULT_PADDING_X = -5, -77, 0
C_EditMode.SaveLayouts=function(data) layoutData=copyTable(data) end
C_EditMode.OnLayoutAdded=function(id) layoutData.activeLayout=id end
C_EditMode.SetActiveLayout=function(id) layoutData.activeLayout=id end
Constants.EditModeConsts.EditModeMaxLayoutsPerType=10
local cases={
 {name="split-right-50-50",sw=3142.8571,sh=1767.8571,l=1571.42855,b=0,r=3142.8571,t=1767.8571},
 {name="split-left-50-50",sw=3142.8571,sh=1767.8571,l=0,b=0,r=1571.42855,t=1767.8571},
 {name="dual-right",sw=3840,sh=1080,l=1920,b=0,r=3840,t=1080},
 {name="dual-left",sw=3840,sh=1080,l=0,b=0,r=1920,t=1080},
 {name="portrait-left",sw=4000,sh=2560,l=1440,b=0,r=4000,t=1440},
 {name="portrait-4k-bottom-offset",sw=5280,sh=2560,l=1440,b=400,r=5280,t=2560},
 {name="stacked-top",sw=1920,sh=2160,l=0,b=1080,r=1920,t=2160},
 {name="stacked-bottom",sw=1920,sh=2160,l=0,b=0,r=1920,t=1080},
}
for _,eui in ipairs({false,true}) do
 C_AddOns.IsAddOnLoaded=function(name)
  return eui and (name=="EllesmereUIActionBars" or name=="EllesmereUIUnitFrames")
 end
 if eui then
  local function element(width, scale)
   local f=frame();f.scale=scale;f.GetRect=function() return 100,100,width,480 end
   return {getFrame=function() return f end}
  end
  EllesmereUI={IsUnlockAnchored=function() return false end,
   GetActiveProfileData=function() return {} end,
   _unlockRegisteredElements={Bar4=element(60,.8),Bar5=element(40,1.1)}}
  assert(loadfile("Core/ForeverEllesmereLayout.lua"))("Offhand",addon)
 end
 for _,barScale in ipairs({.65,1,1.25}) do
 MultiBarRight.scale,MultiBarLeft.scale=barScale,barScale*.9
 for _,case in ipairs(cases) do
  UIParent.GetWidth=function() return case.sw end
  UIParent.GetHeight=function() return case.sh end
  metrics={gameLeft=case.l,gameBottom=case.b,gameRight=case.r,gameTop=case.t,isSpanned=true}
  if case.b>0 then
   metrics.workspaceLeft,metrics.workspaceBottom,metrics.workspaceRight,metrics.workspaceTop=0,0,case.sw,case.b
  elseif case.t<case.sh then
   metrics.workspaceLeft,metrics.workspaceBottom,metrics.workspaceRight,metrics.workspaceTop=0,case.t,case.sw,case.sh
  elseif case.l>0 then
   metrics.workspaceLeft,metrics.workspaceBottom,metrics.workspaceRight,metrics.workspaceTop=0,0,case.l,case.sh
  else
   metrics.workspaceLeft,metrics.workspaceBottom,metrics.workspaceRight,metrics.workspaceTop=case.r,0,case.sw,case.sh
  end
  addon.Mainhand:Update("geometry-matrix")
  OffhandDB,OffhandCharDB={},{}
  layoutData={activeLayout=1,layouts={}}
  local ok,name=addon.Mainhand:CreateOrUpdateEditModeLayout()
  assert(ok,tostring(name))
  local generated=layoutData.layouts[layoutData.activeLayout-3]
  local a,b,c=generated.systems[3].anchorInfo,generated.systems[4].anchorInfo,generated.systems[5].anchorInfo
  local overlap=a.point==b.point and a.relativeTo==b.relativeTo and a.relativePoint==b.relativePoint
   and a.offsetX==b.offsetX and a.offsetY==b.offsetY
  if eui then
   local rows=addon.EllesmereLayout:Preview("ellesmere")
   local a,b=rows[6].proposed,rows[7].proposed
   assert(a and b and b.left+b.width<=a.left-4.99,
    case.name..": replacement right bars must have separate columns at their actual scales")
   for _,bounds in ipairs({a,b}) do
    assert(bounds.left>=case.l and bounds.left+bounds.width<=case.r
     and bounds.bottom>=case.b and bounds.bottom+bounds.height<=case.t,
     case.name..": replacement bar bounds escaped Mainhand")
   end
  end
  local second=generated.systems[6].anchorInfo2
  local secondMismatch=math.abs(second.offsetX-(-24+case.r-case.sw))>.01
   or math.abs(second.offsetY-(100+case.b))>.01
  assert(not secondMismatch,case.name..": generation transformed only one anchor of a stretched frame")
  assert(c.offsetX==100 and c.offsetY==100,case.name..": generation moved a customized source entry")
  if not eui then
   assert(not overlap,case.name..": native right bars still overlap")
   local width=40*MultiBarRight.scale
   assert(math.abs(a.offsetX - (case.r - 5)) < 0.01 and math.abs(a.offsetY - ((case.b + case.t)/2 - 77)) < 0.01
    and b.offsetX<=a.offsetX-width-4.99,case.name..": native right columns must keep their stock spacing")
  else
   assert(generated.systems[3].isInDefaultPosition and generated.systems[4].isInDefaultPosition,
    "generation must preserve external native ownership while the transfer uses a projected copy")
  end
  assert(source.systems[3].isInDefaultPosition and source.systems[3].anchorInfo.offsetX==-5
   and source.systems[6].anchorInfo2.offsetX==-24,"generation or preview mutated the source preset")
 end
 end
end
RIGHT_ACTION_BAR_DEFAULT_OFFSET_X, RIGHT_ACTION_BAR_DEFAULT_OFFSET_Y, RIGHT_ACTION_BAR_DEFAULT_PADDING_X = nil, nil, nil
print("PASS: native generation and EllesmereUI projection across eight topologies and three bar scales")
end

do
-- Forever uses separate Edit Mode containers. A stale live TOP anchor on the
-- main bar and the legacy manager must not lower XP into the action buttons.
addon.isForever, addon.isRetail = true, false
GetCVar = function() return "Keyboard" end
ConsolePort,C_CVar,EditModeManagerFrame = nil,nil,nil
currentInterfaceStyle = 0
UnitName = function() return "StatusProbe" end
UnitGUID = function() return "Player-status-probe" end
local action,status,menu = Enum.EditModeSystem.ActionBar,Enum.EditModeSystem.StatusTrackingBar,Enum.EditModeSystem.MicroMenu
local barIndices = Enum.EditModeActionBarSystemIndices
barIndices.MainBar,barIndices.Bar2,barIndices.Bar3=1,2,3
Enum.EditModeStatusTrackingBarSystemIndices={StatusTrackingBar1=1,StatusTrackingBar2=2}
MainActionBar=frame("MainActionBar");MainActionBar:SetSize(570,40);MainActionBar.scale=.85
MainActionBar:SetPoint("TOPLEFT",UIParent,"TOPLEFT",-90000,90000)
MicroMenuContainer=frame("MicroMenuContainer");MicroMenuContainer:SetSize(200,40);MicroMenuContainer.scale=1.2
MainStatusTrackingBarContainer=frame("MainStatusTrackingBarContainer")
MainStatusTrackingBarContainer:SetSize(900,14);MainStatusTrackingBarContainer.scale=.8
MainStatusTrackingBarContainer:SetPoint("TOPLEFT",UIParent,"TOPLEFT",90000,-90000)
SecondaryStatusTrackingBarContainer=frame("SecondaryStatusTrackingBarContainer")
SecondaryStatusTrackingBarContainer:SetSize(800,16);SecondaryStatusTrackingBarContainer.scale=1.1
SecondaryStatusTrackingBarContainer:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-90000,90000)
StatusTrackingBarManager=frame("StatusTrackingBarManager");StatusTrackingBarManager:SetSize(9000,900)
MultiBarBottomLeft=frame("MultiBarBottomLeft");MultiBarBottomLeft:SetSize(450,35);MultiBarBottomLeft.scale=1
MultiBarBottomRight=frame("MultiBarBottomRight");MultiBarBottomRight:SetSize(450,35);MultiBarBottomRight.scale=1
for _,native in ipairs({MainActionBar,MainStatusTrackingBarContainer,SecondaryStatusTrackingBarContainer}) do
 native.SetPoint=function() error("generation moved a protected native status/action frame") end
 native.ClearAllPoints=native.SetPoint
 native.SetScale=native.SetPoint
end
local source={layoutName="Modern",layoutIndex=0,interfaceStyle=0,systems={
 {system=action,systemIndex=1,isInDefaultPosition=true,anchorInfo={point="BOTTOMRIGHT",relativeTo="MicroMenuContainer",relativePoint="BOTTOMLEFT",offsetX=-4.5,offsetY=-4}},
 {system=menu,isInDefaultPosition=true,anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=116.5,offsetY=6}},
 {system=status,systemIndex=1,isInDefaultPosition=true,anchorInfo={point="BOTTOM",relativeTo="StatusTrackingBarManager",relativePoint="BOTTOM",offsetX=0,offsetY=0}},
 {system=status,systemIndex=2,isInDefaultPosition=true,anchorInfo={point="BOTTOM",relativeTo="StatusTrackingBarManager",relativePoint="BOTTOM",offsetX=0,offsetY=0}},
 {system=action,systemIndex=2,isInDefaultPosition=true,anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=0,offsetY=0}},
 {system=action,systemIndex=3,isInDefaultPosition=true,anchorInfo={point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOM",offsetX=0,offsetY=0}},
}}
presetLayouts={source,{layoutName="Classic",systems={}},{layoutName="Gamepad",interfaceStyle=1,systems={}}}
EditModePresetLayoutManager={GetCopyOfPresetLayouts=function() return copyTable(presetLayouts) end}
C_EditMode.SaveLayouts=function(data) layoutData=copyTable(data) end
C_EditMode.OnLayoutAdded=function(id) layoutData.activeLayout=id end
C_EditMode.SetActiveLayout=function(id) layoutData.activeLayout=id end
Constants.EditModeConsts.EditModeMaxLayoutsPerType=10
local function Near(a,b) assert(math.abs(a-b)<.01,tostring(a).." ~= "..tostring(b)) end
local function ForeverActionCenter(rows, parentWidth)
 local main, micro = rows[1].anchorInfo, rows[2].anchorInfo
 local microLeft = (micro.relativePoint=="BOTTOM" and parentWidth/2 or 0) + micro.offsetX
 if micro.point=="BOTTOM" then microLeft=microLeft-200*1.2/2 end
 return microLeft+main.offsetX-570*.85/2
end
for _,eui in ipairs({false,true}) do
 C_AddOns={IsAddOnLoaded=function(name) return eui and name=="EllesmereUIActionBars" end}
 EllesmereUI=eui and {Lite={GetAddon=function() return {db={profile={useBlizzardDataBars=true}}} end}} or nil
 for _,area in ipairs({
  {w=3142.8571,h=1767.8571,l=1571.42855,b=0,r=3142.8571,t=1767.8571},
  {w=4000,h=2560,l=1440,b=0,r=4000,t=1440},
  {w=1920,h=2160,l=0,b=1080,r=1920,t=2160},
 }) do
  UIParent.GetWidth=function() return area.w end;UIParent.GetHeight=function() return area.h end
  metrics={gameLeft=area.l,gameBottom=area.b,gameRight=area.r,gameTop=area.t,isSpanned=true}
  addon.Mainhand:Update("forever-xp")
  OffhandDB,OffhandCharDB={},{}
  layoutData={activeLayout=1,layouts={}}
  assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
  local rows=layoutData.layouts[layoutData.activeLayout-3].systems
  local xp,rep=rows[3].anchorInfo,rows[4].anchorInfo
  assert(xp.point=="BOTTOM")
  Near(rep.offsetY,xp.offsetY+14*.8+4)
  if not eui then
   assert(xp.relativeTo=="MainActionBar" and xp.relativePoint=="TOP")
   local center = ForeverActionCenter(rows, area.w)
   Near(center+xp.offsetX,(area.l+area.r)/2)
   Near(center+rep.offsetX,(area.l+area.r)/2)
   Near(xp.offsetY,3)
   assert(rep.relativeTo=="MainActionBar" and rep.relativePoint=="TOP"
    and rows[5].anchorInfo.relativeTo=="MainActionBar" and rows[5].anchorInfo.offsetY>=rep.offsetY+16*1.1+8,
    "the secondary action row must clear both native status bars")
  else
   assert(xp.relativeTo=="UIParent" and xp.relativePoint=="BOTTOMLEFT")
   Near(xp.offsetX,(area.l+area.r)/2)
   Near(xp.offsetY,area.b+6-4+40*.85+3)
   assert(rows[1].isInDefaultPosition and rows[5].isInDefaultPosition,
    "native status placement must yield movement of replacement-owned action bars")
  end
  source.systems[4].isInDefaultPosition=false
  source.systems[4].anchorInfo={point="BOTTOMLEFT",relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=123,offsetY=111}
  assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
  rows=layoutData.layouts[layoutData.activeLayout-3].systems
  assert(rows[4].anchorInfo.offsetX==123 and rows[4].anchorInfo.offsetY==111,
   "generation must preserve an explicitly customized reputation bar")
  source.systems[4].isInDefaultPosition=true
  source.systems[4].anchorInfo={point="BOTTOM",relativeTo="StatusTrackingBarManager",relativePoint="BOTTOM",offsetX=0,offsetY=0}
 end
end
-- The old generator saved a centered XP anchor before the menu/main-bar
-- group was fitted. Model the reported saved layout and refresh its same slot.
C_AddOns, EllesmereUI = nil, nil
local registered = {
 [action] = {[1] = MainActionBar, [2] = MultiBarBottomLeft, [3] = MultiBarBottomRight},
 [status] = {[1] = MainStatusTrackingBarContainer, [2] = SecondaryStatusTrackingBarContainer},
 [menu] = {[0] = MicroMenuContainer},
}
EditModeManagerFrame = {GetRegisteredSystemFrame = function(_, system, index)
 return registered[system] and registered[system][index or 0]
end}
UIParent.GetWidth = function() return 3047.6 end
UIParent.GetHeight = function() return 1950.5 end
metrics = {gameLeft=1097.1,gameRight=3047.6,gameBottom=4.6,gameTop=1101.7,isSpanned=true}
addon.Mainhand:Update("forever-xp-existing")
OffhandDB,OffhandCharDB={},{}
layoutData={activeLayout=1,layouts={}}
source.systems[2].anchorInfo.offsetY = -8
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
local existingID = layoutData.activeLayout
local existing = layoutData.layouts[existingID-3].systems
assert(existing[2].anchorInfo.offsetY > metrics.gameBottom - 8
 and existing[3].anchorInfo.relativeTo=="MainActionBar" and existing[3].anchorInfo.offsetY==3,
 "fitting the Micro Menu and main bar must carry the generated XP bar with them")
local legacyCenter = (metrics.gameLeft + metrics.gameRight) / 2
Near(ForeverActionCenter(existing, UIParent:GetWidth())+existing[3].anchorInfo.offsetX,legacyCenter)
Near(ForeverActionCenter(existing, UIParent:GetWidth())+existing[4].anchorInfo.offsetX,legacyCenter)
source.systems[2].anchorInfo.offsetY = 6
existing[2].anchorInfo = {point="BOTTOMLEFT",relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=2500,offsetY=149.6}
local legacyXPBottom = metrics.gameBottom + 6 - 4 + 40 * .85 + 3
existing[3].anchorInfo = {point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=legacyCenter,offsetY=20}
existing[4].anchorInfo = {point="BOTTOM",relativeTo="UIParent",relativePoint="BOTTOMLEFT",offsetX=2200,offsetY=75.6}
existing[5].settings = {{setting=1,value=73}}
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
existing = layoutData.layouts[existingID-3].systems
assert(existing[3].anchorInfo.relativeTo=="UIParent" and existing[3].anchorInfo.offsetY==20,
 "refresh must preserve a centered, disjoint manual XP anchor")

existing[3].anchorInfo.offsetY = legacyXPBottom
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
existing = layoutData.layouts[existingID-3].systems
assert(existing[3].anchorInfo.relativeTo=="UIParent" and existing[3].anchorInfo.offsetY==legacyXPBottom,
 "an exact Beta 32 anchor that clears the main bar needs no migration")

existing[2].anchorInfo.offsetY = 47
existing[3].anchorInfo.offsetY = legacyXPBottom + 2
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
existing = layoutData.layouts[existingID-3].systems
assert(existing[3].anchorInfo.relativeTo=="UIParent" and existing[3].anchorInfo.offsetY==legacyXPBottom+2,
 "overlap alone must not replace a manually moved XP anchor")

existing[3].anchorInfo.offsetX = tonumber(("%.1f"):format(legacyCenter))
existing[3].anchorInfo.offsetY = tonumber(("%.1f"):format(legacyXPBottom))
assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
assert(#layoutData.layouts==1 and layoutData.activeLayout==existingID,
 "repair must reuse the generated slot")
local repaired = layoutData.layouts[existingID-3].systems
assert(repaired[3].anchorInfo.relativeTo=="MainActionBar" and repaired[3].anchorInfo.relativePoint=="TOP"
 and repaired[3].anchorInfo.offsetY==3, "refresh must correct the exact overlapping Beta 32 XP anchor")
Near(ForeverActionCenter(repaired, UIParent:GetWidth())+repaired[3].anchorInfo.offsetX,legacyCenter)
assert(repaired[4].anchorInfo.relativeTo=="UIParent" and repaired[4].anchorInfo.offsetX==2200
 and repaired[5].settings[1].value==73, "refresh must retain custom status and action bar settings")
EditModeManagerFrame = nil
print("PASS: Forever XP/Rep containers, saved self points, scale, secondary clearance, custom positions and EUI ownership")
end

-- Production create/rebuild transaction: fit a copy, retain generated edits,
-- honour a deliberate new source, and preserve the replaced generated payload.
do
    addon.isForever, addon.isRetail = true, false
    addon.db.enabled = true
    addon.IsGamepadUIEnabled = function() return false end
    InputUtil = {IsGamepadUIEnabled = function() return false end}
    C_InputInterfaceStyle, ConsolePort, EllesmereUI = nil, nil, nil
    UnitName, UnitGUID = function() return "FitTester" end, function() return "Player-FitTester" end
    Enum.EditModeLayoutType = {Preset = 1, Account = 2, Character = 3}
    Enum.EditModeSystem.Minimap = 501
    UIParent.GetWidth, UIParent.GetHeight = function() return 2496 end, function() return 1322 end
    UIParent.GetEffectiveScale = function() return 1 end
    metrics = {isSpanned = true, gameLeft = 0, gameRight = 1755, gameBottom = 0, gameTop = 1097}
    addon.Mainhand:Update("native-fit-fixture")
    addon.HUDCompatibility = {IsExternallyOwnedEditModeSystem = function() return false end}
    local map = frame("NativeMap")
    map.w, map.h = 100, 100
    local function Row(default, relative, x, y)
        return {system = 501, isInDefaultPosition = default, settings = {{setting = 1, value = 123}},
            anchorInfo = {point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = relative, offsetX = x, offsetY = y}}
    end
    local modern = {layoutName = "Modern", layoutIndex = 0, layoutType = 1, systems = {Row(true, "TOPRIGHT", -20, -30)}}
    local playerSource = {layoutName = "My Custom HUD", layoutType = 2, systems = {Row(false, "BOTTOMLEFT", 2450, 1290)}}
    local playerBefore, modernBefore = copyTable(playerSource), copyTable(modern)
    EditModePresetLayoutManager = {GetCopyOfPresetLayouts = function()
        return {copyTable(modern), {layoutName = "Classic", layoutIndex = 1, layoutType = 1, systems = {}},
            {layoutName = "Gamepad", layoutIndex = 2, layoutType = 1, systems = {}}}
    end}
    EditModeManagerFrame = {GetRegisteredSystemFrame = function(_, system) if system == 501 then return map end end}
    layoutData = {activeLayout = 4, layouts = {copyTable(playerSource)}}
    OffhandDB, OffhandCharDB = {}, {}
    local writes, rejectSave = 0, false
    C_EditMode = {
        GetLayouts = function() return copyTable(layoutData) end,
        SaveLayouts = function(data)
            writes = writes + 1
            if rejectSave then return false end
            layoutData = copyTable(data); return true
        end,
        OnLayoutAdded = function(id) layoutData.activeLayout = id; return true end,
        SetActiveLayout = function(id) layoutData.activeLayout = id; return true end,
    }
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    local id = layoutData.activeLayout
    local target = layoutData.layouts[id - 3]
    assert(target.systems[1].anchorInfo.offsetX <= 1755 and target.systems[1].anchorInfo.offsetY <= 1097,
        "actual create transaction retained the source's off-Mainhand absolute coordinates")
    assert(target.systems[1].settings[1].value == 123 and layoutData.layouts[1].layoutName == playerSource.layoutName
        and layoutData.layouts[1].systems[1].anchorInfo.offsetX == 2450,
        "create transaction overwrote the player's source or HUD settings")
    target.systems[1].anchorInfo.offsetX, target.systems[1].anchorInfo.offsetY = 1000, 800
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX == 1000,
        "rebuilding the active current generated layout discarded an in-Mainhand edit")
    local writesBeforeRepair = writes
    local repaired, repairReason = addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName = "MinimapCluster"})
    assert(not repaired and repairReason == "repair-system" and writes == writesBeforeRepair,
        "an unchanged active HUD repair must not rewrite the layout or request another reload")
    layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX = 2450
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout({repairFrameName = "MinimapCluster"}))
    assert(writes == writesBeforeRepair + 1 and layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX <= 1755,
        "a changed repair must still save the active HUD")
    layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX = 1000
    layoutData.activeLayout = 1
    OffhandCharDB.mainhandLayoutBackups = "invalid-old-data"
    assert(addon.Mainhand:CreateOrUpdateEditModeLayout())
    assert(OffhandCharDB.mainhandLayout.sourceName == "Modern" and OffhandCharDB.mainhandLayout.sourcePreset
        and layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX == -761,
        "explicit Create from Modern reused the prior custom source")
    local backup = OffhandCharDB.mainhandLayoutBackups[OffhandCharDB.mainhandLayout.generatedName]
    assert(backup and backup.layout.systems[1].anchorInfo.offsetX == 1000 and #layoutData.layouts == 2,
        "rebase must retain the old generated payload without consuming another native slot")
    assert(playerSource.systems[1].anchorInfo.offsetX == playerBefore.systems[1].anchorInfo.offsetX
        and modern.systems[1].anchorInfo.offsetX == modernBefore.systems[1].anchorInfo.offsetX,
        "source preset or custom source was mutated")
    local previousRecord = copyTable(OffhandCharDB.mainhandLayout)
    local beforeAnchor = layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX
    OffhandCharDB.mainhandLayoutBackups = nil
    layoutData.activeLayout, rejectSave = 4, true
    local succeeded, reason = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(not succeeded and reason == "save" and layoutData.layouts[id - 3].systems[1].anchorInfo.offsetX == beforeAnchor
        and OffhandCharDB.mainhandLayout.sourceName == previousRecord.sourceName,
        "failed native save changed the active payload or provenance")
    assert(OffhandCharDB.mainhandLayoutBackups[previousRecord.generatedName].layout.systems[1].anchorInfo.offsetX == beforeAnchor,
        "an erroring native save must still retain the pre-write generated payload")
    addon._displayGeometryTransitionActive = true
    local beforeWrites = writes
    succeeded, reason = addon.Mainhand:CreateOrUpdateEditModeLayout()
    assert(not succeeded and reason == "span" and writes == beforeWrites, "unsettled geometry must block layout saving")
    addon._displayGeometryTransitionActive = nil
    print("PASS: native HUD fitting transaction preserves source/generated edits, supports explicit Modern rebase, snapshots and failed-save guards")
end
