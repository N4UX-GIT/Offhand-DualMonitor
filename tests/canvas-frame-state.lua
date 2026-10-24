local addon = { isForever = true }
local worldMap = {}
WorldMapFrame = worldMap

assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
local frameState = assert(addon.CanvasFrameState)

assert(frameState.IsForeverWorldMap(worldMap),
    "Forever's native World Map must use isolated bookkeeping")

frameState.SetMarker(worldMap, "restoreGeneration", 7)
frameState.SetDragging(worldMap, true)
frameState.SetEvicting(worldMap, true)

assert(frameState.GetMarker(worldMap, "restoreGeneration") == 7,
    "isolated World Map markers must round-trip")
assert(frameState.IsDragging(worldMap),
    "isolated World Map drag state must round-trip")
assert(frameState.IsEvicting(worldMap),
    "isolated World Map eviction state must round-trip")
assert(rawget(worldMap, "restoreGeneration") == nil
        and rawget(worldMap, "_OffhandDragging") == nil
        and rawget(worldMap, "_OffhandEvictingPanelSlot") == nil,
    "Forever World Map bookkeeping must not be written onto the native frame")

frameState.SetMarker(worldMap, "restoreGeneration", nil)
frameState.SetDragging(worldMap, false)
frameState.SetEvicting(worldMap, false)
assert(frameState.GetMarker(worldMap, "restoreGeneration") == nil
        and not frameState.IsDragging(worldMap)
        and not frameState.IsEvicting(worldMap),
    "isolated World Map bookkeeping must clear without native frame writes")

local ordinaryFrame = {}
frameState.SetMarker(ordinaryFrame, "restoreGeneration", 9)
frameState.SetDragging(ordinaryFrame, true)
frameState.SetEvicting(ordinaryFrame, true)
assert(ordinaryFrame.restoreGeneration == 9
        and ordinaryFrame._OffhandDragging == true
        and ordinaryFrame._OffhandEvictingPanelSlot == true,
    "ordinary Canvas frames must preserve legacy marker fields")

frameState.SetDragging(ordinaryFrame, false)
frameState.SetEvicting(ordinaryFrame, false)
assert(ordinaryFrame._OffhandDragging == false
        and ordinaryFrame._OffhandEvictingPanelSlot == nil,
    "ordinary Canvas frame state must preserve legacy clearing semantics")

addon.isForever = false
frameState.SetMarker(worldMap, "nonForever", true)
assert(worldMap.nonForever == true,
    "non-Forever maps must retain ordinary frame marker behavior")

print("PASS: Canvas frame bookkeeping isolates Forever World Map state")
