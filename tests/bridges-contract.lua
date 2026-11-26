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
    assert(status.currentOwnership == true and status.ellesmereGainedOwnership == false,
        "a legacy signature saved with every owner present must still match")
    assert(Status(LEGACY_SIGNATURE:gsub("EllesmereUIRaidFrames:", "")).ellesmereGainedOwnership == true,
        "a suite module gaining ownership must be recognised")
    assert(Status(LEGACY_SIGNATURE:gsub(":Chattynator", "")).ellesmereGainedOwnership == false,
        "another addon gaining ownership must not count as the suite")
    -- Only the bar addons' globals own status bars; loaded folders keep the signature.
    Bartender4, Dominos, ElvUI, Tukui, ConsolePort = nil, nil, nil, nil, nil
    EllesmereUI = {Lite = {GetAddon = function() return {db = {profile = {useBlizzardDataBars = true}}} end}}
    status = Status(LEGACY_SIGNATURE)
    assert(status.currentOwnership == false and status.ellesmereGainedOwnership == false
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

-- Core purity: bridged map/bag/catalog/learning modules stay free of DaylightUI specifics.
for _, file in ipairs({
    "Core/Bridges.lua",
    "Core/BagPersistence.lua",
    "Core/Canvas.lua",
    "Core/CanvasCompatibility.lua",
    "Core/CanvasMapPresentation.lua",
    "Core/WorkspaceToggleKeys.lua",
    "Core/AddonWindowCatalog.lua",
    "Core/CanvasAddonEscape.lua",
    "Core/LearnedAddonWindows.lua",
    "Bindings.xml",
}) do
    local handle = assert(io.open(file, "rb"), "missing " .. file)
    local text = handle:read("*a")
    handle:close()
    assert(not text:lower():find("daylight", 1, true), "bridged core module must not name DaylightUI: " .. file)
end
-- Core purity: no core, UI or module file names an addon whose facts moved to a bridge.
local coreFiles = 0
for line in io.lines("Offhand.toc") do
    local file, folder = line:match("^%s*((%a+)\\.-%.lua)%s*$")
    if folder == "Core" or folder == "UI" or folder == "Modules" then
        file = file:gsub("\\", "/")
        local handle = assert(io.open(file, "rb"), "missing " .. file)
        local text = handle:read("*a")
        handle:close()
        coreFiles = coreFiles + 1
        for _, token in ipairs({"ConsolePort", "Bartender4", "Dominos", "SexyMap", "Carbonite",
            "ShadowedUnitFrames", "ShadowUF", "PitBull4", "ZPerl", "XPerl", "Chattynator", "ElvUF", "ElvUI_Bar1",
            "TukuiPlayerFrame", "TukuiUnitFrames", "TukuiActionBars", "MoveMyBagsDB", "EllesmereUIRaidFrames",
            "EllesmereUIChat", "EllesmereUIQuestTracker", "COMPAT_GUIDE", "COMPAT_ELLESMERE_PARTY",
            "Titan", "DetailsBaseFrame", "ForeverXPBar", "BugSack", "RedIsFriend", "TipTac", "TinyTooltip",
            "RXPV2", "RestedXP", "Questie_BaseFrame", "EllesmereUIPlayerAuraBars", "moveMyBags", "ofaMoving"}) do
            assert(not text:find(token, 1, true), "core file must not name " .. token .. ": " .. file)
        end
        assert(not text:find("%f[%w]Cell%f[%W]"), "core file must not name Cell: " .. file)
    end
end
assert(coreFiles > 50, "the purity scan must read the manifest's core files")
-- Core purity: popup roots, menu names, tooltip owners and mover marks moved out of these files.
for _, file in ipairs({"Core/HUDCompatibility.lua", "Core/PopupBounds.lua", "Core/SeamRedirect.lua",
    "Core/CanvasPanelPlacement.lua", "Core/CanvasPanelMotion.lua", "Core/Canvas.lua", "Core/HUDTransientFrames.lua"}) do
    local handle = assert(io.open(file, "rb"), "missing " .. file)
    local text = handle:read("*a")
    handle:close()
    for _, token in ipairs({"RXP", "ProcDocAlertFrame", "BetterBagsBag", "BetterBagsNext", "Baganator_", "ofaMovable"}) do
        assert(not text:find(token, 1, true), "core file must not name " .. token .. ": " .. file)
    end
end
assert(io.open("Core/DaylightMapCompatibility.lua", "rb") == nil,
    "Core/DaylightMapCompatibility.lua must remain retired into Bridges/DaylightUI/Map.lua")

print("PASS: bridge registry, dispatch, isolation, public services, storage, ownership and transient dispatch and core purity")
