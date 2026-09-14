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
if CloseAllBags and not _G.Offhand_OriginalCloseAllBags then
    _G.Offhand_OriginalCloseAllBags = CloseAllBags
    CloseAllBags = function(...)
        if Offhand.db and Offhand.db.enabled and Offhand.db.persistentWorkspacePanels ~= false then
            local closedAny = false
            for i = 1, NUM_CONTAINER_FRAMES or 13 do
                local f = _G["ContainerFrame"..i]
                if f and f:IsShown() then
                    local name = f:GetName()
                    -- If the bag is NOT in the workspace, close it
                    if not (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]) and not IsFrameOnWorkspace(f) then
                        if f.Hide then f:Hide() end
                        closedAny = true
                    end
                end
            end
            if closedAny then return true else return false end
        else
            return _G.Offhand_OriginalCloseAllBags(...)
        end
    end
end

function Canvas:RestorePersistentFrames()
    if not Offhand.db or not Offhand.db.enabled or Offhand.db.persistentWorkspacePanels == false then return end
    if not Offhand.db.savedWorkspacePositions then return end
    
    for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
        local frame = _G[name]
        -- Handle World Map
        if name == "WorldMapFrame" and frame and not frame:IsShown() then
            if ToggleWorldMap then
                ToggleWorldMap()
            elseif frame.Show then
                frame:Show()
            end
        end
        -- Handle Bags
        if name:match("^ContainerFrame") and frame and not frame:IsShown() then
            -- Determine bag ID from frame name if possible (usually ContainerFrame1 is Backpack, etc)
            -- A simpler approach is just to open all bags if any bag was in the workspace, or just try to show the frame directly.
            -- However, bags are dynamically populated. We should use OpenAllBags() if there were bags open.
            -- Wait, if they only had one bag open, we shouldn't open all. But to be safe, we can just call OpenAllBags.
            -- Actually, if we just call frame:Show(), it won't populate the items correctly in WoW Classic.
        end
    end
    
    -- Robust Bag Restoration: If any ContainerFrame was in the workspace, open all bags
    local hasBag = false
    for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
        if name:match("^ContainerFrame") then hasBag = true break end
    end
    if hasBag then
        if OpenAllBags then OpenAllBags() end
    end
end

function Canvas:ConfigureWorldMap()
    local map = WorldMapFrame
    if not map or HasLeatrixMaps() or not Offhand.db or not Offhand.db.enabled then return end

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m or not m.isSpanned then return end

    -- Enable proper parent scaling so the map scales consistently with UIParent
    if map.SetIgnoreParentScale then
        pcall(function() map:SetIgnoreParentScale(false) end)
    end

    -- Ensure windowed mini world map in Classic Era
    pcall(function()
        if GetCVar("miniWorldMap") ~= "1" then
            SetCVar("miniWorldMap", "1")
        end
        if map.IsMaximized and map:IsMaximized() and map.Minimize then
            map:Minimize()
        end
    end)

    -- Permanently demodalize WorldMapFrame so it never conflicts with UIPanels
    DemodalizePanel(map)

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
        if not IsControlKeyDown() then return end
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
    local isWorkspaceMap = pos or IsFrameOnWorkspace(map)
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
    if UIPanelWindows and UIPanelWindows[name] then
        if not originalAreas[name] then
            originalAreas[name] = UIPanelWindows[name].area
        end
        UIPanelWindows[name].area = nil
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
    UnregisterSpecialFrame(name)
    if originalAreas[name] then
        if UIPanelWindows and UIPanelWindows[name] then
            UIPanelWindows[name].area = originalAreas[name]
        end
        if SetUIPanelAttribute then
            pcall(function() SetUIPanelAttribute(frame, "area", originalAreas[name]) end)
        end
    end
end

OnPanelDragStop = function(frame)
    if not frame then return end
    if frame.StopMovingOrSizing then
        pcall(function() frame:StopMovingOrSizing() end)
    end
    pcall(function() frame:SetUserPlaced(true) end)

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
            Canvas:ConfigureWorldMap()
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local scaleFactor = frameScale / parentScale
        local xInParent = (frame:GetLeft() or 0) * scaleFactor
        local yInParent = (frame:GetBottom() or 0) * scaleFactor
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Clamp strictly within the workspace boundaries so panels never bleed across the seam
        local minX, maxX
        if Offhand.db.primaryPosition ~= "LEFT" then
            minX = 12
            maxX = math.max(minX, m.deckWidth - frameWidth - 12)
        else
            minX = m.gameRight + 12
            maxX = math.max(minX, m.screenWidth - frameWidth - 12)
        end
        local clampedX = math.max(minX, math.min(xInParent, maxX))

        local minY = 12
        local screenHeight = m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local maxY = math.max(minY, screenHeight - frameHeight - 30)
        local clampedY = math.max(minY, math.min(yInParent, maxY))

        Offhand.db.savedWorkspacePositions[name] = { x = clampedX, y = clampedY }
        if Offhand.db.savedMainPositions then
            Offhand.db.savedMainPositions[name] = nil
        end

        frame:ClearAllPoints()
        local factor = parentScale / frameScale
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)

        if Offhand.db.independentWorkspacePanels or frame == WorldMapFrame then
            -- Evict from Blizzard UIPanel slot if currently occupying one
            if GetUIPanel and (GetUIPanel("left") == frame or GetUIPanel("center") == frame or GetUIPanel("right") == frame or GetUIPanel("doublewide") == frame) then
                local oldHide = frame:GetScript("OnHide")
                local oldShow = frame:GetScript("OnShow")
                if oldHide then frame:SetScript("OnHide", nil) end
                if oldShow then frame:SetScript("OnShow", nil) end
                
                pcall(function() HideUIPanel(frame, 1) end)
                
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                frame:Show()
                
                if oldHide then frame:SetScript("OnHide", oldHide) end
                if oldShow then frame:SetScript("OnShow", oldShow) end
            end
            DemodalizePanel(frame)
        end

        if string.match(name, "^ContainerFrame") then
            if not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                if Offhand.HUD and Offhand.HUD.LayoutBags then
                    Offhand.HUD:LayoutBags()
                end
            end
        end

        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
    else
        Offhand.db.savedWorkspacePositions[name] = nil
        if frame == WorldMapFrame then
            frame:SetScale(1.0)
            DemodalizePanel(frame)
            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local scaleFactor = frameScale / parentScale
            local xInParent = (frame:GetLeft() or 0) * scaleFactor
            local yInParent = (frame:GetBottom() or 0) * scaleFactor
            Offhand.db.savedMainPositions[name] = { x = xInParent, y = yInParent }
            RegisterSpecialFrame(name)
        elseif string.match(name, "^ContainerFrame") then
            pcall(function() frame:SetUserPlaced(false) end)
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
        else
            RemodalizePanel(frame)
            RegisterSpecialFrame(name)
        end
    end

    frame._OffhandDragging = false
end

RestoreWorkspacePosition = function(selfOrFrame, maybeFrame)
    local frame = (selfOrFrame == Canvas and maybeFrame) or maybeFrame or selfOrFrame
    if not frame or type(frame) ~= "table" or not frame.GetName then return end
    if not Offhand.db or not Offhand.db.enabled then return end
    local name = frame:GetName()
    if not name then return end

    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not m then return end

    local wPos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    if wPos and wPos.x and wPos.y then
        if Offhand.db.independentWorkspacePanels or frame == WorldMapFrame then
            DemodalizePanel(frame)
        end
        if frame == WorldMapFrame then
            Canvas:ConfigureWorldMap()
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
            minX = 12
            maxX = math.max(minX, m.deckWidth - frameWidth - 12)
        else
            minX = m.gameRight + 12
            maxX = math.max(minX, m.screenWidth - frameWidth - 12)
        end
        local clampedX = math.max(minX, math.min(wPos.x, maxX))

        local minY = 12
        local screenHeight = m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local maxY = math.max(minY, screenHeight - frameHeight - 30)
        local clampedY = math.max(minY, math.min(wPos.y, maxY))

        wPos.x, wPos.y = clampedX, clampedY

        local factor = parentScale / frameScale
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
        pcall(function() frame:SetUserPlaced(true) end)
        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
        return
    end

    -- If frame is WorldMapFrame and on the main gaming screen:
    if frame == WorldMapFrame then
        frame:SetScale(1.0)
        DemodalizePanel(frame)
        RegisterSpecialFrame("WorldMapFrame")
        local mPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions["WorldMapFrame"]
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local factor = parentScale / frameScale

        if mPos and mPos.x and mPos.y then
            local minX = m.gameLeft + 10
            local maxX = m.gameRight - (frame:GetWidth() or 610) - 10
            local posX = math.max(minX, math.min(mPos.x, maxX))
            local posY = math.max(10, math.min(mPos.y, m.gameTop - (frame:GetHeight() or 438) - 10))
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", posX * factor, posY * factor)
        else
            local defaultX = m.gameLeft + 20
            local defaultY = math.max(20, m.gameTop - (frame:GetHeight() or 438) - 40)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", defaultX * factor, defaultY * factor)
        end
    end
end

-- ============================================================================
-- Universal Panel Dragger (Allows moving panels to the secondary monitor)
-- ============================================================================
local function MakePanelDraggable(frame)
    if not frame or frame._OffhandMovable then return end
    local name = frame.GetName and frame:GetName()

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
    if frame ~= MinimapCluster then
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

    frame:HookScript("OnShow", function(self)
        RestoreWorkspacePosition(frame)
    end)

    if frame == MinimapCluster then
        local function HookMinimapDragHandle(handleFrame)
            if handleFrame and not handleFrame._OffhandHooked then
                handleFrame._OffhandHooked = true
                handleFrame:EnableMouse(true)
                handleFrame:RegisterForDrag("LeftButton")
                handleFrame:HookScript("OnDragStart", function(self)
                    if InCombatLockdown() or not Offhand.db.enabled then return end
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

function Canvas:TryMakeFrameDraggable(frame)
    if not frame or frame._OffhandMovable or not frame.GetName then return end
    local name = frame:GetName()
    if not name then return end
    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end
    if string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end
    local isPanel = UIPanelWindows and UIPanelWindows[name]
    if isPanel or frame.TitleContainer or frame.TitleText or _G[name .. "TitleText"] then
        frame:SetClampedToScreen(false)
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

    if not hasCustomMinimap then
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
        if frame then
            frame:SetClampedToScreen(false)
            MakePanelDraggable(frame)
            if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
                DemodalizePanel(frame)
            end
        end
    end

    if not hasCustomBags and ContainerFrame_GenerateFrame and not Canvas._bagGenHooked then
        Canvas._bagGenHooked = true
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            if frame and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                frame:SetClampedToScreen(false)
                MakePanelDraggable(frame)
            end
        end)
    end

    if not hasCustomMinimap and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"] and MinimapCluster then
        RestoreWorkspacePosition(MinimapCluster)
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

    if not Canvas.showUIPanelHooked and ShowUIPanel then
        Canvas.showUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(frame)
            Canvas:TryMakeFrameDraggable(frame)
        end)
    end
end

function Offhand:UpdateCanvas()
    Canvas:UpdateLayout()
end
