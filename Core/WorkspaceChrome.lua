--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/WorkspaceChrome.lua: reversible workspace-only window chrome
--]]

local _, Offhand = ...

local Chrome = {
    buttonState = setmetatable({}, { __mode = "k" }),
    dynamicNames = {},
}
Offhand.WorkspaceChrome = Chrome

local knownFrameNames = {
    "WorldMapFrame",
    "CharacterFrame",
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
    "EUI_MainBagFrame",
}

local function CanUseFrame(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
end

local function IsVisible(frame)
    if not frame then return false end
    if frame.IsVisible then return frame:IsVisible() end
    return not frame.IsShown or frame:IsShown()
end

local function ReadMouseEnabled(button)
    if not button or not button.IsMouseEnabled then return true end
    local ok, enabled = pcall(button.IsMouseEnabled, button)
    if ok then return enabled ~= false end
    return true
end

local function RememberButton(button)
    if not button or not button.SetAlpha or not button.EnableMouse then return nil end
    local state = Chrome.buttonState[button]
    if state then return state end
    local alpha = 1
    if button.GetAlpha then
        local ok, value = pcall(button.GetAlpha, button)
        if ok and type(value) == "number" then alpha = value end
    end
    state = { alpha = alpha, mouse = ReadMouseEnabled(button), hidden = false }
    Chrome.buttonState[button] = state
    return state
end

local function SetButtonHidden(button, hidden)
    local state = RememberButton(button)
    if not state or (not hidden and not state.hidden) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if button.IsForbidden and button:IsForbidden() then return end
    if hidden then
        -- Native panel refreshes and third-party skins may restore their own
        -- alpha or mouse state. Reassert the opted-in hidden state on each
        -- refresh without installing hooks on the Blizzard control.
        button:SetAlpha(0)
        button:EnableMouse(false)
    else
        button:SetAlpha(state.alpha)
        button:EnableMouse(state.mouse)
    end
    state.hidden = hidden
end

local function AddButton(buttons, button)
    if button and button.SetAlpha and button.EnableMouse then buttons[button] = true end
end

local function FindEllesmereCloseButton(frame, buttons)
    local header = frame and frame.Header
    if not header or not header.GetChildren then return end
    local children = { header:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "Button"
            and child.GetPoint then
            local point, relativeTo, relativePoint = child:GetPoint(1)
            if point == "RIGHT" and relativePoint == "RIGHT" and relativeTo == header then
                AddButton(buttons, child)
            end
        end
    end
end

local function GetCloseButtons(frame, name)
    local buttons = {}
    AddButton(buttons, frame and frame.CloseButton)
    AddButton(buttons, name and _G[name .. "CloseButton"])
    if name == "WorldMapFrame" then
        AddButton(buttons, _G.WorldMapFrameCloseButton)
    elseif name == "CharacterFrame" then
        AddButton(buttons, _G.CharacterFrameCloseButton)
    elseif name == "EUI_MainBagFrame" then
        FindEllesmereCloseButton(frame, buttons)
    end
    return buttons
end

local function GetMapMaximizeButtons(frame, name)
    local buttons = {}
    if name ~= "WorldMapFrame" then return buttons end
    local border = frame and frame.BorderFrame
    local maximizeMinimize = border and border.MaximizeMinimizeFrame
    AddButton(buttons, maximizeMinimize and maximizeMinimize.MaximizeButton)
    return buttons
end

local function IsOnWorkspace(frame)
    return CanUseFrame(frame) and IsVisible(frame)
        and Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace
        and Offhand.Canvas.IsFrameOnWorkspace(frame) or false
end

function Chrome:RegisterDynamicFrame(name)
    if type(name) == "string" then self.dynamicNames[name] = true end
end

function Chrome:DiscoverDynamicFrames()
    -- BagPersistence owns addon-bag discovery and reports dynamic roots here.
    -- Merge its small registry directly instead of rescanning the entire global
    -- namespace from the one-second chrome refresh.
    local bags = Offhand.BagPersistence
    if bags and type(bags.frames) == "table" then
        for name in pairs(bags.frames) do self:RegisterDynamicFrame(name) end
    end
end

function Chrome:RestoreAll()
    for button in pairs(self.buttonState) do SetButtonHidden(button, false) end
end

function Chrome:Refresh()
    local db = Offhand.db
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    local enabled = db and db.enabled
        and (db.hideWorkspaceCloseButtons == true or db.hideWorkspaceMapMaximizeButton == true)
        and metrics and metrics.isSpanned == true
    if not enabled then
        self:RestoreAll()
        return false
    end
    if InCombatLockdown and InCombatLockdown() then return false end

    self:DiscoverDynamicFrames()
    local frameNames = {}
    for _, name in ipairs(knownFrameNames) do frameNames[name] = true end
    if type(db.savedWorkspacePositions) == "table" then
        for name in pairs(db.savedWorkspacePositions) do frameNames[name] = true end
    end
    if type(db.baganatorWorkspacePanels) == "table" then
        for name in pairs(db.baganatorWorkspacePanels) do frameNames[name] = true end
    end
    for name in pairs(self.dynamicNames) do frameNames[name] = true end

    local desired = {}
    for name in pairs(frameNames) do
        local frame = _G[name]
        if CanUseFrame(frame) then
            local hide = IsOnWorkspace(frame)
            if db.hideWorkspaceCloseButtons == true then
                for button in pairs(GetCloseButtons(frame, name)) do
                    desired[button] = desired[button] or hide
                end
            end
            if db.hideWorkspaceMapMaximizeButton == true then
                for button in pairs(GetMapMaximizeButtons(frame, name)) do
                    desired[button] = desired[button] or hide
                end
            end
        end
    end

    for button in pairs(self.buttonState) do
        if desired[button] == nil then desired[button] = false end
    end
    for button, hidden in pairs(desired) do SetButtonHidden(button, hidden == true) end
    return true
end

function Chrome:SetEnabled(enabled)
    if Offhand.db then Offhand.db.hideWorkspaceCloseButtons = enabled == true end
    self:Refresh()
end

function Chrome:SetMapMaximizeEnabled(enabled)
    if Offhand.db then Offhand.db.hideWorkspaceMapMaximizeButton = enabled == true end
    self:Refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" and C_Timer and C_Timer.NewTicker and not Chrome.ticker then
        Chrome.ticker = C_Timer.NewTicker(1, function() Chrome:Refresh() end)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() Chrome:Refresh() end)
    else
        Chrome:Refresh()
    end
end)
