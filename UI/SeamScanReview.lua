-- Review window for the seam scan: lists the addon windows seen off the game
-- display and offers Keep on game display for those Offhand can place.
local _, Offhand = ...
local Review = {}
Offhand.SeamScanReview = Review

local ROWS, WIDTH, MIN_HEIGHT, ROW_HEIGHT, BUTTON_WIDTH = 8, 620, 420, 34, 180
local TEXT_WIDTH = WIDTH - 28
local window, page, openedFromOptions = nil, 1, false

local function BackdropTemplate()
    return not Offhand.isLegacyWrath and "BackdropTemplate" or nil
end

local function MakeFrame(kind, name, parent, template)
    local factory = Offhand.UIControls and Offhand.UIControls.CreateFrame or CreateFrame
    return factory(kind, name, parent, template)
end

local function Status(entry)
    local L = Offhand.L
    local key
    if entry.state == "learnable" then
        key = entry.visible and "SEAM_SCAN_STATUS_LEARNABLE" or "SEAM_SCAN_STATUS_OPEN_FIRST"
    elseif entry.state == "learned" then
        key = "SEAM_SCAN_STATUS_LEARNED"
    elseif entry.state == "bridged" then
        key = "SEAM_SCAN_STATUS_BRIDGED"
    elseif entry.state == "owned" then
        key = "SEAM_SCAN_STATUS_OWNED"
    else
        key = "SEAM_SCAN_STATUS_MANUAL"
    end
    local text = L[entry.class == "seam" and "SEAM_SCAN_CLASS_SEAM" or "SEAM_SCAN_CLASS_AWAY"] .. ": " .. L[key]
    if entry.bridge and (entry.state == "learnable" or entry.state == "manual") then
        text = text .. " " .. L["SEAM_SCAN_STATUS_GAP"]
    end
    return text
end

local function SummaryText(summary)
    return string.format(Offhand.L["SEAM_SCAN_SUMMARY"], summary.seen, summary.learnable + summary.manual,
        summary.bridged + summary.owned + summary.learned)
end

local function RowAction(button)
    local entry, scan = button.entry, Offhand.SeamScan
    if not entry or not scan then return end
    if button.action == "keep" then
        if not scan:KeepOnMainhand(entry.key) then
            Offhand:Print(Offhand.L["SEAM_SCAN_KEEP_FAILED"], scan:Label(entry))
        end
    elseif button.action == "forget" and scan:Forget(entry.key) then
        Offhand:Print(Offhand.L["LEARN_WINDOW_FORGOTTEN"], scan:Label(entry))
    end
    Review:Refresh()
end

local function CreateWindow()
    local L = Offhand.L
    local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplate())
    frame:SetFrameStrata("DIALOG")
    frame:SetSize(WIDTH, MIN_HEIGHT)
    local heading = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 14, -12)
    heading:SetText(L["SEAM_SCAN_TITLE"])
    local intro = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -34)
    intro:SetWidth(TEXT_WIDTH)
    intro:SetJustifyH("LEFT")
    if intro.SetWordWrap then intro:SetWordWrap(true) end
    intro:SetText(L["SEAM_SCAN_INTRO"])
    local controls = Offhand.UIControls
    local introHeight = controls and controls.FitCompactParagraph
        and controls.FitCompactParagraph(intro, L["SEAM_SCAN_INTRO"], TEXT_WIDTH) or 42
    local summaryTop = 34 + introHeight + 6
    frame.summary = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -summaryTop)
    frame.summary:SetWidth(TEXT_WIDTH)
    frame.summary:SetJustifyH("LEFT")
    local rowsTop = summaryTop + 22
    frame.rows = {}
    for index = 1, ROWS do
        local top = rowsTop + (index - 1) * ROW_HEIGHT
        local row = {}
        row.title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -top)
        row.title:SetWidth(TEXT_WIDTH - BUTTON_WIDTH - 8)
        row.title:SetJustifyH("LEFT")
        if row.title.SetMaxLines then row.title:SetMaxLines(1) end
        row.status = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        row.status:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -(top + 15))
        row.status:SetWidth(TEXT_WIDTH - BUTTON_WIDTH - 8)
        row.status:SetJustifyH("LEFT")
        if row.status.SetMaxLines then row.status:SetMaxLines(1) end
        if row.status.SetTextColor then row.status:SetTextColor(0.62, 0.64, 0.70) end
        row.button = MakeFrame("Button", nil, frame, "UIPanelButtonTemplate")
        row.button:SetSize(BUTTON_WIDTH, 24)
        row.button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -(top + 2))
        row.button:SetScript("OnClick", RowAction)
        row.button:Hide()
        frame.rows[index] = row
    end
    local function Button(label, action)
        local button = MakeFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(110, 26)
        button:SetText(label)
        button:SetScript("OnClick", action)
        return button
    end
    frame.previous = Button(L["BTN_BACK"], function()
        page = page - 1
        Review:Refresh()
    end)
    frame.previous:SetPoint("BOTTOMLEFT", 12, 12)
    frame.next = Button(L["BTN_NEXT"], function()
        page = page + 1
        Review:Refresh()
    end)
    frame.next:SetPoint("LEFT", frame.previous, "RIGHT", 6, 0)
    frame.clear = Button(L["SEAM_SCAN_BTN_CLEAR"], function()
        if Offhand.SeamScan then Offhand.SeamScan:Clear() end
        Review:Refresh()
    end)
    frame.clear:SetPoint("LEFT", frame.next, "RIGHT", 6, 0)
    frame.done = Button(DONE, function() Review:Close(true) end)
    frame.done:SetPoint("BOTTOMRIGHT", -12, 12)
    frame:SetHeight(math.max(MIN_HEIGHT, rowsTop + ROWS * ROW_HEIGHT + 50))
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function() Review:Close() end)
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.5 then
            elapsed = 0
            Review:Refresh()
        end
    end)
    frame:Hide()
    return frame
end

local function Place(frame)
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    frame:ClearAllPoints()
    if metrics and metrics.isSpanned and type(metrics.gameLeft) == "number" and type(metrics.gameRight) == "number"
        and type(metrics.gameBottom) == "number" and type(metrics.gameTop) == "number" then
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (metrics.gameLeft + metrics.gameRight) / 2,
            (metrics.gameBottom + metrics.gameTop) / 2)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function Review:IsOpen()
    return window ~= nil and window:IsShown() == true
end

function Review:Refresh()
    if not self:IsOpen() then return end
    local L, scan = Offhand.L, Offhand.SeamScan
    local entries = scan and scan:GetEntries() or {}
    local pages = math.max(1, math.ceil(#entries / ROWS))
    page = math.max(1, math.min(page, pages))
    window.summary:SetText(scan and SummaryText(scan:GetSummary()) or "")
    for index, row in ipairs(window.rows) do
        local entry = entries[(page - 1) * ROWS + index]
        local action, label
        if entry then
            row.title:SetText(entry.owner .. ": " .. scan:Label(entry))
            row.status:SetText(Status(entry))
            if entry.state == "learnable" and entry.visible then
                action, label = "keep", L["SEAM_SCAN_BTN_KEEP"]
            elseif entry.state == "learned" then
                action, label = "forget", L["LEARN_WINDOW_BTN_FORGET"]
            end
        else
            row.title:SetText("")
            row.status:SetText("")
        end
        row.button.entry, row.button.action = entry, action
        if action then
            row.button:SetText(label)
            row.button:Show()
        else
            row.button:Hide()
        end
    end
    window.previous:SetEnabled(page > 1)
    window.next:SetEnabled(page < pages)
end

-- Opened from Settings, Done returns there, as the window picker does.
function Review:Open(fromOptions)
    if InCombatLockdown and InCombatLockdown() then return end
    if Offhand.Options then Offhand.Options:Close() end
    window = window or CreateWindow()
    if Offhand.UIControls and Offhand.UIControls.StyleSurface then
        Offhand.UIControls.StyleSurface(window, "window")
    end
    Place(window)
    page, openedFromOptions = 1, fromOptions == true
    window:Show()
    self:Refresh()
end

function Review:Close(reopenOptions)
    if not window then return end
    local shouldReopen = reopenOptions == true and openedFromOptions
    openedFromOptions = false
    window:Hide()
    if shouldReopen and not (InCombatLockdown and InCombatLockdown())
        and Offhand.Options and Offhand.Options.Open then
        Offhand.Options:Open()
    end
end

function Review:Toggle(fromOptions)
    if self:IsOpen() then
        self:Close()
    else
        self:Open(fromOptions)
    end
end
