-- ElvUI bag provider (built into Offhand): the former ElvUI bag Escape adapter of
-- Core/BagPersistence.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 50) it finds ElvUI's Bags module once (out of combat), replaces its
-- CloseAllBags so a Game Menu or Settings close on the Escape path is skipped while the
-- backpack ElvUI_ContainerFrame is open on the workspace, post-hooks its ToggleAllBags so a
-- press that only looked like an open still closes, takes the backpack out of
-- UISpecialFrames there and closes the native containers ElvUI disabled but left open. The
-- generic inventory toggles are kept open while ElvUI_ContainerFrame is on the workspace.
-- Registered on every client before ElvUI exists. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

-- vendor: ElvUI's Bags module once found; backpackCleared: Offhand cleared the
-- native backpack bit while ElvUI's backpack stayed open.
local Elv = {}

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function IsOpenElvUIDisabledContainer(frame)
    -- ElvUI's disabled containers retain their native open flag. Offhand can
    -- attach an OnShow observer, so check the anchors and OnHide script.
    return frame and not (frame.IsForbidden and frame:IsForbidden()) and frame:IsShown()
        and frame:GetNumPoints() == 0 and not frame:GetScript("OnHide")
end

local function ClearElvUINativeBags(frame)
    local combined = _G.ContainerFrameCombinedBags
    if CloseBackpack and IsOpenElvUIDisabledContainer(combined) then
        CloseBackpack()
        if frame:IsShown() and not combined:IsShown() then Elv.backpackCleared = true end
    end
    if not CloseBag then return end
    local lastBagID = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for index = 1, NUM_CONTAINER_FRAMES or 13 do
        local container = _G["ContainerFrame" .. index]
        if IsOpenElvUIDisabledContainer(container) and container.GetBagID then
            local id = container:GetBagID()
            if type(id) == "number" and id >= 0 and id <= lastBagID then
                CloseBag(id)
                if id == 0 and frame:IsShown() and not container:IsShown() then Elv.backpackCleared = true end
            end
        end
    end
end

local function RefreshElvUIEscape(services)
    local frame = _G.ElvUI_ContainerFrame
    if not frame or InCombatLockdown() or not IsAddOnLoadedCompat("ElvUI")
        or type(debugstack) ~= "function" or not hooksecurefunc then return end
    local engine = _G.ElvUI and _G.ElvUI[1]
    local parent = engine and engine.UIParent
    if not parent or _G.ElvUIParent ~= parent or frame:GetParent() ~= parent then return end
    local vendor = Elv.vendor
    if not vendor then
        vendor = engine.GetModule and engine:GetModule("Bags", true)
        if not vendor or vendor.BagFrame ~= frame or type(vendor.CloseAllBags) ~= "function"
            or type(vendor.ToggleAllBags) ~= "function" then return end
        Elv.vendor = vendor
        local vendorClose = vendor.CloseAllBags
        vendor.CloseAllBags = function(self, ...)
            if self == vendor and services.CanSuppressVendorClose(frame) then
                local stack = debugstack(2, 24, 0)
                if services.IsGameMenuBagClose(stack) or services.IsSettingsBagClose(stack) then return end
            end
            Elv.backpackCleared = nil
            return vendorClose(self, ...)
        end
        hooksecurefunc(vendor, "ToggleAllBags", function(self)
            -- ElvUI's toggle uses Blizzard's backpack bit. If clearing it
            -- made this press look like an open, honor the existing window.
            if self == vendor and Elv.backpackCleared and frame:IsShown() and not InCombatLockdown() then
                vendor:CloseAllBags()
            end
        end)
    end
    if not frame:IsShown() then Elv.backpackCleared = nil end
    if services.UpdateEscapeRegistration(frame, "ElvUI_ContainerFrame", vendor.BagFrame == frame, parent) then
        ClearElvUINativeBags(frame)
    end
end

API.RegisterBridge("ElvUI", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 50,
        RefreshEscape = RefreshElvUIEscape,
        GetToggleFrame = function() return _G.ElvUI_ContainerFrame end,
    },
})
