local addon = {}
local loaded = {}

C_AddOns = {
    IsAddOnLoaded = function(name)
        return loaded[name] == true
    end,
}
WorldMapFrame = {}

assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
local compatibility = assert(addon.CanvasCompatibility)

assert(compatibility.GetWorldMapExternalOwner() == nil,
    "Offhand must own the World Map when no external owner is loaded")
assert(not compatibility.ShouldYieldWorldMap(WorldMapFrame),
    "an unowned World Map must remain available to Offhand")

loaded.Leatrix_Maps = true
assert(compatibility.GetWorldMapExternalOwner() == "LeatrixMaps",
    "Leatrix Maps ownership was not detected")
assert(compatibility.IsExternallyPositionedWorldMap(WorldMapFrame),
    "Leatrix Maps geometry ownership was not detected")
assert(compatibility.GetDiagnostics(false, 3)
        == "MoveAny=absent | WorldMapOwner=LeatrixMaps | LeatrixMaps=loaded | CoordinateFontRefresh=3",
    "Leatrix Maps diagnostics changed during extraction")

loaded.OpenMap = true
assert(compatibility.GetWorldMapExternalOwner() == "OpenMap",
    "OpenMap must take diagnostic precedence over Leatrix Maps")
assert(compatibility.GetDiagnostics(true)
        == "WorldMapOwner=OpenMap | LeatrixMaps=loaded | OpenMap=loaded",
    "compact compatibility diagnostics changed during extraction")

loaded.ClassicUIForever = true
assert(compatibility.GetWorldMapExternalOwner() == "ClassicUIForever",
    "ClassicUIForever must take precedence over OpenMap")
assert(compatibility.ShouldYieldFrameToClassicUIForever("CharacterFrame"),
    "ClassicUIForever CharacterFrame ownership was not detected")
assert(not compatibility.IsExternallyPositionedWorldMap(WorldMapFrame),
    "ClassicUIForever must not enter the OpenMap and Leatrix geometry path")

MoveAny = {}
assert(compatibility.GetWorldMapExternalOwner() == "MoveAny",
    "MoveAny must remain the highest-priority World Map owner")
assert(compatibility.ShouldYieldWorldMap("WorldMapFrame"),
    "World Map ownership must be yielded by frame name")
assert(not compatibility.ShouldYieldWorldMap("CharacterFrame"),
    "World Map ownership must not apply to unrelated frames")

MoveAny = nil
C_AddOns = nil
loaded = { MoveAnything = true }
IsAddOnLoaded = function(name)
    return loaded[name] == true
end
assert(compatibility.GetWorldMapExternalOwner() == "MoveAny",
    "legacy addon detection must recognize MoveAnything")

IsAddOnLoaded = function()
    error("simulated addon API failure")
end
assert(not compatibility.IsAddonLoaded("MoveAnything"),
    "addon API failures must fail closed")

addon.isForever = true
addon.HasBlizzardEditMode = function() return true end
addon.IsExperimentalForeverProfessionsMovementEnabled = function() return false end
assert(compatibility.IsForeverProfessionsPanel(nil, "ProfessionsFrame"),
    "Forever Professions ownership was not detected")
assert(compatibility.ShouldYieldForeverProfessionsPanel(nil, "TradeSkillFrame"),
    "context-bound Forever Professions panels must remain Blizzard-owned")
assert(compatibility.IsForeverEditModeFrame(nil, "PartyMemberFrame1"),
    "Forever Edit Mode frame ownership was not detected")
assert(compatibility.IsBlizzardEditModeOwnedFrame(nil, "DamageMeterFrame"),
    "native Damage Meter ownership was not detected")

print("PASS: Canvas external ownership priority, yielding, diagnostics and API fallback")
