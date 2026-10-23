-- Forever World Map observation, deferred restoration, and external drag controls.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasForeverMap = Adapter

function Adapter.Install(Canvas, services)
    local Compatibility = Offhand.CanvasCompatibility
    local FrameState = Offhand.CanvasFrameState
    local IsExternallyPositionedWorldMap = Compatibility.IsExternallyPositionedWorldMap
    local ShouldYieldWorldMapToMoveAny = Compatibility.ShouldYieldWorldMap
    local IsForeverWorldMap = FrameState.IsForeverWorldMap
    local GetForeverWorldMapState = FrameState.GetForeverWorldMapState
    local SetPanelDragging = FrameState.SetDragging
    local RegisterSpecialFrame = assert(services.RegisterSpecialFrame, "Missing Forever map service: RegisterSpecialFrame")
    local GetPanelPhysicalPlacement = assert(services.GetPanelPhysicalPlacement, "Missing Forever map service: GetPanelPhysicalPlacement")
    local PlacementMatchesPosition = assert(services.PlacementMatchesPosition, "Missing Forever map service: PlacementMatchesPosition")
    local NotePanelControllerActivity = assert(services.NotePanelControllerActivity, "Missing Forever map service: NotePanelControllerActivity")
    local RestoreSavedPositionAfterShow = assert(services.RestoreSavedPositionAfterShow, "Missing Forever map service: RestoreSavedPositionAfterShow")
    local UnregisterSpecialFrame = assert(services.UnregisterSpecialFrame, "Missing Forever map service: UnregisterSpecialFrame")
    local EvictWorkspacePanelSlot = assert(services.EvictWorkspacePanelSlot, "Missing Forever map service: EvictWorkspacePanelSlot")
    local RestoreWorkspacePosition = assert(services.RestoreWorkspacePosition, "Missing Forever map service: RestoreWorkspacePosition")
    local WithWorkspace = assert(services.WithWorkspace, "Missing Forever map service: WithWorkspace")
    local OnPanelDragStop = assert(services.OnPanelDragStop, "Missing Forever map service: OnPanelDragStop")

    -- Forever's map-pin sharing path is protected. A drag handler parented to the
    -- World Map, or attached to its native title/close controls, taints the same
    -- widget tree used by Blizzard's Shift-click link insertion. Provide the map's
    -- drag affordance from an independent UIParent child and follow the map by
    -- reading geometry only. The handle never becomes a child or anchor dependent
    -- of WorldMapFrame and no script is installed on any native map object.
    local function QueueForeverWorldMapSettlement(map, state, shown, forcePanelTransaction)
        if not Offhand.isForever or not map or not state then return end
        if forcePanelTransaction then
            if not shown then return end
            state.observedShown = true
        elseif state.observedShown == nil then
            state.observedShown = shown
            -- The map begins hidden during login even when the previous session
            -- persisted it as open. Do not reinterpret that construction state as
            -- an explicit close before RestorePersistentFrames gets its turn.
            if not shown then return end
        elseif state.observedShown == shown then
            return
        else
            state.observedShown = shown
        end

        if not shown then
            Canvas:SetWorkspacePanelOpen(map, false)
            if IsExternallyPositionedWorldMap(map) and (not Offhand.db or not Offhand.db.enabled
                or Offhand.db.persistentWorkspacePanels == false) then
                RegisterSpecialFrame("WorldMapFrame")
            end
            return
        end

        if IsExternallyPositionedWorldMap(map) then
            Canvas:PreserveExternalWorldMapOpenState(map)
            return
        end

        state.settlementGeneration = (state.settlementGeneration or 0) + 1
        local generation = state.settlementGeneration
        local function Settle()
            if generation ~= state.settlementGeneration
                or ShouldYieldWorldMapToMoveAny(map)
                or not Offhand.db or not Offhand.db.enabled
                or not map.IsShown or not map:IsShown() then return end
            if InCombatLockdown() then
                if Offhand.RunOrQueueCombat then
                    Offhand:RunOrQueueCombat(Settle)
                end
                return
            end

            local workspacePosition = Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions.WorldMapFrame
            local mainPosition = Offhand.db.savedMainPositions
                and Offhand.db.savedMainPositions.WorldMapFrame
            if workspacePosition then Canvas:SetWorkspacePanelOpen(map, true) end
            local savedPosition = workspacePosition or mainPosition
            if savedPosition then
                local placement = GetPanelPhysicalPlacement(map)
                if not PlacementMatchesPosition(placement, savedPosition) then
                    NotePanelControllerActivity("WorldMapFrame", "forever-world-map", "settlement")
                    RestoreSavedPositionAfterShow(map)
                end
            elseif not (map.IsMaximized and map:IsMaximized()) then
                Canvas:RescuePanelFromVoid(map)
            end
            Canvas:RepairShownWorkspacePanels(map)
            if workspacePosition and Offhand.db.persistentWorkspacePanels ~= false then
                -- ShowUIPanel can reclaim the center slot after the first geometry
                -- restore. Reassert Escape ownership on every delayed settlement.
                UnregisterSpecialFrame("WorldMapFrame")
                EvictWorkspacePanelSlot(map)
            end
        end

        -- Never alter WorldMapFrame from ToggleWorldMap/ToggleQuestLog's protected
        -- hardware-action stack. The independent observer notices the visibility
        -- edge on a later frame and settles geometry only after Blizzard returns.
        Settle()
        if C_Timer and C_Timer.After then
            -- UIPanel transactions on Forever can enqueue another layout from a
            -- timer which itself was created by the first layout pass. Scheduling
            -- every repair from this stack only covers the first timer generation
            -- and lets that nested write move the map afterwards. Chain a bounded
            -- series instead, so each pass is able to observe work queued by the
            -- preceding pass without installing a permanent poller.
            local delays = forcePanelTransaction and { 0, 0.10, 0.20, 0.30 }
                or { 0, 0.10 }
            local function Schedule(index)
                local delay = delays[index]
                if delay == nil then return end
                C_Timer.After(delay, function()
                    if generation ~= state.settlementGeneration then return end
                    Settle()
                    Schedule(index + 1)
                end)
            end
            Schedule(1)
        end
    end

    -- Route every completed Blizzard UIPanel transaction through one dispatcher.
    -- Each panel family still has exactly one position writer: the World Map and
    -- Social adapters run their dedicated repair, while the generic pass can only
    -- touch panels assigned to the generic controller.
    local function RepairUIPanelTransaction(exceptFrame, skipBagCapture)
        local map = _G.WorldMapFrame
        if IsForeverWorldMap(map) and map.IsShown and map:IsShown() then
            QueueForeverWorldMapSettlement(
                map, GetForeverWorldMapState(map), true, true)
        end
        Canvas:RepairShownWorkspacePanels(exceptFrame, skipBagCapture)
        Canvas:RepairShownSocialCommunityPanels()
    end

    local function AttachForeverWorldMapDragHandle(map)
        if not IsForeverWorldMap(map) or not CreateFrame or not UIParent then return false end
        if ShouldYieldWorldMapToMoveAny(map) and not IsExternallyPositionedWorldMap(map) then return false end
        local state = GetForeverWorldMapState(map)
        if state.handle then return true end

        local handle = CreateFrame("Frame", nil, UIParent)
        if not handle then return false end
        state.handle = handle

        if handle.SetFrameStrata then handle:SetFrameStrata("TOOLTIP") end
        if handle.SetFrameLevel then handle:SetFrameLevel(10000) end
        if handle.EnableMouse then handle:EnableMouse(false) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end

        -- Keep the recovery control wholly outside the protected MapCanvas tree.
        -- Its click is a hardware event, so Blizzard's user-action minimize route is
        -- invoked directly from the click rather than from an OnUpdate/timer repair.
        -- The polling code below only reads native map state and positions this
        -- addon-owned button; it never writes to WorldMapFrame.
        local returnButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
        if returnButton then
            state.returnButton = returnButton
            if returnButton.SetFrameStrata then returnButton:SetFrameStrata("TOOLTIP") end
            if returnButton.SetFrameLevel then returnButton:SetFrameLevel(10001) end
            if returnButton.SetSize then returnButton:SetSize(210, 28) end
            if returnButton.SetText then
                local label = Offhand.L and Offhand.L["MAP_RETURN_WINDOWED"]
                returnButton:SetText(label or "Return to Windowed Map")
            end
            if returnButton.SetScript then
                returnButton:SetScript("OnClick", function()
                    if InCombatLockdown() or not map.IsShown or not map:IsShown() then return end
                    if map.IsMaximized and map:IsMaximized() then
                        if map.HandleUserActionMinimizeSelf then
                            map:HandleUserActionMinimizeSelf()
                        elseif map.MaximizeMinimizeFrame and map.MaximizeMinimizeFrame.Minimize then
                            map.MaximizeMinimizeFrame:Minimize()
                        elseif map.Minimize then
                            map:Minimize()
                        end
                    end
                    if not map.IsMaximized or not map:IsMaximized() then
                        Canvas:ConfigureWorldMap()
                        RestoreWorkspacePosition(map)
                    end
                end)
                returnButton:SetScript("OnEnter", function(self)
                    if not GameTooltip then return end
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                    GameTooltip:SetText(Offhand.L and Offhand.L["MAP_RETURN_WINDOWED"])
                    if GameTooltip.AddLine then
                        GameTooltip:AddLine(Offhand.L and Offhand.L["MAP_RETURN_WINDOWED_DESC"], 1, 1, 1, true)
                    end
                    GameTooltip:Show()
                end)
                returnButton:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)
            end
            if returnButton.Hide then returnButton:Hide() end
        end

        local elapsedSinceUpdate = 1
        local function UpdateHandle(_, elapsed)
            local mapShown = Offhand.db and Offhand.db.enabled
                and map.IsShown and map:IsShown()
            QueueForeverWorldMapSettlement(map, state, mapShown and true or false)
            elapsedSinceUpdate = elapsedSinceUpdate + (tonumber(elapsed) or 0)
            if elapsedSinceUpdate < 0.10 then return end
            elapsedSinceUpdate = 0

            if ShouldYieldWorldMapToMoveAny(map) then
                SetPanelDragging(map, false)
                if handle.EnableMouse then handle:EnableMouse(false) end
                if handle.Hide then handle:Hide() end
                if returnButton and returnButton.Hide then returnButton:Hide() end
                return
            end

            local maximized = mapShown and map.IsMaximized and map:IsMaximized()
            if returnButton then
                if maximized and not InCombatLockdown() then
                    local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
                    if metrics and metrics.isSpanned and returnButton.ClearAllPoints and returnButton.SetPoint then
                        local centerX = (metrics.gameLeft + metrics.gameRight) / 2
                        local topY = metrics.gameTop - 20
                        returnButton:ClearAllPoints()
                        returnButton:SetPoint("TOP", UIParent, "BOTTOMLEFT", centerX, topY)
                    end
                    if returnButton.Show then returnButton:Show() end
                elseif returnButton.Hide then
                    returnButton:Hide()
                end
            end

            local usable = mapShown
                and map.GetLeft and map:GetLeft()
                and map.GetTop and map:GetTop()
            if not usable then
                if handle.EnableMouse then handle:EnableMouse(false) end
                if handle.SetSize then handle:SetSize(1, 1) end
                if handle.ClearAllPoints and handle.SetPoint then
                    handle:ClearAllPoints()
                    handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -100, -100)
                end
                return
            end

            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local mapScale = (map.GetEffectiveScale and map:GetEffectiveScale()) or parentScale
            local factor = parentScale > 0 and mapScale / parentScale or 1
            local left = map:GetLeft() * factor
            local top = map:GetTop() * factor
            local width = math.max(48, ((map.GetWidth and map:GetWidth()) or 610) * factor - 64)
            local height = math.max(18, 28 * factor)

            if handle.ClearAllPoints and handle.SetPoint then
                handle:ClearAllPoints()
                handle:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left + 8, top)
            end
            if handle.SetSize then handle:SetSize(width, height) end
            if handle.EnableMouse then handle:EnableMouse(true) end
        end

        if handle.SetScript then
            handle:SetScript("OnUpdate", UpdateHandle)
            handle:SetScript("OnDragStart", function()
                if ShouldYieldWorldMapToMoveAny(map) or InCombatLockdown()
                    or not Offhand.db or not Offhand.db.enabled then return end
                local started = pcall(function()
                    map:SetMovable(true)
                    map:SetClampedToScreen(false)
                    map:StartMoving()
                end)
                SetPanelDragging(map, started)
            end)
            handle:SetScript("OnDragStop", function()
                OnPanelDragStop(map)
                UpdateHandle(nil, 1)
            end)
        end
        if handle.Show then handle:Show() end
        UpdateHandle(nil, 1)
        return true
    end

    return {
        RepairUIPanelTransaction = RepairUIPanelTransaction,
        AttachDragHandle = AttachForeverWorldMapDragHandle,
    }
end

