--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/EllesmereUI/Scale.lua: built-in bridge for EllesmereUI's pixel grid

    This is the former Core/EllesmereScaleCompatibility.lua moved behind the
    bridge contract; its behaviour is unchanged. It reads Offhand's enabled and
    spanned state and requests a full layout through Offhand.API only.

    Core calls RefreshScale() on every full layout pass, right after Offhand
    applies its global UI scale. Like the core module it registers on every
    client before EllesmereUI exists and looks EllesmereUI.PP up on each call,
    so an EllesmereUI that loads after Offhand is still hooked.
--]]

-- Coordinate EllesmereUI's pixel grid with the live root used for spanning.
local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.IsEnabled) ~= "function" or type(API.GetOptionsMetrics) ~= "function"
    or type(API.RequestFullLayout) ~= "function" or type(API.GetBridgeNamespace) ~= "function" then return end

local Compatibility = {}
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

-- Options metrics are the viewport metrics while Offhand is enabled and spanned.
local function Active(pp)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not EllesmereUI or EllesmereUI.PP ~= pp or not API.IsEnabled() then return false end
    return API.GetOptionsMetrics() ~= nil
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
                    if Active(pp) then
                        -- Recompute physical offsets after the vendor setter has
                        -- finished, retaining the scale the player just selected.
                        API.RequestFullLayout(true)
                    end
                end)
            end)
            scaleHooks[pp] = pp.SetUIScale
        end
    end
    pp.UpdateMult()
    SyncGrid(pp)
end

-- The EllesmereUI files share one bridge object (the namespace's bridge).
local ns = API.GetBridgeNamespace("EllesmereUI")
local bridge = ns.bridge or { contract = API.BRIDGE_CONTRACT }
ns.bridge = bridge

function bridge:RefreshScale()
    Compatibility:Refresh()
end

if API.RegisterBridge("EllesmereUI", bridge) then
    ns.Scale = Compatibility
end
