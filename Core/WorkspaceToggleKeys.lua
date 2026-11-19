-- Temporarily mask a keyboard toggle only while its actual window is on Offhand.
-- The first open, explicit close and Mainhand toggle stay with the original owner.
local _, Offhand = ...
local Keys = {}
Offhand.WorkspaceToggleKeys = Keys
local owner, observer, elapsed
local bound, wanted = {}, {}
local assignments, verdicts = {}, {}
local spanned
local locations = setmetatable({}, {__mode = "k"})
local click = "CLICK OffhandWorkspaceToggleKey:LeftButton"
local inventoryActions = {"TOGGLEBACKPACK", "OPENALLBAGS", "BETTERBAGS_TOGGLEBAGS", "BAGNON_TOGGLE", "ARKINV_TOGGLE_BAG"}
local inventoryAction = {}
for _, action in ipairs(inventoryActions) do inventoryAction[action] = true end

local function Visible(frame)
    return frame and frame.IsVisible and (not frame.IsForbidden or not frame:IsForbidden()) and frame:IsVisible()
end

local function OnWorkspace(frame)
    if not Visible(frame) then return false end
    local x, y, w, h = frame:GetRect()
    if not x or not y or not w or not h then return false end
    local scale = frame:GetEffectiveScale()
    local last = locations[frame]
    if last and last.x == x and last.y == y and last.w == w and last.h == h and last.scale == scale then
        return last.workspace
    end
    if spanned == nil then
        local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        spanned = metrics and metrics.isSpanned == true or false
    end
    local workspace = spanned and Offhand.Canvas.IsFrameOnWorkspace(frame)
    locations[frame] = {x=x, y=y, w=w, h=h, scale=scale, workspace=workspace}
    return workspace
end

local function InventoryOnWorkspace(action)
    local bags = Offhand.BagPersistence
    local better = bags and bags.betterBags
    if not better and action == "BETTERBAGS_TOGGLEBAGS" and LibStub then
        local ace = LibStub("AceAddon-3.0", true)
        better = ace and ace:GetAddon("BetterBags", true)
    end
    local backpack = better and better.Bags and better.Bags.Backpack
    if action == "BETTERBAGS_TOGGLEBAGS" then return OnWorkspace(backpack and backpack.frame) end
    if action == "ARKINV_TOGGLE_BAG" then return OnWorkspace(_G.ARKINV_Frame1) end
    if action == "BAGNON_TOGGLE" then
        local frame = Bagnon and Bagnon.Frames and Bagnon.Frames:Get("inventory")
        return OnWorkspace(frame)
    end
    if bags and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        for _, frame in pairs(bags.frames) do
            if OnWorkspace(frame) then return true end
        end
        if OnWorkspace(backpack and backpack.frame) or OnWorkspace(_G.ARKINV_Frame1)
            or OnWorkspace(_G.BagSmithFrame) or OnWorkspace(_G.ElvUI_ContainerFrame)
            or OnWorkspace(_G.DaylightUIBag) or OnWorkspace(_G.EUI_MainBagFrame) then return true end
    end
    if Visible(_G.ContainerFrameCombinedBags) then return OnWorkspace(_G.ContainerFrameCombinedBags) end
    local found = false
    for n = 1, NUM_CONTAINER_FRAMES or 13 do
        local frame = _G["ContainerFrame" .. n]
        if Visible(frame) and frame.GetID then
            local id = frame:GetID()
            if type(id) == "number" and id >= 0 and id <= (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
                and (action == "OPENALLBAGS" or id == 0) then
                -- With bags on both screens, preserve the native all-bags toggle.
                if not OnWorkspace(frame) then return false end
                found = true
            end
        end
    end
    return found
end

function Keys:Available()
    return Offhand.isForever and type(GetBindingKey) == "function" and type(GetBindingAction) == "function"
        and type(SetOverrideBindingClick) == "function" and type(ClearOverrideBindings) == "function"
        and type(RegisterStateDriver) == "function"
end

local function ShouldMask(action)
    if action == "TOGGLEWORLDMAP" then return OnWorkspace(WorldMapFrame) end
    return InventoryOnWorkspace(action)
end

local function ReadKeys(action)
    for _, key in ipairs({GetBindingKey(action)}) do
        if key ~= "ESCAPE" and not key:match("PAD[%w]+$") then
            assignments[key] = action
        end
    end
end

local function UpdateBindings()
    if InCombatLockdown() then return end
    for key in pairs(wanted) do wanted[key] = nil end
    for action in pairs(verdicts) do verdicts[action] = nil end
    spanned = nil
    local db = Offhand.db
    if db and db.enabled and (db.keepMapToggleOpen or db.keepBagToggleOpen) and not _G.ConsolePort
        and not Offhand._displayGeometryTransitionActive and not Offhand._loggingOut
        and Offhand.Canvas and Offhand.Canvas.CanManagePanelsFromAddon()
        and not (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
        and not (EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()) then
        -- Geometry is checked at the ownership boundary for each shown root.
        for key, action in pairs(assignments) do
            local current = GetBindingAction(key, true)
            if current == click then current = bound[key] end
            if current == action or (inventoryAction[action] and inventoryAction[current]) then
                if verdicts[current] == nil then
                    local ok, value = pcall(ShouldMask, current)
                    verdicts[current] = ok and value == true
                end
                if verdicts[current] then wanted[key] = current end
            end
        end
    end
    local changed = false
    for key, action in pairs(bound) do if wanted[key] ~= action then changed = true end end
    for key, action in pairs(wanted) do
        if bound[key] ~= action or GetBindingAction(key, true) ~= click then changed = true end
    end
    if not changed then return end
    if not owner then
        owner = CreateFrame("Button", "OffhandWorkspaceToggleKey", UIParent, "SecureHandlerStateTemplate")
        owner:SetAttribute("_onstate-combat", [[if newstate == "combat" then self:ClearBindings() end]])
        RegisterStateDriver(owner, "combat", "[combat] combat; nocombat")
    end
    ClearOverrideBindings(owner)
    bound, wanted = wanted, bound
    for key in pairs(bound) do SetOverrideBindingClick(owner, true, key, "OffhandWorkspaceToggleKey", "LeftButton") end
end

local function Poll(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 0.05 then elapsed = 0; UpdateBindings() end
end

function Keys:Refresh()
    if not observer then return end
    for frame in pairs(locations) do locations[frame] = nil end
    local db = Offhand.db
    local active = db and db.enabled and (db.keepMapToggleOpen or db.keepBagToggleOpen)
    for key in pairs(assignments) do assignments[key] = nil end
    if active then
        if db.keepMapToggleOpen then ReadKeys("TOGGLEWORLDMAP") end
        if db.keepBagToggleOpen then for _, action in ipairs(inventoryActions) do ReadKeys(action) end end
    end
    observer:SetScript("OnUpdate", active and Poll or nil)
    elapsed = 0
    UpdateBindings()
end

if Keys:Available() then
    observer = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED",
        "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED"}) do
        observer:RegisterEvent(event)
    end
    observer:SetScript("OnEvent", function() Keys:Refresh() end)
end
