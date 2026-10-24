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
