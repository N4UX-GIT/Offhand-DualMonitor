-- ClassicUI Forever data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its world map and character windows, whose geometry and lifecycle
-- it keeps.
-- ClassicUI Forever has its own persistent movement for WorldMapFrame and CharacterFrame.
-- While it is loaded Offhand yields both frames to it (panels.externalOwner, the frames
-- list), whatever the client family, and it is the World Map owner after MoveAny
-- (map.owner, order 20, shown as "ClassicUI Forever"). It also manages the native panels
-- (map.blocksPanelManagement, order 20). Diagnostics: "ClassicUIForever=loaded" before the
-- map owner (compat.head, order 20) and "CharacterFrameOwner=ClassicUIForever" after it
-- (compat.map, order 10), only while loaded; its version among the map integrations
-- (map.integration, order 80).
-- Registered on every client, like the catalog entry and checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local LOADED = { loaded = "ClassicUIForever" }

API.RegisterAddonData("ClassicUIForever", {
    ownership = {
        { role = "panels.externalOwner", name = "ClassicUIForever", order = 10, detect = LOADED,
            frames = { "WorldMapFrame", "CharacterFrame" } },
        { role = "map.owner", name = "ClassicUIForever", order = 20, detect = LOADED, label = "ClassicUI Forever" },
        { role = "map.blocksPanelManagement", name = "ClassicUIForever", order = 20, detect = LOADED },
        { role = "map.integration", name = "ClassicUIForever", order = 80 },
    },
    diagnostics = {
        { slot = "compat.head", order = 20, label = "ClassicUIForever", detect = LOADED },
        { slot = "compat.map", order = 10, label = "CharacterFrameOwner", detect = LOADED, text = "ClassicUIForever" },
    },
    catalogs = {
        ClassicUIForever = {
            worldMap = {position = "addon", close = "native"},
            character = {position = "addon", close = "native"},
        },
    },
})
