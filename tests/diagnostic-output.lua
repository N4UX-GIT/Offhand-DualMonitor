-- Support reports must remain useful without running historical feature probes.
GetBuildInfo = function() return "1.60.1", "70532", "", 16001 end
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
addon.Viewport = {
    CaptureDiagnostics = function() return {viewportMatches = true, metrics = metrics} end,
    GetMetrics = function() error("do not recapture the same geometry") end,
    GetTopologyDiagnostics = function() return topology end,
    GetWorldTextDiagnostics = probe("text", {worldTextScale = "1", worldTextScaleCVar = "WorldTextScale_v2",
        worldTextMethod = "CVAR", worldTextFineTune = 1, worldTextHeightRatio = 1,
        worldTextCompensationRatio = 1}),
    GetPerformanceDiagnostics = function() error("obsolete renderer/nameplate collection") end,
}
addon.HUD = {
    GetForeverEditModeLayoutStatus = function() return {} end,
    GetGroupLootDiagnostics = probe("loot", {}),
    GetPetBattleDiagnostics = probe("pets", {}),
    GetForeverGroupFrameDiagnostics = probe("groups", "bounds"),
    GetForeverProtectedHUDDiagnostics = probe("protected", "bounds"),
}
addon.Mainhand = { GetEditModeDiagnostics = function(_, compact)
    return compact and "Active=7 | Geometry=current" or "Active=7 | GamepadPanels=details"
end }
addon.ManualCanvas = { GetDiagnostics = probe("manual", {}) }
addon.modules.ChatBubbles = { GetDiagnostics = probe("bubbles", {}) }
addon.Canvas = {
    -- The old caller discarded reports without the substring 'loaded'.
    GetCompatibilityDiagnostics = function() return "WorldMapOwner=OpenMap" end,
    GetPanelControllerDiagnostics = probe("panels", "idle"),
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
local full = run("diag full")
for _, name in ipairs({"text", "loot", "pets", "groups", "protected", "manual", "bubbles", "panels", "dialogue"}) do
    assert(probes[name] == 1, "full diagnostics lost requested evidence: " .. name)
end
assert(full:find("diskRevision", 1, true) and full:find("GamepadPanels", 1, true)
    and full:find("User media", 1, true), "full report omitted detailed state")
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
print("PASS: compact support snapshot, conditional recovery evidence and opt-in full diagnostics")
