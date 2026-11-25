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
-- ElvUI with active bag frame + Baganator MUST flag a bag conflict.
ElvUI_ContainerFrame = {}
assert(#compatibility.GetOwnershipConflicts() == 1
    and compatibility.GetOwnershipConflicts()[1].kind == "bags-conflict",
    "ElvUI with active bag frame + Baganator must trigger a bag conflict")
Baganator, ElvUI, ElvUI_ContainerFrame = nil, nil, nil

-- Forever default Blizzard UI + OneForAll Move Blizzard windows: reports window-mover
-- conflict once per session and exposes OneForAllMover=active in diagnostics.
compatibility.ResetConflictNotifications()
printed = {}
loaded = { OneForAll = true }
WorldMapFrame = { ofaMovable = true }
ContainerFrameCombinedBags = { ofaMovable = true }
SettingsPanel = { ofaMovable = true }
OneForAllDB = { qol = { moveWindows = true } }
local ofaConflicts = compatibility.GetOwnershipConflicts()
assert(#ofaConflicts == 1 and ofaConflicts[1].kind == "window-mover"
    and ofaConflicts[1].id == "window-mover:OneForAll",
    "OneForAll moving unmitigated Offhand roots must flag window-mover:OneForAll")
assert(compatibility.NotifyActiveConflicts() == 1 and #printed == 1
    and printed[1]:find("Move Blizzard windows", 1, true),
    "window-mover conflict must notify once per session with the actionable OneForAll setting")
assert(compatibility.NotifyActiveConflicts() == 0 and #printed == 1,
    "window-mover conflict must not spam repeated chat notices")
local ofaDiag = compatibility.GetDiagnostics(false)
assert(ofaDiag:find("OneForAllMover=active", 1, true)
    and ofaDiag:find("Conflicts=window-mover:OneForAll", 1, true),
    "diagnostics must report OneForAllMover=active and window-mover:OneForAll")

-- Disabling Move Blizzard windows in OneForAll clears the conflict even if ofaMovable
-- remains set on frames (for example from Resize Blizzard windows or before reload).
OneForAllDB.qol.moveWindows = false
assert(#compatibility.GetOwnershipConflicts() == 0,
    "disabling OneForAll moveWindows must clear the window-mover conflict")
assert(not compatibility.GetDiagnostics(false):find("OneForAllMover=active", 1, true),
    "disabling OneForAll moveWindows must clear OneForAllMover=active")
OneForAllDB, ContainerFrameCombinedBags, SettingsPanel = nil, nil, nil

-- External frame controllers (e.g. Shadowed Unit Frames, MoveAny, MoveMyBags, Bartender4):
-- surfaced in GetActiveExternalOwners, GetExternalControlGuidance, and full diagnostics,
-- while remaining silent in chat (healthy coexistence, never false conflicts).
compatibility.ResetConflictNotifications()
printed = {}
loaded = { ShadowedUnitFrames = true, MoveAny = true, MoveMyBags = true, Bartender4 = true }
local ctrlOwners = compatibility.GetActiveExternalOwners()
assert(ctrlOwners.unitFrames and ctrlOwners.unitFrames[1] == "ShadowedUnitFrames",
    "ShadowedUnitFrames must be reported under unitFrames")
assert(ctrlOwners.actionBars and ctrlOwners.actionBars[1] == "Bartender4",
    "Bartender4 must be reported under actionBars")
assert(ctrlOwners.movers and ctrlOwners.movers[1] == "MoveAny" and ctrlOwners.movers[2] == "MoveMyBags",
    "MoveAny and MoveMyBags must be reported under movers")
local guides = compatibility.GetExternalControlGuidance()
assert(#guides == 4, "all four external frame controllers must produce actionable guidance")
assert(guides[1].text:find("/suf", 1, true), "SUF guidance must explain /suf and Edit Mode resolution")
assert(guides[2].text:find("/move", 1, true), "MoveAny guidance must explain /move resolution")
assert(guides[3].text:find("/movemybags reset", 1, true)
    and guides[3].text:find("Keep the window you are using in front", 1, true),
    "MoveMyBags guidance on Forever must include the layers tip while layers is enabled")
MoveMyBagsDB = { layers = false }
local guidesNoLayers = compatibility.GetExternalControlGuidance()
assert(guidesNoLayers[3].text:find("/movemybags reset", 1, true)
    and not guidesNoLayers[3].text:find("Keep the window you are using in front", 1, true),
    "MoveMyBags guidance must omit the layers tip once the user disables layers")
MoveMyBagsDB = nil
assert(guides[4].text:find("Bartender4", 1, true), "Bartender4 guidance must name Bartender4")
assert(#compatibility.GetOwnershipConflicts() == 0 and compatibility.NotifyActiveConflicts() == 0 and #printed == 0,
    "single external frame controllers must not spam chat conflicts")
local ctrlDiag = compatibility.GetDiagnostics(false)
assert(ctrlDiag:find("FrameControllers=ShadowedUnitFrames,Bartender4,MoveAny,MoveMyBags", 1, true),
    "full diagnostics must list active FrameControllers for support triage")

print("PASS: Canvas external ownership priority, yielding, diagnostics, contract validation, conflicts, frame-controller guidance and API fallback")
