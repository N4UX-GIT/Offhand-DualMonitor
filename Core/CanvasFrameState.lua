--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasFrameState.lua: Addon-owned Canvas frame bookkeeping
--]]

local _, Offhand = ...

local FrameState = {}
Offhand.CanvasFrameState = FrameState

-- Never store Offhand bookkeeping on Forever's native World Map object. The
-- shareable user-waypoint pin enters restricted Blizzard code on Shift-click;
-- fields or handlers anywhere in that native map tree can taint the protected
-- chat-link action. Keep its state in this addon-owned weak table instead.
local foreverWorldMapState = setmetatable({}, { __mode = "k" })

function FrameState.IsForeverWorldMap(frame)
    return Offhand.isForever and frame and frame == _G.WorldMapFrame
end

function FrameState.GetForeverWorldMapState(frame)
    if not FrameState.IsForeverWorldMap(frame) then return nil end
    local state = foreverWorldMapState[frame]
    if not state then
        state = {}
        foreverWorldMapState[frame] = state
    end
    return state
end

function FrameState.GetMarker(frame, key)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then return state[key] end
    return frame and frame[key] or nil
end

function FrameState.SetMarker(frame, key, value)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then
        state[key] = value
    elseif frame then
        frame[key] = value
    end
end

function FrameState.SetDragging(frame, dragging)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then
        state.dragging = dragging and true or false
    else
        frame._OffhandDragging = dragging and true or false
    end
end

function FrameState.IsDragging(frame)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then return state.dragging == true end
    return frame and frame._OffhandDragging == true or false
end

function FrameState.IsEvicting(frame)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then return state.evicting == true end
    return frame._OffhandEvictingPanelSlot
end

function FrameState.SetEvicting(frame, evicting)
    local state = FrameState.GetForeverWorldMapState(frame)
    if state then
        state.evicting = evicting and true or false
    else
        frame._OffhandEvictingPanelSlot = evicting and true or nil
    end
end
