-- Run from the repository root with Lua 5.1.
local handler, events, timers = nil, {}, {}
local area, shownID, center = 1, 1, 1
local combat, visible, spanned, stitched, instance = false, true, true, true, false
local moves, version = 0, "v0.8.13"
local function flush()
    while #timers > 0 do table.remove(timers, 1)() end
end
local function fire(event)
    if events[event] then handler(nil, event) end
end
local function cross(id)
    area = id
    fire("ZONE_CHANGED_NEW_AREA")
    fire("ZONE_CHANGED")
    flush()
end
CreateFrame = function() return {
    SetScript = function(_, _, fn) handler = fn end,
    RegisterEvent = function(_, name) events[name] = true end,
    UnregisterAllEvents = function() events = {} end,
} end
SlashCmdList, date = {}, os.date
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
InCombatLockdown = function() return combat end
IsInInstance = function() return instance end
C_AddOns = {GetAddOnMetadata = function() return version end}
C_Map = {GetBestMapForUnit = function() return area end,
    GetPlayerMapPosition = function() return {x = 0.4, y = 0.6} end}
WorldMapFrame = {IsVisible = function() return visible end, GetMapID = function() return shownID end,
    IsMaximized = function() return false end}
Offhand = {isForever = true, db = {enabled = true},
    CanvasCompatibility = {GetWorldMapExternalOwner = function() return OpenMapAPI and "OpenMap" end},
    Canvas = {IsFrameOnWorkspace = function() return true end, CanManagePanelsFromAddon = function() return true end},
    Viewport = {GetMetrics = function() return {isSpanned = spanned} end}}
local api = {major = 1, IsStitched = function() return stitched end,
    GetView = function() return 0.3, 0.4, 12 end, MapAt = function() return center end,
    WorldFromMap = function(id, x, y) assert(id == area) return x, y end,
    ShowWorld = function(x, y, zoom)
        assert(x == 0.4 and y == 0.6 and zoom == nil)
        moves, center = moves + 1, area
        return true
    end}
dofile("tools/map-zone-qa/OffhandZoneQA/Zone.lua")
local cmd = SlashCmdList.OFFHANDZONEQA
cmd("watch")
cross(2)
assert(moves == 0)
local requests = 0
WorldMapFrame.IsForbidden = function() return false end
C_Map.OpenWorldMap = function(id)
    assert(id == area and not combat)
    requests = requests + 1
end
cmd("native")
shownID = 999
cross(20)
assert(requests == 0, "leave a browsed zone alone")
shownID = area
cross(21)
shownID = area
cross(22)
assert(requests == 1, "native trial must disarm after one request")
OpenMapAPI = api
cmd("watch")
cross(3)
assert(moves == 0)
cmd("trial")
center = area
cross(4)
cross(4)
assert(moves == 1)
center = 99
cross(5)
visible = false
center = area
cross(6)
visible, spanned, center = true, false, area
cross(7)
spanned, instance, center = true, true, area
cross(8)
instance, stitched, center = false, false, area
cross(9)
stitched, version, center = true, "future", area
cross(10)
version, center, combat = "v0.8.13", area, true
fire("PLAYER_REGEN_DISABLED")
cross(11)
combat = false
fire("PLAYER_REGEN_ENABLED")
flush()
assert(moves == 1)
center = area
area = 12
fire("ZONE_CHANGED_NEW_AREA")
cmd("off")
flush()
assert(moves == 1 and not next(events))
local tick, cancelled
C_Timer.NewTicker = function(_, fn)
    tick, cancelled = fn, false
    return {Cancel = function() cancelled = true end}
end
local zoom, drag, currentX, centerX = 12, false, 0.4, 0.3
api.GetView = function() return centerX, 0.6, zoom end
api.ShowWorld = function(x, y, z)
    assert(x == currentX and y == 0.6 and z == nil)
    moves, centerX = moves + 1, x
    return true
end
C_Map.GetPlayerMapPosition = function() return {x = currentX, y = 0.6} end
WorldMapFrame.IsMouseOver = function() return true end
IsMouseButtonDown = function() return drag end
cmd("follow")
tick()
tick()
assert(moves == 2)
currentX, zoom = 0.41, 18
tick()
assert(moves == 2)
tick()
assert(moves == 3 and zoom == 18)
area, currentX, combat = 13, 0.42, true
tick()
assert(moves == 3)
combat = false
tick()
assert(moves == 4)
drag = true
tick()
assert(cancelled)
cmd("off")
print("PASS: zone QA baseline, public recenter, duplicate events, scope and cancellation")
