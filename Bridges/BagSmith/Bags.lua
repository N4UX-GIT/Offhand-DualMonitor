-- BagSmith bag provider (built into Offhand): the former BagSmith bag Escape adapter of
-- Core/BagPersistence.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 40) it replaces the Hide method of BagSmith's main view once per view (out
-- of combat), so a close from BagSmith's own native bag post-hook on the Escape path is
-- skipped while the backpack is open on the workspace, takes BagSmithFrame out of
-- UISpecialFrames there and closes the native bags BagSmith parks (the parking parent finder
-- of Bridge.lua beside this file). The generic inventory toggles are kept open while
-- BagSmithFrame is on the workspace.
-- Registered on every client before BagSmith exists. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

-- GetParkingParent: from Bridge.lua; escapeView: the main view whose Hide is replaced.
local Smith = API.GetBridgeNamespace("BagSmith")

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function RefreshBagSmithEscape(services)
    local frame = _G.BagSmithFrame
    if not frame or InCombatLockdown() or not IsAddOnLoadedCompat("BagSmith")
        or type(debugstack) ~= "function" then return end
    local view = frame.view
    if not view or view.frame ~= frame or view.isMain ~= true or type(view.Hide) ~= "function" then return end
    if Smith.escapeView ~= view then
        Smith.escapeView = view
        local vendorHide = view.Hide
        -- BagSmith closes synchronously from its native bag post-hook. Scope
        -- the exception to that hook's Escape path on the vendor's view.
        view.Hide = function(self, ...)
            if self == view and services.CanSuppressVendorClose(frame) then
                local stack = debugstack(2, 20, 0)
                if stack:find("BagSmith/Core/Hooks.lua", 1, true)
                    and services.IsGameMenuBagClose(stack) then return end
            end
            return vendorHide(self, ...)
        end
    end
    if services.UpdateEscapeRegistration(frame, "BagSmithFrame", true)
        and type(Smith.GetParkingParent) == "function" then
        services.CloseParkedNativeBags(Smith.GetParkingParent(), NUM_CONTAINER_FRAMES or 13,
            NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
    end
end

API.RegisterBridge("BagSmith", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 40,
        RefreshEscape = RefreshBagSmithEscape,
        GetToggleFrame = function() return _G.BagSmithFrame end,
    },
})
