-- Lua 5.1. Placement checkpoints survive reload, but identify the loaded layout.
local addon = {}
local checkpoint
local metrics = {
    physicalWidth = 4000, physicalHeight = 2560, companionTopology = true,
    gamePixelLeft = 1440, gamePixelBottom = 6, gamePixelWidth = 2560, gamePixelHeight = 1440,
    workspacePixelLeft = 0, workspacePixelBottom = 0,
    workspacePixelWidth = 1440, workspacePixelHeight = 2560,
}
addon.Viewport = {GetMetrics = function() return metrics end}
addon.GetOnboardingSetupMethod = function() return "COMPANION" end
addon.GetPlacementCheckpoint = function() return checkpoint end
addon.SetPlacementCheckpoint = function(_, value) checkpoint = value end
InCombatLockdown = function() return false end
local function Reload()
    assert(loadfile("Core/SetupPlacement.lua"))("Offhand", addon)
    return addon.SetupPlacement
end
local placement = Reload()
assert(placement:AcknowledgeSpan() and placement:RequestReload())
assert(placement:GetStage() == "RELOAD", "requesting reload must not complete it")
placement = Reload()
local stage, signature = placement:GetStage()
assert(stage == "CONFIRM" and placement:Confirm(signature))
assert(placement:GetStage() == "READY")
local saved = checkpoint

-- Mainhand changes while the bounding canvas stays identical.
metrics.gamePixelLeft, metrics.gamePixelBottom = 0, 0
metrics.gamePixelWidth, metrics.gamePixelHeight = 1440, 2560
assert(placement:GetStage() == "SPAN", "the old Mainhand confirmation must not cover another rectangle")
assert(not placement:Confirm(signature), "a previous confirmation must not approve changed geometry")
metrics.gamePixelLeft, metrics.gamePixelBottom = 1440, 6
metrics.gamePixelWidth, metrics.gamePixelHeight = 2560, 1440
assert(placement:GetStage() == "READY", "returning to the same layout must reuse confirmation")

metrics.workspaceRegions = {
    {id = "left", pixelX = 0, pixelY = 0, pixelWidth = 720, pixelHeight = 2560},
    {id = "right", pixelX = 720, pixelY = 0, pixelWidth = 720, pixelHeight = 2560},
}
metrics.primaryWorkspaceRegion = "left"
assert(placement:GetStage() == "SPAN")
assert(placement:AcknowledgeSpan() and placement:RequestReload())
placement = Reload()
stage, signature = placement:GetStage()
assert(stage == "CONFIRM" and placement:Confirm(signature))
metrics.workspaceRegions[1], metrics.workspaceRegions[2] = metrics.workspaceRegions[2], metrics.workspaceRegions[1]
assert(placement:GetStage() == "READY", "equivalent region ordering must keep confirmation")
metrics.workspaceRegions[1].pixelWidth = 700
assert(placement:GetStage() == "SPAN", "a secondary workspace change must invalidate confirmation")
metrics.workspaceRegions = nil
metrics.primaryWorkspaceRegion = nil
checkpoint = saved

-- Older dimension-only checkpoints receive a placement review without forcing
-- another reload. The new confirmation then records the exact rectangles.
checkpoint = "V1|COMPANION|4000|2560|C"
placement = Reload()
stage, signature = placement:GetStage()
assert(stage == "CONFIRM" and placement:Confirm(signature))
assert(checkpoint ~= "V1|COMPANION|4000|2560|C" and placement:GetStage() == "READY")

-- The first requested reload can precede the appearance of exact topology.
metrics.companionTopology = false
checkpoint = nil
placement = Reload()
assert(placement:AcknowledgeSpan() and placement:RequestReload())
metrics.companionTopology = true
assert(placement:GetStage() ~= "CONFIRM", "topology arriving in the same UI session cannot prove reload")
placement = Reload()
stage, signature = placement:GetStage()
assert(stage == "CONFIRM" and placement:Confirm(signature))
print("PASS: exact placement identity, unchanged reuse, workspace changes and legacy checkpoint upgrades")
