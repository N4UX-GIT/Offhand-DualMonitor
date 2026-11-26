--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/DonCore/Bridge.lua: built-in bridge for the Don addons (Questdon,
    Leveldon, DonMap) and their shared DonCore library

    The Don parts of Core/CanvasAddonEscape.lua moved behind the bridge
    contract; their behaviour is unchanged. Its window index names the
    Questdon quest book and DonCore's shared options window for the addon
    window Escape adapter, with their catalog entries, openers, close button
    and header drag. Its frame rules mark the Leveldon guide and the DonMap
    arrow as vendor gameplay frames, and it retires placement records older
    Offhand passes saved for them.

    Registered on every client, like the core code it replaces; the adapter
    itself runs on the Forever client only, and every check reads the addons
    when asked, so a Don addon that loads after Offhand is still handled.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local donGameplayAddons = {LeveldonPanel = "Leveldon", DonMapArrow = "DonMap"}
-- DonCore (shared by Questdon, Leveldon, DonMap) adds every Kit.Window it makes
-- to UISpecialFrames. Questdon's quest book is a workspace panel; DonCore's
-- shared options window is already handled via DonCoreOptions. Its dialogs,
-- menus, the album view and the way box keep closing with Escape; the Leveldon
-- guide, the quest list and the arrows are never registered. Verified against
-- Questdon 1.7.0, Leveldon 0.3.4-beta and DonMap 1.3.6 (Libs/DonCore/Kit.lua).
local donWindows = {
    QuestdonQuestBook = {owner = "Questdon", role = "questBook"},
}

local function Loaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

local function OrdinaryRoot(frame, parent)
    return frame and frame.IsShown and frame.GetParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and frame:GetParent() == (parent or UIParent)
end

local function IsDonGameplayRoot(frame, name, addon)
    if not Loaded(addon) or not OrdinaryRoot(frame) then return false end
    if name == "LeveldonPanel" then
        local header = frame._header
        return frame._isStylePanel == true and type(frame.ApplySettings) == "function"
            and header and header.GetParent and header:GetParent() == frame
    end
    return frame.GetObjectType and frame:GetObjectType() == "Button"
        and frame.icon and frame.shadow and frame.glow
end

-- The frame rule's verify: runs only on the Forever client for these two
-- names, inside the registry's pcall.
local function IsDonGameplayFrame(frame, name)
    local addon = donGameplayAddons[name]
    if not addon or not frame or _G[name] ~= frame then return false end
    return IsDonGameplayRoot(frame, name, addon) and true or false
end

local function DonOptions()
    if not Loaded("Leveldon") or type(LibStub) ~= "table" and type(LibStub) ~= "function" then return end
    local core = LibStub("DonCore-1.0", true)
    return core and core.Get and core:Get("Options", 1)
end

local GAMEPLAY = {names = {"LeveldonPanel", "DonMapArrow"}, when = {forever = true}, verify = IsDonGameplayFrame}

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        catalogs = {
            Leveldon = {
                settings = {position = "addon", close = "workspace-special-windows", opener = "LEVELDON"},
            },
            Questdon = {
                questBook = {position = "addon", close = "workspace-special-windows", opener = "QUESTDON"},
            },
        },
        windows = {
            sourceless = {"DonCoreOptions"},
            names = {"QuestdonQuestBook"},
            owners = {"Leveldon", "Questdon"},
            headerDrag = true,
            openers = {
                slash = {"DONCORE"},
                methods = {{get = DonOptions, key = "Open"}},
            },
        },
        frameRules = {
            vendorGameplay = {GAMEPLAY},
            preservePopup = {GAMEPLAY},
        },
    },
}

function bridge:IdentifyWindow(frame, name, source)
    if name == "DonCoreOptions" then
        local options = DonOptions()
        if options and options.Frame and options.Frame() == frame then return "Leveldon", "settings" end
        return nil
    end
    local don = donWindows[name]
    if not don then return nil end
    -- Kit.Window's own shape: a header and a close button; any addon's copy of DonCore
    if not (source:find("/libs/doncore/kit.lua:", 1, true) and type(frame.header) == "table"
        and type(frame.close) == "table") then return nil end
    if Loaded(don.owner) then return don.owner, don.role end
    return nil
end

function bridge:GetWindowCloseButtons(frame)
    return {frame.close}
end

-- Older Gather passes saved the guide and arrow anchors and also registered
-- them for Escape. Retire the records that can recreate that placement.
function bridge:RetireStalePlacements(services)
    for name in pairs(donGameplayAddons) do
        if services.HasPlacement(name) and services.IsVendorGameplayFrame(_G[name], name) then
            services.ForgetPosition(name)
            services.ForgetOpen(name)
        end
    end
end

API.RegisterBridge("DonCore", bridge)
