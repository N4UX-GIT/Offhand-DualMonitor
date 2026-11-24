local base = arg[1] or "."
local combat, mouse, onWorkspace = false, false, true
local px, py, cx, cy, zoom = 0.5, 0.4, 0.5, 0.4, 20
local moves, version, owner = 0, "v0.8.13", "OpenMap"
local zone = 1455
C_AddOns = {GetAddOnMetadata = function() return version end}
InCombatLockdown = function() return combat end
IsInInstance = function() return false end
IsMouseButtonDown = function() return mouse end
C_Map = {
    GetBestMapForUnit = function() return zone end,
    GetPlayerMapPosition = function() return {GetXY = function() return px, py end} end,
}
OpenMapAPI = {
    major = 1, IsStitched = function() return true end,
    GetView = function() return cx, cy, zoom end,
    WorldFromMap = function(id, x, y) assert(id == zone); return x, y end,
    ShowWorld = function(u, v, ...)
        assert(select("#", ...) == 0, "follow must retain the wheel zoom")
        cx, cy, moves = u, v, moves + 1
        return true
    end,
}
local addon = {db = {}, CanvasCompatibility = {GetWorldMapExternalOwner = function() return owner end},
    Viewport = {GetMetrics = function() return {isSpanned = true} end},
    Canvas = {IsFrameOnWorkspace = function() return onWorkspace end}}
assert(loadfile(base .. "/Core/CanvasForeverMap.lua"))("Offhand", addon)
local map = {IsMouseOver = function() return true end}
local state = {}
local function tick() addon.CanvasForeverMap.UpdateOpenMapFollow(map, state) end
tick()
zone, px = 1426, 0.53
tick()
assert(moves == 1 and cx == px)
zoom, px = 40, 0.54
tick(); tick(); tick()
assert(moves == 2 and cx == px and zoom == 40)
cx = 0.75
tick()
assert(moves == 2, "leave a browsed-away view alone")
cx = px
tick()
mouse, px = true, 0.56
tick()
mouse = false
tick()
assert(moves == 2)
cx = px
tick()
combat, px = true, 0.57
tick()
assert(state.u == nil)
combat, onWorkspace = false, false
cx = px
tick()
assert(state.u == nil)
onWorkspace, version = true, "new"
tick()
assert(state.u == nil)
version, owner = "v0.8.13", "MoveAny"
tick()
assert(state.u == nil)
owner = "OpenMap"
tick()
assert(state.u == px, "recenter resumes following")
issecretvalue = function(value) return value == zone end
tick()
assert(state.u == nil and moves == 2, "skip restricted positions")
print("PASS: OpenMap follow, zone transition, wheel zoom, browsing and ownership")
