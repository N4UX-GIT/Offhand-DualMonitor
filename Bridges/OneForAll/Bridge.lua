--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/OneForAll/Bridge.lua: OneForAll window mover conflicts and
    diagnostics

    This is the former OneForAll conflict detection and diagnostics of
    Core/CanvasCompatibility.lua, moved behind the bridge contract; the conflict
    ids, kinds, fields and diagnostics text are unchanged. Its mover marks stay
    in Data.lua beside it (moverFields), read by core's generic anchor repair.

    GetOwnershipConflicts(context) reports worldmap-mover (order 20, after the
    map owner's contract notice) and window-mover (order 40, after the multiple
    bag addon conflict); GetMoverDiagnostics(context) gives the
    WorldMapMover=OneForAll(...) and OneForAllMover=active segments. It creates
    nothing and hooks nothing. Registered on every client, like the checks it
    replaces.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.IsForeverClient) ~= "function" then return end

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

local function IsOneForAllMoveWindowsDisabled()
    local db = rawget(_G, "OneForAllDB")
    local qol = type(db) == "table" and rawget(db, "qol")
    return type(qol) == "table" and qol.moveWindows == false
end

local function IsOneForAllMovingFrame(frameName)
    if not IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return false
    end
    local frame = rawget(_G, frameName)
    return type(frame) == "table" and frame.ofaMovable == true
end

local function IsOneForAllMovingWorldMap()
    return IsOneForAllMovingFrame("WorldMapFrame")
end

local oneForAllDiagnosticFrameNames = {
    "WorldMapFrame", "ContainerFrameCombinedBags", "SettingsPanel",
    "CooldownViewerSettings", "AddonList", "MerchantFrame", "CharacterFrame",
    "PlayerSpellsFrame", "GameMenuFrame",
}

local function IsOneForAllMovingAnyWindow()
    if not IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return false
    end
    for _, frameName in ipairs(oneForAllDiagnosticFrameNames) do
        if IsOneForAllMovingFrame(frameName) then return true end
    end
    return false
end

local function GetOneForAllUnmitigatedMoverTargets(mapOwner, bagOwners)
    if not IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return nil
    end
    local targets = {}
    if not mapOwner and IsOneForAllMovingFrame("WorldMapFrame") then
        targets[#targets + 1] = "WorldMapFrame"
    end
    if (#bagOwners == 0) and IsOneForAllMovingFrame("ContainerFrameCombinedBags") then
        targets[#targets + 1] = "ContainerFrameCombinedBags"
    end
    if API.IsForeverClient() then
        if IsOneForAllMovingFrame("SettingsPanel") then
            targets[#targets + 1] = "SettingsPanel"
        end
        if IsOneForAllMovingFrame("CooldownViewerSettings") then
            targets[#targets + 1] = "CooldownViewerSettings"
        end
    end
    return #targets > 0 and targets or nil
end

local bridge = { contract = API.BRIDGE_CONTRACT }

-- context: { mapOwner, mapLabel, positionsMap, bagOwners, SyncsWorldMapMover() }.
function bridge:GetOwnershipConflicts(context)
    local conflicts = {}
    local mapOwner = context.mapOwner
    if context.positionsMap and IsOneForAllMovingWorldMap() then
        local mitigated = context.SyncsWorldMapMover()
        if not mitigated then
            conflicts[#conflicts + 1] = {
                order = 20,
                id = "worldmap-mover:OneForAll+" .. mapOwner,
                kind = "worldmap-mover",
                mover = "OneForAll",
                owner = context.mapLabel,
            }
        end
    end
    local ofaTargets = GetOneForAllUnmitigatedMoverTargets(mapOwner, context.bagOwners)
    if ofaTargets then
        conflicts[#conflicts + 1] = {
            order = 40,
            id = "window-mover:OneForAll",
            kind = "window-mover",
            mover = "OneForAll",
            targets = table.concat(ofaTargets, ","),
        }
    end
    return conflicts
end

-- context: { mapOwner, positionsMap, SyncsWorldMapMover() }.
function bridge:GetMoverDiagnostics(context)
    local moverStatus = {}
    if context.positionsMap and IsOneForAllMovingWorldMap() then
        local mitigated = context.SyncsWorldMapMover()
        moverStatus[#moverStatus + 1] = "WorldMapMover=OneForAll(" .. (mitigated and "synced" or "conflict") .. ")"
    end
    if IsOneForAllMovingAnyWindow() then
        moverStatus[#moverStatus + 1] = "OneForAllMover=active"
    end
    if #moverStatus > 0 then return table.concat(moverStatus, " | ") end
end

API.RegisterBridge("OneForAll", bridge)
