local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local ns = shared
if type(shared) == "table" and shared.API and shared.API.GetBridgeNamespace then
    ns = shared.API.GetBridgeNamespace("DaylightUI")
end
if type(ns) ~= "table" or not ns.active then return end

-- ---------------------------------------------------------------------
-- The layout's upkeep: Offhand rescales the UI and follows the monitors
-- without an event of the game's to go by, so it calls the bridge (twice a
-- second on this client, and on its layout and map updates) and reports
-- each change of the game rectangle.
-- ---------------------------------------------------------------------

function ns.RefreshLayout()
    if not ns.layout then return end
    ns.Refresh()
    if ns.SceneRefresh then ns.SceneRefresh() end
    if ns.FireRefresh then ns.FireRefresh() end
    if ns.BarRefresh then ns.BarRefresh() end
    if ns.CdmRefresh then ns.CdmRefresh() end
end

local function IsLoaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if type(query) ~= "function" then return _G[name] ~= nil end
    local ok, loaded = pcall(query, name)
    return ok and loaded and true or false
end

local bridge = {
    contract = 1,
    mapAddons = { "DaylightUI" },
    catalog = {
        suitePrefix = "daylightui_",
        settings = { position = "addon", close = "native", learnPlacementFile = "options/panel.lua" },
        hud = { position = "addon", close = "native" },
    },
}

function bridge:Refresh(reason)
    if ns.Map then ns.Map:Refresh() end
    ns.RefreshLayout()
end

function bridge:RefreshBags(services)
    if ns.Bags then ns.Bags.Refresh(services) end
end

function bridge:GetDiagnostics()
    return ns.Map and ns.Map:GetDiagnostics() or nil
end

function bridge:ShouldPreserveSingleScreenPosition(frame, metrics)
    return ns.Map and ns.Map:ShouldPreserveSingleScreenPosition(frame, metrics) or false
end

function bridge:GetBagFrames()
    return ns.Bags and ns.Bags.GetFrames() or nil
end

function bridge:IsEditModeActive()
    local dui = _G.DaylightUI or ns.DUI
    if type(dui) == "table" and type(dui.Movers) == "table" and dui.Movers.unlocked == true then
        return true
    end
    local cdm = _G.DaylightUICdmEditor
    return type(cdm) == "table" and type(cdm.IsShown) == "function" and cdm:IsShown() == true
end

function bridge:IdentifyLearnPlacement(frame, name, file)
    if name == "DaylightUIOptions" and file == "options/panel.lua" and IsLoaded("DaylightUI")
        and frame and frame.GetParent and frame:GetParent() == UIParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected()) then
        return "settings"
    end
end

Offhand.API.RegisterBridge("DaylightUI", bridge)
Offhand.API.RegisterGeometryCallback(ns, function() ns.RefreshLayout(); return true end)

-- ---------------------------------------------------------------------
-- Events and /ohdaylight
-- ---------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
                         "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    events:RegisterEvent(event)
end

events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME or name == "Offhand" then ns.DB() end
        if name ~= ADDON_NAME and name ~= "Offhand" then return end
    elseif event == "PLAYER_LOGIN" then
        if ns.legacy then
            ns.Print("the older DaylightOffhand addon is still enabled; disable or delete it so Offhand's built-in bridge can take over DaylightUI's layout.")
        end
        if ns.layout and ns.Sweep then ns.Sweep() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not (ns.pending or ns.sweepPending) then return end
        ns.pending = false
        if ns.sweepPending and ns.layout and ns.Sweep then ns.Sweep() end
    end
    if not ns.layout then return end
    ns.RefreshLayout()
    if event == "PLAYER_ENTERING_WORLD" then
        -- Offhand's own start-up can come after this.
        C_Timer.After(1, function() ns.Refresh() end)
        if ns.Check then ns.Check() end
    end
end)

SLASH_OFFHANDDAYLIGHTUI1 = "/ohdaylight"
SlashCmdList.OFFHANDDAYLIGHTUI = function(msg)
    msg = string.lower(string.match(msg or "", "^%s*(.-)%s*$"))
    local Print = ns.Print
    local function MapLine()
        local ok, who = pcall(function() return ns.Map and ns.Map:GetDiagnostics() end)
        Print("world map: " .. tostring(ok and who or "DaylightUI's own mover (Offhand has no saved map position)"))
    end
    if not ns.layout then
        if ns.legacy then
            Print("standing aside: the older DaylightOffhand addon is still enabled and places DaylightUI's layout.")
        else
            Print("DaylightUI's Movers or EditMode weren't found; its layout is left as it is.")
        end
        MapLine()
        return
    end
    if msg == "apply" then
        if ns.Ask then ns.Ask() end
        return
    end
    ns.Refresh()
    local l, b, r, t, sw, sh = ns.gameRect()
    Print(string.format("game area %.0f,%.0f to %.0f,%.0f of a %.0f x %.0f screen; layout %s.",
        l, b, r, t, sw, sh, (ns.layoutStale and ns.layoutStale()) and "needs moving (/ohdaylight apply)" or "in place"))
    MapLine()
    local GameMovers = ns.DUI.GameMovers
    if type(GameMovers) == "table" and type(GameMovers.RollSlot) == "function" then
        local ok, x, y = pcall(GameMovers.RollSlot)
        if ok and type(x) == "number" and type(y) == "number" then
            Print(string.format("loot rolls hang at %.0f,%.0f (%s)", x + sw / 2, y + sh / 2,
                type(GameMovers.Spot) == "function" and GameMovers.Spot(ns.ROLLS) and "where you put DaylightUI's handle"
                or (ns.rollSpot and ns.rollSpot(100)) and "Offhand's spot on the game area" or "DaylightUI's own spot"))
        end
    end
    Print("/ohdaylight apply - rebuild DaylightUI's Edit Mode layout for the game area and reload")
end
