--[[
    Offhand: Multi-Monitor Setup Addon
    Core/HUDTransientPolicy.lua: Mainhand transient-frame registry and eligibility policy
--]]

local _, Offhand = ...

local Policy = {}
Offhand.HUDTransientPolicy = Policy

-- Blizzard owns visibility and interaction for every entry. The registry
-- describes presentation only and grants secure positioning solely to the
-- explicitly reviewed roots.
local specs = {
    { name = "ZoneTextFrame", point = "TOP", x = 0, y = -128 },
    { name = "SubZoneTextFrame", point = "BOTTOM", x = 0, y = 512 },
    { name = "BossBanner", point = "TOP", x = 0, y = -120 },
    { name = "EventToastManagerFrame", point = "TOP", x = 0, y = -190, retailNotification = true },
    { name = "AlertFrame", point = "BOTTOM", x = 0, y = 128 },
    { name = "RolePollPopup", point = "TOP", x = 0, y = -15, retailSpecialPopup = true },
    { name = "ReadyCheckFrame", point = "CENTER", x = 0, y = -10 },
    { name = "LFGDungeonReadyPopup", point = "CENTER", x = 0, y = -10, hookEvent = true, retailSpecialPopup = true },
    -- These use Blizzard's shared special-popup stack, including a restricted
    -- application-note edit box. Observe the external placement transaction;
    -- never install scripts or bookkeeping on their native ancestry.
    { name = "LFGListApplicationDialog", specialPopup = true, retailOnly = true },
    { name = "LFGListInviteDialog", specialPopup = true, retailOnly = true },
    {
        name = "GroupLootContainer", point = "BOTTOM", x = 0, y = 190,
        secure = true, stockPoint = "BOTTOM", stockRelativePoint = "BOTTOM",
        stockX = 0, stockY = 190, allowAnyUIParentAnchor = true,
        allowUnanchored = true, groupLootRows = true,
    },
    { name = "PetBattleFrame", secure = true, petBattleBounds = true },
    { name = "CombatText", point = "CENTER", x = 0, y = 0, normalizeScale = true },
    { name = "TimerTracker", bounds = true, normalizeScale = true, hookEvent = true },
    {
        name = "UIWidgetTopCenterContainerFrame", point = "TOP", x = 0, y = -15,
        secure = true, stockPoint = "TOP", stockRelativePoint = "TOP",
        stockX = 0, stockY = -15,
    },
    {
        name = "PVPMatchScoreboard", point = "CENTER", x = 0, y = 0,
        secure = true, stockPoint = "CENTER", stockRelativePoint = "CENTER",
        stockX = 0, stockY = 0,
    },
    {
        name = "PVPMatchResults", point = "CENTER", x = 0, y = 0,
        secure = true, stockPoint = "CENTER", stockRelativePoint = "CENTER",
        stockX = 0, stockY = 0,
    },
    { name = "HousingControlsFrame", point = "TOP", x = 0, y = -30 },
    {
        name = "HouseEditorFrame.ModeBar", point = "BOTTOM", x = 0, y = 0,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.ModeBar
        end,
    },
    {
        name = "HouseEditorFrame.StorageButton", point = "LEFT", x = 24, y = 150,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.StorageButton
        end,
    },
    {
        name = "HouseEditorFrame.StoragePanel", point = "LEFT", x = 24, y = 150,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel
        end,
    },
    {
        name = "HouseEditorFrame.MarketShoppingCartFrame",
        point = "BOTTOMRIGHT", x = -30, y = 20,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.MarketShoppingCartFrame
        end,
    },
}

function Policy.GetSpecs()
    return specs
end

-- Native StaticPopup_SetUpPosition owns this entire shared stack. Ordinary and
-- special dialogs must use the same root translation on Retail.
function Policy.GetRetailSpecialPopupNames()
    return { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4",
        "LFGListApplicationDialog", "LFGListInviteDialog", "LFGInvitePopup", "LFDRoleCheckPopup",
        "LFGReadyCheckPopup", "PVPReadyPopup", "PetBattleQueueReadyFrame",
        "RolePollPopup", "LFGDungeonReadyPopup" }
end

function Policy.GetRetailNotificationSpecs()
    return {
        { name = "ChallengesKeystoneFrame", point = "CENTER", relativePoint = "CENTER", x = 0, y = 40,
            method = "ShowKeystoneFrame" },
        { name = "ChallengeModeCompleteBanner", point = "TOP", relativePoint = "TOP", x = 0, y = -120,
            method = "PlayBanner" },
        { name = "EventToastManagerFrame", point = "TOP", relativePoint = "TOP", x = 0, y = -190,
            method = "UpdateAnchor", finalMethod = "DisplayToast", nativeOffsets = true },
        { name = "EventToastManagerSideDisplay", point = "TOPRIGHT", relativePoint = "TOP", x = -189, y = -170,
            method = "DisplayToastsByLevel" },
    }
end

function Policy.Resolve(spec)
    if type(spec) ~= "table" then return nil end
    if spec.resolve then return spec.resolve() end
    return _G[spec.name]
end

function Policy.IsSecureRoot(frame)
    if not frame then return false end
    for _, spec in ipairs(specs) do
        if spec.secure and Policy.Resolve(spec) == frame then return true end
    end
    return false
end

function Policy.CanPosition(frame, spec)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    if frame.IsProtected and frame:IsProtected() and not (spec and spec.secure) then
        return false
    end
    return true
end

function Policy.NormalizeScale(frame)
    if not frame or not frame.SetIgnoreParentScale or not frame.IsIgnoringParentScale then
        return false
    end
    local ok, ignoresParent = pcall(frame.IsIgnoringParentScale, frame)
    if not ok or not ignoresParent then return false end
    frame:SetIgnoreParentScale(false)
    return true
end

