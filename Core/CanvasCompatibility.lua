--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasCompatibility.lua: External frame ownership detection for Canvas
--]]

local _, Offhand = ...

local Compatibility = {}
Offhand.CanvasCompatibility = Compatibility

function Compatibility.IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

function Compatibility.HasLeatrixMaps()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Maps")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Maps")
    end
    return false
end

-- MoveAny registers and manages WorldMapFrame on every supported modern client.
-- Canvas must leave scale, anchor, persistence, drag, and post-toggle behavior
-- to a single owner while retaining dormant Offhand coordinates.
function Compatibility.HasMoveAny()
    return _G.MoveAny ~= nil or _G.MoveAnything ~= nil
        or Compatibility.IsAddonLoaded("MoveAny")
        or Compatibility.IsAddonLoaded("MoveAnything")
end

function Compatibility.HasClassicUIForever()
    return Compatibility.IsAddonLoaded("ClassicUIForever")
end

-- ClassicUI Forever has its own persistent movement for these native frames.
-- The addon name is independent of Offhand.isForever, which identifies a
-- client family rather than a frame owner.
function Compatibility.ShouldYieldFrameToClassicUIForever(frameOrName, suppliedName)
    if not Compatibility.HasClassicUIForever() then return false end
    local name = suppliedName
        or (type(frameOrName) == "string" and frameOrName)
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    return name == "WorldMapFrame" or name == "CharacterFrame"
end

function Compatibility.GetWorldMapExternalOwner()
    if Compatibility.HasMoveAny() then return "MoveAny" end
    if Compatibility.HasClassicUIForever() then return "ClassicUIForever" end
    -- OpenMap restores its private anchor and scale after native writes. Keep
    -- it ahead of Leatrix so diagnostics identify the active geometry owner
    -- when both addons are loaded.
    if Compatibility.IsAddonLoaded("OpenMap") then return "OpenMap" end
    if Compatibility.HasLeatrixMaps() then return "LeatrixMaps" end
    return nil
end

function Compatibility.IsExternallyPositionedWorldMap(frameOrName)
    local owner = Compatibility.GetWorldMapExternalOwner()
    if owner ~= "LeatrixMaps" and owner ~= "OpenMap" then return false end
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName == _G.WorldMapFrame
end

function Compatibility.ShouldYieldWorldMap(frameOrName)
    if not Compatibility.GetWorldMapExternalOwner() then return false end
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName == _G.WorldMapFrame
end

function Compatibility.GetDiagnostics(compact, coordinateFontRefreshCount)
    local mapOwner = Compatibility.GetWorldMapExternalOwner() or "Offhand"
    if compact then
        return string.format("WorldMapOwner=%s | LeatrixMaps=%s | OpenMap=%s",
            mapOwner, Compatibility.HasLeatrixMaps() and "loaded" or "absent",
            Compatibility.IsAddonLoaded("OpenMap") and "loaded" or "absent")
    end
    local leatrixStatus = Compatibility.HasLeatrixMaps() and string.format(
        " | LeatrixMaps=loaded | CoordinateFontRefresh=%s",
        tostring(coordinateFontRefreshCount or "pending")) or ""
    if Compatibility.HasClassicUIForever() then
        return string.format(
            "MoveAny=%s | ClassicUIForever=loaded | WorldMapOwner=%s | CharacterFrameOwner=ClassicUIForever",
            Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner) .. leatrixStatus
    end
    return string.format("MoveAny=%s | WorldMapOwner=%s",
        Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner) .. leatrixStatus
end
