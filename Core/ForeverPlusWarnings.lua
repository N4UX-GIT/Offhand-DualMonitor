-- Translate only ForeverPlus's default warning bars, after its own layout.
local _, Offhand = ...
local Warnings = {}
Offhand.ForeverPlusWarnings = Warnings
local tracked = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

local function Ordinary(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Number(value)
    return Ordinary(value) and type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function ReadPoint(frame)
    if frame:GetNumPoints() ~= 1 then return nil end
    local point = { frame:GetPoint(1) }
    for index = 1, 5 do if not Ordinary(point[index]) then return nil end end
    if not Number(point[4]) or not Number(point[5]) then return nil end
    return point
end

local function SamePoint(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
        and math.abs(a[4] - b[4]) < 0.001 and math.abs(a[5] - b[5]) < 0.001
end

local function Accessible(frame)
    return frame and frame.GetPoint and frame.GetNumPoints
        and frame.ClearAllPoints and frame.SetPoint and frame.GetEffectiveScale
        and frame.GetParent and frame:GetParent() == UIParent
        and frame.IsMouseEnabled and frame:IsMouseEnabled() == false
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

local function DefaultOffset(state, original, height, gameHeight)
    local offset = original[5] / height * gameHeight
    -- ForeverPlus 1.0.6's consumable default includes fixed-size icons, timer
    -- text and eight units of air above the general row. Only its proportional
    -- component should shrink with Mainhand. A linear transform loses clearance.
    local list = state.store and state.store.list
    local general = type(list) == "table" and list.general
    if state.id ~= "consumables" or type(general) ~= "table"
        or list.consumables ~= state.bar or not Number(general.size)
        or not Number(state.bar.size) or general.size <= 0 or state.bar.size <= 0
        or type(state.owner.TimerRoom) ~= "function" then return offset end
    local ok, room = pcall(state.owner.TimerRoom)
    if not ok or not Number(room) or room < 0 then return offset end
    local clearance = general.size / 2 + state.bar.size / 2 + room + 8
    local native = math.max(height * 0.30, height * 0.22 + clearance)
    -- A different vendor layout formula keeps the generic proportional path.
    if math.abs(original[5] - native) > 0.001 then return offset end
    return math.max(gameHeight * 0.30, gameHeight * 0.22 + clearance)
end

local function Position(frame, state, metrics)
    if not Accessible(frame) then return end
    local current = ReadPoint(frame)
    local owned = SamePoint(current, state.applied)
    -- The vendor owns explicit positions and its interactive mover previews.
    -- Never persist an Offhand anchor into its bar/profile table.
    if state.bar.positioned or state.owner.movingBars
        or (frame.IsUserPlaced and frame:IsUserPlaced()) then
        state.original, state.applied = nil, nil
        return
    end
    local active = Offhand.isForever and Offhand.db and Offhand.db.enabled
        and Offhand.db.seamRedirect and metrics and metrics.isSpanned
    if not active then
        if owned then
            frame:ClearAllPoints()
            frame:SetPoint(unpack(state.original))
        end
        state.original, state.applied = nil, nil
        return
    end
    local original = owned and state.original or current
    if not original or original[1] ~= "CENTER" or original[2] ~= UIParent
        or original[3] ~= "CENTER" or original[4] ~= 0 then
        state.original, state.applied = nil, nil
        return
    end
    local parentScale, scale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
    local height = UIParent:GetHeight()
    local left, right = metrics.gameLeft, metrics.gameRight
    local bottom, top = metrics.gameBottom, metrics.gameTop
    if not (Number(parentScale) and Number(scale) and Number(height)
        and Number(left) and Number(right) and Number(bottom) and Number(top))
        or parentScale <= 0 or scale <= 0 or height <= 0
        or right <= left or top <= bottom then return end
    local factor = parentScale / scale
    -- Preserve its proportional default height within Mainhand, including
    -- stacked displays, vertical offsets and unequal effective frame scale.
    -- Native point offsets are already frame-local; convert only the center.
    local desired = { "CENTER", UIParent, "BOTTOMLEFT",
        (left + right) / 2 * factor,
        (bottom + top) / 2 * factor + DefaultOffset(state, original, height, top - bottom) }
    state.original, state.applied = original, desired
    if not SamePoint(current, desired) then
        frame:ClearAllPoints()
        frame:SetPoint(unpack(desired))
    end
end

function Warnings:IsOwnedFrame(frame)
    return frame ~= nil and tracked[frame] ~= nil
end

function Warnings:ApplyLayout(metrics)
    if InCombatLockdown and InCombatLockdown() then return end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport:GetMetrics())
    for frame, state in pairs(tracked) do pcall(Position, frame, state, metrics) end
end

function Warnings:Hook()
    if not Offhand.isForever or not hooksecurefunc
        or (InCombatLockdown and InCombatLockdown()) then return end
    local owner = _G.ForeverPlus
    if type(owner) ~= "table" or type(owner.PlaceAsBar) ~= "function"
        or hooked[owner] then return end
    hooked[owner] = true
    -- A public vendor transaction identifies the otherwise anonymous roots.
    -- Do not scan icon children, attach frame scripts, or touch input handling.
    hooksecurefunc(owner, "PlaceAsBar", function(self, frame, id, bar, store)
        if self ~= owner or type(bar) ~= "table" then return end
        pcall(function()
            if not Accessible(frame) or owner.movingBars then return end
            local state = { owner = owner, bar = bar, id = id, store = store }
            tracked[frame] = state
            if not (InCombatLockdown and InCombatLockdown()) then
                Position(frame, state, Offhand.Viewport and Offhand.Viewport:GetMetrics())
            end
        end)
    end)
end
