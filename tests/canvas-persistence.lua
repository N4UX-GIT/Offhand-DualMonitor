local addon = {}

assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
local persistence = assert(addon.CanvasPersistence)

local db = {}
assert(persistence.EnsurePositionTables(db),
    "position tables must initialize for a valid profile")
assert(type(db.savedWorkspacePositions) == "table"
        and type(db.savedMainPositions) == "table",
    "workspace and Mainhand position tables must initialize together")
local existing = db.savedWorkspacePositions
assert(persistence.EnsurePositionTables(db)
        and db.savedWorkspacePositions == existing,
    "position table initialization must preserve existing records")
assert(not persistence.EnsurePositionTables(nil),
    "position table initialization must fail closed without a profile")

assert(persistence.IsPosition({ x = 0, y = 0 }),
    "zero coordinates must remain valid saved positions")
assert(persistence.IsPosition({ x = "120", y = "480" }),
    "numeric SavedVariables strings must remain compatible")
assert(not persistence.IsPosition({ x = 10 }),
    "incomplete saved positions must fail validation")

local metrics = {
    workspaceLeft = 1000,
    workspaceBottom = 100,
    workspaceRight = 2000,
    workspaceTop = 900,
    workspaceWidth = 1000,
    workspaceHeight = 800,
}

local saved = assert(persistence.CreateWorkspacePosition(
    metrics, 1010, 130, 300, 200, false
))
assert(saved.x == 1012 and saved.y == 312,
    "new workspace positions must clamp completely inside the workspace")
assert(saved.canvasLeft == 1000 and saved.canvasBottom == 100
        and saved.canvasWidth == 1000 and saved.canvasHeight == 800,
    "new workspace positions must retain their source Canvas rectangle")

local chatSaved = assert(persistence.CreateWorkspacePosition(
    metrics, 1010, 850, 300, 200, true
))
assert(chatSaved.x == 1048 and chatSaved.y == 850,
    "chat positions must preserve the wider seam inset")

local resizedMetrics = {
    workspaceLeft = 200,
    workspaceBottom = 50,
    workspaceRight = 2200,
    workspaceTop = 1650,
    workspaceWidth = 2000,
    workspaceHeight = 1600,
}
local x, y = persistence.ResolveWorkspacePosition(resizedMetrics, {
    x = 1500,
    y = 500,
    canvasLeft = 1000,
    canvasBottom = 100,
    canvasWidth = 1000,
    canvasHeight = 800,
}, 300, 200, false)
assert(x == 1200 and y == 850,
    "saved coordinates must scale relative to their original Canvas rectangle")

x, y = persistence.ResolveWorkspacePosition(metrics, {
    x = -500,
    y = 5000,
}, 0, -20, false)
assert(x == 1012 and y == 888,
    "legacy positions and invalid frame dimensions must use established clamps")
assert(persistence.ResolveWorkspacePosition(metrics, { x = 1 }, 100, 100, false) == nil,
    "incomplete saved positions must not resolve")

print("PASS: Canvas saved-position creation, scaling and clamping")
