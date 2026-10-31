local owner, leatrix, combat = false, false, false
local addon = {tocVersion=20506, db={enabled=true}, CanvasFrameState={IsEvicting=function() return false end}}
addon.CanvasCompatibility = {
    HasLeatrixMaps=function() return leatrix end,
    ShouldYieldWorldMap=function() return owner end,
}
InCombatLockdown=function() return combat end
local native=function() return 980, 560 end
MapCanvasScrollControllerMixin={GetCursorPosition=native}
assert(loadfile('Core/CanvasMapPresentation.lua'))('Offhand', addon)
local adapter = addon.CanvasMapPresentation.InstallTBCCursorAdapter
local scale=0.7
local function makeMap()
    return {ScrollContainer={GetCursorPosition=native,GetEffectiveScale=function() return scale end}}
end
local map=makeMap()
assert(adapter(map))
local wrapped=map.ScrollContainer.GetCursorPosition
local x,y=wrapped(map.ScrollContainer)
assert(math.abs(x-1400)<0.001 and math.abs(y-800)<0.001)
scale=1.4
x,y=wrapped(map.ScrollContainer)
assert(math.abs(x-700)<0.001 and math.abs(y-400)<0.001, 'scale changes must be read dynamically')
-- Model the native NormalizeUIPosition calculation. A physical cursor at the
-- canvas center must select its center after both window and UI scaling.
scale=0.7
x,y=wrapped(map.ScrollContainer)
local canvasScale,childLeft,childTop,childWidth,childHeight=0.5,2400,1800,800,400
assert(math.abs((x/canvasScale-childLeft)/childWidth-0.5)<0.001)
assert(math.abs((childTop-y/canvasScale)/childHeight-0.5)<0.001)
assert(not adapter(map) and map.ScrollContainer.GetCursorPosition==wrapped, 'adapter must be idempotent')
for _,disabled in ipairs({'enabled','leatrix','owner'}) do
    addon.db.enabled,leatrix,owner = disabled~='enabled',disabled=='leatrix',disabled=='owner'
    x,y=wrapped(map.ScrollContainer)
    assert(x==980 and y==560, 'must yield when disabled or externally owned')
end
addon.db.enabled,leatrix,owner=true,false,false
for _,toc in ipairs({11200,16000,20400,30300,120107}) do
    addon.tocVersion=toc
    assert(not adapter(makeMap()), 'other clients must remain native')
end
addon.tocVersion=20506
combat=true
assert(not adapter(makeMap()))
combat=false
addon.isForever=true
assert(not adapter(makeMap()))
addon.isForever=nil
local custom=makeMap()
custom.ScrollContainer.GetCursorPosition=function() return 1,2 end
assert(not adapter(custom), 'custom cursor handlers must not be replaced')
for _,badScale in ipairs({0,-1,math.huge}) do
    scale=badScale
    x,y=wrapped(map.ScrollContainer)
    assert(x==980 and y==560)
end
print('PASS: TBC map cursor conversion tracks effective scale and yields to custom ownership')
