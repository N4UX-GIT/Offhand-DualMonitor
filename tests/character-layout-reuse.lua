-- The explicit reuse path must not create, rewrite or promote a layout.
local geometry, combat, gamepad, guid = "geometry", false, false, "Player-new"
local saves, selections = 0, 0
local data = {activeLayout = 1, layouts = {{layoutName = "Offhand", systems = {{anchorInfo = {offsetX = 123}}}}}}
UnitName = function() return "New" end
UnitGUID = function() return guid end
InCombatLockdown = function() return combat end
local presets = {{layoutName = "Modern"}, {layoutName = "Classic"}}
EditModePresetLayoutManager = {GetCopyOfPresetLayouts = function() return presets end}
C_EditMode = {
    GetLayouts = function() return data end,
    SaveLayouts = function() saves = saves + 1; error("reuse called SaveLayouts") end,
    SetActiveLayout = function(id) selections = selections + 1; data.activeLayout = id end,
}
local addon = {isRetail = true, db = {enabled = true}, Mainhand = {
    GetRect = function() return {isSpanned = true} end,
    GetGeometrySignature = function() return geometry end,
}, MainhandGeometry = {}, MainhandCompatibility = {
    IsNativeGamepadInterface = function() return gamepad end,
    IsControllerMode = function() return gamepad end,
}}
OffhandDB = {sharedMainhandLayouts = {Offhand = {
    version = 1, client = "retail", ownershipSignature = "", geometrySignature = geometry,
    sourceName = "Modern", sourceID = 1, sourcePreset = true,
}}}
OffhandCharDB = {}
assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", addon)
local status = addon.Mainhand:GetCharacterSetupLayoutStatus()
assert(status.available and not status.ready and saves == 0 and selections == 0)
assert(addon.Mainhand:UseExistingEditModeLayout())
assert(saves == 0 and selections == 1 and data.layouts[1].systems[1].anchorInfo.offsetX == 123)
assert(addon.Mainhand:GetCharacterSetupLayoutStatus().ready)
local ok, _, _, changed = addon.Mainhand:UseExistingEditModeLayout()
assert(ok and not changed and selections == 1, "already active reuse must not select again")
OffhandDB.sharedMainhandLayouts.Offhand.ownershipSignature = "different-owner"
assert(not addon.Mainhand:UseExistingEditModeLayout(),
    "even a character-owned shared record must honor changed external UI ownership")
OffhandDB.sharedMainhandLayouts.Offhand.ownershipSignature = ""
guid = "Player-recreated"
assert(not addon.Mainhand:GetCharacterSetupLayoutStatus().ready,
    "a prior character's record cannot establish readiness for a recreated character")
geometry = "different"
local oldRecord = OffhandCharDB.mainhandLayout
assert(not addon.Mainhand:UseExistingEditModeLayout()
        and OffhandCharDB.mainhandLayout == oldRecord and selections == 1 and saves == 0,
    "geometry mismatch must not rewrite, create or record a layout")
geometry = "geometry"
combat = true
assert(not addon.Mainhand:UseExistingEditModeLayout() and selections == 1)
combat = false
EditModeManagerFrame = {IsShown = function() return true end}
assert(not addon.Mainhand:UseExistingEditModeLayout() and selections == 1)
EditModeManagerFrame = nil
gamepad = true
assert(not addon.Mainhand:UseExistingEditModeLayout(), "a mouse HUD must not be adopted for controller mode")
gamepad = false
ConsolePort = {}
assert(not addon.Mainhand:UseExistingEditModeLayout(), "external controller ownership must be respected")
ConsolePort = nil

-- A registered foreign character name is not a genuinely shared layout.
OffhandCharDB = {}
data.layouts[1].layoutName = "Offhand - Mainhand - Other"
OffhandDB.sharedMainhandLayouts[data.layouts[1].layoutName] = OffhandDB.sharedMainhandLayouts.Offhand
assert(not addon.Mainhand:UseExistingEditModeLayout() and not OffhandCharDB.mainhandLayout)
data.layouts[1].layoutName = "Offhand"
OffhandDB.sharedMainhandLayouts.Offhand.ownershipSignature = "different-owner"
assert(not addon.Mainhand:UseExistingEditModeLayout(), "external-owner mismatch must reject shared reuse")
OffhandDB.sharedMainhandLayouts.Offhand.ownershipSignature = ""
data.activeLayout = 1
C_EditMode.SetActiveLayout = function() return false end
assert(not addon.Mainhand:UseExistingEditModeLayout() and not OffhandCharDB.mainhandLayout,
    "failed activation must not claim that this character adopted the layout")
C_EditMode.SetActiveLayout = function() return nil end
assert(not addon.Mainhand:UseExistingEditModeLayout() and not OffhandCharDB.mainhandLayout,
    "a successful call without verified activation is not a completed reuse")
assert(saves == 0, "no branch of reuse may call SaveLayouts")
print("PASS: read-only discovery and reuse reject stale, foreign, unsafe and failed activation cases")
