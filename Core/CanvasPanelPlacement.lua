-- Panel placement measurement and Social/Communities anchor ownership.
local _, Offhand = ...
local Placement = {}
Offhand.CanvasPanelPlacement = Placement

local diagnosticPanelNames = {
    "CharacterFrame", "SkillFrame", "PlayerSpellsFrame", "SpellBookFrame",
    "ProfessionsFrame", "ProfessionsBookFrame", "TradeSkillFrame", "CraftFrame",
    "WorldMapFrame", "ForeverXPBarMainFrame", "GameMenuFrame", "GamepadReticle",
    "ConsolePortCrosshair",
}

local function IsPublic(value)
    return type(issecretvalue) ~= "function" or not issecretvalue(value)
end

local function IsPublicNumber(value)
    return IsPublic(value) and type(value) == "number" and value > -math.huge and value < math.huge
end

local function DiagnosticFrameName(frame)
    if not IsPublic(frame) then return "unavailable" end
    if not frame then return "none" end
    if frame == UIParent then return "UIParent" end
    if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
    local name = frame.GetName and frame:GetName()
    return IsPublic(name) and type(name) == "string" and name or "unnamed"
end

local function DescribePanelPlacement(frame, parentScale)
    if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
    if not frame:IsShown() or (frame.IsVisible and not frame:IsVisible()) then return end
    local parent = DiagnosticFrameName(frame:GetParent())
    local rect, anchor = "unavailable", "unavailable"
    local scale = frame:GetEffectiveScale()
    local x, y, width, height = frame:GetRect()
    if IsPublicNumber(scale) and scale > 0 and IsPublicNumber(parentScale) and parentScale > 0
        and IsPublicNumber(x) and IsPublicNumber(y) and IsPublicNumber(width) and IsPublicNumber(height) then
        local factor = scale / parentScale
        rect = string.format("%.1f/%.1f/%.1f/%.1f", x * factor, y * factor, width * factor, height * factor)
    end
    if frame.GetPoint then
        local ok, point, relative, relativePoint, offsetX, offsetY = pcall(frame.GetPoint, frame, 1)
        if ok and IsPublic(point) and type(point) == "string" and IsPublic(relativePoint)
            and type(relativePoint) == "string" and IsPublicNumber(offsetX) and IsPublicNumber(offsetY) then
            anchor = string.format("%s/%s/%s/%.1f/%.1f", point, DiagnosticFrameName(relative), relativePoint, offsetX, offsetY)
        end
    end
    return string.format("parent=%s | rectUI=%s | anchor=%s | effScale=%s", parent, rect, anchor,
        IsPublicNumber(scale) and string.format("%.3f", scale) or "unavailable")
end

local function DescribeForeverXPBarSave()
    local db = _G.ForeverXPBarDB
    if type(db) ~= "table" then return "unavailable" end
    local point, relativePoint, x, y = db.point, db.relPoint, db.x, db.y
    if not IsPublic(point) or not IsPublic(relativePoint) or type(point) ~= "string"
        or type(relativePoint) ~= "string" or not IsPublicNumber(x) or not IsPublicNumber(y) then
        return "unavailable"
    end
    return string.format("%s/%s/%.1f/%.1f", point, relativePoint, x, y)
end

-- Keep the native panel manager's secure placement path in combat. These
-- are Blizzard's layout offsets, not attributes on the protected panels.
local stockPanelOffsets = { LEFT_OFFSET = 16, TOP_OFFSET = -116, RIGHT_OFFSET_BUFFER = 80 }
local nativeOffsetOwner, appliedPanelOffsets

function Placement.RefreshNativeMainhandOrigin(metrics, enabled)
    if not Offhand.isForever or InCombatLockdown() or not GetUIPanelLayoutFrame
        or not GetUIPanelLayoutAttribute or not SetUIPanelLayoutAttribute then return end

    local layout = GetUIPanelLayoutFrame()
    if not layout or not layout.CanChangeProtectedState or layout:CanChangeProtectedState() ~= true then return end
    if nativeOffsetOwner ~= layout then
        nativeOffsetOwner, appliedPanelOffsets = layout, nil
    end

    local desired = stockPanelOffsets
    if enabled and metrics and metrics.isSpanned then
        local top, right = UIParent:GetTop(), UIParent:GetRight()
        if IsPublicNumber(top) and IsPublicNumber(right)
            and IsPublicNumber(metrics.gameLeft) and IsPublicNumber(metrics.gameTop)
            and IsPublicNumber(metrics.gameRight) then
            desired = {
                LEFT_OFFSET = stockPanelOffsets.LEFT_OFFSET + metrics.gameLeft,
                TOP_OFFSET = stockPanelOffsets.TOP_OFFSET - math.max(0, top - metrics.gameTop),
                RIGHT_OFFSET_BUFFER = stockPanelOffsets.RIGHT_OFFSET_BUFFER + math.max(0, right - metrics.gameRight),
            }
        end
    end

    local expected = appliedPanelOffsets or stockPanelOffsets
    local current = {}
    for key in pairs(expected) do
        current[key] = GetUIPanelLayoutAttribute(key)
        if not IsPublicNumber(current[key]) then return end
    end
    for key, value in pairs(expected) do
        if current[key] ~= value then
            -- If another mover took an offset, keep its value and release only
            -- the offsets we still own.
            if appliedPanelOffsets then
                for ownedKey, ownedValue in pairs(appliedPanelOffsets) do
                    if current[ownedKey] == ownedValue and ownedValue ~= stockPanelOffsets[ownedKey] then
                        SetUIPanelLayoutAttribute(ownedKey, stockPanelOffsets[ownedKey])
                    end
                end
            end
            appliedPanelOffsets = nil
            return
        end
    end
    for key, value in pairs(desired) do
        if expected[key] ~= value then SetUIPanelLayoutAttribute(key, value) end
    end
    appliedPanelOffsets = desired ~= stockPanelOffsets and desired or nil
end

function Placement.InstallSingleScreen(Canvas, services)
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local IsContextBoundPanel = services.IsContextBoundPanel
    -- A missing saved display leaves no workspace rectangle. Close only panels
    -- that were visible on that workspace so they do not get clamped into a pile
    -- on Mainhand. Their saved geometry and open-state snapshot are intentionally
    -- retained; reconnecting and reloading restores them. Panels opened manually
    -- after recovery remain usable with Blizzard's native single-screen anchors.
    local function IsSingleScreenRecovery(metrics)
        if Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery then
            return Offhand.Viewport:IsSingleScreenRecovery(metrics)
        end
        return metrics and not metrics.isSpanned
            and metrics.topologyStatus == "MISMATCH" or false
    end

    function Canvas:PrepareSingleScreenRecovery(metrics)
        if not IsSingleScreenRecovery(metrics) or not Offhand.db
            or not Offhand.db.savedWorkspacePositions then return end
        for name in pairs(Offhand.db.savedWorkspacePositions) do
            -- NPC and other interaction panels can end the session on Hide.
            -- Their native panel manager owns visibility and placement here.
            if not IsContextBoundPanel(name) and not tostring(name):match("^ChatFrame%d+$")
                and not (Offhand.isForever and Offhand.CanvasCompatibility.IsForeverEllesmereBag(name))
                and not IsForeverEditModeFrame(_G[name], name)
                and not IsForeverProfessionsPanel(_G[name], name) then
                local frame = _G[name]
                local addonEscape = Offhand.CanvasAddonEscape
                local vendorGameplay = addonEscape and addonEscape:IsVendorGameplayFrame(frame, name)
                if frame and not vendorGameplay and frame.IsShown and frame:IsShown() and frame.Hide then
                    pcall(frame.Hide, frame)
                end
            end
        end
    end

    function Canvas:PlaceForSingleScreenRecovery(frame, metrics)
        if not frame or not Offhand.db or not Offhand.db.savedWorkspacePositions then return false end
        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics())
        if not IsSingleScreenRecovery(metrics) then return false end
        local name = frame.GetName and frame:GetName()
        if not name or not Offhand.db.savedWorkspacePositions[name] or IsContextBoundPanel(name)
            or IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return false end
        local daylight = Offhand.DaylightMapCompatibility
        if name == "WorldMapFrame" and daylight and daylight.ShouldPreserveSingleScreenPosition
            and daylight:ShouldPreserveSingleScreenPosition(frame, metrics) then return false end

        -- Blizzard Edit Mode's Modern fallback already places chat correctly and
        -- may also restore its preferred size. Do not override it with panel logic.
        if tostring(name):match("^ChatFrame%d+$") then return false end

        if Offhand.WorkspaceScale and not Offhand.WorkspaceScale:Apply(frame,false,metrics) then return false end
        if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end
        if frame.ClearAllPoints and frame.SetPoint then
            pcall(function()
                frame:ClearAllPoints()
                if name == "CharacterFrame" then
                    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -80)
                elseif name == "ContainerFrameCombinedBags" or tostring(name):match("^ContainerFrame%d+$")
                    or tostring(name):match("Baganator") or tostring(name):match("Baginator")
                    or tostring(name):match("Bagnon") or tostring(name):match("BetterBags") then
                    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -32, 140)
                else
                    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
                end
            end)
        end
        return true
    end
end

function Placement.InstallMainhand(Canvas, services)
    local ShouldYieldFrameToClassicUIForever = services.ShouldYieldFrameToClassicUIForever
    local ShouldYieldWorldMapToMoveAny = services.ShouldYieldWorldMapToMoveAny
    local IsForeverProfessionsPanel = services.IsForeverProfessionsPanel
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local IsWorldMapMaximized = services.IsWorldMapMaximized
    local WithWorkspace = services.WithWorkspace
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local RegisterSpecialFrame = services.RegisterSpecialFrame
    local SaveOpenWorkspacePanels = services.SaveOpenWorkspacePanels
    local SaveForeverPanelOwnership = services.SaveForeverPanelOwnership
    local IsBackpackRoot = services.IsBackpackRoot
    local ClearOtherBackpackRootState = services.ClearOtherBackpackRootState
    local IsFrameOnWorkspace = services.IsFrameOnWorkspace
    local nativeSlots = { "left", "center", "right" }
    local defaultPanelNames = {
        CharacterFrame = true,
        CollectionsJournal = true,
        CollectionsJournalFrame = true,
        PlayerSpellsFrame = true,
    }
    local mainhandInset = 12
    local settledCharacterAnchors = setmetatable({}, { __mode = "k" })
    local function HasUserPlacedPanelAnchor(frame, name)
        if not frame.IsUserPlaced or not frame:IsUserPlaced() then return false end
        if name == "CharacterFrame" and frame.GetPoint then
            -- Forever's slot manager can replace Character's anchor while its
            -- user-placed flag is still set. Recognize native slot points and
            -- our exact result if the newly opened peer is still settling.
            local point, relative, relativePoint, x, y = frame:GetPoint(1)
            if relative == UIParent then
                if point == relativePoint and (point == "TOPLEFT" or point == "TOP") then return false end
                local settled = settledCharacterAnchors[frame]
                if settled and point == "TOPLEFT" and relativePoint == "BOTTOMLEFT"
                    and x == settled.x and y == settled.y then return false end
            end
        end
        return true
    end
    local function GetRestedXPGuideFrame()
        local compatibility = Offhand.HUDCompatibility
        if compatibility and compatibility.GetRestedXPGuideFrame then
            return compatibility.GetRestedXPGuideFrame()
        end
    end

    -- Support snapshots read only these known roots. Protected anchors may
    -- become secret in combat, even when the frame is still shown.
    function Canvas:GetPanelPlacementDiagnostics()
        local reports = {}
        local readScale, parentScale = pcall(UIParent.GetEffectiveScale, UIParent)
        if not readScale then parentScale = nil end
        local db = Offhand.db or {}
        for _, name in ipairs(diagnosticPanelNames) do
            local frame = _G[name]
            if frame then
                local ok, detail = pcall(DescribePanelPlacement, frame, parentScale)
                if not ok then detail = "unavailable" end
                if detail then
                    local saved = db.savedWorkspacePositions and db.savedWorkspacePositions[name] and "workspace"
                        or db.savedMainPositions and db.savedMainPositions[name] and "mainhand" or "none"
                    local ownerAnchor = name == "ForeverXPBarMainFrame"
                        and " | ForeverXPBarSave=" .. DescribeForeverXPBarSave() or ""
                    reports[#reports + 1] = name .. " | " .. detail .. " | saved=" .. saved .. ownerAnchor
                end
            end
        end
        return reports
    end

    -- Blizzard UIPanels anchor against the full UIParent. In an Offhand topology
    -- that native origin may be the workspace, so an unsaved Spellbook,
    -- Professions or Collections panel can open on the wrong monitor. Mainhand
    -- placements use physical UIParent coordinates and are clamped on every
    -- restore so display changes cannot strand a panel off screen.
    function Canvas:PlacePanelOnMainhand(frame, metrics, position, preserveContained, recoveryAction, anchorOnly)
        local nonMovableSystemPanels = services.GetNonMovablePanels()
        if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
            or not Offhand.db.enabled then return false end
        local registry = Offhand.CanvasPanelRegistry
        if registry and registry.GetPositionRoot(frame) ~= frame then return false end
        if IsWorldMapMaximized(frame) then return false end
        local foreverMap = Offhand.isForever and frame == _G.WorldMapFrame
        if foreverMap and ((self.CanManagePanelsFromAddon and not self.CanManagePanelsFromAddon())
            or (Offhand.CanvasFrameState and Offhand.CanvasFrameState.IsDragging(frame))) then return false end
        local name = frame.GetName and frame:GetName()
        local recoverRestedXP = recoveryAction and not name and frame == GetRestedXPGuideFrame()
        local addonEscape = Offhand.CanvasAddonEscape
        local vendorGameplay = addonEscape and addonEscape:IsVendorGameplayFrame(frame, name)
        if vendorGameplay then
            if not recoveryAction or (frame.IsForbidden and frame:IsForbidden())
                or (frame.IsProtected and frame:IsProtected())
                or (self.CanManagePanelsFromAddon and not self.CanManagePanelsFromAddon()) then
                return false
            end
            anchorOnly = true
        end
        if Offhand.isForever and Offhand.CanvasCompatibility.IsForeverEllesmereBag(name) then return false end
        if ShouldYieldFrameToClassicUIForever(frame, name) then return false end
        if ShouldYieldWorldMapToMoveAny(name or frame) then return false end
        if recoveryAction and name and not vendorGameplay and services.RemodalizePanel
            and not (frame.IsForbidden and frame:IsForbidden())
            and not IsForeverEditModeFrame(frame, name) then
            -- A workspace menu may have been detached from UIPanelWindows.
            -- Restore the registration we saved before testing protected-panel
            -- eligibility or the native toggle's next anchor transaction.
            services.RemodalizePanel(frame)
        end
        local recoverySafePanel = recoveryAction and name and (
            vendorGameplay or IsBackpackRoot(name) or (UIPanelWindows and UIPanelWindows[name])
                or IsForeverSocialPositionRoot(frame, name)
        )
        if not (name or recoverRestedXP) or (nonMovableSystemPanels and nonMovableSystemPanels[name])
            or IsForeverEditModeFrame(frame, name)
            or (IsUnsafeForPanelMutation(frame, name) and not recoverySafePanel) then return false end

        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics()))
        if not metrics or not metrics.isSpanned then return false end
        if not anchorOnly and Offhand.WorkspaceScale
            and not Offhand.WorkspaceScale:Apply(frame, false, metrics) then return false end

        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        if parentScale <= 0 or frameScale <= 0 then return false end
        local scaleFactor = frameScale / parentScale
        local width = ((frame.GetWidth and frame:GetWidth()) or 0) * scaleFactor
        local height = ((frame.GetHeight and frame:GetHeight()) or 0) * scaleFactor
        if width <= 0 then width = 192 * scaleFactor end
        if height <= 0 then height = 192 * scaleFactor end

        local inset = mainhandInset
        local minX = metrics.gameLeft + inset
        local maxX = math.max(minX, metrics.gameRight - width - inset)
        local minY = metrics.gameBottom + height + inset
        local maxY = math.max(minY, metrics.gameTop - inset)
        if (anchorOnly or metrics.workspaceRegions or foreverMap) and height > metrics.gameTop-metrics.gameBottom-2*inset then
            -- An oversized fallback cannot be fully contained. Keep its title
            -- reachable instead of placing it above the physical game monitor.
            minY,maxY=metrics.gameTop-inset,metrics.gameTop-inset
        end

        if preserveContained and not position then
            local left = frame.GetLeft and frame:GetLeft()
            local top = frame.GetTop and frame:GetTop()
            if left and top then
                left, top = left * scaleFactor, top * scaleFactor
                if left >= minX and left + width <= metrics.gameRight - inset
                    and top <= maxY and top - height >= metrics.gameBottom + inset then
                    return false
                end
            end
        end

        local targetX = position and tonumber(position.x)
        local targetY = position and tonumber(position.y)
        if not targetX then
            targetX = metrics.gameLeft + (metrics.gameRight - metrics.gameLeft - width) / 2
        end
        if not targetY then
            targetY = metrics.gameBottom + (metrics.gameTop - metrics.gameBottom + height) / 2
        end
        local clampedX = math.max(minX, math.min(targetX, maxX))
        local clampedY = math.max(minY, math.min(targetY, maxY))
        local pointFactor = parentScale / frameScale

        local ok = pcall(function()
            if not anchorOnly and name and frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                clampedX * pointFactor, clampedY * pointFactor)
        end)
        if ok and anchorOnly and name == "CharacterFrame" and frame.GetPoint then
            local _, _, _, x, y = frame:GetPoint(1)
            settledCharacterAnchors[frame] = { x = x, y = y }
        end
        if ok and not anchorOnly and name and not IsForeverProfessionsPanel(frame, name) then
            RegisterSpecialFrame(name)
        end
        return ok
    end

    -- A native slot update can overwrite every participating anchor. Repair
    -- default placement for the affected roots from the completed transaction.
    function Canvas:RepairDefaultForeverSlots()
        local db, compatibility = Offhand.db, Offhand.CanvasCompatibility
        if not Offhand.isForever or not db or not db.enabled or not GetUIPanel
            or not self.CanManagePanelsFromAddon or not self.CanManagePanelsFromAddon()
            or InCombatLockdown() or compatibility.HasMoveAny()
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then return end
        local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then return end
        local parentScale = UIParent:GetEffectiveScale()
        if parentScale <= 0 then return end

        local panels, totalWidth, previousRight, fitInPlace = {}, 0, nil, true
        for _, slot in ipairs(nativeSlots) do
            local frame = GetUIPanel(slot)
            local name = frame and frame.GetName and not (frame.IsForbidden and frame:IsForbidden())
                and frame:GetName()
            if name and frame == _G[name]
                and (defaultPanelNames[name] or compatibility.IsPersistentForeverProfessionsPanelName(name))
                and not IsUnsafeForPanelMutation(frame, name)
                and not Offhand.CanvasFrameState.IsDragging(frame) and frame:IsShown()
                and not HasUserPlacedPanelAnchor(frame, name)
                and not (db.savedMainPositions and db.savedMainPositions[name])
                and not (db.savedWorkspacePositions and db.savedWorkspacePositions[name])
                and not (Offhand.WorkspaceRouting and Offhand.WorkspaceRouting:HasRule(name, metrics)) then
                local factor = frame:GetEffectiveScale() / parentScale
                local left, top = frame:GetLeft(), frame:GetTop()
                local width, height = frame:GetWidth() * factor, frame:GetHeight() * factor
                if left and top and width > 0 and height > 0 then
                    left, top = left * factor, top * factor
                    local right = left + width
                    local contained = left >= metrics.gameLeft + mainhandInset
                        and right <= metrics.gameRight - mainhandInset
                        and top <= metrics.gameTop - mainhandInset
                        and top - height >= metrics.gameBottom + mainhandInset
                    panels[#panels + 1] = { frame = frame, width = width, contained = contained }
                    totalWidth = totalWidth + width
                    fitInPlace = fitInPlace and contained and (not previousRight or previousRight <= left)
                    previousRight = right
                end
            end
        end

        if fitInPlace then return end
        local gameWidth = metrics.gameRight - metrics.gameLeft
        local rowWidth = totalWidth + (#panels - 1) * mainhandInset
        if #panels > 1 and rowWidth + 2 * mainhandInset <= gameWidth then
            local left = metrics.gameLeft + (gameWidth - rowWidth) / 2
            for _, panel in ipairs(panels) do
                self:PlacePanelOnMainhand(panel.frame, metrics, { x = left }, false, false, true)
                left = left + panel.width + mainhandInset
            end
        else
            for _, panel in ipairs(panels) do
                if not panel.contained then
                    self:PlacePanelOnMainhand(panel.frame, metrics, nil, true, false, true)
                end
            end
        end
    end

    -- Recovery is an explicit out-of-combat hardware action. Unlike a generic
    -- re-anchor, it must also retire Offhand's workspace ownership or the next
    -- OnShow/restore pass will put the panel back on the secondary display.
    function Canvas:GatherSafeUIToMainhand(missingOnly, onlyFrame)
        local playerInCombat = InCombatLockdown and InCombatLockdown() or false
        if not playerInCombat and UnitAffectingCombat then
            local ok, active = pcall(UnitAffectingCombat, "player")
            playerInCombat = ok and active == true or false
        end
        if playerInCombat then return false, "combat", 0, 0 end
        if not Offhand.db or not Offhand.db.enabled then return false, "disabled", 0, 0 end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then return false, "span", 0, 0 end
        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
        Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
        Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

        local candidates = {}
        local function Add(frame)
            if frame then
                local registry = Offhand.CanvasPanelRegistry
                frame = registry and registry.GetPositionRoot and registry.GetPositionRoot(frame) or frame
                candidates[frame] = true
            end
        end
        local restedXPGuide = missingOnly and GetRestedXPGuideFrame()
        if onlyFrame then
            Add(onlyFrame)
        else
            for name in pairs(Offhand.db.savedWorkspacePositions or {}) do Add(_G[name]) end
            for name in pairs(UIPanelWindows or {}) do Add(_G[name]) end
            if UIParent.GetChildren then
                for _, child in ipairs({UIParent:GetChildren()}) do
                    pcall(function()
                        if not (child.IsForbidden and child:IsForbidden())
                            and child.IsMovable and child:IsMovable() then Add(child) end
                    end)
                end
            end
            if Offhand.BagPersistence and type(Offhand.BagPersistence.frames) == "table" then
                for _, frame in pairs(Offhand.BagPersistence.frames) do Add(frame) end
            end
            Add(_G.WorldMapFrame)
            Add(_G.CharacterFrame)
            Add(_G.ContainerFrameCombinedBags)
            Add(_G.ContainerFrame1)
            Add(restedXPGuide)
        end

        local moved, skipped = 0, 0
        self.lastGatherReport = {}
        for frame in pairs(candidates) do
            -- A registered Blizzard panel can become forbidden after it enters a
            -- restricted state. Never call even basic frame methods until the
            -- complete inspection is behind a guarded boundary.
            local inspected, name, shown, tracked, onWorkspace = pcall(function()
                if frame.IsForbidden and frame:IsForbidden() then return nil, false, false, false end
                local frameName = frame.GetName and frame:GetName()
                local frameShown = frame.IsShown and frame:IsShown() or false
                local frameTracked = frameName and Offhand.db.savedWorkspacePositions[frameName]
                local frameOnWorkspace = frameShown and IsFrameOnWorkspace(frame) or false
                return frameName, frameShown, frameTracked, frameOnWorkspace
            end)
            local isRestedXPGuide = frame == restedXPGuide
            local recover = shown and (tracked or onWorkspace)
            local reopen = false
            if missingOnly and inspected and (name or isRestedXPGuide) and Offhand.Recovery then
                local state = Offhand.Recovery.Inspect(frame, metrics)
                local registry = Offhand.CanvasPanelRegistry
                reopen = not onlyFrame and state == "hidden" and tracked and Offhand.db.openWorkspacePanels[name] == true
                    and registry and registry.IsBasePersistentCandidate(name)
                    and not IsBackpackRoot(name) and UIPanelWindows and UIPanelWindows[name]
                    and type(ShowUIPanel) == "function"
                if reopen and GetUIPanel then
                    -- Opening a native slot beside another panel can reflow or
                    -- close that visible panel. Yield rather than disturb it.
                    for _, slot in ipairs({"left", "center", "right", "doublewide"}) do
                        local read, occupant = pcall(GetUIPanel, slot)
                        if not read or (occupant and occupant ~= frame) then reopen = false; break end
                    end
                end
                recover = state == "missing" or reopen
            end
            local reportName = name or (isRestedXPGuide and "RXPV2GuideWindow")
            if inspected and recover and reportName
                and frame ~= UIParent and frame ~= WorldFrame and frame ~= Offhand.canvas
                and not IsForeverEditModeFrame(frame, name)
                and not ShouldYieldFrameToClassicUIForever(frame, name)
                and not ShouldYieldWorldMapToMoveAny(name or frame) then
                local foreverMap = Offhand.isForever and frame == _G.WorldMapFrame
                if frame == _G.WorldMapFrame and frame.SetScale and not foreverMap then
                    pcall(frame.SetScale, frame, 1)
                end
                local called, placed = pcall(self.PlacePanelOnMainhand,
                    self, frame, metrics, nil, false, true)
                placed = called and placed
                if placed and missingOnly and foreverMap and Offhand.Recovery then
                    placed = Offhand.Recovery.Inspect(frame, metrics) == "visible"
                end
                if placed then
                    self.lastGatherReport[#self.lastGatherReport + 1] = reportName .. "=moved"
                    moved = moved + 1
                end
                -- RestedXP saves its own anchor on logout/reload. Don's guide
                -- and arrow also keep their own anchors and drag handlers.
                local addonEscape = Offhand.CanvasAddonEscape
                if placed and name and not (addonEscape and addonEscape:IsVendorGameplayFrame(frame, name)) then
                    Offhand.db.savedWorkspacePositions[name] = nil
                    Offhand.db.openWorkspacePanels[name] = nil
                    if Offhand.db.baganatorWorkspacePanels then
                        Offhand.db.baganatorWorkspacePanels[name] = nil
                    end

                    if IsBackpackRoot(name) then
                        ClearOtherBackpackRootState(nil)
                        Offhand.db.nativeBackpackWorkspacePosition = nil
                        Offhand.db.nativeBackpackWorkspaceOpen = nil
                    elseif Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
                        Offhand.ForeverPersistence:ClearPosition(name)
                    end

                    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
                    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                    local left = frame.GetLeft and frame:GetLeft()
                    local top = frame.GetTop and frame:GetTop()
                    if left and top and parentScale > 0 then
                        local factor = frameScale / parentScale
                        Offhand.db.savedMainPositions[name] = { x = left * factor, y = top * factor }
                    end
                    if reopen and ShowUIPanel then
                        local opened = pcall(ShowUIPanel, frame)
                        if not opened or not (frame.IsShown and frame:IsShown()) then skipped = skipped + 1 end
                    end
                elseif not placed then
                    skipped = skipped + 1
                    local reason = "placement-unavailable"
                    pcall(function()
                        if frame.IsProtected and frame:IsProtected() and not (UIPanelWindows and UIPanelWindows[name]) then
                            reason = "protected-unregistered"
                        elseif IsWorldMapMaximized(frame) then reason = "native-maximized-map" end
                    end)
                    self.lastGatherReport[#self.lastGatherReport + 1] = reportName .. "=" .. reason
                end
            elseif not inspected then
                skipped = skipped + 1
                self.lastGatherReport[#self.lastGatherReport + 1] = "uninspectable=skipped"
            elseif recover then
                skipped = skipped + 1
                local reason = IsForeverEditModeFrame(frame, name) and "native-HUD-or-EditMode" or "external-or-geometry-owner"
                self.lastGatherReport[#self.lastGatherReport + 1] = tostring(reportName or name) .. "=" .. reason
            end
        end

        if not onlyFrame or moved > 0 then SaveOpenWorkspacePanels() end
        if Offhand.BagPersistence and not missingOnly then
            if Offhand.BagPersistence.ForgetOpenSnapshot then
                Offhand.BagPersistence:ForgetOpenSnapshot()
            end
            if Offhand.BagPersistence.Capture then Offhand.BagPersistence:Capture() end
        end
        if moved > 0 then SaveForeverPanelOwnership() end
        return true, nil, moved, skipped
    end
end

function Placement.InstallVoid(Canvas, services)
    local IsForeverEditModeFrame = services.IsForeverEditModeFrame
    local WithWorkspace = services.WithWorkspace
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local nonMovableSystemPanels = services.NonMovablePanels
    -- A normal Blizzard panel can be reachable by its left edge while its close
    -- button and most of its title bar sit in the mixed-height monitor void. Keep
    -- the complete window inside whichever visible monitor currently contains the
    -- greatest portion of it. Saved user placements are restored separately and
    -- therefore always take precedence over this default-position rescue.
    function Canvas:RescuePanelFromVoid(frame, metrics)
        if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
            or not Offhand.db.enabled then return false end
        local registry = Offhand.CanvasPanelRegistry
        if registry and registry.GetPositionRoot(frame) ~= frame then return false end
        local name = frame.GetName and frame:GetName()
        if not name or nonMovableSystemPanels[name] or IsForeverEditModeFrame(frame, name)
            or IsUnsafeForPanelMutation(frame, name) then return false end
        if not UIPanelWindows or not UIPanelWindows[name] then return false end
        if frame.IsShown and not frame:IsShown() then return false end

        metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
            and WithWorkspace(Offhand.Viewport:GetMetrics()))
        if not metrics or not metrics.isSpanned or metrics.workspaceLeft == nil then return false end

        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        if parentScale <= 0 or frameScale <= 0 then return false end
        local scaleFactor = frameScale / parentScale
        local left = frame.GetLeft and frame:GetLeft()
        local top = frame.GetTop and frame:GetTop()
        local width = frame.GetWidth and frame:GetWidth()
        local height = frame.GetHeight and frame:GetHeight()
        if not left or not top or not width or not height or width <= 0 or height <= 0 then return false end

        left, top = left * scaleFactor, top * scaleFactor
        width, height = width * scaleFactor, height * scaleFactor
        local right, bottom = left + width, top - height
        local inset = 12
        local areas = {
            {
                left = metrics.workspaceLeft, right = metrics.workspaceRight,
                bottom = metrics.workspaceBottom, top = metrics.workspaceTop,
            },
            {
                left = metrics.gameLeft, right = metrics.gameRight,
                bottom = metrics.gameBottom, top = metrics.gameTop,
            },
        }
        if metrics.workspaceRegions then
            areas={areas[2]}
            for _,r in ipairs(metrics.workspaceRegions) do
                areas[#areas+1]={left=r.x,right=r.x+r.width,bottom=r.y,top=r.y+r.height}
            end
        end

        local function IsContained(area)
            return left >= area.left + inset and right <= area.right - inset
                and bottom >= area.bottom + inset and top <= area.top - inset
        end
        for _,area in ipairs(areas) do if IsContained(area) then return false end end

        local function Overlap(area)
            local overlapWidth = math.max(0, math.min(right, area.right) - math.max(left, area.left))
            local overlapHeight = math.max(0, math.min(top, area.top) - math.max(bottom, area.bottom))
            return overlapWidth * overlapHeight
        end
        local target=areas[1]
        for i=2,#areas do if Overlap(areas[i])>Overlap(target) then target=areas[i] end end
        local availableWidth = math.max(0, target.right - target.left - inset * 2)
        local availableHeight = math.max(0, target.top - target.bottom - inset * 2)
        local targetLeft = width <= availableWidth
            and math.max(target.left + inset, math.min(left, target.right - width - inset))
            or target.left + inset
        local targetTop = height <= availableHeight
            and math.max(target.bottom + height + inset, math.min(top, target.top - inset))
            or target.top - inset
        local pointFactor = parentScale / frameScale
        local ok = pcall(function()
            if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
                targetLeft * pointFactor, targetTop * pointFactor)
        end)
        return ok
    end
end



function Placement.Install(Canvas, services)
    local WithWorkspace = services.WithWorkspace
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local NotePanelControllerActivity = services.NotePanelControllerActivity
    local RestoreWorkspacePosition = services.RestoreWorkspacePosition
    local IsPanelDragging = Offhand.CanvasFrameState.IsDragging
    local GetPanelPhysicalPlacement, PlacementMatchesPosition
    local socialMainhandSessionPositions = setmetatable({}, { __mode = "k" })
    local socialAnchorRepairState = setmetatable({}, { __mode = "k" })

    GetPanelPhysicalPlacement = function(frame)
        if not frame then return nil end
        local ok, placement = pcall(function()
            local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
            if Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,frame) end
            if not metrics or not metrics.isSpanned then return nil end
            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            if frameScale <= 0 or parentScale <= 0 then return nil end
            local factor = frameScale / parentScale
            local width = ((frame.GetWidth and frame:GetWidth()) or 0) * factor
            local height = ((frame.GetHeight and frame:GetHeight()) or 0) * factor
            local left = frame.GetLeft and frame:GetLeft()
            local top = frame.GetTop and frame:GetTop()
            local centerX, centerY
            if frame.GetCenter then centerX, centerY = frame:GetCenter() end
            if left then left = left * factor end
            if top then top = top * factor end
            if centerX then centerX = centerX * factor end
            if centerY then centerY = centerY * factor end
            if not centerX and left and width > 0 then centerX = left + width / 2 end
            if not centerY and top and height > 0 then centerY = top - height / 2 end
            if not left and centerX and width > 0 then left = centerX - width / 2 end
            if not top and centerY and height > 0 then top = centerY + height / 2 end
            if not centerX or not centerY then return nil end
            return {
                x = left,
                y = top,
                width = width,
                height = height,
                factor = factor,
                regionId = metrics.workspaceRegionID,
                onWorkspace = centerX >= metrics.workspaceLeft
                    and centerX <= metrics.workspaceRight
                    and centerY >= metrics.workspaceBottom
                    and centerY <= metrics.workspaceTop,
                onMainhand = metrics.gameLeft and centerX >= metrics.gameLeft
                    and centerX <= metrics.gameRight
                    and centerY >= metrics.gameBottom
                    and centerY <= metrics.gameTop,
            }
        end)
        return ok and placement or nil
    end

    PlacementMatchesPosition = function(placement, position)
        return placement and position and position.x and position.y
            and math.abs(placement.x - position.x) < 0.5
            and math.abs(placement.y - position.y) < 0.5
    end

    local combatSlots = { "left", "center", "right", "doublewide" }
    local socialWaitingForSpace = setmetatable({}, { __mode = "k" })
    local combatAnchorRepairing = setmetatable({}, { __mode = "k" })

    local function ReadShownSlot(slot)
        local frame = GetUIPanel(slot)
        if not IsPublic(frame) then return nil, true end
        if not frame then return nil end
        local ok, shown = pcall(function() return frame:IsShown() end)
        if not ok or not IsPublic(shown) then return nil, true end
        return shown and frame or nil
    end

    local function SavedAnchorOverlapsPeer(frame, x, y, width, height)
        if not GetUIPanel then return false end
        for _, slot in ipairs(combatSlots) do
            local peer, unreadable = ReadShownSlot(slot)
            if unreadable then return true end
            if peer and peer ~= frame then
                local other = GetPanelPhysicalPlacement(peer)
                if not other or not IsPublicNumber(other.x) or not IsPublicNumber(other.y)
                    or not IsPublicNumber(other.width) or not IsPublicNumber(other.height) then return true end
                if x < other.x + other.width and x + width > other.x
                    and y > other.y - other.height and y - height < other.y then return true end
            end
        end
        return false
    end

    local function ResolveCombatWorkspaceAnchor(metrics, frame, position, width, height)
        if type(position) ~= "table" or position.autoRoute
            or not IsPublicNumber(position.x) or not IsPublicNumber(position.y) then return end
        if Offhand.WorkspaceRegions then metrics = Offhand.WorkspaceRegions:ForFrame(metrics, frame, position) end
        local persistence = Offhand.CanvasPersistence
        if not persistence.FitsWorkspace(metrics, width, height) then return end
        return persistence.ResolveWorkspacePosition(metrics, position, width, height, false, UIParent:GetHeight())
    end

    local combatPanelClamps = {}

    local function InsetsMatch(current, expected)
        for i = 1, 4 do
            if not IsPublicNumber(current[i]) or math.abs(current[i] - expected[i]) > 0.01 then return false end
        end
        return true
    end

    local function PrepareCombatPanelClamp(frame, metrics, position)
        if not frame or combatPanelClamps[frame] then return end
        local ok, record = pcall(function()
            if frame:IsForbidden() ~= false or frame:IsProtected() ~= true
                or frame:CanChangeProtectedState() ~= true or frame:GetParent() ~= UIParent
                or IsPanelDragging(frame) then return end
            local uiScale, frameScale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
            local frameWidth, frameHeight = frame:GetWidth(), frame:GetHeight()
            if not IsPublicNumber(uiScale) or uiScale <= 0 or not IsPublicNumber(frameScale) or frameScale <= 0
                or not IsPublicNumber(frameWidth) or frameWidth <= 0
                or not IsPublicNumber(frameHeight) or frameHeight <= 0 then return end
            local factor = frameScale / uiScale
            local width, height = frameWidth * factor, frameHeight * factor
            local left, right, bottom, top = metrics.gameLeft, metrics.gameRight, metrics.gameBottom, metrics.gameTop
            if position then
                left, top = ResolveCombatWorkspaceAnchor(metrics, frame, position, width, height)
                if not IsPublicNumber(left) or not IsPublicNumber(top) then return end
                right, bottom = left + width, top - height
            elseif width > right - left or height > top - bottom then
                return
            end

            local original = {frame:GetClampRectInsets()}
            local wasClamped = frame:IsClampedToScreen()
            if not IsPublic(wasClamped) or type(wasClamped) ~= "boolean" or not InsetsMatch(original, original) then return end
            local desired = {-left / factor, (UIParent:GetWidth() - right) / factor,
                (UIParent:GetHeight() - top) / factor, -bottom / factor}
            return {original=original, wasClamped=wasClamped, desired=desired, workspace=position ~= nil}
        end)
        if not ok or not record then return end
        -- The client still assigns every native slot. Bounds constrain the
        -- resulting rectangle even when it cannot accept addon anchor writes.
        local applied = pcall(function()
            frame:SetClampRectInsets(unpack(record.desired))
            frame:SetClampedToScreen(true)
        end)
        if applied then
            combatPanelClamps[frame] = record
        else
            pcall(frame.SetClampRectInsets, frame, unpack(record.original))
        end
    end

    function Canvas:PrepareCombatPanelClamps()
        local db = Offhand.db
        if not Offhand.isForever or not db or not db.enabled or InCombatLockdown() or not UIPanelWindows
            or not self.CanManagePanelsFromAddon() or Offhand.CanvasCompatibility.HasMoveAny()
            or Offhand.CanvasCompatibility.HasClassicUIForever()
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then return end
        local metrics = WithWorkspace(Offhand.Viewport:GetMetrics())
        if not metrics or not metrics.isSpanned then return end

        local workspacePositions = db.savedWorkspacePositions or {}
        for name, position in pairs(workspacePositions) do
            local registration = UIPanelWindows[name]
            local frame = registration and _G[name]
            if frame and (registration.area == "left" or registration.area == "doublewide"
                or name == "PlayerSpellsFrame")
                and self:GetPanelController(name) == "generic"
                and not Offhand.CanvasPanelRegistry.IsContextBoundPanel(name)
                and not IsUnsafeForPanelMutation(frame, name) then
                PrepareCombatPanelClamp(frame, metrics, position)
            end
        end
        -- An expanded Spellbook or Talents takes the true center slot. Native
        -- horizontal placement for that slot uses the entire spanned window.
        if not workspacePositions.PlayerSpellsFrame then
            PrepareCombatPanelClamp(_G.PlayerSpellsFrame, metrics)
        end
    end

    function Canvas:ReleaseCombatPanelClamps()
        if InCombatLockdown() then return end
        local repairDefaults
        for frame, record in pairs(combatPanelClamps) do
            combatPanelClamps[frame] = nil
            local released, shown, name = pcall(function()
                if frame:IsForbidden() ~= false or frame:CanChangeProtectedState() ~= true
                    or not InsetsMatch({frame:GetClampRectInsets()}, record.desired) then return false end
                frame:SetClampRectInsets(unpack(record.original))
                if frame:IsClampedToScreen() then frame:SetClampedToScreen(record.wasClamped) end
                return frame:IsShown(), frame:GetName()
            end)
            if released and shown then
                local mainPositions = Offhand.db and Offhand.db.savedMainPositions
                if record.workspace or (IsPublic(name) and mainPositions and mainPositions[name]) then
                    RestoreWorkspacePosition(frame)
                else
                    repairDefaults = true
                end
            end
        end
        if repairDefaults then self:RepairDefaultForeverSlots() end
    end

    function Canvas:ShouldDeferCombatSocialAnchor(frame)
        local pending = socialWaitingForSpace[frame]
        if not pending then return false end
        local position = Offhand.db and Offhand.db.savedMainPositions and Offhand.db.savedMainPositions.SocialUIFrame
        local current = GetPanelPhysicalPlacement(frame)
        if frame == _G.SocialUIFrame and position == pending.position and current
            and IsPublicNumber(current.width) and IsPublicNumber(current.height)
            and SavedAnchorOverlapsPeer(frame, pending.x, pending.y, current.width, current.height) then return true end
        socialWaitingForSpace[frame] = nil
        return false
    end

    local function RestoreCombatSavedAnchor(frame, workspace, position)
        if combatAnchorRepairing[frame] or type(position) ~= "table" or position.autoRoute
            or not IsPublicNumber(position.x) or not IsPublicNumber(position.y)
            or not Canvas.CanManagePanelsFromAddon()
            or Offhand.CanvasCompatibility.HasMoveAny()
            or Offhand.CanvasCompatibility.HasClassicUIForever()
            or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then return false end
        local ok, restored = pcall(function()
            if not frame.IsForbidden or not IsPublic(frame:IsForbidden()) or frame:IsForbidden()
                or not frame.IsProtected or not IsPublic(frame:IsProtected()) or frame:IsProtected()
                or not frame.CanChangeProtectedState or frame:CanChangeProtectedState() ~= true
                or not frame.IsAnchoringRestricted or frame:IsAnchoringRestricted() ~= false
                or not frame.IsAnchoringSecret or frame:IsAnchoringSecret() ~= false
                or frame:GetParent() ~= UIParent then return false end

            local metrics = WithWorkspace(Offhand.Viewport:GetMetrics())
            if not metrics or not metrics.isSpanned then return false end

            local placement = GetPanelPhysicalPlacement(frame)
            if not placement or not IsPublicNumber(placement.factor) or placement.factor <= 0
                or not IsPublicNumber(placement.x) or not IsPublicNumber(placement.y)
                or not IsPublicNumber(placement.width) or not IsPublicNumber(placement.height)
                or placement.width <= 0 or placement.height <= 0 then return false end
            local x, y = position.x, position.y
            if workspace then
                x, y = ResolveCombatWorkspaceAnchor(metrics, frame, position, placement.width, placement.height)
            else
                local left, right = metrics.gameLeft + 12, metrics.gameRight - 12
                local bottom, top = metrics.gameBottom + 12, metrics.gameTop - 12
                if placement.width > right - left or placement.height > top - bottom then return false end
                x = math.max(left, math.min(x, right - placement.width))
                y = math.max(bottom + placement.height, math.min(y, top))
            end
            if not IsPublicNumber(x) or not IsPublicNumber(y) then return false end
            if frame == _G.SocialUIFrame then
                if not workspace and SavedAnchorOverlapsPeer(frame, x, y, placement.width, placement.height) then
                    socialWaitingForSpace[frame] = {position=position, x=x, y=y}
                    return true
                end
                socialWaitingForSpace[frame] = nil
            end
            if PlacementMatchesPosition(placement, {x=x, y=y}) then return true end
            combatAnchorRepairing[frame] = true
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / placement.factor, y / placement.factor)
            return true
        end)
        combatAnchorRepairing[frame] = nil
        return ok and restored or false
    end

    function Canvas:RepairCombatWorkspaceSlots()
        local db = Offhand.db
        if not Offhand.isForever or not db or not db.enabled or not db.savedWorkspacePositions
            or not GetUIPanel or not InCombatLockdown() then return end
        for _, slot in ipairs(combatSlots) do
            local frame = ReadShownSlot(slot)
            if frame and frame ~= _G.SocialUIFrame and frame.GetName and not IsPanelDragging(frame) then
                local name = frame:GetName()
                local position = IsPublic(name) and type(name) == "string" and db.savedWorkspacePositions[name]
                if position and _G[name] == frame and Canvas:GetPanelController(name) == "generic"
                    and not Offhand.CanvasPanelRegistry.IsContextBoundPanel(name)
                    and not IsUnsafeForPanelMutation(frame, name) then
                    RestoreCombatSavedAnchor(frame, true, position)
                end
            end
        end
    end

    local function RepairShownSocialPanel(frame, suppliedName)
        if not frame or not frame.IsShown or not frame:IsShown()
            or IsPanelDragging(frame) or not Offhand.db or not Offhand.db.enabled then return false end
        if InCombatLockdown() then
            if frame ~= _G.SocialUIFrame then return false end
            local db = Offhand.db
            local workspace = db.savedWorkspacePositions and db.savedWorkspacePositions.SocialUIFrame
            return RestoreCombatSavedAnchor(frame, workspace,
                workspace or db.savedMainPositions and db.savedMainPositions.SocialUIFrame)
        end
        if Canvas:ShouldDeferCombatSocialAnchor(frame) then return true end
        if Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return false end
        local name = (frame.GetName and frame:GetName()) or suppliedName
        if not name then return false end
        local positionOnlyRoot = IsForeverSocialPositionRoot(frame, name)
            or IsForeverSocialPositionRoot(frame, suppliedName)
        if not positionOnlyRoot and IsUnsafeForPanelMutation(frame, name) then return false end

        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.repairing then return false end

        local workspacePosition = Offhand.db.savedWorkspacePositions
            and (Offhand.db.savedWorkspacePositions[name]
                or (suppliedName and Offhand.db.savedWorkspacePositions[suppliedName]))
        local mainPosition = Offhand.db.savedMainPositions
            and (Offhand.db.savedMainPositions[name]
                or (suppliedName and Offhand.db.savedMainPositions[suppliedName]))
        local placement = GetPanelPhysicalPlacement(frame)
        state.repairing = true
        if workspacePosition or mainPosition then
            local savedPosition = workspacePosition or mainPosition
            if not PlacementMatchesPosition(placement, savedPosition) then
                NotePanelControllerActivity(name, "forever-social-community", "saved-repair")
                RestoreWorkspacePosition(frame)
            end
        else
            local sessionPosition = socialMainhandSessionPositions[frame]
            if sessionPosition then
                if not PlacementMatchesPosition(placement, sessionPosition) then
                    NotePanelControllerActivity(name, "forever-social-community", "session-repair")
                    Canvas:PlacePanelOnMainhand(frame, nil,
                        sessionPosition, false, true)
                end
            elseif placement and not placement.onWorkspace and placement.x and placement.y then
                -- Capture the panel's native Mainhand anchor before another member
                -- of Blizzard's shared UIPanel stack recalculates it.
                socialMainhandSessionPositions[frame] = {
                    x = placement.x,
                    y = placement.y,
                }
            elseif placement and placement.onWorkspace then
                -- An unsaved Friends frame has no intentional Offhand ownership.
                -- Restore the last native Mainhand anchor, or center it safely when
                -- this session first discovered the frame after displacement.
                NotePanelControllerActivity(name, "forever-social-community", "mainhand-rescue")
                Canvas:PlacePanelOnMainhand(frame, nil,
                    socialMainhandSessionPositions[frame], false, true)
                local restored = GetPanelPhysicalPlacement(frame)
                if restored and not restored.onWorkspace and restored.x and restored.y then
                    socialMainhandSessionPositions[frame] = {
                        x = restored.x,
                        y = restored.y,
                    }
                end
            end
        end
        state.repairing = nil
        return true
    end

    local function HookSocialPanelAnchorResets(frame, suppliedName)
        if not frame or not hooksecurefunc then return false end
        if Offhand.CanvasPanelRegistry.GetPositionRoot(frame) ~= frame then return false end
        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.hooked then return true end
        state.hooked = true
        hooksecurefunc(frame, "SetPoint", function()
            if state.repairing or IsPanelDragging(frame) or not Offhand.db
                or not Offhand.db.enabled or not frame.IsShown or not frame:IsShown() then return end
            state.generation = (state.generation or 0) + 1
            local generation = state.generation
            -- Root SetPoint hooks run after Blizzard's write but before the next
            -- render. Repair immediately so the native intermediate anchor is not
            -- visible, then retain one bounded next-frame pass for layout work that
            -- continues asynchronously.
            RepairShownSocialPanel(frame, suppliedName)
            local function RepairAfterNativeLayout()
                if generation ~= state.generation or state.repairing
                    or not frame.IsShown or not frame:IsShown() then return end
                RepairShownSocialPanel(frame, suppliedName)
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RepairAfterNativeLayout)
            else
                RepairAfterNativeLayout()
            end
        end)
        return true
    end

    function Canvas:RepairShownSocialCommunityPanels()
        if not Offhand.db or not Offhand.db.enabled then return end
        local inCombat = InCombatLockdown()
        local repaired = setmetatable({}, { __mode = "k" })
        local names = {
            "FriendsFrame", "FriendsListFrame", "SocialFrame", "SocialUIFrame",
            "CommunitiesFrame",
        }
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame and not repaired[frame] and frame.IsShown and frame:IsShown() then
                repaired[frame] = true
                if not inCombat then HookSocialPanelAnchorResets(frame, name) end
                RepairShownSocialPanel(frame, name)
            end
        end
    end
    return GetPanelPhysicalPlacement, PlacementMatchesPosition, HookSocialPanelAnchorResets
end

