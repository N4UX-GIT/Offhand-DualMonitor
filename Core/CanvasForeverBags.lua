-- Forever native backpack proxy, isolated from the item-button ancestry.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasForeverBags = Adapter

local function Near(a, b)
    return type(a) == "number" and math.abs(a - b) < 0.001
end

function Adapter.Install(Canvas, services)
    local WithWorkspace = assert(services.WithWorkspace, "Missing Forever bag service: WithWorkspace")
    local IsBackpackRoot = assert(services.IsBackpackRoot, "Missing Forever bag service: IsBackpackRoot")
    local GetNativeBackpackWorkspacePosition = assert(services.GetNativeBackpackWorkspacePosition, "Missing Forever bag service: GetNativeBackpackWorkspacePosition")
    local IsNativeBackpackTrackedOpen = assert(services.IsNativeBackpackTrackedOpen, "Missing Forever bag service: IsNativeBackpackTrackedOpen")
    local ClearNativeBackpackOpenState = assert(services.ClearNativeBackpackOpenState, "Missing Forever bag service: ClearNativeBackpackOpenState")
    local ClearOtherBackpackRootState = assert(services.ClearOtherBackpackRootState, "Missing Forever bag service: ClearOtherBackpackRootState")
    local SaveOpenWorkspacePanels = assert(services.SaveOpenWorkspacePanels, "Missing Forever bag service: SaveOpenWorkspacePanels")
    local SaveForeverPanelOwnership = assert(services.SaveForeverPanelOwnership, "Missing Forever bag service: SaveForeverPanelOwnership")
    local GetShownNativeBackpackRoot = assert(services.GetShownNativeBackpackRoot, "Missing Forever bag service: GetShownNativeBackpackRoot")
    local IsSpannedLayoutActive = assert(services.IsSpannedLayoutActive, "Missing Forever bag service: IsSpannedLayoutActive")
    local CanManagePanelsFromAddon = assert(services.CanManagePanelsFromAddon, "Missing Forever bag service: CanManagePanelsFromAddon")
    local IsForeverProfessionsPanel = assert(services.IsForeverProfessionsPanel, "Missing Forever bag service: IsForeverProfessionsPanel")
    local IsFrameOnWorkspace = assert(services.IsFrameOnWorkspace, "Missing Forever bag service: IsFrameOnWorkspace")
    local backpackRootNames = Offhand.CanvasBackpackState.RootNames

    -- Forever's native bag item buttons enter protected UseContainerItem paths.
    -- Keep all Offhand state and input handlers outside the ContainerFrame tree so
    -- moving the bag root does not also install addon code on an item-action
    -- ancestor.  The only native writes performed by this adapter are the root
    -- movement requested by a hardware drag and an out-of-combat anchor restore.
    local foreverNativeBagState = setmetatable({}, { __mode = "k" })
    local foreverNativeBagController

    local function GetForeverNativeBagSavedPosition(frame)
        if not Offhand.isForever or not Offhand.db or not frame or not frame.GetName then
            return nil, nil
        end
        local name = frame:GetName()
        if not IsBackpackRoot(name) then return nil, nil end
        local workspace = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[name]
        if type(workspace) ~= "table" then
            workspace = GetNativeBackpackWorkspacePosition()
        end
        if type(workspace) == "table" and workspace.x and workspace.y then
            return workspace, true
        end
        local mainhand = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions[name]
        if type(mainhand) == "table" and mainhand.x and mainhand.y then
            return mainhand, false
        end
        return nil, nil
    end

    local function GetForeverNativeBagTarget(frame, position, onWorkspace)
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned or not frame then return nil end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if frameScale <= 0 or parentScale <= 0 then return nil end
        local physicalScale = frameScale / parentScale
        local frameWidth = ((frame.GetWidth and frame:GetWidth()) or 0) * physicalScale
        local frameHeight = ((frame.GetHeight and frame:GetHeight()) or 0) * physicalScale
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        local targetX, targetY = position.x, position.y
        local minX, maxX, minY, maxY
        if onWorkspace then
            local savedWidth = tonumber(position.canvasWidth)
            local savedLeft = tonumber(position.canvasLeft) or 0
            if savedWidth and savedWidth > 0 and metrics.workspaceWidth > 0 then
                targetX = metrics.workspaceLeft
                    + (targetX - savedLeft) * metrics.workspaceWidth / savedWidth
            end
            local workspaceHeight = metrics.workspaceHeight or metrics.screenHeight
                or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local savedHeight = tonumber(position.canvasHeight)
            local savedBottom = tonumber(position.canvasBottom) or 0
            if savedHeight and savedHeight > 0 and workspaceHeight > 0 then
                targetY = metrics.workspaceBottom
                    + (targetY - savedBottom) * workspaceHeight / savedHeight
            end
            minX = metrics.workspaceLeft + 12
            maxX = math.max(minX, metrics.workspaceRight - frameWidth - 12)
            minY = metrics.workspaceBottom + frameHeight + 12
            maxY = math.max(minY, metrics.workspaceTop - 12)
        else
            minX = metrics.gameLeft + 12
            maxX = math.max(minX, metrics.gameRight - frameWidth - 12)
            minY = metrics.gameBottom + frameHeight + 12
            maxY = math.max(minY, metrics.gameTop - 12)
        end

        return math.max(minX, math.min(targetX, maxX)),
            math.max(minY, math.min(targetY, maxY)), frameScale, parentScale
    end

    -- This restore deliberately bypasses the generic panel lifecycle. It does not
    -- demodalize the bag, change UIPanel metadata, call SetUserPlaced, or run any
    -- Blizzard bag function. Keeping the mutation to the root anchor is the key
    -- isolation boundary for protected item-button clicks on Forever.
    local function RestoreForeverNativeBagRoot(frame)
        if not Offhand.isForever or (InCombatLockdown and InCombatLockdown())
            or not Offhand.db or not Offhand.db.enabled or not frame
            or not frame.IsShown or not frame:IsShown() then return false end
        local position, onWorkspace = GetForeverNativeBagSavedPosition(frame)
        if not position then return false end
        local x, y, frameScale, parentScale =
            GetForeverNativeBagTarget(frame, position, onWorkspace)
        if not x then return false end

        local actualLeft = frame.GetLeft and frame:GetLeft()
        local actualTop = frame.GetTop and frame:GetTop()
        if actualLeft and actualTop then
            actualLeft = actualLeft * frameScale / parentScale
            actualTop = actualTop * frameScale / parentScale
            if math.abs(actualLeft - x) < 0.75 and math.abs(actualTop - y) < 0.75 then
                return true
            end
        end

        local pointFactor = parentScale / frameScale
        return pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x * pointFactor, y * pointFactor)
        end)
    end

    local function SaveForeverNativeBagRoot(frame)
        if not Offhand.isForever or (InCombatLockdown and InCombatLockdown())
            or not Offhand.db or not Offhand.db.enabled or not frame
            or not frame.GetName then return false end
        local name = frame:GetName()
        if not IsBackpackRoot(name) then return false end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then return false end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if frameScale <= 0 or parentScale <= 0 then return false end
        local physicalScale = frameScale / parentScale
        local left = ((frame.GetLeft and frame:GetLeft()) or 0) * physicalScale
        local top = ((frame.GetTop and frame:GetTop()) or 0) * physicalScale
        local width = ((frame.GetWidth and frame:GetWidth()) or 192) * physicalScale
        local height = ((frame.GetHeight and frame:GetHeight()) or 192) * physicalScale
        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
        Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

        if IsFrameOnWorkspace(frame) then
            local x = math.max(metrics.workspaceLeft + 12,
                math.min(left, math.max(metrics.workspaceLeft + 12,
                    metrics.workspaceRight - width - 12)))
            local y = math.max(metrics.workspaceBottom + height + 12,
                math.min(top, math.max(metrics.workspaceBottom + height + 12,
                    metrics.workspaceTop - 12)))
            local position = {
                x = x, y = y,
                canvasWidth = metrics.workspaceWidth,
                canvasHeight = metrics.workspaceHeight or metrics.screenHeight,
                canvasLeft = metrics.workspaceLeft,
                canvasBottom = metrics.workspaceBottom,
            }
            ClearOtherBackpackRootState(name)
            Offhand.db.savedWorkspacePositions[name] = position
            Offhand.db.savedMainPositions[name] = nil
            Offhand.db.nativeBackpackWorkspacePosition = position
            Offhand.db.nativeBackpackWorkspaceOpen = frame.IsShown and frame:IsShown() and true or nil
            Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
            Offhand.db.openWorkspacePanels[name] = Offhand.db.nativeBackpackWorkspaceOpen
            if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveWorkspacePosition then
                Offhand.ForeverPersistence:SaveWorkspacePosition(
                    name, position, frame.GetWidth and frame:GetWidth(), frame.GetHeight and frame:GetHeight())
            end
            SaveOpenWorkspacePanels()
        else
            ClearOtherBackpackRootState(nil)
            -- Clear the mode-independent family snapshot as well as the per-frame
            -- records. Leaving this populated makes the observer interpret the
            -- Mainhand drop as a combined/individual mode switch and immediately
            -- restore the previous workspace anchor.
            Offhand.db.nativeBackpackWorkspacePosition = nil
            Offhand.db.nativeBackpackWorkspaceOpen = nil
            local x = math.max(metrics.gameLeft + 12,
                math.min(left, math.max(metrics.gameLeft + 12, metrics.gameRight - width - 12)))
            local y = math.max(metrics.gameBottom + height + 12,
                math.min(top, math.max(metrics.gameBottom + height + 12, metrics.gameTop - 12)))
            Offhand.db.savedMainPositions[name] = { x = x, y = y }
        end
        SaveForeverPanelOwnership()
        return RestoreForeverNativeBagRoot(frame)
    end

    local function PositionForeverNativeBagHandle(frame, state)
        local handle = state and state.handle
        if not handle or not frame or not frame.GetLeft or not frame.GetTop then return false end
        local left, top = frame:GetLeft(), frame:GetTop()
        if not left or not top then return false end
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if frameScale <= 0 or parentScale <= 0 then return false end
        local factor = frameScale / parentScale
        local width = math.max(40, (((frame.GetWidth and frame:GetWidth()) or 180) - 96) * factor)
        local x, y, height = (left + 44) * factor, (top - 2) * factor, 24 * factor
        -- This is our UIParent-owned grip, not the protected bag root. Compare
        -- actual geometry so a displaced grip still repairs in the first frame,
        -- without reapplying identical anchors and size every rendered frame.
        local samePoint = false
        if handle.GetNumPoints and handle.GetPoint and handle:GetNumPoints() == 1 then
            local point, relative, relativePoint, currentX, currentY = handle:GetPoint(1)
            samePoint = point == "TOPLEFT" and relative == UIParent and relativePoint == "BOTTOMLEFT"
                and Near(currentX, x) and Near(currentY, y)
        end
        if not samePoint then
            if handle.ClearAllPoints then handle:ClearAllPoints() end
            if handle.SetPoint then handle:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) end
        end
        if handle.SetSize and (not handle.GetWidth or not handle.GetHeight
            or not Near(handle:GetWidth(), width) or not Near(handle:GetHeight(), height)) then
            handle:SetSize(width, height)
        end
        return true
    end

    local function EnsureForeverNativeBagHandle(frame)
        if not frame or not CreateFrame or not UIParent then return nil end
        local state = foreverNativeBagState[frame]
        if not state then
            state = {}
            foreverNativeBagState[frame] = state
        end
        if state.handle then return state.handle, state end

        -- UIParent, not the bag, owns this frame. No anchor on either side refers
        -- to a ContainerFrame, so the native item-button ancestry stays untouched.
        local handle = CreateFrame("Frame", nil, UIParent)
        if not handle then return nil end
        state.handle = handle
        if handle.SetFrameStrata then handle:SetFrameStrata("TOOLTIP") end
        if handle.SetFrameLevel then handle:SetFrameLevel(10000) end
        if handle.Hide then handle:Hide() end
        if handle.EnableMouse then handle:EnableMouse(true) end
        if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
        if handle.SetScript then
            handle:SetScript("OnDragStart", function()
                if (InCombatLockdown and InCombatLockdown()) or not Offhand.db
                    or not Offhand.db.enabled or not frame.IsShown or not frame:IsShown() then return end
                local started = pcall(function()
                    frame:SetMovable(true)
                    frame:StartMoving()
                end)
                state.dragging = started and true or false
            end)
            handle:SetScript("OnDragStop", function()
                if not state.dragging then return end
                pcall(function() frame:StopMovingOrSizing() end)
                state.dragging = false
                SaveForeverNativeBagRoot(frame)
            end)
        end
        return handle, state
    end

    local function IsForeverNativeBagCloseButtonFocused()
        local focusList
        if GetMouseFoci then
            local ok, result = pcall(GetMouseFoci)
            if ok and type(result) == "table" then focusList = result end
        elseif GetMouseFocus then
            local ok, result = pcall(GetMouseFocus)
            if ok and result then focusList = { result } end
        end
        if not focusList then return false end
        for _, frameName in ipairs(backpackRootNames) do
            local bag = _G[frameName]
            local closeButton = bag and (bag.CloseButton or _G[frameName .. "CloseButton"])
            if closeButton then
                for _, focus in ipairs(focusList) do
                    if focus == closeButton then return true end
                end
            end
        end
        return false
    end

    -- Secure post-hooks observe only the global close/toggle transaction. They do
    -- not replace a Blizzard function, call a bag API from its native stack, or
    -- attach anything to ContainerFrame. Deferring the decision until OnUpdate
    -- allows ToggleAllBags/ToggleBag to label B-key closes as explicit after their
    -- nested CloseAllBags call has returned. Forever's Escape binding enters
    -- ToggleGameMenu, whose first CloseAllBags currently consumes the toggle; its
    -- post-hook labels that distinct transaction for a deferred menu repair.
    local function InstallForeverNativeBagCloseObservers()
        if not Offhand.isForever or not hooksecurefunc then return end
        local function ObserveClose()
            if Canvas._foreverNativeBagRestoreInProgress then return end
            Canvas._foreverNativeBagCloseObserved = true
            if IsForeverNativeBagCloseButtonFocused() then
                Canvas._foreverNativeBagExplicitCloseObserved = true
            end
        end
        local function ObserveExplicitToggle()
            if Canvas._foreverNativeBagRestoreInProgress then return end
            -- Forever can hide the native root directly from ToggleAllBags without
            -- routing through either CloseAllBags observer. The hardware bag toggle
            -- is therefore authoritative on its own. The controller receives the
            -- higher-level Game Menu/Settings markers in the same event turn and
            -- excludes those native navigation transactions before clearing state.
            Canvas._foreverNativeBagExplicitCloseObserved = true
        end
        if CloseAllBags and not Canvas._foreverNativeCloseAllBagsObserved then
            Canvas._foreverNativeCloseAllBagsObserved = true
            hooksecurefunc("CloseAllBags", ObserveClose)
        end
        if C_Container and C_Container.CloseAllBags
            and not Canvas._foreverNativeContainerCloseAllBagsObserved then
            Canvas._foreverNativeContainerCloseAllBagsObserved = true
            hooksecurefunc(C_Container, "CloseAllBags", ObserveClose)
        end
        if ToggleAllBags and not Canvas._foreverNativeToggleAllBagsObserved then
            Canvas._foreverNativeToggleAllBagsObserved = true
            hooksecurefunc("ToggleAllBags", ObserveExplicitToggle)
        end
        if ToggleBackpack and not Canvas._foreverNativeToggleBackpackObserved then
            Canvas._foreverNativeToggleBackpackObserved = true
            hooksecurefunc("ToggleBackpack", ObserveExplicitToggle)
        end
        if ToggleBag and not Canvas._foreverNativeToggleBagObserved then
            Canvas._foreverNativeToggleBagObserved = true
            hooksecurefunc("ToggleBag", ObserveExplicitToggle)
        end
        if C_Container and type(C_Container.ToggleBackpack) == "function"
            and not Canvas._foreverNativeContainerToggleBackpackObserved then
            Canvas._foreverNativeContainerToggleBackpackObserved = true
            hooksecurefunc(C_Container, "ToggleBackpack", ObserveExplicitToggle)
        end
        if ToggleGameMenu and not Canvas._foreverNativeToggleGameMenuHooked then
            Canvas._foreverNativeToggleGameMenuHooked = true
            hooksecurefunc("ToggleGameMenu", function()
                Canvas._foreverNativeGameMenuToggleObserved = true
            end)
        end
    end

    -- Forever can hide a ContainerFrame while retaining Blizzard's logical-open
    -- bag state. OpenAllBags then declines to recreate the root. Normalize that
    -- mismatch only through Blizzard's public bag APIs: the toggle either opens
    -- the missing root or clears the stale logical state, after which OpenAllBags
    -- can initialize the pooled item buttons normally. Never call frame:Show().
    local function OpenForeverNativeBackpackThroughBlizzard()
        local shownBag = GetShownNativeBackpackRoot()
        if shownBag then return shownBag end
        if not CanManagePanelsFromAddon() then return nil end

        Canvas._foreverNativeBagRestoreInProgress = true
        if OpenAllBags then
            pcall(OpenAllBags)
        elseif ToggleAllBags then
            pcall(ToggleAllBags)
        end
        shownBag = GetShownNativeBackpackRoot()
        if not shownBag and ToggleAllBags then
            pcall(ToggleAllBags)
            shownBag = GetShownNativeBackpackRoot()
            if not shownBag and OpenAllBags then
                pcall(OpenAllBags)
                shownBag = GetShownNativeBackpackRoot()
            end
        end
        Canvas._foreverNativeBagRestoreInProgress = nil
        return shownBag
    end

    -- These panels can directly hide native bags after leaving the Game Menu.
    -- Polling visibility from the addon-owned controller avoids attaching scripts
    -- or state to Forever's protected Edit Mode and system-panel trees.
    local foreverNativeBagPreservingPanelNames = {
        "SettingsPanel",
        "InterfaceOptionsFrame",
        "VideoOptionsFrame",
        "AudioOptionsFrame",
        "AddonList",
        "EditModeManagerFrame",
    }

    local foreverSystemPanelNames = {
        "SettingsPanel",
        "InterfaceOptionsFrame",
        "VideoOptionsFrame",
        "AudioOptionsFrame",
    }

    local function IsForeverNativeBagPreservingPanelShown()
        for _, name in ipairs(foreverNativeBagPreservingPanelNames) do
            local panel = _G[name]
            if panel and panel.IsShown and panel:IsShown() then return true end
        end
        if IsOptionFrameOpen then
            local ok, shown = pcall(IsOptionFrameOpen)
            if ok and shown then return true end
        end
        -- Professions temporarily hides Blizzard's native backpack while it takes
        -- the UIPanel slot. That is a panel transition, not an explicit bag close.
        -- Discover the load-on-demand frame from the native panel registry instead
        -- of depending on one client-build-specific Professions root name.
        if UIPanelWindows then
            for name in pairs(UIPanelWindows) do
                local panel = _G[name]
                if panel and IsForeverProfessionsPanel(panel, name)
                    and panel.IsShown and panel:IsShown() then
                    return true
                end
            end
        end
        return false
    end

    -- Third-party backpack adapters need the same transition classification as
    -- the native backpack controller, but must remain outside Blizzard and addon
    -- frame trees. Expose read-only predicates so BagPersistence can defer its own
    -- visibility sample and use the replacement addon's public root manager.
    function Canvas:IsForeverBagPreservingPanel(frame)
        if not Offhand.isForever or not frame then return false end
        local name = frame.GetName and frame:GetName()
        if not name then return false end
        for _, panelName in ipairs(foreverNativeBagPreservingPanelNames) do
            if name == panelName then return true end
        end
        return IsForeverProfessionsPanel(frame, name)
    end

    function Canvas:IsForeverBagPreservingPanelShown()
        return IsForeverNativeBagPreservingPanelShown()
    end

    -- Forever's Options button can close the backpack through ToggleAllBags before
    -- the Settings panel becomes visible. That native toggle is indistinguishable
    -- from the B binding at the bag-function boundary, so observe the higher-level
    -- Settings request instead. Secure post-hooks leave Blizzard's functions and
    -- panel tree unmodified while giving the external controller one frame to
    -- classify the close as a system-panel transition.
    local function InstallForeverOptionsOpeningObservers()
        if not hooksecurefunc then return end
        local function ObserveOptionsOpening()
            Canvas._foreverOptionsOpeningObserved = true
            local function SettleSystemPanel()
                if Canvas.PlaceShownSystemPanelsOnMainhand then
                    Canvas:PlaceShownSystemPanelsOnMainhand()
                end
            end
            -- Run outside Blizzard's gamepad-navigation call chain. This moves only
            -- the unprotected settings root and never annotates or hooks that frame.
            if C_Timer and C_Timer.After then
                C_Timer.After(0, SettleSystemPanel)
                C_Timer.After(0.10, SettleSystemPanel)
            else
                SettleSystemPanel()
            end
        end
        if Settings and type(Settings.OpenToCategory) == "function"
            and not Canvas._foreverSettingsOpenToCategoryObserved then
            Canvas._foreverSettingsOpenToCategoryObserved = true
            hooksecurefunc(Settings, "OpenToCategory", ObserveOptionsOpening)
        end
        if C_SettingsUtil and type(C_SettingsUtil.OpenSettingsPanel) == "function"
            and not Canvas._foreverOpenSettingsPanelObserved then
            Canvas._foreverOpenSettingsPanelObserved = true
            hooksecurefunc(C_SettingsUtil, "OpenSettingsPanel", ObserveOptionsOpening)
        end
        if type(InterfaceOptionsFrame_OpenToCategory) == "function"
            and not Canvas._foreverLegacyOptionsOpeningObserved then
            Canvas._foreverLegacyOptionsOpeningObserved = true
            hooksecurefunc("InterfaceOptionsFrame_OpenToCategory", ObserveOptionsOpening)
        end
    end

    function Canvas:GetForeverNativeBagDiagnostics()
        if not Offhand.isForever then return nil end
        local roots = {}
        for _, frameName in ipairs(backpackRootNames) do
            local frame = _G[frameName]
            if frame then
                roots[#roots + 1] = string.format("%s=%s", frameName,
                    frame.IsShown and frame:IsShown() and "shown" or "hidden")
            end
        end
        local optionOpen = false
        if IsOptionFrameOpen then
            local ok, value = pcall(IsOptionFrameOpen)
            optionOpen = ok and value and true or false
        end
        local status = string.format(
            "tracked=%s saved=%s menu=%s option=%s panel=%s combat=%s input=%s roots=%s",
            IsNativeBackpackTrackedOpen() and "1" or "0",
            GetNativeBackpackWorkspacePosition() and "1" or "0",
            GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() and "1" or "0",
            optionOpen and "1" or "0",
            IsForeverNativeBagPreservingPanelShown() and "1" or "0",
            InCombatLockdown and InCombatLockdown() and "1" or "0",
            Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() and "1" or "0",
            #roots > 0 and table.concat(roots, ",") or "none")
        return status
    end

    -- A B/X close can be followed immediately by /reload, before the proxy's next
    -- OnUpdate has converted the observed native close into persisted state. Honor
    -- that already-completed hardware close at the teardown boundary. We cannot use
    -- raw visibility alone here because Forever may hide open panels before addons
    -- receive PLAYER_LEAVING_WORLD/PLAYER_LOGOUT.
    function Canvas:FinalizeForeverNativeBagStateForTransition()
        if not Offhand.isForever or not Offhand.db then return false end
        local shownRoot = GetShownNativeBackpackRoot()
        local explicitClose = Canvas._foreverNativeBagExplicitCloseObserved == true
        for frame, state in pairs(foreverNativeBagState) do
            state.pendingOpenRestore = nil
            state.pendingOpenAttempts = nil
            state.pendingGameMenuToggle = nil
            state.wasShown = false
        end
        -- The lifecycle handler persists the complete panel snapshot immediately
        -- after this reconciliation. Do not write a partial snapshot here, because
        -- single-screen recovery deliberately preserves the last spanned state.
        Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
        for _, rootName in ipairs(backpackRootNames) do
            Offhand.db.openWorkspacePanels[rootName] = nil
        end
        if shownRoot and GetNativeBackpackWorkspacePosition() then
            local name = shownRoot.GetName and shownRoot:GetName()
            Offhand.db.nativeBackpackWorkspaceOpen = true
            if name then Offhand.db.openWorkspacePanels[name] = true end
        elseif explicitClose then
            Offhand.db.nativeBackpackWorkspaceOpen = nil
        end
        return true
    end

    function Canvas:EnableForeverNativeBagProxy()
        if not Offhand.isForever or not CreateFrame or not UIParent then return false end
        InstallForeverNativeBagCloseObservers()
        InstallForeverOptionsOpeningObservers()
        if foreverNativeBagController then return true end
        foreverNativeBagController = CreateFrame("Frame", "OffhandForeverNativeBagController", UIParent)
        if not foreverNativeBagController or not foreverNativeBagController.SetScript then return false end
        local lastGameMenuShown = GameMenuFrame and GameMenuFrame.IsShown
            and GameMenuFrame:IsShown() or false
        local lastPreservingPanelShown = IsForeverNativeBagPreservingPanelShown()
        foreverNativeBagController:SetScript("OnUpdate", function(_, elapsed)
            local enabled = Offhand.db and Offhand.db.enabled
                and IsSpannedLayoutActive()
                and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon())
            local nativeGamepad = Offhand.Mainhand
                and type(Offhand.Mainhand.IsNativeGamepadInterface) == "function"
                and Offhand.Mainhand:IsNativeGamepadInterface()
            if nativeGamepad then
                -- Mainhand's Gamepad adapter owns the root-only placement and its
                -- independent drag grips in this mode. Retire the older backpack
                -- proxy without interpreting Blizzard's visibility as a close.
                for _, state in pairs(foreverNativeBagState) do
                    if state.handle and state.handle.Hide then state.handle:Hide() end
                    state.dragging = false
                end
                Canvas._foreverNativeBagCloseObserved = nil
                Canvas._foreverNativeBagExplicitCloseObserved = nil
                Canvas._foreverNativeGameMenuToggleObserved = nil
                Canvas._foreverOptionsOpeningObserved = nil
                return
            end
            local inCombat = InCombatLockdown and InCombatLockdown()
            local gameMenuShown = GameMenuFrame and GameMenuFrame.IsShown
                and GameMenuFrame:IsShown() or false
            local gameMenuChanged = gameMenuShown ~= lastGameMenuShown
            local closeObserved = Canvas._foreverNativeBagCloseObserved == true
            local explicitCloseObserved = Canvas._foreverNativeBagExplicitCloseObserved == true
            local gameMenuToggleObserved = Canvas._foreverNativeGameMenuToggleObserved == true
            local optionsOpeningObserved = Canvas._foreverOptionsOpeningObserved == true
            local inputReserved = Offhand.IsBlizzardInputReserved
                and Offhand:IsBlizzardInputReserved() or false
            local preservingPanelShown = IsForeverNativeBagPreservingPanelShown()
            local preservingPanelChanged = preservingPanelShown ~= lastPreservingPanelShown
            if preservingPanelShown and preservingPanelChanged
                and Canvas.PlaceShownSystemPanelsOnMainhand then
                Canvas:PlaceShownSystemPanelsOnMainhand()
            end
            local leavingGameMenu = lastGameMenuShown and not gameMenuShown
            -- A direct ToggleGameMenu observation means Escape dismissed the menu;
            -- no delayed system-panel cleanup is coming, so do not hold the bag in
            -- the navigation grace window. A menu button that routes into Settings,
            -- AddOns, or Edit Mode closes the menu without that marker and retains
            -- the short grace until the destination panel becomes observable.
            local leavingGameMenuForPanel = leavingGameMenu and not gameMenuToggleObserved
            local panelTransitionActive = preservingPanelShown
                or preservingPanelChanged or optionsOpeningObserved
                or leavingGameMenuForPanel
            for _, frameName in ipairs(backpackRootNames) do
                local frame = _G[frameName]
                if frame then
                    local handle, state = EnsureForeverNativeBagHandle(frame)
                    local shown = enabled and frame.IsShown and frame:IsShown()
                    local trackedWorkspaceBag = enabled
                        and GetNativeBackpackWorkspacePosition()
                        and IsNativeBackpackTrackedOpen()

                    if not shown and state.wasShown and explicitCloseObserved
                        and not optionsOpeningObserved and not gameMenuToggleObserved
                        and not leavingGameMenuForPanel then
                        state.pendingOpenRestore = nil
                        state.pendingOpenAttempts = nil
                        state.pendingGameMenuToggle = nil
                        ClearNativeBackpackOpenState()
                        trackedWorkspaceBag = false
                    end

                    if not shown and trackedWorkspaceBag
                        and ((state.wasShown and closeObserved and not explicitCloseObserved)
                            or (state.wasShown and gameMenuChanged)
                            or panelTransitionActive) then
                        state.pendingOpenRestore = true
                        state.pendingOpenAttempts = 0
                        if gameMenuToggleObserved and not gameMenuChanged then
                            state.pendingGameMenuToggle = true
                        end
                    end
                    if state.pendingOpenRestore and not CanManagePanelsFromAddon() then
                        -- Let the Gamepad UI close stand. The saved position remains
                        -- available when the player opens the bag again.
                        state.pendingOpenRestore = nil
                        state.pendingOpenAttempts = nil
                        state.pendingGameMenuToggle = nil
                    end
                    if not shown and state.pendingOpenRestore and not inCombat
                        and not inputReserved then
                        state.pendingOpenAttempts = (state.pendingOpenAttempts or 0) + 1
                        if state.pendingGameMenuToggle then
                            state.pendingGameMenuToggle = nil
                            if gameMenuShown then
                                if GameMenuFrame and GameMenuFrame.Hide then GameMenuFrame:Hide() end
                            elseif GameMenuFrame and GameMenuFrame.Show then
                                GameMenuFrame:Show()
                            end
                            gameMenuShown = GameMenuFrame and GameMenuFrame.IsShown
                                and GameMenuFrame:IsShown() or false
                        end
                        OpenForeverNativeBackpackThroughBlizzard()
                        shown = enabled and frame.IsShown and frame:IsShown()
                        local restoredRoot = GetShownNativeBackpackRoot()
                        if restoredRoot then
                            state.pendingOpenRestore = nil
                            state.pendingOpenAttempts = nil
                            if restoredRoot ~= frame then state.wasShown = false end
                        elseif state.pendingOpenAttempts >= 5 then
                            state.pendingOpenRestore = nil
                            state.pendingOpenAttempts = nil
                            state.pendingGameMenuToggle = nil
                        end
                    end
                    if shown and not inCombat then
                        state.nativeInitialized = true
                        local exactPosition = Offhand.db.savedWorkspacePositions
                            and Offhand.db.savedWorkspacePositions[frameName]
                        if GetNativeBackpackWorkspacePosition()
                            and (not state.wasShown or not exactPosition) then
                            Canvas:PrepareNativeBackpackFrame(frame)
                        end
                        if not state.dragging then RestoreForeverNativeBagRoot(frame) end
                        PositionForeverNativeBagHandle(frame, state)
                        if handle and handle.Show then handle:Show() end
                        if not state.wasShown or not IsNativeBackpackTrackedOpen() then
                            Canvas:SetWorkspacePanelOpen(frame, true)
                        end
                        state.wasShown = true
                    else
                        if handle and handle.Hide then handle:Hide() end
                        local systemPanelTransition = Canvas._systemPanelOpeningToken ~= nil
                            or panelTransitionActive
                        if state.wasShown and not shown and not state.dragging
                            and not inCombat and not state.pendingOpenRestore
                            and not systemPanelTransition then
                            ClearNativeBackpackOpenState()
                        end
                        if not state.pendingOpenRestore then
                            state.wasShown = shown and true or false
                        end
                    end
                end
            end
            Canvas._foreverNativeBagCloseObserved = nil
            Canvas._foreverNativeBagExplicitCloseObserved = nil
            Canvas._foreverNativeGameMenuToggleObserved = nil
            Canvas._foreverOptionsOpeningObserved = nil
            lastGameMenuShown = gameMenuShown
            lastPreservingPanelShown = preservingPanelShown
        end)
        return true
    end

    return {
        OpenNativeBackpack = OpenForeverNativeBackpackThroughBlizzard,
        IsPreservingPanelShown = IsForeverNativeBagPreservingPanelShown,
        SystemPanelNames = foreverSystemPanelNames,
        InstallOptionsOpeningObservers = InstallForeverOptionsOpeningObservers,
    }
end

