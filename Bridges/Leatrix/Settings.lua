--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Leatrix/Settings.lua: built-in bridge for the Leatrix Maps,
    Leatrix Plus and Leatrix Sounds settings windows

    The Leatrix parts of Core/CanvasAddonEscape.lua moved behind the bridge
    contract; their behaviour is unchanged. Its window index matches the
    anonymous configuration panels (17-character F names) for the addon window
    Escape adapter, with the three catalogs and their close buttons. The
    Leatrix Maps world map provider and Options contribution of Maps.lua,
    loaded before this file, join the same bridge object.

    Registered on every client, like the core code it replaces; the adapter
    itself runs on the Forever client only, and the addons are read when asked.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local VENDORS = {"Leatrix_Maps", "Leatrix_Plus", "Leatrix_Sounds"}

local function Loaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

local function Source(frame)
    if not frame.GetSourceLocation then return nil end
    local value = frame:GetSourceLocation()
    -- ObjectDebug access can return a secret. Never compare or format it first.
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "string" then return nil end
    return value:gsub("\\", "/"):lower()
end

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        catalogs = {
            Leatrix_Maps = {
                settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Maps"},
                worldMap = {position = "addon", close = "map-adapter"},
            },
            Leatrix_Plus = {
                settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Plus"},
            },
            Leatrix_Sounds = {
                settings = {position = "addon", close = "workspace-special-windows", opener = "Leatrix_Sounds"},
            },
        },
        windows = {
            -- An F and sixteen letters or digits: the vendors' random root names.
            patterns = {"^F" .. string.rep("%w", 16) .. "$"},
            owners = VENDORS,
        },
    },
}

function bridge:IdentifyWindow(frame, name, source)
    if not frame.GetFrameStrata or frame:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then return nil end
    for _, vendor in ipairs(VENDORS) do
        local lower = vendor:lower()
        if Loaded(vendor) and source:find("/" .. lower .. "/" .. lower .. ".lua:", 1, true) then
            if vendor == "Leatrix_Sounds" then
                if frame.cb and frame.mainTex and frame.footTex then return vendor, "settings" end
            elseif (frame.mt and frame.v) or (frame.c and frame.r and frame.b) then
                return vendor, "settings"
            end
        end
    end
end

local maps = API.GetBridgeNamespace("Leatrix").Maps
if type(maps) == "table" then
    bridge.mapProvider = maps.mapProvider
    bridge.GetSettingsContributions = maps.GetSettingsContributions
end

function bridge:GetWindowCloseButtons(frame, owner)
    if owner == "Leatrix_Sounds" then return {frame.cb} end
    if frame.c then return {frame.c} end
    -- Maps/Plus main X buttons are anonymous helper-created children. Inspect
    -- only this verified root's bounded direct children, not its whole tree.
    if not frame.GetNumChildren or frame:GetNumChildren() > 128 or not frame.GetChildren then return {} end
    local result = {}
    for _, child in ipairs({frame:GetChildren()}) do
        if child and not (child.IsForbidden and child:IsForbidden())
            and not (child.IsProtected and child:IsProtected())
            and child.GetObjectType and child:GetObjectType() == "Button"
            and child.GetParent and child:GetParent() == frame and child.GetPoint then
            local point, relative, relativePoint, x, y = child:GetPoint(1)
            local source = Source(child)
            local vendor = owner:lower()
            if point == "TOPRIGHT" and relative == frame and relativePoint == "TOPRIGHT"
                and x == 0 and y == 0 and source
                and source:find("/" .. vendor .. "/" .. vendor .. ".lua:", 1, true)
                -- Native scaled dimensions contain small floating-point drift.
                and child.GetWidth and math.abs(child:GetWidth() - 30) < .01
                and child.GetHeight and math.abs(child:GetHeight() - 30) < .01 then
                result[#result + 1] = child
            end
        end
    end
    return result
end

API.RegisterBridge("Leatrix", bridge)
