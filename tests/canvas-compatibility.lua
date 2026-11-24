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

-- Active external owners, conflict detection, diagnostics, and once-per-session notice
C_AddOns = { IsAddOnLoaded = function(name) return loaded[name] == true end }
IsAddOnLoaded = nil
addon.db = { enabled = true }
addon.L = {}
addon.Viewport = { GetMetrics = function() return { isSpanned = true } end }
local printed = {}
addon.Print = function(_, msg) printed[#printed + 1] = msg end

-- Healthy single-owner OpenMap + OneForAll (mitigated via ok contract): zero conflicts, silent chat, synced diag
loaded = { OpenMap = true, OneForAll = true, Baganator = true }
WorldMapFrame = { ofaMovable = true }
OpenMap = { version = "v0.8.14", GetModule = function() return { db = OpenMapDB.worldmap } end }
OpenMapAPI = { major = 1, version = 5 }
OpenMapDB = { worldmap = { enabled = true, windowScale = 1, window = false, windowSize = false } }
Baganator = {}
local owners = compatibility.GetActiveExternalOwners()
assert(owners.map == "OpenMap" and owners.bags[1] == "Baganator",
    "GetActiveExternalOwners must name active map and bag owners")
assert(#compatibility.GetOwnershipConflicts() == 0,
    "healthy OpenMap v1 + OneForAll must not trigger an unmitigated conflict")
assert(compatibility.NotifyActiveConflicts() == 0 and #printed == 0,
    "healthy coexistence must never print chat notices")
local diagSynced = compatibility.GetDiagnostics(false)
assert(diagSynced:find("OpenMapContract=ok", 1, true)
    and diagSynced:find("WorldMapMover=OneForAll(synced)", 1, true),
    "detailed diagnostics must expose OpenMapContract and synced mover status")

-- Breaking OpenMap major bump + OneForAll: reports both contract stand-down and mover conflict once per session
OpenMapAPI.major = 2
local conflicts = compatibility.GetOwnershipConflicts()
assert(#conflicts == 2, "breaking OpenMap major + OneForAll must report contract and mover conflicts")
assert(compatibility.NotifyActiveConflicts() == 2 and #printed == 2,
    "active conflicts must notify once per session")
assert(compatibility.NotifyActiveConflicts() == 0 and #printed == 2,
    "repeated NotifyActiveConflicts must never spam the same conflict twice")
assert(compatibility.GetDiagnostics(false):find("OpenMapContract=unsupported-major", 1, true)
    and compatibility.GetDiagnostics(false):find("WorldMapMover=OneForAll(conflict)", 1, true)
    and compatibility.GetDiagnostics(false):find("Conflicts=", 1, true))

-- Leatrix_Maps + OneForAll + competing bag addons
compatibility.ResetConflictNotifications()
printed = {}
loaded = { Leatrix_Maps = true, OneForAll = true, Baganator = true, Bagnon = true }
Bagnon = {}
OpenMap, OpenMapAPI, OpenMapDB = nil, nil, nil
conflicts = compatibility.GetOwnershipConflicts()
assert(#conflicts == 2, "Leatrix_Maps + OneForAll and dual bag addons must both flag conflicts")
assert(compatibility.NotifyActiveConflicts() == 2 and #printed == 2)
Bagnon = nil

-- ElvUI with bags module disabled + Baganator must NOT flag a false bag conflict;
-- ElvUI with active ElvUI_ContainerFrame + Baganator MUST flag a bag conflict.
loaded = { Baganator = true }
ElvUI = { { private = { bags = { enable = false } } } }
ElvUI_ContainerFrame = nil
assert(#compatibility.GetOwnershipConflicts() == 0,
    "ElvUI with disabled bags + Baganator must not trigger a false bag conflict")
ElvUI_ContainerFrame = {}
assert(#compatibility.GetOwnershipConflicts() == 1
    and compatibility.GetOwnershipConflicts()[1].kind == "bags-conflict",
    "ElvUI with active bag frame + Baganator must trigger a bag conflict")
Baganator, ElvUI, ElvUI_ContainerFrame = nil, nil, nil

print("PASS: Canvas external ownership priority, yielding, diagnostics, contract validation, conflicts and API fallback")
