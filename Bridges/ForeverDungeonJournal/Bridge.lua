--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/ForeverDungeonJournal/Bridge.lua: built-in bridge for
    ForeverDungeonJournal

    The journal parts of Core/CanvasAddonEscape.lua and Core/HUDRecovery.lua
    moved behind the bridge contract; their behaviour is unchanged. Its window
    index names the journal root for the addon window Escape adapter (known by
    its name alone, before any source location is read), with its catalog
    entry (the picker may learn its placement) and its close button. Its frame
    rule names its minimap button for the minimap visibility report.

    Registered on every client, like the core code it replaces; the adapter
    itself runs on the Forever client only, and the addon is read when asked.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local function Loaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        catalogs = {
            ForeverDungeonJournal = {
                journal = {position = "addon", close = "workspace-special-windows", opener = "FOREVERDUNGEONJOURNAL",
                    learnPlacementFile = "core/journal.lua"},
            },
        },
        windows = {
            sourceless = {"ForeverDungeonJournalFrame"},
            owners = {"ForeverDungeonJournal"},
        },
        frameRules = {
            minimapDiagnosticFrame = {"LibDBIcon10_ForeverDungeonJournal"},
        },
    },
}

function bridge:IdentifyWindow(frame, name)
    if name == "ForeverDungeonJournalFrame" and Loaded("ForeverDungeonJournal") then
        return "ForeverDungeonJournal", "journal"
    end
    return nil
end

function bridge:GetWindowCloseButtons(frame)
    return {frame.closeButton}
end

API.RegisterBridge("ForeverDungeonJournal", bridge)
