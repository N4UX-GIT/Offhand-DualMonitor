-- Support reports must remain useful without running historical feature probes.
GetBuildInfo = function() return "1.60.1", "70862", "", 16001 end
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
StaticPopupDialogs, SlashCmdList = {}, {}
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
strsplit = function(_, s) return s:match("^(%S+)%s*(.*)$") end
InCombatLockdown = function() return false end
GetScreenWidth = function() return 3900 end
GetScreenHeight = function() return 1097 end
UIParent = { GetEffectiveScale = function() return 0.7 end }
local addon = {}
assert(loadfile("Core/Init.lua"))("Offhand", addon)
assert(loadfile("Core/ClientRuntime.lua"))("Offhand", addon)
assert(loadfile("Core/Viewport.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
addon.db = { enabled = true, firstRunComplete = true }
local lines, probes = {}, {}
addon.Print = function(_, fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
local function probe(name, result)
    return function() probes[name] = (probes[name] or 0) + 1; return result end
end
local metrics = {
    isSpanned = true, companionTopology = true, physicalWidth = 3840, physicalHeight = 1080,
    gamePixelWidth = 1920, gamePixelHeight = 1080, workspacePixelWidth = 1920,
    workspacePixelHeight = 1080, gameWidth = 1950, gameHeight = 1097,
}
local topology = { status = "READY", liveWidth = 3840, liveHeight = 1080,
    canvasWidth = 3900, canvasHeight = 1097 }
local viewportMatches = true
local getGraphics = addon.Viewport.GetGraphicsDiagnostics
local graphicsReads, versionReads = 0, 0
local forbiddenCalls = 0
local function unexpectedCall()
    forbiddenCalls = forbiddenCalls + 1
    error("diagnostics attempted a write or an unrelated call")
end
local secret = "fixture-restricted-value"
issecretvalue = function(value) return value == secret end
local values = { vsync = "0", gxVSync = "1", maxFPS = "100", maxFPSBk = 30,
    gxApi = "D3D12", RenderScale = "1", ResampleQuality = "3", ResampleSharpness = "0.2",
    ffxAntiAliasingMode = "2", CMAA2Quality = "3", MSAAQuality = "0" }
GetFramerate = function() graphicsReads = graphicsReads + 1; return 73.5 end
GetCVar = function(name)
    if name == "DynamicRenderScale" then error("unavailable on this client") end
    return values[name]
end
C_CVar = {
    GetCVar = function(name)
        if name == "DynamicRenderScale" then return "0" end
        if name == "ResampleAlwaysSharpen" then return secret end
    end,
    SetCVar = unexpectedCall,
}
SetCVar = C_CVar.SetCVar
C_NamePlate = { GetNamePlates = unexpectedCall }
local loadedMapAddons = {OpenMap = true}
C_AddOns = {
    IsAddOnLoaded = function(name) return loadedMapAddons[name] end,
    GetAddOnMetadata = function(name, field)
        versionReads = versionReads + 1
        assert(field == "Version")
        if name == "BlizzMove" then return "v3.8.6" end
        if name == "Leatrix_Maps" then return " 1.2.3 " end
        if name == "MoveAny" then error("metadata unavailable") end
    end,
    LoadAddOn = unexpectedCall,
}
OpenMap = {version = "v0.8.9", GetModule = unexpectedCall}
MapWiseAPI = {version = "2.3.98"}
addon.Viewport = {
    CaptureDiagnostics = function(_, remember)
        assert(remember == false, "support diagnostics must not persist a geometry snapshot")
        return {viewportMatches = viewportMatches, metrics = metrics,
            frames = {WorldFrame = {x=0,y=2,width=1920,height=1080}}}
    end,
    GetMetrics = function() error("do not recapture the same geometry") end,
    GetTopologyDiagnostics = function() return topology end,
    GetGraphicsDiagnostics = getGraphics,
    GetWorldTextDiagnostics = probe("text", {worldTextScale = "1", worldTextScaleCVar = "WorldTextScale_v2",
        worldTextMethod = "CVAR", worldTextFineTune = 1, worldTextHeightRatio = 1,
        worldTextCompensationRatio = 1}),
    GetPerformanceDiagnostics = function() error("obsolete renderer/nameplate collection") end,
}
addon.HUD = {
    GetInteractionVisibilityDiagnostics = probe("interaction", { "ProfessionsFrame=hidden", "PVEFrame=absent" }),
    GetForeverEditModeLayoutStatus = function() return {} end,
    GetGroupLootDiagnostics = function(_, capturedMetrics)
        assert(capturedMetrics == metrics, "loot diagnostics must use the captured display bounds")
        probes.loot = (probes.loot or 0) + 1
        return {activeRolls=2, containerVisibility="visible", slots={"2=hidden", "3=visible,rectUI=10/20/30/40 mainhand"}}
    end,
    GetPetBattleDiagnostics = probe("pets", {}),
    GetForeverGroupFrameDiagnostics = probe("groups", "bounds"),
    GetForeverProtectedHUDDiagnostics = probe("protected", "bounds"),
}
local captureAllowed, captures = true, 0
addon.PopupBounds = {
    GetTooltipPresentationDiagnostics = probe("tooltip", { "GameTooltip=hidden" }),
    ArmTooltipPresentationCapture = function() captures = captures + 1; return captureAllowed end,
}
addon.CanvasChat = { GetPlacementDiagnostics = function(_, compact)
    probes.chat = (probes.chat or 0) + 1
    return compact and {"SnapToElements=yes", "ChatFrame1 anchors=fixture"}
        or {"SnapToElements=yes", "ChatFrame1 anchors=fixture", "ChatFrame10 shown=no"}
end }
addon.Mainhand = { GetEditModeDiagnostics = function(_, compact)
    return compact and "Active=7 | Geometry=current" or "Active=7 | GamepadPanels=details"
end }
addon.ManualCanvas = { GetDiagnostics = probe("manual", {}) }
-- The guide frame probe is a bridge's debug report (Bridges/Zygor).
local guidesProbe = probe("guides", {"Zygor probes: fixture"})
addon.modules.ChatBubbles = { GetDiagnostics = probe("bubbles", {}) }
addon.Canvas = {
    -- The old caller discarded reports without the substring 'loaded'.
    GetCompatibilityDiagnostics = function(_, compact) return addon.CanvasCompatibility.GetDiagnostics(compact) end,
    GetPanelControllerDiagnostics = probe("panels", "idle"),
    GetPanelPlacementDiagnostics = probe("placement", {"CharacterFrame | parent=UIParent | rectUI=10/20/30/40"}),
    GetForeverNativeBagDiagnostics = probe("bags", "roots=ContainerFrameCombinedBags=shown"),
}
-- Long per-bridge reports reach the debug mode through the bridge registry.
dofile("tests/support/core-bridges.lua").Load(addon, { "Bridges/BlizzMove/Bridge.lua", "Bridges/ClassicUIForever/Bridge.lua",
    "Bridges/Leatrix/Maps.lua", "Bridges/MapUtils/Bridge.lua", "Bridges/MapWise/Data.lua", "Bridges/MoveAny/Bridge.lua",
    "Bridges/OpenMap/Data.lua", "Bridges/OpenMap/Contract.lua", "Bridges/OpenMap/Recovery.lua", "Bridges/OpenMap/Map.lua",
    "Bridges/OpenMap/Init.lua" })
local dialogueProbe = probe("dialogue", "animation")
addon.Bridges.GetDebugDiagnostics = function()
    local reports = {}
    for _, line in ipairs(guidesProbe()) do reports[#reports + 1] = { label = "Guide frame", text = line } end
    reports[#reports + 1] = { label = "Dialogue UI", text = dialogueProbe() }
    return reports
end
local media = { status = "MISSING", installed = false, reason = "NOT_INSTALLED" }
addon.UserMedia = { GetDiagnostics = function() return media end }
local function run(command)
    lines = {}
    SlashCmdList.OFFHAND(command)
    return table.concat(lines, "\n")
end
local compact = run("diag")
assert(next(probes) == nil, "default diagnostics collected detailed feature probes")
assert(graphicsReads == 0 and versionReads == 0, "compact diagnostics read graphics or addon versions")
assert(#lines <= 12, "default support report grew beyond a compact snapshot")
assert(compact:find("WorldMapOwner=OpenMap", 1, true), "OpenMap-only ownership was hidden")
assert(compact:find("Forever persistence diagnostics:", 1, true), "persistence evidence lost")
assert(compact:find("More detail: /offhand diag full", 1, true), "full report is undiscoverable")
for _, absent in ipairs({"Topology diagnostics:", "Manual canvas", "Group frame", "Protected HUD",
    "Dialogue UI", "User media", "diskRevision", "GamepadPanels", "Graphics:", "Graphics AA settings:", "Map integrations:"}) do
    assert(not compact:find(absent, 1, true), "unnecessary default output: " .. absent)
end
addon.db.automaticSetupSuppressed = true
addon.GetOnboardingResumeStep = function() return 4 end
OffhandCharDB = {characterSetup = {version = 1, choice = "later", complete = true}}
loadedMapAddons = {MapWise = true, Leatrix_Maps = true, MoveAny = true}
local full = run("diag full")
assert(not compact:find("Setup state:", 1, true)
        and full:find("Setup state: Account=complete | Guide=paused | Resume=4 | Character=later | Decision=saved", 1, true),
    "full diagnostics must expose setup intent and character decision without bloating compact reports")
assert(#lines <= 20, "full support snapshot exceeded fixture budget")
assert(probes.chat == 1 and full:find("SnapToElements=yes", 1, true)
    and full:find("ChatFrame1 anchors=fixture", 1, true), "full report lost active chat evidence")
assert(full:find("diskRevision", 1, true) and full:find("Topology diagnostics: state=READY", 1, true)
    and full:find("Geometry: Physical=3840x1080", 1, true), "full report lost core evidence")
assert(graphicsReads == 1 and full:find("Graphics: FPS=73.5 | VSync=0 | maxFPS=100 | maxFPSBk=30 | API=D3D12", 1, true)
    and full:find("RenderScale=1 | DynamicRenderScale=0 | ResampleQuality=3 | ResampleAlwaysSharpen=unavailable | ResampleSharpness=0.2", 1, true)
    and not full:find(secret, 1, true), "full diagnostics lost graphics values, fallback, or redaction")
assert(full:find("Graphics AA settings: ffxAntiAliasingMode=2 | CMAA2Quality=3 | MSAAQuality=0 | MSAAAlphaTest=unavailable | OffhandAntiShimmer=off", 1, true),
    "full diagnostics must report configured AA values and Offhand's resampling option")
assert(versionReads == 2 and full:find("Map integrations: MapWise=2.3.98 | Leatrix_Maps=1.2.3 | MoveAny=unknown version", 1, true)
    and full:find("WorldMapOwner=MoveAny", 1, true) and not full:find("OpenMap=v0.8.9", 1, true),
    "full diagnostics missed loaded map integrations or reported a stale namespace")
for _, name in ipairs({"tooltip", "interaction", "text", "loot", "pets", "groups", "protected", "manual", "bubbles", "panels", "dialogue", "guides", "bags"}) do
    assert(probes[name] == nil, "full report ran an unrelated probe: " .. name)
end
for _, absent in ipairs({"GamepadPanels", "Cinematic skip-dialog", "User media", "ChatFrame10", "Preset=", "DeckWidth="}) do
    assert(not full:find(absent, 1, true), "full report retained irrelevant detail: " .. absent)
end
assert(captures == 0, "snapshot armed a tooltip capture")
local previousFPS = GetFramerate
GetFramerate = function() error("FPS unavailable") end
values.vsync = nil
values.ffxAntiAliasingMode = "0"
addon.db.antiShimmer = true
loadedMapAddons = {MapWise = true, OpenMap = true}
local fallback = run("diag full")
assert(fallback:find("Graphics: FPS=unavailable | VSync=1", 1, true)
    and fallback:find("Map integrations: OpenMap=v0.8.9 | MapWise=2.3.98", 1, true),
    "full diagnostics lost the legacy VSync fallback or OpenMap version")
assert(fallback:find("ffxAntiAliasingMode=0", 1, true) and fallback:find("OffhandAntiShimmer=on", 1, true),
    "full diagnostics must reflect current settings on each invocation")
loadedMapAddons = {MapWise = true}
local mapWiseOnly = run("diag full")
assert(mapWiseOnly:find("WorldMapOwner=Offhand", 1, true) and mapWiseOnly:find("Map integrations: MapWise=2.3.98", 1, true),
    "MapWise must be listed even when Offhand owns the native frame")
loadedMapAddons = {BlizzMove = true}
local blizzMove = run("diag full")
assert(blizzMove:find("WorldMapOwner=Offhand", 1, true) and blizzMove:find("Map integrations: BlizzMove=v3.8.6", 1, true),
    "BlizzMove must be reported without assigning it Offhand's placement ownership")
loadedMapAddons = {}
assert(run("diag full"):find("Map integrations: none detected", 1, true), "empty map integration state missing")
GetFramerate = previousFPS
local chat = run("diag chat")
assert(chat:find("ChatFrame10 shown=no", 1, true), "focused chat report omitted inactive windows")
assert(graphicsReads == 1 and versionReads == 3, "focused chat diagnostics sampled graphics or map integration versions")
local tooltip = run("diag tooltip")
assert(tooltip:find("Tooltip presentation: GameTooltip=hidden", 1, true) and captures == 0,
    "focused tooltip snapshot should be read-only")
assert(run("diag tooltip capture"):find("Tooltip capture armed", 1, true) and captures == 1,
    "explicit hover capture must remain available")
captureAllowed = false
assert(run("diag tooltip capture"):find("Tooltip capture unavailable", 1, true),
    "failed/combat-deferred capture must explain that it did not start")
local panels = run("diag panels")
assert(panels:find("Interaction visibility: ProfessionsFrame=hidden", 1, true)
    and panels:find("1 unloaded roots omitted", 1, true)
    and not panels:find("PVEFrame=absent", 1, true)
    and panels:find("Native bag diagnostics:", 1, true), "focused panel evidence lost")
local debugReport = run("diag debug")
for _, name in ipairs({"tooltip", "interaction", "text", "loot", "pets", "groups", "protected", "manual", "bubbles", "panels", "dialogue", "guides", "bags"}) do
    assert((probes[name] or 0) >= 1, "debug report lost deep evidence: " .. name)
end
for _, expected in ipairs({"GamepadPanels", "Cinematic skip-dialog diagnostics: not-attached", "User media",
    "ChatFrame10", "Guide frame diagnostics: Zygor probes: fixture", "PVEFrame=absent"}) do
    assert(debugReport:find(expected, 1, true), "debug report lost raw detail: " .. expected)
end
assert(captures == 2, "debug snapshot must not start capture")
local oldCapture = addon.Viewport.CaptureDiagnostics
addon.Viewport.CaptureDiagnostics = function() error("invalid mode collected state") end
local usage = run("diag nonsense")
assert(usage:find("Use /offhand diag [full, chat, tooltip, panels, debug]", 1, true),
    'usage separators must survive native chat escape parsing')
assert(run("diag full capture"):find("Use /offhand diag", 1, true))
addon.Viewport.CaptureDiagnostics = oldCapture
topology.status = "MISMATCH"
assert(run("metrics"):find("Topology diagnostics: state=MISMATCH", 1, true),
    "default report hid a topology mismatch")
metrics.companionTopology = false
assert(run("info"):find("Manual canvas diagnostics:", 1, true),
    "active manual geometry lost its support evidence")
media.installed, media.status, media.enabled = true, "INVALID", true
local invalid = run("diag")
assert(invalid:find("User media diagnostics: status=INVALID", 1, true)
    and not invalid:find("texture=", 1, true), "invalid installed media must remain visible and concise")
local armed,stopped=0,0
addon.HUD.ArmNotificationCapture=function() armed=armed+1;return true end
addon.HUD.StopNotificationCapture=function() stopped=stopped+1 end
addon.HUD.GetNotificationCaptureReports=function() return {"retained-frame-evidence"} end
assert(run('notifycapture start'):find('Notification capture armed',1,true) and armed==1)
assert(run('notifycapture stop'):find('Notification capture stopped',1,true) and stopped==1)
assert(run('notifycapture show'):find('retained-frame-evidence',1,true))
assert(run('diag debug'):find('Notification capture: retained-frame-evidence',1,true))
assert(not run('diag full'):find('retained-frame-evidence',1,true),'support snapshots must not dump capture history')
addon.isForever = false
local oldBags = probes.bags
assert(not run('diag panels'):find('Native bag diagnostics:',1,true) and probes.bags == oldBags,
    'other clients must not collect Forever-only bag state')
C_AddOns = nil
IsAddOnLoaded = function(name) return name == "MapUtils", true end
GetAddOnMetadata = function(name, field)
    assert(name == "MapUtils" and field == "Version")
    return "1.7.0"
end
assert(run("diag full"):find("Map integrations: MapUtils=1.7.0", 1, true),
    "legacy clients must report loaded addon versions")
assert(forbiddenCalls == 0, "diagnostics called a setter, loader, map module or nameplate enumeration")
print("PASS: full graphics and map reports, compact and focused modes, raw debug and explicit capture")
