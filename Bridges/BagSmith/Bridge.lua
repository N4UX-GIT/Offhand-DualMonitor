-- BagSmith data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its inventory, under Offhand's dedicated bag Escape handling and
-- kept out of the addon window picker.
-- Bag facts: on Forever, while BagSmith is loaded or present and its replacement has parked
-- the native backpack under a hidden, anonymous UIParent child, it replaces the bags
-- (hud.bags, order 120) and is a bag owner in the compatibility report (report.bags, order
-- 100). The parking parent finder is shared with its bag Escape adapter in Bags.lua beside
-- this file through the BagSmith bridge namespace.
-- Registered on every client, like the catalog entry it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

local Smith = API.GetBridgeNamespace("BagSmith")

local function IsAddonPresent(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded(name) then return true end
    elseif IsAddOnLoaded then
        if IsAddOnLoaded(name) then return true end
    end
    if _G and _G[name] ~= nil then return true end
    return false
end

local function GetBagSmithParkingParent(frame)
    -- BagSmith can leave the native bag binding enabled. Its replacement
    -- parks the native backpack under a hidden, anonymous UIParent child.
    if not frame or not frame.GetParent or (frame.IsForbidden and frame:IsForbidden()) then return end
    local parent = frame:GetParent()
    if parent and parent ~= UIParent and parent ~= _G.ContainerFrameContainer
        and not (parent.IsForbidden and parent:IsForbidden())
        and parent.GetName and parent:GetName() == nil and parent.GetParent
        and parent:GetParent() == UIParent and parent.IsShown and not parent:IsShown() then
        return parent
    end
end

-- The hidden parent BagSmith parks the native bags under, on Forever while
-- BagSmith is present, or nil.
function Smith.GetParkingParent()
    if API.IsForeverClient() and IsAddonPresent("BagSmith") then
        return GetBagSmithParkingParent(_G.ContainerFrame1)
            or GetBagSmithParkingParent(_G.ContainerFrameCombinedBags)
    end
end

local PARKED = { forever = true, present = "BagSmith",
    active = function() return Smith.GetParkingParent() ~= nil end }

API.RegisterAddonData("BagSmith", {
    ownership = {
        { role = "hud.bags", name = "BagSmith", order = 120, detect = PARKED },
        { role = "report.bags", name = "BagSmith", order = 100, detect = PARKED },
    },
    catalogs = {
        BagSmith = {
            inventory = {position = "adapter", close = "bag-adapter"},
        },
    },
})
