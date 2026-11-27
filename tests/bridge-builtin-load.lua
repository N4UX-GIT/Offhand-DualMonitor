-- Every default-anchor bridge listed in the manifests, loaded together in manifest
-- order: inert on a client with none of their addons, inert off Forever, and all
-- registered and refreshing without error when every addon is present.
local Client = dofile("tests/support/bridge-client.lua")

local TARGETS = { "Beastfinder", "EasyFishing", "ForeverLedger", "Gathercraft", "MobInfo2", "Questie", "RareScanner" }

-- The bridge files of the generic manifest, in order, without the DaylightUI
-- block (it has its own suites and needs its own mock).
local files = {}
for line in io.lines("Offhand.toc") do
    local file = line:match("^%s*(Bridges\\.-%.lua)%s*$")
    if file and not file:find("DaylightUI", 1, true) then files[#files + 1] = (file:gsub("\\", "/")) end
end
assert(files[1] == "Bridges/Shared/DefaultAnchors.lua", "the shared helper must be the first bridge file")
for _, target in ipairs(TARGETS) do
    local listed = false
    for _, file in ipairs(files) do
        if file == "Bridges/" .. target .. "/Bridge.lua" then listed = true end
    end
    assert(listed, "manifest is missing the " .. target .. " bridge")
end

-- Former core modules that keep an event frame from file load on every
-- client, so an addon loading after Offhand is still handled. Their own
-- suites cover them; here they are only scanned for forbidden strings.
local OWN_EVENT_FRAME = { ["Bridges/ProcDoc/Bridge.lua"] = true }

local function LoadAll()
    Client.LoadOffhand()                       -- loads the shared helper itself
    for index = 2, #files do
        Client.ForbiddenStrings(files[index])
        if not OWN_EVENT_FRAME[files[index]] then Client.Load(files[index]) end
    end
end

local function Registered()
    local set = {}
    for _, id in ipairs(Client.addon.Bridges:List()) do set[id] = true end
    return set
end

-- No target addon loaded: nothing is created and no default-anchor bridge registers.
Client.Reset()
LoadAll()
local frames, timers, tickers, slashes = Client.Counts()
assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
    "bridges must create nothing when their addons are not loaded")
for _, target in ipairs(TARGETS) do
    assert(not Registered()[target], target .. " bridge must not register without its addon")
end
Client.Tick()
assert(next(Client.Errors()) == nil, "an empty client must refresh without bridge errors")

-- Every target addon loaded, but not the Forever client: still nothing.
local loaded = {}
for _, target in ipairs(TARGETS) do loaded[target] = true end
Client.Reset({ loaded = loaded, toc = 120107 })
LoadAll()
frames, timers, tickers, slashes = Client.Counts()
assert(frames == 0 and timers == 0 and tickers == 0 and slashes == 0,
    "bridges must create nothing off the Forever client")
for _, target in ipairs(TARGETS) do
    assert(not Registered()[target], target .. " bridge must not register off the Forever client")
end

-- Every target addon loaded on Forever: all register, and every refresh reason
-- core uses runs clean even though none of the addons' frames exist yet.
Client.Reset({ loaded = loaded })
LoadAll()
for _, target in ipairs(TARGETS) do
    assert(Registered()[target], target .. " bridge must register when its addon is loaded")
    assert(Client.addon.Bridges:Get(target).catalog == nil,
        target .. " bridge must not change the learned-window catalog")
end
-- Each bridge declares the frames it places itself (data.placedFrames), so the seam scan
-- reports them as handled by that bridge.
local DECLARED = {
    Beastfinder = { "BeastfinderNewBeastCard" },
    EasyFishing = { "EasyFishingSessionWindow", "EasyFishingButton", "EasyFishingIndicator", "EasyFishingLureBadge",
        "EasyFishingGlow", "EasyFishingSettings", "EasyFishingDebugConsole" },
    ForeverLedger = { "ForeverLedgerCustomers", "ForeverLedgerDisenchant", "ForeverLedgerSessionTracker",
        "ForeverLedgerSidePanel" },
    Gathercraft = { "GathercraftRunSummary", "GathercraftSkillPlan", "GathercraftWelcome", "GathercraftWhatsNew",
        "GathercraftPlanHint", "GathercraftPlanGathered", "GathercraftPlanZones", "GathercraftPanel",
        "GathercraftArrow", "GathercraftMain", "OffhandGathercraftPins" },
    MobInfo2 = { "MI2_TooltipAnchor" },
    Questie = { "QuestieTutorialChooseObjectiveType", "QuestieProfilerIndicator", "OffhandQuestieIcons",
        "QuestieTraceConsentFrame", "QuestieFrame12" },
    RareScanner = { "RARESCANNER_BUTTON", "RSExplorerFrame", "LibDialog-1.0RS_Dialog1", "LibDialog-1.0RS_Dialog2",
        "LibDialog-1.0RS_Dialog3", "LibDialog-1.0RS_Dialog4" },
}
for _, target in ipairs(TARGETS) do
    for _, name in ipairs(DECLARED[target]) do
        assert(Client.addon.Bridges:GetPlacedFrameOwner(name) == target, target .. " bridge must declare " .. name)
    end
    assert(Client.addon.Bridges:GetAddonBridge(target:lower()) == target, target .. " bridge must be found by its folder")
end
for _, reason in ipairs({ "tick", "layout", "map", "persistence", "something-new" }) do Client.Tick(reason) end
Client.Geometry()
Client.RunTimers()
Client.combat = true
Client.Tick()
Client.combat = false
Client.spanned = false
Client.Tick()
Client.Geometry()
assert(next(Client.Errors()) == nil, "bridges must tolerate every refresh reason, combat and an unspanned layout")
local diagnostics = Client.Diagnostics()
for _, target in ipairs(TARGETS) do
    assert(type(diagnostics) == "string" and diagnostics:find(target .. "Anchors=0/", 1, true),
        target .. " bridge must report its anchors in diagnostics")
end
_, _, _, slashes = Client.Counts()
assert(slashes == 0, "bridges must not add slash commands")

print("PASS: built-in default-anchor bridges load inert, register together and refresh cleanly")
