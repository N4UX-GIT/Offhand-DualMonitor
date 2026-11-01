--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Canvas.lua: Unsegmented free-space secondary monitor workspace with universal window dragging
--]]

local _, Offhand = ...

local Canvas = {}
Offhand.Canvas = Canvas

local Compatibility = assert(
    Offhand.CanvasCompatibility,
    "Offhand Canvas compatibility must load before Canvas"
)
local HasLeatrixMaps = Compatibility.HasLeatrixMaps
local HasMoveAny = Compatibility.HasMoveAny
local HasClassicUIForever = Compatibility.HasClassicUIForever
local ShouldYieldFrameToClassicUIForever = Compatibility.ShouldYieldFrameToClassicUIForever
local GetWorldMapExternalOwner = Compatibility.GetWorldMapExternalOwner
local IsExternallyPositionedWorldMap = Compatibility.IsExternallyPositionedWorldMap
local ShouldYieldWorldMapToMoveAny = Compatibility.ShouldYieldWorldMap
local IsForeverProfessionsPanel = Compatibility.IsForeverProfessionsPanel
local IsExperimentalForeverProfessionsMovementEnabled =
    Compatibility.IsExperimentalForeverProfessionsMovementEnabled
local ShouldYieldForeverProfessionsPanel = Compatibility.ShouldYieldForeverProfessionsPanel
local IsPersistentForeverProfessionsPanelName =
    Compatibility.IsPersistentForeverProfessionsPanelName
local IsBlizzardEditModeOwnedFrame = Compatibility.IsBlizzardEditModeOwnedFrame
local HasBlizzardEditMode = Compatibility.HasBlizzardEditMode
local IsForeverEditModeFrame = Compatibility.IsForeverEditModeFrame

local FrameState = assert(
    Offhand.CanvasFrameState,
    "Offhand Canvas frame state must load before Canvas"
)
local IsForeverWorldMap = FrameState.IsForeverWorldMap
local GetForeverWorldMapState = FrameState.GetForeverWorldMapState
local GetPanelMarker = FrameState.GetMarker
local SetPanelMarker = FrameState.SetMarker
local SetPanelDragging = FrameState.SetDragging
local IsPanelDragging = FrameState.IsDragging
local IsPanelEvicting = FrameState.IsEvicting
local SetPanelEvicting = FrameState.SetEvicting

local PanelRegistry = assert(
    Offhand.CanvasPanelRegistry,
    "Offhand Canvas panel registry must load before Canvas"
)
local IsContextBoundPanel = PanelRegistry.IsContextBoundPanel

local Persistence = assert(
    Offhand.CanvasPersistence,
    "Offhand Canvas persistence must load before Canvas"
)

local BackpackState = assert(
    Offhand.CanvasBackpackState,
    "Offhand Canvas backpack state must load before Canvas"
)

-- Native Gamepad UI panel visibility, focus and geometry are owned by
-- Blizzard's FrameControlsManager. Even an addon-only marker written onto a
-- managed panel can put later protected focus work in the addon's execution
-- chain. Keep every native panel completely untouched while this interface is
-- active. Addon-owned Canvas controls remain available.
local function CanManagePanelsFromAddon()
    local mainhand = Offhand.Mainhand
    if mainhand and type(mainhand.IsNativeGamepadInterface) == "function"
        and mainhand:IsNativeGamepadInterface() then
        return false
    end
    return not (type(Offhand.IsGamepadUIEnabled) == "function"
        and Offhand:IsGamepadUIEnabled())
end
Canvas.CanManagePanelsFromAddon = CanManagePanelsFromAddon

local rootCanvas


local function IsWorldMapMaximized(frame)
    if not frame or frame ~= _G.WorldMapFrame or not frame.IsMaximized then return false end
    local ok, maximized = pcall(frame.IsMaximized, frame)
    return ok and maximized == true
end

-- Accept metrics from older modules/tests while all live Viewport metrics now
-- expose an explicit workspace rectangle.
local function WithWorkspace(metrics)
    if not metrics or metrics.workspaceLeft ~= nil then return metrics end
    local position = Offhand.db and Offhand.db.primaryPosition or "RIGHT"
    if position == "TOP" then
        metrics.workspaceLeft, metrics.workspaceBottom = 0, 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.screenWidth, metrics.deckWidth
    elseif position == "BOTTOM" then
        metrics.workspaceLeft, metrics.workspaceBottom = 0, metrics.gameTop + (metrics.bezel or 0)
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.screenWidth, metrics.deckWidth
    elseif position == "LEFT" then
        metrics.workspaceLeft, metrics.workspaceBottom = metrics.gameRight + (metrics.bezel or 0), 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.deckWidth, metrics.screenHeight
    else
        metrics.workspaceLeft, metrics.workspaceBottom = 0, 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.deckWidth, metrics.screenHeight
    end
    metrics.workspaceRight = metrics.workspaceLeft + metrics.workspaceWidth
    metrics.workspaceTop = metrics.workspaceBottom + metrics.workspaceHeight
    return metrics
end

function Canvas:CreateFrames()
    if rootCanvas then return end

    -- Root Canvas (covers the secondary monitor as an open, unsegmented free workspace)
    rootCanvas = CreateFrame("Frame", "OffhandCanvasFrame", UIParent,
        not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
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

    local metrics = WithWorkspace(Offhand.Viewport:GetMetrics())

    if not metrics.isSpanned or not Offhand.db.enabled then
        Persistence.FitPlayerSpellsToWorkspace(_G.PlayerSpellsFrame, metrics, false)
        rootCanvas:Hide()
        return
    end

    rootCanvas:Show()
    rootCanvas:ClearAllPoints()
    rootCanvas:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.workspaceLeft, metrics.workspaceBottom)
    rootCanvas:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", metrics.workspaceRight, metrics.workspaceTop)

    -- Apply clean, dark backdrop theme to the workspace
    if Offhand.Themes and Offhand.Themes.ApplyCanvasTheme then
        Offhand.Themes:ApplyCanvasTheme(rootCanvas)
    end

    -- Enable free dragging for standard Blizzard frames so the player can move them anywhere on the workspace
    self:EnableFreeDragging()
    self:UpdateMapMovementBehavior()
end

-- Leatrix Maps configures Blizzard's player, cursor, and crosshair coordinate
-- labels before a live Companion span changes UIParent's effective scale. On
-- affected clients those font strings can retain their pre-span raster size
-- even though the World Map itself has the correct geometry; /reload fixes it
-- only because the labels are then configured after the final scale is known.
-- Refresh the known Blizzard coordinate labels when available, with a narrow
-- text/anchor fallback for older Leatrix releases that created their own
-- coordinate frames. Their font tuple and font object are preserved, and
-- Leatrix retains complete ownership of map scale, anchors, settings, scripts,
-- and saved variables.
assert(Offhand.CanvasMapPresentation, "Offhand map presentation must load before Canvas")
    .InstallFonts(Canvas, {

    })

local function HasLeatrixPlus()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Plus")
    end
    return false
end

local DemodalizePanel, RemodalizePanel, OnPanelDragStop, RestoreWorkspacePosition, IsFrameOnWorkspace
local EvictWorkspacePanelSlot
local nonMovableSystemPanels


-- Preserve the established Canvas API while the ownership policy lives in its
-- dedicated compatibility module.
function Canvas:ShouldYieldWorldMap(frameOrName)
    return ShouldYieldWorldMapToMoveAny(frameOrName)
end

function Canvas:GetCompatibilityDiagnostics(compact)
    return Compatibility.GetDiagnostics(
        compact,
        self._lastLeatrixCoordinateFontRefreshCount
    )
end

local function IsUnsafeForDirectMutation(frame)
    if not frame then return true end
    if ShouldYieldFrameToClassicUIForever(frame) then return true end
    if IsBlizzardEditModeOwnedFrame(frame) then return true end
    if ShouldYieldForeverProfessionsPanel(frame) then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then return true end
    return false
end

-- Forever exposes the Friends surface through more than one protected root
-- name depending on which Social module loaded it. Blizzard provides no Edit
-- Mode system for these roots, but the Gamepad adapter already permits the
-- same out-of-combat, root-anchor-only movement. Keep this exception local to
-- position restoration so protected children and scripts remain untouched.
local foreverSocialPositionRootNames = {
    FriendsFrame = true,
    FriendsListFrame = true,
    SocialFrame = true,
    SocialUIFrame = true,
}

local function IsForeverSocialPositionRoot(frame, suppliedName)
    if not Offhand.isForever or not frame then return false end
    local name = suppliedName or (frame.GetName and frame:GetName())
    if not (name and foreverSocialPositionRootNames[name]) then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    return frame.IsProtected and frame:IsProtected() or false
end

-- One controller must own position repair for every high-risk Forever panel.
-- The generic peer pass previously also repaired World Map and Social roots,
-- even though both families already had dedicated settlement logic. That gave
-- a single native UIPanel transaction multiple position writers and made the
-- result depend on timer order. Keep this policy centralized and observable.
local foreverSocialCommunityControllerNames = {
    FriendsFrame = true,
    FriendsListFrame = true,
    SocialFrame = true,
    SocialUIFrame = true,
    CommunitiesFrame = true,
}
local panelControllerActivity = {}
local panelControllerSequence = 0

local function GetPanelController(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not Offhand.isForever then return "generic" end
    if name == "WorldMapFrame" or IsForeverWorldMap(frame) then
        return ShouldYieldWorldMapToMoveAny(name or frame)
            and "external-world-map" or "forever-world-map"
    end
    if IsForeverProfessionsPanel(frame, name) then
        return IsExperimentalForeverProfessionsMovementEnabled()
            and "forever-professions" or "blizzard-professions"
    end
    if IsForeverEditModeFrame(frame, name) then return "blizzard-edit-mode" end
    if name and foreverSocialCommunityControllerNames[name] then
        return "forever-social-community"
    end
    return "generic"
end

local function NotePanelControllerActivity(frameOrName, controller, action)
    local name = type(frameOrName) == "string" and frameOrName
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    if not name then return end
    panelControllerSequence = panelControllerSequence + 1
    panelControllerActivity[name] = {
        controller = controller or GetPanelController(_G[name], name),
        action = action or "unknown",
        sequence = panelControllerSequence,
    }
end

function Canvas:GetPanelController(frameOrName)
    local frame = type(frameOrName) == "string" and _G[frameOrName] or frameOrName
    local name = type(frameOrName) == "string" and frameOrName
        or (frame and frame.GetName and frame:GetName())
    return GetPanelController(frame, name)
end

function Canvas:GetPanelControllerDiagnostics()
    local names = {
        "WorldMapFrame", "SocialUIFrame", "FriendsFrame",
        "CommunitiesFrame", "ProfessionsFrame", "ProfessionsBookFrame",
    }
    local entries = {}
    for _, name in ipairs(names) do
        local activity = panelControllerActivity[name]
        entries[#entries + 1] = string.format("%s=%s/%s#%s", name,
            GetPanelController(_G[name], name),
            activity and activity.action or "idle",
            activity and tostring(activity.sequence) or "0")
    end
    return table.concat(entries, ",") .. (self.GetRecoveryPolicyDiagnostics
        and (" | Recovery=" .. self:GetRecoveryPolicyDiagnostics()) or "")
end

-- Forever marks several ordinary, load-on-demand UIPanels as protected even
-- while they are only usable out of combat.  They may still be repositioned
-- from a hardware drag while out of combat. Keep the exception restricted to
-- Blizzard's UIPanel registry; secure HUD/Edit Mode frames are not registered
-- here and remain covered by the stricter guard above.
local function IsUnsafeForPanelMutation(frame, name)
    if not frame then return true end
    if ShouldYieldFrameToClassicUIForever(frame, name) then return true end
    if ShouldYieldWorldMapToMoveAny(name or frame) then return true end
    if IsBlizzardEditModeOwnedFrame(frame, name) then return true end
    if ShouldYieldForeverProfessionsPanel(frame, name) then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then
        name = name or (frame.GetName and frame:GetName())
        return not (name and UIPanelWindows and UIPanelWindows[name])
    end
    return false
end

local function IsPersistentPanelLoadCandidate(name)
    return PanelRegistry.IsBasePersistentCandidate(name)
        and (not IsForeverProfessionsPanel(nil, name)
            or IsPersistentForeverProfessionsPanelName(name))
        and not IsForeverEditModeFrame(nil, name)
        and not (nonMovableSystemPanels and nonMovableSystemPanels[name])
end

function Canvas:InitializePanelLoadTracking()
    PanelRegistry.InitializeTracking(self)
end

-- Associate UIPanels created during a Blizzard ADDON_LOADED turn with their
-- owner. This lets later client builds add new load-on-demand panels without
-- requiring another hard-coded Offhand release for reload persistence.
function Canvas:RecordLoadedPanelAddon(addonName)
    PanelRegistry.RecordLoadedPanelAddon(
        self,
        addonName,
        IsPersistentPanelLoadCandidate
    )
end

function Canvas:GetPersistentPanelAddon(name)
    return PanelRegistry.GetPersistentPanelAddon(name)
end

function Canvas:RequestPersistentPanelLoad(name, delaySeconds)
    local retailStandalone = Offhand.isRetail and not Offhand.isForever
        and (name == "PlayerSpellsFrame" or name == "ProfessionsBookFrame")
    if not CanManagePanelsFromAddon()
        or (not Offhand.isForever and not retailStandalone) or not IsPersistentPanelLoadCandidate(name)
        or not Offhand.db or not Offhand.db.openWorkspacePanels
        or not Offhand.db.openWorkspacePanels[name]
        or not Offhand.db.savedWorkspacePositions
        or not Offhand.db.savedWorkspacePositions[name] then return false end

    self:InitializePanelLoadTracking()
    local addonName = self:GetPersistentPanelAddon(name)
    if not addonName then return false end
    if self.panelLoadRequests[name] then return true end
    self.panelLoadRequests[name] = "requested:" .. addonName

    local callOK, loadResult = true, true
    if not PanelRegistry.IsAddonLoaded(addonName) then
        callOK, loadResult = PanelRegistry.LoadAddon(addonName)
    end
    local loaded = PanelRegistry.IsAddonLoaded(addonName)
        or (callOK and loadResult ~= false and loadResult ~= nil)
    self.panelLoadRequests[name] = loaded and "loaded:" .. addonName
        or "failed:" .. addonName
    if not loaded or not C_Timer or not C_Timer.After then return false end

    -- Loading creates and registers the panel synchronously on current clients,
    -- but defer opening it until the addon and its ADDON_LOADED listeners have
    -- completely settled. QueuePersistentPanelRestore performs all final
    -- combat, topology, Professions, and open-state checks again.
    C_Timer.After(0, function()
        local frame = _G[name]
        if not frame then return end
        Canvas:TryMakeFrameDraggable(frame)
        Canvas:QueuePersistentPanelRestore(frame, name, delaySeconds)
    end)
    return true
end

function Canvas:GetPersistentPanelLoadDiagnostics()
    return PanelRegistry.GetDiagnostics(self)
end

local function RegisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    if not CanManagePanelsFromAddon() then return end
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return end
    end
    table.insert(UISpecialFrames, name)
end

local function UnregisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    if not CanManagePanelsFromAddon() then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            table.remove(UISpecialFrames, i)
        end
    end
end

local Chat = assert(
    Offhand.CanvasChat,
    "Offhand chat adapter must load before Canvas"
).Install(Canvas)
local HasCustomChatAddon = Chat.HasCustomChatAddon
local IsSecondaryBlizzardChatFrame = Chat.IsSecondaryBlizzardChatFrame
local IsForeverCombatLog = Chat.IsForeverCombatLog
local GetBlizzardChatDockMembership = Chat.GetBlizzardChatDockMembership
local IsBlizzardChatFrameDocked = Chat.IsBlizzardChatFrameDocked
local QueueForeverChatDockSettlement = Chat.QueueForeverChatDockSettlement
local RefreshDetachedChatPresentation = Chat.RefreshDetachedChatPresentation
local QueueDetachedChatPresentationRefresh = Chat.QueueDetachedChatPresentationRefresh
local ClearTrackedChatState = Chat.ClearTrackedChatState
local RelinquishDockedChatPosition = Chat.RelinquishDockedChatPosition
local ShouldManageBlizzardChatEditBox = Chat.ShouldManageBlizzardChatEditBox

local function IsRetailEditModePrimaryChat(frame)
    return Offhand.HUD and Offhand.HUD.IsRetailEditModePrimaryChat
        and Offhand.HUD:IsRetailEditModePrimaryChat(frame) or false
end

local function IsRetailChatEditModeActive(frame)
    return IsRetailEditModePrimaryChat(frame) and ((frame and frame.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown())
        or (Canvas.IsRetailEditModeChatSettlementActive and Canvas:IsRetailEditModeChatSettlementActive(frame)))
end

local function SaveOpenWorkspacePanels()
    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveOpenPanels then
        Offhand.ForeverPersistence:SaveOpenPanels(Offhand.db and Offhand.db.openWorkspacePanels)
    end
end

-- Forever's ordinary SavedVariables table can be stale or absent on /reload.
-- Position CVars preserve workspace coordinates, but they do not carry the
-- mutually exclusive savedMainPositions ownership table. Commit the complete
-- profile whenever a hardware action transfers a panel across the seam so a
-- later reload cannot resurrect the previous owner.
local function SaveForeverPanelOwnership()
    local persistence = Offhand.isForever and Offhand.ForeverPersistence
    if persistence and persistence.SaveProfileSnapshot then
        return persistence:SaveProfileSnapshot(true)
    end
    return false
end

local backpackRootNames = BackpackState.RootNames

local function IsForeverNativeContainerName(name)
    return BackpackState.IsForeverContainerName(name)
end

local function IsBackpackRoot(name)
    return BackpackState.IsRoot(name)
end

-- Only actual bag roots may request that bags reopen during persistent restore.
-- Baganator exposes many named child regions; treating its entire namespace as
-- a bag root lets stale child snapshots reopen Blizzard's backpack on login.
local function IsRestorableBagRootName(name)
    return BackpackState.IsRestorableRootName(name)
end

local function IsSpannedLayoutActive()
    local viewport = Offhand.Viewport
    if not viewport or not viewport.GetMetrics then return false end
    local ok, metrics = pcall(viewport.GetMetrics, viewport)
    return ok and metrics and metrics.isSpanned == true or false
end

-- Combined and individual bags are two presentations of the same backpack.
-- Only one root may own the saved workspace position at a time; otherwise an
-- inactive root can pull the newly opened presentation back off Mainhand.
local function ClearOtherBackpackRootState(keepName)
    if not Offhand.db then return end
    local changedOpenState = BackpackState.ClearOtherRoots(Offhand.db, keepName)
    for _, rootName in ipairs(backpackRootNames) do
        if rootName ~= keepName then
            if Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
                Offhand.ForeverPersistence:ClearPosition(rootName)
            end
        end
    end
    if changedOpenState then SaveOpenWorkspacePanels() end
end

-- Blizzard replaces the visible backpack root when Combined Bags is toggled.
-- Keep one mode-independent position so that retiring the inactive frame does
-- not also forget where the backpack family belongs.
local function GetNativeBackpackWorkspacePosition()
    return BackpackState.GetWorkspacePosition(Offhand.db)
end

local function IsNativeBackpackTrackedOpen()
    return BackpackState.IsTrackedOpen(Offhand.db)
end

local function ClearNativeBackpackOpenState()
    if not Offhand.db then return end
    local changed = BackpackState.ClearOpenState(Offhand.db)
    if changed then SaveOpenWorkspacePanels() end
end

local function GetShownNativeBackpackRoot()
    return BackpackState.GetShownRoot()
end

local function GetPreferredNativeBackpackRoot()
    return BackpackState.GetPreferredRoot(Offhand.db)
end

function Canvas:GetNativeBackpackWorkspacePosition()
    return GetNativeBackpackWorkspacePosition()
end

function Canvas:PrepareNativeBackpackFrame(frame)
    local name = frame and frame.GetName and frame:GetName()
    if not IsBackpackRoot(name) or not Offhand.db or not IsSpannedLayoutActive() then return false end
    local position = GetNativeBackpackWorkspacePosition()
    if not position then return false end

    local trackedOpen = IsNativeBackpackTrackedOpen()
    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    ClearOtherBackpackRootState(name)
    Offhand.db.savedWorkspacePositions[name] = position
    Offhand.db.nativeBackpackWorkspacePosition = position
    if frame.IsShown and frame:IsShown() then trackedOpen = true end
    Offhand.db.nativeBackpackWorkspaceOpen = trackedOpen or nil
    Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
    Offhand.db.openWorkspacePanels[name] = trackedOpen and true or nil
    SaveOpenWorkspacePanels()

    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveWorkspacePosition then
        Offhand.ForeverPersistence:SaveWorkspacePosition(
            name, position, frame.GetWidth and frame:GetWidth(), frame.GetHeight and frame:GetHeight()
        )
    end
    return true
end

function Canvas:SyncNativeBackpackOpenState()
    if not Offhand.db or not IsSpannedLayoutActive()
        or not GetNativeBackpackWorkspacePosition() then return false end
    local frame = GetShownNativeBackpackRoot()
    local shown = frame ~= nil
    Offhand.db.nativeBackpackWorkspaceOpen = shown and true or nil
    for _, rootName in ipairs(backpackRootNames) do
        if Offhand.db.openWorkspacePanels then
            Offhand.db.openWorkspacePanels[rootName] = nil
        end
    end
    if shown then
        self:PrepareNativeBackpackFrame(frame)
        self:SetWorkspacePanelOpen(frame, true)
    else
        SaveOpenWorkspacePanels()
    end
    return shown
end

-- Kept as a compatibility entry point for beta builds which called this while
-- enabling the canvas. Native snapshots are no longer discarded: the isolated
-- proxy adapter below can safely consume them without attaching to the native
-- title, close button, item buttons, or bag API functions.
function Canvas:RelinquishForeverNativeBags()
    if not Offhand.isForever then return false end
    return false
end

-- Old Offhand builds could capture Blizzard Edit Mode frames as persistent
-- workspace panels. A later ADDON_LOADED restore (Professions is a common
-- trigger) would then call ShowUIPanel on the manager and appear to open Edit
-- Mode alongside the requested window. Purge that historical ownership without
-- touching the live Blizzard frames.
function Canvas:RelinquishForeverEditModeFrames(onlyName)
    if not HasBlizzardEditMode() or not Offhand.db then return false end
    local cleared = false
    local clearedNames = {}
    local tables = {
        Offhand.db.savedWorkspacePositions,
        Offhand.db.savedMainPositions,
        Offhand.db.openWorkspacePanels,
    }
    for _, records in ipairs(tables) do
        if type(records) == "table" then
            for name in pairs(records) do
                if (not onlyName or name == onlyName)
                    and IsForeverEditModeFrame(_G[name], name) then
                    records[name] = nil
                    cleared = true
                    clearedNames[name] = true
                end
            end
        end
    end
    if cleared and Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
        for name in pairs(clearedNames) do
            Offhand.ForeverPersistence:ClearPosition(name)
        end
    end
    if cleared then SaveOpenWorkspacePanels() end
    return cleared
end

function Canvas:SetWorkspacePanelOpen(frameOrName, isOpen)
    if not Offhand.db then return false end
    local name = type(frameOrName) == "string" and frameOrName
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    if not name then return false end
    -- MoveAny owns the live map geometry, but Offhand still owns the user's
    -- explicit request to reopen a saved workspace map after /reload.
    if ShouldYieldWorldMapToMoveAny(name) and not IsExternallyPositionedWorldMap(name)
        and (name ~= "WorldMapFrame" or Offhand.isForever) then return false end
    if IsBackpackRoot(name) and not IsSpannedLayoutActive() then return false end
    if HasBlizzardEditMode() and IsForeverEditModeFrame(frameOrName, name) then
        self:RelinquishForeverEditModeFrames(name)
        return false
    end
    Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
    local hasWorkspacePosition = Offhand.db.savedWorkspacePositions
        and Offhand.db.savedWorkspacePositions[name]
    if not hasWorkspacePosition and IsExternallyPositionedWorldMap(name)
        and type(frameOrName) ~= "string" and IsFrameOnWorkspace(frameOrName) then
        -- The external addon owns the anchor; Offhand stores only independent open
        -- intent. Geometry remains entirely in the external addon's saved variables.
        hasWorkspacePosition = true
    end
    if IsBackpackRoot(name) then
        local exactPosition = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[name]
        if isOpen and type(exactPosition) == "table" and exactPosition.x and exactPosition.y then
            Offhand.db.nativeBackpackWorkspacePosition = exactPosition
        end
        if GetNativeBackpackWorkspacePosition() then
            Offhand.db.nativeBackpackWorkspaceOpen = isOpen and true or nil
        end
    end
    if isOpen and hasWorkspacePosition then
        Offhand.db.openWorkspacePanels[name] = true
    else
        Offhand.db.openWorkspacePanels[name] = nil
    end
    SaveOpenWorkspacePanels()
    if isOpen and name == "PlayerSpellsFrame" then
        Persistence.CapturePlayerSpellsTab(_G[name])
    end
    return Offhand.db.openWorkspacePanels[name] == true
end

assert(Offhand.CanvasMapPresentation, "Offhand map presentation must load before Canvas")
    .InstallBehavior(Canvas, {
        IsFrameOnWorkspace = function(...) return IsFrameOnWorkspace(...) end,
        RegisterSpecialFrame = function(...) return RegisterSpecialFrame(...) end,
        UnregisterSpecialFrame = function(...) return UnregisterSpecialFrame(...) end,
        EvictWorkspacePanelSlot = function(...) return EvictWorkspacePanelSlot(...) end,
    })

function Canvas:UpdatePersistenceBehavior()
    if not Offhand.db then return end
    -- Forever's UI panel manager participates in secure Edit Mode and secret-value
    -- flows. Removing Blizzard frames from its global registries taints later panel
    -- opens, so native Escape behavior wins over persistent-open panels here.
    if Offhand.isForever then return end
    local shouldPersist = (Offhand.db.persistentWorkspacePanels ~= false)
    if WorldMapFrame and not ShouldYieldFrameToClassicUIForever(WorldMapFrame) then
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
            if frame and not ShouldYieldFrameToClassicUIForever(frame, name) then
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
local HookCombinedBagCloseButton = assert(
    Offhand.CanvasPanelLifecycle, "Offhand panel lifecycle must load before Canvas"
).InstallClosePolicy(Canvas, {
    IsFrameOnWorkspace = function(...) return IsFrameOnWorkspace(...) end,
})

-- A load-on-demand UIPanel can register while the same hardware action that
-- loaded its Blizzard addon is still opening it. Calling ShowUIPanel from that
-- registration stack (or its immediate zero-delay continuation) can re-enter
-- the native panel loader and is a credible cause of reported Forever Beta
-- crashes when opening Professions. Give Blizzard time to finish first. If the
-- native K/micro-button path already showed the panel, only restore its saved
-- workspace anchor. Otherwise perform the requested reload restoration after
-- the frame is fully initialized.
function Canvas:QueuePersistentPanelRestore(frame, name, delaySeconds)
    if not frame or not name or not C_Timer or not C_Timer.After then return false end
    if PanelRegistry.GetPositionRoot(frame) ~= frame then return false end
    if IsContextBoundPanel(name) then return false end
    if ShouldYieldFrameToClassicUIForever(frame, name) then return false end
    if ShouldYieldWorldMapToMoveAny(name) then return false end
    if IsForeverEditModeFrame(frame, name) then
        self:RelinquishForeverEditModeFrames(name)
        return false
    end
    if IsForeverProfessionsPanel(frame, name) then
        if ShouldYieldForeverProfessionsPanel(frame, name) then
            self:RelinquishForeverProfessionsPanels(name)
        end
        local db = Offhand.db
        local canRestoreBook = IsPersistentForeverProfessionsPanelName(name)
            and db and db.openWorkspacePanels and db.openWorkspacePanels[name]
            and db.savedWorkspacePositions and db.savedWorkspacePositions[name]
        if not canRestoreBook then return false end
    end
    if GetPanelMarker(frame, "persistentRestoreQueued") then return true end

    SetPanelMarker(frame, "persistentRestoreQueued", true)
    C_Timer.After(tonumber(delaySeconds) or 0.75, function()
        SetPanelMarker(frame, "persistentRestoreQueued", nil)
        local db = Offhand.db
        local shouldRestore = db and db.enabled
            and IsSpannedLayoutActive()
            and db.persistentWorkspacePanels ~= false
            and db.restoreWorkspaceOnReload ~= false
            and db.openWorkspacePanels and db.openWorkspacePanels[name]
            and db.savedWorkspacePositions and db.savedWorkspacePositions[name]
        if not shouldRestore then return end
        if InCombatLockdown() then
            if Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(function()
                    Canvas:QueuePersistentPanelRestore(frame, name)
                end)
            end
            return
        end

        if frame.IsShown and frame:IsShown() then
            RestoreWorkspacePosition(frame)
            if IsPersistentForeverProfessionsPanelName(name) then
                Canvas:QueueExperimentalForeverProfessionsMovement(frame, name)
            end
            return
        end

        if IsContextBoundPanel(name) then return end
        if not CanManagePanelsFromAddon() then return end

        local retailCharacter = Offhand.isRetail and not Offhand.isForever
            and name == "CharacterFrame" and frame == _G.CharacterFrame
        local retailStandalone = Offhand.isRetail and not Offhand.isForever
            and (name == "PlayerSpellsFrame" or name == "ProfessionsBookFrame")
        if retailCharacter and db.independentWorkspacePanels then
            -- CharacterFrame expands its PaperDoll child from OnShow and
            -- collapses it from OnHide. Detach the hidden frame from Blizzard's
            -- left UIPanel slot before opening it so RestoreWorkspacePosition's
            -- OnShow pass never has to evict it with a nested Hide/Show cycle.
            -- Re-entering that lifecycle during the first reload open can leave
            -- CharacterFrameInsetRight (and therefore CharacterStatsPane)
            -- anchored outside the expanded frame until the next clean reopen.
            DemodalizePanel(frame)
        end

        local opened = false
        if retailStandalone and name == "PlayerSpellsFrame" then
            Persistence.RestorePlayerSpellsTab(frame)
        end
        if retailCharacter and ToggleCharacter then
            local ok = pcall(ToggleCharacter, "PaperDollFrame", true)
            opened = ok and frame.IsShown and frame:IsShown()
        end
        if not opened and retailStandalone and db.independentWorkspacePanels and frame.Show then
            -- These standalone menus finish initialization when their addon loads.
            -- Open the saved workspace menu without allocating a shared native
            -- panel slot, which would close a previously restored workspace peer.
            -- Keep native registration and OnShow/OnHide scripts intact. Crafting
            -- interaction roots never enter this path.
            pcall(frame.Show, frame)
        elseif not opened and ShowUIPanel and UIPanelWindows and UIPanelWindows[name] then
            pcall(ShowUIPanel, frame)
        elseif not opened and frame.Show then
            pcall(frame.Show, frame)
        end
        if frame.IsShown and frame:IsShown()
            and IsPersistentForeverProfessionsPanelName(name) then
            Canvas:QueueExperimentalForeverProfessionsMovement(frame, name)
        end

        -- OnShow normally restores the position. Retain a final deferred pass
        -- for panels whose native layout writes its anchor after OnShow.
        C_Timer.After(0, function()
            if frame.IsShown and frame:IsShown() then
                if retailCharacter and frame.RefreshDisplay then
                    -- Use Blizzard's own width/inset refresh after PaperDoll's
                    -- expansion has settled; never take ownership of its child
                    -- stat-pane anchors.
                    pcall(frame.RefreshDisplay, frame)
                end
                RestoreWorkspacePosition(frame)
            end
        end)
    end)
    return true
end

function Canvas:RestorePersistentFrames(mode)
    local activeLockRestore = mode == "lock"
    if not Offhand.db or not Offhand.db.enabled then return end
    if Offhand.isForever and not CanManagePanelsFromAddon() then return end
    self:RelinquishForeverEditModeFrames()
    self:RelinquishForeverNativeBags()
    if not IsSpannedLayoutActive() then return end
    if Offhand.db.persistentWorkspacePanels == false then return end
    -- A first-character intro can begin after PLAYER_ENTERING_WORLD while
    -- Blizzard still owns Escape. Opening inherited account-wide panels here
    -- inserts them into the Escape stack and prevents skip/Game Menu handling.
    if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then
        self.persistentRestorePendingForInput = true
        return
    end
    self.persistentRestorePendingForInput = nil
    if not IsExperimentalForeverProfessionsMovementEnabled() then
        self:RelinquishForeverProfessionsPanels()
    end
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
    local canOpenPanels = CanManagePanelsFromAddon()
    local nativeBackpackOnMainhand = Offhand.db.savedMainPositions
        and (Offhand.db.savedMainPositions.ContainerFrameCombinedBags
            or Offhand.db.savedMainPositions.ContainerFrame1)
    
    for name, _ in pairs(openPanels) do
        local hasWorkspaceOwner = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[name]
        local hasMainhandOwner = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions[name]
        local conflictsWithNativeMainhand = nativeBackpackOnMainhand
            and not IsBackpackRoot(name)
        if hasWorkspaceOwner and not hasMainhandOwner
            and IsRestorableBagRootName(name) and not conflictsWithNativeMainhand then
            hasBag = true
            break
        end
    end
    
    local savedNames = {}
    local savedNameSet = {}
    for name in pairs(Offhand.db.savedWorkspacePositions) do
        savedNames[#savedNames + 1] = name
        savedNameSet[name] = true
    end
    if openPanels.WorldMapFrame and IsExternallyPositionedWorldMap("WorldMapFrame")
        and not savedNameSet.WorldMapFrame then
        savedNames[#savedNames + 1] = "WorldMapFrame"
    end
    table.sort(savedNames)
    local genericRestoreIndex = 0
    for _, name in ipairs(savedNames) do
        local frame = _G[name]
        if frame and ShouldYieldWorldMapToMoveAny(name) then
            if canOpenPanels and name == "WorldMapFrame" and IsExternallyPositionedWorldMap(name)
                and openPanels[name] and not IsContextBoundPanel(name) then
                if not frame:IsShown() then
                    if ToggleWorldMap then ToggleWorldMap() else frame:Show() end
                end
                if frame:IsShown() then self:PreserveExternalWorldMapOpenState(frame) end
            elseif canOpenPanels and name == "WorldMapFrame" and not Offhand.isForever and openPanels[name]
                and not IsContextBoundPanel(name) then
                if not frame:IsShown() then
                    if ToggleWorldMap then ToggleWorldMap() else frame:Show() end
                end
                if frame:IsShown() then Canvas:RepairYieldedWorldMapAnchor(frame) end
            end
        elseif frame
            and not self:ShouldDeferSecondaryChatRestore(frame, name)
            and not IsForeverEditModeFrame(frame, name)
            and (not IsForeverProfessionsPanel(frame, name)
                or IsPersistentForeverProfessionsPanelName(name)) then
            if frame:IsShown() then
                RestoreWorkspacePosition(frame)
            elseif canOpenPanels and openPanels[name] and not IsContextBoundPanel(name) then
                if name == "WorldMapFrame" then
                    if ToggleWorldMap then
                        ToggleWorldMap()
                    else
                        frame:Show()
                    end
                elseif IsRestorableBagRootName(name) then
                    -- An explicit native Mainhand backpack ownership wins over
                    -- stale custom-bag snapshots left by an earlier setup.
                    if not nativeBackpackOnMainhand or IsBackpackRoot(name) then
                        hasBag = true
                    end
                elseif name:match("^ChatFrame") then
                    if not self:IsInactiveNativeChatWindow(frame) then frame:Show() end
                    RestoreWorkspacePosition(frame)
                else
                    -- Generic UIPanels (Character, Quest, Guild, etc.)
                    -- Restore one native UIPanel per settlement window. Forever's
                    -- panel manager otherwise opens every saved left-slot panel
                    -- in the same timer turn, causing each to close the previous
                    -- one before Offhand can detach it from the active slot. Only
                    -- an accepted restore consumes a slot: old addon child-frame
                    -- snapshots must not push valid panels several seconds back.
                    local delay = activeLockRestore and 0.10
                        or (0.75 + genericRestoreIndex * 0.20)
                    if Canvas:QueuePersistentPanelRestore(frame, name, delay) then
                        genericRestoreIndex = genericRestoreIndex + 1
                    end
                end
            end
        elseif canOpenPanels and not frame and openPanels[name] then
            -- Load-on-demand Blizzard frames (Spellbook, Macros, Collections,
            -- and similar panels) do not exist yet after /reload. Load only the
            -- owner of a panel the user explicitly left open on the workspace.
            local delay = activeLockRestore and 0.10
                or (0.75 + genericRestoreIndex * 0.20)
            if Canvas:RequestPersistentPanelLoad(name, delay) then
                genericRestoreIndex = genericRestoreIndex + 1
            end
        end
    end
    
    -- Baganator has its own root-frame snapshot/restore path. The generic
    -- prefix scan can see its still-shown child buttons while the bag is hidden.
    -- Historical Baganator/EUI child snapshots must not resurrect the native
    -- backpack on Forever. Only the explicit mode-independent native marker is
    -- authoritative there.
    if Offhand.isForever then hasBag = IsNativeBackpackTrackedOpen() end
    if canOpenPanels and hasBag and not (Baganator and Offhand.BagPersistence)
        and (not activeLockRestore or not self.activeLockBagRestoreQueued) then
        if activeLockRestore then self.activeLockBagRestoreQueued = true end
        C_Timer.After(activeLockRestore and 0.10 or 1.5, function()
            if activeLockRestore then Canvas.activeLockBagRestoreQueued = nil end
            -- The player can change interface style during the delay.
            if not CanManagePanelsFromAddon() then return end
            -- Combined Backpack mode may never create ContainerFrame1 during
            -- startup, which makes the general compatibility heuristic report
            -- a false custom-bag positive. An explicit saved native root wins.
            local hasNativeCombinedSnapshot = openPanels.ContainerFrameCombinedBags
                and Offhand.db.savedWorkspacePositions.ContainerFrameCombinedBags
                and _G.ContainerFrameCombinedBags
            local hasCustomBagAddon = not hasNativeCombinedSnapshot
                and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
            local isAlreadyOpen = false

            if hasCustomBagAddon then
                if IsBagOpen then isAlreadyOpen = IsBagOpen(0) end
                -- Custom bags can route OpenAllBags to a toggle, so inspect
                -- their actual root frames before invoking it.
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
            else
                -- IsBagOpen() reports logical container state and can remain
                -- true while Forever's Combined Backpack root is hidden.
                -- Native restoration therefore trusts rendered frame state.
                local combined = _G.ContainerFrameCombinedBags
                isAlreadyOpen = combined and combined.IsShown and combined:IsShown() or false
                if not isAlreadyOpen then
                    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                        local frame = _G["ContainerFrame" .. i]
                        if frame and frame.IsShown and frame:IsShown() then
                            isAlreadyOpen = true
                            break
                        end
                    end
                end
            end

            if not isAlreadyOpen then
                if not hasCustomBagAddon and OpenAllBags then
                    OpenAllBags()
                elseif ToggleAllBags then
                    -- Some custom bags ignore OpenAllBags and expose only the
                    -- native toggle route.
                    ToggleAllBags()
                end
            end
        end)
    end

    -- Blizzard and Edit Mode can finish their initial layout after the first
    -- restore pass. Reapply only already-visible saved workspace frames so chat
    -- dimensions and panel-slot detachment win the final startup race.
    if not activeLockRestore and C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if Offhand.db and Offhand.db.enabled then
                Canvas:RepairShownWorkspacePanels()
            end
        end)
    end
end

assert(Offhand.CanvasMapPresentation, "Offhand map presentation must load before Canvas")
    .InstallConfiguration(Canvas, {
        IsWorldMapMaximized = function(...) return IsWorldMapMaximized(...) end,
        IsFrameOnWorkspace = function(...) return IsFrameOnWorkspace(...) end,
        WithWorkspace = function(...) return WithWorkspace(...) end,
        OnPanelDragStop = function(...) return OnPanelDragStop(...) end,
        RestoreWorkspacePosition = function(...) return RestoreWorkspacePosition(...) end,
        RegisterSpecialFrame = function(...) return RegisterSpecialFrame(...) end,
        UnregisterSpecialFrame = function(...) return UnregisterSpecialFrame(...) end,
        EvictWorkspacePanelSlot = function(...) return EvictWorkspacePanelSlot(...) end,
    })

IsFrameOnWorkspace = function(frame)
    if not frame then return false end
    local x = frame:GetLeft()
    local y = frame.GetBottom and frame:GetBottom()
    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m then return false end
    if not x then
        local numPoints = frame.GetNumPoints and frame:GetNumPoints() or 0
        for i = 1, numPoints do
            local _, relTo, _, px = frame:GetPoint(i)
            if px then x = px; break end
        end
    end
    if not x or not y then return false end
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local scaleFactor = frameScale / parentScale
    local width = (frame:GetWidth() or 0) * scaleFactor
    local height = (frame:GetHeight() or 0) * scaleFactor
    if width <= 0 then width = 192 * scaleFactor end
    if height <= 0 then height = 192 * scaleFactor end
    local centerX = (x * scaleFactor) + (width / 2)
    local centerY = (y * scaleFactor) + (height / 2)
    return centerX >= m.workspaceLeft and centerX <= m.workspaceRight
        and centerY >= m.workspaceBottom and centerY <= m.workspaceTop
end

EvictWorkspacePanelSlot, DemodalizePanel, RemodalizePanel = Offhand.CanvasPanelLifecycle.InstallModality(Canvas, {
    IsFrameOnWorkspace = IsFrameOnWorkspace,
    CanManagePanelsFromAddon = CanManagePanelsFromAddon,
    RegisterSpecialFrame = RegisterSpecialFrame,
    UnregisterSpecialFrame = UnregisterSpecialFrame,
})

OnPanelDragStop = Persistence.InstallDrag(Canvas, {
    ShouldYieldFrameToClassicUIForever = function(...) return ShouldYieldFrameToClassicUIForever(...) end,
    ShouldYieldWorldMapToMoveAny = function(...) return ShouldYieldWorldMapToMoveAny(...) end,
    IsForeverProfessionsPanel = function(...) return IsForeverProfessionsPanel(...) end,
    IsExperimentalForeverProfessionsMovementEnabled = function(...) return IsExperimentalForeverProfessionsMovementEnabled(...) end,
    IsPersistentForeverProfessionsPanelName = function(...) return IsPersistentForeverProfessionsPanelName(...) end,
    IsForeverEditModeFrame = function(...) return IsForeverEditModeFrame(...) end,
    SetPanelDragging = function(...) return SetPanelDragging(...) end,
    IsWorldMapMaximized = function(...) return IsWorldMapMaximized(...) end,
    WithWorkspace = function(...) return WithWorkspace(...) end,
    DemodalizePanel = function(...) return DemodalizePanel(...) end,
    EvictWorkspacePanelSlot = function(...) return EvictWorkspacePanelSlot(...) end,
    IsUnsafeForPanelMutation = function(...) return IsUnsafeForPanelMutation(...) end,
    RegisterSpecialFrame = function(...) return RegisterSpecialFrame(...) end,
    UnregisterSpecialFrame = function(...) return UnregisterSpecialFrame(...) end,
    HasCustomChatAddon = function(...) return HasCustomChatAddon(...) end,
    ClearTrackedChatState = function(...) return ClearTrackedChatState(...) end,
    RelinquishDockedChatPosition = function(...) return RelinquishDockedChatPosition(...) end,
    ShouldManageBlizzardChatEditBox = function(...) return ShouldManageBlizzardChatEditBox(...) end,
    IsRetailEditModePrimaryChat = function(...) return IsRetailEditModePrimaryChat(...) end,
    SaveForeverPanelOwnership = function(...) return SaveForeverPanelOwnership(...) end,
    IsBackpackRoot = function(...) return IsBackpackRoot(...) end,
    ClearOtherBackpackRootState = function(...) return ClearOtherBackpackRootState(...) end,
    RemodalizePanel = function(...) return RemodalizePanel(...) end,
    IsFrameOnWorkspace = function(...) return IsFrameOnWorkspace(...) end,
})

Offhand.CanvasPanelPlacement.InstallSingleScreen(Canvas, {
    IsForeverProfessionsPanel = function(...) return IsForeverProfessionsPanel(...) end,
    IsForeverEditModeFrame = function(...) return IsForeverEditModeFrame(...) end,
    IsUnsafeForPanelMutation = function(...) return IsUnsafeForPanelMutation(...) end,
})

-- Forever's Edit Mode can move and resize non-secure utility frames without
-- dispatching their normal drag callbacks. Mirror explicit Combined Backpack
-- and chat saves without touching protected Edit Mode anchors or handlers.
function Canvas:CaptureForeverFramePosition(frame)
    if not Offhand.isForever or InCombatLockdown() or not frame or not Offhand.db
        or not Offhand.db.enabled or not Offhand.ForeverPersistence then return false end
    local name = frame.GetName and frame:GetName()
    if name ~= "ContainerFrameCombinedBags" and not (name and name:match("^ChatFrame%d+$")) then return false end
    if name and name:match("^ChatFrame%d+$") and HasCustomChatAddon() then
        ClearTrackedChatState(name)
        return false
    end
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
        local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        local position = {
            x = x, y = y, width = width, height = height,
            canvasWidth = metrics and metrics.workspaceWidth or nil,
            canvasHeight = metrics and metrics.workspaceHeight or nil,
            canvasLeft = metrics and metrics.workspaceLeft or nil,
            canvasBottom = metrics and metrics.workspaceBottom or nil,
        }
        Offhand.db.savedWorkspacePositions[name] = position
        if IsBackpackRoot(name) then
            Offhand.db.nativeBackpackWorkspacePosition = position
            ClearOtherBackpackRootState(name)
            Offhand.db.savedWorkspacePositions[name] = position
        end
        Offhand.ForeverPersistence:SaveWorkspacePosition(name, position, width, height)
        SaveForeverPanelOwnership()
        return true
    elseif Offhand.db.savedWorkspacePositions[name] then
        Offhand.db.savedWorkspacePositions[name] = nil
        if IsBackpackRoot(name) then
            ClearOtherBackpackRootState(nil)
            Offhand.db.nativeBackpackWorkspacePosition = nil
            Offhand.db.nativeBackpackWorkspaceOpen = nil
        end
        Offhand.ForeverPersistence:ClearPosition(name)
        SaveForeverPanelOwnership()
        return true
    end
    return false
end

Offhand.CanvasPanelPlacement.InstallMainhand(Canvas, {
    RemodalizePanel = function(...) return RemodalizePanel(...) end,
    ShouldYieldFrameToClassicUIForever = function(...) return ShouldYieldFrameToClassicUIForever(...) end,
    ShouldYieldWorldMapToMoveAny = function(...) return ShouldYieldWorldMapToMoveAny(...) end,
    IsForeverProfessionsPanel = function(...) return IsForeverProfessionsPanel(...) end,
    IsForeverEditModeFrame = function(...) return IsForeverEditModeFrame(...) end,
    IsWorldMapMaximized = function(...) return IsWorldMapMaximized(...) end,
    WithWorkspace = function(...) return WithWorkspace(...) end,
    IsForeverSocialPositionRoot = function(...) return IsForeverSocialPositionRoot(...) end,
    IsUnsafeForPanelMutation = function(...) return IsUnsafeForPanelMutation(...) end,
    RegisterSpecialFrame = function(...) return RegisterSpecialFrame(...) end,
    SaveOpenWorkspacePanels = function(...) return SaveOpenWorkspacePanels(...) end,
    SaveForeverPanelOwnership = function(...) return SaveForeverPanelOwnership(...) end,
    IsBackpackRoot = function(...) return IsBackpackRoot(...) end,
    ClearOtherBackpackRootState = function(...) return ClearOtherBackpackRootState(...) end,
    IsFrameOnWorkspace = function(...) return IsFrameOnWorkspace(...) end,
    GetNonMovablePanels = function() return nonMovableSystemPanels end,
})

RestoreWorkspacePosition = Persistence.InstallRestore(Canvas, {
    ShouldYieldFrameToClassicUIForever = function(...) return ShouldYieldFrameToClassicUIForever(...) end,
    ShouldYieldWorldMapToMoveAny = function(...) return ShouldYieldWorldMapToMoveAny(...) end,
    IsForeverProfessionsPanel = function(...) return IsForeverProfessionsPanel(...) end,
    IsExperimentalForeverProfessionsMovementEnabled = function(...) return IsExperimentalForeverProfessionsMovementEnabled(...) end,
    IsForeverEditModeFrame = function(...) return IsForeverEditModeFrame(...) end,
    IsWorldMapMaximized = function(...) return IsWorldMapMaximized(...) end,
    WithWorkspace = function(...) return WithWorkspace(...) end,
    DemodalizePanel = function(...) return DemodalizePanel(...) end,
    EvictWorkspacePanelSlot = function(...) return EvictWorkspacePanelSlot(...) end,
    IsForeverSocialPositionRoot = function(...) return IsForeverSocialPositionRoot(...) end,
    IsUnsafeForPanelMutation = function(...) return IsUnsafeForPanelMutation(...) end,
    RegisterSpecialFrame = function(...) return RegisterSpecialFrame(...) end,
    UnregisterSpecialFrame = function(...) return UnregisterSpecialFrame(...) end,
    HasCustomChatAddon = function(...) return HasCustomChatAddon(...) end,
    ClearTrackedChatState = function(...) return ClearTrackedChatState(...) end,
    ShouldManageBlizzardChatEditBox = function(...) return ShouldManageBlizzardChatEditBox(...) end,
    IsRetailChatEditModeActive = function(...) return IsRetailChatEditModeActive(...) end,
    RemodalizePanel = function(...) return RemodalizePanel(...) end,
})

function Canvas:CaptureRetailEditModeChatPlacement()
    local frame = _G.ChatFrame1
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
        or not IsRetailEditModePrimaryChat(frame) then return end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}
    if IsFrameOnWorkspace(frame) then
        OnPanelDragStop(frame)
    else
        Offhand.db.savedWorkspacePositions.ChatFrame1 = nil
        Offhand.db.savedMainPositions.ChatFrame1 = nil
        self:SetWorkspacePanelOpen("ChatFrame1", false)
        if Offhand.ForeverPersistence then Offhand.ForeverPersistence:ClearPosition("ChatFrame1") end
    end
end

function Canvas:IsRetailEditModeChatSettlementActive(frame)
    return self._retailEditModeChatSettlementActive == true
        and (frame == nil or frame == _G.ChatFrame1)
end

function Canvas:QueueRetailEditModeChatPlacementCapture()
    if Offhand.isForever then return false end
    self._retailEditModeChatSettlementGeneration =
        (self._retailEditModeChatSettlementGeneration or 0) + 1
    local generation = self._retailEditModeChatSettlementGeneration
    self._retailEditModeChatSettlementActive = true

    local function Finish()
        if generation ~= Canvas._retailEditModeChatSettlementGeneration then return end
        Canvas:CaptureRetailEditModeChatPlacement()
        if generation == Canvas._retailEditModeChatSettlementGeneration then
            Canvas._retailEditModeChatSettlementActive = nil
        end
    end

    if C_Timer and C_Timer.After then
        -- Blizzard and Edit Mode consumers can both queue zero-delay SetPoint
        -- work from the close transition. Keep stale-anchor repair suspended
        -- through that complete turn, then capture the settled native result.
        C_Timer.After(0, function()
            if generation ~= Canvas._retailEditModeChatSettlementGeneration then return end
            C_Timer.After(0, Finish)
        end)
    else
        Finish()
    end
    return true
end

local GetPanelPhysicalPlacement
local PlacementMatchesPosition

function Canvas:RepairShownWorkspacePanels(exceptFrame, skipBagCapture)
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
    -- Addon-owned bag roots can be moved by their own Edit Mode without
    -- dispatching Offhand's drag callbacks. Reconcile their physical monitor
    -- before consuming general workspace records so map toggles cannot apply a
    -- stale Offhand anchor over a newly chosen Mainhand position.
    if not skipBagCapture and Offhand.BagPersistence and Offhand.BagPersistence.Capture then
        Offhand.BagPersistence:Capture()
    end
    local repaired = {}
    local function Repair(name, isMainhand)
        if repaired[name] then return end
        repaired[name] = true
        local frame = _G[name]
        if frame and frame ~= exceptFrame and frame.IsShown and frame:IsShown()
            and GetPanelController(frame, name) == "generic"
            and not (isMainhand and IsBackpackRoot(name))
            and not IsUnsafeForPanelMutation(frame, name) then
            local position = isMainhand
                and Offhand.db.savedMainPositions[name]
                or Offhand.db.savedWorkspacePositions[name]
            local placement = GetPanelPhysicalPlacement(frame)
            if not PlacementMatchesPosition(placement, position) then
                NotePanelControllerActivity(name, "generic", "peer-repair")
                RestoreWorkspacePosition(frame)
            end
        end
    end
    for name in pairs(Offhand.db.savedWorkspacePositions or {}) do
        Repair(name, false)
    end
    for name in pairs(Offhand.db.savedMainPositions or {}) do
        if not (Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[name]) then
            Repair(name, true)
        end
    end
end

local HookSocialPanelAnchorResets
GetPanelPhysicalPlacement, PlacementMatchesPosition, HookSocialPanelAnchorResets =
    assert(Offhand.CanvasPanelPlacement, "Offhand panel placement must load before Canvas").Install(Canvas, {
        WithWorkspace = WithWorkspace,
        IsForeverSocialPositionRoot = IsForeverSocialPositionRoot,
        IsUnsafeForPanelMutation = IsUnsafeForPanelMutation,
        NotePanelControllerActivity = NotePanelControllerActivity,
        RestoreWorkspacePosition = RestoreWorkspacePosition,
    })

-- ============================================================================
-- Universal Panel Dragger (Allows moving panels to the secondary monitor)
-- ============================================================================
nonMovableSystemPanels = {
    GameMenuFrame = true,
    SettingsPanel = true,
    InterfaceOptionsFrame = true,
    VideoOptionsFrame = true,
    AudioOptionsFrame = true,
    -- Transient/interactive Blizzard UI is positioned by SeamRedirect (where
    -- safe) or left to secure/Edit Mode ownership. It must never acquire the
    -- generic panel drag, persistence, independent-open, or Escape behavior.
    ZoneTextFrame = true,
    SubZoneTextFrame = true,
    BossBanner = true,
    EventToastManagerFrame = true,
    AlertFrame = true,
    RolePollPopup = true,
    ReadyCheckFrame = true,
    LFGDungeonReadyPopup = true,
    GroupLootContainer = true,
    CombatText = true,
    DamageMeter = true,
    TimerTracker = true,
    OverrideActionBar = true,
    HousingControlsFrame = true,
    HouseEditorFrame = true,
}

Offhand.CanvasPanelPlacement.InstallVoid(Canvas, {
    IsForeverEditModeFrame = function(...) return IsForeverEditModeFrame(...) end,
    WithWorkspace = function(...) return WithWorkspace(...) end,
    IsUnsafeForPanelMutation = function(...) return IsUnsafeForPanelMutation(...) end,
    NonMovablePanels = nonMovableSystemPanels,
})

local function RestoreSavedPositionAfterShow(frame)
    if not frame or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
    if PanelRegistry.GetPositionRoot(frame) ~= frame then return end
    if Offhand.isForever and not CanManagePanelsFromAddon() then return end
    local frameName = frame.GetName and frame:GetName()
    if ShouldYieldFrameToClassicUIForever(frame, frameName) then return end
    if ShouldYieldWorldMapToMoveAny(frameName or frame) then return end
    if IsForeverEditModeFrame(frame, frameName) then
        Canvas:RelinquishForeverEditModeFrames(frameName)
        return
    end
    if IsForeverProfessionsPanel(frame, frameName) then
        if not IsExperimentalForeverProfessionsMovementEnabled()
            or (not frame._OffhandExperimentalProfessionsRestoreAllowed
                and not frame._OffhandExperimentalProfessionsAttached) then return end
    end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if metrics and not metrics.isSpanned then
        Canvas:PlaceForSingleScreenRecovery(frame, metrics)
        if C_Timer and C_Timer.After then
            local generation = (GetPanelMarker(frame, "recoveryGeneration") or 0) + 1
            SetPanelMarker(frame, "recoveryGeneration", generation)
            C_Timer.After(0, function()
                if GetPanelMarker(frame, "recoveryGeneration") ~= generation then return end
                if frame.IsShown and not frame:IsShown() then return end
                Canvas:PlaceForSingleScreenRecovery(frame)
            end)
        end
        return
    end
    local name = frameName
    local workspacePosition = name and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    local mainPosition = name and Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]
    if not workspacePosition and not mainPosition then
        local isNativePanel = name and UIPanelWindows and UIPanelWindows[name]
            and not nonMovableSystemPanels[name]
        if isNativePanel then
            Canvas:PlacePanelOnMainhand(frame, metrics, nil, true)
        else
            Canvas:RescuePanelFromVoid(frame, metrics)
        end
        if C_Timer and C_Timer.After then
            local generation = (GetPanelMarker(frame, "rescueGeneration") or 0) + 1
            SetPanelMarker(frame, "rescueGeneration", generation)
            C_Timer.After(0, function()
                if GetPanelMarker(frame, "rescueGeneration") ~= generation then return end
                if frame.IsShown and not frame:IsShown() then return end
                if isNativePanel then
                    Canvas:PlacePanelOnMainhand(frame, nil, nil, true)
                else
                    Canvas:RescuePanelFromVoid(frame)
                end
            end)
        end
        return
    end

    -- Apply once after Blizzard's show/layout stack has finished. UIPanel and
    -- container managers can set their native anchor after OnShow, which made
    -- the final position depend on panel opening order after a cold launch.
    RestoreWorkspacePosition(frame)
    if C_Timer and C_Timer.After then
        local generation = (GetPanelMarker(frame, "restoreGeneration") or 0) + 1
        SetPanelMarker(frame, "restoreGeneration", generation)
        C_Timer.After(0, function()
            if GetPanelMarker(frame, "restoreGeneration") ~= generation then return end
            if frame.IsShown and not frame:IsShown() then return end
            RestoreWorkspacePosition(frame)
        end)
    end
end

local function HookContainerTitlePersistence(frame, name)
    if not frame or not name or not string.match(name, "^ContainerFrame") then return end
    if IsForeverNativeContainerName(name) then return end
    local titleContainer = frame.TitleContainer or _G[name .. "TitleContainer"]
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

local function HookProtectedContainerPersistence(frame, name)
    if not frame or not name or not name:match("^ContainerFrame") then return false end
    if IsForeverNativeContainerName(name) then return false end
    HookContainerTitlePersistence(frame, name)
    local titleContainer = frame.TitleContainer or _G[name .. "TitleContainer"]
    return titleContainer and titleContainer._OffhandPersistenceHooked == true
end


local function HookPanelCloseButton(frame, name)
    if not frame or not name or name == "ContainerFrameCombinedBags" then return end
    if IsForeverNativeContainerName(name) then return end
    local closeButton = frame.CloseButton or _G[name .. "CloseButton"]
    if not closeButton or not closeButton.HookScript or closeButton._OffhandOpenStateHooked then return end
    closeButton._OffhandOpenStateHooked = true
    closeButton:HookScript("PreClick", function()
        Canvas:SetWorkspacePanelOpen(frame, false)
    end)
end

-- MoveAny can intentionally yield Retail's WorldMapFrame when another addon
-- has made it movable. If both addons then decline the live frame, Blizzard's
-- M/L toggle marks it shown without resolving any bounds. Bootstrap only that
-- anchorless state; once the frame has geometry, MoveAny remains its sole
-- scale, drag, and persistence owner.
assert(Offhand.CanvasMapPresentation, "Offhand map presentation must load before Canvas")
    .InstallBootstrap(Canvas, {
        IsWorldMapMaximized = function(...) return IsWorldMapMaximized(...) end,
        WithWorkspace = function(...) return WithWorkspace(...) end,
    })

local foreverBags = assert(
    Offhand.CanvasForeverBags,
    "Offhand Forever bag adapter must load before Canvas"
).Install(Canvas, {
    WithWorkspace = WithWorkspace,
    IsBackpackRoot = IsBackpackRoot,
    GetNativeBackpackWorkspacePosition = GetNativeBackpackWorkspacePosition,
    IsNativeBackpackTrackedOpen = IsNativeBackpackTrackedOpen,
    ClearNativeBackpackOpenState = ClearNativeBackpackOpenState,
    ClearOtherBackpackRootState = ClearOtherBackpackRootState,
    SaveOpenWorkspacePanels = SaveOpenWorkspacePanels,
    SaveForeverPanelOwnership = SaveForeverPanelOwnership,
    GetShownNativeBackpackRoot = GetShownNativeBackpackRoot,
    IsSpannedLayoutActive = IsSpannedLayoutActive,
    CanManagePanelsFromAddon = CanManagePanelsFromAddon,
    IsForeverProfessionsPanel = IsForeverProfessionsPanel,
    IsFrameOnWorkspace = IsFrameOnWorkspace,
})
local OpenForeverNativeBackpackThroughBlizzard = foreverBags.OpenNativeBackpack
local IsForeverNativeBagPreservingPanelShown = foreverBags.IsPreservingPanelShown
local foreverSystemPanelNames = foreverBags.SystemPanelNames
local InstallForeverOptionsOpeningObservers = foreverBags.InstallOptionsOpeningObservers

local foreverMap = assert(
    Offhand.CanvasForeverMap,
    "Offhand Forever map adapter must load before Canvas"
).Install(Canvas, {
    RegisterSpecialFrame = RegisterSpecialFrame,
    GetPanelPhysicalPlacement = GetPanelPhysicalPlacement,
    PlacementMatchesPosition = PlacementMatchesPosition,
    NotePanelControllerActivity = NotePanelControllerActivity,
    RestoreSavedPositionAfterShow = RestoreSavedPositionAfterShow,
    UnregisterSpecialFrame = UnregisterSpecialFrame,
    EvictWorkspacePanelSlot = EvictWorkspacePanelSlot,
    RestoreWorkspacePosition = RestoreWorkspacePosition,
    WithWorkspace = WithWorkspace,
    OnPanelDragStop = OnPanelDragStop,
})
local RepairUIPanelTransaction = foreverMap.RepairUIPanelTransaction
local AttachForeverWorldMapDragHandle = foreverMap.AttachDragHandle

local PanelMotion = assert(
    Offhand.CanvasPanelMotion,
    "Offhand Canvas panel motion must load before Canvas"
).Install(Canvas, {
    RestoreSavedPositionAfterShow = RestoreSavedPositionAfterShow,
    RestoreWorkspacePosition = RestoreWorkspacePosition,
    IsUnsafeForPanelMutation = IsUnsafeForPanelMutation,
    CanManagePanelsFromAddon = CanManagePanelsFromAddon,
    OnPanelDragStop = OnPanelDragStop,
    HookPanelCloseButton = HookPanelCloseButton,
})
local HookKnownPanelAnchorResets = PanelMotion.HookKnownPanelAnchorResets
local AttachGuardedForeverPanelMotion = PanelMotion.AttachGuardedForeverPanelMotion

local MakePanelDraggable = Offhand.CanvasPanelMotion.InstallGenericDragging(Canvas, {
    ShouldYieldFrameToClassicUIForever = ShouldYieldFrameToClassicUIForever,
    ShouldYieldWorldMapToMoveAny = ShouldYieldWorldMapToMoveAny,
    IsForeverEditModeFrame = IsForeverEditModeFrame,
    IsForeverWorldMap = IsForeverWorldMap,
    SetPanelDragging = SetPanelDragging,
    IsUnsafeForPanelMutation = IsUnsafeForPanelMutation,
    IsForeverNativeContainerName = IsForeverNativeContainerName,
    HookCombinedBagCloseButton = HookCombinedBagCloseButton,
    RestoreSavedPositionAfterShow = RestoreSavedPositionAfterShow,
    HookContainerTitlePersistence = HookContainerTitlePersistence,
    HookPanelCloseButton = HookPanelCloseButton,
    AttachForeverWorldMapDragHandle = AttachForeverWorldMapDragHandle,
    HookKnownPanelAnchorResets = HookKnownPanelAnchorResets,
    AttachGuardedForeverPanelMotion = AttachGuardedForeverPanelMotion,
    OnPanelDragStop = OnPanelDragStop,
})

Canvas.RestoreWorkspacePosition = RestoreWorkspacePosition
Canvas.MakePanelDraggable = MakePanelDraggable
Canvas.HookCombinedBagCloseButton = HookCombinedBagCloseButton
Canvas.IsFrameOnWorkspace = IsFrameOnWorkspace
Canvas.OnPanelDragStop = OnPanelDragStop
Canvas.IsForeverProfessionsPanel = IsForeverProfessionsPanel
Canvas.ShouldYieldForeverProfessionsPanel = ShouldYieldForeverProfessionsPanel

assert(
    Offhand.CanvasProfessions,
    "Offhand Professions adapter must load before Canvas"
).Install(Canvas, {
    CanManagePanelsFromAddon = CanManagePanelsFromAddon,
    IsSpannedLayoutActive = IsSpannedLayoutActive,
    NotePanelControllerActivity = NotePanelControllerActivity,
    RestoreSavedPositionAfterShow = RestoreSavedPositionAfterShow,
    UnregisterSpecialFrame = UnregisterSpecialFrame,
    HookKnownPanelAnchorResets = HookKnownPanelAnchorResets,
    OnPanelDragStop = OnPanelDragStop,
    SaveOpenWorkspacePanels = SaveOpenWorkspacePanels,
})

-- System settings must always open on Mainhand.  Generic void rescue is a
-- fallback and can miss a panel whose geometry is not final on its first show.
function Canvas:PlaceSystemPanelOnMainhand(frame)
    if not Offhand.isForever or not frame or IsUnsafeForDirectMutation(frame)
        or (InCombatLockdown and InCombatLockdown()) then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not metrics or not metrics.isSpanned then return false end

    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if frameScale <= 0 or parentScale <= 0 then return false end
    local factor = frameScale / parentScale
    local x = ((metrics.gameLeft + metrics.gameRight) / 2 - UIParent:GetWidth() / 2) / factor
    local y = ((metrics.gameBottom + metrics.gameTop) / 2 - UIParent:GetHeight() / 2) / factor
    local ok = pcall(function()
        if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end)
    return ok
end

function Canvas:PlaceShownSystemPanelsOnMainhand()
    if not Offhand.isForever or not Offhand.db or not Offhand.db.enabled
        or (InCombatLockdown and InCombatLockdown()) then return 0 end
    local moved = 0
    for _, name in ipairs(foreverSystemPanelNames) do
        local panel = _G[name]
        if panel and panel.IsShown and panel:IsShown()
            and self:PlaceSystemPanelOnMainhand(panel) then
            moved = moved + 1
        end
    end
    return moved
end

-- Opening Blizzard Settings closes native bags as part of its panel cleanup.
-- A workspace backpack marked open is independent workspace content, so reopen
-- only that tracked bag after Settings finishes its transition.
function Canvas:RestoreTrackedWorkspaceBag()
    if not Offhand.isForever or (InCombatLockdown and InCombatLockdown())
        or not Offhand.db or not Offhand.db.enabled
        or Offhand.db.persistentWorkspacePanels == false
        or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
        or not CanManagePanelsFromAddon()
        or not IsSpannedLayoutActive() then return false end
    local saved = GetNativeBackpackWorkspacePosition()
    local trackedOpen = IsNativeBackpackTrackedOpen()
    if not saved or not trackedOpen then return false end

    Canvas._restoringWorkspaceBagFromEscape = true
    local bag = GetPreferredNativeBackpackRoot()
    if not (bag and bag.IsShown and bag:IsShown()) then
        local shownBag = OpenForeverNativeBackpackThroughBlizzard()
        if shownBag and shownBag == bag then bag = shownBag end
        -- Never call Show() on a native ContainerFrame. Blizzard's bag APIs
        -- initialize its pooled item buttons; showing only the frame shell can
        -- leave ContainerFrame_OnHide indexing a nil item button later.
        if not bag then bag = GetPreferredNativeBackpackRoot() end
    end
    local name = bag and bag.GetName and bag:GetName()
    local restored = bag and bag.IsShown and bag:IsShown()
    if restored then
        Canvas:PrepareNativeBackpackFrame(bag)
        RestoreSavedPositionAfterShow(bag)
        Canvas:SetWorkspacePanelOpen(name, true)
    else
        -- The client can retain a logical-open bag state after hiding its root.
        -- During Settings ownership, Forever can deliberately reject every
        -- public bag opener. Keep the tracked intent for the isolated native
        -- bag controller, which can re-show only a root it previously observed
        -- fully initialized. Outside a known panel transition, retain the old
        -- fail-closed behavior so an unavailable shell is never exposed.
        local preservingPanel = Canvas._systemPanelOpeningToken ~= nil
            or IsForeverNativeBagPreservingPanelShown()
        if not preservingPanel then ClearNativeBackpackOpenState() end
    end
    Canvas._restoringWorkspaceBagFromEscape = false
    return restored and true or false
end

-- Settings can run its native bag cleanup after the panel's OnShow callbacks.
-- Keep this short-lived marker separate from normal bag persistence so B and
-- the backpack close button remain explicit closers once the transition ends.
function Canvas:RestoreWorkspaceBagClosedDuringSystemPanelOpen()
    if not Canvas._systemPanelOpeningToken or not C_Timer or not C_Timer.After then
        return false
    end
    C_Timer.After(0, function() Canvas:RestoreTrackedWorkspaceBag() end)
    C_Timer.After(0.10, function() Canvas:RestoreTrackedWorkspaceBag() end)
    return true
end

function Canvas:HookMainhandSystemPanels()
    if not Offhand.isForever then return end
    for _, name in ipairs(foreverSystemPanelNames) do
        local panel = _G[name]
        if panel and panel.HookScript and not panel._OffhandMainhandHooked then
            panel._OffhandMainhandHooked = true
            panel:HookScript("OnShow", function(self)
                local openingToken = {}
                Canvas._systemPanelOpeningToken = openingToken
                local function SettleSystemPanel()
                    if self.IsShown and not self:IsShown() then return end
                    Canvas:PlaceSystemPanelOnMainhand(self)
                    Canvas:RestoreTrackedWorkspaceBag()
                end
                SettleSystemPanel()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, SettleSystemPanel)
                    C_Timer.After(0.50, function()
                        if Canvas._systemPanelOpeningToken == openingToken then
                            Canvas._systemPanelOpeningToken = nil
                        end
                    end)
                end
            end)
        end
        if panel and panel.IsShown and panel:IsShown() then
            Canvas:PlaceSystemPanelOnMainhand(panel)
        end
    end
end

function Canvas:TryMakeFrameDraggable(frame)
    if not frame or not frame.GetName then return end
    if PanelRegistry.GetPositionRoot(frame) ~= frame then return end
    if Offhand.isForever and not CanManagePanelsFromAddon() then return end
    if ShouldYieldFrameToClassicUIForever(frame) then return end
    if ShouldYieldWorldMapToMoveAny(frame) then return end
    if IsForeverWorldMap(frame) then
        MakePanelDraggable(frame)
        return
    end
    if frame._OffhandMovable then return end
    local name = frame:GetName()
    if not name then return end
    if IsForeverProfessionsPanel(frame, name) then
        if ShouldYieldForeverProfessionsPanel(frame, name) then
            self:RelinquishForeverProfessionsPanels(name)
        elseif frame.IsShown and frame:IsShown() then
            self:QueueExperimentalForeverProfessionsMovement(frame, name)
        end
        return
    end
    if nonMovableSystemPanels[name] then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end
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

-- Load-on-demand Blizzard features register their panels independently and do
-- not share a stable exhaustive name list across clients. Discover the native
-- UIPanel registry after each addon load instead of requiring one Offhand entry
-- for every spell book, profession, collection, guild or future panel.
function Canvas:DiscoverUIPanels()
    if not UIPanelWindows or not Offhand.db or not Offhand.db.enabled then return end
    if Offhand.isForever and not CanManagePanelsFromAddon() then return end
    for name in pairs(UIPanelWindows) do
        local frame = _G[name]
        if frame then
            if IsForeverProfessionsPanel(frame, name) then
                if ShouldYieldForeverProfessionsPanel(frame, name) then
                    self:RelinquishForeverProfessionsPanels(name)
                elseif frame.IsShown and frame:IsShown() then
                    self:QueueExperimentalForeverProfessionsMovement(frame, name)
                end
            else
                self:TryMakeFrameDraggable(frame)
            end
            if not IsForeverEditModeFrame(frame, name)
                and not IsForeverProfessionsPanel(frame, name)
                and frame.IsShown and frame:IsShown() then
                RestoreSavedPositionAfterShow(frame)
            end
        end
    end
end

function Canvas:EnableFreeDragging()
    if not Offhand.db or not Offhand.db.enabled then return end
    Persistence.InstallPlayerSpellsCloseObserver(self)
    if Offhand.isForever then InstallForeverOptionsOpeningObservers() end
    if Offhand.isForever and not CanManagePanelsFromAddon() then return end
    self:InitializePanelLoadTracking()
    self:RelinquishClassicUIForeverFrames()
    self:RelinquishForeverEditModeFrames()
    self:RelinquishForeverNativeBags()
    if not IsExperimentalForeverProfessionsMovementEnabled() then
        self:RelinquishForeverProfessionsPanels()
    else
        self:EnableExperimentalForeverProfessionsMovement()
    end
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

    self:HookMainhandSystemPanels()

    -- RegisterUIPanel is the common path used by load-on-demand Blizzard
    -- features (including PlayerSpellsFrame). Hook the registration itself so
    -- a panel cannot be missed because its addon initialized after Offhand's
    -- ADDON_LOADED callback. Never show the frame from the registration turn:
    -- the same K/micro-button action may still be inside Blizzard's native
    -- loader. The settlement queue preserves reload persistence without that
    -- re-entrant panel open.
    if hooksecurefunc and RegisterUIPanel and not self.registerUIPanelHooked then
        self.registerUIPanelHooked = true
        hooksecurefunc("RegisterUIPanel", function(frame)
            local registeredName = frame and frame.GetName and frame:GetName()
            if registeredName then
                Canvas.panelsRegisteredSinceAddonEvent =
                    Canvas.panelsRegisteredSinceAddonEvent or {}
                Canvas.panelsRegisteredSinceAddonEvent[registeredName] = true
            end
            if IsBlizzardEditModeOwnedFrame(frame, registeredName) then
                if IsForeverEditModeFrame(frame, registeredName) then
                    Canvas:RelinquishForeverEditModeFrames(registeredName)
                end
                return
            end
            if IsForeverEditModeFrame(frame, registeredName) then
                Canvas:RelinquishForeverEditModeFrames(registeredName)
                return
            end
            if IsForeverProfessionsPanel(frame, registeredName) then
                if ShouldYieldForeverProfessionsPanel(frame, registeredName) then
                    Canvas:RelinquishForeverProfessionsPanels(registeredName)
                else
                    -- The queue waits beyond the native registration/opening
                    -- stack and verifies that Blizzard actually showed the
                    -- panel before attaching experimental movement.
                    Canvas:QueueExperimentalForeverProfessionsMovement(frame, registeredName)
                end
                return
            end
            local function AttachRegisteredPanel()
                Canvas:TryMakeFrameDraggable(frame)
                local name = frame and frame.GetName and frame:GetName()
                local shouldRestore = name and Offhand.db and Offhand.db.openWorkspacePanels
                    and Offhand.db.openWorkspacePanels[name]
                    and Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name]
                if shouldRestore and frame.IsShown and not frame:IsShown() then
                    Canvas:QueuePersistentPanelRestore(frame, name)
                end
                if frame and frame.IsShown and frame:IsShown() then
                    RestoreSavedPositionAfterShow(frame)
                end
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, AttachRegisteredPanel)
            else
                AttachRegisteredPanel()
            end
        end)
    end

    local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
    local hasCustomMinimap = Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon()

    if Offhand.isForever and not hasCustomBags then
        self:EnableForeverNativeBagProxy()
    end
    if Offhand.isForever and IsExternallyPositionedWorldMap(_G.WorldMapFrame) then
        -- The addon-owned handle stays hidden while the external addon owns geometry;
        -- its read-only observer still preserves Escape and reload open state.
        AttachForeverWorldMapDragHandle(_G.WorldMapFrame)
    end

    local function HookSocialCommunityPanelToggles()
        if not hooksecurefunc or not Canvas._syncExplicitPanelToggle then return end
        local socialNames = {
            "FriendsFrame", "FriendsListFrame", "SocialFrame", "SocialUIFrame",
        }
        for _, frameName in ipairs(socialNames) do
            local frame = _G[frameName]
            if frame then HookSocialPanelAnchorResets(frame, frameName) end
        end
        local toggles = {
            ToggleFriendsFrame = {
                "FriendsFrame", "FriendsListFrame", "SocialFrame", "SocialUIFrame",
            },
            ToggleCommunitiesFrame = {
                "CommunitiesFrame", "FriendsFrame", "FriendsListFrame",
                "SocialFrame", "SocialUIFrame",
            },
            ToggleGuildFrame = {
                "CommunitiesFrame", "FriendsFrame", "FriendsListFrame",
                "SocialFrame", "SocialUIFrame",
            },
        }
        Canvas._socialCommunityToggleHooks = Canvas._socialCommunityToggleHooks or {}
        for functionName, frameNames in pairs(toggles) do
            if type(_G[functionName]) == "function"
                and not Canvas._socialCommunityToggleHooks[functionName] then
                Canvas._socialCommunityToggleHooks[functionName] = true
                hooksecurefunc(functionName, function()
                    for _, frameName in ipairs(frameNames) do
                        local frame = _G[frameName]
                        if frame then Canvas._syncExplicitPanelToggle(frame) end
                    end
                end)
            end
        end
        if ShowUIPanel and not Canvas._socialPanelTransactionHooked then
            Canvas._socialPanelTransactionHooked = true
            hooksecurefunc("ShowUIPanel", function(openedFrame)
                if openedFrame and IsPanelEvicting(openedFrame) then return end
                local function Repair()
                    -- Opening any UIPanel can reflow every other panel in
                    -- Blizzard's shared slots, including an already-visible
                    -- Offhand World Map. Restore all saved peers, but do not
                    -- sample replacement-bag visibility from inside this panel
                    -- transaction because Settings may have hidden it only
                    -- temporarily.
                    RepairUIPanelTransaction(openedFrame, true)
                end
                -- The post-hook catches the usual synchronous left-slot reflow.
                -- Two bounded passes cover panels which finish layout from a
                -- zero-delay continuation without introducing a polling loop.
                Repair()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, Repair)
                    C_Timer.After(0.10, Repair)
                end
            end)
        end
        if HideUIPanel and not Canvas._socialPanelHideTransactionHooked then
            Canvas._socialPanelHideTransactionHooked = true
            hooksecurefunc("HideUIPanel", function(closedFrame)
                if closedFrame and IsPanelEvicting(closedFrame) then return end
                local function Repair()
                    RepairUIPanelTransaction(closedFrame, true)
                end
                Repair()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, Repair)
                    C_Timer.After(0.10, Repair)
                end
            end)
        end
        if type(_G.UpdateUIPanelPositions) == "function"
            and not Canvas._socialPanelLayoutHooked then
            Canvas._socialPanelLayoutHooked = true
            hooksecurefunc("UpdateUIPanelPositions", function()
                -- This is the authoritative completion point for Blizzard's
                -- shared left/center/right panel arrangement. Restore every
                -- saved visible peer plus Social after the manager has written
                -- every native anchor, including close routes and paths which
                -- bypass ShowUIPanel.
                RepairUIPanelTransaction(nil, true)
            end)
        end
    end

    if hooksecurefunc and not Canvas._explicitPanelToggleHooks then
        Canvas._explicitPanelToggleHooks = true
        local function SyncExplicitToggle(frame)
            if not frame or not C_Timer or not C_Timer.After then return end
            if PanelRegistry.GetPositionRoot(frame) ~= frame then return end
            if ShouldYieldWorldMapToMoveAny(frame) then
                if Offhand.isForever then return end
                Canvas:SetWorkspacePanelOpen(frame,
                    frame.IsShown and frame:IsShown() or false)
                Canvas:RepairYieldedWorldMapAnchor(frame)
                C_Timer.After(0, function()
                    Canvas:RepairYieldedWorldMapAnchor(frame)
                end)
                return
            end
            local function SyncPass(repairPeers)
                local name = frame.GetName and frame:GetName()
                if not name or not Offhand.db then return end
                local workspacePosition = Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name]
                local mainPosition = Offhand.db.savedMainPositions
                    and Offhand.db.savedMainPositions[name]
                local shown = frame.IsShown and frame:IsShown()
                if workspacePosition then Canvas:SetWorkspacePanelOpen(name, shown) end
                if shown then
                    if frame == _G.WorldMapFrame and Offhand.isForever
                        and not workspacePosition and not mainPosition then
                        -- Forever's native map cannot receive an OnShow hook: doing
                        -- so taints MapCanvas pin acquisition. Rescue its unsaved
                        -- default anchor from a mixed-height monitor void only from
                        -- this external post-toggle path, and repeat once after
                        -- Blizzard's deferred map layout has completed.
                        local maximized = frame.IsMaximized and frame:IsMaximized()
                        if not maximized then
                            Canvas:RescuePanelFromVoid(frame)
                            C_Timer.After(0, function()
                                if frame.IsShown and frame:IsShown()
                                    and (not frame.IsMaximized or not frame:IsMaximized()) then
                                    Canvas:RescuePanelFromVoid(frame)
                                end
                            end)
                        end
                    elseif workspacePosition or mainPosition then
                        RestoreSavedPositionAfterShow(frame)
                    end
                end
                -- Opening or closing either native left-slot panel can reflow
                -- every other shown UIPanel. Reassert both Offhand and Mainhand
                -- peers from this external post-toggle hook; the restricted
                -- Forever map itself still receives no OnShow/OnHide hooks.
                if repairPeers then
                    RepairUIPanelTransaction(frame)
                end
            end
            -- The secure post-hook still runs inside the native key/button
            -- action, before the next rendered frame. Restore a known anchor
            -- immediately to avoid showing Blizzard's default map position for
            -- one frame, then repeat after deferred native layout settles.
            SyncPass(true)
            C_Timer.After(0, function() SyncPass(true) end)
            C_Timer.After(0.10, function() SyncPass(true) end)
        end
        Canvas._syncExplicitPanelToggle = SyncExplicitToggle
        local function SyncNativeBags()
            if not C_Timer or not C_Timer.After then return end
            C_Timer.After(0, function()
                Canvas:SyncNativeBackpackOpenState()
            end)
        end
        if not Offhand.isForever and ToggleAllBags then hooksecurefunc("ToggleAllBags", SyncNativeBags) end
        if not Offhand.isForever and ToggleBag then hooksecurefunc("ToggleBag", SyncNativeBags) end
        if ToggleWorldMap and not Offhand.isForever then
            hooksecurefunc("ToggleWorldMap", function() SyncExplicitToggle(_G.WorldMapFrame) end)
        end
        if ToggleCharacter then
            hooksecurefunc("ToggleCharacter", function() SyncExplicitToggle(_G.CharacterFrame) end)
        end
    end
    -- Friends and Communities are load-on-demand on some Forever builds.
    -- Re-run this idempotent hook installer after every addon load so opening
    -- either panel repairs the other panel's saved Mainhand/Offhand anchor in
    -- the same UI turn, before Blizzard's shared left-slot reflow is rendered.
    HookSocialCommunityPanelToggles()

    if not Offhand.isForever and hooksecurefunc and ToggleQuestLog and Canvas._syncExplicitPanelToggle
        and not Canvas._toggleQuestLogPersistenceHooked then
        Canvas._toggleQuestLogPersistenceHooked = true
        -- Forever's L binding opens the quest view through the same
        -- WorldMapFrame but bypasses ToggleWorldMap. Observe both native entry
        -- points so they converge on one saved map anchor. This late-load guard
        -- retries after Blizzard addons initialize the quest-log function.
        hooksecurefunc("ToggleQuestLog", function()
            Canvas._syncExplicitPanelToggle(_G.WorldMapFrame)
        end)
    end

    -- Forever's Escape path calls CloseAllBags followed by ToggleGameMenu
    -- directly; it does not pass through CloseAllWindows. Pair those native
    -- calls within one event turn so B and the backpack X remain explicit
    -- closers while Escape restores a workspace backpack after opening or
    -- closing the Game Menu. Each hook has a retryable late-load guard.
    if not Offhand.isForever and hooksecurefunc and CloseAllBags
        and not Canvas._closeAllBagsEscapeHooked then
        Canvas._closeAllBagsEscapeHooked = true
        hooksecurefunc("CloseAllBags", function()
            if Canvas._restoringWorkspaceBagFromEscape or not C_Timer or not C_Timer.After
                or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
                or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
                or not IsSpannedLayoutActive() then
                Canvas._workspaceBagAwaitingGameMenuToggle = nil
                return
            end
            local saved = GetNativeBackpackWorkspacePosition()
            local wasTrackedOpen = IsNativeBackpackTrackedOpen()
            if not saved or not wasTrackedOpen or GetShownNativeBackpackRoot() then return end

            -- Forever Settings may close bags after its OnShow handler. Restore
            -- from this post-hook while the bounded opening marker is active.
            if Canvas:RestoreWorkspaceBagClosedDuringSystemPanelOpen() then
                Canvas._workspaceBagAwaitingGameMenuToggle = nil
                return
            end

            local token = {}
            Canvas._workspaceBagAwaitingGameMenuToggle = {
                token = token,
                menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                    and GameMenuFrame:IsShown() or false,
            }
            C_Timer.After(0, function()
                local pending = Canvas._workspaceBagAwaitingGameMenuToggle
                if pending and pending.token == token then
                    Canvas._workspaceBagAwaitingGameMenuToggle = nil
                end
            end)
        end)
    end

    if not Offhand.isForever and hooksecurefunc and ToggleGameMenu
        and not Canvas._toggleGameMenuEscapeHooked then
        Canvas._toggleGameMenuEscapeHooked = true
        hooksecurefunc("ToggleGameMenu", function()
            local pending = Canvas._workspaceBagAwaitingGameMenuToggle
            if not pending or not C_Timer or not C_Timer.After then return end
            Canvas._workspaceBagAwaitingGameMenuToggle = nil
            if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then
                return
            end
            C_Timer.After(0, function()
                if (InCombatLockdown and InCombatLockdown()) or not Offhand.db or not Offhand.db.enabled then
                    Canvas._restoringWorkspaceBagFromEscape = false
                    return
                end
                if not IsSpannedLayoutActive() then
                    Canvas._restoringWorkspaceBagFromEscape = false
                    return
                end
                local menuShouldBeShown = not pending.menuWasShown
                Canvas._restoringWorkspaceBagFromEscape = true
                if ToggleAllBags then
                    pcall(ToggleAllBags)
                elseif OpenAllBags then
                    pcall(OpenAllBags)
                end
                local bag = GetShownNativeBackpackRoot()
                if not bag then bag = GetPreferredNativeBackpackRoot() end
                local name = bag and bag.GetName and bag:GetName()
                if bag and bag.IsShown and bag:IsShown() then
                    Canvas:PrepareNativeBackpackFrame(bag)
                    RestoreSavedPositionAfterShow(bag)
                    Canvas:SetWorkspacePanelOpen(name, true)
                else
                    ClearNativeBackpackOpenState()
                end
                -- ToggleGameMenu's post-hook runs before Forever finishes the
                -- menu transition, so derive the desired result from the stable
                -- state captured before Escape closed the bags.
                local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
                    and GameMenuFrame:IsShown() or false
                if menuShouldBeShown ~= menuIsShown then
                    -- A second ToggleGameMenu closes the backpack again on
                    -- Forever. Direct Show/Hide was verified to preserve the
                    -- bag while keeping the Escape-derived end state.
                    if menuShouldBeShown and GameMenuFrame and GameMenuFrame.Show then
                        pcall(function() GameMenuFrame:Show() end)
                    elseif GameMenuFrame and GameMenuFrame.Hide then
                        pcall(function() GameMenuFrame:Hide() end)
                    end
                end
                C_Timer.After(0, function()
                    Canvas._restoringWorkspaceBagFromEscape = false
                end)
            end)
        end)
    end

    -- List of standard frames that players love dragging to their secondary workspace
    local frameNames = {
        "WorldMapFrame",
        "CharacterFrame",
        "QuestLogFrame",
        "SpellBookFrame",
        "TalentFrame",
        "PlayerTalentFrame",
        "FriendsFrame",
        "SocialUIFrame",
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
    if not HasBlizzardEditMode() and not EditModeManagerFrame then
        table.insert(frameNames, "PartyMemberFrame1")
        table.insert(frameNames, "CompactPartyFrame")
        table.insert(frameNames, "CompactRaidFrameContainer")
    end

    if not HasBlizzardEditMode() and not hasCustomMinimap then
        table.insert(frameNames, "MinimapCluster")
    end

    if not hasCustomBags and not Offhand.isForever then
        for i = 1, 13 do
            table.insert(frameNames, "ContainerFrame" .. i)
        end
        table.insert(frameNames, "ContainerFrameCombinedBags")
    end

    for _, name in ipairs(frameNames) do
        local frame = _G[name]
        if frame and not IsForeverEditModeFrame(frame, name)
            and not ShouldYieldFrameToClassicUIForever(frame, name)
            and not ShouldYieldWorldMapToMoveAny(frame) then
            local unsafe = IsUnsafeForPanelMutation(frame, name)
            if unsafe and name:match("^ContainerFrame") then
                -- Protected native bags already implement title dragging. Only
                -- observe that hardware drag; do not add an overlay, replace a
                -- handler, or make the protected frame movable ourselves.
                HookProtectedContainerPersistence(frame, name)
            elseif not unsafe then
                MakePanelDraggable(frame)
            end
            if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
                DemodalizePanel(frame)
            end
        end
    end

    self:DiscoverUIPanels()

    if not hasCustomBags and not Offhand.isForever
        and ContainerFrame_GenerateFrame and not Canvas._bagGenHooked then
        Canvas._bagGenHooked = true
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            if frame and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                local name = frame.GetName and frame:GetName()
                if IsUnsafeForDirectMutation(frame) then
                    HookProtectedContainerPersistence(frame, name)
                else
                    MakePanelDraggable(frame)
                end
            end
        end)
    end

    if not HasBlizzardEditMode() and not hasCustomMinimap and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"] and MinimapCluster then
        RestoreWorkspacePosition(MinimapCluster)
    end
    if not HasBlizzardEditMode() and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["PartyMemberFrame1"] and _G.PartyMemberFrame1 then
        RestoreWorkspacePosition(_G.PartyMemberFrame1)
    end
    

    -- Hook Chat Frames and Tabs for workspace dragging and persistence
    local function ApplyTrackedChatPosition(chatFrame)
        if HasCustomChatAddon() or IsBlizzardChatFrameDocked(chatFrame) then return false end
        chatFrame._OffhandApplyingTrackedChatPosition = true
        local ok = pcall(RestoreWorkspacePosition, chatFrame)
        chatFrame._OffhandApplyingTrackedChatPosition = nil
        return ok
    end

    local function RestoreTrackedChatPosition(chatFrame)
        if not chatFrame or not Offhand.db or not Offhand.db.enabled
            or InCombatLockdown() or chatFrame._OffhandDragging
            or MOVING_CHATFRAME == chatFrame or IsRetailChatEditModeActive(chatFrame) then return end
        local chatName = chatFrame.GetName and chatFrame:GetName()
        if not chatName then return end
        local workspacePosition = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[chatName]
        local mainPosition = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions[chatName]
        if not workspacePosition and not mainPosition then return end

        local function applyDetachedPosition()
            if not Offhand.db or not Offhand.db.enabled or InCombatLockdown()
                or chatFrame._OffhandDragging or MOVING_CHATFRAME == chatFrame
                or IsRetailChatEditModeActive(chatFrame)
                or (Offhand.isForever
                    and GetBlizzardChatDockMembership(chatFrame) ~= false) then return end
            -- ChatFrame2 is Blizzard's built-in Combat Log. Never turn it on,
            -- change its saved dock bit, or replay floating presentation during
            -- automatic recovery. A genuinely detached and already visible
            -- Combat Log may still receive its explicitly dragged position.
            if IsForeverCombatLog(chatFrame, chatName)
                and chatFrame.IsShown and not chatFrame:IsShown() then return end
            if not IsForeverCombatLog(chatFrame, chatName) then
                RefreshDetachedChatPresentation(chatFrame, chatName)
            end
            ApplyTrackedChatPosition(chatFrame)
            chatFrame._OffhandChatRestoreGeneration =
                (chatFrame._OffhandChatRestoreGeneration or 0) + 1
            local generation = chatFrame._OffhandChatRestoreGeneration
            if C_Timer and C_Timer.After then C_Timer.After(0, function()
                if chatFrame._OffhandChatRestoreGeneration ~= generation
                    or chatFrame._OffhandDragging or MOVING_CHATFRAME == chatFrame
                    or (chatFrame.IsShown and not chatFrame:IsShown()) then return end
                ApplyTrackedChatPosition(chatFrame)
            end) end
        end

        -- A Forever secondary chat frame is not restored until Blizzard's dock
        -- membership agrees twice. This prevents an inactive docked Combat Log
        -- from being shown over General while still preserving genuinely
        -- detached custom windows. Settled dock membership retires an obsolete
        -- Offhand snapshot so later reloads cannot replay it.
        if Offhand.isForever and IsSecondaryBlizzardChatFrame(chatFrame, chatName) then
            QueueForeverChatDockSettlement(chatFrame, "tracked-position", function(isDocked)
                if not Offhand.isForever or not Offhand.db or not Offhand.db.enabled then return end
                if isDocked == true then
                    -- A settled live dock entry prevents restoration. Retire
                    -- the snapshot only when Blizzard's persisted state also
                    -- says docked; disagreement can still be a slow startup
                    -- transition for a genuinely detached window.
                    local id = chatFrame.GetID and chatFrame:GetID()
                        or tonumber(chatName:match("(%d+)$"))
                    local ok, nativeDocked = false, nil
                    if id and FCF_GetChatWindowInfo then
                        local values = {pcall(FCF_GetChatWindowInfo, id)}
                        ok = values[1]
                        nativeDocked = values[10]
                    end
                    if ok and nativeDocked == true then
                        ClearTrackedChatState(chatName)
                    end
                elseif isDocked == false then
                    applyDetachedPosition()
                end
            end)
            return
        end

        if IsBlizzardChatFrameDocked(chatFrame, chatName) then return end
        applyDetachedPosition()
    end

    local function RegisterChatFrame(chatFrame)
        if not chatFrame then return end
        local chatName = chatFrame.GetName and chatFrame:GetName()
        if chatName and HasCustomChatAddon() then
            ClearTrackedChatState(chatName)
            return
        end
        if IsForeverEditModeFrame(chatFrame, chatName) then
            Canvas:RelinquishForeverEditModeFrames(chatName)
            return
        end
        if chatFrame._OffhandChatHooked then return end
        chatFrame._OffhandChatHooked = true
        if not IsBlizzardChatFrameDocked(chatFrame, chatName)
            and chatFrame.SetClampedToScreen then
            pcall(function() chatFrame:SetClampedToScreen(false) end)
        end

        if chatFrame.HookScript then
            chatFrame:HookScript("OnShow", function(self)
                RestoreTrackedChatPosition(self)
            end)
            chatFrame:HookScript("OnDragStart", function(self) self._OffhandDragging = true end)
            chatFrame:HookScript("OnDragStop", function(self)
                self._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                OnPanelDragStop(self)
            end)
        end

        local chatTab = chatName and _G[chatName .. "Tab"]
        if chatTab and not chatTab._OffhandTabHooked and chatTab.HookScript then
            chatTab._OffhandTabHooked = true

            -- Observe Blizzard's native chat-tab drag without changing its lock,
            -- docking, drag registration or movable state. Forcing StartMoving on
            -- Forever's locked static ChatFrame1 raises "Frame is not movable".
            chatTab:HookScript("OnDragStart", function()
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                chatFrame._OffhandDragging = true
            end)

            chatTab:HookScript("OnDragStop", function(self)
                chatFrame._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                -- Docked tabs belong to GeneralDockManager (or its scroll child),
                -- not the message frame. Persist the associated chat window.
                OnPanelDragStop(chatFrame)
            end)
        end
    end

    if not HasCustomChatAddon() and FCF_StopDragging and not Canvas._fcfHooked then
        Canvas._fcfHooked = true
        hooksecurefunc("FCF_StopDragging", function(chatFrame)
            if chatFrame and Offhand.db and Offhand.db.enabled
                and not HasCustomChatAddon() then
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

    if not HasCustomChatAddon() and FCF_DockFrame and not Canvas._fcfDockHooked then
        Canvas._fcfDockHooked = true
        hooksecurefunc("FCF_DockFrame", function(chatFrame)
            -- Forever calls FCF_DockFrame while rebuilding chat windows during
            -- login even when the saved window is detached. Only a dock that
            -- occurs inside Blizzard's observed tab-drag transaction represents
            -- the player's decision to relinquish Offhand's saved position.
            if chatFrame and Offhand.db and Offhand.db.enabled
                and (chatFrame._OffhandDragging or MOVING_CHATFRAME == chatFrame) then
                RelinquishDockedChatPosition(chatFrame)
            end
        end)
    end

    if not HasCustomChatAddon() and FCF_PopInWindow and not Canvas._fcfPopInHooked then
        Canvas._fcfPopInHooked = true
        hooksecurefunc("FCF_PopInWindow", function(frame, fallback)
            -- "Close Window" routes through FCF_PopInWindow for ordinary
            -- custom chat windows. Relinquish the saved monitor snapshot so a
            -- deliberate close is not mistaken for reload-time visibility loss.
            local chatFrame = fallback or frame
            local name = chatFrame and chatFrame.GetName and chatFrame:GetName()
            if name and name:match("Tab$") then
                chatFrame = _G[name:gsub("Tab$", "")]
                name = chatFrame and chatFrame.GetName and chatFrame:GetName()
            end
            if name and IsSecondaryBlizzardChatFrame(chatFrame, name) then
                ClearTrackedChatState(name)
            end
        end)
    end

    -- Forever's manager participates in protected/secret-value Edit Mode paths.
    -- Even a read-only OnHide hook makes Offhand part of that execution chain
    -- and can prevent native Party Frame dragging. Retail alone needs this hook
    -- to hand ChatFrame1 placement back after Edit Mode closes.
    if not Offhand.isForever and EditModeManagerFrame and EditModeManagerFrame.HookScript
        and not EditModeManagerFrame._OffhandRetailChatExitHooked then
        EditModeManagerFrame._OffhandRetailChatExitHooked = true
        EditModeManagerFrame:HookScript("OnHide", function()
            Canvas:QueueRetailEditModeChatPlacementCapture()
        end)
    end

    if not HasCustomChatAddon() and FCF_SavePositionAndDimensions and not Canvas._fcfSaveHooked then
        Canvas._fcfSaveHooked = true
        hooksecurefunc("FCF_SavePositionAndDimensions", function(chatFrame)
            local name = chatFrame and chatFrame.GetName and chatFrame:GetName()
            if name and Offhand.db and Offhand.db.enabled then
                if Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name] then
                    if IsBlizzardChatFrameDocked(chatFrame, name) then
                        -- Ignore Forever's transient startup dock save. The
                        -- explicit FCF_DockFrame/drag path above owns re-docks.
                        RestoreTrackedChatPosition(chatFrame)
                    else
                        Canvas:CaptureForeverFramePosition(chatFrame)
                    end
                elseif Offhand.isForever and Offhand.db.savedMainPositions
                    and Offhand.db.savedMainPositions[name] then
                    -- Forever can replay an unspanned/full-canvas anchor while
                    -- rebuilding detached chat windows during login. Preserve
                    -- the last explicit Mainhand drop after that native save.
                    RestoreTrackedChatPosition(chatFrame)
                end
            end
        end)
    end

    -- Forever's chat-color picker can run a dock-oriented fade update after it
    -- writes the chosen color/opacity, suppressing textures on a physically
    -- detached frame. Reassert the newly saved Blizzard values on the next
    -- frame. Native Settings initialization may use doNotSave=true, so observe
    -- both forms; Offhand's own replay is excluded by the per-frame guard.
    if not HasCustomChatAddon() and FCF_SetWindowColor and not Canvas._fcfColorHooked then
        Canvas._fcfColorHooked = true
        hooksecurefunc("FCF_SetWindowColor", function(chatFrame)
            QueueDetachedChatPresentationRefresh(chatFrame)
        end)
    end
    if not HasCustomChatAddon() and FCF_SetWindowAlpha and not Canvas._fcfAlphaHooked then
        Canvas._fcfAlphaHooked = true
        hooksecurefunc("FCF_SetWindowAlpha", function(chatFrame)
            QueueDetachedChatPresentationRefresh(chatFrame)
        end)
    end

    if not HasCustomChatAddon() and FCF_OpenNewWindow and not Canvas._fcfNewHooked then
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
            local chatName = "ChatFrame" .. i
            if (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
                or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[chatName]) then
                RestoreTrackedChatPosition(cf)
            end
        end
    end
    self:ReconcileForeverCombatLogOwnership()

    self:ConfigureWorldMap()
    self:UpdatePersistenceBehavior()
end

function Offhand:InitializeCanvas()
    Canvas:CreateFrames()

    function Canvas:RefreshAfterAddonLoaded(loadedAddon)
        self:RecordLoadedPanelAddon(loadedAddon)
        self:EnableFreeDragging()
        self:UpdateMapMovementBehavior()
        self:UpdatePersistenceBehavior()
        self:ConfigureWorldMap()
        -- Other ADDON_LOADED handlers may create/register their panel later in
        -- the same event dispatch. Rescan movement support once initialization
        -- settles, but never perform a global visibility restore here. Dynamic
        -- UIPanels use the targeted RegisterUIPanel queue above; restoring every
        -- saved frame would reopen unrelated panels such as the World Map when
        -- Collections, Professions, or another load-on-demand addon initializes.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                Canvas:EnableFreeDragging()
            end)
        end
    end

    -- Re-check draggable frames when Blizzard on-demand addons load
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(_, _, loadedAddon)
        Canvas:RefreshAfterAddonLoaded(loadedAddon)
    end)
    Canvas:UpdateMapMovementBehavior()
    Canvas:UpdatePersistenceBehavior()
    Canvas:ConfigureWorldMap()

    if Offhand.isForever and C_Timer and C_Timer.NewTicker and not Canvas.foreverPositionTicker then
        Canvas.foreverPositionTicker = C_Timer.NewTicker(0.5, function()
            if Offhand._displayGeometryTransitionActive then return end
            Canvas:RetryMissingExperimentalForeverProfessionsMovement()
            Canvas:MonitorDetachedChatSettingsPresentation()
            local editModeShown = EditModeManagerFrame and EditModeManagerFrame.IsShown
                and EditModeManagerFrame:IsShown()
            if editModeShown then
                Canvas._foreverEditModeWasShown = true
            elseif Canvas._foreverEditModeWasShown then
                Canvas._foreverEditModeWasShown = false
                -- Blizzard can display the saved chat width in Edit Mode while
                -- applying a stale runtime width. Trust Offhand's last explicit
                -- FCF save and restore it after protected Edit Mode closes.
                Canvas:RepairShownWorkspacePanels()
                return
            else
                return
            end
            Canvas:CaptureForeverFramePosition(_G.ContainerFrameCombinedBags)
        end)
    end

        if not Offhand.isForever and not Canvas.showUIPanelHooked and ShowUIPanel then
        Canvas.showUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(frame)
            if IsForeverEditModeFrame(frame) or IsUnsafeForDirectMutation(frame) then return end
            if frame and UIPanelWindows and UIPanelWindows[frame:GetName()] and not UIPanelWindows[frame:GetName()].area then
                if not frame:IsShown() then frame:Show() end
            end
            Canvas:TryMakeFrameDraggable(frame)
            RestoreSavedPositionAfterShow(frame)
        end)
    end
    if not Offhand.isForever and not Canvas.hideUIPanelHooked and HideUIPanel then
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




