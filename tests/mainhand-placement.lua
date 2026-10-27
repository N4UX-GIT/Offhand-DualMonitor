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
assert(loadfile("Core/MainhandGeometry.lua"))("Offhand", addon)
assert(loadfile("Core/MainhandCompatibility.lua"))("Offhand", addon)
assert(loadfile("Core/MainhandGamepad.lua"))("Offhand", addon)
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

ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and localName == "Offhand - Mainhand - Tester" and moved == 11,
    "Mainhand Edit Mode layout was not generated from the active preset")
assert(layoutAdded == 4 and activated == nil and #saved.layouts == 1 and saveCount == 1,
    "generated custom layout did not use Blizzard's one-save layout-added transaction")
local generated = saved.layouts[1]
assert(generated.systems[1].anchorInfo.offsetX == 720
        and generated.systems[1].anchorInfo.offsetY == -656,
    "the default Damage Meter was not translated and inset below Mainhand's top region")
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
        and generated.systems[13].anchorInfo.offsetY == -1184,
    "the default Minimap and its system-relative Buff row were not inset from Mainhand's top edge")
assert(generated.systems[14].anchorInfo.relativeTo == "MinimapCluster"
        and generated.systems[14].anchorInfo.offsetX == -8
        and generated.systems[14].anchorInfo.offsetY == -96,
    "the default keyboard Buff Frame was not inset further without breaking its native relationship")
assert(preset.systems[1].anchorInfo.offsetX == 0 and preset.systems[1].anchorInfo.offsetY == 0,
    "the source preset was mutated")
assert(OffhandCharDB.mainhandLayout.sourcePreset
        and OffhandCharDB.mainhandLayout.sourceID == 1
        and OffhandCharDB.foreverEditModeLayoutID == 4,
    "per-character layout provenance was not recorded")

-- Retail/Anniversary login restores a character's layout by name. Repairing
-- the HUD must replace any stale remembered layout in the same successful
-- transaction, otherwise /reload immediately undoes the repair.
addon.isForever = false
addon.isRetail = true
OffhandCharDB.editModeLayoutName = "1234"
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and OffhandCharDB.editModeLayoutName == localName
        and localName == "Offhand - Mainhand - Tester",
    "Retail HUD repair did not persist the generated layout as the character preference")
addon.isForever = true
addon.isRetail = false

-- Updating for another topology must rebuild from the original preset, not
-- translate the generated layout a second time.
metrics = { gameLeft = 0, gameBottom = 0, gameRight = 2560, gameTop = 1440, isSpanned = true }
addon.Mainhand:Update("topology")
ok, localName, moved = addon.Mainhand:CreateOrUpdateEditModeLayout()
assert(ok and #saved.layouts == 1 and layoutData.activeLayout == 4 and moved == 11,
    "layout update duplicated the generated layout")
assert(saveCount == 3,
    "layout updates must save once and must not resubmit the payload after activation")
generated = saved.layouts[1]
assert(generated.systems[1].anchorInfo.offsetX == -720
        and generated.systems[1].anchorInfo.offsetY == -656,
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
assert(ok and localName == "Offhand - Mainhand - Tester"
        and #saved.layouts == 2 and saved.layouts[1].layoutName == foreignLayout.layoutName
        and saved.layouts[2].layoutName == "Offhand - Mainhand - Tester",
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
local shownPopup
addon.ShowPopup = function(_, key) shownPopup = key end
assert(addon.Mainhand:PromptReload()
        and shownPopup == "OFFHAND_MAINHAND_LAYOUT_RELOAD"
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept == nil
        and StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.button2 == nil,
    "native Gamepad reload prompt retained a protected ReloadUI callback")
currentInterfaceStyle = 1
assert(addon.Mainhand:PromptReload()
        and type(StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept) == "function",
    "keyboard reload prompt did not retain its normal reload action")
StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.OnAccept()
assert(reloadCalls == 1, "keyboard reload prompt did not call ReloadUI")
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
-- A custom Retail source can attach Action Bar 1 to the XP bar while the XP bar
-- keeps its default StatusTrackingBarManager anchor at the bottom of the span.
-- Repair must bring the default status bars into Mainhand so the chain follows.
MainStatusTrackingBarContainer=frame('MainStatusTrackingBarContainer')
MainStatusTrackingBarContainer:SetSize(571,17); MainStatusTrackingBarContainer.scale=0.8
local customSource=copyTable(preset)
customSource.systems={
    {system=Enum.EditModeSystem.ActionBar,systemIndex=Enum.EditModeActionBarSystemIndices.MainBar,isInDefaultPosition=false,
        anchorInfo={point='BOTTOMLEFT',relativeTo='MainStatusTrackingBarContainer',relativePoint='TOPLEFT',offsetX=0,offsetY=4}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=1,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='StatusTrackingBarManager',relativePoint='BOTTOM',offsetX=0,offsetY=0}},
    {system=Enum.EditModeSystem.StatusTrackingBar,systemIndex=2,isInDefaultPosition=true,
        anchorInfo={point='BOTTOM',relativeTo='StatusTrackingBarManager',relativePoint='BOTTOM',offsetX=0,offsetY=17}},
    {system=Enum.EditModeSystem.ActionBar,systemIndex=Enum.EditModeActionBarSystemIndices.StanceBar,isInDefaultPosition=false,
        anchorInfo={point='BOTTOM',relativeTo='UIParent',relativePoint='BOTTOM',offsetX=0,offsetY=200}},
}
presetLayouts={customSource,{layoutName='Classic',layoutIndex=1,systems={}}}
layoutData={activeLayout=1,layouts={}}
ok=addon.Mainhand:CreateOrUpdateEditModeLayout(); assert(ok)
local rect=addon.Mainhand:GetRect()
local rows=saved.layouts[1].systems
assert(rows[1].anchorInfo.relativeTo=='MainStatusTrackingBarContainer' and rows[1].anchorInfo.offsetY==4,
    'the player-attached main bar keeps its relationship and follows the status bar')
assert(rows[2].anchorInfo.relativeTo=='UIParent' and rows[2].anchorInfo.point=='BOTTOM'
    and rows[2].isInDefaultPosition==false,'default XP bar must be rebased out of the span bottom')
near(rows[2].anchorInfo.offsetX*0.8,(rect.left+rect.right)/2-UIParent:GetWidth()/2)
near(rows[2].anchorInfo.offsetY*0.8,rect.bottom+8)
near(rows[3].anchorInfo.offsetY*1.1,rect.bottom+8+17*0.8+4)
assert(customSource.systems[2].anchorInfo.relativeTo=='StatusTrackingBarManager','source layout must not be mutated')
print('PASS: Retail custom main bar attached to a default XP bar is brought into Mainhand')
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
