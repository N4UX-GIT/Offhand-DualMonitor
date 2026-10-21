-- Lua 5.1. Pure remembered-canvas validation and matching regression.
local addon = { db = {
    layoutPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
    primaryPosition = "RIGHT",
} }
OffhandDB = {}
assert(loadfile("Core/ManualCanvas.lua"))("Offhand", addon)

local manager = addon.ManualCanvas
local metrics = {
    physicalWidth = 3998, physicalHeight = 2480,
    screenWidth = 3048, screenHeight = 1890,
    gamePixelLeft = 1439, gamePixelBottom = 0,
    gamePixelWidth = 2559, gamePixelHeight = 1439,
    workspacePixelLeft = 0, workspacePixelBottom = 0,
    workspacePixelWidth = 1439, workspacePixelHeight = 2480,
}

local ok, id, record = manager:RememberFromMetrics(metrics, "FancyZones desk", "FANCYZONES")
assert(ok and id == "manual-1" and record.source == "FANCYZONES")
assert(OffhandDB.manualCanvasSchema == 1 and OffhandDB.preferredGeometrySource == "MANUAL",
    "remembering a manual or FancyZones canvas must keep stale exact topology from retaking priority")

local exact = manager:Match(3998, 2480, 3048 / 1890, addon.db)
assert(exact.state == "MATCH" and exact.id == id)

local smallDrift = manager:Match(3970, 2464, (3048 / 1890) * 0.999, addon.db)
assert(smallDrift.state == "MATCH", "small border drift must remain a match")

local close = manager:Match(3922, 2430, (3048 / 1890) * 0.99, addon.db)
assert(close.state == "CLOSE", "a plausible resized window must be close, not exact")

local single = manager:Match(2114, 1353, 1874 / 1200, addon.db)
assert(single.state == "MISMATCH", "ordinary one-monitor geometry must fail safely")

addon.db.primaryPosition = "LEFT"
assert(manager:Match(3998, 2480, 3048 / 1890, addon.db).state == "MATCH",
    "canvas recognition must remain independent from profile-scoped Mainhand placement")
addon.db.primaryPosition = "RIGHT"

OffhandDB.manualCanvases["manual-2"] = record
local ambiguous = manager:Match(3998, 2480, 3048 / 1890, addon.db)
assert(ambiguous.state == "AMBIGUOUS" and ambiguous.candidateCount == 2)
OffhandDB.manualCanvases["manual-2"] = nil

local malformed = {}
for key, value in pairs(record) do malformed[key] = value end
malformed.game = { x = 0.9, y = 0, width = 0.5, height = 1 }
OffhandDB.manualCanvases.bad = malformed
assert(manager:Match(3998, 2480, 3048 / 1890, addon.db).id == "manual-1",
    "malformed records must be ignored without mutating valid records")

assert(manager:SetGeometryPreference("MANUAL"))
assert(manager:GetGeometryPreference() == "MANUAL")
assert(not manager:SetGeometryPreference("UNKNOWN"))
assert(manager:Forget(id) and not manager:Forget(id))

local future = { manualCanvasSchema = 99, manualCanvases = { keep = { sentinel = true } } }
OffhandDB = future
assert(manager:GetDiagnostics().state == "FUTURE_SCHEMA")
assert(future.manualCanvasSchema == 99 and future.manualCanvases.keep.sentinel,
    "future schemas must be rejected without mutating their stored data")
assert(not manager:RememberFromMetrics(metrics, "Must not write", "MANUAL"))

print("PASS: remembered manual and FancyZones canvas validation, confidence, ambiguity, and safe mismatch")
