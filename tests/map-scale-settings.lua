-- Synthetic ownership/settings regression. Native rendering and taint need live QA.
local owner, combat, gamepad, stitched, disabled = nil, false, false, true, false
local map = {scale=1, workspace=true}
function map:GetScale() return self.scale end
function map:GetEffectiveScale() return self.scale * .8 end
function map:GetWidth() return 1000 end
function map:GetHeight() return 800 end
function map:IsMaximized() return self.maximized end
function map:IsForbidden() return self.forbidden end
WorldMapFrame = map
UIParent = {GetEffectiveScale=function() return .8 end}
InCombatLockdown = function() return combat end
local metrics = {isSpanned=true,workspaceWidth=1024,workspaceHeight=1000,gameWidth=2024,gameHeight=1800}
local addon = {isForever=true, db={enabled=true,workspaceMapScale=1,mainMapScale=1},
    CanvasCompatibility={GetWorldMapExternalOwner=function() return owner end},
    IsGamepadUIEnabled=function() return gamepad end,
    Viewport={GetMetrics=function() return metrics end},
    Canvas={IsFrameOnWorkspace=function() return map.workspace end}}
local applies = 0
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
addon.CanvasCompatibility.GetWorldMapExternalOwner = function() return owner end
function addon.Canvas:ConfigureWorldMap()
    applies = applies + 1
    map.scale = addon.db[map.workspace and "workspaceMapScale" or "mainMapScale"]
end
assert(loadfile("Core/MapScale.lua"))("Offhand", addon)
local scale = addon.MapScale
assert(scale:Set(.75) and addon.db.workspaceMapScale==.75 and applies==1)
map.workspace=false
assert(scale:Set(1.25) and addon.db.mainMapScale==1.25 and addon.db.workspaceMapScale==.75)
assert(not scale:Set(0/0) and not scale:Set(math.huge) and not scale:Set("1.5"))

local ownerDB = {enabled=true,windowScale=1,window={"TOPLEFT","TOPLEFT",100,-100},windowSize={1000,800}}
local ownerApplies = 0
local module = {db=ownerDB, Refresh=function() error("scale must not rebuild data providers") end}
function module:WindowOptions(options, get, set, off)
    options.windowScale = {min=.5,max=1.6,step=.05,
        disabled=function() return off() or disabled end,
        set=function(info, value)
            assert(info[1]=="windowScale")
            set(info,value)
            map.scale=ownerDB.windowScale
            ownerApplies=ownerApplies+1
        end}
end
OpenMap = {version="v0.7.5-beta",GetModule=function(_, name) assert(name=="worldmap"); return module end}
OpenMapDB = {worldmap=ownerDB}
OpenMapAPI = {major=1,version=4,IsStitched=function() return stitched end}
owner="OpenMap"
map.workspace=true
-- Stale native positions cannot choose the side for an externally owned map.
addon.db.savedMainPositions={WorldMapFrame={}}
local anchor, size = ownerDB.window, ownerDB.windowSize
assert(scale:GetState().max==1.6 and scale:Set(1.5))
assert(map.scale==1.5 and ownerDB.windowScale==1.5 and applies==2)
assert(ownerDB.window==anchor and ownerDB.windowSize==size)
assert(scale:Set(2.5) and ownerDB.windowScale==1.6)
assert(scale:Set("AUTO") and math.abs(ownerDB.windowScale-1)<.0001 and math.abs(map.scale-1)<.0001)
assert(addon.db.workspaceMapScale==.75 and addon.db.mainMapScale==1.25,
    "OpenMap action changed an inactive native preference")

local function Refuses()
    local oldScale, count = ownerDB.windowScale, ownerApplies
    assert(not scale:GetState().available and not scale:Set(1.2))
    assert(ownerDB.windowScale==oldScale and ownerApplies==count)
end
combat=true; Refuses(); combat=false
gamepad=true; Refuses(); gamepad=false
map.maximized=true; Refuses(); map.maximized=false
map.forbidden=true; Refuses(); map.forbidden=false
disabled=true; Refuses(); disabled=false
stitched=false; Refuses(); stitched=true
ownerDB.enabled=false; Refuses(); ownerDB.enabled=true
addon.db.enabled=false; Refuses(); addon.db.enabled=true
OpenMap.version="v0.7.6-beta"; Refuses(); OpenMap.version="v0.7.5-beta"
module.MoveAnyOn=function() return true end; Refuses(); module.MoveAnyOn=nil
OpenMapAPI.version=5; Refuses(); OpenMapAPI.version=4
OpenMapDB.worldmap={}; Refuses(); OpenMapDB.worldmap=ownerDB
for _, name in ipairs({"MoveAny","LeatrixMaps","ClassicUIForever"}) do owner=name; Refuses() end
owner="OpenMap"
map.workspace=false
OpenMap.version="v0.8.6"
assert(scale:Set(1.2) and ownerDB.windowScale==1.2)
OpenMap.version="v0.8.7"
assert(scale:Set("AUTO") and ownerDB.windowScale==1.6,
    "Mainhand auto fit did not use the current owner's side and range")
ownerDB.mapFpsCap = 24
GetCVar = function(name) assert(name == "maxFPS"); return "24" end
local diagnostics = addon.CanvasCompatibility.GetDiagnostics(false)
assert(diagnostics:find("OpenMap=v0.8.7 | MapFPSCap=24 | maxFPS=24 | OpenMapWindow=saved", 1, true))
assert(not addon.CanvasCompatibility.GetDiagnostics(true):find("MapFPSCap=", 1, true),
    "map performance settings belong in detailed diagnostics")
print("PASS: map settings route by active side/owner, fit and enforce version, fullscreen, combat and ownership guards")
