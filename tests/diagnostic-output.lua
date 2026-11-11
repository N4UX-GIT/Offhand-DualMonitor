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
addon.Viewport = {
    CaptureDiagnostics = function(_, remember)
        assert(remember == false, "support diagnostics must not persist a geometry snapshot")
        return {viewportMatches = viewportMatches, metrics = metrics,
            frames = {WorldFrame = {x=0,y=2,width=1920,height=1080}}}
    end,
    GetMetrics = function() error("do not recapture the same geometry") end,
    GetTopologyDiagnostics = function() return topology end,
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
addon.CanvasCompatibility = {GetGuideAddonDiagnostics = probe("guides", {"Zygor probes: fixture"})}
addon.modules.ChatBubbles = { GetDiagnostics = probe("bubbles", {}) }
addon.Canvas = {
    -- The old caller discarded reports without the substring 'loaded'.
    GetCompatibilityDiagnostics = function() return "WorldMapOwner=OpenMap" end,
    GetPanelControllerDiagnostics = probe("panels", "idle"),
    GetPanelPlacementDiagnostics = probe("placement", {"CharacterFrame | parent=UIParent | rectUI=10/20/30/40"}),
    GetForeverNativeBagDiagnostics = probe("bags", "roots=ContainerFrameCombinedBags=shown"),
}
addon.DialogueUICompat = { GetDiagnostics = probe("dialogue", "animation") }
local media = { status = "MISSING", installed = false, reason = "NOT_INSTALLED" }
addon.UserMedia = { GetDiagnostics = function() return media end }
local function run(command)
    lines = {}
    SlashCmdList.OFFHAND(command)
    return table.concat(lines, "\n")
end
local compact = run("diag")
assert(next(probes) == nil, "default diagnostics collected detailed feature probes")
assert(#lines <= 12, "default support report grew beyond a compact snapshot")
assert(compact:find("WorldMapOwner=OpenMap", 1, true), "OpenMap-only ownership was hidden")
assert(compact:find("Forever persistence diagnostics:", 1, true), "persistence evidence lost")
assert(compact:find("More detail: /offhand diag full", 1, true), "full report is undiscoverable")
for _, absent in ipairs({"Topology diagnostics:", "Manual canvas", "Group frame", "Protected HUD",
    "Dialogue UI", "User media", "diskRevision", "GamepadPanels"}) do
    assert(not compact:find(absent, 1, true), "unnecessary default output: " .. absent)
end
addon.db.automaticSetupSuppressed = true
addon.GetOnboardingResumeStep = function() return 4 end
OffhandCharDB = {characterSetup = {version = 1, choice = "later", complete = true}}
local full = run("diag full")
assert(not compact:find("Setup state:", 1, true)
        and full:find("Setup state: Account=complete | Guide=paused | Resume=4 | Character=later | Decision=saved", 1, true),
    "full diagnostics must expose setup intent and character decision without bloating compact reports")
assert(#lines <= 20, "full support snapshot exceeded fixture budget")
assert(probes.chat == 1 and full:find("SnapToElements=yes", 1, true)
    and full:find("ChatFrame1 anchors=fixture", 1, true), "full report lost active chat evidence")
assert(full:find("diskRevision", 1, true) and full:find("Topology diagnostics: state=READY", 1, true)
    and full:find("Geometry: Physical=3840x1080", 1, true), "full report lost core evidence")
for _, name in ipairs({"tooltip", "interaction", "text", "loot", "pets", "groups", "protected", "manual", "bubbles", "panels", "dialogue", "guides", "bags"}) do
    assert(probes[name] == nil, "full report ran an unrelated probe: " .. name)
end
for _, absent in ipairs({"GamepadPanels", "Cinematic skip-dialog", "User media", "ChatFrame10", "Preset=", "DeckWidth="}) do
    assert(not full:find(absent, 1, true), "full report retained irrelevant detail: " .. absent)
end
assert(captures == 0, "snapshot armed a tooltip capture")
local chat = run("diag chat")
assert(chat:find("ChatFrame10 shown=no", 1, true), "focused chat report omitted inactive windows")
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
print("PASS: concise full support report, focused chat/tooltip/panels, raw debug and explicit capture")
