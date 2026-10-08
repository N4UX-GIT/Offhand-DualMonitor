-- Keep transient unit context menus inside the physical Mainhand rectangle.
-- Blizzard evaluates overflow against the complete spanned top-level parent,
-- including the Offhand monitor and any physical void between displays.
local _, Offhand = ...
local PopupBounds = {}
Offhand.modules.PopupBounds = PopupBounds
Offhand.PopupBounds = PopupBounds

local unitMenuTags = {
    "MENU_UNIT_TARGET", "MENU_UNIT_PLAYER", "MENU_UNIT_SELF", "MENU_UNIT_PET",
    "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_FRIEND", "MENU_UNIT_CHAT_ROSTER",
}

local function Active()
    if not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    return metrics and metrics.isSpanned and metrics or false
end

local function Accessible(frame)
    if not frame or not frame.GetLeft or not frame.GetRight
        or not frame.GetTop or not frame.GetBottom or not frame.GetEffectiveScale
        or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    if frame.IsShown and not frame:IsShown() then return false end
    return true
end

function PopupBounds:Constrain(frame)
    if InCombatLockdown and InCombatLockdown() then return false end
    local metrics = Active()
    if not metrics or not Accessible(frame) then return false end

    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local frameScale = frame:GetEffectiveScale()
    if not uiScale or uiScale <= 0 or not frameScale or frameScale <= 0 then return false end
    local toUI = frameScale / uiScale
    local left, right = frame:GetLeft(), frame:GetRight()
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end
    left, right, top, bottom = left * toUI, right * toUI, top * toUI, bottom * toUI
    local width, height = right - left, top - bottom
    if width <= 0 or height <= 0 then return false end

    local margin = 4 * (tonumber(metrics.hudScale) or 1)
    local minLeft, maxRight = metrics.gameLeft + margin, metrics.gameRight - margin
    local minBottom, maxTop = metrics.gameBottom + margin, metrics.gameTop - margin
    local newLeft = math.max(minLeft, math.min(left, maxRight - width))
    local newTop = math.min(maxTop, math.max(top, minBottom + height))
    if math.abs(newLeft - left) < 0.01 and math.abs(newTop - top) < 0.01 then return false end

    local fromUI = uiScale / frameScale
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", newLeft * fromUI, newTop * fromUI)
    end)
    return ok
end

function PopupBounds:Queue(frame)
    if not frame then return end
    local function constrain()
        if frame.IsShown and not frame:IsShown() then return end
        PopupBounds:Constrain(frame)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, constrain) else constrain() end
end

local function LegacyUnitMenu(dropdown)
    if not dropdown then return false end
    return dropdown.unit ~= nil or dropdown.which ~= nil
        or dropdown == _G.PlayerFrameDropDown or dropdown == _G.TargetFrameDropDown
        or dropdown == _G.FocusFrameDropDown
end

function PopupBounds:Initialize()
    if self.initialized then return end
    self.initialized = true

    -- Mainline and current Classic branches expose the acquired menu frame as a
    -- supported proxy. Registering against unit-menu tags avoids scanning _G or
    -- touching unrelated addon menus.
    if Menu and Menu.ModifyMenu then
        for _, tag in ipairs(unitMenuTags) do
            pcall(Menu.ModifyMenu, tag, function(_, rootDescription)
                if rootDescription and rootDescription.AddMenuAcquiredCallback then
                    rootDescription:AddMenuAcquiredCallback(function(menuFrame)
                        PopupBounds:Queue(menuFrame)
                    end)
                end
            end)
        end
    end

    -- Legacy UnitPopup uses the shared DropDownList frames. Observe the native
    -- open transaction and move only unit menus after Blizzard has sized them.
    if ToggleDropDownMenu and hooksecurefunc then
        hooksecurefunc("ToggleDropDownMenu", function(_, _, dropdown)
            if not LegacyUnitMenu(dropdown) then return end
            for index = 1, 3 do
                local menuFrame = _G["DropDownList" .. index]
                if menuFrame and (not menuFrame.IsShown or menuFrame:IsShown()) then
                    PopupBounds:Queue(menuFrame)
                end
            end
        end)
    end
end
