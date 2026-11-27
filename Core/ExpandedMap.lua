local _, Offhand = ...
local Expanded = {}
Offhand.ExpandedMap = Expanded

local session, listener

local function Workspace()
    if not Offhand.db or not Offhand.db.enabled or Offhand._loggingOut
        or Offhand._displayGeometryTransitionActive or (InCombatLockdown and InCombatLockdown())
        or Offhand.CanvasMapPresentation.IsNativeGamepadOwned(Offhand.Canvas)
        or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
        or (EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive and EditModeManagerFrame:IsEditModeActive()) then return end
    local metrics = Offhand.Viewport:GetMetrics()
    if metrics and metrics.isSpanned then return metrics end
end

-- Blizzard's map, or an external owner whose provider handles the expanded
-- map (HandlesExpandedMap) and recovers its compact window (CanRecover,
-- Recover, ReportRecoveryFailure).
local function SupportedOwner()
    local compat = Offhand.CanvasCompatibility
    local owner = compat.GetWorldMapExternalOwner()
    if not owner then return "Blizzard" end
    if Offhand.Bridges and Offhand.Bridges:CallMap(owner, "HandlesExpandedMap") == true then return owner end
end

local function PlaceCompact(map, owner, metrics)
    if owner ~= "Blizzard" then
        local bridges = Offhand.Bridges
        if bridges:CallMap(owner, "CanRecover") ~= true then return end
        if Offhand.Canvas.IsFrameOnWorkspace(map) then return true end
        local moved, reason = bridges:CallMap(owner, "Recover", true)
        if moved then return true end
        if reason == "workspace-fit" then
            local target = Offhand.WorkspaceRegions:ForRegion(metrics)
            local _, _, width, height = Offhand.WorkspaceRegions:FrameRect(map)
            local state = Offhand.MapScale:GetState()
            if state.available and width and width > 0 and height > 0 then
                local fit = state.value * math.min((target.workspaceWidth - 24) / width, (target.workspaceHeight - 24) / height)
                if fit >= state.min and fit < state.value and Offhand.MapScale:Set(fit) then
                    if bridges:CallMap(owner, "Recover", true) then return true end
                    Offhand.MapScale:Set(state.value)
                end
            end
        end
        bridges:CallMap(owner, "ReportRecoveryFailure", reason)
        return false
    end
    local db = Offhand.db
    local positions = db.savedWorkspacePositions
    if not positions then positions = {}; db.savedWorkspacePositions = positions end
    if not Offhand.CanvasPersistence.IsPosition(positions.WorldMapFrame) then
        metrics = Offhand.WorkspaceRegions:ForRegion(metrics)
        Offhand.CanvasMapPresentation.FitWindow(map, metrics, true)
        local left, top, width, height = Offhand.WorkspaceRegions:FrameRect(map)
        if not left then return end
        if not Offhand.Canvas.IsFrameOnWorkspace(map) then
            left = metrics.workspaceLeft + (metrics.workspaceWidth - width) / 2
            top = metrics.workspaceTop - 12
        end
        local position = Offhand.CanvasPersistence.CreateWorkspacePosition(metrics, left, top, width, height)
        if not position then return end
        positions.WorldMapFrame = position
        if db.savedMainPositions then db.savedMainPositions.WorldMapFrame = nil end
        if Offhand.ForeverPersistence then
            Offhand.ForeverPersistence:SaveWorkspacePosition("WorldMapFrame", position, map:GetWidth(), map:GetHeight())
        end
    end
    Offhand.Canvas.RestoreWorkspacePosition(map)
    return Offhand.Canvas.IsFrameOnWorkspace(map)
end

local function EndSession()
    session = nil
    if listener then listener:Hide() end
end

local function ReturnCompact(current)
    EndSession()
    local map, metrics = current.map, Workspace()
    if not metrics or map ~= WorldMapFrame or map:IsForbidden() or current.owner ~= SupportedOwner() then return end
    if not map:IsShown() then ShowUIPanel(map) end
    if not map:IsShown() then return end
    if map:IsMaximized() then map:HandleUserActionMinimizeSelf() end
    if not map:IsMaximized() then PlaceCompact(map, current.owner, metrics) end
end

local function QueueReturn(dismissed)
    local current = session
    if not current then return end
    if dismissed == true then current.dismissed = true end
    if current.pending then return end
    current.pending = true
    -- The native minimize event is delivered before Blizzard finishes sizing the frame.
    C_Timer.After(0, function()
        if session ~= current then return end
        current.pending = nil
        if current.dismissed or not current.map:IsShown() or not current.map:IsMaximized() then ReturnCompact(current) end
    end)
end

local function Listen()
    if listener then return end
    listener = CreateFrame("Frame", "OffhandExpandedMapEscape", UIParent)
    listener:Hide()
    listener:RegisterEvent("PLAYER_LEAVING_WORLD")
    listener:RegisterEvent("PLAYER_REGEN_DISABLED")
    listener:SetScript("OnEvent", EndSession)
    -- Persistent compact panels opt out of Escape. Only this explicit expanded
    -- session participates in Blizzard's special-window dismissal.
    table.insert(UISpecialFrames, "OffhandExpandedMapEscape")
    listener:SetScript("OnHide", function(self)
        if not self:IsShown() then QueueReturn(true) end
    end)
    EventRegistry:RegisterCallback("WorldMapOnHide", QueueReturn, listener)
    EventRegistry:RegisterCallback("WorldMapMinimized", QueueReturn, listener)
end

function Expanded:Toggle()
    local metrics, owner = Workspace(), SupportedOwner()
    if not metrics or not owner or not UISpecialFrames or not EventRegistry or not EventRegistry.RegisterCallback
        or not C_Timer or not C_Timer.After or not ShowUIPanel then return end
    if C_GameRules and C_GameRules.IsGameRuleActive and Enum and Enum.GameRule and Enum.GameRule.MaximizeWorldMapDisabled
        and C_GameRules.IsGameRuleActive(Enum.GameRule.MaximizeWorldMapDisabled) then return end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    local map = WorldMapFrame
    if not map or not map.HandleUserActionMaximizeSelf or not map.HandleUserActionMinimizeSelf
        or not map.IsMaximized or map:IsForbidden() then return end
    local current = {map=map, owner=owner}
    if session or (map:IsShown() and map:IsMaximized()) then
        ReturnCompact(current)
        return
    end
    if not map:IsShown() then ShowUIPanel(map) end
    if not map:IsShown() then return end
    Listen()
    session = current
    if not map:IsMaximized() then map:HandleUserActionMaximizeSelf() end
    if map:IsMaximized() then listener:Show() else EndSession() end
end
