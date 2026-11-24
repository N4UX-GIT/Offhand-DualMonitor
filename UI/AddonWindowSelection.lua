local _, Offhand = ...
local Selection = {}
Offhand.AddonWindowSelection = Selection

local Windows = Offhand.LearnedAddonWindows
local toolbar, session
local buttons, spare = {}, {}
local outline = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 3,
}

local function BackdropTemplate()
    return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
end

local function MakeFrame(kind, name, parent, template)
    local factory = Offhand.UIControls and Offhand.UIControls.CreateFrame or CreateFrame
    return factory(kind, name, parent, template)
end

local function HideOutlineTooltip()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
end

local function ShowOutlineTooltip(button)
    local window = button.window
    if not window or not GameTooltip or not GameTooltip.SetOwner then return end
    GameTooltip:SetOwner(button, "ANCHOR_CURSOR")
    if GameTooltip.SetText then
        GameTooltip:SetText(string.format("%s (%s)", window.owner, window.name), 1, 0.82, 0)
    end
    if GameTooltip.AddLine then
        GameTooltip:AddLine(Offhand.L["LEARN_WINDOW_CLICK_TOOLTIP"], 0.9, 0.9, 0.9, true)
    end
    if GameTooltip.Show then GameTooltip:Show() end
end

local function RemoveButton(frame)
    local button = buttons[frame]
    button:Hide()
    button.window = nil
    buttons[frame] = nil
    spare[#spare + 1] = button
end

function Selection:Stop()
    if not session then return end
    session = nil
    HideOutlineTooltip()
    for frame in pairs(buttons) do RemoveButton(frame) end
    toolbar:Hide()
end

local function SameLocation(a, b)
    return a.strata == b.strata and a.level == b.level
        and math.abs(a.x - b.x) < 1 and math.abs(a.y - b.y) < 1
        and math.abs(a.width - b.width) < 1 and math.abs(a.height - b.height) < 1
end

local function SaveWindow(button)
    local window = button.window
    if not session or not window or not Windows:GetSelectionMetrics() then return end
    local current = Windows:DescribeSelection(window.frame)
    if not current or window.db ~= Offhand.db or current.name ~= window.name
        or current.owner ~= window.owner or current.file ~= window.file or not SameLocation(current, window) then
        Selection:Refresh()
        return
    end
    if Windows:RememberSelection(current) then
        session.saved[window.frame] = true
        HideOutlineTooltip()
        RemoveButton(window.frame)
        Offhand:Print(Offhand.L["LEARN_WINDOW_SAVED"], window.name)
        Selection:Refresh()
    else
        Offhand:Print(Offhand.L["LEARN_WINDOW_CANNOT_SAVE"], window.name)
    end
end

local function Highlight(button)
    local focused = session and session.focused == button.window.frame
    button:SetBackdropColor(0, 0.72, 1, (button.hovered or focused) and 0.28 or 0.14)
    if focused then button:SetBackdropBorderColor(1, 0.92, 0.45, 1)
    else button:SetBackdropBorderColor(0.25, 0.88, 1, button.hovered and 1 or 0.9) end
end

local function ShowButton(window)
    local button = buttons[window.frame]
    if not button then
        button = table.remove(spare)
        if not button then
            button = CreateFrame("Button", nil, UIParent, BackdropTemplate())
            button:SetBackdrop(outline)
            button:EnableMouse(true)
            button:RegisterForClicks("LeftButtonUp")
            button:SetScript("OnEnter", function(self)
                self.hovered = true
                if self.window then Highlight(self); ShowOutlineTooltip(self) end
            end)
            button:SetScript("OnLeave", function(self)
                self.hovered = nil
                HideOutlineTooltip()
                if self.window then Highlight(self) end
            end)
            button:SetScript("OnClick", SaveWindow)
        end
        buttons[window.frame] = button
        button.hovered = nil
    end
    local previous = button.window
    if not previous or previous.owner ~= window.owner or previous.file ~= window.file
        or not SameLocation(previous, window) then
        button:SetFrameStrata(window.strata)
        button:SetFrameLevel(window.level)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", window.x, window.y)
        button:SetSize(window.width, window.height)
        button.window = window
        Highlight(button)
        button:Show()
    end
end

local function FitToolbar()
    if not toolbar then return end
    local width = toolbar.boxWidth or 520
    local textWidth = width - 28
    local controls = Offhand.UIControls
    local hintHeight
    if controls and controls.FitCompactParagraph then
        hintHeight = controls.FitCompactParagraph(toolbar.hint, toolbar.hintText or "", textWidth)
    elseif toolbar.hint.GetStringHeight then
        hintHeight = math.max(24, math.ceil(toolbar.hint:GetStringHeight() or 24) + 2)
    else
        hintHeight = 42
    end
    local focusTop = 36 + hintHeight + 8
    if toolbar.focusText.ClearAllPoints then toolbar.focusText:ClearAllPoints() end
    toolbar.focusText:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 14, -focusTop)
    local focusHeight = toolbar.focusText.GetStringHeight
        and math.max(16, math.ceil(toolbar.focusText:GetStringHeight() or 16)) or 16
    toolbar:SetSize(width, math.max(132, focusTop + focusHeight + 48))
end

local function SetFocus(index)
    local previous = session.focused
    session.index = index
    local window = session.windows[index]
    session.focused = window and window.frame
    if previous ~= session.focused then
        if previous and buttons[previous] then Highlight(buttons[previous]) end
        if window then Highlight(buttons[window.frame]) end
    end
    toolbar.next:SetEnabled(#session.windows > 1)
    toolbar.add:SetEnabled(window ~= nil)
    if window then
        if toolbar.focusText.SetTextColor then toolbar.focusText:SetTextColor(1, 0.86, 0.35) end
        toolbar.focusText:SetText(string.format(Offhand.L["LEARN_WINDOW_FOCUS_ITEM"],
            index, #session.windows, window.owner, window.name))
    else
        if toolbar.focusText.SetTextColor then toolbar.focusText:SetTextColor(0.74, 0.76, 0.82) end
        toolbar.focusText:SetText(Offhand.L["LEARN_WINDOW_FOCUS_NONE"])
    end
end

function Selection:Cycle(step)
    if not session or #session.windows == 0 then return end
    SetFocus((session.index - 1 + step) % #session.windows + 1)
end

function Selection:AddFocused()
    local button = session and buttons[session.focused]
    if button then SaveWindow(button) end
end

function Selection:Refresh()
    if not session then return end
    local metrics = Windows:GetSelectionMetrics()
    if not metrics or session.db ~= Offhand.db then
        self:Stop()
        return
    end
    local windows = Windows:FindSelections(session.saved)
    table.sort(windows, function(a, b)
        if a.owner == b.owner then return a.name < b.name end
        return a.owner < b.owner
    end)
    local visible = {}
    for index, window in ipairs(windows) do visible[window.frame] = index end
    for frame in pairs(buttons) do
        if not visible[frame] then RemoveButton(frame) end
    end
    for _, window in ipairs(windows) do ShowButton(window) end
    session.windows = windows
    SetFocus(visible[session.focused] or math.max(1, math.min(session.index, #windows)))
    local hintText = Offhand.L[#windows > 0 and "LEARN_WINDOW_MODE_HELP" or "LEARN_WINDOW_NO_TARGET"]
    toolbar.hintText = hintText
    toolbar.hint:SetText(hintText)
    FitToolbar()
end

local function CreateToolbar()
    local L = Offhand.L
    local bar = CreateFrame("Frame", nil, UIParent, BackdropTemplate())
    bar:SetFrameStrata("TOOLTIP")
    bar:SetSize(520, 146)
    local heading = bar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 14, -12)
    heading:SetText(L["BINDING_NAME_OFFHAND_LEARN_WINDOW"])
    bar.hint = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bar.hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    bar.hint:SetJustifyH("LEFT")
    if bar.hint.SetWordWrap then bar.hint:SetWordWrap(true) end
    bar.focusText = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bar.focusText:SetPoint("TOPLEFT", bar, "TOPLEFT", 14, -84)
    bar.focusText:SetJustifyH("LEFT")
    if bar.focusText.SetMaxLines then bar.focusText:SetMaxLines(1) end
    local function Button(label, action)
        local button = MakeFrame("Button", nil, bar, "UIPanelButtonTemplate")
        button:SetSize(100, 26)
        button:SetText(label)
        button:SetScript("OnClick", action)
        return button
    end
    bar.next = Button(L["BTN_NEXT"], function() Selection:Cycle(1) end)
    bar.next:SetPoint("BOTTOMLEFT", 12, 12)
    bar.add = Button(ADD or L["BTN_REAPPLY"], function() Selection:AddFocused() end)
    bar.add:SetPoint("LEFT", bar.next, "RIGHT", 6, 0)
    bar.done = Button(DONE, function() Selection:Stop() end)
    bar.done:SetPoint("BOTTOMRIGHT", -12, 12)
    bar:RegisterEvent("PLAYER_REGEN_DISABLED")
    bar:RegisterEvent("PLAYER_ENTERING_WORLD")
    bar:SetScript("OnEvent", function() Selection:Stop() end)
    bar:SetScript("OnHide", function() Selection:Stop() end)
    local elapsed = 0
    bar:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.25 then
            elapsed = 0
            Selection:Refresh()
        end
    end)
    return bar
end

function Selection:Toggle()
    if session then
        self:Stop()
        return
    end
    local metrics = Windows:GetSelectionMetrics()
    if not metrics then
        Offhand:Print(Offhand.L["LEARN_WINDOW_UNAVAILABLE"])
        return
    end
    if Offhand.Options then Offhand.Options:Close() end
    toolbar = toolbar or CreateToolbar()
    Offhand.UIControls.StyleSurface(toolbar, "window")
    local width = math.max(300, math.min(540, metrics.gameRight - metrics.gameLeft - 24))
    toolbar.boxWidth = width
    toolbar:SetWidth(width)
    toolbar.hint:SetWidth(width - 28)
    toolbar.focusText:SetWidth(width - 28)
    local buttonWidth = math.min(116, (width - 48) / 3)
    toolbar.next:SetWidth(buttonWidth)
    toolbar.add:SetWidth(buttonWidth)
    toolbar.done:SetWidth(buttonWidth)
    toolbar:ClearAllPoints()
    toolbar:SetPoint("TOP", UIParent, "BOTTOMLEFT",
        (metrics.gameLeft + metrics.gameRight) / 2, metrics.gameTop - 12)
    session = {db = Offhand.db, saved = {}, windows = {}, index = 1}
    toolbar:Show()
    self:Refresh()
end
