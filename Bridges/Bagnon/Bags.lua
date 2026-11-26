-- Bagnon bag provider (built into Offhand). Its inventory toggle binding BAGNON_TOGGLE is kept
-- open while the inventory window from Bagnon's frame manager is on the workspace. The rest of
-- its bag persistence stays in the core for now.
-- Registered on every client before Bagnon exists; the addon's global is read when asked.
-- See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

API.RegisterBridge("Bagnon", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        toggleActions = { "BAGNON_TOGGLE" },
        GetToggleFrame = function(action)
            if action ~= "BAGNON_TOGGLE" then return nil end
            return Bagnon and Bagnon.Frames and Bagnon.Frames:Get("inventory")
        end,
    },
})
