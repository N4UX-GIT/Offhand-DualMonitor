-- Bridge registry contract, public bridge services, storage helpers, and core purity.
local width, height = 3840, 1080
UIParent = {GetWidth = function() return width end, GetHeight = function() return height end}
WorldMapFrame = nil

local function Load()
    local addon = {AddonWindowCatalog = {}}
    assert(loadfile("Core/Bridges.lua"))("Offhand", addon)
    return addon, addon.Bridges
end

-- Registration
local addon, Bridges = Load()
assert(addon.API.BRIDGE_CONTRACT == 1 and Bridges.CONTRACT == 1, "the bridge contract version must be 1")
local function Fails(reason, ...)
    local ok, why = Bridges:Register(...)
    assert(ok == false and why == reason, "registration must fail with " .. reason)
end
Fails("id", nil, {contract = 1})
Fails("id", "", {contract = 1})
Fails("id", 7, {contract = 1})
Fails("bridge", "Alpha", "not a table")
Fails("contract", "Alpha", {})
Fails("contract", "Alpha", {contract = 2})
local alpha, beta = {contract = 1}, {contract = 1}
assert(Bridges:Register("Alpha", alpha) == true and alpha.id == "Alpha", "a valid bridge must register")
Fails("duplicate", "Alpha", {contract = 1})
assert(Bridges:Register("Alpha", alpha) == true, "re-registering the same table must succeed")
assert(addon.API.RegisterBridge("Beta", beta) == true, "Offhand.API.RegisterBridge must register")
assert(Bridges:Get("Alpha") == alpha and Bridges:Get("Beta") == beta and Bridges:Get("Gamma") == nil,
    "Get must return the registered table")
local ids = Bridges:List()
assert(#ids == 2 and ids[1] == "Alpha" and ids[2] == "Beta", "List must keep registration order once per id")
ids[1] = "changed"
assert(Bridges:List()[1] == "Alpha", "List must return a copy")

-- Built-in bridge namespace and account-wide OffhandDB.bridges storage
local nsA = addon.API.GetBridgeNamespace("Alpha")
assert(nsA == addon.API.GetBridgeNamespace("Alpha") and nsA ~= addon.API.GetBridgeNamespace("Beta"),
    "GetBridgeNamespace must return a stable isolated table per bridge id")
_G.OffhandDB = nil
local preStorage = addon.API.GetBridgeStorage("Alpha")
preStorage.rect = "early"
_G.OffhandDB = {profiles = {}}
local storage = addon.API.GetBridgeStorage("Alpha")
assert(storage == _G.OffhandDB.bridges.Alpha and storage.rect == "early",
    "GetBridgeStorage must attach under OffhandDB.bridges[id] without losing pre-init state")
local flushed = 0
addon.ForeverPersistence = {SaveProfileSnapshot = function(_, inc) if inc then flushed = flushed + 1 end end}
addon.API.FlushBridgeStorage()
assert(flushed == 1, "FlushBridgeStorage must persist Forever snapshot when available")
_G.OffhandDB = nil

-- Catalog auto-registration, IsEditModeActive, and CanLearnPlacement
addon, Bridges = Load()
local editing = false
local sampleFrame = {}
local gamma = {
    contract = 1,
    catalog = {
        suitePrefix = "gamma_",
        settings = {position = "addon", close = "native", learnPlacementFile = "options/panel.lua"},
    },
    IsEditModeActive = function() return editing end,
    IdentifyLearnPlacement = function(_, frame, name, file)
        if frame == sampleFrame and name == "GammaOptions" and file == "options/panel.lua" then
            return "settings"
        end
    end,
}
assert(Bridges:Register("Gamma", gamma) == true)
assert(addon.AddonWindowCatalog.Gamma == gamma.catalog, "bridge catalog must register into AddonWindowCatalog")
assert(Bridges:IsEditModeActive() == false)
editing = true
assert(Bridges:IsEditModeActive() == true, "IsEditModeActive must reflect active bridge edit mode")
editing = false
assert(Bridges:CanLearnPlacement(sampleFrame, "GammaOptions", "Gamma", "options/panel.lua") == true,
    "CanLearnPlacement must accept matching bridge role and file")
assert(Bridges:CanLearnPlacement(sampleFrame, "GammaHUD", "Gamma", "hud.lua") == false,
    "CanLearnPlacement must reject non-matching bridge frames")

-- Dispatch
addon, Bridges = Load()
local calls = {}
local first = {contract = 1, mapAddons = {"MapA", "Shared"}}
function first:Refresh(reason) calls[#calls + 1] = {"first", self, reason} end
function first:RefreshBags(services) calls[#calls + 1] = {"firstBags", self, services} end
local second = {contract = 1, mapAddons = {"Shared", "MapB", "", 5}}
function second:Refresh(reason) calls[#calls + 1] = {"second", self, reason} end
assert(Bridges:Register("First", first) and Bridges:Register("Second", second))
Bridges:Refresh("tick")
assert(#calls == 2 and calls[1][1] == "first" and calls[1][2] == first and calls[1][3] == "tick"
    and calls[2][1] == "second" and calls[2][2] == second and calls[2][3] == "tick",
    "Refresh must pass self and the reason to every bridge in order")
local services = {}
calls = {}
Bridges:RefreshBags(services)
assert(#calls == 1 and calls[1][2] == first and calls[1][3] == services,
    "RefreshBags must pass the services and skip bridges without the method")
assert(Bridges:GetDiagnostics() == nil, "diagnostics must be nil when no bridge reports")
function first:GetDiagnostics() return "First=on" end
function second:GetDiagnostics() return "" end
assert(Bridges:GetDiagnostics() == "First=on", "empty diagnostics must be skipped")
function second:GetDiagnostics() return "Second=off" end
assert(Bridges:GetDiagnostics() == "First=on | Second=off", "diagnostics must join with ' | '")
local frameA, frameB, metricsArg = {}, {}, {isSpanned = false}
assert(Bridges:ShouldPreserveSingleScreenPosition(frameA, metricsArg) == false, "no bridge must mean no preserve")
function first:ShouldPreserveSingleScreenPosition() return 1 end
function second:ShouldPreserveSingleScreenPosition() return "yes" end
assert(Bridges:ShouldPreserveSingleScreenPosition(frameA, metricsArg) == false, "only a literal true may preserve")
local seenFrame, seenMetrics
function second:ShouldPreserveSingleScreenPosition(frame, metrics)
    seenFrame, seenMetrics = frame, metrics
    return frame == frameA
end
assert(Bridges:ShouldPreserveSingleScreenPosition(frameA, metricsArg) == true
    and seenFrame == frameA and seenMetrics == metricsArg, "a literal true must preserve")
assert(Bridges:ShouldPreserveSingleScreenPosition(frameB, metricsArg) == false, "other frames must not be preserved")
assert(Bridges:IsBagOnWorkspace(function() return true end) == false, "no bag frames must mean not on workspace")
assert(Bridges:IsBagOnWorkspace(nil) == false and Bridges:IsBagOnWorkspace("x") == false,
    "a non-function workspace test must be rejected")
function first:GetBagFrames() return {nil, frameB} end
function second:GetBagFrames() return "not a table" end
local tested = {}
local function OnWorkspace(frame) tested[#tested + 1] = frame; return frame == frameA end
assert(Bridges:IsBagOnWorkspace(OnWorkspace) == false and #tested == 1 and tested[1] == frameB,
    "nil holes and non-table results must be tolerated")
function second:GetBagFrames() return {frameA} end
assert(Bridges:IsBagOnWorkspace(OnWorkspace) == true, "a bridge's bag on the workspace must be reported")
local hasBag, bagOwner = Bridges:HasCustomBag()
assert(hasBag == true and bagOwner == "First", "HasCustomBag must report registered bridge bag frames")
local names = Bridges:GetMapAddons()
assert(#names == 3 and names[1] == "MapA" and names[2] == "Shared" and names[3] == "MapB",
    "map addon names must be deduplicated in order")

-- Isolation
addon, Bridges = Load()
local reached = {}
local broken = {contract = 1}
function broken:Refresh() error("boom") end
function broken:GetDiagnostics() error("boom") end
function broken:ShouldPreserveSingleScreenPosition() error("boom") end
function broken:GetBagFrames() error("boom") end
function broken:IsEditModeActive() error("boom") end
local healthy = {contract = 1}
function healthy:Refresh(reason) reached.refresh = reason end
function healthy:GetDiagnostics() return "Healthy=ok" end
function healthy:ShouldPreserveSingleScreenPosition() return true end
function healthy:GetBagFrames() return {frameA} end
function healthy:IsEditModeActive() return true end
assert(Bridges:Register("Broken", broken) and Bridges:Register("Healthy", healthy))
assert(Bridges:GetDiagnostics() == "Bridge:Broken=error | Healthy=ok",
    "a failing bridge must be reported and must not stop later bridges")
Bridges:Refresh("layout")
assert(reached.refresh == "layout", "a throwing bridge must not stop later refreshes")
assert(Bridges:ShouldPreserveSingleScreenPosition(frameA, metricsArg) == true, "later bridges must still be asked")
assert(Bridges:IsBagOnWorkspace(function(frame) return frame == frameA end) == true,
    "later bridges must still name their bags")
assert(Bridges:IsEditModeActive() == true, "later bridges must still report edit mode state")
assert(Bridges:Get("Broken") == broken and #Bridges:List() == 2, "a failing bridge must stay registered")
assert(Bridges.errors.Broken and Bridges.errors.Broken:find("boom", 1, true), "the latest error must be kept")
assert(Bridges:GetDiagnostics():find("Bridge:Broken=error", 1, true), "diagnostics must show the failing bridge")

-- GetGameRect
addon = Load()
local rect = addon.API.GetGameRect()
assert(rect.left == 0 and rect.bottom == 0 and rect.right == width and rect.top == height
    and rect.width == width and rect.height == height and rect.screenWidth == width
    and rect.screenHeight == height and rect.isSpanned == false, "without geometry the rect must be the screen")
local liveRect = {left = 0, bottom = 0, right = 1920, top = 1080, width = 1920, height = 1080,
    screenWidth = 3840, screenHeight = 1080, isSpanned = true}
addon.MainhandGeometry = {GetCurrentRect = function() return liveRect end}
assert(addon.API.GetGameRect() == liveRect, "the current Mainhand rect must be returned")
addon.MainhandGeometry = {GetCurrentRect = function() error("not ready") end}
assert(addon.API.GetGameRect().right == width, "a failing geometry must fall back to the screen")

-- IsPointVisible (L-shaped and multi-workspace void detection)
addon = Load()
addon.MainhandGeometry = {GetCurrentRect = function()
    return {left = 1440, bottom = 6, right = 4000, top = 1446, width = 2560, height = 1440,
        screenWidth = 4000, screenHeight = 2560, isSpanned = true}
end}
addon.Viewport = {GetMetrics = function()
    return {isSpanned = true, workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1440, workspaceTop = 2560}
end}
assert(addon.API.IsPointVisible(2720, 726) == true, "Mainhand point must be visible")
assert(addon.API.IsPointVisible(720, 2000) == true, "Offhand workspace point must be visible")
assert(addon.API.IsPointVisible(2000, 2544) == false, "L-shaped void above Mainhand must not be visible")
assert(addon.API.IsPointVisible("bad", 10) == false and addon.API.IsPointVisible(0 / 0, 10) == false)
addon.Viewport = {GetMetrics = function()
    return {isSpanned = true, workspaceRegions = {{x = 1280, y = 1440, width = 2560, height = 1440}}}
end}
assert(addon.API.IsPointVisible(2560, 2000) == true, "point inside workspaceRegions must be visible")
assert(addon.API.IsPointVisible(100, 2000) == false, "T-shaped top-left void must not be visible")

-- OwnsWorldMapPlacement
local state
local function Reset()
    state = {enabled = true, map = true, big = false, manage = true, external = nil,
        workspace = {x = 1, y = 2}, main = nil, spanned = true}
end
local map = {}
function map:GetScale() return 1 end
function map:IsForbidden() return false end
function map:IsMaximized() return state.big end
addon = Load()
addon.Canvas = {CanManagePanelsFromAddon = function() return state.manage end}
addon.CanvasCompatibility = {GetWorldMapExternalOwner = function() return state.external end}
addon.CanvasPersistence = {IsPosition = function(p)
    return type(p) == "table" and tonumber(p.x) ~= nil and tonumber(p.y) ~= nil
end}
addon.Viewport = {GetMetrics = function() return {isSpanned = state.spanned, hudScale = 2} end}
local function Owns()
    addon.db = {enabled = state.enabled, savedWorkspacePositions = {WorldMapFrame = state.workspace},
        savedMainPositions = {WorldMapFrame = state.main}}
    WorldMapFrame = state.map and map or nil
    return addon.API.OwnsWorldMapPlacement()
end
Reset(); assert(Owns() == true, "Offhand must own a spanned, saved, unclaimed compact map")
Reset(); state.enabled = false; assert(Owns() == false, "disabled Offhand must not own the map")
Reset(); state.map = false; assert(Owns() == false, "a missing map must not be owned")
Reset(); state.big = true; assert(Owns() == false, "a maximized map must not be owned")
Reset(); state.manage = false; assert(Owns() == false, "panels that cannot be managed must not be owned")
Reset(); state.external = "OpenMap"; assert(Owns() == false, "an external map owner must win")
Reset(); state.workspace = nil; assert(Owns() == false, "a map without a saved position must not be owned")
Reset(); state.workspace = nil; state.main = {x = 5, y = 6}
assert(Owns() == true, "a saved Mainhand position alone must be enough")
Reset(); state.spanned = false; assert(Owns() == false, "an unspanned layout must not own the map")
addon.db = nil; WorldMapFrame = map
assert(addon.API.OwnsWorldMapPlacement() == false, "missing settings must not own the map")
WorldMapFrame = nil

-- GetGroupLootSpot
addon = Load()
assert(addon.API.GetGroupLootSpot() == nil, "the whole screen must have no group loot spot")
addon.MainhandGeometry = {GetCurrentRect = function()
    return {left = 1920, bottom = 0, right = 3840, top = 1080, screenWidth = 3840, screenHeight = 1080}
end}
local x, y = addon.API.GetGroupLootSpot()
assert(x == 2880 and y == 190 + 50, "without settings the spot must be the default centre at HUD scale 1")
addon.db = {groupLootPosition = {x = 0.25, y = 0.5}}
x, y = addon.API.GetGroupLootSpot(40)
assert(x == 1920 + 480 and y == 540, "saved ratios must place the spot inside the game rect")
addon.db = {groupLootPosition = {x = 2, y = 0.5}}
addon.Viewport = {GetMetrics = function() return {hudScale = 2} end}
x, y = addon.API.GetGroupLootSpot()
assert(x == 2880 and y == 380 + 50, "out-of-range ratios must use the default centre scaled by hudScale")
x, y = addon.API.GetGroupLootSpot(200)
assert(y == 380 + 100, "the height argument must centre the slot")

addon.db = {enabled = true, persistentWorkspacePanels = true, restoreWorkspaceOnReload = false}
assert(addon.API.IsEscapeProtectionEnabled() == true,
    "IsEscapeProtectionEnabled must stay true when restoreWorkspaceOnReload is false")
assert(addon.API.IsWorkspacePersistenceEnabled() == false,
    "IsWorkspacePersistenceEnabled must still respect restoreWorkspaceOnReload")
addon.db.persistentWorkspacePanels = false
assert(addon.API.IsEscapeProtectionEnabled() == false,
    "IsEscapeProtectionEnabled must be false when persistentWorkspacePanels is false")
addon.db.persistentWorkspacePanels = true
addon.db.enabled = false
assert(addon.API.IsEscapeProtectionEnabled() == false,
    "IsEscapeProtectionEnabled must be false when Offhand is disabled")

-- GetDebugDiagnostics
addon, Bridges = Load()
assert(#Bridges:GetDebugDiagnostics() == 0, "no bridge must mean no debug reports")
local quiet, chatty, failing, partial = {contract = 1}, {contract = 1}, {contract = 1}, {contract = 1}
function chatty:GetDebugDiagnostics() return "Chatty", "state=ready" end
function failing:GetDebugDiagnostics() error("boom") end
function partial:GetDebugDiagnostics() return "Partial", "" end
assert(Bridges:Register("Quiet", quiet) and Bridges:Register("Failing", failing)
    and Bridges:Register("Partial", partial) and Bridges:Register("Chatty", chatty))
local debugReports = Bridges:GetDebugDiagnostics()
assert(#debugReports == 1 and debugReports[1].label == "Chatty" and debugReports[1].text == "state=ready",
    "debug reports must skip silent, empty and failing bridges")
assert(Bridges.errors.Failing and Bridges.errors.Failing:find("boom", 1, true),
    "a failing debug report must be recorded")
assert(not Bridges:GetDiagnostics():find("Chatty", 1, true), "debug reports must stay out of compact diagnostics")
do
    local lined = {contract = 1}
    function lined:GetDebugDiagnostics() return "Lined", {"first", "", 7, "second"} end
    assert(Bridges:Register("Lined", lined))
    debugReports = Bridges:GetDebugDiagnostics()
    assert(#debugReports == 3 and debugReports[1].label == "Chatty" and debugReports[2].label == "Lined"
        and debugReports[2].text == "first" and debugReports[3].label == "Lined" and debugReports[3].text == "second",
        "an array of debug lines must give one report per non-empty line, in order, under its label")
end

-- GetOwnershipConflicts, GetMoverDiagnostics and RefreshAddonOptions
addon, Bridges = Load()
do
    assert(#Bridges:GetOwnershipConflicts({}) == 0 and #Bridges:GetMoverDiagnostics({}) == 0,
        "no bridge must mean no conflicts and no mover segments")
    local moverA, moverB, refreshed = {contract = 1}, {contract = 1}, {}
    local conflictContext, moverContext
    function moverA:GetOwnershipConflicts(context)
        conflictContext = context
        return {{order = 40, id = "a-late"}, "junk", {order = 20, id = "a-early"}}
    end
    function moverA:GetMoverDiagnostics(context) moverContext = context; return "MoverA=active" end
    function moverA:RefreshAddonOptions(getMetrics) refreshed[#refreshed + 1] = {"A", getMetrics()} end
    function moverB:GetOwnershipConflicts() error("boom") end
    function moverB:GetMoverDiagnostics() return "" end
    function moverB:RefreshAddonOptions(getMetrics) refreshed[#refreshed + 1] = {"B", getMetrics()} end
    assert(Bridges:Register("MoverA", moverA) and Bridges:Register("MoverB", moverB))
    local probeContext = {mapOwner = "Map"}
    local bridgeConflicts = Bridges:GetOwnershipConflicts(probeContext)
    assert(#bridgeConflicts == 2 and bridgeConflicts[1].id == "a-late" and bridgeConflicts[2].id == "a-early"
        and conflictContext == probeContext, "bridge conflicts come back in bridge order with the caller's context")
    assert(Bridges.errors.MoverB and Bridges.errors.MoverB:find("boom", 1, true), "a failing conflict report must be recorded")
    local moverParts = Bridges:GetMoverDiagnostics(probeContext)
    assert(#moverParts == 1 and moverParts[1] == "MoverA=active" and moverContext == probeContext,
        "mover segments must skip empty answers")
    Bridges:RefreshAddonOptions(function() return "metrics" end)
    assert(#refreshed == 2 and refreshed[1][1] == "A" and refreshed[1][2] == "metrics" and refreshed[2][1] == "B",
        "every bridge must get the options metrics getter in registration order")
    addon.PopupBounds = {optionsWindowHelpers = {Fits = function() return true end}}
    assert(addon.API.GetOptionsWindowHelpers().Fits(), "the options window helpers come from PopupBounds")
    addon.PopupBounds = nil
    assert(addon.API.GetOptionsWindowHelpers() == nil, "no PopupBounds must mean no options window helpers")
end

-- IsParkedNativePanel: bridges answer first, then frame rule parkedNativePanel, each with the
-- parking addon's declared reason (else "bridge-parked").
addon, Bridges = Load()
do
    local panel, other = {}, {}
    assert(Bridges:IsParkedNativePanel(panel) == false, "no bridge must mean not parked")
    local parker = {contract = 1}
    function parker:IsParkedNativePanel(frame) return frame == other end
    assert(Bridges:Register("Parker", parker))
    local parked, reason = Bridges:IsParkedNativePanel(other)
    assert(parked == true and reason == "bridge-parked", "a bridge without a declared reason reports bridge-parked")
    ParkedFixture = panel
    addon.isForever = false
    addon.API.RegisterAddonData("Parker", {parkedReason = "parker-parked", frameRules = {parkedNativePanel = {
        {identity = {"ParkedFixture"}, when = {forever = true}, verify = function(frame) return frame.held == true end},
    }}})
    parked, reason = Bridges:IsParkedNativePanel(other)
    assert(parked == true and reason == "parker-parked", "a bridge's answer carries its addon's declared reason")
    panel.held = true
    assert(Bridges:IsParkedNativePanel(panel) == false, "rule parkedNativePanel must respect its detector")
    addon.isForever = true
    parked, reason = Bridges:IsParkedNativePanel(panel)
    assert(parked == true and reason == "parker-parked", "rule parkedNativePanel must park a verified frame")
    panel.held = false
    assert(Bridges:IsParkedNativePanel(panel) == false, "rule parkedNativePanel must ask verify")
    ParkedFixture = nil

    -- The DaylightUI facts register on every client, even with DaylightUI absent when the bridge loads,
    -- and answer for the Spellbook and Trainer panels from DaylightUI's live follower holders.
    local daylight = {AddonWindowCatalog = {}, isForever = true}
    local registry = dofile("tests/support/core-bridges.lua").Load(daylight, {"Bridges/DaylightUI/Init.lua"})
    assert(#registry:List() == 0, "the DaylightUI bridge itself must stay unregistered without DaylightUI")
    local names = table.concat(registry:GetRuleNames("diagnosticFrame"), ",")
    assert(names == "DaylightUIBook,DaylightUINpc", "DaylightUI's windows join the panel placement diagnostics")
    local holder = {}
    local spells = {GetParent = function() return holder end}
    PlayerSpellsFrame, ClassTrainerFrame = spells, nil
    assert(registry:IsParkedNativePanel(spells) == false, "no DaylightUI must mean not parked")
    DaylightUI = {Win = {Followers = {aside = {}, hidden = {}, veil = holder}}}
    parked, reason = registry:IsParkedNativePanel(spells)
    assert(parked == true and reason == "daylight-parked", "a Spellbook under a DaylightUI holder reports daylight-parked")
    assert(registry:IsParkedNativePanel({GetParent = function() return holder end}) == false,
        "only the Spellbook and Trainer panels count")
    daylight.isForever = false
    assert(registry:IsParkedNativePanel(spells) == false, "the DaylightUI parked check is Forever only")
    PlayerSpellsFrame, DaylightUI = nil, nil
end

-- Core sorts bridge conflicts around its own by order: map owner contract 10,
-- bag addons 30. The context carries the map owner facts and the bag owners.
do
    local savedAddOns = C_AddOns
    C_AddOns = {IsAddOnLoaded = function() return false end}
    local compatAddon = {AddonWindowCatalog = {}, isForever = true}
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", compatAddon)
    local registry = dofile("tests/support/core-bridges.lua").Load(compatAddon)
    local compat = compatAddon.CanvasCompatibility
    local synced = false
    compatAddon.API.RegisterAddonData("TestMap", {ownership = {
        {role = "map.owner", name = "TestMap", order = 1, positionsMap = true, label = "Test Map"},
        {role = "report.bags", name = "BagOne", order = 1}, {role = "report.bags", name = "BagTwo", order = 2},
    }})
    assert(registry:Register("TestMap", {contract = 1, mapProvider = {owner = "TestMap",
        GetContractConflict = function() return {id = "contract"} end,
        SyncsWorldMapMover = function() return synced end}}))
    local seen = {}
    local window = {contract = 1}
    function window:GetOwnershipConflicts(context)
        seen.conflicts = context
        return {{order = 40, id = "mover-late"}, {order = 20, id = "mover-early"}}
    end
    function window:GetMoverDiagnostics(context)
        seen.diagnostics = context
        return "Mover=" .. (context.SyncsWorldMapMover() and "synced" or "conflict")
    end
    assert(registry:Register("Window", window))
    local ids = {}
    for _, conflict in ipairs(compat.GetOwnershipConflicts()) do ids[#ids + 1] = conflict.id end
    assert(table.concat(ids, ",") == "contract,mover-early,bags-conflict:BagOne+BagTwo,mover-late",
        "conflicts must be ordered contract 10, bridge 20, bags 30, bridge 40")
    local context = seen.conflicts
    assert(context.mapOwner == "TestMap" and context.mapLabel == "Test Map" and context.positionsMap == true
        and table.concat(context.bagOwners, ",") == "BagOne,BagTwo" and context.SyncsWorldMapMover() == false,
        "the conflict context must carry the map owner facts and bag owners")
    synced = true
    assert(context.SyncsWorldMapMover() == true, "the conflict context must ask the map owner's provider")
    compatAddon.isForever = false
    assert(context.SyncsWorldMapMover() ~= true, "off Forever a map owner never syncs a mover for conflicts")
    assert(compat.GetDiagnostics(false):find(" | Mover=synced", 1, true)
        and seen.diagnostics.mapOwner == "TestMap" and seen.diagnostics.positionsMap == true,
        "mover diagnostics must be appended with the map owner facts, on every client")
    C_AddOns = savedAddOns
end

-- IsExternallyOwnedFrame
addon, Bridges = Load()
local owned = {}
assert(Bridges:IsExternallyOwnedFrame(owned, "Owned") == false, "no bridge must mean not externally owned")
local throwing = {contract = 1}
function throwing:IsExternallyOwnedFrame() error("boom") end
local truthy = {contract = 1}
function truthy:IsExternallyOwnedFrame() return 1 end
assert(Bridges:Register("Throwing", throwing) and Bridges:Register("Truthy", truthy))
assert(Bridges:IsExternallyOwnedFrame(owned, "Owned") == false, "only a literal true may claim a frame")
assert(Bridges.errors.Throwing and Bridges.errors.Throwing:find("boom", 1, true),
    "a throwing ownership check must be recorded")
local owner = {contract = 1}
local ownerFrame, ownerName
function owner:IsExternallyOwnedFrame(frame, name)
    ownerFrame, ownerName = frame, name
    return true
end
assert(Bridges:Register("Owner", owner))
assert(Bridges:IsExternallyOwnedFrame(nil, "Owned") == false and ownerFrame == nil,
    "a nil frame must never be externally owned")
assert(Bridges:IsExternallyOwnedFrame(owned, "Owned") == true and ownerFrame == owned and ownerName == "Owned",
    "a literal true after a throwing bridge must claim the frame and receive frame and name")

-- RefreshTransientFrames
addon, Bridges = Load()
local phases = {}
local plain = {contract = 1}
local failing = {contract = 1}
function failing:RefreshTransientFrames(phase) phases[#phases + 1] = "failing:" .. phase; error("boom") end
local later = {contract = 1}
function later:RefreshTransientFrames(phase) phases[#phases + 1] = "later:" .. phase end
assert(Bridges:Register("Plain", plain) and Bridges:Register("Failing", failing) and Bridges:Register("Later", later))
Bridges:RefreshTransientFrames("hook")
Bridges:RefreshTransientFrames("position")
assert(#phases == 4 and phases[1] == "failing:hook" and phases[2] == "later:hook"
    and phases[3] == "failing:position" and phases[4] == "later:position",
    "transient phases must reach every bridge with the method in order despite a throwing bridge")
assert(Bridges.errors.Failing and Bridges.errors.Failing:find("boom", 1, true),
    "a throwing transient refresh must be recorded")

-- IsPopupRedirectEnabled
addon = Load()
addon.db = nil
assert(addon.API.IsPopupRedirectEnabled() == false, "missing settings must not redirect popups")
addon.db = {enabled = false, seamRedirect = true}
assert(addon.API.IsPopupRedirectEnabled() == false, "disabled Offhand must not redirect popups")
addon.db = {enabled = true, seamRedirect = false}
assert(addon.API.IsPopupRedirectEnabled() == false, "popup redirection off must not redirect popups")
addon.db = {enabled = true}
assert(addon.API.IsPopupRedirectEnabled() == false, "an unset popup redirection must not redirect popups")
addon.db = {enabled = true, seamRedirect = true}
assert(addon.API.IsPopupRedirectEnabled() == true, "enabled popup redirection must return a literal true")

-- GetMainhandPixelHeightRatio
addon = Load()
assert(addon.API.GetMainhandPixelHeightRatio() == 1, "a missing viewport must give ratio 1")
local viewportMetrics = {isSpanned = false, physicalHeight = 2560, gamePixelHeight = 1440}
addon.Viewport = {GetMetrics = function() return viewportMetrics end}
assert(addon.API.GetMainhandPixelHeightRatio() == 1, "an unspanned window must give ratio 1")
viewportMetrics.isSpanned = true
assert(math.abs(addon.API.GetMainhandPixelHeightRatio() - 0.5625) < 1e-9,
    "a spanned window must give game pixel height over physical height")
viewportMetrics.gamePixelHeight = 0
assert(addon.API.GetMainhandPixelHeightRatio() == 1, "an empty game height must give ratio 1")
addon.Viewport = {GetMetrics = function() error("metrics boom") end}
assert(addon.API.GetMainhandPixelHeightRatio() == 1, "a throwing viewport must give ratio 1")

-- QueuePopupBounds
addon = Load()
local queuedFrame = {}
assert(addon.API.QueuePopupBounds(queuedFrame) == false, "missing popup bounds must not queue")
local queued = {}
addon.PopupBounds = {Queue = function(self, frame) queued[#queued + 1] = frame end}
assert(addon.API.QueuePopupBounds(nil) == false and #queued == 0, "a missing frame must not queue")
assert(addon.API.QueuePopupBounds(queuedFrame) == true and queued[1] == queuedFrame,
    "QueuePopupBounds must hand the frame to the popup bounds pass")
addon.PopupBounds = {Queue = function() error("queue boom") end}
assert(addon.API.QueuePopupBounds(queuedFrame) == false, "a throwing popup bounds pass must not escape")

-- RegisterAddonData, bridge.data and catalogs
local loadedAddons = {}
C_AddOns = {IsAddOnLoaded = function(name) return loadedAddons[name] == true end}
addon, Bridges = Load()
local function Rejects(reason, ...)
    local ok, why = addon.API.RegisterAddonData(...)
    assert(ok == false and why == reason, "addon data must be rejected with " .. reason)
end
Rejects("id", nil, {})
Rejects("id", "", {})
Rejects("data", "Facts", "not a table")
local factCatalog, dataCatalog = {settings = {position = "addon"}}, {main = {position = "addon"}}
assert(addon.API.RegisterAddonData("Facts", {catalogs = {FactsFolder = factCatalog, [""] = {}, Other = "x"}}) == true,
    "valid addon data must register")
assert(addon.AddonWindowCatalog.FactsFolder == factCatalog and addon.AddonWindowCatalog[""] == nil
    and addon.AddonWindowCatalog.Other == nil, "data catalogs must merge into AddonWindowCatalog by folder")
assert(#Bridges:List() == 0 and Bridges:Get("Facts") == nil, "addon data must not create a bridge")
local carrier = {contract = 1, data = {catalogs = {CarrierSuite = dataCatalog},
    ownership = {{role = "test.repeat", name = "Carrier"}}}}
assert(Bridges:Register("Carrier", carrier) == true and addon.AddonWindowCatalog.CarrierSuite == dataCatalog,
    "Register must merge bridge.data catalogs")
assert(Bridges:Register("Carrier", carrier) == true and #Bridges:GetRoleOwners("test.repeat") == 1,
    "re-registering a bridge must not merge its data twice")

-- Ownership roles: order sorting, first wins and detectors
addon, Bridges = Load()
loadedAddons = {}
addon.API.RegisterAddonData("Late", {ownership = {
    {role = "test.owner", name = "Third", order = 30},
    {role = "test.owner", name = "Unordered"},
    {role = "test.owner", name = "FirstTie", order = 10},
}})
addon.API.RegisterAddonData("Early", {ownership = {
    {role = "test.owner", name = "SecondTie", order = 10},
    {role = "test.owner", name = "Lowest", order = 5, detect = {loaded = "LowestAddon"}},
    {role = "", name = "Invalid"}, {role = "test.owner"}, "junk",
}})
local ownerNames, ownerEntries = Bridges:GetRoleOwners("test.owner")
assert(table.concat(ownerNames, ",") == "FirstTie,SecondTie,Third,Unordered" and #ownerEntries == 4
    and ownerEntries[1].name == "FirstTie", "owners must sort by order, then registration, unordered last")
assert(Bridges:FirstRoleOwner("test.owner") == "FirstTie", "the first present owner must win")
loadedAddons.LowestAddon = true
local firstName, firstEntry = Bridges:FirstRoleOwner("test.owner")
assert(firstName == "Lowest" and firstEntry.order == 5, "a detected lower order must win and return its entry")
assert(Bridges:HasRole("test.owner") == true and Bridges:HasRole("test.none") == false
    and Bridges:FirstRoleOwner("test.none") == nil and #Bridges:GetRoleOwners("test.none") == 0,
    "unknown roles must have no owner")
local activeCalls = 0
addon.isForever = false
addon.API.RegisterAddonData("Detectors", {ownership = {
    {role = "d.loaded", name = "L", detect = {loaded = "LoadedAddon"}},
    {role = "d.global", name = "G", detect = {global = "DetectorGlobal"}},
    {role = "d.present", name = "P", detect = {present = "PresentAddon"}},
    {role = "d.any", name = "A", detect = {anyOf = {{global = "AnyOne"}, {loaded = "AnyTwo"}}}},
    {role = "d.forever", name = "F", detect = {forever = true}},
    {role = "d.active", name = "Act", detect = {global = "ActiveGlobal",
        active = function() activeCalls = activeCalls + 1; return activeCalls end}},
    {role = "d.throw", name = "T", detect = {active = function() error("detector boom") end}},
}})
for _, role in ipairs({"d.loaded", "d.global", "d.present", "d.any", "d.forever", "d.active"}) do
    assert(Bridges:HasRole(role) == false, role .. " must be absent before its addon appears")
end
assert(activeCalls == 0, "active must not run before the declarative detector passed")
loadedAddons.LoadedAddon = true
_G.DetectorGlobal = {}
_G.PresentAddon = {}
loadedAddons.AnyTwo = true
addon.isForever = true
_G.ActiveGlobal = true
assert(Bridges:HasRole("d.loaded") and Bridges:HasRole("d.global") and Bridges:HasRole("d.present")
    and Bridges:HasRole("d.any") and Bridges:HasRole("d.forever"), "each detector field must detect its addon")
_G.PresentAddon = nil
loadedAddons.PresentAddon = true
assert(Bridges:HasRole("d.present") == true, "present must also accept a loaded addon")
assert(Bridges:HasRole("d.active") == false and activeCalls == 1,
    "active must run once the declarative part passed and must return a literal true")
addon.API.RegisterAddonData("Yes", {ownership = {
    {role = "d.yes", name = "Yes", detect = {active = function() return true end}},
}})
assert(Bridges:HasRole("d.yes") == true, "a literal true active must detect")
assert(Bridges:HasRole("d.throw") == false and Bridges.errors.Detectors
    and Bridges.errors.Detectors:find("detector boom", 1, true), "a throwing active must be recorded and fail")
_G.DetectorGlobal, _G.ActiveGlobal = nil, nil

-- Frame rules: every FrameMatcher field, verify only after a hit
addon, Bridges = Load()
loadedAddons = {}
local verified = {}
local plainFrame, patternFrame, identityFrame, widgetFrame = {}, {}, {}, {}
local indexFrame, fieldFrame, trueFrame, childFrame = {}, {moverMark = false}, {flag = true}, {}
_G.IdentityRoot = identityFrame
_G.WidgetHolder = setmetatable({}, {__index = function() return widgetFrame end})
_G.IndexedBar = indexFrame
_G.IndexStore = {IndexedBar = {frame_name = "IndexedBar"}}
function childFrame:GetParent() return UIParent end
addon.API.RegisterAddonData("Rules", {frameRules = {
    test = {
        "PlainName",
        {names = {"ListedName", ""}},
        {patterns = {"^Pattern%d+$"}},
        {identity = {"IdentityRoot"}},
        {widget = {"WidgetHolder", "frame"}},
        {index = {"IndexStore", "frame_name"}},
        {field = "moverMark"},
        {fieldTrue = "flag"},
        {names = {"WhenName"}, when = {loaded = "WhenAddon"}},
        {names = {"ChildRoot"}, parent = "UIParent"},
        {names = {"Checked"}, verify = function(frame, name)
            verified[#verified + 1] = name
            return frame == plainFrame
        end},
        {names = {"Throws"}, verify = function() error("verify boom") end},
    },
}})
assert(Bridges:MatchFrame("test", plainFrame, "PlainName") and Bridges:MatchFrame("test", plainFrame, "ListedName"),
    "plain names and names-only matchers must match by name")
assert(Bridges:MatchFrame("test", patternFrame, "Pattern12") and not Bridges:MatchFrame("test", patternFrame, "Pattern"),
    "patterns must match the name")
assert(Bridges:MatchFrame("test", identityFrame, nil) and not Bridges:MatchFrame("test", {}, "IdentityRoot"),
    "identity must compare the frame with the global")
_G.WidgetHolder = {frame = widgetFrame}
assert(Bridges:MatchFrame("test", widgetFrame, nil), "widget must read the holder's field")
_G.WidgetHolder = setmetatable({}, {__index = function() return widgetFrame end})
assert(not Bridges:MatchFrame("test", widgetFrame, nil), "widget must read the holder's own field only")
assert(Bridges:MatchFrame("test", indexFrame, "IndexedBar") and not Bridges:MatchFrame("test", {}, "IndexedBar"),
    "index must require the global frame and its store entry")
_G.IndexStore.IndexedBar.frame_name = "Other"
assert(not Bridges:MatchFrame("test", indexFrame, "IndexedBar"), "index must require the entry to name the frame")
assert(Bridges:MatchFrame("test", fieldFrame, nil) and not Bridges:MatchFrame("test", {}, nil),
    "field must match any value set on the frame")
assert(Bridges:MatchFrame("test", trueFrame, nil) and not Bridges:MatchFrame("test", {flag = 1}, nil),
    "fieldTrue must require a literal true")
assert(not Bridges:MatchFrame("test", {}, "WhenName"), "when must hold the matcher back while its addon is absent")
loadedAddons.WhenAddon = true
assert(Bridges:MatchFrame("test", {}, "WhenName"), "when must let the matcher through once its addon is present")
assert(Bridges:MatchFrame("test", childFrame, "ChildRoot") and not Bridges:MatchFrame("test", {}, "ChildRoot"),
    "parent must require the named parent frame")
assert(#verified == 0, "verify must not run before a declarative hit")
assert(not Bridges:MatchFrame("test", patternFrame, "Unrelated") and #verified == 0,
    "verify must not run for a frame no selector chose")
assert(Bridges:MatchFrame("test", plainFrame, "Checked") and verified[1] == "Checked",
    "verify must run after a hit and receive frame and name")
assert(not Bridges:MatchFrame("test", patternFrame, "Checked"), "a false verify must reject the frame")
assert(not Bridges:MatchFrame("test", plainFrame, "Throws") and Bridges.errors.Rules
    and Bridges.errors.Rules:find("verify boom", 1, true), "a throwing verify must be recorded and fail")
assert(Bridges:MatchName("test", "PlainName") and Bridges:MatchName("test", "Pattern3")
    and not Bridges:MatchName("test", "ChildRoot") and not Bridges:MatchName("test", "IndexedBar"),
    "MatchName must use names and patterns only")
assert(not Bridges:MatchFrame("missing", plainFrame, "PlainName"), "an unknown rule must not match")
addon.API.RegisterAddonData("MoreRules", {frameRules = {test = {"Later", {names = {"PlainName"}}}}})
assert(table.concat(Bridges:GetRuleNames("test"), ",")
    == "PlainName,ListedName,WhenName,ChildRoot,Checked,Throws,Later",
    "rule names must keep registration order once each")
local ruleNames = Bridges:GetRuleNames("test")
ruleNames[1] = "changed"
assert(Bridges:GetRuleNames("test")[1] == "PlainName" and #Bridges:GetRuleNames("missing") == 0,
    "GetRuleNames must return a copy")
_G.IdentityRoot, _G.WidgetHolder, _G.IndexedBar, _G.IndexStore = nil, nil, nil, nil

-- Mover fields
addon, Bridges = Load()
assert(Bridges.IsExternallyMovable({ofaMovable = true}) == false, "no mover fields must mean not movable")
addon.API.RegisterAddonData("Mover", {moverFields = {movable = {"markMovable"}, moving = {"markMoving"}}})
addon.API.RegisterAddonData("Mover2", {moverFields = {movable = {"markMovable", "otherMovable"}}})
assert(Bridges.IsExternallyMovable({markMovable = true}) and Bridges.IsExternallyMovable({otherMovable = true})
    and not Bridges.IsExternallyMovable({markMovable = 1}) and not Bridges.IsExternallyMovable(nil),
    "a movable field must be a literal true")
assert(Bridges.IsExternallyMoving({markMoving = 1}) and not Bridges.IsExternallyMoving({})
    and not Bridges.IsExternallyMoving(nil), "a moving field must be set")

-- Settings: legacy keys, defaults, stores and character reset keys
addon, Bridges = Load()
addon.API.RegisterAddonData("Setter", {settings = {
    center = {legacyKey = "legacyCenterKey", default = false},
    plain = {default = 3},
    open = {store = "character", legacyKey = "legacyOpenKey", resetOnCharacterChange = true},
    kept = {store = "character"},
}})
assert(addon.API.GetBridgeSetting("Setter", "center") == false, "an unset setting must read its default")
addon.db = {legacyCenterKey = true}
assert(addon.API.GetBridgeSetting("Setter", "center") == true, "a setting must read its legacy key")
assert(addon.API.SetBridgeSetting("Setter", "center", false) == true and addon.db.legacyCenterKey == false
    and addon.API.GetBridgeSetting("Setter", "center") == false, "a setting must write its legacy key")
assert(addon.API.SetBridgeSetting("Setter", "plain", 7) == true and addon.db.plain == 7,
    "a setting without a legacy key must use its own key")
assert(addon.API.GetBridgeSetting("Setter", "open") == nil and addon.API.SetBridgeSetting("Setter", "open", 1) == false
    and addon.API.GetBridgeSetting("Setter", "missing") == nil and addon.API.GetBridgeSetting("Nobody", "center") == nil,
    "undeclared keys and other stores must neither read nor write")
_G.OffhandCharDB = nil
assert(addon.API.SetBridgeCharacterSetting("Setter", "open", true) == false and _G.OffhandCharDB == nil,
    "a character write must not create the character table")
_G.OffhandCharDB = {legacyOpenKey = true}
assert(addon.API.GetBridgeCharacterSetting("Setter", "open") == true, "a character setting must read its legacy key")
assert(addon.API.SetBridgeCharacterSetting("Setter", "kept", "x") == true and _G.OffhandCharDB.kept == "x",
    "a character setting must write its key")
local resetList = Bridges:GetCharacterResetKeys()
assert(#resetList == 1 and resetList[1] == "legacyOpenKey", "only reset-on-change character keys must be listed")
local defaults = Bridges:GetSettingDefaults()
assert(defaults.legacyCenterKey == false and defaults.plain == 3 and defaults.legacyOpenKey == nil,
    "profile defaults must be keyed by their stored key")
addon.db, _G.OffhandCharDB = nil, nil

-- CallMap
addon, Bridges = Load()
assert(Bridges:CallMap("MapOwner", "ReadFade") == nil and Bridges:CallMap(nil, "ReadFade") == nil,
    "no provider must return nothing")
local providerSelf, providerArg
local provider = {owner = "MapOwner"}
function provider:GetScaleState(arg) providerSelf, providerArg = self, arg; return {max = 2, step = 0.1}, "second" end
function provider:Recover() error("map boom") end
local shadow = {owner = "MapOwner"}
function shadow:GetScaleState() return "shadow" end
assert(Bridges:Register("MapBridge", {contract = 1, mapProvider = provider})
    and Bridges:Register("Shadow", {contract = 1, mapProvider = shadow}))
local scaleState, extra = Bridges:CallMap("MapOwner", "GetScaleState", "arg")
assert(type(scaleState) == "table" and scaleState.max == 2 and extra == "second" and providerSelf == provider
    and providerArg == "arg", "CallMap must call the first provider of the owner with self and return its results")
assert(Bridges:CallMap("MapOwner", "Missing") == nil and Bridges:CallMap("Other", "GetScaleState") == nil,
    "a missing method or owner must return nothing")
assert(Bridges:CallMap("MapOwner", "Recover") == nil and Bridges.errors.MapBridge
    and Bridges.errors.MapBridge:find("map boom", 1, true), "a throwing map method must be recorded")

-- GetSettingsContributions
addon, Bridges = Load()
assert(#Bridges:GetSettingsContributions("map") == 0, "no bridge must mean no contributions")
local slotsSeen = {}
local contributorA, contributorB, contributorC = {contract = 1}, {contract = 1}, {contract = 1}
function contributorA:GetSettingsContributions(slot)
    slotsSeen[#slotsSeen + 1] = slot
    return {{id = "a1", order = 20}, {id = "a2"}, {id = ""}, "junk"}
end
function contributorB:GetSettingsContributions() error("options boom") end
function contributorC:GetSettingsContributions() return {{id = "c1", order = 20}, {id = "c2", order = 5}} end
assert(Bridges:Register("ContribA", contributorA) and Bridges:Register("ContribB", contributorB)
    and Bridges:Register("ContribC", contributorC))
local contributionIds = {}
for _, entry in ipairs(Bridges:GetSettingsContributions("alerts")) do contributionIds[#contributionIds + 1] = entry.id end
assert(table.concat(contributionIds, ",") == "c2,a1,c1,a2" and slotsSeen[1] == "alerts",
    "contributions must sort by order, then bridge order, and skip entries without an id")
assert(Bridges.errors.ContribB and Bridges.errors.ContribB:find("options boom", 1, true),
    "a throwing contribution must be recorded")

-- RegisterHUDTransfer
addon = Load()
local transfer = {id = "Suite"}
assert(select(2, addon.API.RegisterHUDTransfer({})) == "provider"
    and select(2, addon.API.RegisterHUDTransfer("x")) == "provider", "a transfer provider needs an id")
assert(addon.API.RegisterHUDTransfer(transfer) == true and addon.HUDTransfer == transfer,
    "a transfer provider must register as Offhand.HUDTransfer")
assert(addon.API.RegisterHUDTransfer(transfer) == true, "re-registering the same provider must succeed")
local ok, why = addon.API.RegisterHUDTransfer({id = "Other"})
assert(ok == false and why == "duplicate" and addon.HUDTransfer == transfer, "a second provider must be refused")

-- RunSlashCommand
addon, Bridges = Load()
local slashArgs = {}
assert(Bridges:RunSlashCommand("recover", "x") == false, "no bridge must leave a command unhandled")
assert(Bridges:Register("SlashA", {contract = 1, slashCommands = {
    recover = function(arg) slashArgs[#slashArgs + 1] = "A:" .. tostring(arg) end,
    broken = function() error("slash boom") end,
}}) and Bridges:Register("SlashB", {contract = 1, slashCommands = {
    recover = function() slashArgs[#slashArgs + 1] = "B" end,
    other = function(arg) slashArgs[#slashArgs + 1] = "B:" .. tostring(arg) end,
}}))
assert(Bridges:RunSlashCommand("recover", "now") == true and Bridges:RunSlashCommand("other", "y") == true
    and table.concat(slashArgs, ",") == "A:now,B:y", "the first bridge naming a command must handle it")
assert(Bridges:RunSlashCommand("unknown") == false and Bridges:RunSlashCommand(nil) == false,
    "unclaimed commands must stay unhandled")
assert(Bridges:RunSlashCommand("broken") == true and Bridges.errors.SlashA
    and Bridges.errors.SlashA:find("slash boom", 1, true), "a throwing command must be handled and recorded")

-- Core state services
addon = Load()
local API = addon.API
assert(API.IsEnabled() == false and API.IsForeverClient() == false and API.IsInputReserved() == false
    and API.IsGamepadUIEnabled() == false and API.IsNativeGamepadInterface() == false
    and API.IsGeometryTransitionActive() == false and API.IsLoggingOut() == false,
    "services must be false before core state exists")
addon.db = {enabled = true}
addon.isForever = true
addon._displayGeometryTransitionActive = true
addon._loggingOut = true
local reserved, gamepad = true, true
function addon:IsBlizzardInputReserved() return reserved end
function addon:IsGamepadUIEnabled() return gamepad end
addon.MainhandCompatibility = {IsNativeGamepadInterface = function() return gamepad end}
assert(API.IsEnabled() == true and API.IsForeverClient() == true and API.IsInputReserved() == true
    and API.IsGamepadUIEnabled() == true and API.IsNativeGamepadInterface() == true
    and API.IsGeometryTransitionActive() == true and API.IsLoggingOut() == true,
    "services must reflect core state")
reserved, gamepad = false, false
assert(API.IsInputReserved() == false and API.IsGamepadUIEnabled() == false and API.IsNativeGamepadInterface() == false,
    "services must follow core state changes")
local printed, layout, chromeCalls, dynamic = {}, {}, 0, {}
function addon:Print(fmt, ...) printed[#printed + 1] = string.format(fmt, ...) end
function addon:ShowPopup(key, a, b, data) return key .. ":" .. tostring(a) .. tostring(b) .. tostring(data) end
function addon:ApplyFullLayout(preserve) layout[#layout + 1] = preserve end
function addon:GetReloadUIFunction() return print end
addon.L = setmetatable({KNOWN = "Known"}, {__index = function(_, key) return key end})
addon.WorkspaceChrome = {Refresh = function() chromeCalls = chromeCalls + 1 end,
    RegisterDynamicFrame = function(_, name) dynamic[#dynamic + 1] = name end}
addon.CanvasCompatibility = {GetWorldMapExternalOwner = function() return "MapOwner" end}
addon.UIControls = {}
API.Print("%s=%d", "x", 2)
assert(printed[1] == "x=2", "Print must go through Offhand's chat line")
assert(API.GetText("KNOWN") == "Known" and API.GetText("MISSING") == "MISSING", "GetText must read the locale table")
assert(API.ShowPopup("KEY", 1, 2, 3) == "KEY:123", "ShowPopup must pass its arguments to Offhand's popups")
assert(API.RequestFullLayout(true) == true and layout[1] == true, "RequestFullLayout must run the full layout")
assert(API.RefreshWorkspaceChrome() == true and chromeCalls == 1, "RefreshWorkspaceChrome must refresh the chrome")
assert(API.RegisterDynamicChromeFrame("AddonWindow") == true and dynamic[1] == "AddonWindow",
    "RegisterDynamicChromeFrame must register the name")
assert(API.GetExternalMapOwner() == "MapOwner" and API.GetReloadFunction() == print
    and API.GetControls() == addon.UIControls, "map owner, reload and controls must come from core")
addon.Viewport = {GetMetrics = function() return {isSpanned = true, gameLeft = 1} end}
assert(API.GetOptionsMetrics().gameLeft == 1, "spanned options metrics must be returned")
addon.Viewport = {GetMetrics = function() return {isSpanned = false} end}
assert(API.GetOptionsMetrics() == nil, "unspanned options metrics must be nil")
addon.db.enabled = false
assert(API.IsEnabled() == false and API.GetOptionsMetrics() == nil, "disabled Offhand must report disabled")
addon = Load()
assert(addon.API.RequestFullLayout(true) == false and addon.API.RefreshWorkspaceChrome() == false
    and addon.API.RegisterDynamicChromeFrame("X") == false and addon.API.GetExternalMapOwner() == nil
    and addon.API.GetReloadFunction() == nil and addon.API.GetText("KEY") == nil,
    "services must be safe before their core modules load")
addon.API.Print("unused")
C_AddOns = nil

-- Test support loader
local CoreBridges = dofile("tests/support/core-bridges.lua")
local supported = {AddonWindowCatalog = {}}
local supportBridges = CoreBridges.Load(supported)
assert(supportBridges == supported.Bridges and supported.API.RegisterAddonData,
    "the support loader must load the real registry")
assert(supported.API.RegisterBridge("Kept", {contract = 1}) == true)
assert(CoreBridges.Load(supported, {}) == supportBridges and supportBridges:Get("Kept"),
    "the support loader must keep an already loaded registry")

-- loaded and present detectors ask the client once per check, with no pcall
addon, Bridges = Load()
addon.API.RegisterAddonData("Queried", {ownership = {
    {role = "t.loaded", name = "L", detect = {loaded = "Anything"}},
    {role = "t.present", name = "P", detect = {present = "QueriedGlobal"}},
}})
local addonQueries, addonAnswer = 0, nil
C_AddOns = {IsAddOnLoaded = function() addonQueries = addonQueries + 1; return addonAnswer end}
assert(Bridges:HasRole("t.loaded") == false and Bridges:HasRole("t.present") == false and addonQueries == 2,
    "an addon that is not loaded must not hold a role, at one query per check")
addonAnswer = 1
assert(Bridges:HasRole("t.loaded") == true and Bridges:HasRole("t.present") == true,
    "a truthy query result must count as loaded")
addonAnswer = nil
_G.QueriedGlobal = {}
assert(Bridges:HasRole("t.present") == true and Bridges:HasRole("t.loaded") == false,
    "present must accept the global when the addon is not loaded")
_G.QueriedGlobal, C_AddOns = nil, nil

-- IsControllerOwned and the ConsolePort data bridge
addon, Bridges = Load()
assert(addon.API.IsControllerOwned() == false, "no controller owner must mean not controller owned")
CoreBridges.Load(addon, {"Bridges/ConsolePort/Bridge.lua"})
assert(#Bridges:List() == 0, "the ConsolePort data bridge must not register a bridge object")
local controllerRoles = {"hud.controller", "hud.actionBars", "hud.statusBars", "hud.editModeBlocker", "report.actionBars"}
for _, role in ipairs(controllerRoles) do
    assert(Bridges:HasRole(role) == false, role .. " must be absent without ConsolePort")
end
assert(addon.API.IsControllerOwned() == false, "ConsolePort data alone must not claim the controller")
assert(table.concat(Bridges:GetRuleNames("diagnosticFrame"), ",") == "ConsolePortCrosshair",
    "ConsolePort must name its crosshair for placement diagnostics")
_G.ConsolePort = {}
for _, role in ipairs(controllerRoles) do
    assert(Bridges:HasRole(role) == true, role .. " must follow the ConsolePort global")
end
assert(addon.API.IsControllerOwned() == true, "IsControllerOwned must follow the hud.controller role")
local controllerOwner, controllerEntry = Bridges:FirstRoleOwner("report.actionBars")
assert(controllerOwner == "ConsolePort" and controllerEntry.order == 40,
    "ConsolePort must report action bars at order 40")
_G.ConsolePort = nil
C_AddOns = {IsAddOnLoaded = function(name) return name == "ConsolePort" end}
assert(Bridges:HasRole("report.actionBars") == true and Bridges:HasRole("hud.controller") == false
    and addon.API.IsControllerOwned() == false,
    "a loaded ConsolePort without its global must be reported but must not own the controller")
C_AddOns = nil

-- Role entries, guidance entries and diagnostic segments
addon, Bridges = Load()
addon.API.RegisterAddonData("Second", {
    ownership = {{role = "t.entries", name = "Late", order = 20, detect = {global = "NeverSetGlobal"}}},
    guidance = {{id = "late", order = 20}, {id = "unordered"}},
    diagnostics = {{slot = "s", order = 20, label = "B"}, {slot = "s", label = "C"}, {slot = "s", order = 5}},
})
addon.API.RegisterAddonData("First", {
    ownership = {{role = "t.entries", name = "Early", order = 10, detect = {global = "NeverSetGlobal"}}},
    guidance = {{id = "early", order = 10, suffixWhen = {global = "SuffixGlobal"}}, {order = 1}},
    diagnostics = {{slot = "s", order = 10, label = "A"}},
})
local function Joined(list, field)
    local out = {}
    for index, item in ipairs(list) do out[index] = field and item[field] or item end
    return table.concat(out, ",")
end
assert(Joined(Bridges:GetRoleEntries("t.entries"), "name") == "Early,Late" and #Bridges:GetRoleOwners("t.entries") == 0,
    "role entries must list every owner in order, present or not")
assert(#Bridges:GetRoleEntries("t.none") == 0, "an unknown role must have no entries")
local guide, suffix = Bridges:GetGuidanceEntries()
assert(Joined(guide, "id") == "early,late,unordered" and suffix[1] == false and suffix[2] == false
    and suffix[3] == false, "guidance must sort by order, last when unordered, and need an id")
_G.SuffixGlobal = {}
guide, suffix = Bridges:GetGuidanceEntries()
assert(suffix[1] == true and suffix[2] == false, "a guidance suffix must follow its detector")
_G.SuffixGlobal = nil
assert(Joined(Bridges:GetDiagnosticSegments("s"), "label") == "A,B,C",
    "diagnostic segments must sort by order and need a slot and a label")
assert(#Bridges:GetDiagnosticSegments("none") == 0, "an unknown slot must have no segments")

-- The HUD and report ownership data bridges reproduce the legacy lists and their order.
local hudBridgeFiles = {}
for _, name in ipairs({"Bartender4", "BlizzMove", "Carbonite", "Cell", "Chattynator", "ConsolePort", "Dominos",
    "EllesmereUI", "ElvUI", "MoveAny", "MoveMyBags", "PitBull4", "SexyMap", "ShadowedUnitFrames", "Tukui",
    "XPerl", "ZPerl"}) do
    hudBridgeFiles[#hudBridgeFiles + 1] = "Bridges/" .. name .. "/Bridge.lua"
end
local hudLoaded = {}
local hudFolders = {"EllesmereUIActionBars", "EllesmereUIMinimap", "EllesmereUIChat", "EllesmereUICooldownManager",
    "EllesmereUIQuestTracker", "EllesmereUIUnitFrames", "EllesmereUIRaidFrames", "Bartender4", "Dominos", "ElvUI",
    "Tukui", "Chattynator", "ShadowedUnitFrames", "Cell", "PitBull4", "ZPerl", "XPerl", "MoveAny", "BlizzMove",
    "MoveMyBags", "ConsolePort"}
local hudGlobals = {"Bartender4", "Dominos", "ElvUI", "Tukui", "ConsolePort", "SexyMap", "Carbonite", "MoveAny",
    "ElvUI_Bar1", "TukuiActionBars", "TukuiPlayerFrame", "ElvUF_Player"}
local function SetHUDOwners(present)
    for _, name in ipairs(hudFolders) do hudLoaded[name] = present or nil end
    for _, name in ipairs(hudGlobals) do _G[name] = present and {} or nil end
    C_AddOns = present and {IsAddOnLoaded = function(name) return hudLoaded[name] == true end} or nil
end
local hudRoles = {"hud.actionBars", "hud.statusBars", "hud.minimap", "hud.chat", "hud.partyFrames", "hud.unitFrames",
    "hud.groupFrames", "hud.cooldownViewer", "hud.objectiveTracker", "hud.editModeBlocker", "hud.layoutSignature",
    "report.actionBars", "report.chat", "report.minimap", "report.unitFrames", "report.movers"}
local LEGACY_SIGNATURE = "EllesmereUIActionBars:EllesmereUIMinimap:EllesmereUIChat:EllesmereUICooldownManager:"
    .. "EllesmereUIQuestTracker:EllesmereUIUnitFrames:EllesmereUIRaidFrames:Bartender4:Dominos:ElvUI:Tukui:Chattynator"
local GUIDANCE_ORDER = "suf,moveany,movemybags,blizzmove,ab:Bartender4,ab:Dominos,suite:ElvUI,suite:Tukui,"
    .. "ellesmere,uf:PitBull4,uf:ZPerl,uf:XPerl,uf:Cell"
addon, Bridges = Load()
CoreBridges.Load(addon, hudBridgeFiles)
assert(#Bridges:List() == 0, "the ownership data bridges must not register bridge objects")
for _, role in ipairs(hudRoles) do
    assert(Bridges:HasRole(role) == false, role .. " must have no owner while no addon is present")
end
SetHUDOwners(true)
local function Owners(role, separator) return table.concat((Bridges:GetRoleOwners(role)), separator or ",") end
assert(Owners("hud.layoutSignature", ":") == LEGACY_SIGNATURE,
    "the layout ownership signature must keep the legacy order byte for byte")
assert(Owners("report.actionBars") == "Bartender4,Dominos,EllesmereUIActionBars,ConsolePort,ElvUI,Tukui",
    "action bar owners must keep the legacy report order")
assert(Owners("report.unitFrames") == "ShadowedUnitFrames,EllesmereUIUnitFrames,ElvUI,Tukui,Cell,PitBull4,ZPerl,XPerl",
    "unit frame owners must keep the legacy report order")
assert(Owners("report.chat") == "Chattynator,EllesmereUIChat", "chat owners must keep the legacy report order")
assert(Owners("report.minimap") == "EllesmereUIMinimap,SexyMap,Carbonite,ElvUI"
    and Bridges:FirstRoleOwner("report.minimap") == "EllesmereUIMinimap",
    "minimap owners must keep the legacy first-wins order")
assert(Owners("report.movers") == "MoveAny,BlizzMove,MoveMyBags", "frame movers must keep the legacy report order")
assert(Owners("hud.actionBars") == "Bartender4,Dominos,ElvUI,Tukui,ConsolePort,EllesmereUIActionBars"
    and Owners("hud.statusBars") == "Bartender4,Dominos,ElvUI,Tukui,ConsolePort,EllesmereUIActionBars",
    "bar owners must be tested in the legacy order")
assert(Owners("hud.minimap") == "SexyMap,Carbonite,ElvUI,EllesmereUIMinimap"
    and Owners("hud.chat") == "Chattynator,EllesmereUIChat"
    and Owners("hud.unitFrames") == "EllesmereUIUnitFrames,ElvUI"
    and Owners("hud.groupFrames") == "ElvUI"
    and Owners("hud.editModeBlocker") == "ConsolePort,ElvUI,Tukui,MoveAny",
    "HUD owners must be tested in the legacy order")
local _, partyEntry = Bridges:FirstRoleOwner("hud.partyFrames")
assert(partyEntry.name == "EllesmereUIRaidFrames" and partyEntry.noticeKey == "COMPAT_ELLESMERE_PARTY",
    "custom party frames must supply the legacy notice key")
assert(Joined((Bridges:GetGuidanceEntries()), "id") == GUIDANCE_ORDER, "guidance must keep the legacy order")
assert(Joined(Bridges:GetDiagnosticSegments("chat"), "label") == "EllesmereUIChat,Chattynator"
    and Joined(Bridges:GetDiagnosticSegments("minimap"), "label")
        == "SexyMap,EllesmereCore,EllesmereMinimap,EllesmereOptions,EllesmereMover,EllesmereProfileEnabled",
    "diagnostic segments must keep the legacy order")
EllesmereUI = {Lite = {GetAddon = function() return {db = {profile = {useBlizzardDataBars = true}}} end}}
assert(Owners("hud.statusBars") == "Bartender4,Dominos,ElvUI,Tukui,ConsolePort",
    "Blizzard XP/Rep bars chosen in EllesmereUI must release its status bar ownership")
EllesmereUI = nil
SetHUDOwners(false)

-- The compatibility report, its guidance and the layout status consume those lists.
do
    local report = {AddonWindowCatalog = {}, isForever = true}
    WorldMapFrame = {}
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", report)
    CoreBridges.Load(report, hudBridgeFiles)
    local compat = report.CanvasCompatibility
    assert(#compat.GetExternalControlGuidance() == 0, "no guidance without external owners")
    SetHUDOwners(true)
    local owners = compat.GetActiveExternalOwners()
    assert(table.concat(owners.actionBars, ",") == "Bartender4,Dominos,EllesmereUIActionBars,ConsolePort,ElvUI,Tukui"
        and table.concat(owners.unitFrames, ",")
            == "ShadowedUnitFrames,EllesmereUIUnitFrames,ElvUI,Tukui,Cell,PitBull4,ZPerl,XPerl"
        and table.concat(owners.chat, ",") == "Chattynator,EllesmereUIChat" and owners.minimap == "EllesmereUIMinimap"
        and table.concat(owners.movers, ",") == "MoveAny,BlizzMove,MoveMyBags",
        "the compatibility report must keep the legacy owner lists")
    local tips, ids, byId = compat.GetExternalControlGuidance(), {}, {}
    for index, tip in ipairs(tips) do ids[index], byId[tip.id] = tip.id, tip end
    assert(table.concat(ids, ",") == GUIDANCE_ORDER, "the guidance must come out in the legacy order")
    assert(byId["ab:Dominos"].addon == "Dominos" and byId["ab:Dominos"].text
        == "Dominos controls action bars. Unlock and move bars in Dominos instead of Blizzard Edit Mode.",
        "formatted guidance must name its addon twice")
    assert(byId.movemybags.text:find("Options > AddOns > MoveMyBags.", 1, true),
        "the MoveMyBags layers tip must follow its guidance on Forever")
    MoveMyBagsDB = {layers = false}
    assert(not compat.GetExternalControlGuidance()[3].text:find("Options > AddOns", 1, true),
        "the layers tip must stay away once MoveMyBags layers are off")
    MoveMyBagsDB = nil
    assert(compat.GetDiagnostics(false):find(" | FrameControllers=ShadowedUnitFrames,EllesmereUIUnitFrames,ElvUI,"
        .. "Tukui,Cell,PitBull4,ZPerl,XPerl,Bartender4,Dominos,EllesmereUIActionBars,ConsolePort,MoveAny,BlizzMove,"
        .. "MoveMyBags", 1, true), "the frame controller diagnostics must keep the legacy order")
    SetHUDOwners(false)
    WorldMapFrame = nil

    local layout = {Mainhand = {}, MainhandGeometry = {}, MainhandCompatibility = {
        IsNativeGamepadInterface = function() return false end, IsControllerMode = function() return false end}}
    assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", layout)
    assert(loadfile("Core/MainhandEditMode.lua"))("Offhand", layout)
    CoreBridges.Load(layout, hudBridgeFiles)
    SetHUDOwners(true)
    local function Status(signature)
        return layout.Mainhand:GetLayoutStatus("geometry", {generatedName = "Offhand", ownershipSignature = signature})
    end
    local status = Status(LEGACY_SIGNATURE)
    assert(status.currentOwnership == true and status.suiteGainedOwnership == false,
        "a legacy signature saved with every owner present must still match")
    assert(Status(LEGACY_SIGNATURE:gsub("EllesmereUIRaidFrames:", "")).suiteGainedOwnership == true,
        "a suite module gaining ownership must be recognised")
    assert(Status(LEGACY_SIGNATURE:gsub(":Chattynator", "")).suiteGainedOwnership == false,
        "another addon gaining ownership must not count as the suite")
    -- Only the bar addons' globals own status bars; loaded folders keep the signature.
    Bartender4, Dominos, ElvUI, Tukui, ConsolePort = nil, nil, nil, nil, nil
    EllesmereUI = {Lite = {GetAddon = function() return {db = {profile = {useBlizzardDataBars = true}}} end}}
    status = Status(LEGACY_SIGNATURE)
    assert(status.currentOwnership == false and status.suiteGainedOwnership == false
        and Status(LEGACY_SIGNATURE .. ":native-status").currentOwnership == true,
        "Blizzard XP/Rep bars must append native-status to the signature")
    EllesmereUI = nil
    SetHUDOwners(false)
end

-- GetRuleWidget resolves the first widget matcher holding a frame, without qualifiers.
addon, Bridges = Load()
local heldFrame = {}
addon.API.RegisterAddonData("Widgets", {frameRules = {held = {
    "NamedOnly",
    {widget = {"EmptyHolder", "frame"}},
    {widget = {"FullHolder", "frame"}, when = {global = "NeverSetGlobal"}},
}}})
assert(Bridges:GetRuleWidget("held") == nil and Bridges:GetRuleWidget("missing") == nil,
    "no holder must mean no widget frame")
_G.EmptyHolder = setmetatable({}, {__index = function() return heldFrame end})
_G.FullHolder = {frame = heldFrame}
local heldWidget, heldName = Bridges:GetRuleWidget("held")
assert(heldWidget == heldFrame and heldName == "FullHolder",
    "the first holder with its own field must give the frame and the holder's name")
_G.EmptyHolder, _G.FullHolder = nil, nil

-- Popup roots, frame-name rules, tooltip owners and mover fields reproduce the core checks they replace.
local ruleBridgeFiles = {}
for _, path in ipairs({"Baganator/Data", "BetterBags/Data", "BugSack/Bridge", "Details/Bridge", "EllesmereUI/Bridge",
    "ForeverXPBar/Bridge", "MoveMyBags/Bridge", "OneForAll/Data", "ProcDoc/Data", "Questie/Rules",
    "RedIsFriend/Bridge", "RestedXP/Bridge", "TinyTooltip/Bridge", "TinyTooltipReforged/Bridge", "TipTac/Bridge",
    "Titan/Bridge"}) do
    ruleBridgeFiles[#ruleBridgeFiles + 1] = "Bridges/" .. path .. ".lua"
end
do
    local rules = {AddonWindowCatalog = {}}
    WorldMapFrame = {}
    assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", rules)
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", rules)
    local hud, canvas = rules.HUDCompatibility, rules.CanvasCompatibility
    local anonymous = {}
    assert(hud.ShouldPreservePopupPosition(anonymous, "BetterBagsBagBank", true) == false
        and hud.IsExternallyOwnedHUDFrame(anonymous, "EllesmereUIPlayerAuraBars_Buffs") == false
        and hud.GetPreservedAnonymousRoot() == nil
        and canvas.ShouldYieldNativeContainer({moveMyBags = 1}, "ContainerFrame1") == false,
        "without the registry no addon rule may match")
    local registry = CoreBridges.Load(rules, ruleBridgeFiles)
    assert(#registry:List() == 0, "the rule data bridges must not register bridge objects")
    -- allowUserPlaced stops ShouldPreservePopupPosition right after the rules.
    local function Preserves(frame, name) return hud.ShouldPreservePopupPosition(frame, name, true) end
    for _, name in ipairs({"BetterBagsBagBackpack", "BetterBagsBagBank", "BetterBagsBagBackpackAnchor",
        "BetterBagsBagBankAnchor", "BetterBagsNextBackpack", "BetterBagsNextBank", "BetterBagsNextVendor",
        "BetterBagsNextGuildBank", "RXPFrame", "RXPItemFrame", "ProcDocAlertFrame", "ForeverXPBarMainFrame",
        "Questie_BaseFrame", "ChatAlertFrame", "DetailsBaseFrame1", "DetailsBaseFrame12"}) do
        assert(Preserves({}, name) == true, "popup recovery must preserve the addon-owned root " .. name)
    end
    for _, name in ipairs({"DetailsBaseFrameSettings", "OtherDetailsBaseFrame1", "BetterBagsBagBankX",
        "UnrelatedFrame", "ContainerFrame3", "ContainerFrameCombinedBags", "Baganator_SingleViewBackpackViewFrame"}) do
        assert(Preserves({}, name) == false, "popup recovery must not preserve " .. name)
    end
    assert(Preserves(anonymous, nil) == false, "an anonymous frame without owner marks must not be preserved")
    local bar, impostor = {}, {}
    _G.TitanBar = bar
    _G.TitanBarData = {TitanBar = {frame_name = "TitanBar"}}
    assert(Preserves(bar, "TitanBar") == true and Preserves(impostor, "TitanBar") == false,
        "a Titan bar must be the global frame its store entry names")
    _G.TitanBarData.TitanBar.frame_name = "Other"
    assert(Preserves(bar, "TitanBar") == false, "a Titan store entry naming another frame must not match")
    _G.TitanBar, _G.TitanBarData = nil, nil
    assert(Preserves(bar, "TitanBar") == false, "without TitanBarData no bar must be preserved")
    local root, child = {}, {}
    function root:GetParent() return UIParent end
    function child:GetParent() return root end
    assert(Preserves(root, "Baganator_SingleViewBackpackViewFrameblizzard") == true
        and Preserves(root, "Baganator_CategoryViewBackpackViewFrameblizzard") == true
        and Preserves(child, "Baganator_SingleViewBackpackViewFrameblizzardTitle") == false,
        "only Baganator backpack roots parented to UIParent must be preserved")
    assert(Preserves({moveMyBags = "attached"}, nil) == true and Preserves({moveMyBags = false}, "Any") == true,
        "a container marked by MoveMyBags must be preserved, even anonymous")
    _G.MoveMyBags = {}
    assert(Preserves({}, "ContainerFrame6") == true and Preserves({}, "ContainerFrameCombinedBags") == true
        and Preserves({}, "ContainerFrameX") == false and Preserves({}, "BagContainerFrame1") == false,
        "every native container must be preserved while MoveMyBags is present")
    assert(canvas.ShouldYieldNativeContainer("ContainerFrame2") == true
        and canvas.ShouldYieldNativeContainer({}, "ContainerFrameCombinedBags") == true
        and canvas.ShouldYieldNativeContainer({}, "BankFrame") == false,
        "native containers must yield while MoveMyBags is present")
    _G.MoveMyBags = nil
    assert(canvas.ShouldYieldNativeContainer("ContainerFrame2") == false
        and canvas.ShouldYieldNativeContainer({}, "ContainerFrame2") == false
        and canvas.ShouldYieldNativeContainer({moveMyBags = 1}, "ContainerFrame2") == true
        and canvas.ShouldYieldNativeContainer({moveMyBags = 1}, "BankFrame") == false,
        "without MoveMyBags only a marked native container must yield")
    local guide = {}
    assert(Preserves(guide, nil) == false and hud.GetPreservedAnonymousRoot() == nil,
        "no RestedXP V2 widget must mean no preserved anonymous root")
    _G.RXPV2GuideWindow = {frame = guide}
    local preservedRoot, preservedName = hud.GetPreservedAnonymousRoot()
    assert(Preserves(guide, nil) == true and Preserves({}, nil) == false
        and preservedRoot == guide and preservedName == "RXPV2GuideWindow",
        "the RestedXP V2 guide frame must be preserved and recoverable under its widget's name")
    _G.RXPV2GuideWindow = nil
    assert(hud.IsExternallyOwnedHUDFrame({}, "EllesmereUIPlayerAuraBars_Buffs") == true
        and hud.IsExternallyOwnedHUDFrame({}, "EllesmereUIPlayerAuraBars_Debuffs") == true
        and hud.IsExternallyOwnedHUDFrame({}, "EllesmereUIPlayerAuraBars_Other") == false
        and hud.IsExternallyOwnedHUDFrame({}, nil) == false,
        "only the Ellesmere aura bar roots must count as externally owned HUD")
    assert(table.concat(registry:GetRuleNames("menuFrame"), ",") == "BugSackFrame,RedIsFriendFrame",
        "addon menus must keep the legacy order after the Blizzard names")
    assert(registry:FirstRoleOwner("tooltip.owner") == nil, "no tooltip owner without a tooltip addon")
    _G.TinyTooltipReforged = {}
    assert(registry:FirstRoleOwner("tooltip.owner") == "TinyTooltipReforged", "TinyTooltipReforged alone owns tooltips")
    _G.TinyTooltip = {}
    assert(registry:FirstRoleOwner("tooltip.owner") == "TinyTooltip", "TinyTooltip must win over TinyTooltipReforged")
    _G.TipTac = {}
    assert(registry:FirstRoleOwner("tooltip.owner") == "TipTac", "TipTac must win over both TinyTooltips")
    _G.TipTac, _G.TinyTooltip, _G.TinyTooltipReforged = nil, nil, nil
    assert(registry.IsExternallyMovable({ofaMovable = true}) and not registry.IsExternallyMovable({ofaMovable = 1})
        and not registry.IsExternallyMovable({}) and registry.IsExternallyMoving({ofaMoving = 1})
        and not registry.IsExternallyMoving({ofaMovable = true}),
        "OneForAll's movable and moving marks must be the mover fields")
    assert(table.concat(registry:GetRuleNames("diagnosticFrame"), ",") == "ForeverXPBarMainFrame",
        "ForeverXPbar must name its bar for the panel placement diagnostics")
    local segments = registry:GetDiagnosticSegments("panelPlacement")
    assert(#segments == 1 and segments[1].frame == "ForeverXPBarMainFrame" and segments[1].label == "ForeverXPBarSave"
        and segments[1].value() == "unavailable", "an unsaved XP bar must report its save as unavailable")
    ForeverXPBarDB = {point = "CENTER", relPoint = "CENTER", x = 40, y = 50}
    assert(segments[1].value() == "CENTER/CENTER/40.0/50.0", "the XP bar save must read point/relPoint/x/y")
    ForeverXPBarDB = {point = "CENTER", relPoint = "CENTER", x = "40", y = 50}
    assert(segments[1].value() == "unavailable", "a malformed XP bar save must report unavailable")
    ForeverXPBarDB, WorldMapFrame = nil, nil
end

-- ProcDoc: the centering bridge keeps its opt-in under the stored key
-- centerProcDocOnMainhand, which joins the profile defaults, and its status is
-- the compat.tail diagnostics segment rather than part of the bridges segment.
do
    local procDoc = {AddonWindowCatalog = {}, db = {centerProcDocOnMainhand = true}}
    local registry = CoreBridges.Load(procDoc, {"Bridges/ProcDoc/Data.lua", "Bridges/ProcDoc/Bridge.lua"})
    local ids = registry:List()
    assert(#ids == 1 and ids[1] == "ProcDoc", "the ProcDoc bridge must register on every client")
    assert(procDoc.API.GetBridgeSetting("ProcDoc", "centerProcDocOnMainhand") == true,
        "a value saved under centerProcDocOnMainhand must be read back through the bridge setting")
    assert(procDoc.API.SetBridgeSetting("ProcDoc", "centerProcDocOnMainhand", false) == true
        and procDoc.db.centerProcDocOnMainhand == false, "the opt-in must be written under its stored key")
    assert(registry:GetSettingDefaults().centerProcDocOnMainhand == false
        and #registry:GetCharacterResetKeys() == 0, "the opt-in must be a profile default of false")
    assert(registry:MatchName("preservePopup", "ProcDocAlertFrame"), "the data file must still preserve the alert root")
    local tail = registry:GetDiagnosticSegments("compat.tail")
    assert(#tail == 1 and tail[1].label == "ProcDocCenter" and tail[1].value() == "inactive"
        and registry:GetDiagnostics() == nil, "the ProcDoc status must be the compat.tail segment")
    local contributions = registry:GetSettingsContributions("alerts")
    assert(#contributions == 1 and contributions[1].addon == "ProcDoc" and contributions[1].kind == "check",
        "the ProcDoc opt-in must be an alerts checkbox for its addon")

    -- Config fills a fresh profile with the bridge default and keeps a saved value.
    local savedCreateFrame, savedUIParent = CreateFrame, UIParent
    StaticPopupDialogs, SlashCmdList = {}, {}
    GetBuildInfo = function() return "1.60.1", "70790", "synthetic", 16001 end
    InCombatLockdown = function() return false end
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    UIParent = {GetEffectiveScale = function() return 1 end, GetWidth = function() return width end,
        GetHeight = function() return height end}
    local cvars = {}
    RegisterCVar = function(name, default) if cvars[name] == nil then cvars[name] = default or "" end end
    GetCVar = function(name) return cvars[name] end
    SetCVar = function(name, value) cvars[name] = tostring(value) end
    UnitName = function() return "Tester" end
    UnitFullName = function() return "Tester", "Realm" end
    GetNormalizedRealmName = function() return "Realm" end
    C_Timer = {After = function() end}
    local function Configured(account)
        OffhandDB, OffhandCharDB = account, nil
        local configured = {}
        assert(loadfile("Core/Init.lua"))("Offhand", configured)
        assert(loadfile("Core/ClientRuntime.lua"))("Offhand", configured)
        assert(loadfile("Core/Config.lua"))("Offhand", configured)
        CoreBridges.Load(configured, {"Bridges/ProcDoc/Data.lua", "Bridges/ProcDoc/Bridge.lua"})
        configured:InitializeConfig()
        return configured
    end
    local fresh = Configured(nil)
    assert(fresh.db.centerProcDocOnMainhand == false, "a fresh profile must hold the ProcDoc opt-in default")
    fresh.db.centerProcDocOnMainhand = true
    local kept = Configured(OffhandDB)
    assert(kept.db.centerProcDocOnMainhand == true
        and kept.API.GetBridgeSetting("ProcDoc", "centerProcDocOnMainhand") == true,
        "a saved ProcDoc opt-in must survive configuration and read back through the bridge")
    OffhandDB, OffhandCharDB, StaticPopupDialogs, SlashCmdList, GetBuildInfo, InCombatLockdown = nil, nil, nil, nil, nil, nil
    RegisterCVar, GetCVar, SetCVar, UnitName, UnitFullName, GetNormalizedRealmName, C_Timer = nil, nil, nil, nil, nil, nil, nil
    CreateFrame, UIParent = savedCreateFrame, savedUIParent
    _G.Offhand = nil
end

-- PrepareTransition and BeginSession: registration order, bridges without the
-- method skipped, a throwing bridge recorded without stopping the others.
addon, Bridges = Load()
local sessionCalls = {}
local sessionA, sessionB, sessionC = {contract = 1}, {contract = 1}, {contract = 1}
function sessionA:PrepareTransition() sessionCalls[#sessionCalls + 1] = "A:prepare" end
function sessionA:BeginSession(...) sessionCalls[#sessionCalls + 1] = "A:begin" .. select("#", ...) end
function sessionB:PrepareTransition() error("prepare boom") end
function sessionC:BeginSession() sessionCalls[#sessionCalls + 1] = "C:begin" end
assert(Bridges:Register("SessionA", sessionA) and Bridges:Register("SessionB", sessionB)
    and Bridges:Register("SessionC", sessionC))
Bridges:PrepareTransition()
Bridges:BeginSession()
assert(table.concat(sessionCalls, ",") == "A:prepare,A:begin0,C:begin",
    "session dispatch must keep registration order and skip bridges without the method")
assert(Bridges.errors.SessionB and Bridges.errors.SessionB:find("prepare boom", 1, true),
    "a throwing PrepareTransition must be recorded")

-- Kerzo Classic Quest Log: its catalog entry, workspace close button frame and
-- character open intent (stored key kerzoQuestLogOpen, cleared on a character
-- change by Config) come from the bridge.
do
    local kerzo = {AddonWindowCatalog = {}}
    local registry = CoreBridges.Load(kerzo, {"Bridges/KerzoQuestLog/Bridge.lua"})
    assert(#registry:List() == 1 and registry:Get("KerzoQuestLog"), "the Kerzo bridge must register on every client")
    assert(kerzo.AddonWindowCatalog["Kerzo Classic Quest Log"].questLog.close == "quest-log-adapter",
        "the Kerzo catalog entry must be merged")
    assert(table.concat(registry:GetRuleNames("workspaceChrome"), ",") == "KerzosQuestLog",
        "the quest log must be a workspace chrome frame")
    _G.OffhandCharDB = {kerzoQuestLogOpen = true}
    assert(kerzo.API.GetBridgeCharacterSetting("KerzoQuestLog", "kerzoQuestLogOpen") == true,
        "a value saved under kerzoQuestLogOpen must be read back through the bridge setting")
    _G.OffhandCharDB = nil

    local savedCreateFrame, savedUIParent = CreateFrame, UIParent
    StaticPopupDialogs, SlashCmdList = {}, {}
    GetBuildInfo = function() return "1.60.1", "70790", "synthetic", 16001 end
    InCombatLockdown = function() return false end
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    UIParent = {GetEffectiveScale = function() return 1 end}
    UnitName = function() return "Tester" end
    local guid = "Player-1"
    UnitGUID = function() return guid end
    local configured = {}
    assert(loadfile("Core/Init.lua"))("Offhand", configured)
    assert(loadfile("Core/ClientRuntime.lua"))("Offhand", configured)
    assert(loadfile("Core/Config.lua"))("Offhand", configured)
    CoreBridges.Load(configured, {"Bridges/KerzoQuestLog/Bridge.lua"})
    OffhandCharDB = {characterGUID = "Player-1", kerzoQuestLogOpen = true, characterSetup = {}}
    configured:EnsureCharacterIdentity()
    assert(OffhandCharDB.kerzoQuestLogOpen == true, "the same character must keep its open intent")
    guid = "Player-2"
    configured:EnsureCharacterIdentity()
    assert(OffhandCharDB.kerzoQuestLogOpen == nil and OffhandCharDB.characterSetup == nil
        and OffhandCharDB.characterGUID == "Player-2", "a character change must clear the bridge's reset keys")
    OffhandCharDB, StaticPopupDialogs, SlashCmdList, GetBuildInfo, InCombatLockdown = nil, nil, nil, nil, nil
    UnitName, UnitGUID = nil, nil
    CreateFrame, UIParent = savedCreateFrame, savedUIParent
    _G.Offhand = nil
end

-- RefreshScale: registration order, bridges without the method skipped, a
-- throwing bridge recorded; the EllesmereUI scale bridge registers before
-- EllesmereUI exists and stays inert without it.
addon, Bridges = Load()
local scaleCalls = {}
local scaleA, scaleB, scaleC = {contract = 1}, {contract = 1}, {contract = 1}
function scaleA:RefreshScale(...) scaleCalls[#scaleCalls + 1] = "A" .. select("#", ...) end
function scaleB:RefreshScale() error("scale boom") end
function scaleC:RefreshScale() scaleCalls[#scaleCalls + 1] = "C" end
assert(Bridges:Register("ScaleA", scaleA) and Bridges:Register("ScaleB", scaleB)
    and Bridges:Register("ScaleD", {contract = 1}) and Bridges:Register("ScaleC", scaleC))
Bridges:RefreshScale()
assert(table.concat(scaleCalls, ",") == "A0,C", "RefreshScale must keep registration order and skip bridges without it")
assert(Bridges.errors.ScaleB and Bridges.errors.ScaleB:find("scale boom", 1, true),
    "a throwing RefreshScale must be recorded")
do
    local suite = {AddonWindowCatalog = {}}
    local registry = CoreBridges.Load(suite, {"Bridges/EllesmereUI/Bridge.lua", "Bridges/EllesmereUI/Scale.lua"})
    local ids = registry:List()
    assert(#ids == 1 and ids[1] == "EllesmereUI" and suite.API.GetBridgeNamespace("EllesmereUI").Scale,
        "the EllesmereUI scale bridge must register on every client")
    registry:RefreshScale()
    assert(registry.errors.EllesmereUI == nil, "the scale bridge must be inert without EllesmereUI")
end

-- InitializePopupWindows and OwnsFeature: registration order, bridges without
-- the method skipped, a throwing bridge recorded; the first literal true names
-- the owning bridge. The EllesmereUI window bridge shares the suite's bridge
-- object and starts its 0.2 s ticker only on Forever with EllesmereUI present.
addon, Bridges = Load()
local popupCalls = {}
local popupA, popupB, popupC = {contract = 1}, {contract = 1}, {contract = 1}
function popupA:InitializePopupWindows(...) popupCalls[#popupCalls + 1] = "A" .. select("#", ...) end
function popupB:InitializePopupWindows() error("popup boom") end
function popupA:OwnsFeature(feature) popupCalls[#popupCalls + 1] = "own:" .. tostring(feature); return 1 end
function popupB:OwnsFeature() error("feature boom") end
function popupC:OwnsFeature(feature) return feature == "chatBubbles" end
assert(Bridges:Register("PopupA", popupA) and Bridges:Register("PopupB", popupB)
    and Bridges:Register("PopupD", {contract = 1}) and Bridges:Register("PopupC", popupC))
Bridges:InitializePopupWindows()
assert(popupCalls[1] == "A0" and #popupCalls == 1, "InitializePopupWindows must skip bridges without it")
assert(Bridges.errors.PopupB and Bridges.errors.PopupB:find("popup boom", 1, true),
    "a throwing InitializePopupWindows must be recorded")
assert(Bridges:OwnsFeature("chatBubbles") == "PopupC" and popupCalls[2] == "own:chatBubbles",
    "only a literal true claims a feature, for the first bridge returning it")
assert(Bridges.errors.PopupB:find("feature boom", 1, true), "a throwing OwnsFeature must be recorded")
assert(Bridges:OwnsFeature("other") == nil, "an unclaimed feature has no owner")
do
    local savedTimer, savedSuite = C_Timer, EllesmereUI
    local tickers = {}
    C_Timer = {NewTicker = function(interval, callback) tickers[#tickers + 1] = {interval, callback}; return {} end}
    local function Suite(forever)
        local suite = {AddonWindowCatalog = {}, isForever = forever}
        local registry = CoreBridges.Load(suite, {"Bridges/EllesmereUI/Bridge.lua", "Bridges/EllesmereUI/Scale.lua",
            "Bridges/EllesmereUI/Windows.lua"})
        return suite, registry
    end
    EllesmereUI = nil
    local suite, registry = Suite(true)
    local ids = registry:List()
    assert(#ids == 1 and ids[1] == "EllesmereUI" and suite.API.GetBridgeNamespace("EllesmereUI").Windows
        and registry:Get("EllesmereUI").RefreshScale and registry:Get("EllesmereUI").OwnsFeature,
        "the EllesmereUI files must share one bridge registered on every client")
    registry:InitializePopupWindows()
    assert(#tickers == 0 and registry:OwnsFeature("chatBubbles") == nil,
        "without EllesmereUI there is no window ticker and no bubble owner")
    EllesmereUI = {GetActiveProfileData = function() return {chatBubbles = {enabled = true}} end}
    suite, registry = Suite(false)
    registry:InitializePopupWindows()
    assert(#tickers == 0 and registry:OwnsFeature("chatBubbles") == "EllesmereUI",
        "the window ticker is Forever only; enabled EllesmereUI bubbles are owned by its bridge on every client")
    suite, registry = Suite(true)
    registry:InitializePopupWindows()
    assert(#tickers == 1 and tickers[1][1] == 0.2, "Forever with EllesmereUI must observe its windows every 0.2 s")
    tickers[1][2]()
    assert(registry.errors.EllesmereUI == nil, "a window pass without windows must be clean")
    EllesmereUI.GetActiveProfileData = function() return {chatBubbles = {enabled = false}} end
    assert(registry:OwnsFeature("chatBubbles") == nil, "disabled EllesmereUI bubbles must stay Offhand's")
    C_Timer, EllesmereUI = savedTimer, savedSuite
end

-- GetSetupNotes: non-empty answers joined in registration order, a throwing
-- bridge recorded. The HUD transfer services reach the Mainhand layout source,
-- the fallback save, the geometry signature and the layout failure text, and are
-- safe before those modules load.
do
    local suite, registry = Load()
    local notesA, notesB = {contract = 1}, {contract = 1}
    function notesA:GetSetupNotes(context) return context == "before-span" and "A" or "" end
    function notesB:GetSetupNotes() error("notes boom") end
    assert(registry:GetSetupNotes("before-span") == nil, "no bridge must give no setup notes")
    assert(registry:Register("NotesA", notesA) and registry:Register("NotesB", notesB)
        and registry:Register("NotesC", {contract = 1, GetSetupNotes = function() return "C" end}))
    assert(registry:GetSetupNotes("before-span") == "A\n\nC" and registry:GetSetupNotes("other") == "C",
        "setup notes must join in registration order and skip empty answers")
    assert(registry.errors.NotesB:find("notes boom", 1, true), "a throwing GetSetupNotes must be recorded")
    local api = suite.API
    local unsaved, unsavedReason = api.SaveHUDTransferFallback({}, {})
    assert(api.GetHUDTransferSource(true) == nil and unsaved == false and unsavedReason == "unavailable"
        and api.GetGeometrySignature({}) == nil and api.GetLayoutFailureText("span") == nil,
        "the transfer services must be safe before their core modules load")
    local sources = {}
    suite.Mainhand = {
        GetHUDTransferSource = function(self, geometryOnly, sizes)
            sources[#sources + 1] = tostring(self == suite.Mainhand) .. ":" .. tostring(geometryOnly)
            return {sizes = sizes}
        end,
        SaveHUDTransferFallback = function(_, context, rows) return context.ok and rows.ok, "Offhand HUD - Blizzard" end,
    }
    suite.MainhandGeometry = {Signature = function(rect) return "signature:" .. tostring(rect.left) end}
    suite.Options = {GetMainhandLayoutFailureText = function(_, reason) return "failure:" .. reason end}
    local sizes = {}
    assert(api.GetHUDTransferSource(false, sizes).sizes == sizes and api.GetHUDTransferSource(true)
        and sources[1] == "true:false" and sources[2] == "true:true",
        "GetHUDTransferSource must ask Offhand's Mainhand with its arguments")
    local saved, savedName = api.SaveHUDTransferFallback({ok = true}, {ok = true})
    assert(saved == true and savedName == "Offhand HUD - Blizzard", "SaveHUDTransferFallback must return the save result")
    assert(api.GetGeometrySignature({left = 3}) == "signature:3" and api.GetLayoutFailureText("span") == "failure:span",
        "the geometry signature and failure text must come from core")
end

-- The EllesmereUI HUD transfer provider exists on Forever only (with or without
-- EllesmereUI), names its texts with locale keys that exist, and its
-- /offhand ellesmere command runs at the old slash branch with the same output.
-- Its profile backup advice is a before-span setup note on Forever only.
do
    local savedTrim, savedOffhand = strtrim, _G.Offhand
    strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
    local files = {"Bridges/EllesmereUI/Bridge.lua", "Bridges/EllesmereUI/Bags.lua", "Bridges/EllesmereUI/Layout.lua",
        "Bridges/EllesmereUI/Preview.lua", "Bridges/EllesmereUI/Scale.lua", "Bridges/EllesmereUI/Windows.lua"}
    local standard = {AddonWindowCatalog = {}}
    local registry = CoreBridges.Load(standard, files)
    assert(standard.HUDTransfer == nil and registry:RunSlashCommand("ellesmere", "") == false,
        "off Forever there must be no transfer provider and no ellesmere command")
    local forever = {AddonWindowCatalog = {}, isForever = true}
    registry = CoreBridges.Load(forever, files)
    local transfer = forever.HUDTransfer
    assert(transfer and transfer.id == "EllesmereUI" and transfer.addon == "EllesmereUI"
        and transfer.copyDirection == "ellesmere" and transfer.reloadPopup == "OFFHAND_ELLESMERE_HUD_RELOAD"
        and transfer.ShowPreview and transfer.PromptImportReload and transfer.Preview and transfer.Run
        and forever.API.GetBridgeNamespace("EllesmereUI").Transfer == transfer,
        "the Forever client must register the EllesmereUI transfer provider with its preview")
    assert(table.concat(registry:List(), ",") == "EllesmereUIBags,EllesmereUI"
        and registry:Get("EllesmereUI").slashCommands.ellesmere,
        "the transfer command must join the suite's one bridge")
    local locale = {}
    assert(loadfile("Locales/enUS.lua"))("Offhand", locale)
    local names = {}
    for name, key in pairs(transfer.text) do
        names[#names + 1] = name
        assert(rawget(locale.L, key) ~= nil, "the transfer text " .. name .. " must name a locale key: " .. key)
    end
    table.sort(names)
    assert(table.concat(names, ",") == "busy,characterReview,finishCurrent,finishReload,helpBody,importReady,"
        .. "previewDesc,savedInactive,setupDesc,stage,title,wizardBody,wizardExisting,wizardIntro,wizardReload,"
        .. "wizardSelect,wizardSelectManual", "the transfer texts core shows must all be named")
    assert(transfer.text.title == "ELLESMERE_HUD_VISUAL" and transfer.text.stage == "SETUP_STAGE_ELLESMERE"
        and transfer.text.characterReview == "CHARACTER_SETUP_ELLESMERE",
        "the transfer keys must keep their stored locale names")
    local printed = {}
    forever.Print = function(_, text) printed[#printed + 1] = text end
    forever.L = setmetatable({}, {__index = function(_, key) return key end})
    assert(registry:RunSlashCommand("ellesmere", " nonsense ") and printed[1] == "ELLESMERE_HUD_HELP"
        and registry:RunSlashCommand("ellesmere", "") and #printed == 1 and registry.errors.EllesmereUI == nil,
        "/offhand ellesmere must print its help for an unknown action and preview silently without EllesmereUI")
    local savedSuite = EllesmereUI
    EllesmereUI = {ExportProfile = function() error("advice must not export a profile") end}
    assert(registry:GetSetupNotes("before-span") == "ELLESMERE_HUD_BACKUP_BEFORE_SPAN"
        and registry:GetSetupNotes("first-panel") == nil, "Forever must advise a profile backup before the span")
    forever.isForever = false
    assert(registry:GetSetupNotes("before-span") == nil, "the backup advice is Forever only")
    EllesmereUI, strtrim, _G.Offhand = savedSuite, savedTrim, savedOffhand
end

-- Addon window index (data.windows): a sourceless name is answered before the
-- source is read, an exact name or a pattern needs the source first, and only
-- the bridge whose name or pattern matched is called. Close buttons and header
-- drags go to the bridge listing the owner; openers come out by kind in
-- registration order.
addon, Bridges = Load()
local windowCalls = {}
local function WindowBridge(label, owner, role, windows)
    local bridge = {contract = 1, data = {windows = windows}}
    function bridge:IdentifyWindow(frame, name, source)
        windowCalls[#windowCalls + 1] = label .. ":" .. name .. ":" .. tostring(source)
        if role == "error" then error(label .. " boom") end
        if role then return owner, role end
    end
    function bridge:GetWindowCloseButtons(frame, who, name) return {label, who, name} end
    return bridge
end
assert(Bridges:Register("Early", WindowBridge("Early", "EarlyOwner", "settings",
        {sourceless = {"EarlyFrame"}, names = {"SharedName"}, owners = {"EarlyOwner"}, headerDrag = true}))
    and Bridges:Register("Named", WindowBridge("Named", "NamedOwner", "book",
        {names = {"NamedFrame", "SharedName"}, owners = {"NamedOwner", "EarlyOwner"}}))
    and Bridges:Register("Miss", WindowBridge("Miss", "MissOwner", nil, {patterns = {"^Pat%d+$"}}))
    and Bridges:Register("Hit", WindowBridge("Hit", "HitOwner", "panel", {patterns = {"^Pat1%d*$", ""}}))
    and Bridges:Register("Broken", WindowBridge("Broken", "BrokenOwner", "error", {names = {"BrokenFrame"}}))
    and Bridges:Register("Unlisted", WindowBridge("Unlisted", "UnlistedOwner", "settings", nil)))
local reads = 0
local windowFrame = {source = "src"}
local function ReadSource(frame) reads = reads + 1; return frame.source end
local function Identified(name)
    windowCalls, reads = {}, 0
    local owner, role = Bridges:IdentifyWindow(windowFrame, name, ReadSource)
    return tostring(owner) .. "/" .. tostring(role) .. "|" .. table.concat(windowCalls, ",") .. "|" .. reads
end
assert(Identified("EarlyFrame") == "EarlyOwner/settings|Early:EarlyFrame:nil|0",
    "a sourceless name must be answered before the source is read")
assert(Identified("SharedName") == "EarlyOwner/settings|Early:SharedName:src|1",
    "an exact name must read the source once and keep its first bridge")
assert(Identified("NamedFrame") == "NamedOwner/book|Named:NamedFrame:src|1", "an exact name must reach its bridge")
assert(Identified("Pat12") == "HitOwner/panel|Miss:Pat12:src,Hit:Pat12:src|1",
    "patterns must be tried in registration order until one bridge answers, reading the source once")
assert(Identified("Pat2") == "nil/nil|Miss:Pat2:src|1", "a pattern that no bridge answers must give nil")
assert(Identified("Elsewhere") == "nil/nil||0", "an unlisted name must call no bridge and read no source")
windowFrame.source = nil
assert(Identified("NamedFrame") == "nil/nil||1" and Identified("Pat12") == "nil/nil||1",
    "without a source no listed name or pattern may reach its bridge")
windowFrame.source = "src"
assert(Identified("BrokenFrame") == "nil/nil|Broken:BrokenFrame:src|1"
    and Bridges.errors.Broken:find("Broken boom", 1, true), "a throwing IdentifyWindow must be recorded and give nil")
assert(Bridges:IdentifyWindow(windowFrame, nil, ReadSource) == nil, "a missing name must identify nothing")
local buttons = Bridges:GetWindowCloseButtons(windowFrame, "EarlyOwner", "SharedName")
assert(table.concat(buttons, ",") == "Early,EarlyOwner,SharedName"
    and Bridges:GetWindowCloseButtons(windowFrame, "NamedOwner", "NamedFrame")[1] == "Named"
    and Bridges:GetWindowCloseButtons(windowFrame, "HitOwner", "Pat12") == nil
    and Bridges:GetWindowCloseButtons(windowFrame, nil, "x") == nil,
    "close buttons must come from the first bridge listing the owner, and only from it")
assert(Bridges:WindowUsesHeaderDrag("EarlyOwner") == true and Bridges:WindowUsesHeaderDrag("NamedOwner") == false
    and Bridges:WindowUsesHeaderDrag(nil) == false, "header drags must follow the owner's bridge")
local savedSlash = SlashCmdList
SlashCmdList = {}
local tableA = {}
assert(Bridges:Register("OpenerA", {contract = 1, data = {windows = {openers = {
        slash = {"A1", ""}, globals = {"G1"},
        methods = {{get = function() return tableA end, key = "Open"}, {get = function() error("get boom") end, key = "Open"}},
        links = {{link = "addon:a", when = {loaded = "AbsentAddon"}}},
    }}}})
    and addon.API.RegisterAddonData("OpenerB", {windows = {openers = {
        slash = {"B1"}, globals = {"G2"}, methods = {{get = function() return nil end, key = "Show"}},
    }}}))
local observed = {}
local function Observe(owner, key)
    local label = owner == SlashCmdList and "slash" or owner == _G and "_G" or owner == tableA and "A" or tostring(owner)
    observed[#observed + 1] = label .. "." .. key
end
for _, kind in ipairs({"slash", "globals", "methods", "unknown"}) do Bridges:ObserveWindowOpeners(kind, Observe) end
assert(table.concat(observed, ",") == "slash.A1,slash.B1,_G.G1,_G.G2,A.Open,nil.Show",
    "openers must be observed by kind in registration order, skipping empty keys and failed getters")
assert(Bridges.errors.OpenerA and Bridges.errors.OpenerA:find("get boom", 1, true), "a throwing getter must be recorded")
local savedAddOns = C_AddOns
C_AddOns = {IsAddOnLoaded = function(name) return name == "LinkAddon" end}
assert(Bridges:HasWindowOpenerLinks() == false and Bridges:IsWindowOpenerLink("addon:a") == true,
    "a link observer is wanted only while a link's detector passes")
addon.API.RegisterAddonData("OpenerC", {windows = {openers = {links = {{link = "addon:c", when = {loaded = "LinkAddon"}}}}}})
assert(Bridges:HasWindowOpenerLinks() == true and Bridges:IsWindowOpenerLink("addon:c") == true
    and Bridges:IsWindowOpenerLink("addon:x") == false and Bridges:IsWindowOpenerLink(nil) == false,
    "opener links must be told apart by their text")
C_AddOns, SlashCmdList = savedAddOns, savedSlash

-- RetireStalePlacements: registration order, bridges without it skipped, a
-- throwing bridge recorded, the same services table for every bridge.
addon, Bridges = Load()
local retired, retireServices = {}, {}
local retireA, retireB, retireC = {contract = 1}, {contract = 1}, {contract = 1}
function retireA:RetireStalePlacements(services) retired[#retired + 1] = services == retireServices and "A" or "A?" end
function retireB:RetireStalePlacements() error("retire boom") end
function retireC:RetireStalePlacements(services) retired[#retired + 1] = services == retireServices and "C" or "C?" end
assert(Bridges:Register("RetireA", retireA) and Bridges:Register("RetireB", retireB)
    and Bridges:Register("RetireD", {contract = 1}) and Bridges:Register("RetireC", retireC))
Bridges:RetireStalePlacements(retireServices)
assert(table.concat(retired, ",") == "A,C" and Bridges.errors.RetireB:find("retire boom", 1, true),
    "RetireStalePlacements must keep registration order, skip bridges without it and record a throw")

-- The addon window bridges: every catalog entry the core catalog held, the
-- window bridges registered in manifest order, the vendor gameplay frames and
-- the minimap report names.
local catalogFiles = {"ArkInventory/Bridge", "Baganator/Data", "Bagnaros/Bridge", "Bagnon/Bridge", "BagSmith/Bridge",
    "BetterBags/Data", "ClassicUIForever/Bridge", "DonCore/Bridge", "EllesmereUI/Bridge", "ElvUI/Bridge",
    "FlareUI/Bridge", "ForeverDungeonJournal/Bridge", "Leatrix/Settings", "MoveAny/Bridge", "OpenMap/Data",
    "Platynator/Bridge", "RestedXP/Bridge"}
for index, path in ipairs(catalogFiles) do catalogFiles[index] = "Bridges/" .. path .. ".lua" end
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
do
    local windows = {}
    assert(loadfile("Core/AddonWindowCatalog.lua"))("Offhand", windows)
    assert(next(windows.AddonWindowCatalog) == nil, "the core catalog must start empty")
    local catalogTable = windows.AddonWindowCatalog
    local registry = CoreBridges.Load(windows, catalogFiles)
    assert(windows.AddonWindowCatalog == catalogTable, "the bridges must fill the core catalog table in place")
    local SPECIAL = "workspace-special-windows"
    local expected = {
        Leatrix_Maps = {settings = {position = "addon", close = SPECIAL, opener = "Leatrix_Maps"},
            worldMap = {position = "addon", close = "map-adapter"}},
        Leatrix_Plus = {settings = {position = "addon", close = SPECIAL, opener = "Leatrix_Plus"}},
        Leatrix_Sounds = {settings = {position = "addon", close = SPECIAL, opener = "Leatrix_Sounds"}},
        Leveldon = {settings = {position = "addon", close = SPECIAL, opener = "LEVELDON"}},
        Questdon = {questBook = {position = "addon", close = SPECIAL, opener = "QUESTDON"}},
        Platynator = {settings = {position = "addon", close = SPECIAL, opener = "Platynator",
            learnPlacementFile = "customisedialog/main.lua"}},
        ForeverDungeonJournal = {journal = {position = "addon", close = SPECIAL, opener = "FOREVERDUNGEONJOURNAL",
            learnPlacementFile = "core/journal.lua"}},
        Baganator = {backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"}},
        Bagnon = {inventory = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"}},
        EllesmereUIBags = {backpack = {position = "adapter", close = "bag-adapter", restoreOpen = "adapter"}},
        BetterBags = {backpack = {position = "addon", close = "native"}, bank = {position = "addon", close = "native"}},
        RXPGuides = {guide = {position = "addon", close = "native"}},
        OpenMap = {worldMap = {position = "addon", close = "map-adapter"}},
        MoveAny = {worldMap = {position = "addon", close = "map-adapter"}},
        ClassicUIForever = {worldMap = {position = "addon", close = "native"},
            character = {position = "addon", close = "native"}},
        EllesmereUI = {suitePrefix = "ellesmereui", hud = {position = "addon", close = "native"}},
        ElvUI = {suitePrefix = "elvui", hud = {position = "addon", close = "native"}},
        FlareUI = {suitePrefix = "flareui", hud = {position = "addon", close = "native"}},
        ArkInventory = {inventory = {position = "adapter", close = "bag-adapter"}},
        BagSmith = {inventory = {position = "adapter", close = "bag-adapter"}},
        Bagnaros = {inventory = {position = "adapter", close = "bag-adapter"}},
    }
    assert(Same(windows.AddonWindowCatalog, expected), "the bridges must supply exactly the former core catalog")
    assert(table.concat(registry:List(), ",") == "DonCore,ForeverDungeonJournal,Leatrix,Platynator",
        "only the four window bridges may register bridge objects, in manifest order")
    for _, id in ipairs(registry:List()) do
        assert(registry:Get(id).catalog == nil, id .. " must keep its catalog in data, not bridge.catalog")
    end
    assert(table.concat(registry:GetRuleNames("unsavedPosition"), ",") == "RXPFrame,RXPItemFrame"
        and registry:MatchName("unsavedPosition", "RXPFrame") and not registry:MatchName("unsavedPosition", "LeveldonPanel"),
        "only the RestedXP guide frames must be kept out of saved positions")
    assert(table.concat(registry:GetRuleNames("minimapDiagnosticFrame"), ",") == "LibDBIcon10_ForeverDungeonJournal",
        "the journal's minimap button must be named for the minimap report")

    local savedAddOns, savedUIParent = C_AddOns, UIParent
    UIParent = {}
    local loaded = {}
    C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
    local escape = windows
    escape.isForever = true
    assert(loadfile("Core/CanvasAddonEscape.lua"))("Offhand", escape)
    local adapter = escape.CanvasAddonEscape
    local guide = {_isStylePanel = true, ApplySettings = function() end}
    function guide:GetParent() return UIParent end
    function guide:IsShown() return true end
    guide._header = {GetParent = function() return guide end}
    local arrow = {icon = {}, shadow = {}, glow = {}, IsShown = guide.IsShown, GetParent = guide.GetParent}
    function arrow:GetObjectType() return "Button" end
    _G.LeveldonPanel, _G.DonMapArrow = guide, arrow
    assert(not adapter:IsVendorGameplayFrame(guide, "LeveldonPanel"), "an unloaded Leveldon guide must not count")
    loaded.Leveldon, loaded.DonMap = true, true
    assert(adapter:IsVendorGameplayFrame(guide, "LeveldonPanel") == true
        and adapter:IsVendorGameplayFrame(arrow, "DonMapArrow") == true,
        "the Leveldon guide and the DonMap arrow must be vendor gameplay frames on Forever")
    assert(not adapter:IsVendorGameplayFrame(arrow, "LeveldonPanel") and not adapter:IsVendorGameplayFrame({}, "DonMapArrow")
        and not adapter:IsVendorGameplayFrame(nil, "DonMapArrow"), "the Don frames must be the globals of their shape")
    assert(registry:MatchFrame("preservePopup", guide, "LeveldonPanel"), "popup recovery must keep the vendor gameplay frames")
    escape.isForever = false
    assert(not adapter:IsVendorGameplayFrame(guide, "LeveldonPanel"), "the Don frames count on Forever only")
    local rxp = {}
    _G.RXPFrame = rxp
    assert(adapter:IsVendorGameplayFrame(nil, "RXPItemFrame") == true and adapter:IsVendorGameplayFrame(rxp, nil) == true
        and adapter:IsVendorGameplayFrame(rxp, "Other") == true and not adapter:IsVendorGameplayFrame({}, "Other"),
        "the RestedXP frames count by name or as those globals on every client")
    assert(registry:MatchFrame("preservePopup", rxp, "Other"), "popup recovery must keep the RestedXP globals too")
    _G.LeveldonPanel, _G.DonMapArrow, _G.RXPFrame = nil, nil, nil

    -- Opener installation keeps the former order: catalog slash openers, the
    -- shared slash command, the compartment callback, Offhand's options, the
    -- DonCore options window, then the settings link observer.
    escape.isForever, escape.db = true, {enabled = true}
    escape.Viewport = {GetMetrics = function() return {isSpanned = false} end}
    local savedSlash, savedHook, savedRegistry, savedLibStub = SlashCmdList, hooksecurefunc, EventRegistry, LibStub
    SlashCmdList, UISpecialFrames = {}, {}
    local function Opener() end
    for _, key in ipairs({"Leatrix_Maps", "Leatrix_Plus", "Leatrix_Sounds", "LEVELDON", "QUESTDON", "Platynator",
        "FOREVERDUNGEONJOURNAL", "DONCORE"}) do SlashCmdList[key] = Opener end
    _G.Platynator_AddonCompartmentCallback = Opener
    local donOptions = {Open = Opener}
    LibStub = function(library) if library == "DonCore-1.0" then return {Get = function() return donOptions end} end end
    escape.Options = {Open = Opener}
    local hooked, linked = {}, 0
    hooksecurefunc = function(owner, key)
        hooked[#hooked + 1] = (owner == SlashCmdList and "slash." or owner == _G and "_G."
            or owner == escape.Options and "options." or owner == donOptions and "don." or "?.") .. key
    end
    EventRegistry = {RegisterCallback = function(_, event) if event == "SetItemRef" then linked = linked + 1 end end}
    loaded.Platynator = true
    adapter:Refresh()
    local tail = {}
    for index = 8, #hooked do tail[#tail + 1] = hooked[index] end
    local catalogOpeners = {}
    for index = 1, 7 do catalogOpeners[hooked[index]] = true end
    assert(#hooked == 11 and catalogOpeners["slash.Leatrix_Maps"] and catalogOpeners["slash.Leatrix_Plus"]
        and catalogOpeners["slash.Leatrix_Sounds"] and catalogOpeners["slash.LEVELDON"] and catalogOpeners["slash.QUESTDON"]
        and catalogOpeners["slash.Platynator"] and catalogOpeners["slash.FOREVERDUNGEONJOURNAL"]
        and table.concat(tail, ",") == "slash.DONCORE,_G.Platynator_AddonCompartmentCallback,options.Open,don.Open"
        and linked == 1, "openers must install in the former order: " .. table.concat(hooked, ","))
    adapter:Refresh()
    assert(#hooked == 11 and linked == 1, "openers and the link observer must install once")
    SlashCmdList, hooksecurefunc, EventRegistry, LibStub = savedSlash, savedHook, savedRegistry, savedLibStub
    _G.Platynator_AddonCompartmentCallback, UISpecialFrames = nil, nil

    -- Sourceless names are identified without reading the source: the journal
    -- and the DonCore options window, here with a source that throws.
    local function Root(fields)
        fields.IsShown, fields.GetParent = function() return true end, function() return UIParent end
        fields.GetSourceLocation = function() error("no source access") end
        return fields
    end
    local journal = Root({})
    loaded.ForeverDungeonJournal = true
    assert(adapter:CanLearnPlacement(journal, "ForeverDungeonJournalFrame", "ForeverDungeonJournal", "core/journal.lua")
        == true, "the journal must be identified by name before any source is read")
    local options = Root({})
    donOptions.Frame = function() return options end
    LibStub = function(library) if library == "DonCore-1.0" then return {Get = function() return donOptions end} end end
    assert(registry:IdentifyWindow(options, "DonCoreOptions", function() error("source read") end) == "Leveldon",
        "the DonCore options window must be identified by name before any source is read")
    LibStub = savedLibStub

    -- Close buttons: Leatrix Plus helper X buttons in child order.
    local plus = {GetNumChildren = function() return 3 end}
    local function X(x)
        return {GetObjectType = function() return "Button" end, GetParent = function() return plus end,
            GetPoint = function() return "TOPRIGHT", plus, "TOPRIGHT", x, 0 end,
            GetSourceLocation = function() return "Interface\\AddOns\\Leatrix_Plus\\Leatrix_Plus.lua:9" end,
            GetWidth = function() return 30 end, GetHeight = function() return 30 end}
    end
    local first, other, second = X(0), X(-40), X(0)
    plus.GetChildren = function() return first, other, second end
    local found = registry:GetWindowCloseButtons(plus, "Leatrix_Plus", "F2222222222222222")
    assert(#found == 2 and found[1] == first and found[2] == second, "Leatrix X buttons must come out in child order")
    plus.c = {}
    assert(registry:GetWindowCloseButtons(plus, "Leatrix_Plus")[1] == plus.c
        and registry:GetWindowCloseButtons({cb = 1}, "Leatrix_Sounds")[1] == 1,
        "a named Leatrix close button wins over the child scan")
    C_AddOns, UIParent = savedAddOns, savedUIParent

    -- The minimap visibility report keeps the journal's button third, absent or not.
    local report = {db = {}}
    assert(loadfile("Core/HUDRecovery.lua"))("Offhand", report)
    CoreBridges.Load(report, {"Bridges/ForeverDungeonJournal/Bridge.lua"})
    local lines = report.HUDRecovery.GetMinimapVisibilityDiagnostics()
    assert(lines[2] == "MinimapCluster.state=absent" and lines[3] == "Minimap.state=absent"
        and lines[4] == "LibDBIcon10_ForeverDungeonJournal.state=absent" and lines[5] == "LFGMinimapFrame.state=absent"
        and lines[6] == "QueueStatusButton.state=absent" and #lines == 6,
        "the minimap report must list the journal's button between the minimap and the queue buttons")
end

-- GetRoleEntry finds an entry by name, present or not; diagnostic segments
-- report whether each detector passes.
addon, Bridges = Load()
addon.API.RegisterAddonData("RoleA", {
    ownership = {{role = "facts", name = "First", order = 20, detect = {global = "AbsentGlobal"}, flag = 1},
        {role = "facts", name = "Second", order = 10, flag = 2}},
    diagnostics = {{slot = "probe", order = 20, label = "Off", detect = {global = "AbsentGlobal"}},
        {slot = "probe", order = 10, label = "On", detect = {}}, {slot = "probe", order = 30, label = "Plain"}},
})
assert(Bridges:GetRoleEntry("facts", "First").flag == 1 and Bridges:GetRoleEntry("facts", "Second").flag == 2
    and Bridges:GetRoleEntry("facts", "Third") == nil and Bridges:GetRoleEntry("none", "First") == nil,
    "GetRoleEntry must find an entry by name whether or not its owner is present")
do
    local entries, present = Bridges:GetDiagnosticSegments("probe")
    assert(entries[1].label == "On" and entries[2].label == "Off" and entries[3].label == "Plain"
        and present[1] == true and present[2] == false and present[3] == false,
        "diagnostic segments must come in order with whether each detector passes")
end

-- World map owners: map.owner and map.fade are first-wins in fixed orders, and
-- their facts, yield frames, panel roles, integration order and diagnostics
-- reproduce what the core held.
do
    local maps = {AddonWindowCatalog = {}}
    local loaded = {}
    local savedAddOns = C_AddOns
    C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", maps)
    local registry = CoreBridges.Load(maps, {"Bridges/BlizzMove/Bridge.lua", "Bridges/ClassicUIForever/Bridge.lua",
        "Bridges/Leatrix/Maps.lua", "Bridges/Leatrix/Settings.lua", "Bridges/MapUtils/Bridge.lua",
        "Bridges/MapWise/Data.lua", "Bridges/MapWise/Bridge.lua", "Bridges/MoveAny/Bridge.lua", "Bridges/OpenMap/Data.lua", "Bridges/OpenMap/Contract.lua",
        "Bridges/OpenMap/Recovery.lua", "Bridges/OpenMap/Map.lua", "Bridges/OpenMap/Init.lua"})
    assert(table.concat(registry:List(), ",") == "Leatrix,MapWise,OpenMap",
        "only the Leatrix, MapWise and OpenMap bridges may register bridge objects among the map addons")
    local compat = maps.CanvasCompatibility
    local function Combinations(names, check)
        for mask = 0, 2 ^ #names - 1 do
            loaded = {}
            local present = {}
            for index, name in ipairs(names) do
                if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
                    loaded[name] = true
                    present[#present + 1] = name
                end
            end
            check(present, table.concat(present, "+"))
        end
    end
    local ownerNames = {MoveAny = "MoveAny", ClassicUIForever = "ClassicUIForever", OpenMap = "OpenMap",
        Leatrix_Maps = "LeatrixMaps"}
    Combinations({"MoveAny", "ClassicUIForever", "OpenMap", "Leatrix_Maps"}, function(present, label)
        local expected = present[1] and ownerNames[present[1]]
        local owner = compat.GetWorldMapExternalOwner()
        assert(owner == (expected or nil), "map owner for " .. label .. ": " .. tostring(owner))
        assert(compat.ShouldYieldWorldMap("WorldMapFrame") == (expected ~= nil),
            "the map must yield exactly while it has an owner: " .. label)
        assert(compat.IsExternallyPositionedWorldMap("WorldMapFrame")
            == (expected == "OpenMap" or expected == "LeatrixMaps"), "positioned map for " .. label)
        maps.isForever = true
        assert(not not compat.SupportsExternalWorldMapEscapeProtection("WorldMapFrame")
            == (expected == "OpenMap" or expected == "LeatrixMaps" or expected == "MoveAny"),
            "Forever escape protection for " .. label)
        maps.isForever = nil
        assert(not not compat.SupportsExternalWorldMapEscapeProtection("WorldMapFrame")
            == (expected == "OpenMap" or expected == "LeatrixMaps"), "escape protection for " .. label)
        assert(compat.HasPanelManagementOwner() == (loaded.MoveAny or loaded.ClassicUIForever or false)
            and compat.HasPanelSlotRepairOwner() == (loaded.MoveAny or false)
            and compat.HasWorldMapConfigurationOwner() == (loaded.Leatrix_Maps or false),
            "panel and configuration roles for " .. label)
        assert(compat.ShouldYieldFrameToExternalOwner("CharacterFrame") == (loaded.ClassicUIForever or false)
            and compat.ShouldYieldFrameToExternalOwner({GetName = function() return "WorldMapFrame" end})
                == (loaded.ClassicUIForever or false)
            and not compat.ShouldYieldFrameToExternalOwner("SpellBookFrame"), "yield frames for " .. label)
    end)
    Combinations({"OpenMap", "MapUtils", "MapWise", "Leatrix_Maps"}, function(present, label)
        assert(compat.GetWorldMapFadeAddon() == present[1], "fade addon for " .. label)
    end)
    loaded = {}
    MoveAnything = {}
    assert(compat.GetWorldMapExternalOwner() == "MoveAny" and compat.HasPanelManagementOwner(),
        "a MoveAnything global must make MoveAny the owner")
    MoveAnything = nil
    loaded = {MoveAnything = true, ClassicUIForever = true}
    assert(compat.GetWorldMapExternalOwner() == "MoveAny"
        and table.concat(compat.GetExternalOwnerFrames(), ",") == "WorldMapFrame,CharacterFrame",
        "a loaded MoveAnything must win the map while ClassicUI Forever keeps its frames")
    assert(compat.GetActiveExternalOwners().map == "MoveAny", "the MoveAny label is its name")
    loaded = {ClassicUIForever = true}
    assert(compat.GetActiveExternalOwners().map == "ClassicUI Forever", "the ClassicUI Forever label changed")
    loaded = {Leatrix_Maps = true}
    assert(compat.GetActiveExternalOwners().map == "Leatrix Maps", "the Leatrix Maps label changed")

    -- Diagnostics strings, byte for byte.
    loaded = {}
    assert(compat.GetDiagnostics(true) == "WorldMapOwner=Offhand | LeatrixMaps=absent | OpenMap=absent"
        and compat.GetDiagnostics(false) == "MoveAny=absent | WorldMapOwner=Offhand",
        "diagnostics without a map owner changed")
    loaded = {Leatrix_Maps = true}
    assert(compat.GetDiagnostics(false) == "MoveAny=absent | WorldMapOwner=LeatrixMaps | LeatrixMaps=loaded | CoordinateFontRefresh=pending"
        and compat.GetDiagnostics(false, 4) == "MoveAny=absent | WorldMapOwner=LeatrixMaps | LeatrixMaps=loaded | CoordinateFontRefresh=4"
        and compat.GetDiagnostics(true) == "WorldMapOwner=LeatrixMaps | LeatrixMaps=loaded | OpenMap=absent",
        "Leatrix Maps diagnostics changed")
    loaded = {OpenMap = true}
    assert(compat.GetDiagnostics(true) == "WorldMapOwner=OpenMap | LeatrixMaps=absent | OpenMap=loaded",
        "OpenMap compact diagnostics changed")
    loaded = {ClassicUIForever = true, Leatrix_Maps = true}
    assert(compat.GetDiagnostics(false, 2) == "MoveAny=absent | ClassicUIForever=loaded | WorldMapOwner=ClassicUIForever"
        .. " | CharacterFrameOwner=ClassicUIForever | LeatrixMaps=loaded | CoordinateFontRefresh=2",
        "ClassicUI Forever diagnostics changed")
    loaded = {MoveAny = true, ClassicUIForever = true}
    assert(compat.GetDiagnostics(false) == "MoveAny=loaded | ClassicUIForever=loaded | WorldMapOwner=MoveAny"
        .. " | CharacterFrameOwner=ClassicUIForever", "MoveAny diagnostics changed")

    -- Map integrations keep the former core order, then the bridges' mapAddons.
    loaded = {OpenMap = true, MapWise = true, MapUtils = true, Leatrix_Maps = true, BlizzMove = true,
        MoveAny = true, MoveAnything = true, ClassicUIForever = true}
    OpenMap, MapWiseAPI = {version = "v0.9"}, {version = "2.4"}
    assert(compat.GetMapIntegrationDiagnostics() == "OpenMap=v0.9 | MapWise=2.4 | MapUtils=unknown version"
        .. " | Leatrix_Maps=unknown version | BlizzMove=unknown version | MoveAny=unknown version"
        .. " | MoveAnything=unknown version | ClassicUIForever=unknown version", "map integration order changed")
    OpenMap, MapWiseAPI = nil, nil

    -- OpenMap: one bridge object with the map provider, its fade entry, the
    -- recovermap command and the World Map card controls.
    local openMap = registry:Get("OpenMap")
    local maxScale, scaleStep = registry:CallMap("OpenMap", "GetScaleRange")
    assert(openMap.mapProvider.owner == "OpenMap" and maxScale == 1.6 and scaleStep == .05
        and registry:CallMap("MoveAny", "GetScaleRange") == nil, "the OpenMap provider must answer only for OpenMap")
    local fade = registry:GetRoleEntry("map.fade", "OpenMap")
    assert(type(fade.read) == "function" and fade.key == "moveFade" and fade.opaque == 0
        and type(fade.refresh) == "function" and fade.helpKey == "MAP_MOVEMENT_OPENMAP",
        "the OpenMap fade entry must carry its reader, key, no-fade value, refresh and help")
    local printed = {}
    maps.L = setmetatable({}, {__index = function(_, key) return key end})
    maps.Print = function(_, text) printed[#printed + 1] = text end
    local savedCombat, savedTrim = InCombatLockdown, strtrim
    InCombatLockdown = function() return false end
    strtrim = function(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
    assert(registry:RunSlashCommand("recovermap", "") and registry:RunSlashCommand("recovermap", " offhand ")
        and printed[1] == "OPENMAP_RECOVERY_UNAVAILABLE" and printed[2] == "OPENMAP_RECOVERY_UNAVAILABLE"
        and registry.errors.OpenMap == nil, "recovermap must run OpenMap's recovery and report")
    local coreCommands = {}
    for name in assert(io.open("Core/Init.lua", "rb")):read("*a"):gmatch('cmd == "([%w_]+)"') do coreCommands[name] = true end
    assert(coreCommands.window and coreCommands.centerline, "the core command scan must find the slash handler")
    for _, id in ipairs(registry:List()) do
        for name in pairs(registry:Get(id).slashCommands or {}) do
            assert(not coreCommands[name], id .. " must not shadow the core command " .. name)
        end
    end
    maps.isForever = nil
    assert(#(openMap:GetSettingsContributions("map") or {}) == 0, "the OpenMap recovery buttons exist on Forever only")
    maps.isForever = true
    local buttons = openMap:GetSettingsContributions("map")
    local title = openMap:GetSettingsContributions("mapScaleTitle")[1]
    local prefix = openMap:GetSettingsContributions("mapDescription")[1]
    assert(#buttons == 2 and buttons[1].kind == "button" and buttons[1].text == "OPENMAP_RECOVERY_BUTTON"
        and buttons[1].tooltip == "OPENMAP_RECOVERY_TIP" and buttons[1].height == 30
        and buttons[2].text == "OPENMAP_WORKSPACE_BUTTON" and buttons[2].tooltip == nil and buttons[2].height == 36
        and buttons[1].owner == "OpenMap" and buttons[2].addon == "OpenMap",
        "the OpenMap buttons must keep their texts, tooltip and 66 units of height")
    assert(title.kind == "suffix" and title.text == " (OpenMap)" and title.help == "MAP_SCALE_OPENMAP_HELP"
        and prefix.kind == "prefix" and prefix.text == "OPENMAP_WORKSPACE_HELP" and prefix.owner == "OpenMap",
        "the OpenMap scale title and description must keep their texts")

    -- The contract notice, its wording and the Forever diagnostics.
    maps.L = {}
    loaded = {OpenMap = true}
    OpenMap = {version = "v1", GetModule = function() end}
    OpenMapAPI = {major = 2, version = 5}
    local conflicts = compat.GetOwnershipConflicts()
    assert(#conflicts == 1 and conflicts[1].id == "openmap-contract:unsupported-major"
        and conflicts[1].kind == "openmap-contract" and conflicts[1].reason == "unsupported-major",
        "a breaking OpenMap contract must be one notice")
    assert(compat.FormatConflictMessage(conflicts[1]) == "Notice: OpenMap updated to an unsupported contract"
        .. " (unsupported-major). Offhand stood down its OpenMap drag sync and recovery helpers.",
        "the OpenMap contract notice wording changed")
    OpenMapDB = {worldmap = {}}
    assert(compat.GetDiagnostics(false) == "MoveAny=absent | WorldMapOwner=OpenMap | OpenMap=v1 | MapFPSCap=unavailable"
        .. " | maxFPS=unavailable | OpenMapWindow=none | OpenMapContract=unsupported-major"
        .. " | Conflicts=openmap-contract:unsupported-major", "the Forever OpenMap diagnostics changed")
    maps.isForever = nil
    assert(#compat.GetOwnershipConflicts() == 0 and compat.GetDiagnostics(false) == "MoveAny=absent | WorldMapOwner=OpenMap",
        "the OpenMap notice and diagnostics are Forever only")
    OpenMap, OpenMapAPI, OpenMapDB = nil, nil, nil
    InCombatLockdown, strtrim = savedCombat, savedTrim
    C_AddOns = savedAddOns
end

-- MapUtils, MapWise and Leatrix Maps: the fade readers in the former order,
-- each with its Options help, the MapWise layout guard roles and provider,
-- and the Leatrix coordinate label refresh behind the configuration owner.
do
    local maps = {AddonWindowCatalog = {}}
    local loaded = {}
    local savedAddOns, savedCombat = C_AddOns, InCombatLockdown
    C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
    InCombatLockdown = function() return false end
    local registry = CoreBridges.Load(maps, {"Bridges/Leatrix/Maps.lua", "Bridges/Leatrix/Settings.lua",
        "Bridges/MapUtils/Bridge.lua", "Bridges/MapWise/Data.lua", "Bridges/MapWise/Bridge.lua",
        "Bridges/OpenMap/Data.lua", "Bridges/OpenMap/Contract.lua", "Bridges/OpenMap/Recovery.lua",
        "Bridges/OpenMap/Map.lua", "Bridges/OpenMap/Init.lua"})
    local readers, helps = {}, {}
    for _, entry in ipairs(registry:GetRoleEntries("map.fade")) do
        if type(entry.read) == "function" then readers[#readers + 1] = entry.name end
        helps[#helps + 1] = entry.name .. "=" .. tostring(entry.helpKey)
    end
    assert(table.concat(readers, ",") == "OpenMap,MapUtils,MapWise"
        and table.concat(helps, ",") == "OpenMap=MAP_MOVEMENT_OPENMAP,MapUtils=MAP_MOVEMENT_MAPUTILS,"
            .. "MapWise=MAP_MOVEMENT_MAPWISE,Leatrix_Maps=nil",
        "the fade readers and their help must keep the former order")
    local mapUtils = registry:GetRoleEntry("map.fade", "MapUtils")
    local mapWise = registry:GetRoleEntry("map.fade", "MapWise")
    assert(mapUtils.key == "WORLDMAPFADE" and mapUtils.opaque == false and mapUtils.refresh == nil
        and mapWise.key == "fadeMapWhileMoving" and mapWise.opaque == false, "the fade keys changed")
    assert(registry:Get("MapWise").mapProvider.owner == "MapWise"
        and type(registry:Get("MapWise").mapProvider.InstallPositionGuard) == "function"
        and type(registry:Get("MapWise").mapProvider.UpdateLayout) == "function",
        "the MapWise guard must be its provider")
    assert(not registry:HasRole("map.layoutGuard") and not registry:HasRole("map.blocksCombatAnchorRepair"),
        "the MapWise roles need MapWise")
    MapWiseAPI = {}
    assert(registry:FirstRoleOwner("map.layoutGuard") == "MapWise", "MapWiseAPI must install the MapWise guard")
    MapWiseAPI = nil
    loaded.MapWise = true
    assert(registry:HasRole("map.blocksCombatAnchorRepair"), "a loaded MapWise keeps the combat anchor")
    MAUTTAB = {WORLDMAPFADE = true}
    loaded.MapUtils = true
    C_AddOns.GetAddOnMetadata = function(name) return name == "MapUtils" and "1.7.0" or nil end
    assert(mapUtils.read() == MAUTTAB, "a MapUtils 1.x fade preference must be read")
    C_AddOns.GetAddOnMetadata = function() return "2.0.0" end
    assert(mapUtils.read() == nil, "another MapUtils major version keeps its setting")
    MAUTTAB = nil

    -- The coordinate label refresh: the configuration owner's provider, with
    -- its last count in the compatibility line.
    maps.CanvasCompatibility = {}
    maps.CanvasFrameState = {IsEvicting = function() return false end}
    assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", maps)
    local canvas = {}
    maps.CanvasMapPresentation.InstallFonts(canvas, {})
    local refreshed = 0
    local function Label(text)
        return {GetObjectType = function() return "FontString" end, GetText = function() return text end,
            GetFont = function() return "font", 12, "" end, SetFont = function() refreshed = refreshed + 1 end}
    end
    local savedMap = WorldMapFrame
    WorldMapFrame = {overlayFrames = {{PlayerCoords = {Label = Label("1, 2")}, CursorCoords = {Label = Label("3, 4")}}}}
    assert(canvas:RefreshExternalMapCoordinateFonts() == 0 and refreshed == 0
        and canvas._lastExternalCoordinateFontRefreshCount == nil, "without Leatrix Maps nothing is refreshed")
    loaded.Leatrix_Maps = true
    assert(registry:Get("Leatrix").mapProvider.owner == "LeatrixMaps"
        and canvas:RefreshExternalMapCoordinateFonts() == 2 and refreshed == 2
        and canvas._lastExternalCoordinateFontRefreshCount == 2, "the Leatrix coordinate labels must be refreshed")
    InCombatLockdown = function() return true end
    assert(canvas:RefreshExternalMapCoordinateFonts() == 0 and refreshed == 2, "no refresh in combat")
    local fallback = registry:Get("Leatrix"):GetSettingsContributions("mapDescription")[1]
    assert(fallback.kind == "fallback" and fallback.addon == "Leatrix_Maps",
        "the Leatrix Maps description must be a fallback while Leatrix Maps is loaded")
    WorldMapFrame, C_AddOns, InCombatLockdown = savedMap, savedAddOns, savedCombat
end

-- Map provider services: viewport metrics, the workspace region and the
-- workspace panel persistence preference, read as core reads them.
addon, Bridges = Load()
assert(addon.API.GetViewportMetrics() == nil and addon.API.GetWorkspaceRegion({}) == nil
    and addon.API.KeepsWorkspacePanelsOpen() == true, "the map services must be safe before the core loads")
local viewportMetrics, region = {isSpanned = true}, {x = 1}
addon.Viewport = {GetMetrics = function() return viewportMetrics end}
addon.WorkspaceRegions = {Get = function(_, metrics) return metrics == viewportMetrics and region or nil end}
addon.db = {persistentWorkspacePanels = false}
assert(addon.API.GetViewportMetrics() == viewportMetrics and addon.API.GetWorkspaceRegion(viewportMetrics) == region
    and addon.API.KeepsWorkspacePanelsOpen() == false, "the map services must read the live core state")
addon.db.persistentWorkspacePanels = nil
assert(addon.API.KeepsWorkspacePanelsOpen() == true, "only an explicit false closes workspace panels")

-- Bag owners, bag name rules, the custom bag workspace record and the bag
-- providers reproduce what the core held.
do
    local bagFiles = {"Bridges/AdiBags/Bridge.lua", "Bridges/ArkInventory/Bridge.lua", "Bridges/ArkInventory/Bags.lua",
        "Bridges/Baganator/Data.lua", "Bridges/Bagnaros/Bridge.lua", "Bridges/Bagnaros/Bags.lua",
        "Bridges/Bagnon/Bridge.lua", "Bridges/Bagnon/Bags.lua", "Bridges/BagSmith/Bridge.lua", "Bridges/BagSmith/Bags.lua",
        "Bridges/BetterBags/Data.lua", "Bridges/BetterBags/Bags.lua", "Bridges/EllesmereUI/Bridge.lua",
        "Bridges/EllesmereUI/Bags.lua", "Bridges/ElvUI/Bridge.lua", "Bridges/ElvUI/Bags.lua",
        "Bridges/Inventorian/Bridge.lua", "Bridges/MoveMyBags/Bridge.lua", "Bridges/Tukui/Bridge.lua"}
    local bags = {AddonWindowCatalog = {}}
    local loaded = {}
    local savedAddOns, savedFrame1 = C_AddOns, ContainerFrame1
    C_AddOns = {IsAddOnLoaded = function(name) return loaded[name] == true end}
    assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", bags)
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", bags)
    local registry = CoreBridges.Load(bags, bagFiles)
    assert(table.concat(registry:List(), ",") == "ArkInventory,Bagnaros,Bagnon,BagSmith,BetterBags,EllesmereUIBags,ElvUI",
        "only the bag provider files may register bridge objects among the bag addons")
    local hud, compat = bags.HUDCompatibility, bags.CanvasCompatibility

    -- report.bags keeps the legacy order, which is part of the bags-conflict id.
    local LEGACY_BAGS = {"EllesmereUIBags", "MoveMyBags", "Baganator", "Bagnon", "ArkInventory", "BetterBags",
        "Bagnaros", "AdiBags", "Inventorian", "BagSmith", "ElvUI", "Tukui"}
    local parked = {GetName = function() return nil end, GetParent = function() return UIParent end,
        IsShown = function() return false end}
    ContainerFrame1 = {GetParent = function() return parked end}
    bags.isForever = true
    local function SetBagOwner(name, present)
        if name == "ElvUI" then
            ElvUI = present and {{private = {bags = {enable = true}}}} or nil
        elseif name == "Tukui" then
            Tukui = present and {nil, {Bags = {Enable = true}}} or nil
        else
            loaded[name] = present or nil
        end
    end
    local function BagConflictId()
        for _, conflict in ipairs(compat.GetOwnershipConflicts()) do
            if conflict.kind == "bags-conflict" then return conflict.id end
        end
    end
    for mask = 0, 2 ^ #LEGACY_BAGS - 1, 37 do
        local expected = {}
        for index, name in ipairs(LEGACY_BAGS) do
            local present = math.floor(mask / 2 ^ (index - 1)) % 2 == 1
            SetBagOwner(name, present)
            if present then expected[#expected + 1] = name end
        end
        local label = table.concat(expected, ",")
        assert(table.concat(compat.GetActiveBagOwners(), ",") == label, "bag owners for " .. label)
        assert(BagConflictId() == (#expected >= 2 and "bags-conflict:" .. table.concat(expected, "+") or nil),
            "the bags-conflict id must keep the legacy order for " .. label)
    end
    for _, name in ipairs(LEGACY_BAGS) do SetBagOwner(name, true) end
    assert(BagConflictId() == "bags-conflict:EllesmereUIBags+MoveMyBags+Baganator+Bagnon+ArkInventory+BetterBags+"
        .. "Bagnaros+AdiBags+Inventorian+BagSmith+ElvUI+Tukui", "every bag owner must keep the legacy conflict id")
    bags.Mainhand = {IsNativeGamepadInterface = function() return true end}
    assert(compat.GetActiveBagOwners()[1] == "MoveMyBags",
        "EllesmereUIBags must stand aside under the Forever native Gamepad interface")
    bags.Mainhand = nil
    for _, name in ipairs(LEGACY_BAGS) do SetBagOwner(name, false) end
    ElvUI = {{private = {bags = {enable = false}}}}
    assert(#compat.GetActiveBagOwners() == 0, "ElvUI with disabled bags must not be a bag owner")
    ElvUI = nil

    -- hud.bags: each legacy replacement test still owns the bags on its own.
    assert(not hud.HasCustomBagAddon(), "stock bags must remain available")
    local hudOwners = {
        {loaded = "EllesmereUIBags"}, {loaded = "MoveMyBags"}, {global = "MoveMyBags"}, {global = "Baganator"},
        {global = "Baginator"}, {global = "Bagnon"}, {global = "AdiBags"}, {global = "ArkInventory"},
        {global = "BetterBags"}, {loaded = "BetterBags"}, {global = "Inventorian"}, {global = "ElvUI"},
        {global = "Tukui"}, {loaded = "Bagnaros"}, {global = "Bagnaros"}, {loaded = "BagSmith"},
    }
    for _, owner in ipairs(hudOwners) do
        if owner.loaded then loaded[owner.loaded] = true else _G[owner.global] = {} end
        assert(hud.HasCustomBagAddon(), "bag owner " .. (owner.loaded or owner.global) .. " must own the bags")
        if owner.loaded then loaded[owner.loaded] = nil else _G[owner.global] = nil end
    end
    loaded.Baganator, loaded.Bagnon = true, true
    assert(not hud.HasCustomBagAddon(), "Baganator and Bagnon own the bags through their globals only")
    loaded.Baganator, loaded.Bagnon = nil, nil
    loaded.EllesmereUIBags = true
    bags.Mainhand = {IsNativeGamepadInterface = function() return true end}
    assert(not hud.HasCustomBagAddon(), "EllesmereUIBags must stand aside under the Forever native Gamepad interface")
    bags.isForever = false
    assert(hud.HasCustomBagAddon(), "the Gamepad stand-down applies on Forever only")
    loaded.BagSmith = true
    assert(table.concat(compat.GetActiveBagOwners(), ",") == "EllesmereUIBags",
        "BagSmith's parked backpack counts on Forever only")
    loaded.BagSmith, loaded.EllesmereUIBags, bags.Mainhand = nil, nil, nil
    assert(registry:HasRole("bags.selfRestoring") == false, "no self-restoring bag addon without its global")
    Baganator = {}
    assert(registry:HasRole("bags.selfRestoring") == true, "Baganator restores its own roots while its global exists")
    Baganator = nil

    -- Bag name rules keep the legacy lists, which differ on purpose.
    local function Any(name, patterns)
        for _, pattern in ipairs(patterns) do
            if name:match(pattern) then return true end
        end
        return false
    end
    local legacy = {
        ["bagNamespace.openScan"] = function(name) return Any(name, {"^Baganator", "^Baginator", "^BGR", "^Bagnon",
            "^AdiBags", "^BetterBags", "^ArkInventory", "^ElvUI_ContainerFrame"}) end,
        ["bagNamespace.logoutScan"] = function(name) return Any(name, {"^Baganator", "^Baginator", "^Bagnon",
            "^AdiBags", "^BetterBags", "^ArkInventory", "^ElvUI_ContainerFrame"}) end,
        ["bagNamespace.recoveryAnchor"] = function(name) return Any(name, {"Baganator", "Baginator", "Bagnon",
            "BetterBags"}) end,
        bagRestorable = function(name) return name == "EUI_MainBagFrame" or Any(name, {
            "^Baganator_SingleViewBackpackViewFrame", "^Baganator_CategoryViewBackpackViewFrame", "^Baginator", "^BGR",
            "^Bagnon", "^AdiBags", "^BetterBags", "^ArkInventory"}) end,
        customBagRoot = function(name) return name == "EUI_MainBagFrame" or Any(name, {"^Baganator_.*BackpackViewFrame"}) end,
        selfManagedBag = function(name) return name == "EUI_MainBagFrame" or name == "EUI_ReagentBagFrame"
            or name == "EUI_BagsWindowFrame" end,
    }
    local samples = {"BaganatorX", "Baganator_SingleViewBackpackViewFrame1", "Baganator_CategoryViewBackpackViewFrameA",
        "Baganator_SingleViewBankViewFrame", "XBaganator", "BaginatorMain", "BGR_Main", "xBGR", "BagnonInventory",
        "MyBagnon", "AdiBagsContainer", "XAdiBags", "BetterBagsBag", "SomeBetterBags", "ArkInventoryFrame",
        "ElvUI_ContainerFrame", "ElvUI_ContainerFrameBag1", "ElvUI_Bar1", "EUI_MainBagFrame", "EUI_ReagentBagFrame",
        "EUI_BagsWindowFrame", "ContainerFrame1", "ContainerFrameCombinedBags", "CustomBagRestorer", "WorldMapFrame"}
    for rule, check in pairs(legacy) do
        for _, name in ipairs(samples) do
            assert(registry:MatchName(rule, name) == check(name), rule .. " changed for " .. name)
        end
    end
    bags.isForever = true
    assert(compat.IsForeverSelfManagedBag("EUI_ReagentBagFrame") and not compat.IsForeverSelfManagedBag("ContainerFrame1"),
        "the self-managed bag roots must yield on Forever")
    bags.isForever = false
    assert(not compat.IsForeverSelfManagedBag("EUI_MainBagFrame"), "the self-managed bag roots yield on Forever only")
    local chromeNames = table.concat(registry:GetRuleNames("workspaceChrome"), ",")
    assert(chromeNames:find("EUI_MainBagFrame", 1, true), "the EllesmereUI backpack keeps its workspace close buttons")

    -- The custom bag workspace record keeps its stored key: a record saved
    -- under it reads back through the declared setting, EllesmereUI's first.
    assert(registry:GetSettingKey("customBagWorkspacePanels") == "baganatorWorkspacePanels"
        and registry:GetSettingKey("unknownSetting") == nil, "the custom bag record must keep its stored key")
    local persisted = {AddonWindowCatalog = {}, isForever = true}
    local savedCreate, savedTimer = CreateFrame, C_Timer
    CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    C_Timer = {After = function() end, NewTicker = function() return {} end}
    local euiPosition, baganatorPosition = {x = 10, y = 20}, {x = 30, y = 40}
    persisted.db = {enabled = true, baganatorWorkspacePanels = {
        Baganator_SingleViewBackpackViewFrameElvUI = baganatorPosition, EUI_MainBagFrame = euiPosition}}
    assert(loadfile("Core/BagPersistence.lua"))("Offhand", persisted)
    CoreBridges.Load(persisted, {"Bridges/Baganator/Data.lua", "Bridges/EllesmereUI/Bags.lua"})
    local savedName, savedPosition = persisted.BagPersistence:GetSavedPosition()
    assert(savedName == "EUI_MainBagFrame" and savedPosition == euiPosition,
        "the EllesmereUI entry of the record saved under the old key must read back first")
    persisted.BagPersistence:ForgetOpenSnapshot("EUI_MainBagFrame")
    savedName, savedPosition = persisted.BagPersistence:GetSavedPosition()
    assert(persisted.db.baganatorWorkspacePanels.EUI_MainBagFrame == nil
        and savedName == "Baganator_SingleViewBackpackViewFrameElvUI" and savedPosition == baganatorPosition,
        "forgetting an entry must write the record under the old key")
    CreateFrame, C_Timer = savedCreate, savedTimer

    -- Bag providers: Escape adapters run by provider order around the bridges'
    -- own RefreshBags, one pcall each; notices, toggle actions and close buttons.
    local dispatch = Load()
    local calls = {}
    local function Provider(id, providerOrder, extra)
        local provider = {order = providerOrder, RefreshEscape = function(services)
            assert(services.tag == "services", "bag providers must receive the services table")
            calls[#calls + 1] = id
        end}
        for key, value in pairs(extra or {}) do provider[key] = value end
        assert(dispatch.API.RegisterBridge(id, {contract = 1, bagProvider = provider}))
        return provider
    end
    Provider("Late", 70)
    assert(dispatch.API.RegisterBridge("Plain", {contract = 1, RefreshBags = function(_, services)
        assert(services.tag == "services")
        calls[#calls + 1] = "Plain"
    end}))
    Provider("Second", 20, {CancelEscape = function() calls[#calls + 1] = "cancel" end})
    Provider("First", 10, {toggleActions = {"FIRST_TOGGLE"}, GetToggleFrame = function(action) return action end,
        closeButtonRoots = {"FirstRoot"}, GetCloseButtons = function(frame, name) return {frame, name} end})
    Provider("Broken", 30, {RefreshEscape = function() error("broken bag provider") end})
    Provider("Unordered")
    dispatch.Bridges:RefreshBags({tag = "services"})
    assert(table.concat(calls, ",") == "First,Second,Plain,Late,Unordered",
        "bag providers must run by order with the bridges' own RefreshBags at order 60")
    assert(dispatch.Bridges.errors.Broken and dispatch.Bridges.errors.Broken:find("broken bag provider", 1, true),
        "a failing bag provider must be recorded and must not stop the others")
    calls = {}
    dispatch.Bridges:NotifyBagProviders("CancelEscape")
    assert(table.concat(calls, ",") == "cancel", "a bag notice must reach only the providers implementing it")
    local providers = dispatch.Bridges:GetBagProviders()
    assert(providers[1].id == "First" and providers[2].id == "Second" and providers[#providers].id == "Unordered",
        "the bag providers must be listed in their order")
    assert(table.concat(dispatch.Bridges:GetBagToggleActions(), ",") == "FIRST_TOGGLE"
        and dispatch.Bridges:GetBagToggleFrame("FIRST_TOGGLE") == "FIRST_TOGGLE"
        and dispatch.Bridges:GetBagToggleFrame("OTHER") == nil, "toggle actions must reach their own provider")
    local buttons = dispatch.Bridges:GetBagCloseButtons("frame", "FirstRoot")
    assert(buttons[1] == "frame" and buttons[2] == "FirstRoot" and dispatch.Bridges:GetBagCloseButtons("frame", "Other") == nil,
        "close buttons must come from the provider listing the root")
    assert(dispatch.Bridges:HasRole("none", function() return true end) == false, "an accept filter needs an owner")
    dispatch.API.RegisterAddonData("Filtered", {ownership = {{role = "filtered", name = "Skip", order = 1, skip = true},
        {role = "filtered", name = "Keep", order = 2}}})
    local function NotSkipped(entry) return not entry.skip end
    assert(dispatch.Bridges:HasRole("filtered", NotSkipped) and table.concat((dispatch.Bridges:GetRoleOwners("filtered",
        NotSkipped)), ",") == "Keep" and table.concat((dispatch.Bridges:GetRoleOwners("filtered")), ",") == "Skip,Keep",
        "an accept filter must drop the entries it rejects and keep the order")

    C_AddOns, ContainerFrame1 = savedAddOns, savedFrame1
end

-- The persistent bag root engine (Core/BagPersistence.lua) names no addon: a
-- synthetic set of bag providers drives every root hook it calls.
do
    local saved = {CreateFrame = CreateFrame, C_Timer = C_Timer, InCombatLockdown = InCombatLockdown,
        UIParent = UIParent, ToggleAllBags = ToggleAllBags, hooksecurefunc = hooksecurefunc,
        ToggleGameMenu = ToggleGameMenu, GameMenuFrame = GameMenuFrame, C_AddOns = C_AddOns,
        CloseSpecialWindows = CloseSpecialWindows, CloseAllBags = CloseAllBags, ShowUIPanel = ShowUIPanel,
        HideUIPanel = HideUIPanel, EventRegistry = EventRegistry}
    local onEvent, queue = nil, {}
    CreateFrame = function() return {RegisterEvent = function() end,
        SetScript = function(_, _, handler) onEvent = handler end} end
    C_Timer = {After = function(delay, fn) queue[#queue + 1] = {delay = delay, fn = fn} end,
        NewTicker = function() return {} end}
    local function Flush()
        while #queue > 0 do
            table.sort(queue, function(a, b) return a.delay < b.delay end)
            table.remove(queue, 1).fn()
        end
    end
    InCombatLockdown = function() return false end
    C_AddOns = {IsAddOnLoaded = function() return false end}
    UIParent = {GetEffectiveScale = function() return 1 end}
    local toggles = 0
    ToggleAllBags = function() toggles = toggles + 1 end
    GameMenuFrame = {IsShown = function() return false end}
    ToggleGameMenu = function() end
    hooksecurefunc = function(name, callback)
        local original = _G[name]
        _G[name] = function(...) local result = original(...); callback(...); return result end
    end

    local engine = {AddonWindowCatalog = {}, Canvas = {}, isForever = true,
        db = {enabled = true, savedWorkspacePositions = {}}}
    engine.Canvas.IsFrameOnWorkspace = function(frame) return frame.workspace == true end
    engine.Canvas.RestoreWorkspacePosition = function() end
    assert(loadfile("Core/BagPersistence.lua"))("Offhand", engine)
    CoreBridges.Load(engine, {})
    local bags = engine.BagPersistence
    engine.API.RegisterAddonData("SyntheticRecord", {settings = {
        customBagWorkspacePanels = {store = "profile", legacyKey = "syntheticRecord"}}})

    local function Root(name, parent)
        local frame = {name = name, parent = parent or UIParent, shown = true, workspace = true, hooks = {}}
        function frame:GetName() return self.name end
        function frame:GetParent() return self.parent end
        function frame:IsShown() return self.shown end
        function frame:IsVisible() return self.shown end
        function frame:GetLeft() return 10 end
        function frame:GetTop() return 20 end
        function frame:GetEffectiveScale() return 1 end
        function frame:HookScript(script) self.hooks[#self.hooks + 1] = script end
        _G[name] = frame
        return frame
    end
    local log, state = {}, {managed = false, closed = false, alphaClaims = false, betaClaims = false}
    local function Note(text) log[#log + 1] = text end
    local alpha = {order = 10, hookScripts = false,
        IsRoot = function(name) return name == "AlphaRoot" end,
        Discover = function(register, deep)
            Note("alpha:" .. tostring(deep))
            if _G.AlphaRoot then return register("AlphaRoot", _G.AlphaRoot) end
            return false
        end,
        GetManagedRoot = function() return state.managed and "AlphaRoot" or nil end,
        ExplicitlyClosed = function(name) return name == "AlphaRoot" and state.closed end,
        ClaimsSharedToggle = function() Note("claim:alpha"); return state.alphaClaims end,
        Show = function(name) if name == "AlphaRoot" then return state.show end return nil end,
        CapturePosition = function(position) position.extra = true end,
        GetRootDiagnostics = function() return "Alpha=on" end,
    }
    local beta = {order = 20, selfAnchored = true, dragStopCapture = true, panelTransitions = "options",
        loadAddon = "BetaAddon", deepDiscovery = true, escapeOrder = 20, escapeSource = "beta_observer",
        IsRoot = function(name, frame)
            return type(name) == "string" and name:match("^BetaRoot") ~= nil and frame and frame:GetParent() == UIParent
        end,
        IsRootName = function(name) return type(name) == "string" and name:match("^BetaRoot") ~= nil end,
        IsDirectEscapeRoot = function(name) return type(name) == "string" and name:match("^BetaRoot") ~= nil end,
        Discover = function(register, deep, services)
            Note("beta:" .. tostring(deep))
            assert(type(services.GetSavedRecords) == "function" and type(services.RegisterRoot) == "function",
                "a provider's discovery must receive the bag services")
            return false
        end,
        InstallCallbacks = function(services)
            assert(type(services.Discover) == "function", "callbacks must receive the bag services")
            Note("install:beta")
            return true
        end,
        ClaimsSharedToggle = function() Note("claim:beta"); return state.betaClaims end,
        CloseParkedBags = function() Note("parked:beta") end,
    }
    local gamma = {order = 30, panelTransitions = "all", escapeOrder = 10, escapeSource = "gamma_observer",
        IsRoot = function(name) return name == "GammaRoot" or name == "AlphaRoot" end,
        IsDirectEscapeRoot = function(name) return name == "GammaRoot" end,
        CloseParkedBags = function() Note("parked:gamma") end,
    }
    assert(engine.API.RegisterBridge("Gamma", {contract = 1, bagProvider = gamma}))
    assert(engine.API.RegisterBridge("Beta", {contract = 1, bagProvider = beta}))
    assert(engine.API.RegisterBridge("Alpha", {contract = 1, bagProvider = alpha}))

    -- Login installs every provider's callbacks, discovers in provider order and
    -- allows the one deep pass only after every login handler.
    onEvent(nil, "PLAYER_LOGIN")
    assert(table.concat(log, ",") == "install:beta,alpha:false,beta:false", "login must install, then discover shallowly")
    assert(bags.callbacksInstalled.Beta == true, "a provider's installed callbacks must be recorded by bridge id")
    log = {}
    Flush()
    assert(table.concat(log, ",") == "alpha:true,beta:true", "the post-login pass must be the deep one")
    log = {}
    onEvent(nil, "ADDON_LOADED", "OtherAddon"); Flush()
    assert(table.concat(log, ",") == "alpha:false,beta:false", "another addon's load must not run a deep pass")
    log = {}
    onEvent(nil, "ADDON_LOADED", "BetaAddon"); Flush()
    assert(table.concat(log, ",") == "alpha:false,beta:false,install:beta,alpha:true,beta:true",
        "a provider's own addon load must install its callbacks, then run its deep pass")

    -- The first provider in order owns a root; its hookScripts and flags apply.
    local alphaRoot = Root("AlphaRoot")
    bags:Discover(false)
    assert(bags.frames.AlphaRoot == alphaRoot and #alphaRoot.hooks == 0,
        "the first provider claiming a root must own it, and hookScripts = false must install no scripts")
    local betaRoot = Root("BetaRootMain")
    assert(bags:RegisterRoot("BetaRootMain", betaRoot), "a provider's root must register")
    assert(table.concat(betaRoot.hooks, ",") == "OnShow,OnHide,OnDragStop",
        "a hooked root gets its show and hide observers, and its drag-stop capture on Forever")
    local child = Root("BetaRootMainTitle", betaRoot)
    assert(not bags:RegisterRoot("BetaRootMainTitle", child), "a child region named after a root is not a root")
    assert(bags.IsSelfAnchoredRoot(betaRoot, "BetaRootMain") and not bags.IsSelfAnchoredRoot(child, "BetaRootMainTitle")
        and not bags.IsSelfAnchoredRoot(alphaRoot, "AlphaRoot"), "only a selfAnchored provider's roots are self-anchored")
    local gammaRoot = Root("GammaRoot")
    assert(bags:RegisterRoot("GammaRoot", gammaRoot) and #gammaRoot.hooks == 2,
        "a provider without dragStopCapture gets no drag-stop capture")

    -- Capture on Forever: direct-Escape roots leave their registration and their
    -- providers close the bags they park, in escape order.
    local excluded = {}
    engine.CanvasAddonEscape = {SetSpecialFrameExcluded = function(_, registration, record, exclude)
        record.removed = exclude or nil
        excluded[registration] = exclude
    end}
    bags.paused = false
    log = {}
    bags:Capture()
    assert(excluded[gammaRoot] and excluded[betaRoot] and excluded[alphaRoot] == nil,
        "only direct-Escape roots may leave the native Escape registration")
    assert(table.concat(log, ","):find("parked:gamma,parked:beta", 1, true),
        "parked native bags must close in escape order")
    local record = engine.db.syntheticRecord
    assert(record.AlphaRoot and record.BetaRootMain and engine.db.savedWorkspacePositions.AlphaRoot,
        "visible workspace roots must be captured into the custom bag workspace record")
    assert(record.AlphaRoot.extra == nil, "only a managed root gets its provider's capture additions")

    -- A managed root wins the saved position, skips the workspace record and
    -- takes its provider's additions.
    state.managed = true
    engine.db.savedWorkspacePositions.AlphaRoot = nil
    bags:Capture()
    assert(engine.db.syntheticRecord.AlphaRoot.extra == true and engine.db.savedWorkspacePositions.AlphaRoot == nil,
        "a managed root keeps only its open snapshot, with its provider's additions")
    assert(bags:GetSavedPosition() == "AlphaRoot", "a managed root's saved open state must win")
    assert(bags:GetDiagnostics():sub(-11) == " | Alpha=on", "each provider appends its own diagnostics segment")

    -- The shared bag toggle: a provider opens its own root, the toggle opens the
    -- rest, and two claimants block it. The claim test stops once it is decided.
    state.show = true
    assert(bags:OpenSavedRoot("AlphaRoot") == true and toggles == 0, "a provider's Show must open its own root")
    state.show = nil
    log = {}
    assert(bags:OpenSavedRoot("BetaRootMain") == true and toggles == 1 and log[1] == "claim:alpha"
        and not table.concat(log, ","):find("claim:beta", 1, true),
        "the shared toggle opens the root when only one provider could claim it")
    state.alphaClaims, state.betaClaims = true, true
    log = {}
    assert(bags:OpenSavedRoot("BetaRootMain") == false and toggles == 1 and table.concat(log, ",") == "claim:alpha,claim:beta",
        "two providers claiming the shared toggle must block it")
    state.alphaClaims, state.betaClaims = false, false

    -- The Escape observer labels the pending restore with the root's provider.
    state.managed = false
    engine.db.syntheticRecord = {GammaRoot = {x = 1, y = 2}}
    gammaRoot.shown = false
    bags:InstallEscapeHooks()
    queue = {}
    ToggleGameMenu()
    assert(bags.escapePending and bags.escapePending.source == "gamma_observer",
        "the Escape observer must carry the direct-Escape provider's own source label")
    bags.escapePending, queue = nil, {}
    gammaRoot.shown = true

    -- A provider's record of the player's own close cancels the reload restore.
    state.managed, state.closed = true, true
    alphaRoot.shown = false
    engine.db.syntheticRecord = {AlphaRoot = {x = 1, y = 2}}
    bags:Resume(); Flush()
    assert(engine.db.syntheticRecord.AlphaRoot == nil, "an explicit close must forget the open snapshot")
    assert(not next(engine.Bridges.errors), "no synthetic provider call may fail")

    -- The built-in persistent-root providers: their order, taint flags and
    -- escape order reproduce the core's former fixed sequences.
    local builtin = {AddonWindowCatalog = {}}
    local registry = CoreBridges.Load(builtin, {"Bridges/Baganator/Data.lua", "Bridges/Baganator/Bags.lua",
        "Bridges/Bagnon/Bags.lua", "Bridges/EllesmereUI/Bags.lua"})
    local ids, byId = {}, {}
    for _, entry in ipairs(registry:GetBagProviders()) do ids[#ids + 1] = entry.id; byId[entry.id] = entry.provider end
    assert(table.concat(ids, ",") == "EllesmereUIBags,Bagnon,Baganator", "persistent roots are tried in the legacy order")
    assert(byId.Bagnon.hookScripts == false, "Bagnon's root must never get scripts")
    builtin.isForever = true
    assert(byId.EllesmereUIBags.hookScripts() == false, "the EllesmereUI root gets no scripts on Forever")
    builtin.isForever = false
    assert(byId.EllesmereUIBags.hookScripts() == true, "the EllesmereUI root is hooked off Forever")
    assert(byId.Baganator.escapeOrder < byId.Bagnon.escapeOrder and byId.Baganator.selfAnchored
        and byId.Baganator.dragStopCapture and byId.Baganator.deepDiscovery and not byId.Bagnon.deepDiscovery,
        "Baganator leads the escape order and is the self-anchored, drag-captured, deep-discovered root")
    assert(byId.Baganator.escapeSource == "baganator_toggle_observer" and byId.Bagnon.escapeSource == "bagnon_toggle_observer",
        "the Escape observer source labels must keep their legacy strings")
    assert(byId.Baganator.IsRoot("Baganator_SingleViewBackpackViewFrameX", {GetParent = function() return UIParent end})
        and not byId.Baganator.IsRoot("Baganator_SingleViewBackpackViewFrameX", {GetParent = function() return {} end})
        and byId.Baganator.IsRootName("Baganator_CategoryViewBackpackViewFrameTitle")
        and registry:MatchFrame("preservePopup", {GetParent = function() return UIParent end},
            "Baganator_CategoryViewBackpackViewFrameX"), "the Baganator root patterns are shared with its popup rule")

    for key, value in pairs(saved) do _G[key] = value end
    AlphaRoot, BetaRootMain, BetaRootMainTitle, GammaRoot = nil, nil, nil, nil
end

-- Frames a bridge places itself (data.placedFrames): exact names first-wins, "^" patterns in
-- registration order, other entries ignored; GetAddonBridge finds a bridge or data id case-insensitively.
do
    local _, registry = Load()
    assert(registry:MergeData("PlacerOne", {placedFrames = {"PlacerWindow", "^PlacerPin%d+$", "", 7, false}}) == true)
    assert(registry:Register("PlacerTwo", {contract = 1,
        data = {placedFrames = {"PlacerWindow", "PlacerOther", "^Placer"}}}) == true)
    assert(registry:GetPlacedFrameOwner("PlacerWindow") == "PlacerOne", "the first addon to declare a name keeps it")
    assert(registry:GetPlacedFrameOwner("PlacerOther") == "PlacerTwo", "a later addon still declares its own names")
    assert(registry:GetPlacedFrameOwner("PlacerPin12") == "PlacerOne", "patterns are tried in registration order")
    assert(registry:GetPlacedFrameOwner("PlacerSomething") == "PlacerTwo", "a later pattern answers when earlier ones miss")
    assert(registry:GetPlacedFrameOwner("Unrelated") == nil and registry:GetPlacedFrameOwner(nil) == nil
        and registry:GetPlacedFrameOwner(7) == nil and registry:GetPlacedFrameOwner("") == nil,
        "an undeclared or non-string name has no owner")
    assert(registry:GetAddonBridge("placerone") == "PlacerOne" and registry:GetAddonBridge("PLACERTWO") == "PlacerTwo",
        "the bridge lookup ignores case for data entries and bridges")
    assert(registry:MergeData("DataOnly", {}) == true and registry:GetAddonBridge("DataOnly") == "DataOnly",
        "addon data without placed frames still names its addon")
    assert(registry:GetAddonBridge("Missing") == nil and registry:GetAddonBridge(nil) == nil,
        "an addon without a bridge has none")
end

-- Core purity (final): no file under Core/, UI/ or Modules/, and not Bindings.xml, names a third-party
-- addon. Every addon specific lives in Bridges/<Addon>/ behind the bridge contract. Locales/*.lua are
-- outside the scan on purpose: player-facing text and key names such as ELLESMERE_HUD_*, OPENMAP_*,
-- PROCDOC_*, COMPAT_GUIDE_MOVEANY and MAP_MOVEMENT_MAPWISE stay there.
do
    -- The files: every Core, UI and Modules Lua file of the six manifests, plus the Modules files no
    -- manifest lists (kept in the repository, never loaded), plus Bindings.xml.
    local UNLISTED_MODULES = {"Modules/BagDock.lua", "Modules/CharacterDock.lua", "Modules/MapDock.lua"}
    local files, listed = {}, {}
    local function AddFile(file)
        if not listed[file] then
            listed[file] = true
            files[#files + 1] = file
        end
    end
    for _, toc in ipairs({"Offhand.toc", "Offhand_Classic.toc", "Offhand_Forever.toc", "Offhand_Mainline.toc",
        "Offhand_Vanilla.toc", "Offhand_Wrath335a.toc"}) do
        for line in io.lines(toc) do
            local file, folder = line:match("^%s*((%a+)\\.-%.lua)%s*$")
            if folder == "Core" or folder == "UI" or folder == "Modules" then AddFile((file:gsub("\\", "/"))) end
        end
    end
    for _, file in ipairs(UNLISTED_MODULES) do
        assert(not listed[file], file .. " is now in a manifest: drop it from the unlisted list")
        AddFile(file)
    end
    AddFile("Bindings.xml")
    assert(#files > 70, "the purity scan must read every core, UI and module file")

    -- Justified exceptions: the exact text removed from one file before the scan, and why.
    local EXCEPTIONS = {
        {file = "UI/Options.lua", text = "OpenMapSettings",
            reason = "Options:OpenMapSettings is Offhand's own 'open the map settings' method, not the OpenMap addon"},
    }

    -- Case-insensitive plain substrings.
    local TOKENS = {"ellesmere", "openmap", "mapwise", "maputils", "leatrix", "moveany", "classicuiforever",
        "classicui", "blizzmove", "baganator", "baginator", "bagnon", "betterbags", "bagsmith", "elvui", "elvuf",
        "arkinventory", "arkinv", "bagnaros", "movemybags", "adibags", "inventorian", "tukui", "questdon",
        "leveldon", "donmap", "doncore", "platynator", "dungeonjournal", "kerzo", "restedxp", "questie", "procdoc",
        "foreverxpbar", "chattynator", "itemrack", "tiptac", "tinytooltip", "oneforall", "ofamov", "zygor",
        "consoleport", "bugsack", "redisfriend", "daylight", "dialogueui", "bartender", "dominos", "sexymap",
        "carbonite", "shadoweduf", "shadowuf", "shadowedunit", "pitbull", "zperl", "xperl", "flareui",
        "foreverplus", "gathercraft", "rarescanner", "mobinfo", "beastfinder", "easyfishing", "foreverledger",
        "naowh", "basicminimap", "compat_guide", "recovermap", "mauttab"}
    -- Case-sensitive plain substrings the earlier scans held.
    local CASED_TOKENS = {"Titan", "RXP", "DetailsBaseFrame"}
    -- Frontier patterns: names whose plain spelling also occurs inside unrelated words (TOGGLEUIFOCUS,
    -- PlacementDetails, Cancel).
    local PATTERNS = {"%f[%w]EUI_", "%f[%w]EUI%u", "%f[%w]RXP", "%f[%w]Titan", "%f[%w]DetailsBaseFrame",
        "%f[%w]Cell%f[%W]", "%f[%w]BGR", "%f[%w]LibDBIcon10_"}

    -- Addon-presence API: a string literal passed as the addon name to one of these, to a local alias of
    -- one (or of anything in C_AddOns), or to Offhand's own wrappers, is a Blizzard_ addon or Offhand.
    local PRESENCE = {"IsAddOnLoaded", "GetAddOnMetadata", "GetAddOnEnableState", "LoadAddOn", "DoesAddOnExist",
        "GetAddOnInfo", "IsAddOnLoadOnDemand", "EnableAddOn", "DisableAddOn"}
    local WRAPPERS = {"IsAddonLoaded", "IsAddonPresent", "LoadAddon", "IsIntegrationActive", "Loaded", "AddonLoaded"}
    local function PresenceLiterals(text)
        local callees = {}
        for _, name in ipairs(PRESENCE) do callees[name] = true end
        for _, name in ipairs(WRAPPERS) do callees[name] = true end
        for alias, rhs in text:gmatch("local%s+([%a_][%w_]*)%s*=%s*([^\n]*)") do
            if rhs:find("C_AddOns", 1, true) then callees[alias] = true end
            for _, name in ipairs(PRESENCE) do
                if rhs:find(name, 1, true) then callees[alias] = true end
            end
        end
        local literals = {}
        for name, literal in text:gmatch("([%a_][%w_]*)%s*%(%s*[\"']([^\"']*)[\"']") do
            if callees[name] then literals[#literals + 1] = literal end
        end
        for name, literal in text:gmatch("pcall%(%s*([%a_][%w_%.]*)%s*,%s*[\"']([^\"']*)[\"']") do
            if callees[name] or callees[name:match("([%a_][%w_]*)$")] then literals[#literals + 1] = literal end
        end
        return literals
    end
    local function AllowedAddonName(literal)
        return literal == "Offhand" or literal:match("^Blizzard_") ~= nil
    end
    -- The literal scan itself must see every call form it guards.
    local planted = PresenceLiterals(table.concat({
        'C_AddOns.IsAddOnLoaded("Alpha")',
        'local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn',
        'pcall(load, "Beta")',
        'pcall(C_AddOns.GetAddOnInfo, "Gamma")',
        'Compatibility.IsAddonLoaded("Delta")',
        'C_AddOns.LoadAddOn("Blizzard_Fixture")',
        'getMetadata = nil; GetAddOnMetadata("Offhand", "Version")',
    }, "\n"))
    local disallowed = {}
    for _, literal in ipairs(planted) do
        if not AllowedAddonName(literal) then disallowed[#disallowed + 1] = literal end
    end
    assert(table.concat(disallowed, ",") == "Alpha,Delta,Beta,Gamma" and #planted == 6,
        "the addon-presence scan must catch direct, aliased, pcall and wrapper calls: " .. table.concat(planted, ","))

    local exceptionHits = {}
    for _, file in ipairs(files) do
        local handle = assert(io.open(file, "rb"), "missing " .. file)
        local text = handle:read("*a")
        handle:close()
        for index, exception in ipairs(EXCEPTIONS) do
            if exception.file == file then
                local stripped, count = text:gsub(exception.text, "")
                exceptionHits[index] = (exceptionHits[index] or 0) + count
                text = stripped
            end
        end
        local lower = text:lower()
        for _, token in ipairs(TOKENS) do
            assert(not lower:find(token, 1, true), "core file must not name " .. token .. ": " .. file)
        end
        for _, token in ipairs(CASED_TOKENS) do
            assert(not text:find(token, 1, true), "core file must not name " .. token .. ": " .. file)
        end
        for _, pattern in ipairs(PATTERNS) do
            assert(not text:find(pattern), "core file must not match " .. pattern .. ": " .. file)
        end
        if file:match("%.lua$") then
            for _, literal in ipairs(PresenceLiterals(text)) do
                assert(AllowedAddonName(literal),
                    "core file must not ask the addon API about " .. literal .. ": " .. file)
            end
        end
    end
    for index, exception in ipairs(EXCEPTIONS) do
        assert((exceptionHits[index] or 0) > 0, "stale purity exception (" .. exception.reason .. "): " .. exception.file)
    end

    -- Retired files stay retired.
    for _, retired in ipairs({
        {"Core/DaylightMapCompatibility.lua", "Bridges/DaylightUI/Map.lua"},
        {"Core/ForeverPlusWarnings.lua", "Bridges/ForeverPlus/Bridge.lua"},
        {"Core/DialogueUICompat.lua", "Bridges/DialogueUI/Bridge.lua"},
        {"Core/ProcDocCompatibility.lua", "Bridges/ProcDoc/Bridge.lua"},
        {"Core/CanvasKerzoQuestLog.lua", "Bridges/KerzoQuestLog/Bridge.lua"},
        {"Core/EllesmereScaleCompatibility.lua", "Bridges/EllesmereUI/Scale.lua"},
        {"Core/OpenMapRecovery.lua", "Bridges/OpenMap/Recovery.lua"},
        {"Core/ForeverEllesmereLayout.lua", "Bridges/EllesmereUI/Layout.lua"},
        {"UI/EllesmereLayoutPreview.lua", "Bridges/EllesmereUI/Preview.lua"},
    }) do
        assert(io.open(retired[1], "rb") == nil, retired[1] .. " must remain retired into " .. retired[2])
        local moved = io.open(retired[2], "rb")
        assert(moved, retired[2] .. " must exist")
        moved:close()
    end
end

print("PASS: bridge registry, dispatch, isolation, public services, storage, ownership and transient dispatch and core purity")
