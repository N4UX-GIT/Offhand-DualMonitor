--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Canvas.lua: Unsegmented free-space secondary monitor workspace with universal window dragging
--]]

local _, Offhand = ...

local Canvas = {}
Offhand.Canvas = Canvas

local rootCanvas

-- Never store Offhand bookkeeping on Forever's native World Map object. The
-- shareable user-waypoint pin enters restricted Blizzard code on Shift-click;
-- addon fields or handlers anywhere in that native map tree can taint the
-- protected chat-link action. Keep all of our state in an addon-owned weak
-- table instead.
local foreverWorldMapState = setmetatable({}, { __mode = "k" })

-- Forever's native bag item buttons enter protected UseContainerItem paths.
-- Keep all Offhand state and input handlers outside the ContainerFrame tree so
-- moving the bag root does not also install addon code on an item-action
-- ancestor.  The only native writes performed by this adapter are the root
-- movement requested by a hardware drag and an out-of-combat anchor restore.
local foreverNativeBagState = setmetatable({}, { __mode = "k" })
local foreverNativeBagController

local function IsForeverWorldMap(frame)
    return Offhand.isForever and frame and frame == _G.WorldMapFrame
end

local function GetForeverWorldMapState(frame)
    if not IsForeverWorldMap(frame) then return nil end
    local state = foreverWorldMapState[frame]
    if not state then
        state = {}
        foreverWorldMapState[frame] = state
    end
    return state
end

local function SetPanelDragging(frame, dragging)
    local state = GetForeverWorldMapState(frame)
    if state then
        state.dragging = dragging and true or false
    else
        frame._OffhandDragging = dragging and true or false
    end
end

local function IsPanelDragging(frame)
    local state = GetForeverWorldMapState(frame)
    if state then return state.dragging == true end
    return frame and frame._OffhandDragging == true or false
end

local function IsPanelEvicting(frame)
    local state = GetForeverWorldMapState(frame)
    if state then return state.evicting == true end
    return frame._OffhandEvictingPanelSlot
end

local function SetPanelEvicting(frame, evicting)
    local state = GetForeverWorldMapState(frame)
    if state then
        state.evicting = evicting and true or false
    else
        frame._OffhandEvictingPanelSlot = evicting and true or nil
    end
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
local EvictWorkspacePanelSlot
local nonMovableSystemPanels

-- These panels live in Blizzard load-on-demand addons and therefore do not
-- exist during the first PLAYER_ENTERING_WORLD persistence pass. The table is
-- only a bootstrap for established Blizzard frames; subsequent registrations
-- are learned at runtime and saved with the active Offhand profile.
local knownPanelLoadAddons = {
    PlayerSpellsFrame = "Blizzard_PlayerSpells",
    SpellBookFrame = "Blizzard_SpellBook",
    MacroFrame = "Blizzard_MacroUI",
    CollectionsJournal = "Blizzard_Collections",
    CollectionsJournalFrame = "Blizzard_Collections",
    WardrobeFrame = "Blizzard_Collections",
    AchievementFrame = "Blizzard_AchievementUI",
    AlliedRacesFrame = "Blizzard_AlliedRacesUI",
    ArchaeologyFrame = "Blizzard_ArchaeologyUI",
    CalendarFrame = "Blizzard_Calendar",
    CalendarViewEventFrame = "Blizzard_Calendar",
    ClassTalentFrame = "Blizzard_ClassTalentUI",
    EncounterJournal = "Blizzard_EncounterJournal",
    ExpansionLandingPage = "Blizzard_ExpansionLandingPage",
    MajorFactionRenownFrame = "Blizzard_MajorFactions",
    PVEFrame = "Blizzard_GroupFinder",
    PVPUIFrame = "Blizzard_PVPUI",
    CommunitiesFrame = "Blizzard_Communities",
    GuildFrame = "Blizzard_GuildUI",
    WeeklyRewardsFrame = "Blizzard_WeeklyRewards",
}

-- Position can still be remembered for these panels, but their visibility is
-- tied to a unit, NPC, bank, mailbox, taxi node, or other interaction that no
-- longer exists after /reload. Loading and showing their shell would create a
-- broken or misleading UI, so they deliberately retain native reload behavior.
local contextBoundPanelNames = {
    AuctionHouseFrame = true,
    BankFrame = true,
    BlackMarketFrame = true,
    ClassTrainerFrame = true,
    FlightMapFrame = true,
    GuildBankFrame = true,
    GuildControlUI = true,
    GuildRegistrarFrame = true,
    InspectFrame = true,
    ItemInteractionFrame = true,
    ItemSocketingFrame = true,
    ItemUpgradeFrame = true,
    MailFrame = true,
    MerchantFrame = true,
    OpenMailFrame = true,
    ScrappingMachineFrame = true,
    StableFrame = true,
    TabardFrame = true,
    TradeFrame = true,
    TransmogFrame = true,
}

-- Forever's load-on-demand Professions UI has produced repeatable client
-- crashes while Offhand participates in its registration, drag, or restore
-- lifecycle. Treat the complete Professions family as Blizzard-owned by
-- default. A separately consented experimental path supports delayed movement
-- without reconnecting it to the generic panel lifecycle.
local function IsForeverProfessionsPanel(frame, suppliedName)
    if not Offhand.isForever then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not name then return false end
    return name == "TradeSkillFrame" or name == "CraftFrame"
        or name:match("^Professions") ~= nil
        or name:match("^Profession") ~= nil
        or name:match("TradeSkill") ~= nil
end

local function IsExperimentalForeverProfessionsMovementEnabled()
    return Offhand.isForever
        and Offhand.IsExperimentalForeverProfessionsMovementEnabled
        and Offhand:IsExperimentalForeverProfessionsMovementEnabled() or false
end

local function ShouldYieldForeverProfessionsPanel(frame, suppliedName)
    return IsForeverProfessionsPanel(frame, suppliedName)
        and not IsExperimentalForeverProfessionsMovementEnabled()
end

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
    EssentialCooldownViewer = true,
    UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true,
    BottomManagedFrameContainer = true,
}

-- Edit Mode systems are Blizzard-owned on every client that exposes them.
-- Treat the new native Damage Meter as part of the same family even during
-- load-on-demand initialization, when its protection flags can be incomplete.
local function IsBlizzardEditModeOwnedFrame(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    return name and (name:match("^EditMode") ~= nil
        or name:match("^DamageMeter") ~= nil) or false
end

local function HasBlizzardEditMode()
    if Offhand.isRetail or Offhand.isForever then return true end
    if C_EditMode ~= nil or EditModeManagerFrame ~= nil then return true end
    local version = tonumber(Offhand.tocVersion)
    return (version and (version >= 100000 or (version >= 16000 and version < 17000))) or false
end

local function IsForeverEditModeFrame(frame, suppliedName)
    if not HasBlizzardEditMode() then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if IsBlizzardEditModeOwnedFrame(frame, name) then return true end
    -- Forever's primary chat is a Blizzard Edit Mode system on newer builds,
    -- but older builds do not expose it that way. Feature-detect the native
    -- contract so legacy chat persistence remains available where appropriate.
    if name == "ChatFrame1" and Offhand.isForever and frame
        and type(frame.OnEditModeEnter) == "function"
        and type(frame.OnEditModeExit) == "function" then
        return true
    end
    if not name then return false end
    return foreverEditModeFrameNames[name]
        or name:match("^EditMode") ~= nil
        or name:match("CooldownViewer") ~= nil
        or name:match("ManagedFrameContainer") ~= nil
        or name:match("^PartyMemberFrame") ~= nil
        or name:match("^CompactPartyFrame") ~= nil
        or name:match("^CompactRaidFrame") ~= nil
end

local function IsUnsafeForDirectMutation(frame)
    if not frame then return true end
    if IsBlizzardEditModeOwnedFrame(frame) then return true end
    if ShouldYieldForeverProfessionsPanel(frame) then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then return true end
    return false
end

-- Forever marks several ordinary, load-on-demand UIPanels as protected even
-- while they are only usable out of combat.  They may still be repositioned
-- from a hardware drag while out of combat. Keep the exception restricted to
-- Blizzard's UIPanel registry; secure HUD/Edit Mode frames are not registered
-- here and remain covered by the stricter guard above.
local function IsUnsafeForPanelMutation(frame, name)
    if not frame then return true end
    if IsBlizzardEditModeOwnedFrame(frame, name) then return true end
    if ShouldYieldForeverProfessionsPanel(frame, name) then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then
        name = name or (frame.GetName and frame:GetName())
        return not (name and UIPanelWindows and UIPanelWindows[name])
    end
    return false
end

local function IsBlizzardLoadAddonName(name)
    return type(name) == "string" and name:match("^Blizzard_[%w_]+$") ~= nil
end

local function IsPersistentPanelLoadCandidate(name)
    return type(name) == "string" and name:match("^[%w_]+$") ~= nil
        and not contextBoundPanelNames[name]
        and not IsForeverProfessionsPanel(nil, name)
        and not IsForeverEditModeFrame(nil, name)
        and not (nonMovableSystemPanels and nonMovableSystemPanels[name])
end

function Canvas:InitializePanelLoadTracking()
    if self.knownUIPanelNames then return end
    self.knownUIPanelNames = {}
    self.panelsRegisteredSinceAddonEvent = {}
    self.panelLoadRequests = {}
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do self.knownUIPanelNames[name] = true end
    end
end

-- Associate UIPanels created during a Blizzard ADDON_LOADED turn with their
-- owner. This lets later client builds add new load-on-demand panels without
-- requiring another hard-coded Offhand release for reload persistence.
function Canvas:RecordLoadedPanelAddon(addonName)
    self:InitializePanelLoadTracking()
    local canRemember = IsBlizzardLoadAddonName(addonName)
    Offhand.db.workspacePanelLoadAddons = Offhand.db.workspacePanelLoadAddons or {}
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            local newlySeen = not self.knownUIPanelNames[name]
                or self.panelsRegisteredSinceAddonEvent[name]
            if canRemember and newlySeen and IsPersistentPanelLoadCandidate(name) then
                Offhand.db.workspacePanelLoadAddons[name] = addonName
            end
            self.knownUIPanelNames[name] = true
        end
    end
    self.panelsRegisteredSinceAddonEvent = {}
end

local function IsAddonLoadedCompat(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok then return loaded == true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok then return loaded == true end
    end
    return false
end

local function LoadAddonCompat(addonName)
    if C_AddOns and C_AddOns.LoadAddOn then
        return pcall(C_AddOns.LoadAddOn, addonName)
    elseif LoadAddOn then
        return pcall(LoadAddOn, addonName)
    end
    return false, "api_unavailable"
end

function Canvas:GetPersistentPanelAddon(name)
    local learned = Offhand.db and Offhand.db.workspacePanelLoadAddons
    local addonName = type(learned) == "table" and learned[name] or nil
    if IsBlizzardLoadAddonName(addonName) then return addonName, "learned" end
    addonName = knownPanelLoadAddons[name]
    if IsBlizzardLoadAddonName(addonName) then return addonName, "known" end
    return nil, "unknown"
end

function Canvas:RequestPersistentPanelLoad(name, delaySeconds)
    if not Offhand.isForever or not IsPersistentPanelLoadCandidate(name)
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
    if not IsAddonLoadedCompat(addonName) then
        callOK, loadResult = LoadAddonCompat(addonName)
    end
    local loaded = IsAddonLoadedCompat(addonName)
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
    local learnedCount = 0
    local learned = Offhand.db and Offhand.db.workspacePanelLoadAddons
    if type(learned) == "table" then
        for _, addonName in pairs(learned) do
            if IsBlizzardLoadAddonName(addonName) then learnedCount = learnedCount + 1 end
        end
    end
    local requests = {}
    for name, status in pairs(self.panelLoadRequests or {}) do
        requests[#requests + 1] = name .. "=" .. status
    end
    table.sort(requests)
    return string.format("Learned=%d | Requests=%s", learnedCount,
        #requests > 0 and table.concat(requests, ",") or "none")
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

local function HasChattynator()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Chattynator")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Chattynator")
    end
    return false
end

local function IsSecondaryBlizzardChatFrame(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    local index = name and tonumber(name:match("^ChatFrame(%d+)$"))
    return index and index > 1 or false
end

local function GetBlizzardChatDockMembership(frame)
    local dock = GENERAL_CHAT_DOCK or GeneralDockManager
    if not dock or type(dock.DOCKED_CHAT_FRAMES) ~= "table" then return nil end
    for _, dockedFrame in pairs(dock.DOCKED_CHAT_FRAMES) do
        if dockedFrame == frame then return true end
    end
    return false
end

local function IsBlizzardChatFrameDocked(frame, suppliedName)
    if not IsSecondaryBlizzardChatFrame(frame, suppliedName) then return false end
    -- Forever can leave isDocked/isStaticDocked set after a chat tab has been
    -- pulled out of the primary dock.  The dock manager's membership table is
    -- the current topology and must win over those stale compatibility fields.
    local membership = GetBlizzardChatDockMembership(frame)
    if membership ~= nil then return membership end
    if FCF_IsDocked then
        local ok, docked = pcall(FCF_IsDocked, frame)
        if ok and docked then return true end
    end
    if frame.isDocked == true or frame.isDocked == 1
        or frame.isStaticDocked == true then return true end
    return false
end

local function RefreshDetachedChatPresentation(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not IsSecondaryBlizzardChatFrame(frame, name) or HasChattynator()
        or GetBlizzardChatDockMembership(frame) ~= false
        or frame._OffhandRefreshingChatPresentation then return false end

    -- Forever can remove a tab from DOCKED_CHAT_FRAMES without completing the
    -- visual part of its floating-window transition. Do not call
    -- FCF_UnDockFrame here: built-in windows such as Combat Log can be saved as
    -- hidden while docked, and running that transition before repairing the
    -- shown bit makes Blizzard hide them. Commit shown first, then the detached
    -- saved state, and normalize only the stale runtime isDocked flag.
    -- Do this even when the legacy flags are already nil: the reverted
    -- undock-based beta cleared them before a later native update hid custom
    -- windows, and those windows need the same non-destructive recovery.
    frame._OffhandRefreshingChatPresentation = true
    local id = frame.GetID and frame:GetID() or tonumber(name:match("(%d+)$"))
    if id and SetChatWindowShown then pcall(SetChatWindowShown, id, true) end
    if id and SetChatWindowDocked then pcall(SetChatWindowDocked, id, false) end
    frame.isDocked = nil
    local wasLocked = frame.isLocked
    if wasLocked ~= nil and FCF_SetLocked then
        pcall(FCF_SetLocked, frame, wasLocked)
    end

    -- A docked frame may have every CHAT_FRAME_TEXTURES entry faded to
    -- zero. Reapply the player's own saved background color and opacity through
    -- Blizzard's setters so its floating border/background becomes visible
    -- without Offhand inventing or persisting presentation values.
    if id and FCF_GetChatWindowInfo then
        local ok, _, _, r, g, b, alpha = pcall(FCF_GetChatWindowInfo, id)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number"
            and FCF_SetWindowColor then
            pcall(FCF_SetWindowColor, frame, r, g, b, true)
        end
        if ok and type(alpha) == "number" and FCF_SetWindowAlpha then
            pcall(FCF_SetWindowAlpha, frame, alpha, true)
        end
    end
    -- A tracked detached window is expected to remain visible. Repair the
    -- shown bit damaged by the previous undock-based implementation and use
    -- Blizzard's normal visibility helper for both message frame and tab.
    local tab = _G[name .. "Tab"]
    if FCF_CheckShowChatFrame then
        pcall(FCF_CheckShowChatFrame, frame)
    else
        if frame.Show then pcall(frame.Show, frame) end
    end
    -- FCF_CheckShowChatFrame expects the scrolling message frame, not its tab.
    -- Forever can leave the tab hidden even after the saved shown bit is fixed.
    if tab and tab.Show then pcall(tab.Show, tab) end
    if FCF_FadeInChatFrame then pcall(FCF_FadeInChatFrame, frame) end
    frame._OffhandRefreshingChatPresentation = nil
    return true
end

-- One beta build could erase a detached Combat Log snapshot after mistaking
-- Forever's transient login dock for a user re-dock. Blizzard still retains
-- DOCKED=0 and the native position, but SHOWN=0 leaves the window unreachable.
-- Repair that exact signature once, then capture the recovered native position
-- so subsequent reloads use the normal tracked-chat path.
function Canvas:RecoverLostForeverCombatLog()
    if not Offhand.isForever or HasChattynator() or not Offhand.db
        or not Offhand.db.enabled or not FCF_GetChatWindowInfo then return false end
    if type(OffhandDB) ~= "table" then return false end
    OffhandDB.compatibility = OffhandDB.compatibility or {}
    if (tonumber(OffhandDB.compatibility.detachedCombatLogRecoveryVersion) or 0) >= 1 then
        return false
    end

    local frame = _G.ChatFrame2
    if not frame then return false end
    local tracked = (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions.ChatFrame2)
        or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions.ChatFrame2)
    local ok, windowName, _, _, _, _, _, shown, _, docked = pcall(FCF_GetChatWindowInfo, 2)
    if not ok or type(windowName) ~= "string" then return false end
    OffhandDB.compatibility.detachedCombatLogRecoveryVersion = 1
    if tracked or windowName ~= "Combat Log" or shown ~= false or docked ~= false then
        return false
    end

    if SetChatWindowShown then pcall(SetChatWindowShown, 2, true) end
    if FCF_CheckShowChatFrame then pcall(FCF_CheckShowChatFrame, frame)
    elseif frame.Show then pcall(frame.Show, frame) end
    local tab = _G.ChatFrame2Tab
    if tab and tab.Show then pcall(tab.Show, tab) end
    if FCF_FadeInChatFrame then pcall(FCF_FadeInChatFrame, frame) end

    local function capture()
        if frame.IsShown and frame:IsShown()
            and not IsBlizzardChatFrameDocked(frame, "ChatFrame2") then
            OnPanelDragStop(frame)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.20, capture) else capture() end
    return true
end

local function QueueDetachedChatPresentationRefresh(frame)
    if not frame or frame._OffhandChatAppearanceRefreshPending
        or frame._OffhandRefreshingChatPresentation or HasChattynator()
        or not Offhand.db or not Offhand.db.enabled then return end
    local name = frame.GetName and frame:GetName()
    if not IsSecondaryBlizzardChatFrame(frame, name)
        or GetBlizzardChatDockMembership(frame) ~= false then return end
    local tracked = (Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[name])
        or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name])
    if not tracked then return end

    local function refresh(finalPass)
        if not frame._OffhandRefreshingChatPresentation then
            RefreshDetachedChatPresentation(frame, name)
        end
        if finalPass then frame._OffhandChatAppearanceRefreshPending = nil end
    end
    frame._OffhandChatAppearanceRefreshPending = true
    if C_Timer and C_Timer.After then
        -- Forever's chat Settings flow performs another dock-oriented fade
        -- after the color/opacity setters return. The next-frame replay keeps
        -- ordinary picker changes responsive; the bounded settlement pass
        -- restores the final saved values after that later native fade.
        C_Timer.After(0, function() refresh(false) end)
        C_Timer.After(0.20, function() refresh(true) end)
    else
        refresh(true)
    end
end

-- Forever's Chat Settings panel can fade floating chat chrome without routing
-- that work through FCF_SetWindowColor/FCF_SetWindowAlpha. Observe the panel
-- from Offhand's own ticker instead of hooking the Blizzard panel into our call
-- chain, then replay only the saved presentation of tracked detached windows.
function Canvas:MonitorDetachedChatSettingsPresentation()
    if HasChattynator() or not Offhand.db or not Offhand.db.enabled then return end
    local settingsShown = ChatConfigFrame and ChatConfigFrame.IsShown
        and ChatConfigFrame:IsShown() or false
    local transitioned = settingsShown ~= self._detachedChatSettingsWasShown
    self._detachedChatSettingsWasShown = settingsShown
    if not transitioned and not settingsShown then return end

    for i = 2, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        local name = frame and frame.GetName and frame:GetName()
        local tracked = name and ((Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name])
            or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
        if tracked and GetBlizzardChatDockMembership(frame) == false then
            QueueDetachedChatPresentationRefresh(frame)
        end
    end
end

local function ClearTrackedChatState(name)
    if not name or not Offhand.db then return false end
    local cleared = false
    for _, key in ipairs({"savedWorkspacePositions", "savedMainPositions", "openWorkspacePanels"}) do
        local records = Offhand.db[key]
        if records and records[name] ~= nil then
            records[name] = nil
            cleared = true
        end
    end
    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
        Offhand.ForeverPersistence:ClearPosition(name)
    end
    return cleared
end

local function RelinquishDockedChatPosition(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not name or not IsBlizzardChatFrameDocked(frame, name) then return false end
    ClearTrackedChatState(name)

    -- Chattynator reparents the native Combat Log (ChatFrame2), anchors it on
    -- two sides inside its custom holder, and hides Blizzard's chrome. Never
    -- resize or reanchor that borrowed native frame.
    if HasChattynator() then return true end

    local dock = GENERAL_CHAT_DOCK or GeneralDockManager
    local primary = dock and dock.primary or _G.ChatFrame1
    if primary and primary ~= frame and primary.GetWidth and primary.GetHeight
        and frame.SetSize then
        local width, height = primary:GetWidth(), primary:GetHeight()
        local currentWidth = frame.GetWidth and frame:GetWidth()
        local currentHeight = frame.GetHeight and frame:GetHeight()
        if width and width > 0 and height and height > 0
            and (not currentWidth or not currentHeight
                or math.abs(currentWidth - width) > 0.001
                or math.abs(currentHeight - height) > 0.001) then
            pcall(frame.SetSize, frame, width, height)
        end
    end
    return true
end

-- Chattynator deliberately reuses Blizzard's primary edit box while anchoring
-- it to an unnamed Chattynator window.  Reattaching that edit box to the hidden
-- ChatFrame1 makes Enter focus a valid but invisible input field.
local function ShouldManageBlizzardChatEditBox(frame)
    return frame == ChatFrame1 and not HasChattynator()
end

local function IsRetailEditModePrimaryChat(frame)
    return Offhand.HUD and Offhand.HUD.IsRetailEditModePrimaryChat
        and Offhand.HUD:IsRetailEditModePrimaryChat(frame) or false
end

local function IsRetailChatEditModeActive(frame)
    return IsRetailEditModePrimaryChat(frame) and ((frame and frame.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown()))
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

local backpackRootNames = {
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
}

local function IsForeverNativeContainerName(name)
    return Offhand.isForever and type(name) == "string"
        and name:match("^ContainerFrame") ~= nil
end

local function IsBackpackRoot(name)
    return name == "ContainerFrame1" or name == "ContainerFrameCombinedBags"
end

-- Only actual bag roots may request that bags reopen during persistent restore.
-- Baganator exposes many named child regions; treating its entire namespace as
-- a bag root lets stale child snapshots reopen Blizzard's backpack on login.
local function IsRestorableBagRootName(name)
    if type(name) ~= "string" then return false end
    return name:match("^ContainerFrame%d+$") ~= nil
        or name == "ContainerFrameCombinedBags"
        or name == "EUI_MainBagFrame"
        or name:match("^Baganator_SingleViewBackpackViewFrame") ~= nil
        or name:match("^Baganator_CategoryViewBackpackViewFrame") ~= nil
        or name:match("^Baginator") ~= nil
        or name:match("^BGR") ~= nil
        or name:match("^Bagnon") ~= nil
        or name:match("^AdiBags") ~= nil
        or name:match("^BetterBags") ~= nil
        or name:match("^ArkInventory") ~= nil
        or name == "CustomBagRestorer"
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
    local changedOpenState = false
    for _, rootName in ipairs(backpackRootNames) do
        if rootName ~= keepName then
            if Offhand.db.savedWorkspacePositions then
                Offhand.db.savedWorkspacePositions[rootName] = nil
            end
            if Offhand.db.savedMainPositions then
                Offhand.db.savedMainPositions[rootName] = nil
            end
            if Offhand.db.openWorkspacePanels and Offhand.db.openWorkspacePanels[rootName] then
                Offhand.db.openWorkspacePanels[rootName] = nil
                changedOpenState = true
            end
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
    if not Offhand.db then return nil end
    local position = Offhand.db.nativeBackpackWorkspacePosition
    if type(position) == "table" and position.x and position.y then
        return position
    end
    local saved = Offhand.db.savedWorkspacePositions
    if type(saved) ~= "table" then return nil end
    for _, rootName in ipairs(backpackRootNames) do
        position = saved[rootName]
        if type(position) == "table" and position.x and position.y then
            Offhand.db.nativeBackpackWorkspacePosition = position
            return position
        end
    end
    return nil
end

local function IsNativeBackpackTrackedOpen()
    if not Offhand.db then return false end
    if Offhand.db.nativeBackpackWorkspaceOpen == true then return true end
    local openPanels = Offhand.db.openWorkspacePanels
    if type(openPanels) ~= "table" then return false end
    for _, rootName in ipairs(backpackRootNames) do
        if openPanels[rootName] then
            Offhand.db.nativeBackpackWorkspaceOpen = true
            return true
        end
    end
    return false
end

local function ClearNativeBackpackOpenState()
    if not Offhand.db then return end
    Offhand.db.nativeBackpackWorkspaceOpen = nil
    if Offhand.db.openWorkspacePanels then
        for _, rootName in ipairs(backpackRootNames) do
            Offhand.db.openWorkspacePanels[rootName] = nil
        end
    end
    SaveOpenWorkspacePanels()
end

local function GetShownNativeBackpackRoot()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.IsShown and combined:IsShown() then return combined end
    local individual = _G.ContainerFrame1
    if individual and individual.IsShown and individual:IsShown() then return individual end
    return nil
end

local function GetPreferredNativeBackpackRoot()
    local saved = Offhand.db and Offhand.db.savedWorkspacePositions
    if saved and saved.ContainerFrameCombinedBags then return _G.ContainerFrameCombinedBags end
    if saved and saved.ContainerFrame1 then return _G.ContainerFrame1 end
    local prefersCombined = GetCVarBool and GetCVarBool("combinedBags")
    return prefersCombined and _G.ContainerFrameCombinedBags or _G.ContainerFrame1
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
    if IsBackpackRoot(name) and not IsSpannedLayoutActive() then return false end
    if HasBlizzardEditMode() and IsForeverEditModeFrame(frameOrName, name) then
        self:RelinquishForeverEditModeFrames(name)
        return false
    end
    Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
    local hasWorkspacePosition = Offhand.db.savedWorkspacePositions
        and Offhand.db.savedWorkspacePositions[name]
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
    return Offhand.db.openWorkspacePanels[name] == true
end

function Canvas:UpdateMapMovementBehavior()
    local map = WorldMapFrame
    if not map then return end
    if HasLeatrixMaps() then return end
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

function Canvas:UpdatePersistenceBehavior()
    if not Offhand.db then return end
    -- Forever's UI panel manager participates in secure Edit Mode and secret-value
    -- flows. Removing Blizzard frames from its global registries taints later panel
    -- opens, so native Escape behavior wins over persistent-open panels here.
    if Offhand.isForever then return end
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

if not Offhand.isForever and not Offhand.isRetail
    and CloseAllBags and not _G.Offhand_OriginalCloseAllBags then
    _G.Offhand_OriginalCloseAllBags = CloseAllBags
    CloseAllBags = function(...)
        return HandleCustomCloseAllBags(_G.Offhand_OriginalCloseAllBags, ...)
    end
end

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
    if IsForeverEditModeFrame(frame, name) then
        self:RelinquishForeverEditModeFrames(name)
        return false
    end
    if IsForeverProfessionsPanel(frame, name) then
        if ShouldYieldForeverProfessionsPanel(frame, name) then
            self:RelinquishForeverProfessionsPanels(name)
        end
        -- Even opted-in Professions panels are never opened automatically.
        -- Their saved anchor is restored only after a native manual opening.
        return false
    end
    if frame._OffhandPersistentRestoreQueued then return true end

    frame._OffhandPersistentRestoreQueued = true
    C_Timer.After(tonumber(delaySeconds) or 0.75, function()
        frame._OffhandPersistentRestoreQueued = nil
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
            return
        end

        if contextBoundPanelNames[name] then return end

        if ShowUIPanel and UIPanelWindows and UIPanelWindows[name] then
            pcall(ShowUIPanel, frame)
        elseif frame.Show then
            pcall(frame.Show, frame)
        end

        -- OnShow normally restores the position. Retain a final deferred pass
        -- for panels whose native layout writes its anchor after OnShow.
        C_Timer.After(0, function()
            if frame.IsShown and frame:IsShown() then
                RestoreWorkspacePosition(frame)
            end
        end)
    end)
    return true
end

function Canvas:RestorePersistentFrames()
    if not Offhand.db or not Offhand.db.enabled then return end
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
    for name in pairs(Offhand.db.savedWorkspacePositions) do
        savedNames[#savedNames + 1] = name
    end
    table.sort(savedNames)
    local genericRestoreIndex = 0
    for _, name in ipairs(savedNames) do
        local frame = _G[name]
        if frame and not IsForeverEditModeFrame(frame, name)
            and not IsForeverProfessionsPanel(frame, name) then
            if frame:IsShown() then
                RestoreWorkspacePosition(frame)
            elseif openPanels[name] and not contextBoundPanelNames[name] then
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
                    frame:Show()
                    RestoreWorkspacePosition(frame)
                else
                    -- Generic UIPanels (Character, Quest, Guild, etc.)
                    -- Restore one native UIPanel per settlement window. Forever's
                    -- panel manager otherwise opens every saved left-slot panel
                    -- in the same timer turn, causing each to close the previous
                    -- one before Offhand can detach it from the active slot. Only
                    -- an accepted restore consumes a slot: old addon child-frame
                    -- snapshots must not push valid panels several seconds back.
                    local delay = 0.75 + genericRestoreIndex * 0.20
                    if Canvas:QueuePersistentPanelRestore(frame, name, delay) then
                        genericRestoreIndex = genericRestoreIndex + 1
                    end
                end
            end
        elseif not frame and openPanels[name] then
            -- Load-on-demand Blizzard frames (Spellbook, Macros, Collections,
            -- and similar panels) do not exist yet after /reload. Load only the
            -- owner of a panel the user explicitly left open on the workspace.
            local delay = 0.75 + genericRestoreIndex * 0.20
            if Canvas:RequestPersistentPanelLoad(name, delay) then
                genericRestoreIndex = genericRestoreIndex + 1
            end
        end
    end
    
    -- Baganator has its own root-frame snapshot/restore path. The generic
    -- prefix scan can see its still-shown child buttons while the bag is hidden.
    if hasBag and not (Baganator and Offhand.BagPersistence) then
        C_Timer.After(1.5, function()
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
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if Offhand.db and Offhand.db.enabled then
                Canvas:RepairShownWorkspacePanels()
            end
        end)
    end
end

local function AdjustWorldMapScale(map, delta)
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

    -- Forever's maximized map is a distinct Blizzard-owned layout. Applying the
    -- saved windowed scale or anchors while that layout is active shrinks the
    -- full-map chrome into the workspace and can leave its minimize control off
    -- screen. Preserve the native maximized geometry completely; the independent
    -- recovery button created below is the only Offhand control shown in that
    -- state.
    if Offhand.isForever and map.IsMaximized and map:IsMaximized() then return end

    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m or not m.isSpanned then return end

    -- Enable proper parent scaling so the map scales consistently with UIParent
    if not Offhand.isForever and map.SetIgnoreParentScale then
        pcall(function() map:SetIgnoreParentScale(false) end)
    end

    -- Ensure windowed mini world map in Classic Era. Forever owns protected
    -- map state and must not be minimized or have its CVar changed by Offhand.
    if not Offhand.isForever then
        pcall(function()
            if type(GetCVar("miniWorldMap")) == "string" and GetCVar("miniWorldMap") ~= "1" then
                SetCVar("miniWorldMap", "1")
            end
            if map.IsMaximized and map:IsMaximized() and map.Minimize then
                map:Minimize()
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
        if map.HookScript then map:HookScript("OnShow", ScheduleWindowed) end
    end

    -- Hook Blizzard's built-in title button drag handlers
    if not Offhand.isForever and WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
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

local originalAreas = {}

-- A workspace panel can still occupy one of Blizzard's active UIPanel slots
-- even after it has been removed from UISpecialFrames. Escape closes that slot
-- independently. Detach only the already-saved workspace panel; do not alter
-- UIPanelWindows or any secure layout attributes (especially on Forever).
EvictWorkspacePanelSlot = function(frame)
    if not frame or not GetUIPanel or not HideUIPanel or IsPanelEvicting(frame)
        or (InCombatLockdown and InCombatLockdown()) then return false end
    local name = frame.GetName and frame:GetName()
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

OnPanelDragStop = function(frame)
    if not frame then return end
    if InCombatLockdown() then SetPanelDragging(frame, false); return end
    local dragName = frame.GetName and frame:GetName()
    if dragName and dragName:match("^ChatFrame%d+$") and HasChattynator() then
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
        
    elseif not Offhand.isForever then
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

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

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
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Clamp strictly within the workspace boundaries so panels never bleed across the seam
        local inset = string.match(name, "^ChatFrame") and 48 or 12
        local minX = m.workspaceLeft + inset
        local maxX = math.max(minX, m.workspaceRight - frameWidth - 12)
        local clampedX = math.max(minX, math.min(xInParent, maxX))

        local screenHeight = m.workspaceHeight or m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = m.workspaceBottom + frameHeight + 12
        local maxY = math.max(minY, m.workspaceTop - 12)
        local clampedY = math.max(minY, math.min(yInParent, maxY))

        Offhand.db.savedWorkspacePositions[name] = {
            x = clampedX, y = clampedY,
            canvasWidth = m.workspaceWidth, canvasHeight = screenHeight,
            canvasLeft = m.workspaceLeft, canvasBottom = m.workspaceBottom,
        }
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
        
        if not restrictedProfessionsMovement and wasShown
            and (Offhand.db.independentWorkspacePanels or frame == WorldMapFrame) then
            -- Escape closes active UIPanel slots even when UISpecialFrames no
            -- longer contains this workspace panel.
            EvictWorkspacePanelSlot(frame)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
            if frame.IsShown and not frame:IsShown() and frame.Show then frame:Show() end
            DemodalizePanel(frame)
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

        if not restrictedProfessionsMovement and Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
        if restrictedProfessionsMovement then
            Canvas:SetWorkspacePanelOpen(name, false)
        elseif wasShown then
            Canvas:SetWorkspacePanelOpen(name, true)
        end
    else
        Offhand.db.savedWorkspacePositions[name] = nil
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
        if not tostring(name):match("^ChatFrame%d+$")
            and not IsForeverEditModeFrame(_G[name], name)
            and not IsForeverProfessionsPanel(_G[name], name) then
            local frame = _G[name]
            if frame and frame.IsShown and frame:IsShown() and frame.Hide then
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
    if not name or not Offhand.db.savedWorkspacePositions[name]
        or IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return false end

    -- Blizzard Edit Mode's Modern fallback already places chat correctly and
    -- may also restore its preferred size. Do not override it with panel logic.
    if tostring(name):match("^ChatFrame%d+$") then return false end

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

-- Forever's Edit Mode can move and resize non-secure utility frames without
-- dispatching their normal drag callbacks. Mirror explicit Combined Backpack
-- and chat saves without touching protected Edit Mode anchors or handlers.
function Canvas:CaptureForeverFramePosition(frame)
    if not Offhand.isForever or InCombatLockdown() or not frame or not Offhand.db
        or not Offhand.db.enabled or not Offhand.ForeverPersistence then return false end
    local name = frame.GetName and frame:GetName()
    if name ~= "ContainerFrameCombinedBags" and not (name and name:match("^ChatFrame%d+$")) then return false end
    if name and name:match("^ChatFrame%d+$") and HasChattynator() then
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

-- Blizzard UIPanels anchor against the full UIParent. In an Offhand topology
-- that native origin may be the workspace, so an unsaved Spellbook,
-- Professions or Collections panel can open on the wrong monitor. Mainhand
-- placements use physical UIParent coordinates and are clamped on every
-- restore so display changes cannot strand a panel off screen.
function Canvas:PlacePanelOnMainhand(frame, metrics, position, preserveContained, recoveryAction)
    if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
        or not Offhand.db.enabled then return false end
    local name = frame.GetName and frame:GetName()
    local recoverySafePanel = recoveryAction and name and (
        IsBackpackRoot(name) or (UIPanelWindows and UIPanelWindows[name])
    )
    if not name or (nonMovableSystemPanels and nonMovableSystemPanels[name])
        or IsForeverEditModeFrame(frame, name)
        or (IsUnsafeForPanelMutation(frame, name) and not recoverySafePanel) then return false end

    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and WithWorkspace(Offhand.Viewport:GetMetrics()))
    if not metrics or not metrics.isSpanned then return false end

    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
    if parentScale <= 0 or frameScale <= 0 then return false end
    local scaleFactor = frameScale / parentScale
    local width = ((frame.GetWidth and frame:GetWidth()) or 0) * scaleFactor
    local height = ((frame.GetHeight and frame:GetHeight()) or 0) * scaleFactor
    if width <= 0 then width = 192 * scaleFactor end
    if height <= 0 then height = 192 * scaleFactor end

    local inset = 12
    local minX = metrics.gameLeft + inset
    local maxX = math.max(minX, metrics.gameRight - width - inset)
    local minY = metrics.gameBottom + height + inset
    local maxY = math.max(minY, metrics.gameTop - inset)

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
        if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            clampedX * pointFactor, clampedY * pointFactor)
    end)
    if ok and not IsForeverProfessionsPanel(frame, name) then RegisterSpecialFrame(name) end
    return ok
end

-- Recovery is an explicit out-of-combat hardware action. Unlike a generic
-- re-anchor, it must also retire Offhand's workspace ownership or the next
-- OnShow/restore pass will put the panel back on the secondary display.
function Canvas:GatherSafeUIToMainhand()
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
        if frame then candidates[frame] = true end
    end
    for name in pairs(Offhand.db.savedWorkspacePositions or {}) do Add(_G[name]) end
    for name in pairs(UIPanelWindows or {}) do Add(_G[name]) end
    if Offhand.BagPersistence and type(Offhand.BagPersistence.frames) == "table" then
        for _, frame in pairs(Offhand.BagPersistence.frames) do Add(frame) end
    end
    Add(_G.WorldMapFrame)
    Add(_G.CharacterFrame)
    Add(_G.ContainerFrameCombinedBags)
    Add(_G.ContainerFrame1)

    local moved, skipped = 0, 0
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
        if inspected and shown and name and (tracked or onWorkspace)
            and frame ~= UIParent and frame ~= WorldFrame and frame ~= Offhand.canvas
            and not IsForeverEditModeFrame(frame, name) then
            if frame == _G.WorldMapFrame and frame.SetScale then
                pcall(frame.SetScale, frame, 1)
            end
            local called, placed = pcall(self.PlacePanelOnMainhand,
                self, frame, metrics, nil, false, true)
            placed = called and placed
            if placed then
                moved = moved + 1
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
            else
                skipped = skipped + 1
            end
        elseif not inspected then
            skipped = skipped + 1
        end
    end

    SaveOpenWorkspacePanels()
    if Offhand.BagPersistence then
        if Offhand.BagPersistence.ForgetOpenSnapshot then
            Offhand.BagPersistence:ForgetOpenSnapshot()
        end
        if Offhand.BagPersistence.Capture then Offhand.BagPersistence:Capture() end
    end
    if moved > 0 then SaveForeverPanelOwnership() end
    return true, nil, moved, skipped
end

RestoreWorkspacePosition = function(selfOrFrame, maybeFrame)
    local frame = (selfOrFrame == Canvas and maybeFrame) or maybeFrame or selfOrFrame
    if InCombatLockdown() or not frame or type(frame) ~= "table" or not frame.GetName then return end
    if not Offhand.db or not Offhand.db.enabled then return end
    local name = frame:GetName()
    if not name then return end
    if name:match("^ChatFrame%d+$") and HasChattynator() then
        ClearTrackedChatState(name)
        return
    end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end
    local restrictedProfessionsMovement = IsForeverProfessionsPanel(frame, name)
        and IsExperimentalForeverProfessionsMovementEnabled()
    if IsRetailChatEditModeActive(frame) then return end

    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m then return end
    if not m.isSpanned then
        Canvas:PlaceForSingleScreenRecovery(frame, m)
        return
    end

    local wPos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    if type(wPos) == "table" and wPos.x and wPos.y then
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
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Sanitize/clamp in case DB had bad coordinates (like y = -4.2 or x = 493.6)
        local inset = string.match(name, "^ChatFrame") and 48 or 12
        local minX = m.workspaceLeft + inset
        local maxX = math.max(minX, m.workspaceRight - frameWidth - 12)
        local targetX = wPos.x
        local savedCanvasWidth = tonumber(wPos.canvasWidth)
        local savedCanvasLeft = tonumber(wPos.canvasLeft) or 0
        if savedCanvasWidth and savedCanvasWidth > 0 and m.workspaceWidth > 0 then
            targetX = m.workspaceLeft + (targetX - savedCanvasLeft) * m.workspaceWidth / savedCanvasWidth
        end
        local clampedX = math.max(minX, math.min(targetX, maxX))

        local screenHeight = m.workspaceHeight or m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = m.workspaceBottom + frameHeight + 12
        local maxY = math.max(minY, m.workspaceTop - 12)
        local savedCanvasHeight = tonumber(wPos.canvasHeight)
        local savedCanvasBottom = tonumber(wPos.canvasBottom) or 0
        local targetY = wPos.y
        if savedCanvasHeight and savedCanvasHeight > 0 and screenHeight > 0 then
            targetY = m.workspaceBottom + (targetY - savedCanvasBottom) * screenHeight / savedCanvasHeight
        end
        local clampedY = math.max(minY, math.min(targetY, maxY))

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
        if not restrictedProfessionsMovement and Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
        return
    end

    local mPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]
    if type(mPos) == "table" and mPos.x and mPos.y then
        if frame == WorldMapFrame then Canvas:ConfigureWorldMap() end
        RemodalizePanel(frame)
        Canvas:PlacePanelOnMainhand(frame, m, mPos, false)
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

function Canvas:RepairShownWorkspacePanels(exceptFrame)
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
    -- Addon-owned bag roots can be moved by their own Edit Mode without
    -- dispatching Offhand's drag callbacks. Reconcile their physical monitor
    -- before consuming general workspace records so map toggles cannot apply a
    -- stale Offhand anchor over a newly chosen Mainhand position.
    if Offhand.BagPersistence and Offhand.BagPersistence.Capture then
        Offhand.BagPersistence:Capture()
    end
    local repaired = {}
    local function Repair(name, isMainhand)
        if repaired[name] then return end
        repaired[name] = true
        local frame = _G[name]
        if frame and frame ~= exceptFrame and frame.IsShown and frame:IsShown()
            and not IsForeverEditModeFrame(frame, name)
            and not IsForeverProfessionsPanel(frame, name)
            and not (isMainhand and IsBackpackRoot(name))
            and not IsUnsafeForPanelMutation(frame, name) then
            RestoreWorkspacePosition(frame)
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

-- A normal Blizzard panel can be reachable by its left edge while its close
-- button and most of its title bar sit in the mixed-height monitor void. Keep
-- the complete window inside whichever visible monitor currently contains the
-- greatest portion of it. Saved user placements are restored separately and
-- therefore always take precedence over this default-position rescue.
function Canvas:RescuePanelFromVoid(frame, metrics)
    if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
        or not Offhand.db.enabled then return false end
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

    local function IsContained(area)
        return left >= area.left + inset and right <= area.right - inset
            and bottom >= area.bottom + inset and top <= area.top - inset
    end
    if IsContained(areas[1]) or IsContained(areas[2]) then return false end

    local function Overlap(area)
        local overlapWidth = math.max(0, math.min(right, area.right) - math.max(left, area.left))
        local overlapHeight = math.max(0, math.min(top, area.top) - math.max(bottom, area.bottom))
        return overlapWidth * overlapHeight
    end
    local target = Overlap(areas[1]) >= Overlap(areas[2]) and areas[1] or areas[2]
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

local function RestoreSavedPositionAfterShow(frame)
    if not frame or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
    local frameName = frame.GetName and frame:GetName()
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
            frame._OffhandRecoveryGeneration = (frame._OffhandRecoveryGeneration or 0) + 1
            local generation = frame._OffhandRecoveryGeneration
            C_Timer.After(0, function()
                if frame._OffhandRecoveryGeneration ~= generation then return end
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
            frame._OffhandRescueGeneration = (frame._OffhandRescueGeneration or 0) + 1
            local generation = frame._OffhandRescueGeneration
            C_Timer.After(0, function()
                if frame._OffhandRescueGeneration ~= generation then return end
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
        frame._OffhandRestoreGeneration = (frame._OffhandRestoreGeneration or 0) + 1
        local generation = frame._OffhandRestoreGeneration
        C_Timer.After(0, function()
            if frame._OffhandRestoreGeneration ~= generation then return end
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
        Offhand.db.nativeBackpackWorkspaceOpen = true
        Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
        Offhand.db.openWorkspacePanels[name] = true
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
    if handle.ClearAllPoints then handle:ClearAllPoints() end
    if handle.SetPoint then
        handle:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            (left + 44) * factor, (top - 2) * factor)
    end
    if handle.SetSize then handle:SetSize(width, 24 * factor) end
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
        if Canvas._foreverNativeBagCloseObserved then
            Canvas._foreverNativeBagExplicitCloseObserved = true
        end
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
    if ToggleBag and not Canvas._foreverNativeToggleBagObserved then
        Canvas._foreverNativeToggleBagObserved = true
        hooksecurefunc("ToggleBag", ObserveExplicitToggle)
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

local function IsForeverNativeBagPreservingPanelShown()
    for _, name in ipairs(foreverNativeBagPreservingPanelNames) do
        local panel = _G[name]
        if panel and panel.IsShown and panel:IsShown() then return true end
    end
    if IsOptionFrameOpen then
        local ok, shown = pcall(IsOptionFrameOpen)
        if ok and shown then return true end
    end
    return false
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
    local panelTransitionGrace = 0
    foreverNativeBagController:SetScript("OnUpdate", function(_, elapsed)
        -- Settings APIs may arrive with a load-on-demand Blizzard module.
        InstallForeverOptionsOpeningObservers()
        local enabled = Offhand.db and Offhand.db.enabled
            and IsSpannedLayoutActive()
            and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon())
        local inCombat = InCombatLockdown and InCombatLockdown()
        local gameMenuShown = GameMenuFrame and GameMenuFrame.IsShown
            and GameMenuFrame:IsShown() or false
        local gameMenuChanged = gameMenuShown ~= lastGameMenuShown
        local closeObserved = Canvas._foreverNativeBagCloseObserved == true
        local explicitCloseObserved =
            Canvas._foreverNativeBagExplicitCloseObserved == true
        local gameMenuToggleObserved =
            Canvas._foreverNativeGameMenuToggleObserved == true
        local optionsOpeningObserved =
            Canvas._foreverOptionsOpeningObserved == true
        local inputReserved = Offhand.IsBlizzardInputReserved
            and Offhand:IsBlizzardInputReserved() or false
        local preservingPanelShown = IsForeverNativeBagPreservingPanelShown()
        local preservingPanelChanged = preservingPanelShown ~= lastPreservingPanelShown
        local leavingGameMenu = lastGameMenuShown and not gameMenuShown
        if preservingPanelShown or preservingPanelChanged or optionsOpeningObserved
            or leavingGameMenu then
            panelTransitionGrace = 3
        else
            panelTransitionGrace = math.max(0,
                panelTransitionGrace - (tonumber(elapsed) or 0.016))
        end
        local panelTransitionActive = preservingPanelShown
            or panelTransitionGrace > 0
        for _, frameName in ipairs(backpackRootNames) do
            local frame = _G[frameName]
            if frame then
                local handle, state = EnsureForeverNativeBagHandle(frame)
                local shown = enabled and frame.IsShown and frame:IsShown()
                local trackedWorkspaceBag = enabled
                    and GetNativeBackpackWorkspacePosition()
                    and IsNativeBackpackTrackedOpen()
                -- B and the native close button remain authoritative even
                -- while a preserving system panel is visible. Forever's
                -- Game Menu buttons can also call ToggleAllBags while routing
                -- into a panel without invoking a discoverable Settings API;
                -- that same-frame Game Menu exit is navigation, not B.
                if not shown and state.wasShown and explicitCloseObserved
                    and not optionsOpeningObserved and not leavingGameMenu then
                    state.pendingOpenRestore = nil
                    state.pendingOpenAttempts = nil
                    state.pendingGameMenuToggle = nil
                    ClearNativeBackpackOpenState()
                    trackedWorkspaceBag = false
                    panelTransitionGrace = 0
                end

                -- Forever's ToggleGameMenu closes native bags and returns
                -- before showing GameMenuFrame. Its secure post-hook lets this
                -- external observer distinguish Escape from an explicit B/X
                -- close. On the following frame, complete the already-requested
                -- menu visibility change without re-entering ToggleGameMenu's
                -- protected SpellStopCasting path, then reopen the bag through
                -- Blizzard's own API.
                if not shown and trackedWorkspaceBag
                    and ((state.wasShown and closeObserved
                            and not explicitCloseObserved)
                        or (state.wasShown and gameMenuChanged)
                        or panelTransitionActive) then
                    state.pendingOpenRestore = true
                    state.pendingOpenAttempts = 0
                    if gameMenuToggleObserved and not gameMenuChanged then
                        state.pendingGameMenuToggle = true
                    end
                end
                if not shown and state.pendingOpenRestore and not inCombat
                    and not inputReserved then
                    state.pendingOpenAttempts = (state.pendingOpenAttempts or 0) + 1
                    if state.pendingGameMenuToggle then
                        state.pendingGameMenuToggle = nil
                        if gameMenuShown then
                            if GameMenuFrame and GameMenuFrame.Hide then
                                GameMenuFrame:Hide()
                            end
                        elseif GameMenuFrame and GameMenuFrame.Show then
                            GameMenuFrame:Show()
                        end
                        gameMenuShown = GameMenuFrame and GameMenuFrame.IsShown
                            and GameMenuFrame:IsShown() or false
                    end
                    OpenForeverNativeBackpackThroughBlizzard()
                    shown = enabled and frame.IsShown and frame:IsShown()
                    if not shown and panelTransitionActive
                        and state.nativeInitialized and state.wasShown
                        and frame.Show then
                        -- Forever's modal Options/AddOns/Edit Mode ownership can
                        -- reject every public bag opener. This root was already
                        -- fully initialized and visible before the transition,
                        -- so re-show only that existing instance. Never use this
                        -- fallback for login/reload construction or an unseen
                        -- ContainerFrame shell.
                        pcall(frame.Show, frame)
                        shown = enabled and frame.IsShown and frame:IsShown()
                    end
                    local restoredRoot = GetShownNativeBackpackRoot()
                    if restoredRoot then
                        state.pendingOpenRestore = nil
                        state.pendingOpenAttempts = nil
                        if restoredRoot ~= frame then
                            state.wasShown = false
                        end
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
                    state.wasShown = true
                    if GetNativeBackpackWorkspacePosition() then
                        Offhand.db.nativeBackpackWorkspaceOpen = true
                        Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
                        Offhand.db.openWorkspacePanels[frame:GetName()] = true
                    end
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

-- Forever's map-pin sharing path is protected. A drag handler parented to the
-- World Map, or attached to its native title/close controls, taints the same
-- widget tree used by Blizzard's Shift-click link insertion. Provide the map's
-- drag affordance from an independent UIParent child and follow the map by
-- reading geometry only. The handle never becomes a child or anchor dependent
-- of WorldMapFrame and no script is installed on any native map object.
local function AttachForeverWorldMapDragHandle(map)
    if not IsForeverWorldMap(map) or not CreateFrame or not UIParent then return false end
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
        elapsedSinceUpdate = elapsedSinceUpdate + (tonumber(elapsed) or 0)
        if elapsedSinceUpdate < 0.10 then return end
        elapsedSinceUpdate = 0

        local mapShown = Offhand.db and Offhand.db.enabled
            and map.IsShown and map:IsShown()
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
            if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
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

-- Communities changes its own root anchor when switching between Chat, Roster,
-- Info and recruitment/settings views. Preserve an explicit Offhand placement
-- after that native layout pass instead of letting the panel jump to UIParent's
-- spanned top-left corner. Visibility and tab selection remain Blizzard-owned.
local function HookKnownPanelAnchorResets(frame, name)
    local panelName = name or (frame and frame.GetName and frame:GetName())
    local isCommunities = (panelName == "CommunitiesFrame")
    local isProfessions = IsForeverProfessionsPanel(frame, panelName) and IsExperimentalForeverProfessionsMovementEnabled()
    if (not isCommunities and not isProfessions) or frame._OffhandAnchorResetHooked
        or not hooksecurefunc or not C_Timer or not C_Timer.After then return end
    frame._OffhandAnchorResetHooked = true
    hooksecurefunc(frame, "SetPoint", function()
        if frame._OffhandAnchorRepairing or frame._OffhandDragging
            or not Offhand.db or not Offhand.db.enabled then return end
        local workspace = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[panelName]
        local mainhand = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions[panelName]
        if not workspace and not mainhand then return end
        if isProfessions then
            if not frame._OffhandExperimentalProfessionsAttached
                or not IsExperimentalForeverProfessionsMovementEnabled() then return end
            frame._OffhandAnchorRepairing = true
            frame._OffhandExperimentalProfessionsRestoreAllowed = true
            RestoreSavedPositionAfterShow(frame)
            frame._OffhandExperimentalProfessionsRestoreAllowed = nil
            frame._OffhandAnchorRepairing = nil
            return
        end
        if frame._OffhandAnchorRepairPending then return end
        frame._OffhandAnchorRepairPending = true
        C_Timer.After(0, function()
            frame._OffhandAnchorRepairPending = nil
            if frame._OffhandDragging or not Offhand.db or not Offhand.db.enabled
                or (frame.IsShown and not frame:IsShown()) then return end
            frame._OffhandAnchorRepairing = true
            RestoreWorkspacePosition(frame)
            frame._OffhandAnchorRepairing = nil
        end)
    end)
end

-- Forever's ordinary registered UIPanels use the same original Offhand motion
-- adapter that was validated with Professions. The Blizzard title template owns
-- StartMoving/StopMovingOrSizing; Offhand only observes the completed gesture
-- and persists the resulting monitor placement. No panel-body mouse ownership,
-- script replacement, or protected Edit Mode frame is involved.
local function AttachGuardedForeverPanelMotion(frame, name)
    if not Offhand.isForever or not frame or not name
        or not UIPanelWindows or not UIPanelWindows[name] then return false end
    if IsForeverEditModeFrame(frame, name) or IsForeverProfessionsPanel(frame, name)
        or IsForeverWorldMap(frame) or IsUnsafeForPanelMutation(frame, name) then
        return false
    end

    local motion = Offhand.PanelMotion
    if not motion or not motion.AttachGuardedTitleGrip then
        frame._OffhandPanelMotionStatus = "module_unavailable"
        return true
    end

    local title = frame.TitleContainer or _G[name .. "TitleContainer"] or frame
    local grip, status = motion:AttachGuardedTitleGrip(frame, {
        anchorFrame = title,
        leftInset = 10,
        rightInset = 36,
        height = 32,
        onBegin = function()
            if not Offhand.db or not Offhand.db.enabled then return end
            SetPanelDragging(frame, true)
        end,
        onFinish = function()
            if IsPanelDragging(frame) and Offhand.db and Offhand.db.enabled then
                OnPanelDragStop(frame)
            else
                SetPanelDragging(frame, false)
            end
        end,
    })
    frame._OffhandPanelMotionStatus = status
    if not grip then
        if status == "combat_deferred" and Offhand.RunOrQueueCombat then
            Offhand:RunOrQueueCombat(function()
                if Offhand.db and Offhand.db.enabled then
                    AttachGuardedForeverPanelMotion(frame, name)
                end
            end)
        end
        return true
    end

    frame._OffhandPanelMotionGrip = grip
    frame._OffhandHandle = grip
    HookPanelCloseButton(frame, name)
    HookKnownPanelAnchorResets(frame, name)

    if frame.HookScript and not frame._OffhandGuardedPanelShowHooked then
        frame._OffhandGuardedPanelShowHooked = true
        frame:HookScript("OnShow", function(self)
            if not Offhand.db or not Offhand.db.enabled then return end
            RestoreSavedPositionAfterShow(self)
            if Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name] then
                Canvas:SetWorkspacePanelOpen(self, true)
            end
        end)
    end

    frame._OffhandMovable = true
    return true
end

local function MakePanelDraggable(frame)
    if not frame then return end
    if IsForeverWorldMap(frame) then
        AttachForeverWorldMapDragHandle(frame)
        return
    end
    if frame._OffhandMovable then return end
    local name = frame.GetName and frame:GetName()
    if IsForeverNativeContainerName(name) then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end

    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end

    if name and string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end

    -- Registered Forever UIPanels fail closed through the guarded title adapter.
    -- Do not fall back to the legacy whole-panel mouse/drag hooks if the secure
    -- grip cannot be established.
    if AttachGuardedForeverPanelMotion(frame, name) then return end

    local movableOK = pcall(function()
        frame:SetMovable(true)
        frame:SetClampedToScreen(false)
    end)
    if not movableOK or (frame.IsMovable and not frame:IsMovable()) then return end

    local function HookPanelDragSurface(surface)
        if not surface or surface._OffhandPanelDragTarget == frame
            or (surface.IsForbidden and surface:IsForbidden()) then return false end

        local hooked = pcall(function()
            surface:EnableMouse(true)
            surface:RegisterForDrag("LeftButton")
            surface:HookScript("OnDragStart", function()
                if InCombatLockdown() or not Offhand.db.enabled then return end
                local started = pcall(function() frame:StartMoving() end)
                frame._OffhandDragging = started and true or false
            end)
            surface:HookScript("OnDragStop", function()
                OnPanelDragStop(frame)
            end)
        end)
        if not hooked then return false end
        surface._OffhandPanelDragTarget = frame
        return true
    end

    -- Modern Blizzard panel templates place TitleContainer at frame level 510.
    -- Use that native title region directly: a child overlay at the parent's
    -- ordinary frame level sits underneath it and never receives drag input.
    -- Fall back to an elevated overlay only for older panels without a title
    -- container.
    -- MinimapCluster uses MinimapZoneTextButton as its natural drag handle and must not have an overlaid handle
    -- Unit frames (PartyMemberFrame, CompactPartyFrame) and FocusedRosterFrame must NOT have an overlaid handle
    -- to prevent blocking unit targeting, healing, right-click context menus, and roster row selection
    local isUnitFrame = name and (string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "PlayerFrame" or name == "TargetFrame")
    if frame ~= MinimapCluster and not isUnitFrame  then
        local titleContainer = frame.TitleContainer or (name and _G[name .. "TitleContainer"])
        if titleContainer and HookPanelDragSurface(titleContainer) then
            frame._OffhandHandle = titleContainer
        elseif not frame._OffhandHandle and CreateFrame then
            local handle
            handle = CreateFrame("Frame", nil, frame)
            handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
            handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, 0)
            handle:SetHeight(32)
            local lvl = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
            if handle.SetFrameLevel then handle:SetFrameLevel(math.max(lvl + 25, 520)) end
            HookPanelDragSurface(handle)
            frame._OffhandHandle = handle
        end
    end

    local frameIsProtected = frame.IsProtected and frame:IsProtected()
    if not frameIsProtected then
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
    end

    -- Modern/Forever combined bags are dragged by their native TitleContainer,
    -- which may not exist yet when the parent frame is first discovered.
    HookContainerTitlePersistence(frame, name)
    HookCombinedBagCloseButton(frame, name)
    HookPanelCloseButton(frame, name)
    HookKnownPanelAnchorResets(frame, name)

    pcall(function()
        frame:HookScript("OnShow", function(self)
            HookContainerTitlePersistence(frame, name)
            HookCombinedBagCloseButton(frame, name)
            HookPanelCloseButton(frame, name)
            RestoreSavedPositionAfterShow(frame)
            if Offhand.db and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name] then
                Canvas:SetWorkspacePanelOpen(frame, true)
            end
        end)
    end)

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

    if frame == WorldMapFrame and not Offhand.isForever then
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
Canvas.IsForeverProfessionsPanel = IsForeverProfessionsPanel
Canvas.ShouldYieldForeverProfessionsPanel = ShouldYieldForeverProfessionsPanel

-- Experimental Forever Professions support is intentionally isolated from the
-- universal panel lifecycle. It never opens the panel, changes its Escape/UI
-- panel registration, or participates in login/reload restoration. Blizzard
-- must first finish a native manual opening; only then is an Offhand drag
-- surface attached. Existing saved anchors are restored, while the first
-- opted-in opening is centered on Mainhand so its title cannot remain trapped
-- in a non-physical part of a mixed-height UIParent.
function Canvas:QueueExperimentalForeverProfessionsMovement(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not frame or not name or not IsForeverProfessionsPanel(frame, name)
        or not IsExperimentalForeverProfessionsMovementEnabled()
        or not C_Timer or not C_Timer.After then return false end
    if frame._OffhandExperimentalProfessionsQueued then return true end

    -- Once the handle is attached and cold-start initialization has settled,
    -- subsequent openings can restore their saved placement immediately instead
    -- of waiting 1.0 second at Blizzard's native spanned top-left anchor.
    if frame._OffhandExperimentalProfessionsAttached then
        HookKnownPanelAnchorResets(frame, name)
        Canvas:SetWorkspacePanelOpen(name, false)
        local hasSavedPosition = Offhand.db and
            ((Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
                or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
        if hasSavedPosition then
            frame._OffhandExperimentalProfessionsRestoreAllowed = true
            RestoreSavedPositionAfterShow(frame)
            frame._OffhandExperimentalProfessionsRestoreAllowed = nil
        else
            Canvas:PlacePanelOnMainhand(frame, nil, nil, false)
        end
        local grip = frame._OffhandExperimentalProfessionsGrip
        if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
            local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
            frame._OffhandExperimentalProfessionsMotionStatus = status
        end
        return true
    end

    frame._OffhandExperimentalProfessionsQueued = true
    frame._OffhandExperimentalProfessionsGeneration =
        (frame._OffhandExperimentalProfessionsGeneration or 0) + 1
    local generation = frame._OffhandExperimentalProfessionsGeneration
    C_Timer.After(1.0, function()
        frame._OffhandExperimentalProfessionsQueued = nil
        if frame._OffhandExperimentalProfessionsGeneration ~= generation
            or not IsExperimentalForeverProfessionsMovementEnabled()
            or (frame.IsShown and not frame:IsShown()) then return end
        if InCombatLockdown() then
            if Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(function()
                    Canvas:QueueExperimentalForeverProfessionsMovement(frame, name)
                end)
            end
            return
        end

        if not frame._OffhandExperimentalProfessionsAttached then
            if not Offhand.PanelMotion or not Offhand.PanelMotion.AttachGuardedTitleGrip then
                frame._OffhandExperimentalProfessionsMotionStatus = "module_unavailable"
                return
            end

            local grip, status = Offhand.PanelMotion:AttachGuardedTitleGrip(frame, {
                anchorFrame = frame.TitleContainer,
                leftInset = 10,
                rightInset = 36,
                height = 32,
                onBegin = function()
                    if not Offhand.db or not Offhand.db.enabled
                        or not IsExperimentalForeverProfessionsMovementEnabled() then return end
                    frame._OffhandDragging = true
                end,
                onFinish = function()
                    if frame._OffhandDragging and IsExperimentalForeverProfessionsMovementEnabled() then
                        OnPanelDragStop(frame)
                    else
                        frame._OffhandDragging = false
                    end
                end,
            })
            frame._OffhandExperimentalProfessionsMotionStatus = status
            if not grip then return end

            frame._OffhandExperimentalProfessionsGrip = grip
            frame._OffhandExperimentalProfessionsAttached = true
            HookKnownPanelAnchorResets(frame, name)
            if frame.HookScript then
                frame:HookScript("OnShow", function(self)
                    Canvas:QueueExperimentalForeverProfessionsMovement(self, name)
                end)
            end
        end

        local grip = frame._OffhandExperimentalProfessionsGrip
        if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
            local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
            frame._OffhandExperimentalProfessionsMotionStatus = status
        end
        Canvas:SetWorkspacePanelOpen(name, false)
        local hasSavedPosition = Offhand.db and
            ((Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name])
                or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
        if hasSavedPosition then
            frame._OffhandExperimentalProfessionsRestoreAllowed = true
            RestoreSavedPositionAfterShow(frame)
            frame._OffhandExperimentalProfessionsRestoreAllowed = nil
        else
            -- Blizzard anchors this panel against the complete spanned
            -- UIParent. With a portrait workspace beside a landscape Mainhand,
            -- that default upper-left anchor can put the title bar in the void
            -- above Mainhand and make our opt-in drag surface unreachable.
            -- This runs only after the one-second native-open settlement and
            -- only under explicit experimental consent; it does not open,
            -- demodalize, persist or otherwise join the generic panel lifecycle.
            Canvas:PlacePanelOnMainhand(frame, nil, nil, false)
        end
    end)
    return true
end

function Canvas:GetExperimentalProfessionsMotionDiagnostics()
    if not Offhand.isForever then return nil end
    local enabled = IsExperimentalForeverProfessionsMovementEnabled() and "1" or "0"
    local entries = {}
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            local frame = _G[name]
            if frame and IsForeverProfessionsPanel(frame, name) then
                local protected = frame.IsProtected and frame:IsProtected() and "1" or "0"
                local status = frame._OffhandExperimentalProfessionsMotionStatus
                    or (Offhand.PanelMotion and Offhand.PanelMotion.GetStatus
                        and Offhand.PanelMotion:GetStatus(frame)) or "not_attached"
                entries[#entries + 1] = string.format("%s:%s/protected=%s", name, status, protected)
            end
        end
    end
    table.sort(entries)
    local allMotion = Offhand.PanelMotion and Offhand.PanelMotion.GetDiagnostics
        and Offhand.PanelMotion:GetDiagnostics() or "Attached=0 | Frames=none"
    return string.format("Enabled=%s | Professions=%s | %s", enabled,
        #entries > 0 and table.concat(entries, ",") or "not loaded", allMotion)
end

function Canvas:EnableExperimentalForeverProfessionsMovement()
    if not IsExperimentalForeverProfessionsMovementEnabled() then return false end
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            local frame = _G[name]
            if frame and IsForeverProfessionsPanel(frame, name) then
                if frame._OffhandExperimentalProfessionsAttached then
                    local grip = frame._OffhandExperimentalProfessionsGrip
                    if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                        local _, status = Offhand.PanelMotion:SetTitleGripActive(frame, true)
                        frame._OffhandExperimentalProfessionsMotionStatus = status
                    end
                    HookKnownPanelAnchorResets(frame, name)
                end
            end
        end
    end
    if C_Timer and C_Timer.NewTicker and not self.experimentalProfessionsWatcher then
        self.experimentalProfessionsWatcher = C_Timer.NewTicker(0.5, function()
            if not IsExperimentalForeverProfessionsMovementEnabled() then
                if Canvas.experimentalProfessionsWatcher.Cancel then
                    Canvas.experimentalProfessionsWatcher:Cancel()
                end
                Canvas.experimentalProfessionsWatcher = nil
                return
            end
            if not UIPanelWindows then return end
            for name in pairs(UIPanelWindows) do
                local frame = _G[name]
                if frame and IsForeverProfessionsPanel(frame, name)
                    and frame.IsShown and frame:IsShown()
                    and not frame._OffhandExperimentalProfessionsAttached then
                    Canvas:QueueExperimentalForeverProfessionsMovement(frame, name)
                end
            end
        end)
    end
    return true
end

function Canvas:DisableExperimentalForeverProfessionsMovement()
    if not Offhand.isForever then return false end
    if self.experimentalProfessionsWatcher then
        if self.experimentalProfessionsWatcher.Cancel then
            self.experimentalProfessionsWatcher:Cancel()
        end
        self.experimentalProfessionsWatcher = nil
    end
    if UIPanelWindows then
        for name in pairs(UIPanelWindows) do
            if IsForeverProfessionsPanel(nil, name) then
                local frame = _G[name]
                if frame then
                    frame._OffhandExperimentalProfessionsGeneration =
                        (frame._OffhandExperimentalProfessionsGeneration or 0) + 1
                    frame._OffhandExperimentalProfessionsQueued = nil
                    frame._OffhandExperimentalProfessionsRestoreAllowed = nil
                    local grip = frame._OffhandExperimentalProfessionsGrip
                    if grip and Offhand.PanelMotion and Offhand.PanelMotion.SetTitleGripActive then
                        local deactivated, status = Offhand.PanelMotion:SetTitleGripActive(frame, false)
                        frame._OffhandExperimentalProfessionsMotionStatus = status
                        if not deactivated and status == "combat_deferred" and Offhand.RunOrQueueCombat then
                            Offhand:RunOrQueueCombat(function()
                                if Offhand.PanelMotion then
                                    local _, deferredStatus = Offhand.PanelMotion:SetTitleGripActive(frame, false)
                                    frame._OffhandExperimentalProfessionsMotionStatus = deferredStatus
                                end
                            end)
                        end
                    end
                end
            end
        end
    end
    self:RelinquishForeverProfessionsPanels()
    return true
end

-- Remove historical Offhand ownership records so an upgraded installation
-- cannot keep retrying a Professions restore that the new policy forbids.
-- This does not hide, show, anchor, register, or otherwise touch Blizzard's
-- live frame.
function Canvas:RelinquishForeverProfessionsPanels(onlyName)
    if not Offhand.isForever or not Offhand.db then return false end
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
                    and IsForeverProfessionsPanel(nil, name) then
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

local foreverSystemPanelNames = {
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "AudioOptionsFrame",
}

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

-- Opening Blizzard Settings closes native bags as part of its panel cleanup.
-- A workspace backpack marked open is independent workspace content, so reopen
-- only that tracked bag after Settings finishes its transition.
function Canvas:RestoreTrackedWorkspaceBag()
    if not Offhand.isForever or (InCombatLockdown and InCombatLockdown())
        or not Offhand.db or not Offhand.db.enabled
        or Offhand.db.persistentWorkspacePanels == false
        or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved())
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
    self:InitializePanelLoadTracking()
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

    if hooksecurefunc and not Canvas._explicitPanelToggleHooks then
        Canvas._explicitPanelToggleHooks = true
        local function SyncExplicitToggle(frame)
            if not frame or not C_Timer or not C_Timer.After then return end
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
                    Canvas:RepairShownWorkspacePanels(frame)
                end
            end
            -- The secure post-hook still runs inside the native key/button
            -- action, before the next rendered frame. Restore a known anchor
            -- immediately to avoid showing Blizzard's default map position for
            -- one frame, then repeat after deferred native layout settles.
            SyncPass(true)
            C_Timer.After(0, function() SyncPass(true) end)
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
        if ToggleWorldMap then
            hooksecurefunc("ToggleWorldMap", function() SyncExplicitToggle(_G.WorldMapFrame) end)
        end
        if ToggleCharacter then
            hooksecurefunc("ToggleCharacter", function() SyncExplicitToggle(_G.CharacterFrame) end)
        end
    end

    if hooksecurefunc and ToggleQuestLog and Canvas._syncExplicitPanelToggle
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
        if frame and not IsForeverEditModeFrame(frame, name) then
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
        chatFrame._OffhandApplyingTrackedChatPosition = true
        local ok = pcall(RestoreWorkspacePosition, chatFrame)
        chatFrame._OffhandApplyingTrackedChatPosition = nil
        return ok
    end

    local function RestoreTrackedChatPosition(chatFrame)
        if not chatFrame or not Offhand.db or not Offhand.db.enabled
            or InCombatLockdown() or chatFrame._OffhandDragging
            or MOVING_CHATFRAME == chatFrame then return end
        local chatName = chatFrame.GetName and chatFrame:GetName()
        if not chatName then return end
        local workspacePosition = Offhand.db.savedWorkspacePositions
            and Offhand.db.savedWorkspacePositions[chatName]
        local mainPosition = Offhand.db.savedMainPositions
            and Offhand.db.savedMainPositions[chatName]
        if not workspacePosition and not mainPosition then return end

        -- Forever temporarily inserts detached windows into the primary dock
        -- while rebuilding chat during login. That is not a user re-dock and
        -- must never delete the saved monitor snapshot. Wait for Blizzard's
        -- persisted DOCKED=0 state to settle, then restore presentation and
        -- position. A genuine re-dock is handled by the observed drag path.
        if IsBlizzardChatFrameDocked(chatFrame, chatName) then
            if C_Timer and C_Timer.After and not chatFrame._OffhandChatDockSettlementPending then
                chatFrame._OffhandChatDockSettlementPending = true
                chatFrame._OffhandChatDockSettlementGeneration =
                    (chatFrame._OffhandChatDockSettlementGeneration or 0) + 1
                local generation = chatFrame._OffhandChatDockSettlementGeneration
                for _, delay in ipairs({0, 0.20, 1.00}) do
                    local retryDelay = delay
                    C_Timer.After(retryDelay, function()
                        if chatFrame._OffhandChatDockSettlementGeneration ~= generation
                            or chatFrame._OffhandDragging or MOVING_CHATFRAME == chatFrame then return end
                        if not IsBlizzardChatFrameDocked(chatFrame, chatName) then
                            chatFrame._OffhandChatDockSettlementPending = nil
                            RestoreTrackedChatPosition(chatFrame)
                        elseif retryDelay == 1.00 then
                            chatFrame._OffhandChatDockSettlementPending = nil
                        end
                    end)
                end
            end
            return
        end

        RefreshDetachedChatPresentation(chatFrame, chatName)
        ApplyTrackedChatPosition(chatFrame)
        if C_Timer and C_Timer.After then
            chatFrame._OffhandChatRestoreGeneration =
                (chatFrame._OffhandChatRestoreGeneration or 0) + 1
            local generation = chatFrame._OffhandChatRestoreGeneration
            C_Timer.After(0, function()
                if chatFrame._OffhandChatRestoreGeneration ~= generation
                    or chatFrame._OffhandDragging or MOVING_CHATFRAME == chatFrame
                    or (chatFrame.IsShown and not chatFrame:IsShown()) then return end
                ApplyTrackedChatPosition(chatFrame)
            end)
        end
    end

    local function RegisterChatFrame(chatFrame)
        if not chatFrame then return end
        local chatName = chatFrame.GetName and chatFrame:GetName()
        if chatName and HasChattynator() then
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

    if not HasChattynator() and FCF_StopDragging and not Canvas._fcfHooked then
        Canvas._fcfHooked = true
        hooksecurefunc("FCF_StopDragging", function(chatFrame)
            if chatFrame and Offhand.db and Offhand.db.enabled
                and not HasChattynator() then
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

    if not HasChattynator() and FCF_DockFrame and not Canvas._fcfDockHooked then
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

    -- Forever's manager participates in protected/secret-value Edit Mode paths.
    -- Even a read-only OnHide hook makes Offhand part of that execution chain
    -- and can prevent native Party Frame dragging. Retail alone needs this hook
    -- to hand ChatFrame1 placement back after Edit Mode closes.
    if not Offhand.isForever and EditModeManagerFrame and EditModeManagerFrame.HookScript
        and not EditModeManagerFrame._OffhandRetailChatExitHooked then
        EditModeManagerFrame._OffhandRetailChatExitHooked = true
        EditModeManagerFrame:HookScript("OnHide", function()
            local capture = function() Canvas:CaptureRetailEditModeChatPlacement() end
            if C_Timer and C_Timer.After then C_Timer.After(0, capture) else capture() end
        end)
    end

    if not HasChattynator() and FCF_SavePositionAndDimensions and not Canvas._fcfSaveHooked then
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
    if not HasChattynator() and FCF_SetWindowColor and not Canvas._fcfColorHooked then
        Canvas._fcfColorHooked = true
        hooksecurefunc("FCF_SetWindowColor", function(chatFrame)
            QueueDetachedChatPresentationRefresh(chatFrame)
        end)
    end
    if not HasChattynator() and FCF_SetWindowAlpha and not Canvas._fcfAlphaHooked then
        Canvas._fcfAlphaHooked = true
        hooksecurefunc("FCF_SetWindowAlpha", function(chatFrame)
            QueueDetachedChatPresentationRefresh(chatFrame)
        end)
    end

    if not HasChattynator() and FCF_OpenNewWindow and not Canvas._fcfNewHooked then
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
    self:RecoverLostForeverCombatLog()

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




