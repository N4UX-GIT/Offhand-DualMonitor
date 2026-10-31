-- Shared World Map presentation, scaling, refocusing, and compatibility recovery.
local _, Offhand = ...
local Map = {}
Offhand.CanvasMapPresentation = Map
local Compatibility = Offhand.CanvasCompatibility
local HasLeatrixMaps = Compatibility.HasLeatrixMaps
local ShouldYieldFrameToClassicUIForever = Compatibility.ShouldYieldFrameToClassicUIForever
local GetWorldMapExternalOwner = Compatibility.GetWorldMapExternalOwner
local IsExternallyPositionedWorldMap = Compatibility.IsExternallyPositionedWorldMap
local ShouldYieldWorldMapToMoveAny = Compatibility.ShouldYieldWorldMap
local IsPanelEvicting = Offhand.CanvasFrameState.IsEvicting

-- TBC's native scroll controller returns physical cursor pixels, then compares
-- them with canvas-local bounds. Offhand's window scaling requires conversion
-- at that boundary. Keep this isolated from Retail/Forever and custom handlers.
local tbcCursorAdapters = setmetatable({}, { __mode = "k" })
function Map.InstallTBCCursorAdapter(map)
    local toc = tonumber(Offhand.tocVersion) or 0
    if Offhand.isForever or toc < 20500 or toc >= 20600
        or not map or not map.ScrollContainer
        or not Offhand.db or not Offhand.db.enabled
        or HasLeatrixMaps() or ShouldYieldWorldMapToMoveAny(map)
        or (InCombatLockdown and InCombatLockdown()) then return false end
    local scroll = map.ScrollContainer
    local native = MapCanvasScrollControllerMixin and MapCanvasScrollControllerMixin.GetCursorPosition
    if type(native) ~= "function" or scroll.GetCursorPosition ~= native
        or type(scroll.GetEffectiveScale) ~= "function" or tbcCursorAdapters[scroll] then return false end
    local function GetScaledCursor(self)
        local x, y = native(self)
        if not Offhand.db or not Offhand.db.enabled or HasLeatrixMaps()
            or ShouldYieldWorldMapToMoveAny(map) then return x, y end
        local scale = self:GetEffectiveScale()
        if type(scale) ~= "number" or scale ~= scale or scale <= 0 or scale >= math.huge then return x, y end
        return x / scale, y / scale
    end
    tbcCursorAdapters[scroll] = GetScaledCursor
    scroll.GetCursorPosition = GetScaledCursor
    return true
end

function Map.InstallFonts(Canvas, services)

    local function IsCoordinateLabelText(text)
        if type(text) ~= "string" or not text:find(":", 1, true) then return false end
        local values = 0
        for _ in text:gmatch("%d+[%.,]?%d*") do
            values = values + 1
            if values >= 2 then return true end
        end
        return false
    end

    function Canvas:RefreshLeatrixMapCoordinateFonts()
        if InCombatLockdown() or not HasLeatrixMaps() then return 0 end
        local map = _G.WorldMapFrame
        if not map then return 0 end

        local refreshed = 0
        local seen = {}
        local function RefreshLabel(region, requireCoordinateText)
            if not region or seen[region] then return false end
            seen[region] = true
            local okType, objectType = pcall(region.GetObjectType, region)
            local okText, label = pcall(region.GetText, region)
            if not okType or objectType ~= "FontString"
                or (requireCoordinateText and (not okText or not IsCoordinateLabelText(label)))
                or not region.GetFont or not region.SetFont then return false end
            local okFont, file, height, flags = pcall(region.GetFont, region)
            local okObject, fontObject = false, nil
            if region.GetFontObject then
                okObject, fontObject = pcall(region.GetFontObject, region)
            end
            fontObject = okObject and fontObject or nil
            if not okFont or not file or not height then return false end
            local ok = pcall(region.SetFont, region, file, height, flags or "")
            if ok and fontObject and region.SetFontObject then
                pcall(region.SetFontObject, region, fontObject)
            end
            if ok then refreshed = refreshed + 1 end
            return ok
        end

        -- Forever Leatrix Maps 1.60.20 enables Blizzard's coordinate overlay and
        -- reparents these three frames into the map canvas. Refer only to Blizzard's
        -- feature-detected overlay fields; no Leatrix namespace or method is used.
        if type(map.overlayFrames) == "table" then
            for _, overlay in ipairs(map.overlayFrames) do
                for _, key in ipairs({"PlayerCoords", "CursorCoords", "CrosshairCoords"}) do
                    local coordinateFrame = type(overlay) == "table" and overlay[key]
                    if coordinateFrame then RefreshLabel(coordinateFrame.Label, false) end
                end
            end
        end

        -- Older Leatrix branches used direct, anonymous WorldMapFrame children.
        if refreshed == 0 and map.GetChildren then
            local children = { pcall(map.GetChildren, map) }
            if table.remove(children, 1) then
                for _, child in ipairs(children) do
                    local bottomAnchored = false
                    local okPoints, points = false, 0
                    if child and child.GetNumPoints then
                        okPoints, points = pcall(child.GetNumPoints, child)
                    end
                    points = okPoints and tonumber(points) or 0
                    for index = 1, points do
                        local ok, point = pcall(child.GetPoint, child, index)
                        if ok and type(point) == "string" and point:find("BOTTOM", 1, true) then
                            bottomAnchored = true
                            break
                        end
                    end

                    if bottomAnchored and child.GetRegions then
                        local regions = { pcall(child.GetRegions, child) }
                        if table.remove(regions, 1) then
                            for _, region in ipairs(regions) do
                                RefreshLabel(region, true)
                            end
                        end
                    end
                end
            end
        end
        self._lastLeatrixCoordinateFontRefreshCount = refreshed
        return refreshed
    end
end

function Map.InstallBehavior(Canvas, services)
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local UnregisterSpecialFrame = services.UnregisterSpecialFrame
    local EvictWorkspacePanelSlot = services.EvictWorkspacePanelSlot
    function Canvas:PreserveExternalWorldMapOpenState(map)
        if not IsExternallyPositionedWorldMap(map) or not map.IsShown or not map:IsShown() then return false end
        if not IsFrameOnWorkspace(map) then
            self:SetWorkspacePanelOpen(map, false)
            RegisterSpecialFrame("WorldMapFrame")
            return false
        end
        self:SetWorkspacePanelOpen(map, true)
        if Offhand.db and Offhand.db.persistentWorkspacePanels ~= false then
            if PlayerMovementFrameFader and PlayerMovementFrameFader.RemoveFrame then
                pcall(function() PlayerMovementFrameFader.RemoveFrame(map) end)
            end
            -- Keep Offhand's Escape and simultaneous-panel behavior, but let
            -- the external addon's OnShow/layout hooks remain the geometry writer.
            UnregisterSpecialFrame("WorldMapFrame")
            EvictWorkspacePanelSlot(map)
        else
            RegisterSpecialFrame("WorldMapFrame")
        end
        return true
    end

    Canvas.PreserveLeatrixWorldMapOpenState = Canvas.PreserveExternalWorldMapOpenState

    function Canvas:UpdateMapMovementBehavior()
        local map = WorldMapFrame
        if not map then return end
        if ShouldYieldWorldMapToMoveAny(map) then return end
        -- Forever routes map-pin mouse actions through restricted Blizzard code.
        -- Do not change the native map event registration on that client; even an
        -- unrelated movement-event mutation can taint the shared map frame before
        -- a player shift-clicks a pin.
        if Offhand.isForever then return end

        if Offhand.db and Offhand.db.enabled and Offhand.db.preventMapCloseOnMove then
            pcall(function() map:UnregisterEvent("PLAYER_STARTED_MOVING") end)
        else
            pcall(function() map:RegisterEvent("PLAYER_STARTED_MOVING") end)
        end
    end

    local function GetDisplayablePlayerMapID()
        if MapUtil and type(MapUtil.GetDisplayableMapForPlayer) == "function" then
            local mapID = MapUtil.GetDisplayableMapForPlayer()
            if mapID then return mapID end
        end
        if C_Map and type(C_Map.GetBestMapForUnit) == "function" then
            return C_Map.GetBestMapForUnit("player")
        end
    end

    function Canvas:RefocusPersistentWorldMap()
        local map = _G.WorldMapFrame
        -- MoveAny owns map geometry, not MapCanvas content. Modern and Classic
        -- clients still need the displayed map ID refreshed while the persistent
        -- frame remains open. Forever keeps its stricter protected-map boundary.
        if ShouldYieldWorldMapToMoveAny(map) and Offhand.isForever then return false end
        if InCombatLockdown() or not map or not map.IsShown or not map:IsShown()
            or IsExternallyPositionedWorldMap(map) or not Offhand.db or not Offhand.db.enabled
            or Offhand.db.persistentWorkspacePanels == false then
            return false
        end

        local workspacePosition = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions.WorldMapFrame
        if not workspacePosition and not IsFrameOnWorkspace(map) then return false end

        local mapID = GetDisplayablePlayerMapID()
        if mapID and type(map.SetMapID) == "function" then
            local currentMapID = type(map.GetMapID) == "function" and map:GetMapID() or nil
            if currentMapID ~= mapID then
                -- Blizzard performs this same SetMapID/ResetZoom sequence from the
                -- native OnShow path. A persistent workspace map never receives a
                -- new OnShow when zoning, so reproduce only that missing refresh.
                map:SetMapID(mapID)
                if type(map.ResetZoom) == "function" then map:ResetZoom() end
                return true
            end
            return false
        end

        -- Original clients pre-dating MapCanvas expose only the legacy global.
        if type(SetMapToCurrentZone) == "function" then
            SetMapToCurrentZone()
            return true
        end
        return false
    end

    function Canvas:RequestPersistentWorldMapRefocus()
        if ShouldYieldWorldMapToMoveAny(_G.WorldMapFrame) and Offhand.isForever then return end
        if not C_Timer or not C_Timer.After then return end
        self._mapZoneRefocusGeneration = (self._mapZoneRefocusGeneration or 0) + 1
        local generation = self._mapZoneRefocusGeneration
        C_Timer.After(0.5, function()
            if generation ~= Canvas._mapZoneRefocusGeneration then return end
            local function Apply()
                if InCombatLockdown() then return end
                Canvas:RefocusPersistentWorldMap()
            end
            if InCombatLockdown() and Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(Apply)
            else
                Apply()
            end
        end)
    end
end

function Map.InstallConfiguration(Canvas, services)
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local WithWorkspace = services.WithWorkspace
    local OnPanelDragStop = services.OnPanelDragStop
    local RestoreWorkspacePosition = services.RestoreWorkspacePosition
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local UnregisterSpecialFrame = services.UnregisterSpecialFrame
    local EvictWorkspacePanelSlot = services.EvictWorkspacePanelSlot
    local function AdjustWorldMapScale(map, delta)
        if ShouldYieldWorldMapToMoveAny(map) then return false end
        if IsWorldMapMaximized(map) then return false end
        if InCombatLockdown() or not IsControlKeyDown() then return false end
        if not Offhand.db or not Offhand.db.enabled or not map then return false end
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
        return true
    end

    function Canvas:ConfigureWorldMap()
        local map = WorldMapFrame
        if InCombatLockdown() or not map or HasLeatrixMaps() or not Offhand.db or not Offhand.db.enabled then return end
        -- Maximized WorldMapFrame is a separate Blizzard-owned layout on every
        -- modern client. Never apply Offhand's windowed scale, anchor, UIPanel
        -- registration, or saved geometry until Blizzard finishes minimizing it.
        if IsWorldMapMaximized(map) then return end
        if ShouldYieldWorldMapToMoveAny(map) then
            self:RepairYieldedWorldMapAnchor(map)
            return
        end

        local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not m or not m.isSpanned then return end

        Map.InstallTBCCursorAdapter(map)

        -- Enable proper parent scaling so the map scales consistently with UIParent
        if not Offhand.isForever and map.SetIgnoreParentScale then
            pcall(function() map:SetIgnoreParentScale(false) end)
        end

        -- Keep the user's normal map in the movable windowed presentation. The
        -- maximized state returned above remains fully native until the player
        -- explicitly minimizes it again.
        if not Offhand.isForever then
            pcall(function()
                if type(GetCVar("miniWorldMap")) == "string" and GetCVar("miniWorldMap") ~= "1" then
                    SetCVar("miniWorldMap", "1")
                end
            end)
        end

        if not Offhand.isForever and not map._OffhandWindowedHook and hooksecurefunc then
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
            if map.Minimize then hooksecurefunc(map, "Minimize", ScheduleWindowed) end
            if map.HookScript then map:HookScript("OnShow", ScheduleWindowed) end
        end

        -- Hook Blizzard's built-in title button drag handlers
        if not Offhand.isForever and WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
            WorldMapTitleButton._OffhandHooked = true
            WorldMapTitleButton:RegisterForDrag("LeftButton")
            WorldMapTitleButton:HookScript("OnDragStart", function(self)
                if InCombatLockdown() or not Offhand.db.enabled
                    or ShouldYieldFrameToClassicUIForever(map) then return end
                map._OffhandDragging = true
            end)
            WorldMapTitleButton:HookScript("OnDragStop", function(self)
                OnPanelDragStop(map)
            end)
        end
        if not Offhand.isForever and WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
            Canvas._titleButtonHooked = true
            hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
                OnPanelDragStop(map)
            end)
        end

        -- Interactive Ctrl + MouseWheel scaling is deliberately unavailable on
        -- Forever. Even an addon-owned control that writes the native map can
        -- contaminate MapCanvas's later protected pin-acquisition path.
        local function OnMapMouseWheel(self, delta)
            AdjustWorldMapScale(map, delta)
        end

        if not Offhand.isForever and not map._OffhandWheelHooked then
            map._OffhandWheelHooked = true
            if map.EnableMouseWheel then map:EnableMouseWheel(true) end
            if map.HookScript then map:HookScript("OnMouseWheel", OnMapMouseWheel) end
        end
        if not Offhand.isForever and WorldMapTitleButton and not WorldMapTitleButton._OffhandWheelHooked then
            WorldMapTitleButton._OffhandWheelHooked = true
            if WorldMapTitleButton.EnableMouseWheel then WorldMapTitleButton:EnableMouseWheel(true) end
            if WorldMapTitleButton.HookScript then WorldMapTitleButton:HookScript("OnMouseWheel", OnMapMouseWheel) end
        end

        -- If map is on the workspace, apply preferred or auto-fit scale
        local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]
        local isWorkspaceMap = pos or (not (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions.WorldMapFrame) and IsFrameOnWorkspace(map))
        if isWorkspaceMap then
            if PlayerMovementFrameFader and PlayerMovementFrameFader.RemoveFrame then
                pcall(function() PlayerMovementFrameFader.RemoveFrame(map) end)
            end
            local userScale = Offhand.db.workspaceMapScale
            local fitScale
            if userScale and userScale ~= "AUTO" and tonumber(userScale) and tonumber(userScale) > 0 then
                fitScale = tonumber(userScale)
            else
                local baseWidth = map:GetWidth() or 610
                if baseWidth <= 0 then baseWidth = 610 end
                local availableWidth = m.workspaceWidth - 24
                fitScale = math.max(0.50, math.min(3.00, availableWidth / baseWidth))
            end
            map:SetScale(fitScale)
            if Offhand.db.persistentWorkspacePanels ~= false then
                UnregisterSpecialFrame("WorldMapFrame")
                EvictWorkspacePanelSlot(map)
            end
        else
            if PlayerMovementFrameFader and PlayerMovementFrameFader.AddDeferredFrame then
                pcall(function()
                    PlayerMovementFrameFader.AddDeferredFrame(
                        map, .5, 1.0, 0.5,
                        function() return not map:IsMaximized() end)
                end)
            end
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
            availableWidth, availableHeight = m.workspaceWidth-24, m.workspaceHeight-24
        end
        local width, height = map:GetWidth(), map:GetHeight()
        if width and height and width > 0 and height > 0 and availableWidth > 0 and availableHeight > 0 then
            local inherited = map:GetEffectiveScale() / map:GetScale() / UIParent:GetEffectiveScale()
            local scale = math.min(map:GetScale(), availableWidth/width/inherited, availableHeight/height/inherited)
            if scale > 0 and scale < math.huge then map:SetScale(scale) end
        end

        if not Offhand.isForever and not map._OffhandPersistenceHooked and map.HookScript then
            map._OffhandPersistenceHooked = true
            map:HookScript("OnShow", function(self)
                local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]) or IsFrameOnWorkspace(self)
                if isWs and (Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) then
                    UnregisterSpecialFrame("WorldMapFrame")
                    if not IsPanelEvicting(self) and C_Timer and C_Timer.After then
                        C_Timer.After(0, function()
                            local saved = Offhand.db and Offhand.db.savedWorkspacePositions
                                and Offhand.db.savedWorkspacePositions["WorldMapFrame"]
                            if saved and self.IsShown and self:IsShown() then
                                RestoreWorkspacePosition(self)
                                Canvas:RepairShownWorkspacePanels(self)
                            end
                        end)
                    end
                else
                    RegisterSpecialFrame("WorldMapFrame")
                end
            end)
            map:HookScript("OnHide", function(self)
                if IsPanelEvicting(self) or not C_Timer or not C_Timer.After then return end
                C_Timer.After(0, function()
                    Canvas:RepairShownWorkspacePanels(self)
                end)
            end)
        end
    end
end

function Map.InstallBootstrap(Canvas, services)
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local WithWorkspace = services.WithWorkspace
    function Canvas:RepairYieldedWorldMapAnchor(frame, metrics)
        if not frame or GetWorldMapExternalOwner() ~= "MoveAny"
            or IsWorldMapMaximized(frame)
            or (InCombatLockdown and InCombatLockdown())
            or not Offhand.db or not Offhand.db.enabled
            or not frame.IsShown or not frame:IsShown() then return false end
        if frame.IsForbidden then
            local inspected, forbidden = pcall(frame.IsForbidden, frame)
            if not inspected or forbidden then return false end
        end

        local workspacePosition = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions.WorldMapFrame
        if workspacePosition and Offhand.db.persistentWorkspacePanels ~= false
            and PlayerMovementFrameFader and PlayerMovementFrameFader.RemoveFrame then
            pcall(function() PlayerMovementFrameFader.RemoveFrame(frame) end)
        end

        local inspected, left, top = pcall(function()
            return frame:GetLeft(), frame:GetTop()
        end)
        if not inspected or left or top then return false end

        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics()))
        if not metrics or not metrics.isSpanned or not UIParent then return false end

        local mainPosition = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions.WorldMapFrame
        local target = workspacePosition and {
            left = metrics.workspaceLeft, right = metrics.workspaceRight,
            bottom = metrics.workspaceBottom, top = metrics.workspaceTop,
        } or {
            left = metrics.gameLeft, right = metrics.gameRight,
            bottom = metrics.gameBottom, top = metrics.gameTop,
        }
        local position = workspacePosition or mainPosition
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        if parentScale <= 0 or frameScale <= 0 then return false end
        local scaleFactor = frameScale / parentScale
        local width = ((frame.GetWidth and frame:GetWidth()) or 702) * scaleFactor
        local height = ((frame.GetHeight and frame:GetHeight()) or 534) * scaleFactor
        if width <= 0 then width = 702 * scaleFactor end
        if height <= 0 then height = 534 * scaleFactor end

        local inset = 12
        local minX = target.left + inset
        local maxX = math.max(minX, target.right - width - inset)
        local minY = target.bottom + height + inset
        local maxY = math.max(minY, target.top - inset)
        local targetX = position and tonumber(position.x)
            or target.left + (target.right - target.left - width) / 2
        local targetY = position and tonumber(position.y)
            or target.bottom + (target.top - target.bottom + height) / 2

        if workspacePosition then
            local savedWidth = tonumber(workspacePosition.canvasWidth)
            local savedLeft = tonumber(workspacePosition.canvasLeft) or 0
            if savedWidth and savedWidth > 0 and metrics.workspaceWidth > 0 then
                targetX = metrics.workspaceLeft
                    + (targetX - savedLeft) * metrics.workspaceWidth / savedWidth
            end
            local savedHeight = tonumber(workspacePosition.canvasHeight)
            local savedBottom = tonumber(workspacePosition.canvasBottom) or 0
            if savedHeight and savedHeight > 0 and metrics.workspaceHeight > 0 then
                targetY = metrics.workspaceBottom
                    + (targetY - savedBottom) * metrics.workspaceHeight / savedHeight
            end
        end

        targetX = math.max(minX, math.min(targetX, maxX))
        targetY = math.max(minY, math.min(targetY, maxY))
        local pointFactor = parentScale / frameScale
        local anchored = pcall(function()
            if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                targetX * pointFactor, targetY * pointFactor)
        end)
        if not anchored then return false end

        -- The first MapCanvas layout can finish before the bootstrap anchor exists,
        -- leaving its scroll child sized for a zero/old rectangle. Re-run only the
        -- public mixin refresh methods after the new anchor has settled; later opens
        -- already have geometry and never enter this path.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if not frame.IsShown or not frame:IsShown() then return end
                if type(frame.OnCanvasSizeChanged) == "function" then
                    pcall(frame.OnCanvasSizeChanged, frame)
                end
                if type(frame.ResetZoom) == "function" then
                    pcall(frame.ResetZoom, frame)
                end
                if type(frame.RefreshAllDataProviders) == "function" then
                    pcall(frame.RefreshAllDataProviders, frame)
                end
            end)
        end
        return true
    end
end


