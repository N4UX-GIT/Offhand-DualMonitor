-- OpenMap data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- Addon window catalog: its world map, under OpenMap's own geometry and the dedicated map
-- policy. Its map handling is the OpenMap bridge in this folder (Init.lua).
-- While loaded, OpenMap is the World Map owner after MoveAny and ClassicUI Forever (map.owner,
-- order 30). It restores its private anchor and scale after native writes, so it stays ahead
-- of Leatrix Maps and diagnostics identify the active geometry owner when both are loaded.
-- It positions the map itself (positionsMap) and keeps Offhand's Escape protection for it
-- (escapeProtection). Its Gamepad fallback leaves Blizzard's map unmodified, so under the
-- Gamepad UI a map whose Maximize is still Blizzard's is Offhand's (gamepadNative). While
-- OpenMapAPI exists OpenMap drives the map camera itself (map.cameraOwner): Offhand runs the
-- OpenMap follow and does not refocus the map on a zone change.
-- Diagnostics: "OpenMap=loaded" or "OpenMap=absent" in the compact line (compact, order 20)
-- and its version, read from the OpenMap table first, among the map integrations
-- (map.integration, order 10).
-- Registered on every client, like the catalog entry and checks it replaces.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local LOADED = { loaded = "OpenMap" }

API.RegisterAddonData("OpenMap", {
    ownership = {
        { role = "map.owner", name = "OpenMap", order = 30, detect = LOADED,
            positionsMap = true, escapeProtection = true, gamepadNative = true },
        { role = "map.cameraOwner", name = "OpenMap", order = 10, detect = { global = "OpenMapAPI" } },
        { role = "map.integration", name = "OpenMap", order = 10, versionNamespace = "OpenMap" },
    },
    diagnostics = {
        { slot = "compact", order = 20, label = "OpenMap", detect = LOADED, absent = "absent" },
    },
    catalogs = {
        OpenMap = {
            worldMap = {position = "addon", close = "map-adapter"},
        },
    },
})
