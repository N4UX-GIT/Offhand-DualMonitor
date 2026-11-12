local function frame(scale)
    return {GetEffectiveScale = function() return scale end}
end
UIParent = frame(1)
UIParent.GetWidth = function() return 4000 end
UIParent.GetHeight = function() return 2560 end
Enum = {
    EditModeSystem = {ActionBar = 0, Minimap = 1, UnitFrame = 2},
    EditModeActionBarSystemIndices = {MainBar = 1},
    EditModeUnitFrameSystemIndices = {Player = 1, Target = 2, Focus = 3},
}
local combat = false
InCombatLockdown = function() return combat end

local function system(kind, index, point, x, y, relativeTo)
    return {system = kind, systemIndex = index, anchorInfo = {
        point = point, relativePoint = point, relativeTo = relativeTo or "UIParent", offsetX = x, offsetY = y,
    }}
end
local rawBar = system(0, 1, "BOTTOM", 0, 200)
local rawMinimap = system(1, nil, "TOPRIGHT", -24, -24)
local generatedMinimap = system(1, nil, "TOPRIGHT", -40, -1184)
local rawPlayer = system(2, 1, "CENTER", -300, -300)
local rawFocus = system(2, 3, "CENTER", 0, 0, "PlayerFrame")
local context = {
    source = {layoutName = "Modern", systems = {rawBar, rawMinimap, rawPlayer, rawFocus}},
    generated = {layoutName = "Offhand", systems = {rawBar, generatedMinimap, rawPlayer, rawFocus}},
    rect = {left = 1440, right = 4000, bottom = 0, top = 1440, width = 2560, height = 1440,
        screenWidth = 4000, screenHeight = 2560},
}
local addon = {isForever = true, db = {enabled = true}, Mainhand = {
    GetEllesmereLayoutSource = function() return context end,
}}
-- This partial addon fixture needs only the reload capability; keep its
-- existing client/input ownership doubles independent of other runtime APIs.
local reloadRuntime = {}
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", reloadRuntime)
addon.GetReloadUIFunction = reloadRuntime.GetReloadUIFunction

local function element(scale)
    local target = frame(scale)
    target.GetRect = function() return 1700, 600, 170, 40 end
    return {getFrame = function() return target end}
end
local snapshots, payload, importOptions = 0
local linked = {}
local overrides
local activeProfile = "Default"
EllesmereUI = {
    _unlockRegisteredElements = {
        MainBar = element(1), EBS_Minimap = element(.8), player = element(1), focus = element(1),
    },
    IsUnlockAnchored = function(key) return linked[key] end,
    SnapshotAllAddons = function()
        snapshots = snapshots + 1
        return {addons = {
            EllesmereUIActionBars = {barPositions = {Bar2 = {x = 42}}, style = "classic"},
            EllesmereUIMinimap = {minimap = {enabled = true}},
            EllesmereUIUnitFrames = {positions = {}, colors = {r = .1}},
            EllesmereUIChat = {untouched = true},
        }, specOverrides = overrides, uiScale = 1.15, assignedSpecs = {1}, blizzSkinGlobals = {skin = true}}
    end,
    EncodePayload = function(value) payload = value; return "encoded" end,
    GetActiveProfileData = function() return {windowSkinLook = "classic"} end,
    GetActiveProfileName = function() return activeProfile end,
    GetProfileKeys = function() return {["offhand hud"] = true} end,
    ImportProfileInteractive = function(options) importOptions = options; return true end,
}

assert(loadfile("Core/ForeverEllesmereLayout.lua"))("Offhand", addon)
local transfer = assert(addon.EllesmereLayout)
local rows, name = transfer:Preview("ellesmere")
assert(name == "Offhand" and snapshots == 0 and not importOptions, "preview must only read geometry")
assert(rows[1].position.x == 720 and rows[1].position.y == 200,
    "an unchanged external anchor must be projected once and converted to target units")
assert(rows[2].position.x == -50 and rows[2].position.y == -1480,
    "an already projected anchor must only be converted to target units")
assert(rows[3].position.x == 420 and rows[3].position.y == -860,
    "player position should follow the smaller Mainhand rectangle")
EllesmereUI._unlockRegisteredElements.player = element(.8)
local scaledRows = transfer:Preview("ellesmere")
assert(scaledRows[3].position.x == 420 and scaledRows[3].position.y == -860,
    "copy must store scaled unit frame positions in UIParent units")
assert(rows[4].reason == "ELLESMERE_HUD_MODULE_MISSING" and rows[5].reason == "ELLESMERE_HUD_NO_ANCHOR",
    "unavailable and system-relative frames must be skipped explicitly")
assert(rawBar.anchorInfo.offsetX == 0 and generatedMinimap.anchorInfo.offsetY == -1184,
    "preview must not mutate native layout rows")

local microBar = system(0, 1, "RIGHT", -4, 0, "MicroMenuContainer")
microBar.anchorInfo.relativePoint = "LEFT"
MicroMenuContainer = frame(.5)
MicroMenuContainer.IsVisible = function() return true end
MicroMenuContainer.GetRect = function() return 5600, 40, 800, 80 end
context.generated.systems[1] = microBar
context.generatedActive = true
local microRows = transfer:Preview("ellesmere")
assert(microRows[1].position.relPoint == "BOTTOMLEFT"
    and microRows[1].position.x == 2796 and microRows[1].position.y == 40,
    "the active Forever Micro Menu reference must resolve to an absolute anchor")
context.generatedActive = false
microRows = transfer:Preview("ellesmere")
assert(microRows[1].reason == "ELLESMERE_HUD_NO_ANCHOR",
    "an inactive layout must not borrow the current Micro Menu position")
Enum.EditModeSystem.MicroMenu = 13
local menu = system(13, nil, "BOTTOMRIGHT", -100, 20)
context.transferLayout = {systems = {microBar, menu}}
MicroMenuContainer.GetWidth = function() return 800 end
MicroMenuContainer.GetHeight = function() return 80 end
MicroMenuContainer.GetRect = function() return 90000, 90000, 800, 80 end
microRows = transfer:Preview("ellesmere")
assert(microRows[1].position.x == 3496 and microRows[1].position.y == 40,
    "Copy must resolve the serialized Micro Menu anchor instead of a stale live position")
context.transferLayout = nil
context.generated.systems[1] = rawBar

local importRows = rows
local messages, completions = {}, 0
addon.L = {ELLESMERE_HUD_RELOAD = "reload", ELLESMERE_HUD_SAVED_INACTIVE = "saved inactive"}
addon.Print = function(_, message) messages[#messages + 1] = message end
local importResult
local function Completed(result)
    importResult = result
    completions = completions + 1
end
assert(transfer:OpenImport(rows, Completed))
assert(importOptions.profileName == "Offhand HUD (2)" and importOptions.importString == "encoded")
assert(payload.data.addons.EllesmereUIActionBars.barPositions.MainBar.x == 720
    and payload.data.addons.EllesmereUIActionBars.barPositions.Bar2.x == 42
    and payload.data.addons.EllesmereUIActionBars.style == "classic",
    "the module snapshot must preserve other settings and positions")
assert(payload.data.windowSkinLook == "classic" and payload.data.partialImport
    and payload.data.overridesExcluded and not payload.data.uiScale and not payload.data.assignedSpecs
    and not payload.data.blizzSkinGlobals and not payload.data.addons.EllesmereUIChat,
    "the payload must omit account-wide changes and unrelated modules")
importOptions.callback(true)
assert(messages[1] == "saved inactive" and completions == 1 and importResult == "inactive"
    and not transfer:HasPendingReload(),
    "a profile saved under a specialization assignment must not promise that reload applies it")
assert(transfer:OpenImport(rows, Completed))
activeProfile = "Renamed import"
importOptions.callback(true)
assert(#messages == 1 and completions == 2 and importResult == "reload"
    and transfer:HasPendingReload(),
    "a newly activated profile must let the caller present reload without a duplicate chat instruction")
activeProfile = "Different profile"
assert(not transfer:HasPendingReload(), "an inactive import cannot request a reload")
overrides = {{spec = 1}}
local ok, reason = transfer:OpenImport(rows)
assert(not ok and reason == "ELLESMERE_HUD_OVERRIDES")

linked.player = true
context.controller = true
rows = transfer:Preview("ellesmere")
assert(rows[1].reason == "ELLESMERE_HUD_NATIVE_PAD" and rows[2].position
    and rows[3].reason == "ELLESMERE_HUD_ANCHORED", "Gamepad and linked elements must keep their owner")
combat = true
rows, reason = transfer:Preview("ellesmere")
assert(not rows and reason == "ELLESMERE_HUD_BUSY")

combat, context.controller, linked.player = false, false, nil
context.rect.width, context.rect.height = 2560, 1440
addon.Viewport = {GetMetrics = function()
    return {isSpanned = true, workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1440, workspaceTop = 2560}
end}
local function placedElement(left, bottom, width, height, scale)
    local target = frame(scale or 1)
    target.GetRect = function() return left, bottom, width, height end
    return {getFrame = function() return target end}
end
EllesmereUI._unlockRegisteredElements.MainBar = placedElement(1500, 1510, 450, 30)
EllesmereUI._unlockRegisteredElements.EBS_Minimap = placedElement(550, 500, 200, 180, .8)
EllesmereUI._unlockRegisteredElements.player = placedElement(1700, 600, 170, 40)
EllesmereUIDB = {unlockAnchors = {extra = {target = "player"}}}
rows = transfer:Preview("fit")
assert(rows[1].current.bottom == 1510 and rows[1].proposed.bottom == 1410
    and rows[1].position.y == 1410, "fit must show and repair a frame over the span's physical gap")
assert(rows[2].position and rows[2].proposed.left == 1440 and rows[2].current.left == 440,
    "fit must offer Mainhand placement for a gameplay frame in the workspace and normalize its scale")
assert(rows[3].reason == "ELLESMERE_HUD_CHILD_BOUNDS" and rows[3].reasonArgs[1] == "extra",
    "fit must identify the linked child whose bounds cannot be measured")
assert(snapshots == 3, "fit preview must not call the profile snapshot or importer")

EllesmereUIDB = nil
local player = EllesmereUI._unlockRegisteredElements.player
EllesmereUI._unlockRegisteredElements.player = placedElement(1900, 1900, 170, 40, .8)
local scaledFit = transfer:Preview("fit")[3]
assert(scaledFit.position.x == scaledFit.proposed.left and scaledFit.position.y == scaledFit.proposed.bottom,
    "fit must also save scaled unit frames in UIParent units")
EllesmereUI._unlockRegisteredElements.player = player

-- The default profile links each mini cast bar to its unit frame. A root
-- must move together with its children without importing new anchor links.
local registry = EllesmereUI._unlockRegisteredElements
registry.player = placedElement(600, 500, 170, 40)
registry.playerCastbar = placedElement(590, 480, 190, 14)
EllesmereUIDB = {unlockAnchors = {playerCastbar = {target = "player", side = "BOTTOM"}}}
local links = EllesmereUIDB.unlockAnchors
overrides = nil
local grouped = transfer:Preview("fit")[3]
assert(grouped.position and grouped.linkedGroup and grouped.proposed.left == 1450
    and grouped.groupProposed.left == 1440 and grouped.groupProposed.bottom == 480,
    "Fit must keep the entire unit and cast bar group inside Mainhand")
grouped = transfer:Preview("ellesmere")[3]
assert(grouped.position and grouped.position.x == 420 and grouped.position.y == -860
    and grouped.groupProposed.left == grouped.proposed.left - 10
    and grouped.groupProposed.bottom == grouped.proposed.bottom - 20,
    "Copy must use the native parent position and show the attached cast bar at the same relative offset")
assert(transfer:OpenImport({grouped}) and payload.data.addons.EllesmereUIUnitFrames.positions.player
    and payload.data.layoutExcluded and not payload.data.unlockLayout and EllesmereUIDB.unlockAnchors == links,
    "the new profile must retain EllesmereUI's link graph while updating the root position")
local focus = registry.focus
registry.focus = placedElement(800, 500, 170, 40)
links.focus = {target = "player", side = "RIGHT"}
linked.focus = true
local linkedRows = transfer:Preview("fit")
assert(not linkedRows[5].position and linkedRows[5].followKey == "player"
    and linkedRows[5].proposed.left - linkedRows[5].current.left
        == linkedRows[3].proposed.left - linkedRows[3].current.left,
    "a mapped child must be drawn at the selected parent's destination without a separate position write")
links.focus, linked.focus, registry.focus = nil, nil, focus
do
    registry.PetBar = placedElement(650, 10, 170, 24)
    registry.SCREEN_BOTTOM = {label = "Bottom Screen Edge"}
    linked.PetBar = true
    links.PetBar = {target = "SCREEN_BOTTOM", side = "TOP"}
    EllesmereUI.IsScreenEdgeKey = function(key) return key == "SCREEN_BOTTOM" end
    for _, direction in ipairs({"fit", "ellesmere"}) do
        local found
        for _, row in ipairs(transfer:Preview(direction)) do
            if row.map.key == "PetBar" then found = row; break end
        end
        assert(found and not found.position and found.reason == "ELLESMERE_HUD_SCREEN_EDGE"
            and found.reasonArgs[1] == "Bottom Screen Edge",
            "a fixed screen edge must explain that its anchor needs adjustment in Unlock Mode")
    end
    assert(links.PetBar.target == "SCREEN_BOTTOM", "preview must preserve the vendor link")
    registry.PetBar, registry.SCREEN_BOTTOM, linked.PetBar, links.PetBar, EllesmereUI.IsScreenEdgeKey = nil, nil, nil, nil, nil
end
registry.playerCastbar = placedElement(0, 480, 3000, 14)
assert(not transfer:Preview("fit")[3].position, "an oversized linked group must remain excluded")
registry.playerCastbar = {getFrame = function() end, isHidden = function() return true end}
assert(transfer:Preview("fit")[3].position,
    "a disabled cast bar without bounds must not block moving its visible parent")
registry.player, registry.playerCastbar, EllesmereUIDB = player, nil, nil

-- Numbered bars need the same scale-aware, checked transfer as Action Bar 1.
Enum.EditModeActionBarSystemIndices.Bar2 = 2
local bar2 = system(0, 2, "BOTTOM", 0, 260)
context.source.systems[#context.source.systems + 1] = bar2
context.generated.systems[#context.generated.systems + 1] = bar2
registry.Bar2 = placedElement(500, 500, 400, 30)
local bars = transfer:Preview("ellesmere")
assert(#bars == 6 and bars[6].map.key == "Bar2" and bars[6].position.x == 720
    and bars[6].position.y == 260, "Copy must include registered numbered action bars")
assert(transfer:Preview("fit")[6].proposed.left == 1440,
    "Fit must include numbered gameplay bars in the workspace")
Enum.EditModeActionBarSystemIndices.RightBar1 = 4
local bar4 = system(0, 4, "RIGHT", -24, 0)
context.source.systems[#context.source.systems + 1] = bar4
context.generated.systems[#context.generated.systems + 1] = bar4
registry.Bar4 = placedElement(3800, 400, 40, 400)
assert(transfer:Preview("ellesmere")[7].position,
    "Action Bar 4 must map through Forever's RightBar1 enum identity")
registry.Bar4.isHidden = function() return true end
assert(#transfer:Preview("fit") == 6, "disabled numbered bars must stay out of the offered transfer")
registry.Bar4 = nil
table.remove(context.source.systems)
table.remove(context.generated.systems)
context.controller = true
assert(transfer:Preview("ellesmere")[6].reason == "ELLESMERE_HUD_NATIVE_PAD",
    "numbered keyboard bars must yield to the native Gamepad layout")
context.controller, registry.Bar2 = false, nil
table.remove(context.source.systems)
table.remove(context.generated.systems)
local generated = context.generated
context.generated = nil
local forwardRows, _, forward = transfer:Preview("ellesmere")
assert(forward.block == "ELLESMERE_HUD_NEED_NATIVE" and not forwardRows[1].position,
    "a Blizzard source preset alone cannot be offered as a copy of the Offhand HUD")
local _, _, fallback = transfer:Preview("blizzard")
assert(fallback.block == "ELLESMERE_HUD_NEED_NATIVE", "the reverse transfer also needs a native template")
context.block = nil
local fitRows, _, fit = transfer:Preview("fit")
assert(not fit.block and fitRows[1].position, "fit is available before an Offhand HUD is created")
context.generated = generated
rows = transfer:Preview("blizzard")
assert(not rows[1].anchor and rows[2].anchor.offsetX == 520 and rows[2].anchor.offsetY == 472
    and rows[3].anchor.offsetX == 1785 and rows[3].proposed.width == 0,
    "the fallback must only copy reachable positions as native UIParent anchors")

local activeID = 4
local signature = "current"
local nativeGamepad = false
addon.MainhandGeometry = {
    GetCurrentRect = function()
        context.rect.isSpanned = true
        return context.rect
    end,
    Signature = function() return signature end,
}
addon.MainhandCompatibility = {
    IsNativeGamepadInterface = function() return nativeGamepad end,
}
C_EditMode = {
    GetLayouts = function() return {activeLayout = activeID, layouts = {context.generated}} end,
    SaveLayouts = function() error("the transfer must not write Blizzard layouts") end,
    SetActiveLayout = function() error("the transfer must not activate Blizzard layouts") end,
}
EditModePresetLayoutManager = {GetCopyOfPresetLayouts = function() return {context.source} end}
OffhandCharDB = {mainhandLayout = {
    sourceName = "Modern", generatedName = "Offhand", geometrySignature = "current",
}}
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", addon)
local selection = addon.Mainhand:GetEllesmereLayoutSource()
assert(selection.source == context.source and selection.generated == context.generated)
signature = "changed"
selection = addon.Mainhand:GetEllesmereLayoutSource()
assert(selection.source == context.source and not selection.generated,
    "a layout from another span must be projected from its source")
OffhandCharDB = {}
assert(not addon.Mainhand:GetEllesmereLayoutSource(), "an untracked Offhand layout must not be translated twice")
OffhandCharDB = {foreverEditModeLayoutName = "Offhand", foreverEditModeLayoutID = 4,
    characterSetup = {geometrySignature = "current", gamepad = false}}
assert(not addon.Mainhand:GetEllesmereLayoutSource(), "a legacy layout must match this span")
signature = "current"
selection = addon.Mainhand:GetEllesmereLayoutSource()
assert(selection.generated == context.generated and selection.generatedActive and not selection.source,
    "a confirmed legacy layout may reuse its coordinates without projection")
activeID = 1
assert(addon.Mainhand:GetEllesmereLayoutSource().source == context.source)

local gamepadPreset = {layoutName = "Gamepad", systems = {system(1, nil, "TOPRIGHT", 0, 0)}}
EditModePresetLayoutManager.GetCopyOfPresetLayouts = function() return {context.source, gamepadPreset} end
nativeGamepad, activeID = true, 4
selection = addon.Mainhand:GetEllesmereLayoutSource()
assert(selection.source == gamepadPreset and not selection.generated,
    "Gamepad preview must use its own preset while a standard layout is still active")

-- Forever can serialize different settings for a replacement-owned row even
-- when the native position is still the default. That row still needs projection.
Enum.EditModeSystem.GamepadMainActionBar = 30
gamepadPreset.systems[2] = system(30, nil, "BOTTOM", 0, 110)
gamepadPreset.systems[3] = system(2, 1, "BOTTOMRIGHT", -185, 295)
gamepadPreset.systems[4] = system(2, 2, "BOTTOMLEFT", 185, 295)
gamepadPreset.systems[5] = system(2, 3, "BOTTOMLEFT", 386, 316)
for index = 3, 5 do gamepadPreset.systems[index].anchorInfo.relativePoint = "BOTTOM" end
local padMap = system(1, nil, "TOPRIGHT", 0, 0)
padMap.isInDefaultPosition = true
padMap.settings = {{setting = 1, value = 2}}
local padLayout = {layoutName = "Offhand - Gamepad", systems = {
    padMap, gamepadPreset.systems[2], gamepadPreset.systems[3], gamepadPreset.systems[4], gamepadPreset.systems[5],
}}
local oldGetLayouts, oldMainhandLayout = C_EditMode.GetLayouts, OffhandCharDB.mainhandLayout
C_EditMode.GetLayouts = function() return {activeLayout = 4, layouts = {padLayout}} end
OffhandCharDB.mainhandLayout = {sourceName = "Gamepad", generatedName = padLayout.layoutName,
    geometrySignature = "current", controllerLayout = true}
selection = addon.Mainhand:GetEllesmereLayoutSource()
local projected = selection.transferLayout.systems
assert(projected[1].anchorInfo.relativePoint == "TOPRIGHT"
    and projected[1].anchorInfo.offsetX == 0 and projected[1].anchorInfo.offsetY == -1120,
    "the Gamepad minimap must have an import anchor inside the short Mainhand below the void")
assert(projected[3].anchorInfo.offsetX == 720 - 185 and projected[3].anchorInfo.offsetY == 295
    and projected[4].anchorInfo.offsetX == 720 + 185 and projected[4].anchorInfo.offsetY == 295
    and projected[5].anchorInfo.offsetX == 720 + 386 and projected[5].anchorInfo.offsetY == 316,
    "the Gamepad import must preserve the preset's relative unit-frame placement")
assert(padMap.anchorInfo.offsetY == 0 and rawMinimap.anchorInfo.offsetY == -24,
    "Gamepad preview must leave both source layouts intact")
registry.target = placedElement(2000, 300, 260, 90)
local widerUnits = transfer:Preview("ellesmere")
assert(widerUnits[4].proposed.left == 2905 and widerUnits[5].proposed.left == 3173
    and widerUnits[5].proposed.bottom == 316,
    "a wider replacement target must leave focus beside it when Mainhand has room")
context.rect.right, context.rect.width = 2640, 1200
local narrowUnits = transfer:Preview("ellesmere")
assert(narrowUnits[5].proposed.left == 2426 and narrowUnits[5].proposed.bottom == 393,
    "a narrow Mainhand must stack the default focus when it cannot fit to the right")
context.rect.right, context.rect.width = 4000, 2560
local stockFocus = padLayout.systems[5]
padLayout.systems[5] = system(2, 3, "BOTTOMLEFT", 3000, 318)
padLayout.systems[5].isInDefaultPosition = false
assert(transfer:Preview("ellesmere")[5].proposed.left == 3000,
    "fitting the stock focus must not reposition an explicit saved focus anchor")
padLayout.systems[5], registry.target = stockFocus, nil
padMap.isInDefaultPosition = false
assert(addon.Mainhand:GetEllesmereLayoutSource().transferLayout.systems[1].anchorInfo.offsetY == 0,
    "an explicit minimap position must stay available for review")
C_EditMode.GetLayouts, OffhandCharDB.mainhandLayout = oldGetLayouts, oldMainhandLayout
nativeGamepad = false

local savedLayouts = {activeLayout = 4, layouts = {context.generated}}
local saves = 0
C_EditMode.GetLayouts = function() return savedLayouts end
C_EditMode.SaveLayouts = function(value) saves = saves + 1; savedLayouts = value end
Constants = {EditModeConsts = {EditModeMaxLayoutsPerType = 2}}
local saved, fallbackName = addon.Mainhand:SaveEllesmereFallback(context, rows)
assert(saved and savedLayouts.activeLayout == 4 and #savedLayouts.layouts == 2
    and savedLayouts.layouts[2].layoutName == fallbackName
    and savedLayouts.layouts[2].systems[3].anchorInfo.offsetX == 1785
    and savedLayouts.layouts[1].systems[3].anchorInfo.offsetX == -300,
    "the reverse transfer must create an inactive copy and preserve the source layout")
assert(addon.Mainhand:SaveEllesmereFallback(context, rows) and saves == 1,
    "an identical fallback must reuse its slot even when the layout list is full")
rows[3].anchor.offsetX = 1800
local success, failure = addon.Mainhand:SaveEllesmereFallback(context, rows)
assert(not success and failure == "maximum" and saves == 1, "a full list must preserve both existing layouts")

local preview, review
local widget = {}
for _, method in ipairs({"ClearAllPoints", "SetPoint", "SetSize", "SetFrameStrata", "EnableMouse",
    "SetJustifyH", "SetWordWrap", "SetAllPoints", "SetFrameLevel", "SetColorTexture", "SetTextColor",
    "SetAlpha", "SetChecked", "SetEnabled", "SetWidth", "SetHeight", "Raise"}) do widget[method] = function() end end
function widget:GetFrameLevel() return 1 end
function widget:GetName() return self.name end
function widget:SetScript(event, callback) self[event] = callback end
function widget:SetText(value)
    self.text = value
    if value == "Review profile import" then review = self end
end
function widget:Show() self.shown = true end
function widget:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.OnHide then self:OnHide() end
end
function widget:IsShown() return self.shown end
function widget:SetShown(shown) self.shown = shown end
function widget:SetEnabled(enabled) self.enabled = enabled end
function widget:CreateFontString() return CreateFrame() end
function widget:CreateTexture() return CreateFrame() end
CreateFrame = function(_, name)
    local instance = setmetatable({name = name}, {__index = widget})
    if name == "OffhandEllesmerePreviewFrame" then preview = instance end
    return instance
end
local pendingTimers = {}
C_Timer = {After = function(_, callback) pendingTimers[#pendingTimers + 1] = callback end}
local function Tick() table.remove(pendingTimers, 1)() end
assert(loadfile("Locales/enUS.lua"))("Offhand", addon)
addon.UIControls = {CreateFrame = CreateFrame, StyleSurface = function() end, FitDialog = function() return 1 end}
addon.Viewport.GetMetrics = function() return {isSpanned = false} end
transfer.Preview = function() return importRows, "Offhand", context end
local optionsShown, profilesReady, navigations, rebuilds = false, false, 0, 0
EllesmereUI.NavigateToElementSettings = function(_, module, page)
    assert(not preview:IsShown() and not importOptions and module == "_EUIProfiles" and page == "Profiles")
    navigations = navigations + 1
    optionsShown = true
end
EllesmereUI.GetActiveModule = function() return "_EUIProfiles" end
EllesmereUI.GetActivePage = function() return "Profiles" end
EllesmereUI.IsShown = function() return optionsShown end
EllesmereUI._profilesRoot = {IsVisible = function() return profilesReady end}
EllesmereUI.RefreshPage = function(_, force)
    assert(force and not importOptions, "rebuild only before the import is handed off")
    rebuilds = rebuilds + 1
    profilesReady = true
end
assert(loadfile("UI/EllesmereLayoutPreview.lua"))("Offhand", addon)
importOptions, overrides = nil, nil
transfer:ShowPreview("ellesmere")
assert(not preview.selected, "the preview's row selection must not accent the dialog border")

context.block = "ELLESMERE_HUD_OVERRIDES"
transfer:ShowPreview("ellesmere")
assert(not review.enabled and preview.status.text == addon.L.ELLESMERE_HUD_OVERRIDES_HELP,
    "profile override blockers need a visible action path and disabled import")
context.block = nil
do
    local savedRows = importRows
    local savedUnavailable = context.unavailable
    context.unavailable = nil
    importRows = {{map = {key = "linkedFixture", displayLabel = "Player frame"},
        reason = "ELLESMERE_HUD_FOLLOWS", reasonArgs = {"Action Bar 1"}}}
    transfer:ShowPreview("ellesmere")
    assert(preview.legend[1].text:find("Follows Action Bar 1", 1, true)
        and preview.status.text:find("1 elements", 1, true) and not review.enabled,
        "explain the linked parent and why no positions can be transferred")
    local tooltip
    GameTooltip = {SetOwner = function() end, SetText = function(_, text) tooltip = text end,
        Show = function() end, Hide = function() end}
    preview.rowHelp[1]:OnEnter()
    assert(tooltip:find("EllesmereUI Unlock Mode", 1, true), "row tooltips must explain how to resolve the blocker")
    preview.rowHelp[1]:OnLeave()
    importRows[1].reason, importRows[1].reasonArgs = "ELLESMERE_HUD_SCREEN_EDGE", {"Bottom Screen Edge"}
    transfer:ShowPreview("ellesmere")
    assert(preview.legend[1].text:find("Anchored to Bottom Screen Edge", 1, true) and not review.enabled,
        "show that the target is a fixed edge")
    preview.rowHelp[1]:OnEnter()
    assert(tooltip:find("remove the anchor", 1, true), "edge-linked rows must show how to make transfer available")
    preview.rowHelp[1]:OnLeave()
    GameTooltip, importRows = nil, savedRows
    context.unavailable = savedUnavailable
    transfer:ShowPreview("ellesmere")
end
do
    local savedRows = importRows
    importRows = {}
    for i = 1, 25 do
        importRows[i] = {map = {key = "page" .. i, displayLabel = "Frame " .. i},
            position = {point = "BOTTOMLEFT", relPoint = "BOTTOMLEFT", x = 1800, y = i * 10}}
    end
    transfer:ShowPreview("ellesmere")
    assert(preview.pages.text == "1 / 3")
    preview.next.OnClick()
    assert(preview.pages.text == "2 / 3" and preview.legend[1].text:find("13  Frame 13", 1, true))
    preview.checkboxes[1].GetChecked = function() return false end
    preview.checkboxes[1]:OnClick()
    assert(preview.rowSelection.page13 == false and preview.rowSelection.page1 == nil,
        "page-two selection must address its global row")
    preview.previous.OnClick()
    assert(preview.pages.text == "1 / 3" and preview.rowSelection.page13 == false)
    importRows = savedRows
    transfer:ShowPreview("ellesmere")
end
review.OnClick()
assert(not preview:IsShown() and navigations == 0)
Tick()
assert(navigations == 1 and not importOptions, "navigation must finish before import starts")
Tick()
assert(rebuilds == 1 and importOptions, "repair a hidden Profiles page before handing off to EllesmereUI")

importOptions = nil
transfer:ShowPreview("ellesmere")
review.OnClick()
Tick()
optionsShown = false
Tick()
assert(not importOptions and not preview:IsShown(), "closing EllesmereUI must cancel a queued handoff")
transfer:ShowPreview("ellesmere")
review.OnClick()
combat = true
Tick()
assert(not importOptions and preview:IsShown(), "combat must stop the handoff and return to the preview")

combat = false
local returns = 0
local lastResult
local function ReturnToWizard(result)
    lastResult = result
    returns = returns + 1
end
assert(transfer:ShowPreview("ellesmere", ReturnToWizard))
preview:Hide()
assert(returns == 0)
Tick()
assert(returns == 1, "Escape or Close returns after the preview has fully hidden")

assert(transfer:ShowPreview("ellesmere", ReturnToWizard))
review.OnClick()
Tick()
Tick()
assert(importOptions and returns == 1, "starting an import keeps the wizard hidden")
optionsShown = false
importOptions.callback(false)
Tick()
assert(returns == 2 and lastResult == nil, "closing the EllesmereUI import returns to the wizard")

local optionsFrame = CreateFrame()
optionsFrame.HookScript = optionsFrame.SetScript
EllesmereUI.GetMainFrame = function() return optionsFrame end
local popup, reloads, gamepad = nil, 0, false
StaticPopupDialogs = {}
addon.ShowPopup = function(_, key) popup = assert(StaticPopupDialogs[key]) end
addon.Mainhand.IsNativeGamepadInterface = function() return gamepad end
ReloadUI = function() reloads = reloads + 1 end
local function StartReview(callback)
    importOptions = nil
    transfer:ShowPreview("ellesmere", callback)
    review.OnClick()
    Tick()
    Tick()
    optionsFrame:Show()
end
StartReview(ReturnToWizard)
activeProfile = "Wizard import"
importOptions.callback(true)
Tick()
assert(returns == 2 and not popup, "the wizard must wait for the profile window to close")
optionsFrame:Hide()
Tick()
assert(returns == 3 and lastResult == "reload" and not popup, "wizard reload waits for Finish")
StartReview()
activeProfile = "Settings import"
importOptions.callback(true)
Tick()
assert(not popup, "the standalone prompt must wait for the profile window to close")
optionsFrame:Hide()
Tick()
assert(popup.text == addon.L.ELLESMERE_HUD_IMPORT_RELOAD_PROMPT and popup.OnAccept
    and popup.offhandAcceptBeforeHide and reloads == 0,
    "Forever keyboard import reload must keep the clicked parent visible")
addon.isForever = false
transfer:PromptImportReload()
assert(popup.text == addon.L.ELLESMERE_HUD_IMPORT_RELOAD_PROMPT and reloads == 0)
popup.OnAccept()
assert(reloads == 1, "Standard reload requires a confirmation click")
do
    local previousUI, previousReload = C_UI, ReloadUI
    C_UI, ReloadUI = { Reload = function() reloads = reloads + 1 end }, nil
    transfer:PromptImportReload()
    popup.OnAccept()
    assert(reloads == 2, "import reload must work with only C_UI.Reload available")
    C_UI, ReloadUI = previousUI, previousReload
end
addon.isForever = true
transfer:PromptImportReload()
assert(popup.OnAccept and popup.offhandAcceptBeforeHide and reloads == 2,
    "Forever keyboard import must retain callback-first reload")
combat = true
popup.OnAccept()
assert(popup.text == addon.L.ELLESMERE_HUD_IMPORT_RELOAD_MANUAL and not popup.OnAccept and reloads == 2,
    "combat starting before the click must replace the dialog with manual instructions")
combat = false
gamepad = true
transfer:PromptImportReload()
assert(popup.text == addon.L.ELLESMERE_HUD_IMPORT_RELOAD_MANUAL and not popup.OnAccept and reloads == 2,
    "Forever Gamepad must receive the manual reload instructions")
print("PASS: EllesmereUI preview, staged profile review, span fit and inactive Blizzard fallback")
