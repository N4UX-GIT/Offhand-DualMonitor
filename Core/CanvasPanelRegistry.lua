--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasPanelRegistry.lua: Load-on-demand panel ownership and tracking
--]]

local _, Offhand = ...

local PanelRegistry = {}
Offhand.CanvasPanelRegistry = PanelRegistry

-- These panels live in Blizzard load-on-demand addons and therefore do not
-- exist during the first PLAYER_ENTERING_WORLD persistence pass. This seed
-- covers established frames; later registrations are learned at runtime.
local knownPanelLoadAddons = {
    PlayerSpellsFrame = "Blizzard_PlayerSpells",
    SpellBookFrame = "Blizzard_SpellBook",
    ProfessionsFrame = "Blizzard_Professions",
    ProfessionsBookFrame = "Blizzard_Professions",
    MacroFrame = "Blizzard_MacroUI",
    CollectionsJournal = "Blizzard_Collections",
    CollectionsJournalFrame = "Blizzard_Collections",
    WardrobeFrame = "Blizzard_Collections",
    AchievementFrame = "Blizzard_AchievementUI",
    AlliedRacesFrame = "Blizzard_AlliedRacesUI",
    ArchaeologyFrame = "Blizzard_ArchaeologyUI",
    CalendarFrame = "Blizzard_Calendar",
    CalendarViewEventFrame = "Blizzard_Calendar",
    ClassTalentFrame = "Blizzard_ClassTalentUI",
    EncounterJournal = "Blizzard_EncounterJournal",
    ExpansionLandingPage = "Blizzard_ExpansionLandingPage",
    MajorFactionRenownFrame = "Blizzard_MajorFactions",
    PVEFrame = "Blizzard_GroupFinder",
    PVPUIFrame = "Blizzard_PVPUI",
    CommunitiesFrame = "Blizzard_Communities",
    GuildFrame = "Blizzard_GuildUI",
    WeeklyRewardsFrame = "Blizzard_WeeklyRewards",
}

-- These frames may retain positions, but their visibility depends on an NPC,
-- unit, mailbox, taxi node, bank, or another interaction that does not survive
-- reload. Loading only their shell would create a broken or misleading UI.
local contextBoundPanelNames = {
    AuctionHouseFrame = true,
    BankFrame = true,
    BlackMarketFrame = true,
    ClassTrainerFrame = true,
    FlightMapFrame = true,
    GuildBankFrame = true,
    GuildControlUI = true,
    GuildRegistrarFrame = true,
    InspectFrame = true,
    ItemInteractionFrame = true,
    ItemSocketingFrame = true,
    ItemUpgradeFrame = true,
    MailFrame = true,
    MerchantFrame = true,
    OpenMailFrame = true,
    ScrappingMachineFrame = true,
    StableFrame = true,
    TabardFrame = true,
    TradeFrame = true,
    TransmogFrame = true,
}

function PanelRegistry.IsBlizzardLoadAddonName(name)
    return type(name) == "string" and name:match("^Blizzard_[%w_]+$") ~= nil
end

function PanelRegistry.IsBasePersistentCandidate(name)
    return type(name) == "string" and name:match("^[%w_]+$") ~= nil
        and not contextBoundPanelNames[name]
end

function PanelRegistry.IsContextBoundPanel(name)
    return contextBoundPanelNames[name] == true
end

function PanelRegistry.InitializeTracking(owner)
    if owner.knownUIPanelNames then return end
    owner.knownUIPanelNames = {}
    owner.panelsRegisteredSinceAddonEvent = {}
    owner.panelLoadRequests = {}
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do owner.knownUIPanelNames[name] = true end
    end
end

function PanelRegistry.RecordLoadedPanelAddon(owner, addonName, isCandidate)
    PanelRegistry.InitializeTracking(owner)
    local canRemember = PanelRegistry.IsBlizzardLoadAddonName(addonName)
    Offhand.db.workspacePanelLoadAddons = Offhand.db.workspacePanelLoadAddons or {}
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            local newlySeen = not owner.knownUIPanelNames[name]
                or owner.panelsRegisteredSinceAddonEvent[name]
            if canRemember and newlySeen and isCandidate(name) then
                Offhand.db.workspacePanelLoadAddons[name] = addonName
            end
            owner.knownUIPanelNames[name] = true
        end
    end
    owner.panelsRegisteredSinceAddonEvent = {}
end

function PanelRegistry.IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok then return loaded == true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok then return loaded == true end
    end
    return false
end

function PanelRegistry.LoadAddon(addonName)
    if C_AddOns and C_AddOns.LoadAddOn then
        return pcall(C_AddOns.LoadAddOn, addonName)
    elseif LoadAddOn then
        return pcall(LoadAddOn, addonName)
    end
    return false, "api_unavailable"
end

function PanelRegistry.GetPersistentPanelAddon(name)
    local learned = Offhand.db and Offhand.db.workspacePanelLoadAddons
    local addonName = type(learned) == "table" and learned[name] or nil
    if PanelRegistry.IsBlizzardLoadAddonName(addonName) then
        return addonName, "learned"
    end
    addonName = knownPanelLoadAddons[name]
    if PanelRegistry.IsBlizzardLoadAddonName(addonName) then
        return addonName, "known"
    end
    return nil, "unknown"
end

function PanelRegistry.GetDiagnostics(owner)
    local learnedCount = 0
    local learned = Offhand.db and Offhand.db.workspacePanelLoadAddons
    if type(learned) == "table" then
        for _, addonName in pairs(learned) do
            if PanelRegistry.IsBlizzardLoadAddonName(addonName) then
                learnedCount = learnedCount + 1
            end
        end
    end
    local requests = {}
    for name, status in pairs(owner.panelLoadRequests or {}) do
        requests[#requests + 1] = name .. "=" .. status
    end
    table.sort(requests)
    return string.format("Learned=%d | Requests=%s", learnedCount,
        #requests > 0 and table.concat(requests, ",") or "none")
end
