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

-- Native P/talent toggles and skinned close buttons must clear reload intent,
-- without adding hide hooks to Blizzard frames or treating a zone hide as close.
addon.isRetail = true
addon.db = {enabled=true, openWorkspacePanels={PlayerSpellsFrame=true},
    savedWorkspacePositions={PlayerSpellsFrame={x=100,y=800}}, workspacePlayerSpellsTab="talents"}
local callbacks, timers, registrations = {}, {}, 0
EventRegistry = {RegisterCallback=function(_,name,callback,owner)
    registrations=registrations+1; callbacks[name]=function() callback(owner) end
end}
C_Timer = {After=function(_,callback) timers[#timers+1]=callback end}
local canvas = {SetWorkspacePanelOpen=function(_,name,open)
    addon.db.openWorkspacePanels[name]=open and true or nil
end}
PlayerSpellsFrame = {shown=false, IsShown=function(self) return self.shown end}
local function flush()
    local pending=timers; timers={}
    for _,callback in ipairs(pending) do callback() end
end
assert(persistence.InstallPlayerSpellsCloseObserver(canvas))
assert(not persistence.InstallPlayerSpellsCloseObserver(canvas) and registrations==1)
callbacks["PlayerSpellsFrame.CloseFrame"]()
callbacks["PlayerSpellsFrame.CloseFrame"]()
assert(#timers==1, "repeated close notifications must coalesce")
flush()
assert(not addon.db.openWorkspacePanels.PlayerSpellsFrame,
    "native close must clear stale reopen intent")
assert(addon.db.savedWorkspacePositions.PlayerSpellsFrame.x==100
    and addon.db.workspacePlayerSpellsTab=="talents", "close must preserve anchor and tab")
addon.db.openWorkspacePanels.PlayerSpellsFrame=true
callbacks["PlayerSpellsFrame.CloseFrame"]()
PlayerSpellsFrame.shown=true
flush()
assert(addon.db.openWorkspacePanels.PlayerSpellsFrame,
    "a minimize hide/show must preserve open intent")
PlayerSpellsFrame.shown=false
callbacks["PlayerSpellsFrame.CloseFrame"]()
addon._openPanelsCapturedForTransition=true
flush()
assert(addon.db.openWorkspacePanels.PlayerSpellsFrame,
    "transition hide must preserve the last active snapshot regardless of event order")
addon._openPanelsCapturedForTransition=false
callbacks["PlayerSpellsFrame.CloseFrame"]()
flush()
assert(not addon.db.openWorkspacePanels.PlayerSpellsFrame,
    "a later explicit close must still clear intent")
addon.isRetail=false
assert(not persistence.InstallPlayerSpellsCloseObserver({}))
addon.isRetail=true; addon.isForever=true
assert(not persistence.InstallPlayerSpellsCloseObserver({}))
print("PASS: native PlayerSpells close intent, transient visibility and transition preservation")
