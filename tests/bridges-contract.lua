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
assert(io.open("Core/DaylightMapCompatibility.lua", "rb") == nil,
    "Core/DaylightMapCompatibility.lua must remain retired into Bridges/DaylightUI/Map.lua")

print("PASS: bridge registry, dispatch, isolation, public services, storage and core purity")
