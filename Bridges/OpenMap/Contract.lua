--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/OpenMap/Contract.lua: OpenMap's reviewed contract and saved window schema

    The OpenMap contract checks of Core/CanvasCompatibility.lua, moved behind
    the bridge contract; their behaviour is unchanged. Read-only: nothing here
    calls into OpenMap except its GetModule("worldmap") lookup, and only after
    the contract check passed.

    Registered on every client, like the core code it replaces; OpenMap is read
    when asked, so an OpenMap that loads after Offhand is still recognised.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.GetBridgeNamespace) ~= "function" then return end

local Contract = {}
API.GetBridgeNamespace("OpenMap").Contract = Contract

local function IsFiniteNumber(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function ValidOpenMapWindowSchema(db, requireWindowFields)
    if type(db) ~= "table" then return false end
    if db.windowScale ~= nil or requireWindowFields then
        if not IsFiniteNumber(db.windowScale) or db.windowScale <= 0 then return false end
    end
    local win = db.window
    if win ~= nil and win ~= false then
        if type(win) ~= "table" or type(win[1]) ~= "string" or type(win[2]) ~= "string"
            or not IsFiniteNumber(win[3]) or not IsFiniteNumber(win[4]) then
            return false
        end
    end
    local size = db.windowSize
    if size ~= nil and size ~= false then
        if type(size) ~= "table" or not IsFiniteNumber(size[1]) or not IsFiniteNumber(size[2])
            or size[1] <= 0 or size[2] <= 0 then
            return false
        end
    end
    return true
end

-- Read-only contract check (safe for diagnostics; never calls GetModule).
-- Uses OpenMapAPI.major == 1 (OpenMap's documented semver boundary) and
-- version >= 4 plus runtime OpenMapDB.worldmap schema validation instead of
-- pinning exact patch strings.
function Contract.InspectOpenMapContract()
    local namespace, api = _G.OpenMap, _G.OpenMapAPI
    if type(namespace) ~= "table" or type(namespace.GetModule) ~= "function"
        or type(api) ~= "table" then return "absent" end
    if api.major ~= 1 then return "unsupported-major" end
    if type(api.version) ~= "number" or api.version < 4 then return "unsupported-api" end
    local db = type(_G.OpenMapDB) == "table" and _G.OpenMapDB.worldmap
    if type(db) ~= "table" then return "schema-mismatch" end
    if db.enabled == false then return "disabled" end
    if not ValidOpenMapWindowSchema(db) then return "schema-mismatch" end
    return "ok"
end

function Contract.GetOpenMapWorldMapModule()
    if Contract.InspectOpenMapContract() ~= "ok" then return end
    local namespace = _G.OpenMap
    local ok, module = pcall(namespace.GetModule, namespace, "worldmap")
    local db = ok and type(module) == "table" and module.db
    if type(db) ~= "table" or db.enabled == false or db ~= _G.OpenMapDB.worldmap
        or not ValidOpenMapWindowSchema(db) then return end
    return module, db
end

-- Placement and expanded-map recovery require the stitched map; windowScale
-- itself applies to every windowed OpenMap view (allowUnstitched = true).
function Contract.GetOpenMapWindowModule(allowUnstitched)
    if not API.IsForeverClient() or API.GetExternalMapOwner() ~= "OpenMap" then return end
    local module, db = Contract.GetOpenMapWorldMapModule()
    local api = _G.OpenMapAPI
    if not module or not ValidOpenMapWindowSchema(db, true) then return end
    if not allowUnstitched and (type(api.IsStitched) ~= "function" or not api.IsStitched()) then return end
    if type(module.MoveAnyOn) == "function" and module.MoveAnyOn() then return end
    return module, db
end
