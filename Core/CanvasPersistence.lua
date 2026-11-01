--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasPersistence.lua: Saved Canvas position normalization
--]]

local _, Offhand = ...

local Persistence = {}
Offhand.CanvasPersistence = Persistence

-- Observe outside the protected frame tree: native toggles and skinned close
-- buttons do not all pass through our close-button observer. A deferred check
-- ignores transient minimize hide/show and preserves world-transition snapshots.
function Persistence.InstallPlayerSpellsCloseObserver(Canvas)
    if not Offhand.isRetail or Offhand.isForever or Canvas._playerSpellsCloseObserver
        or not EventRegistry or not EventRegistry.RegisterCallback
        or not C_Timer or not C_Timer.After then return false end
    EventRegistry:RegisterCallback("PlayerSpellsFrame.CloseFrame", function()
        if Canvas._playerSpellsCloseCheckPending then return end
        Canvas._playerSpellsCloseCheckPending = true
        C_Timer.After(0, function()
            Canvas._playerSpellsCloseCheckPending = nil
            if Offhand._openPanelsCapturedForTransition or not Offhand.db
                or not Offhand.db.enabled then return end
            local frame = _G.PlayerSpellsFrame
            if not frame or (frame.IsForbidden and frame:IsForbidden())
                or not frame.IsShown or frame:IsShown() then return end
            Canvas:SetWorkspacePanelOpen("PlayerSpellsFrame", false)
        end)
    end, Canvas)
    Canvas._playerSpellsCloseObserver = true
    return true
end

-- PlayerSpells defaults to Talents when shown without a selected tab. Keep the
-- semantic choice outside Blizzard's frame tree and resolve its IDs per load.
local playerSpellsScales = setmetatable({}, { __mode = "k" })
local playerSpellsTabs = { spellbook = "spellBookTabID", talents = "talentTabID", specialization = "specTabID" }
local function IsRetailPlayerSpells(frame)
    return Offhand.isRetail and not Offhand.isForever and frame and frame == _G.PlayerSpellsFrame
        and not (frame.IsForbidden and frame:IsForbidden())
end

function Persistence.CapturePlayerSpellsTab(frame)
    local db = Offhand.db
    if not IsRetailPlayerSpells(frame) or not db or not db.enabled
        or not db.savedWorkspacePositions or not db.savedWorkspacePositions.PlayerSpellsFrame
        or not frame.GetTab or not frame.IsShown or not frame:IsShown()
        or (frame.IsInspecting and frame:IsInspecting()) then return end
    local tab = frame:GetTab()
    for key, field in pairs(playerSpellsTabs) do
        if tab and tab == frame[field] then db.workspacePlayerSpellsTab = key; return end
    end
end

function Persistence.RestorePlayerSpellsTab(frame)
    local db = Offhand.db
    if not IsRetailPlayerSpells(frame) or InCombatLockdown() or not db or not db.enabled
        or not db.savedWorkspacePositions or not db.savedWorkspacePositions.PlayerSpellsFrame
        or not frame.SetTab or not frame.IsTabAvailable
        or (frame.IsInspecting and frame:IsInspecting()) then return false end
    local field = playerSpellsTabs[db.workspacePlayerSpellsTab]
    local tab = field and frame[field]
    if not tab or not frame:IsTabAvailable(tab) then return false end
    -- Run before Show: UpdateTabs will retain this available tab instead of
    -- choosing Talents. Do not replay it over an already-open user selection.
    if frame.IsShown and frame:IsShown() then return false end
    frame:SetTab(tab)
    return true
end

function Persistence.FitPlayerSpellsToWorkspace(frame, metrics, ownsWorkspace)
    if not IsRetailPlayerSpells(frame) or InCombatLockdown()
        or not frame.GetScale or not frame.SetScale or not frame.GetEffectiveScale then return end
    local state = playerSpellsScales[frame]
    local scale = frame:GetScale()
    if not scale or scale <= 0 then return end
    if state and math.abs(scale - state.applied) > 0.0001 then
        -- Another owner changed scale. Never restore our old value over it.
        playerSpellsScales[frame] = nil
        return
    end
    if not ownsWorkspace or not metrics or not metrics.isSpanned then
        if state then
            frame:SetScale(state.original)
            playerSpellsScales[frame] = nil
        end
        return
    end
    local parentScale = UIParent:GetEffectiveScale()
    local effective = frame:GetEffectiveScale()
    local width, height = frame:GetWidth(), frame:GetHeight()
    if parentScale <= 0 or effective <= 0 or width <= 0 or height <= 0 then return end
    local original = state and state.original or scale
    local factor = effective / parentScale / scale
    local availableWidth = metrics.workspaceRight - metrics.workspaceLeft - 24
    local availableHeight = metrics.workspaceTop - metrics.workspaceBottom - 24
    if availableWidth <= 0 or availableHeight <= 0 then return end
    local desired = math.min(original, availableWidth / (width * factor), availableHeight / (height * factor))
    if math.abs(scale - desired) > 0.0001 then frame:SetScale(desired) end
    if desired < original then
        playerSpellsScales[frame] = { original = original, applied = desired }
    else
        playerSpellsScales[frame] = nil
    end
end

function Persistence.InstallDrag(Canvas, services)
    local ShouldYieldFrameToClassicUIForever = services.ShouldYieldFrameToClassicUIForever
    local ShouldYieldWorldMapToMoveAny = services.ShouldYieldWorldMapToMoveAny
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsExperimentalForeverProfessionsMovementEnabled = services.IsExperimentalForeverProfessionsMovementEnabled
    local IsPersistentForeverProfessionsPanelName = services.IsPersistentForeverProfessionsPanelName
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local SetPanelDragging = services.SetPanelDragging
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local WithWorkspace = services.WithWorkspace
    local DemodalizePanel = services.DemodalizePanel
    local EvictWorkspacePanelSlot = services.EvictWorkspacePanelSlot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local UnregisterSpecialFrame = services.UnregisterSpecialFrame
    local HasCustomChatAddon = services.HasCustomChatAddon
    local ClearTrackedChatState = services.ClearTrackedChatState
    local RelinquishDockedChatPosition = services.RelinquishDockedChatPosition
    local ShouldManageBlizzardChatEditBox = services.ShouldManageBlizzardChatEditBox
    local IsRetailEditModePrimaryChat = services.IsRetailEditModePrimaryChat
    local SaveForeverPanelOwnership = services.SaveForeverPanelOwnership
    local IsBackpackRoot = services.IsBackpackRoot
    local ClearOtherBackpackRootState = services.ClearOtherBackpackRootState
    local RemodalizePanel = services.RemodalizePanel
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local OnPanelDragStop
    OnPanelDragStop = function(frame)
        if not frame then return end
        if Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return end
        -- End a gesture we started before any policy early return. A native
        -- panel can change protection/ownership during the gesture; skipping
        -- StopMoving in that case leaves it following the cursor indefinitely.
        if frame._OffhandDragging and not InCombatLockdown() and frame.StopMovingOrSizing then
            pcall(frame.StopMovingOrSizing, frame)
        end
        if IsWorldMapMaximized(frame) then
            SetPanelDragging(frame, false)
            return
        end
        if ShouldYieldFrameToClassicUIForever(frame) then
            SetPanelDragging(frame, false)
            return
        end
        if ShouldYieldWorldMapToMoveAny(frame) then
            SetPanelDragging(frame, false)
            return
        end
        if InCombatLockdown() then SetPanelDragging(frame, false); return end
        local dragName = frame.GetName and frame:GetName()
        if dragName and dragName:match("^ChatFrame%d+$") and HasCustomChatAddon() then
            ClearTrackedChatState(dragName)
            SetPanelDragging(frame, false)
            return
        end
        if RelinquishDockedChatPosition(frame, dragName) then
            SetPanelDragging(frame, false)
            return
        end
        local nativeContainerDrag = dragName and dragName:match("^ContainerFrame")
            and frame._OffhandDragging == true
        if IsForeverEditModeFrame(frame, dragName)
            or (IsUnsafeForPanelMutation(frame, dragName) and not nativeContainerDrag) then
            SetPanelDragging(frame, false)
            return
        end
        if dragName and dragName:match("^ChatFrame%d+$") then SetPanelDragging(frame, true) end
        if frame.StopMovingOrSizing then
            pcall(function() frame:StopMovingOrSizing() end)
        end
        local name = frame.GetName and frame:GetName()
        local wasShown = not frame.IsShown or frame:IsShown()

        -- Capture the hardware drag result before changing Blizzard's user-placed
        -- state. Some clients immediately restore the native anchor when
        -- SetUserPlaced(false) runs, which previously made a valid workspace drop
        -- look like a Mainhand-centered drop on every monitor orientation.
        local dragFrameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local dragParentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local dragScaleFactor = dragFrameScale / dragParentScale
        local dragLeftRaw = frame.GetLeft and frame:GetLeft() or 0
        local dragTopRaw = frame.GetTop and frame:GetTop() or 0
        local dragLeftInParent = dragLeftRaw * dragScaleFactor
        local dragTopInParent = dragTopRaw * dragScaleFactor
        local droppedOnWorkspace = IsFrameOnWorkspace(frame)

        if name and string.match(name, "^ChatFrame") then
            
        elseif not Offhand.isForever and not IsBackpackRoot(name) then
            -- Forever should retain Blizzard's user-placed state. Clearing it can
            -- synchronously return the frame to its native center anchor.
            pcall(function() frame:SetUserPlaced(false) end)
        end

        if not Offhand.db or not Offhand.db.enabled then
            SetPanelDragging(frame, false)
            return
        end
        local name = frame:GetName()
        if not name then
            SetPanelDragging(frame, false)
            return
        end
        local restrictedProfessionsMovement = IsForeverProfessionsPanel(frame, name)
            and IsExperimentalForeverProfessionsMovementEnabled()

        Persistence.EnsurePositionTables(Offhand.db)

        local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not m then
            SetPanelDragging(frame, false)
            return
        end

        local onDeck = droppedOnWorkspace

        if IsRetailEditModePrimaryChat(frame) and not onDeck then
            -- Mainhand ChatFrame1 belongs to Retail Edit Mode. Remove legacy
            -- Offhand coordinates without writing another anchor over Blizzard's.
            Offhand.db.savedWorkspacePositions[name] = nil
            Offhand.db.savedMainPositions[name] = nil
            Canvas:SetWorkspacePanelOpen(name, false)
            if Offhand.ForeverPersistence then Offhand.ForeverPersistence:ClearPosition(name) end
            SaveForeverPanelOwnership()
            SetPanelDragging(frame, false)
            return
        end

        if onDeck then
            if frame == WorldMapFrame then
                Offhand.db.savedMainPositions.WorldMapFrame = nil
                Canvas:ConfigureWorldMap()
            end

            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local scaleFactor = frameScale / parentScale
            local xInParent = dragLeftInParent
            local yInParent = dragTopInParent
            local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
            local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
            local fallbackHeight = (UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local position = Persistence.CreateWorkspacePosition(
                m, xInParent, yInParent, frameWidth, frameHeight,
                string.match(name, "^ChatFrame") ~= nil, fallbackHeight
            )
            local clampedX, clampedY = position.x, position.y

            Offhand.db.savedWorkspacePositions[name] = position
            if IsBackpackRoot(name) then
                Offhand.db.nativeBackpackWorkspacePosition = Offhand.db.savedWorkspacePositions[name]
                ClearOtherBackpackRootState(name)
            end
            if Offhand.db.savedMainPositions then
                Offhand.db.savedMainPositions[name] = nil
            end

            local rawW, rawH = frame:GetWidth(), frame:GetHeight()
            if Offhand.ForeverPersistence then
                Offhand.ForeverPersistence:SaveWorkspacePosition(
                    name, Offhand.db.savedWorkspacePositions[name], rawW, rawH
                )
            end
            frame:ClearAllPoints()
            local factor = parentScale / frameScale
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
            
            if wasShown and not restrictedProfessionsMovement
                and (Offhand.db.independentWorkspacePanels or frame == WorldMapFrame) then
                -- Escape closes active UIPanel slots even when UISpecialFrames no
                -- longer contains this workspace panel.
                EvictWorkspacePanelSlot(frame)
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                if frame.IsShown and not frame:IsShown() and frame.Show then frame:Show() end
                if not restrictedProfessionsMovement then DemodalizePanel(frame) end
            end

            if wasShown and string.match(name, "^ContainerFrame") then
                if name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" then
                    if Offhand.db.savedWorkspacePositions then
                        for i = 2, 13 do
                            Offhand.db.savedWorkspacePositions["ContainerFrame" .. i] = nil
                            local bf = _G["ContainerFrame" .. i]
                            if bf then pcall(function() bf:SetUserPlaced(false) end) end
                        end
                    end
                end
                if not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                    if Offhand.HUD and Offhand.HUD.LayoutBags then
                        Offhand.HUD:LayoutBags()
                    end
                end
            elseif string.match(name, "^ChatFrame") then
                if ChatFrame1EditBox and ShouldManageBlizzardChatEditBox(frame) then
                    if ChatFrame1EditBox.ClearAllPoints and ChatFrame1EditBox.SetPoint then
                        ChatFrame1EditBox:ClearAllPoints()
                        ChatFrame1EditBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                        ChatFrame1EditBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                    end
                end
                if FCF_SavePositionAndDimensions then
                    pcall(function() FCF_SavePositionAndDimensions(frame) end)
                end
                if frame == ChatFrame1 and Offhand.HUD and Offhand.HUD.RepairChatButtons then
                    Offhand.HUD:RepairChatButtons(frame)
                end
            end

            if Offhand.db.persistentWorkspacePanels ~= false then
                UnregisterSpecialFrame(name)
            end
            if restrictedProfessionsMovement then
                Canvas:SetWorkspacePanelOpen(name,
                    IsPersistentForeverProfessionsPanelName(name) and wasShown)
            elseif wasShown then
                Canvas:SetWorkspacePanelOpen(name, true)
            end
        else
            Offhand.db.savedWorkspacePositions[name] = nil
            Persistence.FitPlayerSpellsToWorkspace(frame, m, false)
            Canvas:SetWorkspacePanelOpen(name, false)
            if Offhand.ForeverPersistence then
                Offhand.ForeverPersistence:ClearPosition(name)
            end
            if IsBackpackRoot(name) then
                -- Moving either bag presentation to Mainhand transfers the complete
                -- backpack family. Clear an inactive root left by the other mode.
                ClearOtherBackpackRootState(nil)
                Offhand.db.nativeBackpackWorkspacePosition = nil
                Offhand.db.nativeBackpackWorkspaceOpen = nil
            end
            if frame == WorldMapFrame then
                frame:SetScale(1.0)
                DemodalizePanel(frame)
            end

            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local scaleFactor = frameScale / parentScale
            -- World Map resets to scale 1 on Mainhand; retain its pre-reset anchor
            -- units to preserve the established map drag behavior.
            local xInParent = frame == WorldMapFrame and dragLeftRaw or dragLeftInParent
            local yInParent = frame == WorldMapFrame and dragTopRaw or dragTopInParent
            local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
            local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
            if frameWidth <= 0 then frameWidth = 192 end
            if frameHeight <= 0 then frameHeight = 192 end

            -- Clamp strictly inside the Game Viewport so panels never enter the black space above m.gameTop
            local minX = m.gameLeft + 12
            local maxX = math.max(minX, m.gameRight - frameWidth - 12)
            local clampedX = math.max(minX, math.min(xInParent, maxX))

            local minY = m.gameBottom + frameHeight + 12
            local maxY = math.max(minY, m.gameTop - 12)
            local clampedY = math.max(minY, math.min(yInParent, maxY))
            local factor = parentScale / frameScale

            if frame == WorldMapFrame then
                Offhand.db.savedMainPositions[name] = { x = clampedX, y = clampedY }
                RegisterSpecialFrame(name)
                local w, h = frame:GetWidth(), frame:GetHeight()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                        elseif string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "CompactRaidFrameContainer" then
                if EditModeManagerFrame then
                    -- Retail Edit Mode manages these. Do not taint!
                    Offhand.db.savedWorkspacePositions[name] = nil
                    Offhand.db.savedMainPositions[name] = nil
                else
                    Offhand.db.savedMainPositions[name] = { x = clampedX, y = clampedY }
                    local w, h = frame:GetWidth(), frame:GetHeight()
                    frame:ClearAllPoints()
                    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                                end
            
            elseif string.match(name, "^ContainerFrame") then
                if IsBackpackRoot(name) then
                    -- A hardware drag into Mainhand is an explicit placement, not a
                    -- request to return the backpack to Blizzard's default bottom-
                    -- right stack. Retain that exact clamped position and user-
                    -- placed state so the seam edge is a usable destination.
                    Offhand.db.savedMainPositions[name] = {
                        point = "TOPLEFT", x = clampedX, y = clampedY,
                    }
                    pcall(function() frame:SetUserPlaced(true) end)
                    if frame.SetClampedToScreen then
                        pcall(function() frame:SetClampedToScreen(false) end)
                    end
                    frame:ClearAllPoints()
                    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                        clampedX * factor, clampedY * factor)
                else
                    pcall(function() frame:SetUserPlaced(false) end)
                end
                if name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" then
                    if Offhand.db.savedWorkspacePositions then
                        for i = 2, 13 do
                            Offhand.db.savedWorkspacePositions["ContainerFrame" .. i] = nil
                            local bf = _G["ContainerFrame" .. i]
                            if bf then pcall(function() bf:SetUserPlaced(false) end) end
                        end
                    end
                end
                if not IsBackpackRoot(name)
                    and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                    if Offhand.HUD and Offhand.HUD.LayoutBags then
                        Offhand.HUD:LayoutBags()
                    end
                end
            elseif name == "MinimapCluster" then
                pcall(function() frame:SetUserPlaced(false) end)
                if Offhand.HUD and Offhand.HUD.AlignHUDFrames then
                    Offhand.HUD:AlignHUDFrames()
                end
            elseif string.match(name, "^ChatFrame") then
                
                Offhand.db.savedMainPositions[name] = { point = "TOPLEFT", x = clampedX, y = clampedY }
                local w, h = frame:GetWidth(), frame:GetHeight()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                            if FCF_SavePositionAndDimensions then
                    pcall(function() FCF_SavePositionAndDimensions(frame) end)
                end
                
                if frame == ChatFrame1 and Offhand.HUD and Offhand.HUD.RepairChatButtons then
                    Offhand.HUD:RepairChatButtons(frame)
                end
            else
                Offhand.db.savedMainPositions[name] = {
                    point = "TOPLEFT", x = clampedX, y = clampedY,
                }
                if not restrictedProfessionsMovement then
                    RemodalizePanel(frame)
                    RegisterSpecialFrame(name)
                else
                    RegisterSpecialFrame(name)
                end
                if UpdateUIPanelPositions and not Offhand.isForever then
                    pcall(UpdateUIPanelPositions, frame)
                end
                local w, h = frame:GetWidth(), frame:GetHeight()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                        end
        end

        SaveForeverPanelOwnership()
        SetPanelDragging(frame, false)
    end
    return OnPanelDragStop
end

function Persistence.InstallRestore(Canvas, services)
    local ShouldYieldFrameToClassicUIForever = services.ShouldYieldFrameToClassicUIForever
    local ShouldYieldWorldMapToMoveAny = services.ShouldYieldWorldMapToMoveAny
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsExperimentalForeverProfessionsMovementEnabled = services.IsExperimentalForeverProfessionsMovementEnabled
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local WithWorkspace = services.WithWorkspace
    local DemodalizePanel = services.DemodalizePanel
    local EvictWorkspacePanelSlot = services.EvictWorkspacePanelSlot
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local UnregisterSpecialFrame = services.UnregisterSpecialFrame
    local HasCustomChatAddon = services.HasCustomChatAddon
    local ClearTrackedChatState = services.ClearTrackedChatState
    local ShouldManageBlizzardChatEditBox = services.ShouldManageBlizzardChatEditBox
    local IsRetailChatEditModeActive = services.IsRetailChatEditModeActive
    local RemodalizePanel = services.RemodalizePanel
    local RestoreWorkspacePosition
    RestoreWorkspacePosition = function(selfOrFrame, maybeFrame)
        local frame = (selfOrFrame == Canvas and maybeFrame) or maybeFrame or selfOrFrame
        if frame and Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return end
        if InCombatLockdown() or not frame or type(frame) ~= "table" or not frame.GetName then return end
        if IsWorldMapMaximized(frame) then return end
        if not Offhand.db or not Offhand.db.enabled then return end
        local name = frame:GetName()
        if not name then return end
        if frame._OffhandDragging then return end
        if ShouldYieldFrameToClassicUIForever(frame, name) then return end
        if ShouldYieldWorldMapToMoveAny(name) then return end
        if name:match("^ChatFrame%d+$") and HasCustomChatAddon() then
            ClearTrackedChatState(name)
            return
        end
        if Canvas:ShouldDeferSecondaryChatRestore(frame, name) then return end
        if IsForeverEditModeFrame(frame, name)
            or (IsUnsafeForPanelMutation(frame, name)
                and not IsForeverSocialPositionRoot(frame, name)) then return end
        local restrictedProfessionsMovement = IsForeverProfessionsPanel(frame, name)
            and IsExperimentalForeverProfessionsMovementEnabled()
        if IsRetailChatEditModeActive(frame) then return end

        local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not m then return end
        if not m.isSpanned then
            Persistence.FitPlayerSpellsToWorkspace(frame, m, false)
            Canvas:PlaceForSingleScreenRecovery(frame, m)
            return
        end

        local wPos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
        Persistence.FitPlayerSpellsToWorkspace(frame, m, Persistence.IsPosition(wPos))
        if Persistence.IsPosition(wPos) then
            if not restrictedProfessionsMovement
                and (Offhand.db.independentWorkspacePanels or frame == WorldMapFrame) then
                DemodalizePanel(frame)
                EvictWorkspacePanelSlot(frame)
            end
            if frame == WorldMapFrame then
                Canvas:ConfigureWorldMap()
                EvictWorkspacePanelSlot(frame)
            end
            if string.match(name, "^ChatFrame") and wPos.width and wPos.height and frame.SetSize then
                pcall(function() frame:SetSize(wPos.width, wPos.height) end)
            end

            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local frameWidth = (frame:GetWidth() or 0) * frameScale / parentScale
            local frameHeight = (frame:GetHeight() or 0) * frameScale / parentScale
            local fallbackHeight = (UIParent.GetHeight and UIParent:GetHeight()) or 1080
            local clampedX, clampedY = Persistence.ResolveWorkspacePosition(
                m, wPos, frameWidth, frameHeight,
                string.match(name, "^ChatFrame") ~= nil, fallbackHeight
            )

            local factor = parentScale / frameScale
            if frame.SetClampedToScreen then
                pcall(function() frame:SetClampedToScreen(false) end)
            end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
            if string.match(name, "^ChatFrame") and ChatFrame1EditBox
                and ShouldManageBlizzardChatEditBox(frame) then
                if ChatFrame1EditBox.ClearAllPoints and ChatFrame1EditBox.SetPoint then
                    ChatFrame1EditBox:ClearAllPoints()
                    ChatFrame1EditBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                    ChatFrame1EditBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                end
                
                if Offhand.HUD and Offhand.HUD.RepairChatButtons then
                    Offhand.HUD:RepairChatButtons(frame)
                end
            end
            if Offhand.db.persistentWorkspacePanels ~= false then
                UnregisterSpecialFrame(name)
            end
            return
        end

        local mPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]
        if type(mPos) == "table" and mPos.x and mPos.y then
            if frame == WorldMapFrame then Canvas:ConfigureWorldMap() end
            RemodalizePanel(frame)
            Canvas:PlacePanelOnMainhand(frame, m, mPos, false)
            if restrictedProfessionsMovement then RegisterSpecialFrame(name) end
            return
        end

        -- If frame is WorldMapFrame and on the main gaming screen:
        if frame == WorldMapFrame then
            Canvas:ConfigureWorldMap()
              RemodalizePanel(frame)
              RegisterSpecialFrame("WorldMapFrame")

            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local factor = parentScale / frameScale

            local width = frame:GetWidth() / factor
            local height = frame:GetHeight() / factor
            local minX, maxX = m.gameLeft+12, math.max(m.gameLeft+12, m.gameRight-width-12)
            local minY, maxY = m.gameBottom+height+12, m.gameTop-12
            local x = math.max(minX, math.min((mPos and mPos.x) or minX, maxX))
            local y = math.min(maxY, math.max(minY, (mPos and mPos.y) or maxY))
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x*factor, y*factor)
        end
    end
    return RestoreWorkspacePosition
end



local function PositiveDimension(value, fallback)
    value = tonumber(value)
    if value and value > 0 then return value end
    return fallback
end

function Persistence.EnsurePositionTables(db)
    if type(db) ~= "table" then return false end
    db.savedWorkspacePositions = db.savedWorkspacePositions or {}
    db.savedMainPositions = db.savedMainPositions or {}
    return true
end

function Persistence.IsPosition(position)
    return type(position) == "table"
        and tonumber(position.x) ~= nil
        and tonumber(position.y) ~= nil
end

function Persistence.ClampWorkspacePoint(metrics, x, y, frameWidth, frameHeight, isChat)
    if type(metrics) ~= "table" then return nil end
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return nil end

    frameWidth = PositiveDimension(frameWidth, 192)
    frameHeight = PositiveDimension(frameHeight, 192)
    local inset = isChat and 48 or 12
    local minX = metrics.workspaceLeft + inset
    local maxX = math.max(minX, metrics.workspaceRight - frameWidth - 12)
    local minY = metrics.workspaceBottom + frameHeight + 12
    local maxY = math.max(minY, metrics.workspaceTop - 12)
    return math.max(minX, math.min(x, maxX)),
        math.max(minY, math.min(y, maxY))
end

function Persistence.CreateWorkspacePosition(metrics, x, y, frameWidth, frameHeight, isChat,
        fallbackHeight)
    local clampedX, clampedY = Persistence.ClampWorkspacePoint(
        metrics, x, y, frameWidth, frameHeight, isChat
    )
    if not clampedX then return nil end
    local canvasHeight = PositiveDimension(metrics.workspaceHeight,
        PositiveDimension(metrics.screenHeight, fallbackHeight or 1080))
    return {
        x = clampedX,
        y = clampedY,
        canvasWidth = metrics.workspaceWidth,
        canvasHeight = canvasHeight,
        canvasLeft = metrics.workspaceLeft,
        canvasBottom = metrics.workspaceBottom,
    }
end

function Persistence.ResolveWorkspacePosition(metrics, position, frameWidth, frameHeight, isChat,
        fallbackHeight)
    if type(metrics) ~= "table" or not Persistence.IsPosition(position) then return nil end

    local targetX = tonumber(position.x)
    local savedCanvasWidth = tonumber(position.canvasWidth)
    local savedCanvasLeft = tonumber(position.canvasLeft) or 0
    if savedCanvasWidth and savedCanvasWidth > 0 and metrics.workspaceWidth > 0 then
        targetX = metrics.workspaceLeft
            + (targetX - savedCanvasLeft) * metrics.workspaceWidth / savedCanvasWidth
    end

    local canvasHeight = PositiveDimension(metrics.workspaceHeight,
        PositiveDimension(metrics.screenHeight, fallbackHeight or 1080))
    local targetY = tonumber(position.y)
    local savedCanvasHeight = tonumber(position.canvasHeight)
    local savedCanvasBottom = tonumber(position.canvasBottom) or 0
    if savedCanvasHeight and savedCanvasHeight > 0 and canvasHeight > 0 then
        targetY = metrics.workspaceBottom
            + (targetY - savedCanvasBottom) * canvasHeight / savedCanvasHeight
    end

    return Persistence.ClampWorkspacePoint(
        metrics, targetX, targetY, frameWidth, frameHeight, isChat
    )
end

