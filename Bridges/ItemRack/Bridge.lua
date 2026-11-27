--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/ItemRack/Bridge.lua: built-in bridge for ItemRack's Options window
    and its slot flyout

    This is the former ItemRack part of the addon options window fitting in
    Core/PopupBounds.lua, moved behind the bridge contract; its behaviour is
    unchanged. The generic fitting helpers stay in core and are read through
    Offhand.API.GetOptionsWindowHelpers(); the options metrics through
    Offhand.API.GetOptionsMetrics().

    Registered on the Forever client only (the core code ran there only), before
    ItemRack exists: InitializePopupWindows() installs the hooks when the popup
    bounds handling initializes and again on ItemRackOptions' ADDON_LOADED, and
    RefreshAddonOptions(getMetrics) runs with every popup layout pass and after
    combat.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.IsForeverClient) ~= "function" or type(API.GetOptionsMetrics) ~= "function"
    or type(API.GetOptionsWindowHelpers) ~= "function" then return end
if not API.IsForeverClient() then return end
local helpers = API.GetOptionsWindowHelpers()
if type(helpers) ~= "table" then return end

local CanLayoutAddonOptions, ReadWindowPoint = helpers.CanLayoutAddonOptions, helpers.ReadWindowPoint
local SetWindowPoint, OwnsOptionsPoint = helpers.SetWindowPoint, helpers.OwnsOptionsPoint
local FitAddonOptions, GetOptionsBounds = helpers.FitAddonOptions, helpers.GetOptionsBounds
local FrameBounds, Fits, PublicNumber = helpers.FrameBounds, helpers.Fits, helpers.PublicNumber
local GetOptionsMetrics = API.GetOptionsMetrics

local addonOptions = setmetatable({}, { __mode = "k" })

local function MirrorDock(point, from, to)
    local mirrored = point:gsub(from, to)
    if mirrored ~= point then return mirrored end
    return (point:gsub(to, from))
end

local itemRackFlyoutScale

local function RestoreItemRackFlyoutScale(menu)
    local state = itemRackFlyoutScale
    if not state or not CanLayoutAddonOptions(menu) then return end
    itemRackFlyoutScale = nil
    if state.menu == menu and menu:GetScale() == state.applied then menu:SetScale(state.original) end
end

local function FitItemRackFlyout(rack)
    local menu, options = _G.ItemRackMenuFrame, _G.ItemRackOptFrame
    if not options or not CanLayoutAddonOptions(menu) or not menu:IsVisible() then return end
    local owner = menu:GetParent()
    local point = ReadWindowPoint(menu)
    if not owner or owner:GetParent() ~= options or not point or point[2] ~= owner then return end
    local name = owner:GetName()
    if not name or not name:match("^ItemRackOptInv%d+$") then return end
    local metrics = GetOptionsMetrics()
    if not metrics then return end
    local minLeft, maxRight, maxTop, minBottom = GetOptionsBounds(owner, metrics)
    if not minLeft then return end
    local menuDock, mainDock = rack.menuDock, rack.mainDock
    local nativeDock = rack.DockInfo and rack.DockInfo[rack.currentDock]
    if not nativeDock or not menuDock or not mainDock then return end
    local originalMenuDock = menuDock
    RestoreItemRackFlyoutScale(menu)
    if point[1] ~= menuDock or point[3] ~= mainDock
        or math.abs(point[4] - nativeDock.xoff) > 0.01 or math.abs(point[5] - nativeDock.yoff) > 0.01 then
        -- ItemRack can rebuild an open menu without docking it again.
        SetWindowPoint(menu, {menuDock, owner, mainDock, nativeDock.xoff, nativeDock.yoff})
    end

    local left, right, top, bottom, uiScale, menuScale = FrameBounds(menu)
    if not left or Fits(left, right, top, bottom, minLeft, maxRight, maxTop, minBottom) then return end
    local ownerLeft, ownerRight, ownerTop, ownerBottom = FrameBounds(owner)
    if not ownerLeft then return end
    local width, height = right - left, top - bottom
    if width <= 0 or height <= 0 then return end
    local fit = math.min((maxRight - minLeft - 8) / width, (maxTop - minBottom - 8) / height)
    if fit > 0 and fit < 1 then
        -- ItemRack wraps against the whole canvas. If its wrapped menu is
        -- still larger than this display, fit the completed menu as a unit.
        local original = menu:GetScale()
        menu:SetScale(original * fit)
        itemRackFlyoutScale = {menu = menu, original = original, applied = menu:GetScale()}
        SetWindowPoint(menu, {menuDock, owner, mainDock, nativeDock.xoff, nativeDock.yoff})
        left, right, top, bottom, uiScale, menuScale = FrameBounds(menu)
        if not left then return end
        width, height = right - left, top - bottom
    end
    -- A whole-window clamp can hide the outward overflow at coordinate zero.
    -- Favor the side with more room even if both sides need a final offset.
    local mirrorX = (left < minLeft and maxRight - ownerRight > ownerLeft - minLeft)
        or (right > maxRight and ownerLeft - minLeft > maxRight - ownerRight)
    local mirrorY = (bottom < minBottom and maxTop - ownerTop > ownerBottom - minBottom)
        or (top > maxTop and ownerBottom - minBottom > maxTop - ownerTop)
    if mirrorX then
        menuDock = MirrorDock(menuDock, "LEFT", "RIGHT")
        mainDock = MirrorDock(mainDock, "LEFT", "RIGHT")
    end
    if mirrorY then
        menuDock = MirrorDock(menuDock, "TOP", "BOTTOM")
        mainDock = MirrorDock(mainDock, "TOP", "BOTTOM")
    end
    local dock = rack.DockInfo[mainDock .. menuDock]
    if not dock then return end

    if dock ~= nativeDock then
        -- Mirror the completed vendor layout around the slot. Keep its rows,
        -- item buttons and click handlers, including ItemRack's wrap choice.
        SetWindowPoint(menu, {menuDock, owner, mainDock, dock.xoff, dock.yoff})
        for index = 1, #rack.Menu do
            local button = _G["ItemRackMenu" .. index]
            if CanLayoutAddonOptions(button) then
                local anchor = ReadWindowPoint(button)
                if anchor and anchor[2] == menu and anchor[3] == originalMenuDock then
                    local x = dock.xstart + (anchor[4] - nativeDock.xstart) * dock.xdir / nativeDock.xdir
                    local y = dock.ystart + (anchor[5] - nativeDock.ystart) * dock.ydir / nativeDock.ydir
                    SetWindowPoint(button, {anchor[1], menu, menuDock, x, y})
                end
            end
        end
    end
    left, right, top, bottom = FrameBounds(menu)
    if not left then return end
    if not Fits(left, right, top, bottom, minLeft, maxRight, maxTop, minBottom) then
        local inset = 2
        local targetLeft = math.max(minLeft + inset, math.min(left, maxRight - inset - (right - left)))
        local targetTop = math.min(maxTop - inset, math.max(top, minBottom + inset + (top - bottom)))
        local fromUI = uiScale / menuScale
        local rx = mainDock:find("LEFT", 1, true) and ownerLeft or ownerRight
        local ry = mainDock:find("TOP", 1, true) and ownerTop or ownerBottom
        local x = menuDock:find("LEFT", 1, true) and targetLeft or targetLeft + (right - left)
        local y = menuDock:find("TOP", 1, true) and targetTop or targetTop - (top - bottom)
        SetWindowPoint(menu, {menuDock, owner, mainDock, (x - rx) * fromUI, (y - ry) * fromUI})
    end
end

local function RefreshItemRackOptions(frame, metrics, requestedScale)
    if not CanLayoutAddonOptions(frame) then return end
    local state = addonOptions[frame]
    if not state then
        if not metrics or not frame:IsShown() or frame:GetParent() then return end
        state = {}
        addonOptions[frame] = state
    end

    local current = frame:GetScale()
    if PublicNumber(current) and state.scale ~= current then state.nativeScale = current end
    if PublicNumber(requestedScale) and requestedScale > 0 then state.nativeScale = requestedScale end
    local native = state.nativeScale
    if not metrics or frame:GetParent() then
        if state.scale == current and current ~= native then frame:SetScale(native) end
        if OwnsOptionsPoint(frame, state) then SetWindowPoint(frame, state.original) end
        addonOptions[frame] = nil
        return
    end
    if not frame:IsShown() or not PublicNumber(current) or not PublicNumber(native) or native <= 0 then return end

    -- ItemRack's parentless root is rendered relative to the canvas height.
    -- Preserve the vendor preset while sizing it against the game display.
    local width, height, rootScale = frame:GetWidth(), frame:GetHeight(), UIParent:GetEffectiveScale()
    if not PublicNumber(width) or not PublicNumber(height) or not PublicNumber(rootScale)
        or width <= 0 or height <= 0 or rootScale <= 0 or metrics.physicalHeight <= 0 then return end
    local scale = native * metrics.gamePixelHeight / metrics.physicalHeight
    if scale <= 0 then return end
    local toUI = scale / rootScale
    scale = scale * math.min(1,
        (metrics.gameRight - metrics.gameLeft - 8) / (width * toUI),
        (metrics.gameTop - metrics.gameBottom - 8) / (height * toUI))
    if scale <= 0 then return end
    if math.abs(current - scale) > 0.0001 then frame:SetScale(scale) end
    state.scale = frame:GetScale()
    FitAddonOptions(frame, state, metrics)
end

local bridge = { contract = API.BRIDGE_CONTRACT }

-- getMetrics() returns the options metrics of this layout pass (nil while
-- Offhand is off or not spanned). The flyout state can exist only once the
-- Options window does, so without that window there is nothing to restore.
function bridge:RefreshAddonOptions(getMetrics)
    local itemRack = _G.ItemRackOptFrame
    if not itemRack then return end
    local metrics = getMetrics()
    RefreshItemRackOptions(itemRack, metrics)
    local menu = _G.ItemRackMenuFrame
    if not metrics or (menu and not menu:IsVisible()) then
        RestoreItemRackFlyoutScale(menu)
    end
end

function bridge:InitializePopupWindows()
    if not hooksecurefunc or not CreateFrame then return end
    local itemRackHooked, flyoutHooked
    local function installHooks()
        local options = _G.ItemRackOpt
        if not itemRackHooked and options and type(options.ReflectOptScale) == "function" then
            itemRackHooked = true
            hooksecurefunc(options, "ReflectOptScale", function(scale)
                if scale == nil and _G.ItemRackUser then scale = _G.ItemRackUser.OptScale end
                RefreshItemRackOptions(_G.ItemRackOptFrame, GetOptionsMetrics(), scale)
            end)
        end
        local rack = _G.ItemRack
        if not flyoutHooked and itemRackHooked and rack and type(rack.BuildMenu) == "function" then
            flyoutHooked = true
            hooksecurefunc(rack, "BuildMenu", function() FitItemRackFlyout(rack) end)
            if type(rack.ReflectMenuScale) == "function" then
                hooksecurefunc(rack, "ReflectMenuScale", function() itemRackFlyoutScale = nil end)
            end
            if type(rack.MenuOnHide) == "function" then
                hooksecurefunc(rack, "MenuOnHide", function() RestoreItemRackFlyoutScale(_G.ItemRackMenuFrame) end)
            end
        end
    end
    local observer = CreateFrame("Frame")
    observer:RegisterEvent("ADDON_LOADED")
    observer:SetScript("OnEvent", function(_, _, name)
        if name == "ItemRackOptions" then installHooks() end
    end)
    installHooks()
end

API.RegisterBridge("ItemRack", bridge)
