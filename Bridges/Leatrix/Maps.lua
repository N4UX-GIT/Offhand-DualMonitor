--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Leatrix/Maps.lua: Leatrix Maps world map facts and provider for the
    Leatrix bridge

    Facts merged under the Leatrix bridge id: no frame, hook or timer. While
    Leatrix_Maps is loaded it is the last World Map owner (map.owner, order 40,
    owner name LeatrixMaps, shown as "Leatrix Maps"): it positions the map
    itself and keeps Offhand's Escape protection for it. It owns the map's
    configuration (map.configurationOwner): Leatrix retains complete ownership
    of map scale, anchors, settings, scripts and saved variables, so Offhand's
    map configuration and cursor conversion stand aside. It is the last map
    movement fade addon (map.fade, order 40). Diagnostics: "LeatrixMaps=loaded"
    or "LeatrixMaps=absent" in the compact line (compact, order 10), and while
    loaded "LeatrixMaps=loaded | CoordinateFontRefresh=<count or pending>"
    after the map owner (compat.map, orders 20 and 30); its version among the
    map integrations (map.integration, order 40).

    The map provider (owner LeatrixMaps) is the coordinate label refresh of
    Core/CanvasMapPresentation.lua, moved behind the bridge contract with
    unchanged behaviour: Leatrix Maps configures Blizzard's player, cursor and
    crosshair coordinate labels before a live Companion span changes UIParent's
    effective scale. On affected clients those font strings can retain their
    pre-span raster size even though the World Map itself has the correct
    geometry; /reload fixes it only because the labels are then configured
    after the final scale is known. The refresh re-applies the known Blizzard
    coordinate labels' fonts, with a narrow text and anchor fallback for older
    Leatrix releases that created their own coordinate frames. Their font tuple
    and font object are preserved. Off the Forever client the Options map
    description names Leatrix Maps (COMPAT_LEATRIX) while it is loaded.

    Registered on every client, like the code it replaces; the addon is read
    when asked. Loaded before Settings.lua, which registers the bridge object
    with this provider and contribution.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

local LOADED = { loaded = "Leatrix_Maps" }

API.RegisterAddonData("Leatrix", {
    ownership = {
        { role = "map.owner", name = "LeatrixMaps", order = 40, detect = LOADED, label = "Leatrix Maps",
            positionsMap = true, escapeProtection = true },
        { role = "map.configurationOwner", name = "LeatrixMaps", order = 10, detect = LOADED },
        { role = "map.fade", name = "Leatrix_Maps", order = 40, detect = LOADED },
        { role = "map.integration", name = "Leatrix_Maps", order = 40 },
    },
    diagnostics = {
        { slot = "compact", order = 10, label = "LeatrixMaps", detect = LOADED, absent = "absent" },
        { slot = "compat.map", order = 20, label = "LeatrixMaps", detect = LOADED },
        { slot = "compat.map", order = 30, label = "CoordinateFontRefresh", detect = LOADED,
            value = function(count) return tostring(count or "pending") end },
    },
})

local function IsCoordinateLabelText(text)
    if type(text) ~= "string" or not text:find(":", 1, true) then return false end
    local values = 0
    for _ in text:gmatch("%d+[%.,]?%d*") do
        values = values + 1
        if values >= 2 then return true end
    end
    return false
end

local Provider = { owner = "LeatrixMaps" }

-- Returns the number of labels refreshed.
function Provider:RefreshCoordinateFonts(map)
    local refreshed = 0
    local seen = {}
    local function RefreshLabel(region, requireCoordinateText)
        if not region or seen[region] then return false end
        seen[region] = true
        local okType, objectType = pcall(region.GetObjectType, region)
        local okText, label = pcall(region.GetText, region)
        if not okType or objectType ~= "FontString"
            or (requireCoordinateText and (not okText or not IsCoordinateLabelText(label)))
            or not region.GetFont or not region.SetFont then return false end
        local okFont, file, height, flags = pcall(region.GetFont, region)
        local okObject, fontObject = false, nil
        if region.GetFontObject then
            okObject, fontObject = pcall(region.GetFontObject, region)
        end
        fontObject = okObject and fontObject or nil
        if not okFont or not file or not height then return false end
        local ok = pcall(region.SetFont, region, file, height, flags or "")
        if ok and fontObject and region.SetFontObject then
            pcall(region.SetFontObject, region, fontObject)
        end
        if ok then refreshed = refreshed + 1 end
        return ok
    end

    -- Forever Leatrix Maps 1.60.20 enables Blizzard's coordinate overlay and
    -- reparents these three frames into the map canvas. Refer only to Blizzard's
    -- feature-detected overlay fields; no Leatrix namespace or method is used.
    if type(map.overlayFrames) == "table" then
        for _, overlay in ipairs(map.overlayFrames) do
            for _, key in ipairs({"PlayerCoords", "CursorCoords", "CrosshairCoords"}) do
                local coordinateFrame = type(overlay) == "table" and overlay[key]
                if coordinateFrame then RefreshLabel(coordinateFrame.Label, false) end
            end
        end
    end

    -- Older Leatrix branches used direct, anonymous WorldMapFrame children.
    if refreshed == 0 and map.GetChildren then
        local children = { pcall(map.GetChildren, map) }
        if table.remove(children, 1) then
            for _, child in ipairs(children) do
                local bottomAnchored = false
                local okPoints, points = false, 0
                if child and child.GetNumPoints then
                    okPoints, points = pcall(child.GetNumPoints, child)
                end
                points = okPoints and tonumber(points) or 0
                for index = 1, points do
                    local ok, point = pcall(child.GetPoint, child, index)
                    if ok and type(point) == "string" and point:find("BOTTOM", 1, true) then
                        bottomAnchored = true
                        break
                    end
                end

                if bottomAnchored and child.GetRegions then
                    local regions = { pcall(child.GetRegions, child) }
                    if table.remove(regions, 1) then
                        for _, region in ipairs(regions) do
                            RefreshLabel(region, true)
                        end
                    end
                end
            end
        end
    end
    return refreshed
end

local function GetSettingsContributions(_, slot)
    if slot == "mapDescription" then
        return {
            { id = "leatrix.maps-description", kind = "fallback", addon = "Leatrix_Maps",
                text = API.GetText("COMPAT_LEATRIX") },
        }
    end
end

API.GetBridgeNamespace("Leatrix").Maps = {
    mapProvider = Provider,
    GetSettingsContributions = GetSettingsContributions,
}
