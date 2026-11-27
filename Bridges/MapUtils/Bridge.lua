-- MapUtils data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- While loaded, MapUtils is the map movement fade addon after OpenMap (map.fade, order 20),
-- and its version is listed among the map integrations (map.integration, order 30).
-- Its fade reader is the former MapUtils reader of Core/CanvasForeverMap.lua, unchanged:
-- MapUtils 1.x keeps its WORLDMAPFADE preference (unset or a boolean) in MAUTTAB, which the
-- Forever workspace map holds at false and restores afterwards; any other major version
-- keeps its setting. The Options map description names it (MAP_MOVEMENT_MAPUTILS).
-- Registered on every client, like the checks it replaces; MapUtils is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local function IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

local function ParseMajorVersion(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    if type(value) == "number" and value == value and value >= 0 and value < math.huge then
        return math.floor(value)
    end
    if type(value) ~= "string" then return nil end
    return tonumber(value:match("^v?(%d+)%."))
end

local function ReadMapUtilsFade()
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local db = _G.MAUTTAB
    if type(db) ~= "table" or not getMetadata
        or not IsAddonLoaded("MapUtils") then return end
    local version = getMetadata("MapUtils", "Version")
    if ParseMajorVersion(version) == 1
        and (db.WORLDMAPFADE == nil or type(db.WORLDMAPFADE) == "boolean") then return db end
end

API.RegisterAddonData("MapUtils", {
    ownership = {
        { role = "map.fade", name = "MapUtils", order = 20, detect = { loaded = "MapUtils" },
            read = ReadMapUtilsFade, key = "WORLDMAPFADE", opaque = false, helpKey = "MAP_MOVEMENT_MAPUTILS" },
        { role = "map.integration", name = "MapUtils", order = 30 },
    },
})
