-- Coordinate EllesmereUI's pixel grid with the live root used for spanning.
local _, Offhand = ...
local Compatibility = {}
Offhand.EllesmereScaleCompatibility = Compatibility
local updateHooks, scaleHooks = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
local pending

local function Positive(value)
    if type(value) ~= "number" then return false end
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return value == value and value > 0 and value < math.huge
end

local function Active(pp)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not EllesmereUI or EllesmereUI.PP ~= pp or not Offhand.db or not Offhand.db.enabled then return false end
    local viewport = Offhand.Viewport
    local metrics = viewport and viewport.GetMetrics and viewport:GetMetrics()
    return metrics and metrics.isSpanned == true
end

local function SyncGrid(pp)
    if not Active(pp) or not UIParent or type(UIParent.GetScale) ~= "function" then return end
    local ok, scale = pcall(UIParent.GetScale, UIParent)
    if ok and Positive(scale) and Positive(pp.perfect) then
        -- UpdateMult normally uses the saved preference. Offhand changes only
        -- the runtime root, so that saved value can describe a different grid.
        pp.mult = pp.perfect / scale
    end
end

function Compatibility:Refresh()
    local pp = EllesmereUI and EllesmereUI.PP
    if type(pp) ~= "table" or type(pp.UpdateMult) ~= "function" then return end
    if type(hooksecurefunc) == "function" then
        if updateHooks[pp] ~= pp.UpdateMult then
            hooksecurefunc(pp, "UpdateMult", function() SyncGrid(pp) end)
            updateHooks[pp] = pp.UpdateMult
        end
        if type(pp.SetUIScale) == "function" and scaleHooks[pp] ~= pp.SetUIScale then
            hooksecurefunc(pp, "SetUIScale", function()
                if not Active(pp) or pending or not C_Timer or not C_Timer.After then return end
                pending = true
                C_Timer.After(0, function()
                    pending = nil
                    if Active(pp) and Offhand.ApplyFullLayout then
                        -- Recompute physical offsets after the vendor setter has
                        -- finished, retaining the scale the player just selected.
                        Offhand:ApplyFullLayout(true)
                    end
                end)
            end)
            scaleHooks[pp] = pp.SetUIScale
        end
    end
    pp.UpdateMult()
    SyncGrid(pp)
end
