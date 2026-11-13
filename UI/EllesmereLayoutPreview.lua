local _, Offhand = ...
local Transfer = Offhand.EllesmereLayout
if not Transfer then return end

local Controls, L = Offhand.UIControls, Offhand.L
local dialog
local importReturn, watchedImporter
local directions = {"fit", "ellesmere", "blizzard"}
local modeLabels = {fit = "ELLESMERE_HUD_FIT", ellesmere = "ELLESMERE_HUD_COPY", blizzard = "ELLESMERE_HUD_FALLBACK"}
local modeGuidance = {
    fit = "ELLESMERE_HUD_GUIDE_FIT",
    ellesmere = "ELLESMERE_HUD_GUIDE_COPY",
    blizzard = "ELLESMERE_HUD_GUIDE_FALLBACK",
}
local rowGuidance = {
    ELLESMERE_HUD_FOLLOWS = "ELLESMERE_HUD_LINK_HELP",
    ELLESMERE_HUD_SCREEN_EDGE = "ELLESMERE_HUD_SCREEN_EDGE_HELP",
    ELLESMERE_HUD_ANCHORED = "ELLESMERE_HUD_LINK_HELP",
    ELLESMERE_HUD_MOVES_WITH = "ELLESMERE_HUD_LINK_HELP",
    ELLESMERE_HUD_BOUNDS = "ELLESMERE_HUD_BOUNDS_HELP",
    ELLESMERE_HUD_CHILD_BOUNDS = "ELLESMERE_HUD_BOUNDS_HELP",
    ELLESMERE_HUD_ANCHOR_GRAPH = "ELLESMERE_HUD_ANCHOR_GRAPH_HELP",
    ELLESMERE_HUD_GROUP_TOO_LARGE = "ELLESMERE_HUD_GROUP_TOO_LARGE_HELP",
}
local colors = {{1, .73, .3}, {.35, .8, 1}, {.39, .91, .65}, {.98, .55, .66}, {.75, .64, 1}}
for _, color in ipairs({{.95, .85, .4}, {.4, .85, .85}, {.9, .65, .4}, {.8, .9, .5},
    {.6, .7, 1}, {.95, .5, .8}, {.8, .8, .8}}) do colors[#colors + 1] = color end

local function Surface(parent)
    return CreateFrame("Frame", nil, parent, "BackdropTemplate")
end

local function Label(parent, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetJustifyH("LEFT")
    return label
end

local function Button(parent, label, width, onClick)
    local button = Controls.CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 26)
    button:SetText(L[label])
    button:SetScript("OnClick", onClick)
    return button
end

local function MakeDiagram(parent, title, column)
    local map = Surface(parent)
    map:SetSize(424, 216)
    map:SetPoint("TOPLEFT", parent, "TOPLEFT", 18 + column * 440, -160)
    Controls.StyleSurface(map, "input")
    local label = Label(parent, "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", map, "TOPLEFT", 0, 6)
    label:SetText(L[title])
    map.canvas = CreateFrame("Frame", nil, map)
    map.canvas:SetPoint("CENTER")
    map.displays, map.markers = {}, {}
    for i, displayLabel in ipairs({"ELLESMERE_HUD_MAINHAND", "ELLESMERE_HUD_WORKSPACE"}) do
        local screen = CreateFrame("Frame", nil, map.canvas)
        local fill = screen:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        if i == 1 then fill:SetColorTexture(.13, .22, .30, 1) else fill:SetColorTexture(.17, .17, .22, 1) end
        local name = Label(screen, "GameFontHighlightSmall")
        name:SetPoint("TOPLEFT", 5, -5)
        name:SetPoint("RIGHT", -4, 0)
        name:SetWordWrap(false)
        name:SetText(L[displayLabel])
        map.displays[i] = screen
    end
    for i, color in ipairs(colors) do
        local marker = CreateFrame("Frame", nil, map.canvas)
        marker:SetFrameLevel(map.canvas:GetFrameLevel() + 3)
        local fill = marker:CreateTexture(nil, "ARTWORK")
        fill:SetAllPoints()
        fill:SetColorTexture(color[1], color[2], color[3], .65)
        local number = Label(marker, "GameFontHighlightSmall")
        number:SetPoint("CENTER")
        number:SetText(i)
        marker.number = number
        map.markers[i] = marker
    end
    return map
end

local function Plot(map, context, rows, after, direction, selected, offset)
    local rect = context and context.rect
    map.canvas:SetShown(rect ~= nil)
    if not rect then return end
    local width, height = rect.screenWidth, rect.screenHeight
    local scale = math.min(408 / width, 200 / height)
    map.canvas:SetSize(width * scale, height * scale)
    for i, display in ipairs(map.displays) do
        local b = i == 1 and rect or i == 2 and context.workspace
        display:SetShown(b ~= nil and b ~= false)
        if b then
            display:ClearAllPoints()
            display:SetPoint("BOTTOMLEFT", map.canvas, "BOTTOMLEFT", b.left * scale, b.bottom * scale)
            display:SetSize((b.right - b.left) * scale, (b.top - b.bottom) * scale)
        end
    end
    for i, marker in ipairs(map.markers) do
        local row = rows[i + offset]
        marker.number:SetText(i + offset)
        local b = row and (row.groupCurrent or row.current)
        local proposed = row and selected[row.followKey or row.map.key] ~= false and (row.groupProposed or row.proposed)
        if after then b = proposed or (direction ~= "blizzard" and b) end
        marker:Hide()
        if b and b.left <= width and b.bottom <= height and b.left + b.width >= 0 and b.bottom + b.height >= 0 then
            local left, bottom = math.max(b.left, 0), math.max(b.bottom, 0)
            local right, top = math.min(b.left + b.width, width), math.min(b.bottom + b.height, height)
            marker:ClearAllPoints()
            marker:SetPoint("CENTER", map.canvas, "BOTTOMLEFT", (left + right) * scale / 2, (bottom + top) * scale / 2)
            marker:SetSize(math.max(15, (right - left) * scale), math.max(14, (top - bottom) * scale))
            marker:SetAlpha(after and not proposed and .55 or 1)
            marker:Show()
        end
    end
end

local function ReadPlan(direction)
    local ok, rows, source, context = pcall(Transfer.Preview, Transfer, direction)
    if not ok then return nil, "ELLESMERE_HUD_UNAVAILABLE" end
    if not rows then return nil, source end
    local signature = {context.profileName or "", source or "", context.controller and "1" or "0",
        Offhand.MainhandGeometry.Signature(context.rect)}
    local workspace = context.workspace
    if workspace then
        signature[#signature + 1] = string.format("%f,%f,%f,%f", workspace.left, workspace.bottom, workspace.right, workspace.top)
    end
    local changed = 0
    for _, row in ipairs(rows) do
        signature[#signature + 1] = row.map.specKey or ""
        local pos = row.position or row.anchor
        if pos then
            changed = changed + 1
            signature[#signature + 1] = string.format("%s,%s,%s,%.6f,%.6f", row.map.key, pos.point,
                pos.relPoint or pos.relativePoint, pos.x or pos.offsetX, pos.y or pos.offsetY)
        end
        for _, bounds in ipairs({row.groupCurrent or row.current or {}, row.groupProposed or row.proposed or {}}) do
            signature[#signature + 1] = string.format("%s,%s,%s,%s", tostring(bounds.left),
                tostring(bounds.bottom), tostring(bounds.width), tostring(bounds.height))
        end
    end
    return {rows = rows, context = context, source = source, signature = table.concat(signature, "|"), changed = changed}
end

local function Render(direction)
    local plan, reason = ReadPlan(direction)
    if direction ~= dialog.direction then dialog.rowSelection, dialog.page = {}, 1 end
    dialog.direction, dialog.plan = direction, plan
    local context = plan and plan.context
    local rows = plan and plan.rows or {}
    for _, button in ipairs(dialog.modes) do
        button.selected = button.direction == direction
        Controls.StyleSurface(button, "button")
    end
    dialog.subtitle:SetText(context and string.format(L["ELLESMERE_HUD_VISUAL_SOURCE"],
        context.profileName or "—", plan.source or "—") or L[reason])
    dialog.guide:SetText(L[modeGuidance[direction]])
    local pages = math.max(1, math.ceil(#rows / #colors))
    dialog.page = math.min(dialog.page or 1, pages)
    local offset = (dialog.page - 1) * #colors
    dialog.previous:SetEnabled(dialog.page > 1)
    dialog.next:SetEnabled(dialog.page < pages)
    dialog.pages:SetText(string.format("%d / %d", dialog.page, pages))
    Plot(dialog.before, context, rows, false, direction, dialog.rowSelection, offset)
    Plot(dialog.after, context, rows, true, direction, dialog.rowSelection, offset)
    local selected, blocked = 0, 0
    for _, row in ipairs(rows) do
        if (row.position or row.anchor) and dialog.rowSelection[row.map.key] ~= false then selected = selected + 1 end
        if not (row.position or row.anchor or row.followKey) and row.reason ~= "ELLESMERE_HUD_KEEP" then
            blocked = blocked + 1
        end
    end
    for i, label in ipairs(dialog.legend) do
        local row = rows[i + offset]
        local canCopy = row and (row.position or row.anchor)
        local checked = canCopy and dialog.rowSelection[row.map.key] ~= false
        local status = row and (row.reason or (row.anchor and "ELLESMERE_HUD_POINT_ONLY"
            or row.linkedGroup and "ELLESMERE_HUD_MOVE_GROUP" or "ELLESMERE_HUD_WILL_MOVE"))
        local checkbox = dialog.checkboxes[i]
        checkbox:SetShown(canCopy ~= nil and canCopy ~= false)
        checkbox:SetChecked(checked == true)
        local name = row and (row.map.displayLabel or (row.map.number and string.format(L[row.map.label], row.map.number) or L[row.map.label]))
        local message = row and (row.reasonArgs and string.format(L[status], unpack(row.reasonArgs)) or L[status])
        label:SetText(row and string.format("%d  %s  ·  %s", i + offset, name, message) or "")
        local helpKey = row and rowGuidance[status]
        dialog.rowHelp[i].text = row and (name .. "\n" .. message .. (helpKey and "\n\n" .. L[helpKey] or "")) or nil
    end
    dialog.apply:SetText(L[direction == "blizzard" and "ELLESMERE_HUD_SAVE_FALLBACK" or "ELLESMERE_HUD_REVIEW_IMPORT"])
    dialog.apply:SetEnabled(plan and not context.block and selected > 0 or false)
    local summary = context and context.block and L[context.block]
        or plan and selected == 0 and (context.unavailable and L["ELLESMERE_HUD_MODULE_GUIDANCE"]
            or blocked > 0 and string.format(L["ELLESMERE_HUD_BLOCKED_ROWS"], blocked)
            or L[plan.changed == 0 and "ELLESMERE_HUD_NO_CHANGES" or "ELLESMERE_HUD_SELECT_ROWS"])
        or plan and blocked > 0 and string.format(L["ELLESMERE_HUD_PARTIAL"], selected, blocked) or ""
    if context and context.block == "ELLESMERE_HUD_OVERRIDES" then
        summary = L["ELLESMERE_HUD_OVERRIDES_HELP"]
    end
    if direction ~= "blizzard" and context and not context.block and selected > 0 then
        summary = (summary ~= "" and summary .. "\n" or "") .. L["ELLESMERE_HUD_NEW_PROFILE_NAME"]
    end
    dialog.status:SetText(summary)
end

function Transfer:PromptImportReload()
    if not self:HasPendingReload() or not (StaticPopupDialogs and Offhand.ShowPopup) then return end
    local mainhand = Offhand.Mainhand
    local manual = not Offhand:GetReloadUIFunction() or (InCombatLockdown and InCombatLockdown())
        or mainhand and mainhand.IsNativeGamepadInterface and mainhand:IsNativeGamepadInterface()
    StaticPopupDialogs.OFFHAND_ELLESMERE_HUD_RELOAD = {
        offhandAcceptBeforeHide = true,
        text = L[manual and "ELLESMERE_HUD_IMPORT_RELOAD_MANUAL" or "ELLESMERE_HUD_IMPORT_RELOAD_PROMPT"],
        button1 = manual and (OKAY or "OK") or L["ONBOARD_RELOAD_UI"],
        button2 = not manual and L["CHARACTER_SETUP_LATER"] or nil,
        OnAccept = not manual and function()
            if not self:HasPendingReload() then return end
            local reload = Offhand:GetReloadUIFunction()
            if reload and not (InCombatLockdown and InCombatLockdown())
                and not (mainhand and mainhand.IsNativeGamepadInterface and mainhand:IsNativeGamepadInterface()) then
                reload()
            else
                self:PromptImportReload()
            end
        end or nil,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    return Offhand:ShowPopup("OFFHAND_ELLESMERE_HUD_RELOAD")
end

local function ReviewImport(plan, rows)
    local onDismiss = dialog.onDismiss
    dialog.onDismiss = nil
    dialog:Hide()
    local function Failed(reason)
        if dialog.plan ~= plan or dialog:IsShown() then return end
        dialog.onDismiss = onDismiss
        dialog.status:SetText(L[reason or "ELLESMERE_HUD_IMPORT_FAILED"])
        dialog:Show()
        dialog:Raise()
    end
    local function CanContinue()
        if dialog.plan ~= plan or dialog:IsShown() then return false end
        if InCombatLockdown() then
            Failed("ELLESMERE_HUD_BUSY")
            return false
        end
        return true
    end

    -- Let the click and preview close finish before opening the load-on-demand
    -- options panel. Give Profiles its own pass before starting async decode.
    C_Timer.After(0, function()
        if not CanContinue() then return end
        local eui = _G.EllesmereUI
        if not (eui and eui.NavigateToElementSettings and eui.GetActiveModule and eui.GetActivePage) then
            Failed()
            return
        end
        local ok = pcall(eui.NavigateToElementSettings, eui, "_EUIProfiles", "Profiles")
        if not ok then
            Failed()
            return
        end
        C_Timer.After(0, function()
            if not CanContinue() then return end
            if eui.IsShown and not eui:IsShown() then
                if onDismiss then onDismiss() end
                return
            end
            if eui:GetActiveModule() ~= "_EUIProfiles" or eui:GetActivePage() ~= "Profiles" then
                Failed()
                return
            end
            -- The cached tab can be active while its separately pooled content
            -- is hidden. Repair it before there is an import session to orphan.
            local root = eui._profilesRoot
            if eui.RefreshPage and (not root or not root:IsVisible()) then
                local refreshed = pcall(eui.RefreshPage, eui, true)
                if not refreshed then
                    Failed()
                    return
                end
            end
            local function ImportFinished(result)
                if not onDismiss and result ~= "reload" then return end
                local function Return()
                    if onDismiss then
                        onDismiss(result)
                    else
                        Transfer:PromptImportReload()
                    end
                end
                C_Timer.After(0, function()
                    local frame = eui.GetMainFrame and eui:GetMainFrame()
                    if not (frame and frame:IsShown()) then
                        Return()
                        return
                    end
                    -- A decode error leaves EllesmereUI visible. Return when
                    -- the user closes it, just as after a normal review.
                    importReturn = Return
                    if watchedImporter == frame then return end
                    watchedImporter = frame
                    frame:HookScript("OnHide", function()
                        if watchedImporter ~= frame then return end
                        local callback = importReturn
                        importReturn = nil
                        if callback then C_Timer.After(0, callback) end
                    end)
                end)
            end
            local called, opened, reason = pcall(Transfer.OpenImport, Transfer, rows, ImportFinished)
            if not (called and opened) then
                Failed(reason == "ELLESMERE_HUD_OVERRIDES" and reason or nil)
            end
        end)
    end)
end

local function Apply()
    local previous = dialog.plan
    if not previous then return end
    Render(dialog.direction)
    local current = dialog.plan
    if not current or current.context.block then return end
    if current.signature ~= previous.signature then
        dialog.status:SetText(L["ELLESMERE_HUD_REFRESHED"])
        return
    end
    local rows, canApply = {}, false
    for _, row in ipairs(current.rows) do
        if dialog.rowSelection[row.map.key] ~= false then
            rows[#rows + 1] = row
            canApply = canApply or row.position or row.anchor
        end
    end
    if not canApply then return end
    if dialog.direction == "blizzard" then
        local ok, result = Offhand.Mainhand:SaveEllesmereFallback(current.context, rows)
        if ok then
            dialog.apply:Disable()
            dialog.status:SetText(string.format(L["ELLESMERE_HUD_FALLBACK_SAVED"], result))
        else
            dialog.status:SetText(Offhand.Options:GetMainhandLayoutFailureText(result))
        end
    else
        ReviewImport(current, rows)
    end
end

local function CreateDialog()
    local frame = CreateFrame("Frame", "OffhandEllesmerePreviewFrame", UIParent, "BackdropTemplate")
    frame:SetSize(900, 700)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetScript("OnHide", function(self)
        local callback = self.onDismiss
        self.onDismiss = nil
        -- Escape can close multiple registered windows in one pass.
        if callback then C_Timer.After(0, callback) end
    end)
    if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end
    Controls.StyleSurface(frame, "window")
    local title = Label(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 18, -15)
    title:SetText(L["ELLESMERE_HUD_VISUAL"])
    frame.subtitle = Label(frame, "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    frame.modes = {}
    for i, direction in ipairs(directions) do
        local button = Button(frame, modeLabels[direction], 276, function() Render(direction) end)
        button.direction = direction
        button:SetPoint("TOPLEFT", 18 + (i - 1) * 292, -66)
        frame.modes[i] = button
    end
    frame.guide = Label(frame, "GameFontHighlightSmall")
    frame.guide:SetPoint("TOPLEFT", 18, -102)
    frame.guide:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    frame.guide:SetWordWrap(true)
    frame.before = MakeDiagram(frame, "ELLESMERE_HUD_CURRENT", 0)
    frame.after = MakeDiagram(frame, "ELLESMERE_HUD_PROPOSED", 1)
    frame.legend, frame.checkboxes, frame.rowHelp = {}, {}, {}
    for i, color in ipairs(colors) do
        local column, line = math.floor((i - 1) / 6), (i - 1) % 6
        local checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        checkbox:SetSize(16, 16)
        checkbox:SetPoint("TOPLEFT", 18 + column * 440, -381 - line * 26)
        checkbox:SetScript("OnClick", function(self)
            local row = frame.plan and frame.plan.rows[i + ((frame.page or 1) - 1) * #colors]
            if not row then return end
            frame.rowSelection[row.map.key] = self:GetChecked() == true
            Render(frame.direction)
        end)
        frame.checkboxes[i] = checkbox
        local label = Label(frame, "GameFontHighlightSmall")
        label:SetTextColor(unpack(color))
        label:SetPoint("TOPLEFT", 38 + column * 440, -383 - line * 26)
        label:SetWidth(404)
        label:SetHeight(24)
        if label.SetMaxLines then label:SetMaxLines(2) end
        label:SetWordWrap(true)
        frame.legend[i] = label
        local help = CreateFrame("Frame", nil, frame)
        help:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
        help:SetSize(404, 26)
        help:EnableMouse(true)
        help:SetScript("OnEnter", function(self)
            if not self.text or not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.text, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        help:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        frame.rowHelp[i] = help
    end
    frame.previous = Button(frame, "BTN_BACK", 90, function() frame.page = frame.page - 1; Render(frame.direction) end)
    frame.previous:SetPoint("BOTTOMLEFT", 18, 48)
    frame.pages = Label(frame, "GameFontHighlightSmall")
    frame.pages:SetPoint("LEFT", frame.previous, "RIGHT", 12, 0)
    frame.next = Button(frame, "BTN_NEXT", 90, function() frame.page = frame.page + 1; Render(frame.direction) end)
    frame.next:SetPoint("LEFT", frame.pages, "RIGHT", 12, 0)
    local close = Button(frame, "BTN_CLOSE", 120, function() frame:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -18, 14)
    frame.apply = Button(frame, "ELLESMERE_HUD_REVIEW_IMPORT", 228, Apply)
    frame.apply:SetPoint("RIGHT", close, "LEFT", -8, 0)
    frame.status = Label(frame, "GameFontHighlightSmall")
    frame.status:SetPoint("TOPLEFT", 20, -550)
    frame.status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.status:SetHeight(68)
    frame.status:SetWordWrap(true)
    return frame
end

function Transfer:ShowPreview(direction, onDismiss)
    if not self:IsAvailable() then return end
    if not dialog then dialog = CreateDialog() end
    local m = Offhand.Viewport:GetMetrics()
    local scale = Controls.FitDialog(dialog, m)
    dialog:ClearAllPoints()
    if m and m.isSpanned then
        dialog:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (m.gameLeft + m.gameRight) / (2 * scale),
            (m.gameBottom + m.gameTop) / (2 * scale))
    else
        dialog:SetPoint("CENTER", UIParent)
    end
    dialog.rowSelection = {}
    dialog.onDismiss = onDismiss or dialog.onDismiss
    Render(direction or "fit")
    dialog:Show()
    dialog:Raise()
    return true
end
