-- BetterBags bag provider (built into Offhand): the former BetterBags bag Escape adapter of
-- Core/BagPersistence.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 30) it finds the BetterBags addon object once, post-hooks its
-- CloseSpecialWindows (out of combat, the first time the vendor is found) and takes its
-- backpack (BetterBagsNextBackpack or BetterBagsBagBackpack) out of UISpecialFrames while it
-- is open on the workspace, closing the native bags BetterBags parks. When Escape queues
-- BetterBags' own close and the Game Menu toggle or a PlayerSpells center panel follows, the
-- backpack is kept open (PreserveThroughEscape, PreserveThroughPanelShow); an Options
-- transition or leaving the world drops the request (CancelEscape). Its toggle binding
-- BETTERBAGS_TOGGLEBAGS, and the generic inventory toggles, are kept open while the backpack
-- is on the workspace. The vendor object and the pending request live in the BetterBags
-- bridge namespace.
-- Registered on every client before BetterBags exists. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" then return end

-- vendor: the BetterBags addon object once found; escapeRequest: the queued
-- Escape close; escapeFrame: the backpack last given Escape handling.
local Better = API.GetBridgeNamespace("BetterBags")

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function RefreshBetterBagsEscape(services)
    if InCombatLockdown() then return end
    local vendor = Better.vendor
    if not vendor and IsAddOnLoadedCompat("BetterBags") and LibStub and hooksecurefunc and ToggleGameMenu then
        local ace = LibStub("AceAddon-3.0", true)
        vendor = ace and ace:GetAddon("BetterBags", true)
        if not vendor or type(vendor.CloseSpecialWindows) ~= "function"
            or type(vendor.backpackShouldClose) ~= "boolean" then return end
        Better.vendor = vendor
        hooksecurefunc(vendor, "CloseSpecialWindows", function(_, interactingFrame)
            local backpack = vendor.Bags and vendor.Bags.Backpack
            local frame = backpack and backpack.frame
            if interactingFrame or not frame or not services.IsEscapeRegistered(frame)
                or not frame:IsVisible() or vendor.backpackShouldClose ~= true
                or (backpack.IsClosing and backpack:IsClosing()) then return end
            -- BetterBags queues its close for the next frame. Opening or
            -- expanding PlayerSpells also runs CloseSpecialWindows while
            -- Blizzard is assigning the center panel.
            local stack = debugstack and debugstack(2, 24, 0) or ""
            local request = { frame = frame, fromPanelShow =
                stack:find("Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua", 1, true)
                and stack:find("in function 'ShowUIPanel'", 1, true) }
            Better.escapeRequest = request
            C_Timer.After(0, function()
                if Better.escapeRequest == request then Better.escapeRequest = nil end
            end)
        end)
    end
    if not vendor then return end
    local backpack = vendor.Bags and vendor.Bags.Backpack
    local frame = backpack and backpack.frame
    local name = frame and frame:GetName()
    if name ~= "BetterBagsNextBackpack" and name ~= "BetterBagsBagBackpack" then frame = nil end

    local previous = Better.escapeFrame
    if previous and previous ~= frame then
        services.UpdateEscapeRegistration(previous, previous:GetName(), false)
    end
    Better.escapeFrame = frame
    if frame and services.UpdateEscapeRegistration(frame, name, true) then
        services.CloseParkedNativeBags(_G.BetterBagsSneakyFrame, NUM_CONTAINER_FRAMES or 13,
            NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
    end
end

local function PreserveBetterBagsBackpack(services)
    local request = Better.escapeRequest
    Better.escapeRequest = nil
    if not request or services.IsPaused() or InCombatLockdown() or services.InputReserved()
        or not services.TrackEnabled() or not services.CanOpenBagsFromAddon() or not services.IsSpanned() then return end
    local vendor = Better.vendor
    local backpack = vendor.Bags and vendor.Bags.Backpack
    if backpack and backpack.frame == request.frame and request.frame:IsVisible()
        and services.IsFrameOnWorkspace(request.frame) then
        vendor.backpackShouldClose = false
    end
end

API.RegisterBridge("BetterBags", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 30,
        RefreshEscape = RefreshBetterBagsEscape,
        PreserveThroughEscape = PreserveBetterBagsBackpack,
        PreserveThroughPanelShow = function(panel, services)
            local request = Better.escapeRequest
            if request and request.fromPanelShow and services.KeepsIndependentPanels()
                and panel and panel == _G.PlayerSpellsFrame and panel:IsShown() then
                PreserveBetterBagsBackpack(services)
            end
        end,
        CancelEscape = function() Better.escapeRequest = nil end,
        toggleActions = { "BETTERBAGS_TOGGLEBAGS" },
        GetToggleFrame = function(action)
            local better = Better.vendor
            if not better and action == "BETTERBAGS_TOGGLEBAGS" and LibStub then
                local ace = LibStub("AceAddon-3.0", true)
                better = ace and ace:GetAddon("BetterBags", true)
            end
            local backpack = better and better.Bags and better.Bags.Backpack
            return backpack and backpack.frame
        end,
    },
})
