-- Canvas panel close policy and reversible Blizzard panel registration.
local _, Offhand = ...
local Lifecycle = {}
Offhand.CanvasPanelLifecycle = Lifecycle

function Lifecycle.InstallClosePolicy(Canvas, services)
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local ShouldYieldFrameToClassicUIForever = Offhand.CanvasCompatibility.ShouldYieldFrameToClassicUIForever
    local IsForeverNativeContainerName = Offhand.CanvasBackpackState.IsForeverContainerName
    local explicitCombinedBagClose = false

    local function HandleCustomCloseAllBags(originalFunc, ...)
        if explicitCombinedBagClose then return originalFunc(...) end
        if InCombatLockdown() then return originalFunc(...) end
        if not Offhand.db or not Offhand.db.enabled or Offhand.db.persistentWorkspacePanels == false then
            return originalFunc(...)
        end
        
        local closedAny = false
        local framesToCheck = {}
        local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
        if not hasCustomBags then
            for i = 1, NUM_CONTAINER_FRAMES or 13 do
                table.insert(framesToCheck, _G["ContainerFrame"..i])
            end
            if _G.ContainerFrameCombinedBags then
                table.insert(framesToCheck, _G.ContainerFrameCombinedBags)
            end
        end
        
        for _, f in ipairs(framesToCheck) do
            if f and f.IsShown and f:IsShown() then
                local name = f.GetName and f:GetName()
                if name then
                    local isWs = (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]) or IsFrameOnWorkspace(f)
                    if not isWs then
                        if f.Hide then f:Hide() end
                        closedAny = true
                    end
                end
            end
        end
        
        if closedAny then return true else return false end
    end

    -- Retail's combined-bag setting change calls the native close functions inside
    -- a transactional rebuild and asserts that every previous bag really closed.
    -- Its higher-level CloseAllWindows guard already preserves workspace bags on
    -- Escape, so never replace either low-level close entry point on Retail.
    if not Offhand.isForever and not Offhand.isRetail
        and C_Container and C_Container.CloseAllBags
        and not _G.Offhand_Original_C_Container_CloseAllBags then
        _G.Offhand_Original_C_Container_CloseAllBags = C_Container.CloseAllBags
        C_Container.CloseAllBags = function(...)
            return HandleCustomCloseAllBags(_G.Offhand_Original_C_Container_CloseAllBags, ...)
        end
    end


    if not Offhand.isForever and CloseAllWindows and not _G.Offhand_OriginalCloseAllWindows then
        _G.Offhand_OriginalCloseAllWindows = CloseAllWindows
        CloseAllWindows = function(ignoreCenter)
            local activeWorkspaceFrames = {}
            local closedBags = false
            local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
            
            local function TrackFrame(f)
                if not f or not f.IsShown or not f:IsShown() then return end
                if ShouldYieldFrameToClassicUIForever(f) then return end
                for _, existing in ipairs(activeWorkspaceFrames) do
                    if existing == f then return end
                end
                if IsFrameOnWorkspace(f) then
                    table.insert(activeWorkspaceFrames, f)
                end
            end

            local restoredSpecialFrames = {}
            local restoredUIPanels = {}
            
            if not ignoreCenter and not InCombatLockdown() and Offhand.db and Offhand.db.enabled and Offhand.db.persistentWorkspacePanels ~= false then
                -- 1. Track standard bags ONLY if no custom bag addon is controlling them
                if not hasCustomBags then
                    local standardBags = {}
                    for i = 1, NUM_CONTAINER_FRAMES or 13 do table.insert(standardBags, _G["ContainerFrame"..i]) end
                    if _G.ContainerFrameCombinedBags then table.insert(standardBags, _G.ContainerFrameCombinedBags) end
                    
                    for _, f in ipairs(standardBags) do
                        if f and f.IsShown and f:IsShown() then
                            if IsFrameOnWorkspace(f) or (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[f:GetName() or ""]) then
                                TrackFrame(f)
                            else
                                if f.Hide then f:Hide() end
                                closedBags = true
                            end
                        end
                    end
                end
                
                -- 2. Track known saved workspace panels
                if Offhand.db.savedWorkspacePositions then
                    for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
                        TrackFrame(_G[name])
                    end
                end
                
                -- 3. Track ALL UISpecialFrames
                if UISpecialFrames then
                    for _, name in ipairs(UISpecialFrames) do
                        TrackFrame(_G[name])
                    end
                end
                
                -- 4. Track ALL UIPanelWindows
                if UIPanelWindows then
                    for name, _ in pairs(UIPanelWindows) do
                        TrackFrame(_G[name])
                    end
                end
                
                -- 5. Strip them out of the Blizzard engine so Hide() is never called!
                for _, f in ipairs(activeWorkspaceFrames) do
                    local name = f.GetName and f:GetName()
                    if name then
                        -- Temporarily remove from UISpecialFrames
                        if UISpecialFrames then
                            for i = #UISpecialFrames, 1, -1 do
                                if UISpecialFrames[i] == name then
                                    table.insert(restoredSpecialFrames, name)
                                    table.remove(UISpecialFrames, i)
                                end
                            end
                        end
                        -- Temporarily remove from UIPanelWindows
                        if UIPanelWindows and UIPanelWindows[name] and UIPanelWindows[name].area then
                            restoredUIPanels[name] = UIPanelWindows[name].area
                            UIPanelWindows[name].area = nil
                        end
                    end
                end
                
                if #activeWorkspaceFrames > 0 then
                    ignoreCenter = true -- Bypass native C_Container.CloseAllBags()
                end
            end
            
            -- Pre-scan ALL UI panels to see their EXACT state before CloseAllWindows runs
            local statesBefore = {}
            if not InCombatLockdown() then
                if UISpecialFrames then
                    for _, name in ipairs(UISpecialFrames) do
                        local f = _G[name]
                        if f and f.IsShown and f:IsShown() then statesBefore[name] = true end
                    end
                end
                if UIPanelWindows then
                    for name, _ in pairs(UIPanelWindows) do
                        local f = _G[name]
                        if f and f.IsShown and f:IsShown() then statesBefore[name] = true end
                    end
                end
                if not hasCustomBags then
                    for i = 1, NUM_CONTAINER_FRAMES or 13 do
                        local f = _G["ContainerFrame"..i]
                        if f and f.IsShown and f:IsShown() then statesBefore[f:GetName()] = true end
                    end
                end
            end
            
            local closedAny = _G.Offhand_OriginalCloseAllWindows(ignoreCenter)
            
            -- Post-scan: Did anything on the main screen actually close?
            if not InCombatLockdown() and closedAny then
                local legitimateClose = false
                local function CheckLegitimateClose(name)
                    local f = _G[name]
                    if f and statesBefore[name] and not f:IsShown() then
                        local isWs = false
                        for _, w in ipairs(activeWorkspaceFrames) do
                            if w == f then isWs = true; break end
                        end
                        -- A legitimate close is a frame not on the workspace that was physically visible to the user
                        if not isWs and f.GetEffectiveAlpha and f:GetEffectiveAlpha() > 0.05 then
                            local left, bottom, width, height = f:GetRect()
                            if left and bottom and width and height and width > 1 and height > 1 then
                                local scale = f:GetEffectiveScale() or 1
                                local fLeft, fBottom = left * scale, bottom * scale
                                local fRight, fTop = fLeft + (width * scale), fBottom + (height * scale)
                                
                                local pWidth = (UIParent:GetWidth() or 0) * (UIParent:GetEffectiveScale() or 1)
                                local pHeight = (UIParent:GetHeight() or 0) * (UIParent:GetEffectiveScale() or 1)
                                
                                -- Simple bounding box collision with the total UIParent bounds
                                if fLeft < pWidth and fRight > 0 and fBottom < pHeight and fTop > 0 then
                                    legitimateClose = true
                                end
                            end
                        end
                    end
                end
                
                if UISpecialFrames then
                    for _, name in ipairs(UISpecialFrames) do CheckLegitimateClose(name) end
                end
                if UIPanelWindows and not legitimateClose then
                    for name, _ in pairs(UIPanelWindows) do CheckLegitimateClose(name) end
                end
                if not legitimateClose and not hasCustomBags then
                    for i = 1, NUM_CONTAINER_FRAMES or 13 do CheckLegitimateClose("ContainerFrame"..i) end
                end
                
                -- If the ONLY things that closed were our activeWorkspaceFrames, then we SPOOF the return value to false!
                -- This perfectly guarantees ToggleGameMenu will open the Game Menu on the first Escape.
                if not legitimateClose and #activeWorkspaceFrames > 0 then
                    closedAny = false
                end
            end
            
            if not InCombatLockdown() then
                -- Put everything back!
                if UISpecialFrames then
                    for _, name in ipairs(restoredSpecialFrames) do
                        table.insert(UISpecialFrames, name)
                    end
                end
                if UIPanelWindows then
                    for name, area in pairs(restoredUIPanels) do
                        UIPanelWindows[name].area = area
                    end
                end
                
                -- Failsafe (in case something bypassed the tables and closed anyway)
                for _, f in ipairs(activeWorkspaceFrames) do
                    if f.Show and not f:IsShown() then
                        f:Show()
                    end
                end
            end
            
            return closedAny or closedBags
        end
    end

    if not Offhand.isForever and not Offhand.isRetail
        and CloseAllBags and not _G.Offhand_OriginalCloseAllBags then
        _G.Offhand_OriginalCloseAllBags = CloseAllBags
        CloseAllBags = function(...)
            return HandleCustomCloseAllBags(_G.Offhand_OriginalCloseAllBags, ...)
        end
    end

    local function HookCombinedBagCloseButton(frame, name)
        if not frame or name ~= "ContainerFrameCombinedBags" then return end
        if IsForeverNativeContainerName(name) then return end
        local closeButton = frame.CloseButton or _G[name .. "CloseButton"]
        if not closeButton or not closeButton.HookScript or closeButton._OffhandExplicitCloseHooked then return end

        closeButton._OffhandExplicitCloseHooked = true
        closeButton:HookScript("PreClick", function()
            explicitCombinedBagClose = true
            Canvas:SetWorkspacePanelOpen(frame, false)
            -- Do not leave the bypass armed if Blizzard aborts the click before
            -- PostClick. The native close runs synchronously between these scripts.
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    explicitCombinedBagClose = false
                end)
            end
        end)
        closeButton:HookScript("PostClick", function()
            explicitCombinedBagClose = false
        end)
    end
    return HookCombinedBagCloseButton
end

function Lifecycle.InstallModality(Canvas, services)
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local CanManagePanelsFromAddon = services.CanManagePanelsFromAddon
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local UnregisterSpecialFrame = services.UnregisterSpecialFrame
    local IsBackpackRoot = Offhand.CanvasBackpackState.IsRoot
    local IsContextBoundPanel = Offhand.CanvasPanelRegistry.IsContextBoundPanel
    local HasClassicUIForever = Offhand.CanvasCompatibility.HasClassicUIForever
    local State = Offhand.CanvasFrameState
    local IsPanelEvicting = State.IsEvicting
    local SetPanelEvicting = State.SetEvicting
    local SetPanelDragging = State.SetDragging
    local EvictWorkspacePanelSlot, DemodalizePanel, RemodalizePanel
    local originalAreas = {}

    -- A workspace panel can still occupy one of Blizzard's active UIPanel slots
    -- even after it has been removed from UISpecialFrames. Escape closes that slot
    -- independently. Detach only the already-saved workspace panel; do not alter
    -- UIPanelWindows or any secure layout attributes (especially on Forever).
    EvictWorkspacePanelSlot = function(frame)
        if not frame or not GetUIPanel or not HideUIPanel or IsPanelEvicting(frame)
            or (InCombatLockdown and InCombatLockdown()) then return false end
        if not CanManagePanelsFromAddon() then return false end
        local name = frame.GetName and frame:GetName()
        -- NPC and world-interaction panels must remain in Blizzard's active
        -- UIPanel slot. Evicting one uses a native HideUIPanel followed by a direct
        -- frame:Show(), which is safe for ordinary menus but severs the interaction
        -- lifecycle of panels such as AuctionHouseFrame. The frame can look open
        -- after the drag while Blizzard considers the interaction closed; after
        -- its X button is used, the next NPC click then plays the native sound but
        -- has no valid panel transaction to display. These panels still keep their
        -- saved Offhand anchor and restore it from OnShow, while Escape and native
        -- close behavior remain Blizzard-owned.
        if name and IsContextBoundPanel(name) then return false end
        -- Native bag frames own pooled item buttons whose lifecycle is driven by
        -- Blizzard's bag APIs. A HideUIPanel + direct Show cycle can reveal only the
        -- shell and leave UpdateNewItemList with missing item buttons.
        if IsBackpackRoot(name) then return false end
        local occupiesSlot = GetUIPanel("left") == frame or GetUIPanel("center") == frame
            or GetUIPanel("right") == frame or GetUIPanel("doublewide") == frame
        if not occupiesSlot then return false end

        -- Keep Blizzard's scripts installed. Replacing even an unchanged protected
        -- World Map handler taints later quest-pin acquisition on Forever. The
        -- re-entrancy flag makes Offhand's secure post-hooks ignore this deliberate
        -- hide/show cycle while Blizzard vacates the UIPanel slot normally.
        SetPanelEvicting(frame, true)
        pcall(function() HideUIPanel(frame, 1) end)
        if frame.Show then frame:Show() end
        SetPanelEvicting(frame, false)
        return true
    end


    DemodalizePanel = function(frame)
          if not frame then return end
          local name = frame:GetName()
          if not name then return end

          -- Removing the workspace map from Blizzard's movement fader prevents the
          -- intended always-open map from becoming subdued while the player runs.
          -- This public fader registration is independent of the protected map
          -- scripts and UIPanel metadata that must remain untouched on Forever.
          if frame == WorldMapFrame and PlayerMovementFrameFader
              and PlayerMovementFrameFader.RemoveFrame then
              pcall(function() PlayerMovementFrameFader.RemoveFrame(WorldMapFrame) end)
          end

          -- Do not mutate Forever's Blizzard-owned panel registry or panel-layout
          -- attributes. Those feed protected UI execution paths.
          if Offhand.isForever then return end

          if UIPanelWindows and UIPanelWindows[name] then
              if name == "CharacterFrame" or name == "WorldMapFrame" then
                  if not originalAreas[name] then
                      originalAreas[name] = { isAreaNil = true, val = UIPanelWindows[name].area }
                  end
                  -- Retail lazily copies UIPanelWindows metadata onto the frame.
                  -- Materialize it before clearing area so WorldMapFrame retains
                  -- maximizePoint; deleting the whole registry entry first makes
                  -- MaximizeUIPanel call SetPoint(nil).
                  if name == "WorldMapFrame" and SetUIPanelAttribute then
                      pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
                  end
                  UIPanelWindows[name].area = nil
              else
                  if not originalAreas[name] then
                      originalAreas[name] = { isAreaNil = false, val = UIPanelWindows[name] }
                  end
                  UIPanelWindows[name] = nil
              end
          end
        if SetUIPanelAttribute then
            pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
        end
        local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]) or IsFrameOnWorkspace(frame)
        if isWs and (Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) then
            UnregisterSpecialFrame(name)
        else
            RegisterSpecialFrame(name)
        end
    end

    RemodalizePanel = function(frame)
          if not frame then return end
          local name = frame:GetName()
          if not name then return end

          if frame == WorldMapFrame and PlayerMovementFrameFader and PlayerMovementFrameFader.AddDeferredFrame then
              pcall(function()
                  PlayerMovementFrameFader.AddDeferredFrame(
                      WorldMapFrame, .5, 1.0, 0.5,
                      function() return not WorldMapFrame:IsMaximized() end)
              end)
          end

          if Offhand.isForever then return end

          UnregisterSpecialFrame(name)
          if originalAreas[name] then
              if UIPanelWindows then
                  if originalAreas[name].isAreaNil then
                      if UIPanelWindows[name] then UIPanelWindows[name].area = originalAreas[name].val end
                  else
                      UIPanelWindows[name] = originalAreas[name].val
                  end
              end
              if SetUIPanelAttribute then
                  local area = originalAreas[name].isAreaNil and originalAreas[name].val or (originalAreas[name].val and originalAreas[name].val.area)
                  pcall(function() SetUIPanelAttribute(frame, "area", area) end)
              end
          end
      end

    function Canvas:RelinquishClassicUIForeverFrames()
        if not HasClassicUIForever() then return false end
        for _, name in ipairs({"WorldMapFrame", "CharacterFrame"}) do
            local frame = _G[name]
            if frame then
                SetPanelDragging(frame, false)
                local handle = frame._OffhandHandle
                if handle and handle._OffhandSyntheticPanelDragHandle and handle.Hide then
                    handle:Hide()
                end
                if originalAreas[name] then RemodalizePanel(frame) end
            end
        end
        return true
    end
    return EvictWorkspacePanelSlot, DemodalizePanel, RemodalizePanel
end

