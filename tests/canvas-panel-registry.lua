local addon = {
    db = {
        workspacePanelLoadAddons = {},
    },
}

UIPanelWindows = {
    ExistingFrame = {},
}

assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
local registry = assert(addon.CanvasPanelRegistry)
local owner = {}

addon.isRetail = true
assert(registry.RequiresNativePanelRegistration("WorldMapFrame")
    and not registry.IsContextBoundPanel("WorldMapFrame"),
    "Retail MapCanvas must retain native panel registration and provider lifecycle")
PlayerSpellsFrame = {GetName = function() return "PlayerSpellsFrame" end}
SpellBookFrame = {GetParent = function() return PlayerSpellsFrame end}
assert(registry.GetPositionRoot(SpellBookFrame) == PlayerSpellsFrame
        and not registry.IsBasePersistentCandidate("SpellBookFrame"),
    "Retail spellbook content must never be restored as an independent window")
PlayerSpellsFrame, SpellBookFrame, addon.isRetail = nil, nil, nil

assert(registry.IsContextBoundPanel("ProfessionsFrame")
    and registry.IsContextBoundPanel("TradeSkillFrame")
    and registry.IsContextBoundPanel("CraftFrame"), "crafting sessions must retain native visibility ownership")
assert(not registry.IsBasePersistentCandidate("ProfessionsFrame"), "Retail crafting must not load from saved open intent")
addon.isForever = true
assert(not registry.IsContextBoundPanel("ProfessionsFrame")
    and registry.IsBasePersistentCandidate("ProfessionsFrame"), "Forever standalone book persistence must remain available")
assert(registry.IsContextBoundPanel("TradeSkillFrame"), "Forever context-bound crafting remains native")
addon.isForever = nil
addon.isRetail = true
assert(registry.RequiresNativePanelRegistration("PlayerSpellsFrame")
    and not registry.IsContextBoundPanel("PlayerSpellsFrame")
    and registry.IsBasePersistentCandidate("PlayerSpellsFrame"),
    "Retail spellbook must keep native registration without losing standalone reload support")
assert(not registry.IsContextBoundPanel("ProfessionsBookFrame"), "standalone Retail book must permit reload restoration")
assert(registry.RequiresNativePanelRegistration("FriendsFrame")
    and not registry.IsContextBoundPanel("FriendsFrame"),
    "Retail Contacts must retain native registration without becoming an interaction-bound panel")
assert(registry.GetPersistentPanelAddon("ProfessionsBookFrame") == "Blizzard_ProfessionsBook",
    "Retail standalone book must load its own addon")
addon.db.workspacePanelLoadAddons.ProfessionsBookFrame = "Blizzard_Professions"
assert(registry.GetPersistentPanelAddon("ProfessionsBookFrame") == "Blizzard_ProfessionsBook",
    "historical crafting owner must not prevent Retail book restoration")
addon.isRetail, addon.isForever = false, true
assert(registry.GetPersistentPanelAddon("ProfessionsBookFrame") == "Blizzard_Professions",
    "Forever owner routing must remain unchanged")
addon.isRetail, addon.isForever = nil, nil
addon.db.workspacePanelLoadAddons.ProfessionsBookFrame = nil

registry.InitializeTracking(owner)
assert(owner.knownUIPanelNames.ExistingFrame == true,
    "panel tracking must snapshot existing UIPanel registrations")
assert(type(owner.panelsRegisteredSinceAddonEvent) == "table"
        and type(owner.panelLoadRequests) == "table",
    "panel tracking tables must initialize together")

UIPanelWindows.FutureJournalFrame = {}
registry.RecordLoadedPanelAddon(owner, "Blizzard_FutureJournal", function(name)
    return registry.IsBasePersistentCandidate(name)
end)
assert(addon.db.workspacePanelLoadAddons.FutureJournalFrame == "Blizzard_FutureJournal",
    "new persistent UIPanels must learn their Blizzard addon owner")

UIPanelWindows.ClassTrainerFrame = {}
registry.RecordLoadedPanelAddon(owner, "Blizzard_TrainerUI", function(name)
    return registry.IsBasePersistentCandidate(name)
end)
assert(addon.db.workspacePanelLoadAddons.ClassTrainerFrame == nil,
    "context-bound panels must not learn a reload owner")

UIPanelWindows.InvalidOwnerFrame = {}
registry.RecordLoadedPanelAddon(owner, "ThirdParty_Addon", function()
    return true
end)
assert(addon.db.workspacePanelLoadAddons.InvalidOwnerFrame == nil,
    "non-Blizzard addon names must not enter the learned registry")

local addonName, source = registry.GetPersistentPanelAddon("MacroFrame")
assert(addonName == "Blizzard_MacroUI" and source == "known",
    "the established panel seed registry changed during extraction")
addon.db.workspacePanelLoadAddons.MacroFrame = "Blizzard_CustomMacroUI"
addonName, source = registry.GetPersistentPanelAddon("MacroFrame")
assert(addonName == "Blizzard_CustomMacroUI" and source == "learned",
    "learned panel ownership must override the seed registry")
addon.db.workspacePanelLoadAddons.BadFrame = "Unsafe-Addon"
addonName, source = registry.GetPersistentPanelAddon("BadFrame")
assert(addonName == nil and source == "unknown",
    "invalid learned addon names must fail closed")

local loadCalls = 0
C_AddOns = {
    IsAddOnLoaded = function(name)
        return name == "Blizzard_AlreadyLoaded"
    end,
    LoadAddOn = function(name)
        loadCalls = loadCalls + 1
        return name == "Blizzard_Loadable"
    end,
}
assert(registry.IsAddonLoaded("Blizzard_AlreadyLoaded"),
    "modern addon load-state detection changed during extraction")
local callOK, loadResult = registry.LoadAddon("Blizzard_Loadable")
assert(callOK and loadResult == true and loadCalls == 1,
    "modern load-on-demand invocation changed during extraction")

C_AddOns = nil
IsAddOnLoaded = function(name)
    return name == "Blizzard_LegacyLoaded"
end
LoadAddOn = function(name)
    return name == "Blizzard_LegacyLoadable"
end
assert(registry.IsAddonLoaded("Blizzard_LegacyLoaded"),
    "legacy addon load-state detection changed during extraction")
callOK, loadResult = registry.LoadAddon("Blizzard_LegacyLoadable")
assert(callOK and loadResult == true,
    "legacy load-on-demand invocation changed during extraction")

owner.panelLoadRequests = {
    ZetaFrame = "failed:Blizzard_Zeta",
    AlphaFrame = "loaded:Blizzard_Alpha",
}
assert(registry.GetDiagnostics(owner)
        == "Learned=2 | Requests=AlphaFrame=loaded:Blizzard_Alpha,ZetaFrame=failed:Blizzard_Zeta",
    "panel registry diagnostics must preserve learned counts and sorted requests")

print("PASS: Canvas panel registry learning, exclusions, loading and diagnostics")
