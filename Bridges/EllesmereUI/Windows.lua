--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/EllesmereUI/Windows.lua: built-in bridge for EllesmereUI's
    presentation windows, Unlock Mode toolbar, chat bubble ownership and
    onboarding advice

    This is the former EllesmereUI window fitting of Core/PopupBounds.lua, the
    chat bubble ownership probe of Core/ChatBubbles.lua and the profile backup
    advice of UI/Onboarding.lua, moved behind the bridge contract; their
    behaviour is unchanged. Offhand's options metrics, client and locale text
    are read through Offhand.API only.

    Core calls InitializePopupWindows() once where PopupBounds created the 0.2 s
    ticker; like the core module the ticker starts only on Forever and only when
    EllesmereUI exists at that moment. OwnsFeature("chatBubbles") answers the
    chat bubble replacement decision, and GetSetupNotes("before-span") the
    onboarding span step. Registered on every client, like the checks it
    replaces.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.IsForeverClient) ~= "function" or type(API.GetOptionsMetrics) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

local Windows = {}

local function Positionable(frame)
    if not frame or not frame.GetLeft or not frame.GetRight
        or not frame.GetTop or not frame.GetBottom or not frame.GetEffectiveScale
        or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return true
end

local function Accessible(frame)
    if not Positionable(frame) then return false end
    if frame.IsShown and not frame:IsShown() then return false end
    return true
end

local function PublicNumber(value)
    -- Retail may expose secret coordinates even outside combat (for example
    -- encounter-warning previews in Edit Mode). Never compare or calculate
    -- with these values; leave their tooltip placement to Blizzard.
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

local function FrameBounds(frame)
    if not Accessible(frame) then return nil end
    local uiScale = 1
    if UIParent and UIParent.GetEffectiveScale then uiScale = UIParent:GetEffectiveScale() end
    local frameScale = frame:GetEffectiveScale()
    if not PublicNumber(uiScale) or not PublicNumber(frameScale)
        or uiScale <= 0 or frameScale <= 0 then return nil end
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not PublicNumber(left) or not PublicNumber(right)
        or not PublicNumber(top) or not PublicNumber(bottom) then return nil end
    local toUI = frameScale / uiScale
    return left * toUI, right * toUI, top * toUI, bottom * toUI, uiScale, frameScale
end

-- These are EllesmereUI presentation roots. Its HUD, movers, dimmers and
-- input handlers keep their own layout. The full UIParent can include space
-- with no physical display, so fit these windows once per presentation.
local ellesmereWindows = {
    "EllesmereUIFrame", "EUIFirstInstallPopup", "EUIStyleChoicePopup",
    "EUIConfirmPopup", "EUIInfoPopup", "EUIInputPopup",
}
local ellesmerePlacement = setmetatable({}, { __mode = "k" })
local unlockToolbar
local unlockPlacement

local function Fits(left, right, top, bottom, minLeft, maxRight, maxTop, minBottom)
    return left >= minLeft and right <= maxRight and top <= maxTop and bottom >= minBottom
end

local function SetWindowPoint(frame, point)
    frame:ClearAllPoints()
    frame:SetPoint(unpack(point, 1, 5))
end

local function OwnsEllesmerePlacement(frame, placement)
    if not placement.original or frame:GetNumPoints() ~= 1
        or frame:GetScale() ~= placement.scale then return false end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    local applied = placement.applied
    return point == applied[1] and relative == applied[2] and relativePoint == applied[3]
        and PublicNumber(x) and PublicNumber(y)
        and math.abs(x - applied[4]) < 0.01 and math.abs(y - applied[5]) < 0.01
end

local function RestoreEllesmereWindow(frame, placement)
    if OwnsEllesmerePlacement(frame, placement) then
        if placement.scale ~= placement.originalScale then frame:SetScale(placement.originalScale) end
        SetWindowPoint(frame, placement.original)
    end
end

local function GetUnlockToolbar(overlay)
    if unlockToolbar and unlockToolbar:GetParent() == overlay then return unlockToolbar end
    local getAnchor = _G.EllesmereUI.GetUnlockModeTopBarAnchor
    if type(getAnchor) ~= "function" then return end
    local hoverZone = getAnchor(_G.EllesmereUI)
    if not hoverZone or hoverZone:GetParent() ~= overlay then return end
    for _, child in ipairs({overlay:GetChildren()}) do
        if child._hoverZone == hoverZone then
            unlockToolbar = child
            return child
        end
    end
end

local function RefreshEllesmereUnlockToolbar(metrics)
    local overlay = _G.EllesmereUnlockMode
    if not overlay then return end
    local frame = overlay:IsVisible() and GetUnlockToolbar(overlay) or unlockToolbar
    if not frame or frame:IsForbidden() or frame:IsProtected() then return end
    if not metrics or not frame:IsVisible() then
        if unlockPlacement then RestoreEllesmereWindow(frame, unlockPlacement) end
        unlockPlacement = nil
        return
    end
    -- Window/UI scale and topology can settle after the first span callback.
    -- Ownership alone does not mean that the old physical target still fits.
    local geometry = { UIParent:GetWidth(), UIParent:GetHeight(), UIParent:GetEffectiveScale(),
        metrics.gameLeft, metrics.gameRight, metrics.gameBottom, metrics.gameTop,
        metrics.workspaceLeft, metrics.workspaceRight, metrics.workspaceBottom, metrics.workspaceTop,
        frame:GetWidth(), frame:GetHeight() }
    for index = 1, 13 do if not PublicNumber(geometry[index]) then return end end
    if unlockPlacement and OwnsEllesmerePlacement(frame, unlockPlacement) then
        local same = unlockPlacement.geometry ~= nil
        for index = 1, 13 do
            if not same or math.abs(geometry[index] - unlockPlacement.geometry[index]) > 0.01 then
                same = false
                break
            end
        end
        if same then return end
        -- Refit from the vendor's original size, never from our shrunken size.
        RestoreEllesmereWindow(frame, unlockPlacement)
    end
    unlockPlacement = nil

    -- Wait for EllesmereUI to finish sliding the banner in or resizing it.
    -- Its hover handler uses the real UIParent top, so keep the banner flush
    -- with that edge and choose a physical display that reaches it.
    if frame:GetNumPoints() ~= 1 then return end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if point ~= "TOP" or relative ~= UIParent or relativePoint ~= "TOP"
        or not PublicNumber(x) or not PublicNumber(y) or x ~= 0 or y ~= 0 then return end
    local left, right, top, bottom, uiScale, frameScale = FrameBounds(frame)
    if not left or right <= left or top <= bottom then return end
    if Fits(left, right, top, bottom, metrics.gameLeft, metrics.gameRight, metrics.gameTop, metrics.gameBottom)
        or Fits(left, right, top, bottom, metrics.workspaceLeft, metrics.workspaceRight,
            metrics.workspaceTop, metrics.workspaceBottom) then return end

    local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local minLeft, maxRight, minBottom
    if math.abs(metrics.gameTop - screenHeight) < 1 then
        minLeft, maxRight, minBottom = metrics.gameLeft, metrics.gameRight, metrics.gameBottom
    elseif math.abs(metrics.workspaceTop - screenHeight) < 1 then
        minLeft, maxRight, minBottom = metrics.workspaceLeft, metrics.workspaceRight, metrics.workspaceBottom
    else
        return
    end
    local scale = frame:GetScale()
    local ratio = math.min(1, (maxRight - minLeft - 8) / (right - left),
        (screenHeight - minBottom) / (top - bottom))
    if ratio <= 0 or not PublicNumber(scale) or scale <= 0 then return end
    local offset = ((minLeft + maxRight - screenWidth) / 2) * uiScale / (frameScale * ratio)
    local applied = {"TOP", UIParent, "TOP", offset, 0}
    if ratio < 1 then frame:SetScale(scale * ratio) end
    SetWindowPoint(frame, applied)
    unlockPlacement = {
        original = {point, relative, relativePoint, x, y},
        originalScale = scale, scale = frame:GetScale(), applied = applied, geometry = geometry,
    }
end

-- Options metrics are the viewport metrics while Offhand is enabled and spanned.
local function GetEllesmereMetrics()
    return API.GetOptionsMetrics() or false
end

local function FitEllesmereWindow(frame, metrics)
    local left, right, top, bottom, uiScale, frameScale = FrameBounds(frame)
    if not left or right <= left or top <= bottom then return end
    if Fits(left, right, top, bottom, metrics.gameLeft, metrics.gameRight, metrics.gameTop, metrics.gameBottom)
        or Fits(left, right, top, bottom, metrics.workspaceLeft, metrics.workspaceRight,
            metrics.workspaceTop, metrics.workspaceBottom) then return {} end
    if frame:GetNumPoints() ~= 1 then return {} end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    if not point or (relative and relative ~= UIParent)
        or (not relative and frame:GetParent() ~= UIParent)
        or not PublicNumber(x) or not PublicNumber(y) then return {} end

    local scale = frame:GetScale()
    local minLeft, maxRight = metrics.gameLeft + 4, metrics.gameRight - 4
    local minBottom, maxTop = metrics.gameBottom + 4, metrics.gameTop - 4
    if not PublicNumber(scale) or scale <= 0 or maxRight <= minLeft or maxTop <= minBottom then return {} end
    local width, height = right - left, top - bottom
    local ratio = math.min(1, (maxRight - minLeft) / width, (maxTop - minBottom) / height)
    local fromUI = uiScale / (frameScale * ratio)
    local newLeft = math.max(minLeft, math.min(left, maxRight - width * ratio))
    local newTop = math.min(maxTop, math.max(top, minBottom + height * ratio))
    local applied = {"TOPLEFT", UIParent, "BOTTOMLEFT", newLeft * fromUI, newTop * fromUI}
    if ratio < 1 then frame:SetScale(scale * ratio) end
    SetWindowPoint(frame, applied)
    return {
        original = {point, relative or UIParent, relativePoint or point, x, y},
        originalScale = scale, scale = frame:GetScale(), applied = applied,
    }
end

function Windows:Refresh()
    if not API.IsForeverClient() or not _G.EllesmereUI
        or (InCombatLockdown and InCombatLockdown()) then return end
    local metrics
    local overlay = _G.EllesmereUnlockMode
    if unlockPlacement or (overlay and overlay:IsVisible()) then
        metrics = GetEllesmereMetrics()
        RefreshEllesmereUnlockToolbar(metrics)
    end
    for _, name in ipairs(ellesmereWindows) do
        local frame = _G[name]
        if frame and frame.IsProtected and not frame:IsProtected()
            and frame.IsForbidden and not frame:IsForbidden() then
            local placement = ellesmerePlacement[frame]
            local visible = frame:IsVisible()
            if visible or placement then
                if metrics == nil then metrics = GetEllesmereMetrics() end
                if metrics and visible then
                    if not placement then ellesmerePlacement[frame] = FitEllesmereWindow(frame, metrics) end
                elseif placement then
                    RestoreEllesmereWindow(frame, placement)
                    ellesmerePlacement[frame] = nil
                end
            end
        end
    end
end

local function EllesmereOwnsChatBubbles()
    -- Compatibility-only, read-only ownership probe. Offhand does not call the
    -- other addon's layout, refresh or mutation paths. A missing or changed
    -- interface fails open; the native-child alpha gate of Offhand's bubble
    -- pass remains the final authority before Offhand claims a bubble.
    local eui = _G and _G.EllesmereUI
    if not eui or type(eui.GetActiveProfileData) ~= "function" then return false end
    local ok, profile = pcall(eui.GetActiveProfileData)
    local config = ok and type(profile) == "table" and profile.chatBubbles or nil
    return ok and type(config) == "table" and config.enabled == true
end

local ns = API.GetBridgeNamespace("EllesmereUI")
local bridge = ns.bridge or { contract = API.BRIDGE_CONTRACT }
ns.bridge = bridge

function bridge:InitializePopupWindows()
    -- Observe from Offhand's own timer. These windows can raise Forever's
    -- gamepad cursor from their show handlers and may be created lazily.
    if API.IsForeverClient() and _G.EllesmereUI and C_Timer and C_Timer.NewTicker then
        Windows.ticker = C_Timer.NewTicker(0.2, function() Windows:Refresh() end)
    end
end

function bridge:OwnsFeature(feature)
    return feature == "chatBubbles" and EllesmereOwnsChatBubbles()
end

-- Before the span on Forever, advise exporting the EllesmereUI profile while
-- EllesmereUI can export it.
function bridge:GetSetupNotes(context)
    if context == "before-span" and API.IsForeverClient() and EllesmereUI
        and type(EllesmereUI.ExportProfile) == "function" then
        return API.GetText("ELLESMERE_HUD_BACKUP_BEFORE_SPAN")
    end
end

if API.RegisterBridge("EllesmereUI", bridge) then
    ns.Windows = Windows
end
