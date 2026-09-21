--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Canvas.lua: Unsegmented free-space secondary monitor workspace with universal window dragging
--]]

local _, Offhand = ...

local Canvas = {}
Offhand.Canvas = Canvas

local rootCanvas

function Canvas:CreateFrames()
    if rootCanvas then return end

    -- Root Canvas (covers the secondary monitor as an open, unsegmented free workspace)
    rootCanvas = CreateFrame("Frame", "OffhandCanvasFrame", UIParent, "BackdropTemplate")
        rootCanvas:SetFrameStrata("BACKGROUND")
    rootCanvas:SetFrameLevel(1)

    -- Dedicated solid background texture for guaranteed vibrant color visibility
    if not rootCanvas.bgTexture and rootCanvas.CreateTexture then
        rootCanvas.bgTexture = rootCanvas:CreateTexture(nil, "BACKGROUND", nil, -8)
        if rootCanvas.bgTexture.SetAllPoints then
            rootCanvas.bgTexture:SetAllPoints(rootCanvas)
        end
    end

    Offhand.canvas = rootCanvas
end

function Canvas:UpdateLayout()
    if not rootCanvas then self:CreateFrames() end

    local metrics = Offhand.Viewport:GetMetrics()

    if not metrics.isSpanned or not Offhand.db.enabled then
        rootCanvas:Hide()
        return
    end

    rootCanvas:Show()
    rootCanvas:ClearAllPoints()

    local isPortraitDeck = Offhand.db.primaryPosition ~= "LEFT"

    if isPortraitDeck then
        -- Secondary monitor (free space workspace) is on the LEFT
        rootCanvas:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        rootCanvas:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", metrics.deckWidth, 0)
    else
        -- Secondary monitor is on the RIGHT
        local leftOffset = metrics.gameWidth + metrics.bezel
        rootCanvas:SetPoint("TOPLEFT", UIParent, "TOPLEFT", leftOffset, 0)
        rootCanvas:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, 0)
    end

    -- Apply clean, dark backdrop theme to the workspace
    if Offhand.Themes and Offhand.Themes.ApplyCanvasTheme then
        Offhand.Themes:ApplyCanvasTheme(rootCanvas)
    end

    -- Enable free dragging for standard Blizzard frames so the player can move them anywhere on the workspace
    self:EnableFreeDragging()
    self:UpdateMapMovementBehavior()
end

local function HasLeatrixMaps()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Maps")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Maps")
    end
    return false
end

local function HasLeatrixPlus()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Plus")
    end
    return false
end

local DemodalizePanel, RemodalizePanel, OnPanelDragStop, RestoreWorkspacePosition, IsFrameOnWorkspace

-- Forever exposes Edit Mode through a load-on-demand addon.  The absence of
-- EditModeManagerFrame during early login therefore does not mean these frames
-- are safe for addons to move or make draggable.
local foreverEditModeFrameNames = {
    EditModeManagerFrame = true,
    EditModeSystemSettingsDialog = true,
    EditModeUnsavedChangesDialog = true,
    EditModeDialog = true,
    MainMenuBar = true,
    MainActionBar = true,
    StatusTrackingBarManager = true,
    MainMenuExpBar = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarLeft = true,
    MultiBarRight = true,
    StanceBar = true,
    PetActionBar = true,
    PossessActionBar = true,
    MinimapCluster = true,
    PlayerFrame = true,
    TargetFrame = true,
    FocusFrame = true,
    PartyFrame = true,
    PartyMemberFrame1 = true,
    CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    BuffFrame = true,
    BuffCluster = true,
    CastingBarFrame = true,
    PlayerCastingBarFrame = true,
    UIErrorsFrame = true,
    RaidWarningFrame = true,
}

local function IsForeverEditModeFrame(frame, suppliedName)
    if not Offhand.isForever then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not name then return false end
    return foreverEditModeFrameNames[name]
        or name:match("^EditMode") ~= nil
        or name:match("^PartyMemberFrame") ~= nil
        or name:match("^CompactPartyFrame") ~= nil
        or name:match("^CompactRaidFrame") ~= nil
end

local function IsUnsafeForDirectMutation(frame)
    if not frame then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then return true end
    return false
end

local function RegisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return end
    end
    table.insert(UISpecialFrames, name)
end

local function UnregisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            table.remove(UISpecialFrames, i)
        end
    end
end

function Canvas:UpdateMapMovementBehavior()
    local map = WorldMapFrame
    if not map then return end
    if HasLeatrixMaps() then return end

    if Offhand.db and Offhand.db.enabled and Offhand.db.preventMapCloseOnMove then
        pcall(function() map:UnregisterEvent("PLAYER_STARTED_MOVING") end)
    else
        pcall(function() map:RegisterEvent("PLAYER_STARTED_MOVING") end)
    end
end

function Canvas:UpdatePersistenceBehavior()
    if not Offhand.db then return end
    local shouldPersist = (Offhand.db.persistentWorkspacePanels ~= false)
    if WorldMapFrame then
        local isWs = (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]) or IsFrameOnWorkspace(WorldMapFrame)
        if isWs and shouldPersist then
            UnregisterSpecialFrame("WorldMapFrame")
        else
            RegisterSpecialFrame("WorldMapFrame")
        end
    end
    if Offhand.db.savedWorkspacePositions then
        for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
            local frame = _G[name]
            if frame then
                if shouldPersist then
                    UnregisterSpecialFrame(name)
                else
                    RegisterSpecialFrame(name)
                end
            end
        end
    end
end

-- Global Bag Closure Hook for Escape Persistence

-- The Combined Backpack close button uses CloseAllBags too. Distinguish that
-- explicit user action from Escape/CloseAllWindows cleanup so a workspace bag
-- can still be closed from its own X button.
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

if C_Container and C_Container.CloseAllBags and not _G.Offhand_Original_C_Container_CloseAllBags then
    _G.Offhand_Original_C_Container_CloseAllBags = C_Container.CloseAllBags
    C_Container.CloseAllBags = function(...)
        return HandleCustomCloseAllBags(_G.Offhand_Original_C_Container_CloseAllBags, ...)
    end
end


if CloseAllWindows and not _G.Offhand_OriginalCloseAllWindows then
    _G.Offhand_OriginalCloseAllWindows = CloseAllWindows
    CloseAllWindows = function(ignoreCenter)
        local activeWorkspaceFrames = {}
        local closedBags = false
        
        local function TrackFrame(f)
            if not f or not f.IsShown or not f:IsShown() then return end
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
            local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
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
            local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
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

if CloseAllBags and not _G.Offhand_OriginalCloseAllBags then
    _G.Offhand_OriginalCloseAllBags = CloseAllBags
    CloseAllBags = function(...)
        return HandleCustomCloseAllBags(_G.Offhand_OriginalCloseAllBags, ...)
    end
end

function Canvas:RestorePersistentFrames()
    if not Offhand.db or not Offhand.db.enabled or Offhand.db.persistentWorkspacePanels == false then return end
    if Offhand.db.restoreWorkspaceOnReload == false then return end
    if not Offhand.db.savedWorkspacePositions then return end
    if InCombatLockdown() then
        if Offhand.RunOrQueueCombat and not self.persistentRestorePending then
            self.persistentRestorePending = true
            Offhand:RunOrQueueCombat(function()
                Canvas.persistentRestorePending = false
                Canvas:RestorePersistentFrames()
            end)
        end
        return
    end
    
    local hasBag = false
    local openPanels = Offhand.db.openWorkspacePanels or {}
    
    for name, _ in pairs(openPanels) do
        if name:match("^ContainerFrame") or name:match("^Baganator") or name:match("^Baginator") or name:match("^BGR") or name:match("^Bagnon") or name:match("^AdiBags") or name:match("^BetterBags") or name:match("^ArkInventory") or name == "CustomBagRestorer" then
            hasBag = true
            break
        end
    end
    
    for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
        local frame = _G[name]
        if frame then
            if frame:IsShown() then
                RestoreWorkspacePosition(frame)
            elseif openPanels[name] then
                if name == "WorldMapFrame" then
                    if ToggleWorldMap then
                        ToggleWorldMap()
                    else
                        frame:Show()
                    end
                elseif name:match("^ContainerFrame") or name:match("Baganator") or name:match("Baginator") or name:match("BGR") or name:match("Bagnon") or name:match("AdiBags") or name:match("BetterBags") or name:match("ArkInventory") then
                    hasBag = true
                elseif name:match("^ChatFrame") then
                    frame:Show()
                    RestoreWorkspacePosition(frame)
                else
                    -- Generic UIPanels (Character, Quest, Guild, etc.)
                    if ShowUIPanel and (UIPanelWindows and UIPanelWindows[name]) then
                        ShowUIPanel(frame)
                    elseif frame.Show then
                        frame:Show()
                    end
                end
            end
        end
    end
    
    -- Baganator has its own root-frame snapshot/restore path. The generic
    -- prefix scan can see its still-shown child buttons while the bag is hidden.
    if hasBag and not (Baganator and Offhand.BagPersistence) then
        C_Timer.After(1.5, function() 
            -- Check if the bags are ALREADY open natively or by the custom addon's own persistence.
            -- If they are, calling OpenAllBags() might accidentally trigger an internal toggle and close them!
            local isAlreadyOpen = false
            if IsBagOpen then
                isAlreadyOpen = IsBagOpen(0)
            end
            
            -- Brute-force verify custom bags aren't already visible before firing OpenAllBags, 
            -- because custom bags often route OpenAllBags to a toggle function!
            for k, v in pairs(_G) do
                if type(k) == "string" and type(v) == "table" and type(rawget(v, 0)) == "userdata" then
                    if k:match("^Baganator") or k:match("^Baginator") or k:match("^BGR") or k:match("^Bagnon") or k:match("^AdiBags") or k:match("^BetterBags") or k:match("^ArkInventory") or k:match("^ElvUI_ContainerFrame") then
                        local ok, isShown = pcall(function() return v:IsShown() end)
                        if ok and isShown then
                            isAlreadyOpen = true
                            break
                        end
                    end
                end
            end
            
            if not isAlreadyOpen then
                -- Some custom bags completely ignore OpenAllBags and only listen to the Toggle API!
                if ToggleAllBags then ToggleAllBags() end
            end
        end)
    end
end

function Canvas:ConfigureWorldMap()
    local map = WorldMapFrame
    if InCombatLockdown() or not map or HasLeatrixMaps() or not Offhand.db or not Offhand.db.enabled then return end

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m or not m.isSpanned then return end

    -- Enable proper parent scaling so the map scales consistently with UIParent
    if map.SetIgnoreParentScale then
        pcall(function() map:SetIgnoreParentScale(false) end)
    end

    -- Ensure windowed mini world map in Classic Era
    pcall(function()
        if type(GetCVar("miniWorldMap")) == "string" and GetCVar("miniWorldMap") ~= "1" then
            SetCVar("miniWorldMap", "1")
        end
        if map.IsMaximized and map:IsMaximized() and map.Minimize then
            map:Minimize()
        end
        

    end)

    if not map._OffhandWindowedHook and hooksecurefunc then
        map._OffhandWindowedHook = true
        local function ScheduleWindowed()
            if map._OffhandWindowedPending or not C_Timer then return end
            map._OffhandWindowedPending = true
            C_Timer.After(0, function()
                map._OffhandWindowedPending = nil
                local function ApplyWindowed()
                    if not Offhand.db or not Offhand.db.enabled or HasLeatrixMaps() then return end
                    if map.IsShown and map:IsShown() then
                        Canvas:ConfigureWorldMap()
                        RestoreWorkspacePosition(map)
                    end
                end
                if InCombatLockdown() then
                    if Offhand.RunOrQueueCombat then Offhand:RunOrQueueCombat(ApplyWindowed) end
                else ApplyWindowed() end
            end)
        end
        if map.Maximize then hooksecurefunc(map, "Maximize", ScheduleWindowed) end
        if map.HookScript then map:HookScript("OnShow", ScheduleWindowed) end
    end

    -- Hook Blizzard's built-in title button drag handlers
    if WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
        WorldMapTitleButton._OffhandHooked = true
        WorldMapTitleButton:RegisterForDrag("LeftButton")
        WorldMapTitleButton:HookScript("OnDragStart", function(self)
            if InCombatLockdown() or not Offhand.db.enabled then return end
            map._OffhandDragging = true
        end)
        WorldMapTitleButton:HookScript("OnDragStop", function(self)
            OnPanelDragStop(map)
        end)
    end
    if WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
        Canvas._titleButtonHooked = true
        hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
            OnPanelDragStop(map)
        end)
    end

    -- Interactive Ctrl + MouseWheel scaling
    local function OnMapMouseWheel(self, delta)
        if InCombatLockdown() or not IsControlKeyDown() then return end
        if not Offhand.db or not Offhand.db.enabled then return end
        local current = map:GetScale() or 1.0
        local newScale
        if delta > 0 then
            newScale = math.min(3.00, current + 0.05)
        else
            newScale = math.max(0.40, current - 0.05)
        end
        newScale = math.floor(newScale * 100 + 0.5) / 100

        if IsFrameOnWorkspace(map) then
            Offhand.db.workspaceMapScale = newScale
            Canvas:ConfigureWorldMap()
            OnPanelDragStop(map)
        else
            Offhand.db.mainMapScale = newScale
            map:SetScale(newScale)
            OnPanelDragStop(map)
        end

        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(string.format("World Map Scale: %d%%", math.floor(newScale * 100 + 0.5)), 1.0, 0.82, 0.0, 1.0, 1.2)
        end
    end

    if not map._OffhandWheelHooked then
        map._OffhandWheelHooked = true
        if map.EnableMouseWheel then map:EnableMouseWheel(true) end
        if map.HookScript then map:HookScript("OnMouseWheel", OnMapMouseWheel) end
    end
    if WorldMapTitleButton and not WorldMapTitleButton._OffhandWheelHooked then
        WorldMapTitleButton._OffhandWheelHooked = true
        if WorldMapTitleButton.EnableMouseWheel then WorldMapTitleButton:EnableMouseWheel(true) end
        if WorldMapTitleButton.HookScript then WorldMapTitleButton:HookScript("OnMouseWheel", OnMapMouseWheel) end
    end

    -- If map is on the workspace, apply preferred or auto-fit scale
    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]
    local isWorkspaceMap = pos or (not (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions.WorldMapFrame) and IsFrameOnWorkspace(map))
    if isWorkspaceMap then
        local userScale = Offhand.db.workspaceMapScale
        local fitScale
        if userScale and userScale ~= "AUTO" and tonumber(userScale) and tonumber(userScale) > 0 then
            fitScale = tonumber(userScale)
        else
            local baseWidth = map:GetWidth() or 610
            if baseWidth <= 0 then baseWidth = 610 end
            local availableWidth = m.deckWidth - 24
            fitScale = math.max(0.50, math.min(3.00, availableWidth / baseWidth))
        end
        map:SetScale(fitScale)
        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame("WorldMapFrame")
        end
    else
        local userMainScale = Offhand.db.mainMapScale
        if userMainScale and tonumber(userMainScale) and tonumber(userMainScale) > 0 then
            map:SetScale(tonumber(userMainScale))
        else
            map:SetScale(1.0)
        end
        RegisterSpecialFrame("WorldMapFrame")
    end

    local availableWidth, availableHeight = m.gameWidth-24, m.gameHeight-24
    if isWorkspaceMap then
        if Offhand.db.primaryPosition == "TOP" or Offhand.db.primaryPosition == "BOTTOM" then
            availableWidth, availableHeight = m.screenWidth-24, m.deckWidth-24
        else
            availableWidth, availableHeight = m.deckWidth-24, m.screenHeight-24
        end
    end
    local width, height = map:GetWidth(), map:GetHeight()
    if width and height and width > 0 and height > 0 and availableWidth > 0 and availableHeight > 0 then
        local inherited = map:GetEffectiveScale() / map:GetScale() / UIParent:GetEffectiveScale()
        local scale = math.min(map:GetScale(), availableWidth/width/inherited, availableHeight/height/inherited)
        if scale > 0 and scale < math.huge then map:SetScale(scale) end
    end

    if not map._OffhandPersistenceHooked and map.HookScript then
        map._OffhandPersistenceHooked = true
        map:HookScript("OnShow", function(self)
            local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]) or IsFrameOnWorkspace(self)
            if isWs and (Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) then
                UnregisterSpecialFrame("WorldMapFrame")
            else
                RegisterSpecialFrame("WorldMapFrame")
            end
        end)
    end
end

IsFrameOnWorkspace = function(frame)
    if not frame then return false end
    local x = frame:GetLeft()
    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m then return false end
    if not x then
        local numPoints = frame.GetNumPoints and frame:GetNumPoints() or 0
        for i = 1, numPoints do
            local _, relTo, _, px = frame:GetPoint(i)
            if px then x = px; break end
        end
    end
    if not x then return false end
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local scaleFactor = frameScale / parentScale
    local width = (frame:GetWidth() or 0) * scaleFactor
    if width <= 0 then width = 192 * scaleFactor end
    local centerX = (x * scaleFactor) + (width / 2)
    if Offhand.db.primaryPosition ~= "LEFT" then
        return centerX < m.deckWidth
    else
        return centerX >= (m.gameWidth + m.bezel)
    end
end

local originalAreas = {}


DemodalizePanel = function(frame)
      if not frame then return end
      local name = frame:GetName()
      if not name then return end
      
      if frame == WorldMapFrame and PlayerMovementFrameFader and PlayerMovementFrameFader.RemoveFrame then
          PlayerMovementFrameFader.RemoveFrame(WorldMapFrame)
      end

      if UIPanelWindows and UIPanelWindows[name] then
          if name == "CharacterFrame" then
              if not originalAreas[name] then
                  originalAreas[name] = { isAreaNil = true, val = UIPanelWindows[name].area }
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
          PlayerMovementFrameFader.AddDeferredFrame(WorldMapFrame, .5, 1.0, 0.5, function() return not WorldMapFrame:IsMaximized() end)
      end

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

OnPanelDragStop = function(frame)
    if not frame then return end
    if InCombatLockdown() then frame._OffhandDragging = false; return end
    local dragName = frame.GetName and frame:GetName()
    if IsForeverEditModeFrame(frame, dragName) or IsUnsafeForDirectMutation(frame) then
        frame._OffhandDragging = false
        return
    end
    if dragName and dragName:match("^ChatFrame%d+$") then frame._OffhandDragging = true end
    if frame.StopMovingOrSizing then
        pcall(function() frame:StopMovingOrSizing() end)
    end
    local name = frame.GetName and frame:GetName()
    if name and string.match(name, "^ChatFrame") then
        
    else
        pcall(function() frame:SetUserPlaced(false) end)
    end

    if not Offhand.db or not Offhand.db.enabled then
        frame._OffhandDragging = false
        return
    end
    local name = frame:GetName()
    if not name then
        frame._OffhandDragging = false
        return
    end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m then
        frame._OffhandDragging = false
        return
    end

    local onDeck = IsFrameOnWorkspace(frame)

    if onDeck then
        if frame == WorldMapFrame then
            Offhand.db.savedMainPositions.WorldMapFrame = nil
            Canvas:ConfigureWorldMap()
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local scaleFactor = frameScale / parentScale
        local xInParent = (frame:GetLeft() or 0) * scaleFactor
        local yInParent = (frame:GetTop() or 0) * scaleFactor
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Clamp strictly within the workspace boundaries so panels never bleed across the seam
        local minX, maxX
        if Offhand.db.primaryPosition ~= "LEFT" then
            minX = string.match(name, "^ChatFrame") and 48 or 12
              maxX = math.max(minX, m.deckWidth - frameWidth - 12)
        else
            minX = m.gameRight + (string.match(name, "^ChatFrame") and 48 or 12)
              maxX = math.max(minX, m.screenWidth - frameWidth - 12)
        end
        local clampedX = math.max(minX, math.min(xInParent, maxX))

        local screenHeight = m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = frameHeight + 12
        local maxY = math.max(minY, screenHeight - 12)
        local clampedY = math.max(minY, math.min(yInParent, maxY))

        Offhand.db.savedWorkspacePositions[name] = { x = clampedX, y = clampedY }
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
        
        if Offhand.db.independentWorkspacePanels or frame == WorldMapFrame then
            -- Evict from Blizzard UIPanel slot if currently occupying one
            if GetUIPanel and (GetUIPanel("left") == frame or GetUIPanel("center") == frame or GetUIPanel("right") == frame or GetUIPanel("doublewide") == frame) then
                local oldHide = frame:GetScript("OnHide")
                local oldShow = frame:GetScript("OnShow")
                if oldHide then frame:SetScript("OnHide", nil) end
                if oldShow then frame:SetScript("OnShow", nil) end
                
                pcall(function() HideUIPanel(frame, 1) end)
                
                local w, h = frame:GetWidth(), frame:GetHeight()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                                frame:Show()
                
                if oldHide then frame:SetScript("OnHide", oldHide) end
                if oldShow then frame:SetScript("OnShow", oldShow) end
            end
            DemodalizePanel(frame)
        end

        if string.match(name, "^ContainerFrame") then
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
            if ChatFrame1EditBox and frame == ChatFrame1 then
                if ChatFrame1EditBox.ClearAllPoints and ChatFrame1EditBox.SetPoint then
                    ChatFrame1EditBox:ClearAllPoints()
                    ChatFrame1EditBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                    ChatFrame1EditBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                end
            end
            if FCF_SavePositionAndDimensions then
                pcall(function() FCF_SavePositionAndDimensions(frame) end)
            end
        end

        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
    else
        Offhand.db.savedWorkspacePositions[name] = nil
        if Offhand.ForeverPersistence then
            Offhand.ForeverPersistence:ClearPosition(name)
        end
        if frame == WorldMapFrame then
            frame:SetScale(1.0)
            DemodalizePanel(frame)
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local scaleFactor = frameScale / parentScale
        local xInParent = (frame:GetLeft() or 0) * scaleFactor
        local yInParent = (frame:GetTop() or 0) * scaleFactor
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
            pcall(function() frame:SetUserPlaced(false) end)
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
        elseif name == "MinimapCluster" then
            pcall(function() frame:SetUserPlaced(false) end)
            if Offhand.HUD and Offhand.HUD.AlignHUDFrames then
                Offhand.HUD:AlignHUDFrames()
            end
        elseif string.match(name, "^ChatFrame") then
            
            Offhand.db.savedMainPositions[name] = { x = clampedX, y = clampedY }
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
            pcall(function() frame:SetUserPlaced(false) end)
            RemodalizePanel(frame)
            RegisterSpecialFrame(name)
            if UpdateUIPanelPositions then
                pcall(UpdateUIPanelPositions, frame)
            end
            local w, h = frame:GetWidth(), frame:GetHeight()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                    end
    end

    frame._OffhandDragging = false
end

-- Forever's Edit Mode can move and resize non-secure utility frames without
-- dispatching their normal drag callbacks. Sample only the Combined Backpack
-- and chat frames, and mirror their geometry without touching their anchors or
-- attaching handlers to EditModeManagerFrame. This keeps the capture path
-- read-only with respect to Blizzard's protected Edit Mode state.
function Canvas:CaptureForeverFramePosition(frame)
    if not Offhand.isForever or InCombatLockdown() or not frame or not Offhand.db
        or not Offhand.db.enabled or not Offhand.ForeverPersistence then return false end
    local name = frame.GetName and frame:GetName()
    if name ~= "ContainerFrameCombinedBags" and not (name and name:match("^ChatFrame%d+$")) then return false end
    if IsUnsafeForDirectMutation(frame) or not frame.IsShown or not frame:IsShown() then return false end

    local ok, onWorkspace, x, y, width, height = pcall(function()
        local isWorkspace = IsFrameOnWorkspace(frame)
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local factor = frameScale / parentScale
        local left = frame:GetLeft()
        local top = frame:GetTop()
        if not left or not top then return isWorkspace end
        return isWorkspace, left * factor, top * factor, frame:GetWidth(), frame:GetHeight()
    end)
    if not ok then return false end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    if onWorkspace and x and y then
        local position = { x = x, y = y, width = width, height = height }
        Offhand.db.savedWorkspacePositions[name] = position
        Offhand.ForeverPersistence:SaveWorkspacePosition(name, position, width, height)
        return true
    elseif Offhand.db.savedWorkspacePositions[name] then
        Offhand.db.savedWorkspacePositions[name] = nil
        Offhand.ForeverPersistence:ClearPosition(name)
        return true
    end
    return false
end

RestoreWorkspacePosition = function(selfOrFrame, maybeFrame)
    local frame = (selfOrFrame == Canvas and maybeFrame) or maybeFrame or selfOrFrame
    if InCombatLockdown() or not frame or type(frame) ~= "table" or not frame.GetName then return end
    if not Offhand.db or not Offhand.db.enabled then return end
    local name = frame:GetName()
    if not name then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForDirectMutation(frame) then return end

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m then return end

    local wPos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    if type(wPos) == "table" and wPos.x and wPos.y then
        if Offhand.db.independentWorkspacePanels or frame == WorldMapFrame then
            DemodalizePanel(frame)
        end
        if frame == WorldMapFrame then
            Canvas:ConfigureWorldMap()
        end
        if string.match(name, "^ChatFrame") and wPos.width and wPos.height and frame.SetSize then
            pcall(function() frame:SetSize(wPos.width, wPos.height) end)
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Sanitize/clamp in case DB had bad coordinates (like y = -4.2 or x = 493.6)
        local minX, maxX
        if Offhand.db.primaryPosition ~= "LEFT" then
            minX = string.match(name, "^ChatFrame") and 48 or 12
              maxX = math.max(minX, m.deckWidth - frameWidth - 12)
        else
            minX = m.gameRight + (string.match(name, "^ChatFrame") and 48 or 12)
              maxX = math.max(minX, m.screenWidth - frameWidth - 12)
        end
        local clampedX = math.max(minX, math.min(wPos.x, maxX))

        local screenHeight = m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = frameHeight + 12
        local maxY = math.max(minY, screenHeight - 12)
        local clampedY = math.max(minY, math.min(wPos.y, maxY))

        wPos.x, wPos.y = clampedX, clampedY

        local factor = parentScale / frameScale
        if frame.SetClampedToScreen then
            pcall(function() frame:SetClampedToScreen(false) end)
        end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
        
                                                                                        if frame == CharacterFrame then
            if not frame._offhandInitCycled then
                frame._offhandInitCycled = true
                C_Timer.After(0.5, function()
                    if Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["CharacterFrame"] then
                        if CharacterFrame:IsShown() and tostring(GetCVar("characterFrameCollapsed")) == "0" then
                            if ToggleCharacter then
                                -- Space out the toggle by a tick to allow the UI to process the transition
                                pcall(ToggleCharacter, "ReputationFrame")
                                C_Timer.After(0.05, function()
                                    pcall(ToggleCharacter, "PaperDollFrame")
                                end)
                            end
                        end
                    end
                end)
            end
        end


        if string.match(name, "^ChatFrame") and ChatFrame1EditBox and frame == ChatFrame1 then
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

    -- If frame is WorldMapFrame and on the main gaming screen:
    if frame == WorldMapFrame then
        Canvas:ConfigureWorldMap()
          RemodalizePanel(frame)
          RegisterSpecialFrame("WorldMapFrame")

        local mPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions["WorldMapFrame"]
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

-- ============================================================================
-- Universal Panel Dragger (Allows moving panels to the secondary monitor)
-- ============================================================================
local function HookContainerTitlePersistence(frame, name)
    if not frame or not name or not string.match(name, "^ContainerFrame") then return end
    local titleContainer = frame.TitleContainer
    if not titleContainer or not titleContainer.HookScript or titleContainer._OffhandPersistenceHooked then return end

    titleContainer._OffhandPersistenceHooked = true
    titleContainer:HookScript("OnDragStart", function()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        frame._OffhandDragging = true
    end)
    titleContainer:HookScript("OnDragStop", function()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then
            frame._OffhandDragging = false
            return
        end
        OnPanelDragStop(frame)
    end)
end

local function HookCombinedBagCloseButton(frame, name)
    if not frame or name ~= "ContainerFrameCombinedBags" then return end
    local closeButton = frame.CloseButton or _G[name .. "CloseButton"]
    if not closeButton or not closeButton.HookScript or closeButton._OffhandExplicitCloseHooked then return end

    closeButton._OffhandExplicitCloseHooked = true
    closeButton:HookScript("PreClick", function()
        explicitCombinedBagClose = true
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

local function MakePanelDraggable(frame)
    if not frame or frame._OffhandMovable then return end
    local name = frame.GetName and frame:GetName()
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForDirectMutation(frame) then return end

    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end

    if name and string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end

    frame:SetMovable(true)
    frame:SetClampedToScreen(false)

    -- Create an elevated drag handle across the title bar area so clicks aren't swallowed by child elements
    -- MinimapCluster uses MinimapZoneTextButton as its natural drag handle and must not have an overlaid handle
    -- Unit frames (PartyMemberFrame, CompactPartyFrame) and FocusedRosterFrame must NOT have an overlaid handle
    -- to prevent blocking unit targeting, healing, right-click context menus, and roster row selection
    local isUnitFrame = name and (string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "PlayerFrame" or name == "TargetFrame")
    if frame ~= MinimapCluster and not isUnitFrame  then
        local handle = frame._OffhandHandle
        if not handle and CreateFrame then
            handle = CreateFrame("Frame", nil, frame)
            handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
            handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, 0)
            handle:SetHeight(32)
            local lvl = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
            if handle.SetFrameLevel then handle:SetFrameLevel(lvl + 25) end
            handle:EnableMouse(true)
            handle:RegisterForDrag("LeftButton")

            handle:HookScript("OnDragStart", function(self)
                if InCombatLockdown() or not Offhand.db.enabled then return end
                frame._OffhandDragging = true
                frame:StartMoving()
            end)

            handle:HookScript("OnDragStop", function(self)
                OnPanelDragStop(frame)
            end)

            frame._OffhandHandle = handle
        end
    end

    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:HookScript("OnDragStart", function(self)
        if InCombatLockdown() or not Offhand.db.enabled then return end
        frame._OffhandDragging = true
        frame:StartMoving()
    end)

    frame:HookScript("OnDragStop", function(self)
        OnPanelDragStop(frame)
    end)

    -- Modern/Forever combined bags are dragged by their native TitleContainer,
    -- which may not exist yet when the parent frame is first discovered.
    HookContainerTitlePersistence(frame, name)
    HookCombinedBagCloseButton(frame, name)

    frame:HookScript("OnShow", function(self)
        HookContainerTitlePersistence(frame, name)
        HookCombinedBagCloseButton(frame, name)
        RestoreWorkspacePosition(frame)
    end)

    if name == "ContainerFrameCombinedBags" then
        frame:HookScript("OnHide", function()
            -- Closing the combined backpack is a reliable final opportunity to
            -- capture a workspace placement even on clients whose native title
            -- drag does not propagate OnDragStop to the parent.
            if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
            if IsFrameOnWorkspace(frame) then OnPanelDragStop(frame) end
        end)
    end

    if frame == MinimapCluster then
        local function HookMinimapDragHandle(handleFrame)
            if handleFrame and not handleFrame._OffhandHooked then
                handleFrame._OffhandHooked = true
                handleFrame:EnableMouse(true)
                handleFrame:RegisterForDrag("LeftButton")
                handleFrame:HookScript("OnDragStart", function(self)
                    if InCombatLockdown() or not Offhand.db.enabled then return end
                    frame:SetMovable(true)
                    frame._OffhandDragging = true
                    frame:StartMoving()
                end)
                handleFrame:HookScript("OnDragStop", function(self)
                    OnPanelDragStop(frame)
                end)
            end
        end

        HookMinimapDragHandle(MinimapZoneTextButton)
        HookMinimapDragHandle(_G["MinimapBorderTop"])
        HookMinimapDragHandle(MinimapCluster)
    end

    if frame == WorldMapFrame then
        if WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
            WorldMapTitleButton._OffhandHooked = true
            WorldMapTitleButton:RegisterForDrag("LeftButton")
            WorldMapTitleButton:HookScript("OnDragStart", function(self)
                if InCombatLockdown() or not Offhand.db.enabled then return end
                frame._OffhandDragging = true
            end)
            WorldMapTitleButton:HookScript("OnDragStop", function(self)
                OnPanelDragStop(frame)
            end)
        end
        if WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
            Canvas._titleButtonHooked = true
            hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
                OnPanelDragStop(frame)
            end)
        end
    end

    frame._OffhandMovable = true
end

Canvas.RestoreWorkspacePosition = RestoreWorkspacePosition
Canvas.MakePanelDraggable = MakePanelDraggable
Canvas.HookCombinedBagCloseButton = HookCombinedBagCloseButton
Canvas.IsFrameOnWorkspace = IsFrameOnWorkspace
Canvas.OnPanelDragStop = OnPanelDragStop

function Canvas:TryMakeFrameDraggable(frame)
    if not frame or frame._OffhandMovable or not frame.GetName then return end
    local name = frame:GetName()
    if not name then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForDirectMutation(frame) then return end
    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end
    if string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end
    local isPanel = UIPanelWindows and UIPanelWindows[name]
    if isPanel or frame.TitleContainer or frame.TitleText or _G[name .. "TitleText"] then
        MakePanelDraggable(frame)
        if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
            DemodalizePanel(frame)
        end
    end
end

function Canvas:EnableFreeDragging()
    if not Offhand.db or not Offhand.db.enabled then return end
    if InCombatLockdown() then
        if not self.dragSetupPending then
            self.dragSetupPending = true
            Offhand:RunOrQueueCombat(function()
                Canvas.dragSetupPending = false
                Canvas:EnableFreeDragging()
            end)
        end
        return
    end

    local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
    local hasCustomMinimap = Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon()

    -- List of standard frames that players love dragging to their secondary workspace
    local frameNames = {
        "WorldMapFrame",
        "CharacterFrame",
        "QuestLogFrame",
        "SpellBookFrame",
        "TalentFrame",
        "PlayerTalentFrame",
        "FriendsFrame",
        "TradeFrame",
        "MerchantFrame",
        "MailFrame",
        "OpenMailFrame",
        "BankFrame",
        "PVEFrame",
        "InspectFrame",
        "MacroFrame",
        "ClassTrainerFrame",
        "TradeSkillFrame",
        "CraftFrame",
    }
    
    -- In Classic Era (no Edit Mode), we allow dragging unit frames.
    -- In modern WoW, Edit Mode natively handles moving these frames to the offhand monitor.
    if not Offhand.isForever and not EditModeManagerFrame then
        table.insert(frameNames, "PartyMemberFrame1")
        table.insert(frameNames, "CompactPartyFrame")
        table.insert(frameNames, "CompactRaidFrameContainer")
    end

    if not Offhand.isForever and not hasCustomMinimap then
        table.insert(frameNames, "MinimapCluster")
    end

    if not hasCustomBags then
        for i = 1, 13 do
            table.insert(frameNames, "ContainerFrame" .. i)
        end
        table.insert(frameNames, "ContainerFrameCombinedBags")
    end

    for _, name in ipairs(frameNames) do
        local frame = _G[name]
        if frame and not IsUnsafeForDirectMutation(frame) and not IsForeverEditModeFrame(frame, name) then
            MakePanelDraggable(frame)
            if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
                DemodalizePanel(frame)
            end
        end
    end

    if not hasCustomBags and ContainerFrame_GenerateFrame and not Canvas._bagGenHooked then
        Canvas._bagGenHooked = true
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            if frame and not IsUnsafeForDirectMutation(frame)
                and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                MakePanelDraggable(frame)
            end
        end)
    end

    if not Offhand.isForever and not hasCustomMinimap and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"] and MinimapCluster then
        RestoreWorkspacePosition(MinimapCluster)
    end
    if not Offhand.isForever and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["PartyMemberFrame1"] and _G.PartyMemberFrame1 then
        RestoreWorkspacePosition(_G.PartyMemberFrame1)
    end
    

    -- Hook Chat Frames and Tabs for workspace dragging and persistence
    local function RegisterChatFrame(chatFrame)
        if not chatFrame or chatFrame._OffhandChatHooked then return end
        chatFrame._OffhandChatHooked = true
        if chatFrame.SetClampedToScreen then
            pcall(function() chatFrame:SetClampedToScreen(false) end)
        end

        if chatFrame.HookScript then
            chatFrame:HookScript("OnDragStart", function(self) self._OffhandDragging = true end)
            chatFrame:HookScript("OnDragStop", function(self)
                self._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                OnPanelDragStop(self)
            end)
        end

        local chatName = chatFrame.GetName and chatFrame:GetName()
        local chatTab = chatName and _G[chatName .. "Tab"]
        if chatTab and not chatTab._OffhandTabHooked and chatTab.HookScript then
            chatTab._OffhandTabHooked = true
            chatTab:RegisterForDrag("LeftButton")
            chatFrame:SetMovable(true)
            
            -- Override to physically force the chat frame to move even in Retail WoW
            chatTab:HookScript("OnDragStart", function() 
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                chatFrame._OffhandDragging = true 
                chatFrame:StartMoving()
            end)
            
            chatTab:HookScript("OnDragStop", function(self)
                chatFrame:StopMovingOrSizing()
                chatFrame._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                -- Docked tabs belong to GeneralDockManager (or its scroll child),
                -- not the message frame. Persist the associated chat window.
                OnPanelDragStop(chatFrame)
            end)
        end
    end

    if FCF_StopDragging and not Canvas._fcfHooked then
        Canvas._fcfHooked = true
        hooksecurefunc("FCF_StopDragging", function(chatFrame)
            if chatFrame and Offhand.db and Offhand.db.enabled then
                if chatFrame.SetClampedToScreen then
                    pcall(function() chatFrame:SetClampedToScreen(false) end)
                end
                OnPanelDragStop(chatFrame)
                if FCF_SavePositionAndDimensions then
                    pcall(function() FCF_SavePositionAndDimensions(chatFrame) end)
                end
            end
        end)
    end

    if FCF_OpenNewWindow and not Canvas._fcfNewHooked then
        Canvas._fcfNewHooked = true
        hooksecurefunc("FCF_OpenNewWindow", function(...)
            for i = 1, (NUM_CHAT_WINDOWS or 10) do
                local cf = _G["ChatFrame" .. i]
                if cf then RegisterChatFrame(cf) end
            end
        end)
    end

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            RegisterChatFrame(cf)
            if Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ChatFrame" .. i] then
                RestoreWorkspacePosition(cf)
            end
        end
    end

    self:ConfigureWorldMap()
    self:UpdatePersistenceBehavior()
end

function Offhand:InitializeCanvas()
    Canvas:CreateFrames()

    -- Re-check draggable frames when Blizzard on-demand addons load
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function()
        Canvas:EnableFreeDragging()
        Canvas:UpdateMapMovementBehavior()
        Canvas:UpdatePersistenceBehavior()
        Canvas:ConfigureWorldMap()
    end)
    Canvas:UpdateMapMovementBehavior()
    Canvas:UpdatePersistenceBehavior()
    Canvas:ConfigureWorldMap()

    if Offhand.isForever and C_Timer and C_Timer.NewTicker and not Canvas.foreverPositionTicker then
        Canvas.foreverPositionTicker = C_Timer.NewTicker(0.5, function()
            Canvas:CaptureForeverFramePosition(_G.ContainerFrameCombinedBags)
            for i = 1, (NUM_CHAT_WINDOWS or 10) do
                Canvas:CaptureForeverFramePosition(_G["ChatFrame" .. i])
            end
        end)
    end

        if not Canvas.showUIPanelHooked and ShowUIPanel then
        Canvas.showUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(frame)
            if IsForeverEditModeFrame(frame) or IsUnsafeForDirectMutation(frame) then return end
            if frame and UIPanelWindows and UIPanelWindows[frame:GetName()] and not UIPanelWindows[frame:GetName()].area then
                if not frame:IsShown() then frame:Show() end
            end
            Canvas:TryMakeFrameDraggable(frame)
        end)
    end
    if not Canvas.hideUIPanelHooked and HideUIPanel then
        Canvas.hideUIPanelHooked = true
        hooksecurefunc("HideUIPanel", function(frame)
            if IsForeverEditModeFrame(frame) or IsUnsafeForDirectMutation(frame) then return end
            if frame and UIPanelWindows and UIPanelWindows[frame:GetName()] and not UIPanelWindows[frame:GetName()].area then
                if frame:IsShown() then frame:Hide() end
            end
        end)
    end

end

function Offhand:UpdateCanvas()
    Canvas:UpdateLayout()
end




