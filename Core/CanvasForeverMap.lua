-- Forever World Map observation, deferred restoration, and external drag controls.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasForeverMap = Adapter

local fadeChecked, releaseFade, loggingOut
local restoreOpenMapRefresh

local function Finite(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value > -math.huge and value < math.huge
end

local function ParseMajorVersion(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return nil end
    end
    if type(value) == "number" and value == value and value >= 0 and value < math.huge then
        return math.floor(value)
    end
    if type(value) ~= "string" then return nil end
    return tonumber(value:match("^v?(%d+)%."))
end

-- OpenMap's camera glides for 0.4 seconds. A centered camera follows the
-- player; browsing away pauses follow until the player centers it again.
function Adapter.UpdateOpenMapFollow(map, state)
    local api = _G.OpenMapAPI
    if type(api) ~= "table" or api.major ~= 1
        or type(api.GetView) ~= "function" or type(api.WorldFromMap) ~= "function"
        or type(api.ShowWorld) ~= "function" or type(api.IsStitched) ~= "function"
        or not api.IsStitched()
        or Offhand.CanvasCompatibility.GetWorldMapExternalOwner() ~= "OpenMap"
        or Offhand.db.persistentWorkspacePanels == false or InCombatLockdown() or IsInInstance()
        or not Offhand.Viewport:GetMetrics().isSpanned or not Offhand.Canvas.IsFrameOnWorkspace(map) then
        state.u = nil
        return
    end
    local id = C_Map.GetBestMapForUnit("player")
    if not Finite(id) then state.u = nil; return end
    local position = C_Map.GetPlayerMapPosition(id, "player")
    if (issecretvalue and issecretvalue(position)) or not position then state.u = nil; return end
    local x, y = position:GetXY()
    if not Finite(x) or not Finite(y) then state.u = nil; return end
    local u, v = api.WorldFromMap(id, x, y)
    local cu, cv, zoom = api.GetView()
    if not Finite(u) or not Finite(v) or not Finite(cu) or not Finite(cv)
        or not Finite(zoom) or zoom <= 0 then state.u = nil; return end
    if map:IsMouseOver() and IsMouseButtonDown("LeftButton") then state.u = nil; return end
    local offset = math.max(math.abs(cu-u), math.abs(cv-v)) * zoom
    if state.u and math.abs(state.zoom-zoom) > 0.00001 then
        state.u, state.v, state.zoom = cu, cv, zoom
        return
    end
    if state.u and math.max(math.abs(cu-state.u), math.abs(cv-state.v)) * zoom > 0.015 then
        state.u = nil
    end
    if not state.u and offset > 0.015 then return end
    if offset > 0.0005 then
        if not api.ShowWorld(u, v) then state.u = nil; return end
        cu, cv = u, v
    end
    state.u, state.v, state.zoom = cu, cv, zoom
end

local function ReadOpenMapFade()
    if not Offhand.CanvasCompatibility.IsAddonLoaded("OpenMap") then return end
    local module, db = Offhand.CanvasCompatibility.GetOpenMapWorldMapModule()
    if module and module.enabled and type(module.RefreshExtras) == "function"
        and type(db.moveFade) == "number" and db.moveFade >= 0 and db.moveFade <= 0.9 then
        return db, module
    end
end

local function ReadMapUtilsFade()
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local db = _G.MAUTTAB
    local compatibility = Offhand.CanvasCompatibility
    if type(db) ~= "table" or not getMetadata
        or not compatibility.IsAddonLoaded("MapUtils") then return end
    local version = getMetadata("MapUtils", "Version")
    if ParseMajorVersion(version) == 1
        and (db.WORLDMAPFADE == nil or type(db.WORLDMAPFADE) == "boolean") then return db end
end

local function ReadMapWise(map)
    local api = _G.MapWiseAPI
    if type(api) ~= "table" or ParseMajorVersion(api.version) ~= 2
        or not Offhand.CanvasCompatibility.IsAddonLoaded("MapWise") then return end
    local db, integration = api.db, api.Integration
    if type(db) == "table" and db == _G.MapWiseAtlasDB
        and type(integration) == "table" and integration.native == map then return db, api.MapWiseUI end
end

local function ReadMapWiseFade(map)
    local db = ReadMapWise(map)
    if db and type(db.fadeMapWhileMoving) == "boolean" then return db end
end

-- These reviewed implementations read their own fade preference at runtime.
-- Let their existing update paths apply the change to the map.
local addonFades = {
    {name = "OpenMap", read = ReadOpenMapFade, key = "moveFade", opaque = 0},
    {name = "MapUtils", read = ReadMapUtilsFade, key = "WORLDMAPFADE", opaque = false},
    {name = "MapWise", read = ReadMapWiseFade, key = "fadeMapWhileMoving", opaque = false},
}

function Adapter.SupportsAddonMovementFade(name, map)
    if not map then return false end
    for _, fade in ipairs(addonFades) do
        if fade.name == name then
            local ok, db = pcall(fade.read, map)
            return ok and db ~= nil
        end
    end
    return false
end

local function RestoreAddonFade(fade)
    local db = fade.db
    if not db then return end
    if db[fade.key] == fade.opaque then db[fade.key] = fade.previous end
    fade.db, fade.previous = nil, nil
end

local function UpdateAddonFades(map)
    local openMapActive
    for _, fade in ipairs(addonFades) do
        local ok, db, module = pcall(fade.read, map)
        if not ok then db = nil end
        if fade.db ~= db then RestoreAddonFade(fade) end
        if db and db[fade.key] ~= fade.opaque then
            fade.db, fade.previous = db, db[fade.key]
            db[fade.key] = fade.opaque
            if module then restoreOpenMapRefresh = module end
        end
        if module then openMapActive = true end
    end
    return openMapActive
end

local function RefreshReleasedOpenMapFade(map)
    local module = restoreOpenMapRefresh
    if not module then return end
    if not map then restoreOpenMapRefresh = nil; return end
    if InCombatLockdown and InCombatLockdown() then return end
    restoreOpenMapRefresh = nil
    local ok, db, activeModule = pcall(ReadOpenMapFade)
    -- Its own refresh may have hidden the fader while the override was active.
    -- Re-enable it through the vendor for a map that is still open.
    if ok and db and db.moveFade ~= 0 and activeModule == module then pcall(module.RefreshExtras) end
end

local function ReadMapFade()
    local read = C_CVar and C_CVar.GetCVarBool or GetCVarBool
    if not read then return nil end
    local ok, value = pcall(read, "mapFade")
    if ok and type(value) == "boolean" and not (issecretvalue and issecretvalue(value)) then return value end
end

local function ReleaseNativeFade()
    fadeChecked = false
    if releaseFade and releaseFade() then releaseFade = nil end
end

function Adapter.ReleaseMovementFade(leaving, map)
    if leaving then loggingOut = true end
    ReleaseNativeFade()
    for _, fade in ipairs(addonFades) do RestoreAddonFade(fade) end
    RefreshReleasedOpenMapFade(not leaving and map)
end

function Adapter.UpdateMovementFade(map, spanned)
    if loggingOut then return end
    local canvas = Offhand.Canvas
    local eligible = Offhand.isForever and spanned and map and map.IsShown and map:IsShown()
        and (not map.IsVisible or map:IsVisible())
        and not (map.IsMaximized and map:IsMaximized())
        and not (map.IsForbidden and map:IsForbidden())
        and canvas and canvas.IsFrameOnWorkspace
    local ok, workspace
    if eligible then ok, workspace = pcall(canvas.IsFrameOnWorkspace, map) end
    if not ok or not workspace then
        Adapter.ReleaseMovementFade(false, map)
        return
    end
    -- OpenMap holds mapFade itself while its world map is active.
    if UpdateAddonFades(map) then
        ReleaseNativeFade()
        return
    end
    if releaseFade or fadeChecked then return end
    local original = ReadMapFade()
    if original == nil then return end
    fadeChecked = true
    if not original then return end

    -- Blizzard's predicate reads mapFade while moving. Override the CVar only
    -- for the visible workspace map so the protected shared fader stays native.
    local temporary, remove = C_CVar and C_CVar.SetTempCVar, C_CVar and C_CVar.RemoveTempCVar
    if temporary and remove then
        local function RemoveOverride()
            local ok, result = pcall(remove, "mapFade")
            return ok and result ~= false
        end
        local set = pcall(temporary, "mapFade", "0")
        if set and ReadMapFade() == false then
            releaseFade = RemoveOverride
            return
        end
        if set then RemoveOverride() end
    end
    local write = C_CVar and C_CVar.SetCVar or SetCVar
    if not write then return end
    local written, result = pcall(write, "mapFade", "0")
    if written and result ~= false and ReadMapFade() == false then
        releaseFade = function()
            local current = ReadMapFade()
            if current == nil then return false end
            if current then return true end
            local restored, success = pcall(write, "mapFade", "1")
            return restored and success ~= false and ReadMapFade() == true
        end
    end
end

-- Spoken Places attaches its panel and reopen tab to the map's right edge.
-- Constrain the visible attachment without replacing those anchors or saving
-- a different collapsed state in the provider's profile.
local placesClamps = {}

local function PlacesOverlay(frame, active, state, key)
    if not frame then return end
    local strata = frame:GetFrameStrata()
    if active then
        if strata == "LOW" or strata == "MEDIUM" or strata == "HIGH" or strata == "BACKGROUND" then
            state[key] = strata
            frame:SetFrameStrata("DIALOG")
        end
    elseif state[key] then
        if key == "stageStrata" and state.stageLevel then
            if frame:GetFrameLevel() == state.appliedStageLevel then frame:SetFrameLevel(state.stageLevel) end
            state.stageLevel, state.appliedStageLevel = nil, nil
        end
        if strata == "DIALOG" then frame:SetFrameStrata(state[key]) end
        state[key] = nil
    end
end

-- The provider stretches the panel between two points on the same map edge.
-- A map can be taller than its monitor before the player pins or fits it.
local function FitPlacesHeight(frame, metrics, state, factor)
    if frame ~= _G.SpokenPlacesPanel then return end
    local point, edge, relative, x, y = frame:GetPoint(2)
    if point ~= "BOTTOMLEFT" or relative ~= "BOTTOMRIGHT" or not edge then
        state.heightAnchor = nil
        return
    end
    local bottom = state.heightAnchor
    if bottom and (edge ~= bottom.edge or x ~= bottom.x or math.abs(y-bottom.applied) > .01) then
        state.heightAnchor, bottom = nil, nil
    end
    local originalY = bottom and bottom.y or y
    local desired = originalY
    if metrics then
        local topPoint, topEdge, topRelative, _, topY = frame:GetPoint(1)
        if topPoint == "TOPLEFT" and topEdge == edge and topRelative == "TOPRIGHT" then
            local height = edge:GetHeight() * edge:GetEffectiveScale() / frame:GetEffectiveScale()
            desired = math.max(originalY, height + topY - metrics.workspaceHeight * factor)
        end
    end
    if math.abs(y-desired) > .01 then frame:SetPoint(point, edge, relative, x, desired) end
    if desired > originalY + .01 then
        if not bottom or bottom.applied ~= desired then
            state.heightAnchor = {edge=edge, x=x, y=originalY, applied=desired}
        end
    else
        state.heightAnchor = nil
    end
end
local function UpdatePlacesClamp(frame, map, metrics)
    if not frame or frame:IsForbidden() or frame:IsProtected() then return end
    local state = placesClamps[frame]
    local active = metrics and frame:IsVisible() and frame:GetParent() == map
    if not active and not state then return end

    local left, right, top, bottom = frame:GetClampRectInsets()
    if state and (left ~= state.left or right ~= state.right
        or top ~= state.top or bottom ~= state.bottom or not frame:IsClampedToScreen()) then
        -- Another owner changed the clamp. Yield until the map leaves Offhand.
        state.superseded = true
    end
    if not active then
        placesClamps[frame] = nil
        PlacesOverlay(frame, false, state, "strata")
        PlacesOverlay(frame.stage, false, state, "stageStrata")
        FitPlacesHeight(frame, nil, state)
        if state and not state.superseded then
            frame:SetClampRectInsets(unpack(state.original))
            frame:SetClampedToScreen(state.wasClamped)
        end
        return
    end
    if state and state.superseded then return end
    state = state or {original = {left, right, top, bottom}, wasClamped = frame:IsClampedToScreen()}
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    FitPlacesHeight(frame, metrics, state, factor)
    local l = math.min(state.original[1], -metrics.workspaceLeft * factor)
    local r = math.max(state.original[2], (UIParent:GetWidth() - metrics.workspaceRight) * factor)
    local t = math.max(state.original[3], (UIParent:GetHeight() - metrics.workspaceTop) * factor)
    local b = math.min(state.original[4], -metrics.workspaceBottom * factor)
    if math.abs(l-left) > .01 or math.abs(r-right) > .01
        or math.abs(t-top) > .01 or math.abs(b-bottom) > .01 then
        frame:SetClampRectInsets(l, r, t, b)
    end
    if not frame:IsClampedToScreen() then frame:SetClampedToScreen(true) end
    local mapRight, panelLeft = map:GetRight(), frame:GetLeft()
    local overlap = mapRight and panelLeft and mapRight * map:GetEffectiveScale()
        > panelLeft * frame:GetEffectiveScale() + .5
    PlacesOverlay(frame, overlap, state, "strata")
    PlacesOverlay(frame.stage, overlap, state, "stageStrata")
    -- Keep the provider's separately drawn model above its parchment.
    if overlap and frame.stage and state.stageStrata and frame.stage:GetFrameLevel() <= frame:GetFrameLevel() then
        state.stageLevel = state.stageLevel or frame.stage:GetFrameLevel()
        state.appliedStageLevel = frame:GetFrameLevel() + 1
        frame.stage:SetFrameLevel(state.appliedStageLevel)
    end
    -- Read back the client's native floating-point values for ownership checks.
    state.left, state.right, state.top, state.bottom = frame:GetClampRectInsets()
    placesClamps[frame] = state
end

-- The windowed quest list stretches between the map's two right corners.
-- Raise only its lower attachment when the scroll area runs below Offhand.
-- Leave the map provider's chosen scale, window size and position alone.
local questFoot
local function FitQuestList(map, metrics)
    local list = map.QuestLog
    if not list or list ~= _G.QuestMapFrame or list:IsForbidden() or list:IsProtected()
        or list:GetNumPoints() ~= 2 then questFoot = nil; return end
    local topPoint, topFrame, topRelative = list:GetPoint(1)
    local point, relative, corner, x, y = list:GetPoint(2)
    if topPoint ~= "TOPRIGHT" or topFrame ~= map or topRelative ~= "TOPRIGHT"
        or point ~= "BOTTOMRIGHT" or relative ~= map or corner ~= "BOTTOMRIGHT" then
        questFoot = nil
        return
    end
    if questFoot and (questFoot.frame ~= list or math.abs(y - questFoot.applied) > .01) then questFoot = nil end
    local original = questFoot and questFoot.original or y
    local desired = original
    if metrics and list:IsVisible() then
        local factor = list:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local bottom, top = map:GetBottom(), list:GetTop()
        if factor > 0 and bottom and top and top * factor > metrics.workspaceBottom + 24 then
            local mapBottom = bottom * map:GetEffectiveScale() / UIParent:GetEffectiveScale()
            desired = math.max(original, (metrics.workspaceBottom + 3 - mapBottom) / factor)
        end
    end
    if math.abs(y - desired) > .01 then list:SetPoint(point, relative, corner, x, desired) end
    if desired > original + .01 then
        if not questFoot or math.abs(questFoot.applied - desired) > .01 then
            questFoot = {frame = list, original = original, applied = desired}
        end
    else
        questFoot = nil
    end
end

function Adapter.GetDragHandleBounds(map, factor)
    local left, top = map:GetLeft(), map:GetTop()
    if not left or not top then return end
    return left * factor + 8, top * factor,
        math.max(48, ((map.GetWidth and map:GetWidth()) or 610) * factor - 64),
        math.max(18, 28 * factor)
end

function Adapter.Install(Canvas, services)
    local Compatibility = Offhand.CanvasCompatibility
    local FrameState = Offhand.CanvasFrameState
    local SupportsExternalWorldMapEscapeProtection = Compatibility.SupportsExternalWorldMapEscapeProtection
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
    local function NativeGamepadOwnsMap()
        local presentation = Offhand.CanvasMapPresentation
        return presentation and presentation.IsNativeGamepadOwned(Canvas) or false
    end

    local function ReadNativeClosePaths(map)
        local inPanelSlot = Offhand.CanvasPanelLifecycle.OccupiesPanelSlot(map)
        if UISpecialFrames then
            for _, name in pairs(UISpecialFrames) do
                if name == "WorldMapFrame" then return inPanelSlot, true end
            end
        end
        return inPanelSlot, false
    end

    local function InstallMapWisePositionGuard(map, state)
        local db, vendor = ReadMapWise(map)
        if not db or type(vendor) ~= "table" or type(vendor.ApplyWindowPosition) ~= "function" then return end

        local applyWindowPosition = vendor.ApplyWindowPosition
        vendor.ApplyWindowPosition = function(self, ...)
            local profile = Offhand.db
            if not profile or not profile.enabled or not map:IsShown() or (map.IsMaximized and map:IsMaximized())
                or NativeGamepadOwnsMap() or ShouldYieldWorldMapToMoveAny(map) or InCombatLockdown()
                or FrameState.IsDragging(map) or self.dragging or self.positioning or self.resizeDrag
                or (map.IsForbidden and map:IsForbidden()) then return applyWindowPosition(self, ...) end

            local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
            if not metrics or not metrics.isSpanned then return applyWindowPosition(self, ...) end

            local persistence = Offhand.CanvasPersistence
            local workspace = profile.savedWorkspacePositions and profile.savedWorkspacePositions.WorldMapFrame
            local mainhand = profile.savedMainPositions and profile.savedMainPositions.WorldMapFrame
            if type(workspace) == "table" and workspace.autoRoute and not metrics.workspaceRegions then workspace = nil end
            if type(mainhand) == "table" and mainhand.autoRoute and not metrics.workspaceRegions then mainhand = nil end
            local onWorkspace = persistence.IsPosition(workspace)
            local position = onWorkspace and workspace or mainhand
            local firstLayout = not state.mapWiseOpened
            state.mapWiseOpened = true
            if not persistence.IsPosition(position) then
                local previous = state.mapWisePlacement
                if firstLayout or not previous or previous.vendorPosition ~= db.compactPosition then
                    return applyWindowPosition(self, ...)
                end
                onWorkspace, position = previous.onWorkspace, previous
            end

            -- MapWise invokes this method after its compact layout, including
            -- tabs with identical dimensions. Skip only its passive anchor
            -- replay. Fit on the independent observer, outside the click or
            -- native map stack. The vendor's move/resize/reset paths are separate.
            state.mapWiseLayout = { position = position, onWorkspace = onWorkspace,
                vendorPosition = db.compactPosition }
            if self.UpdateWindowResetIcon then self:UpdateWindowResetIcon() end
        end
        state.mapWisePositionGuard = vendor
    end

    local function UpdateMapWiseLayout(map, state, shown, maximized)
        local vendor = state.mapWisePositionGuard
        if not vendor then return end
        local db = ReadMapWise(map)
        if not db then return end

        if not shown or maximized or NativeGamepadOwnsMap() or ShouldYieldWorldMapToMoveAny(map)
            or FrameState.IsDragging(map) or vendor.dragging or vendor.resizeDrag then
            state.mapWiseLayout, state.mapWisePlacement = nil, nil
            if not shown then state.mapWiseOpened = nil end
            return
        end
        if InCombatLockdown() then return end
        local placement = GetPanelPhysicalPlacement(map)
        local layout = state.mapWiseLayout
        state.mapWiseLayout = nil
        if placement and layout and layout.vendorPosition == db.compactPosition then
            local metrics = WithWorkspace(Offhand.Viewport:GetMetrics())
            if layout.onWorkspace and Offhand.WorkspaceRegions then
                metrics = Offhand.WorkspaceRegions:ForFrame(metrics, map, layout.position)
            end
            if metrics and metrics.isSpanned then
                Offhand.CanvasMapPresentation.FitWindow(map, metrics, layout.onWorkspace)
                placement = GetPanelPhysicalPlacement(map)
                if placement then
                    local x, y
                    local persistence = Offhand.CanvasPersistence
                    if layout.onWorkspace then
                        x, y = persistence.ResolveWorkspacePosition(
                            metrics, layout.position, placement.width, placement.height, false)
                    else
                        x, y = persistence.ClampWorkspacePoint({
                            workspaceLeft = metrics.gameLeft, workspaceRight = metrics.gameRight,
                            workspaceBottom = metrics.gameBottom, workspaceTop = metrics.gameTop,
                        }, layout.position.x, layout.position.y, placement.width, placement.height)
                    end
                    if x and (math.abs(placement.x - x) > 0.01 or math.abs(placement.y - y) > 0.01) then
                        map:ClearAllPoints()
                        map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / placement.factor, y / placement.factor)
                        placement = GetPanelPhysicalPlacement(map)
                    end
                end
            end
        end
        if placement and (placement.onWorkspace or placement.onMainhand) then
            placement.vendorPosition = db.compactPosition
            state.mapWisePlacement = placement
        else
            state.mapWisePlacement = nil
        end
    end

    -- Forever's map-pin sharing path is protected. A drag handler parented to the
    -- World Map, or attached to its native title/close controls, taints the same
    -- widget tree used by Blizzard's Shift-click link insertion. Provide the map's
    -- drag affordance from an independent UIParent child and follow the map by
    -- reading geometry only. The handle never becomes a child or anchor dependent
    -- of WorldMapFrame and no script is installed on any native map object.
    local function QueueForeverWorldMapSettlement(map, state, shown, forcePanelTransaction)
        if not Offhand.isForever or not map or not state then return end
        if NativeGamepadOwnsMap() then
            if not state.nativeGamepad then
                state.nativeGamepad = true
                state.settlementGeneration = (state.settlementGeneration or 0) + 1
                state.resumeSettlement = nil
                state.observedShown = nil
                state.observedMaximized = nil
            end
            return
        end
        state.nativeGamepad = nil
        if shown and map.IsMaximized and map:IsMaximized() then
            if not state.observedMaximized then
                state.settlementGeneration = (state.settlementGeneration or 0) + 1
            end
            state.observedShown, state.observedMaximized = true, true
            return
        elseif state.observedMaximized then
            state.observedMaximized = nil
            if shown then state.observedShown = nil end
        end
        local persistent = Offhand.db and Offhand.db.persistentWorkspacePanels ~= false
        local persistenceChanged = shown and state.observedPersistence ~= persistent
        state.observedPersistence = shown and persistent
        if forcePanelTransaction then
            if not shown then return end
            state.observedShown = true
        elseif state.observedShown == nil then
            state.observedShown = shown
            -- The map begins hidden during login even when the previous session
            -- persisted it as open. Do not reinterpret that construction state as
            -- an explicit close before RestorePersistentFrames gets its turn.
            if not shown then return end
        elseif state.observedShown == shown and not persistenceChanged then
            return
        else
            state.observedShown = shown
        end

        if not shown then
            state.settlementGeneration = (state.settlementGeneration or 0) + 1
            state.resumeSettlement = nil
            Canvas:SetWorkspacePanelOpen(map, false)
            if SupportsExternalWorldMapEscapeProtection(map) and (not Offhand.db or not Offhand.db.enabled
                or Offhand.db.persistentWorkspacePanels == false) then
                RegisterSpecialFrame("WorldMapFrame")
            end
            return
        end

        if SupportsExternalWorldMapEscapeProtection(map) then
            Canvas:PreserveExternalWorldMapOpenState(map)
            return
        end

        state.settlementGeneration = (state.settlementGeneration or 0) + 1
        local generation = state.settlementGeneration
        local function ResumeAfterCombat()
            if generation == state.settlementGeneration and map:IsShown() and not FrameState.IsDragging(map) then
                QueueForeverWorldMapSettlement(map, state, true, true)
            end
        end
        local function Settle()
            if generation ~= state.settlementGeneration
                or NativeGamepadOwnsMap()
                or ShouldYieldWorldMapToMoveAny(map)
                or not Offhand.db or not Offhand.db.enabled
                or not map.IsShown or not map:IsShown()
                or (map.IsMaximized and map:IsMaximized()) then return end
            if InCombatLockdown() then
                if Offhand.RunOrQueueCombat then
                    state.resumeSettlement = ResumeAfterCombat
                    if not state.combatSettlementQueued then
                        state.combatSettlementQueued = true
                        Offhand:RunOrQueueCombat(function()
                            state.combatSettlementQueued = nil
                            local resume = state.resumeSettlement
                            state.resumeSettlement = nil
                            -- Blizzard can run a second native layout after regeneration.
                            -- Start the usual bounded retries on the following frame.
                            if resume then
                                if C_Timer and C_Timer.After then C_Timer.After(0, resume) else resume() end
                            end
                        end)
                    end
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
            else
                Canvas:RescuePanelFromVoid(map)
            end
            Canvas:RepairShownWorkspacePanels(map)
            local onWorkspace = workspacePosition or (not mainPosition and Canvas.IsFrameOnWorkspace
                and Canvas.IsFrameOnWorkspace(map))
            if onWorkspace and Offhand.db.persistentWorkspacePanels ~= false then
                -- The native window can already open on Offhand before the
                -- user saves a placement. Protect that view without saving it.
                -- ShowUIPanel can reclaim the center slot after the first geometry
                -- restore. Reassert Escape ownership on every delayed settlement.
                UnregisterSpecialFrame("WorldMapFrame")
                EvictWorkspacePanelSlot(map)
            elseif onWorkspace then
                -- A detached map has no UIPanel slot for Blizzard to close.
                local inPanelSlot, specialFrame = ReadNativeClosePaths(map)
                if not inPanelSlot and not specialFrame then RegisterSpecialFrame("WorldMapFrame") end
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
        if Offhand.isForever and Offhand.db and Offhand.db.enabled
            and not (InCombatLockdown and InCombatLockdown())
            and not NativeGamepadOwnsMap() and exceptFrame
            and (exceptFrame == _G.FlightMapFrame or exceptFrame == _G.TaxiFrame)
            and exceptFrame.IsShown and exceptFrame:IsShown() then
            -- Flight placement must survive a failed/unavailable drag grip.
            -- The native transaction already opened the interaction: recover
            -- its root only, without showing a shell or adding native scripts.
            local name = exceptFrame.GetName and exceptFrame:GetName()
            local db = Offhand.db
            local saved = db and ((db.savedWorkspacePositions and db.savedWorkspacePositions[name])
                or (db.savedMainPositions and db.savedMainPositions[name]))
            if saved then
                RestoreWorkspacePosition(exceptFrame)
            elseif Canvas.PlacePanelOnMainhand then
                -- The shared transaction already has bounded settlement passes.
                -- Do not add per-frame generation markers to this MapCanvas root.
                Canvas:PlacePanelOnMainhand(exceptFrame, nil, nil, true)
            end
        end
        local map = _G.WorldMapFrame
        if IsForeverWorldMap(map) and map.IsShown and map:IsShown() then
            QueueForeverWorldMapSettlement(
                map, GetForeverWorldMapState(map), true, true)
        end
        Canvas:RepairShownWorkspacePanels(exceptFrame, skipBagCapture)
        Canvas:RepairShownSocialCommunityPanels()
    end

    local function RepairAfterPanelHide(closedFrame)
        local function Repair()
            if Offhand._loggingOut or Offhand._openPanelsCapturedForTransition then return end
            RepairUIPanelTransaction(closedFrame, true)
            Canvas:RepairDefaultForeverSlots()
        end
        -- Forever also dispatches TAXIMAP_CLOSED at exit. Let the transition
        -- start before repairing peers or re-showing a native Character panel.
        if not (Offhand.isForever and closedFrame and closedFrame == _G.TaxiFrame) then
            Repair()
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, Repair)
            C_Timer.After(0.10, Repair)
        end
    end

    local function AttachForeverWorldMapDragHandle(map)
        if not IsForeverWorldMap(map) or not CreateFrame or not UIParent then return false end
        if ShouldYieldWorldMapToMoveAny(map) and not SupportsExternalWorldMapEscapeProtection(map) then return false end
        local state = GetForeverWorldMapState(map)
        if Offhand.OpenMapRecovery and Compatibility.GetWorldMapExternalOwner() == "OpenMap" then
            Offhand.OpenMapRecovery:ObserveUserDrag(map)
        end
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
                    if NativeGamepadOwnsMap() or InCombatLockdown()
                        or not map.IsShown or not map:IsShown() then return end
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
        local handlePoint, handleX, handleY, handleWidth, handleHeight
        local handleMouseEnabled = false
        local returnVisible, returnX, returnY = false

        -- Keep observing while parked so the next map show is still detected.
        -- The handle is ours, so unchanged geometry needs no frame writes.
        local function PlaceDragHandle(left, top, width, height)
            local enabled = left ~= nil
            local point = enabled and "TOPLEFT" or "BOTTOMLEFT"
            if not enabled then left, top, width, height = -100, -100, 1, 1 end
            if point ~= handlePoint or left ~= handleX or top ~= handleY then
                if handle.ClearAllPoints and handle.SetPoint then
                    handle:ClearAllPoints()
                    handle:SetPoint(point, UIParent, "BOTTOMLEFT", left, top)
                end
                handlePoint, handleX, handleY = point, left, top
            end
            if width ~= handleWidth or height ~= handleHeight then
                if handle.SetSize then handle:SetSize(width, height) end
                handleWidth, handleHeight = width, height
            end
            if enabled ~= handleMouseEnabled then
                if handle.EnableMouse then handle:EnableMouse(enabled) end
                handleMouseEnabled = enabled
            end
        end

        local function SetReturnVisible(visible)
            if not returnButton or returnVisible == visible then return end
            if visible and returnButton.Show then returnButton:Show() end
            if not visible and returnButton.Hide then returnButton:Hide() end
            returnVisible = visible
        end

        local pendingWorkspaceDrop
        local combatPlacementRemaining
        local follow = {}
        local followElapsed = 0
        local function UpdateHandle(_, elapsed)
            local mapShown = Offhand.db and Offhand.db.enabled
                and map.IsShown and map:IsShown()
            local maximized = mapShown and map.IsMaximized and map:IsMaximized()
            if mapShown and not maximized and _G.OpenMapAPI then
                followElapsed = followElapsed + elapsed
                if followElapsed >= 0.5 then
                    followElapsed = 0
                    if NativeGamepadOwnsMap() or map:IsForbidden() or not map:IsVisible() then
                        follow.u = nil
                    else
                        Adapter.UpdateOpenMapFollow(map, follow)
                    end
                end
            else
                follow.u, followElapsed = nil, 0
            end
            if _G.MapWiseAPI and not state.mapWisePositionGuard then InstallMapWisePositionGuard(map, state) end
            if not mapShown then state.mapWiseOpened, state.mapWiseLayout, state.mapWisePlacement = nil, nil, nil end
            QueueForeverWorldMapSettlement(map, state, mapShown and true or false)
            elapsedSinceUpdate = elapsedSinceUpdate + (tonumber(elapsed) or 0)
            if pendingWorkspaceDrop then
                -- A native panel layout can land after the first frame following
                -- mouse-up. Watch only through the next normal handle update.
                local positions = mapShown and Offhand.db.savedWorkspacePositions
                if not positions or positions.WorldMapFrame ~= pendingWorkspaceDrop or maximized
                    or NativeGamepadOwnsMap() or Compatibility.GetWorldMapExternalOwner()
                    or state.mapWisePositionGuard then
                    pendingWorkspaceDrop = nil
                elseif not InCombatLockdown() then
                    local placement = GetPanelPhysicalPlacement(map)
                    if placement and not PlacementMatchesPosition(placement, pendingWorkspaceDrop) then
                        RestoreWorkspacePosition(map)
                    end
                    if elapsedSinceUpdate >= 0.10 then pendingWorkspaceDrop = nil end
                end
            end
            local combatCompact = mapShown and not maximized and Offhand.db.keepMapToggleOpen and InCombatLockdown()
            if combatCompact then
                -- Observe the first rendered frame and the short native reflow
                -- that follows. The slower drag-handle poll is visible on open.
                if not state.observedCombatCompact then
                    combatPlacementRemaining = 0.6
                elseif combatPlacementRemaining then
                    combatPlacementRemaining = combatPlacementRemaining - elapsed
                end
                if combatPlacementRemaining and combatPlacementRemaining > 0 then
                    if not NativeGamepadOwnsMap() then Canvas:RepairCombatWorldMapAnchor(map) end
                else
                    combatPlacementRemaining = nil
                end
            else
                combatPlacementRemaining = nil
            end
            state.observedCombatCompact = combatCompact
            if elapsedSinceUpdate < 0.10 and not state.mapWiseLayout then return end
            elapsedSinceUpdate = 0
            UpdateMapWiseLayout(map, state, mapShown, maximized)
            local gamepadOwned = NativeGamepadOwnsMap()
            if (_G.SpokenPlacesPanel or map.QuestLog) and not InCombatLockdown() then
                local metrics
                if mapShown and not maximized and not gamepadOwned and not map:IsForbidden()
                    and Canvas.IsFrameOnWorkspace(map) then
                    metrics = WithWorkspace(Offhand.Viewport:GetMetrics())
                    if metrics and metrics.isSpanned and Offhand.WorkspaceRegions then
                        metrics = Offhand.WorkspaceRegions:ForFrame(metrics, map)
                    end
                end
                local workspace = metrics and metrics.isSpanned and metrics
                FitQuestList(map, workspace)
                UpdatePlacesClamp(_G.SpokenPlacesPanel, map, workspace)
                UpdatePlacesClamp(_G.SpokenPlacesPanelToggle, map, workspace)
            end
            if gamepadOwned then
                SetPanelDragging(map, false)
                -- Keep the invisible observer running so keyboard mode can
                -- resume without a reload. Its hit area remains off screen.
                PlaceDragHandle()
                SetReturnVisible(false)
                return
            end
            if ShouldYieldWorldMapToMoveAny(map) then
                SetPanelDragging(map, false)
                if SupportsExternalWorldMapEscapeProtection(map) then
                    -- Keep the noninteractive observer active to detect later
                    -- show edges while the external addon positions the map.
                    PlaceDragHandle()
                    if not mapShown or maximized then
                        state.externalWorkspace, state.externalPersistence = nil, nil
                        state.externalPanelSlot, state.externalSpecialFrame = nil, nil
                    elseif not InCombatLockdown() and Canvas.IsFrameOnWorkspace then
                        local ok, workspace = pcall(Canvas.IsFrameOnWorkspace, map)
                        local persistent = Offhand.db.persistentWorkspacePanels ~= false
                        if ok then
                            local inPanelSlot, specialFrame
                            if workspace and persistent then inPanelSlot, specialFrame = ReadNativeClosePaths(map) end
                            -- OpenMap can retain the same geometry while Blizzard
                            -- puts the map back into a native close path.
                            if state.externalWorkspace ~= workspace or state.externalPersistence ~= persistent
                                or (inPanelSlot and not state.externalPanelSlot)
                                or (specialFrame and not state.externalSpecialFrame) then
                                Canvas:PreserveExternalWorldMapOpenState(map)
                                state.externalWorkspace, state.externalPersistence = workspace, persistent
                                if workspace and persistent then inPanelSlot, specialFrame = ReadNativeClosePaths(map) end
                            end
                            -- Record the resulting state so a refused detach is
                            -- retried only after a new layout or ownership change.
                            state.externalPanelSlot, state.externalSpecialFrame = inPanelSlot, specialFrame
                        end
                    end
                elseif handle.Hide then
                    if handle.EnableMouse then handle:EnableMouse(false) end
                    handleMouseEnabled = false
                    handle:Hide()
                end
                SetReturnVisible(false)
                return
            end
            state.externalWorkspace, state.externalPersistence = nil, nil
            state.externalPanelSlot, state.externalSpecialFrame = nil, nil

            if returnButton then
                if maximized and not InCombatLockdown() then
                    local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
                    if metrics and metrics.isSpanned and returnButton.ClearAllPoints and returnButton.SetPoint then
                        local centerX = (metrics.gameLeft + metrics.gameRight) / 2
                        local topY = metrics.gameTop - 20
                        if centerX ~= returnX or topY ~= returnY then
                            returnButton:ClearAllPoints()
                            returnButton:SetPoint("TOP", UIParent, "BOTTOMLEFT", centerX, topY)
                            returnX, returnY = centerX, topY
                        end
                    end
                    SetReturnVisible(true)
                else
                    SetReturnVisible(false)
                end
            end

            if not mapShown or maximized or not map.GetLeft or not map.GetTop then
                PlaceDragHandle()
                return
            end

            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            local mapScale = (map.GetEffectiveScale and map:GetEffectiveScale()) or parentScale
            local factor = parentScale > 0 and mapScale / parentScale or 1
            PlaceDragHandle(Adapter.GetDragHandleBounds(map, factor))
        end

        if handle.SetScript then
            handle:SetScript("OnUpdate", UpdateHandle)
            handle:SetScript("OnDragStart", function()
                pendingWorkspaceDrop = nil
                if NativeGamepadOwnsMap() or ShouldYieldWorldMapToMoveAny(map) or InCombatLockdown()
                    or (map.IsMaximized and map:IsMaximized())
                    or not Offhand.db or not Offhand.db.enabled then return end
                state.mapWiseLayout, state.mapWisePlacement = nil, nil
                local started = pcall(function()
                    map:SetMovable(true)
                    map:SetClampedToScreen(false)
                    map:StartMoving()
                end)
                SetPanelDragging(map, started)
            end)
            handle:SetScript("OnDragStop", function()
                if NativeGamepadOwnsMap() then
                    SetPanelDragging(map, false)
                    return
                end
                local wasDragging = FrameState.IsDragging(map)
                OnPanelDragStop(map)
                UpdateHandle(nil, 1)
                if wasDragging and Offhand.db and Offhand.db.savedWorkspacePositions then
                    pendingWorkspaceDrop = Offhand.db.savedWorkspacePositions.WorldMapFrame
                end
            end)
        end
        if handle.Show then handle:Show() end
        UpdateHandle(nil, 1)
        return true
    end

    return {
        RepairUIPanelTransaction = RepairUIPanelTransaction,
        RepairAfterPanelHide = RepairAfterPanelHide,
        AttachDragHandle = AttachForeverWorldMapDragHandle,
    }
end

