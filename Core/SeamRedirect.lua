-- Anchor managed HUD frames inside the same rectangle used by WorldFrame.
local _, Offhand = ...
local HUD = {}
Offhand.SeamRedirect = HUD
Offhand.HUD = HUD
local aligning, pending = false, false
local hooks = {}
local desiredFrames = {}
local function IsAddonPresent(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded(name) then return true end
    elseif IsAddOnLoaded then
        if IsAddOnLoaded(name) then return true end
    end
    if _G and _G[name] ~= nil then return true end
    return false
end

local function HasCustomActionBarAddon()
    -- Action bar addons generally hide or unregister the native MainMenuBar.
    if _G.Bartender4 or _G.Dominos or _G.ElvUI or _G.Tukui or _G.ConsolePort then return true end
    local main = _G.MainMenuBar or _G.MainActionBar
    if not main then return true end
    return false
end

local function HasCustomBagAddon()
    if _G.Baganator or _G.Baginator or _G.Bagnon or _G.AdiBags or _G.ArkInventory or _G.BetterBags or _G.Inventorian or _G.ElvUI or _G.Tukui then return true end

    local c1 = _G.ContainerFrame1
    if not c1 then return true end

    return false
end

local function HasCustomMinimapAddon()
    -- Heuristic check for minimap overrides.
    if _G.SexyMap or _G.Carbonite or _G.ElvUI then return true end

    local mm = _G.MinimapCluster
    if not mm then return true end

    -- If another addon has forcibly moved or unanchored the Minimap natively without Offhand's permission
    if mm.IsUserPlaced and mm:IsUserPlaced() then return true end

    return false
end

local function HasEllesmerePartyFrames()
    -- EllesmereUI ships Party/Raid Frames as this child addon in both its full
    -- suite and standalone package. Its replacement frames are positioned with
    -- EllesmereUI Unlock Mode, not Blizzard Edit Mode.
    return IsAddonPresent("EllesmereUIRaidFrames")
end

Offhand.HasCustomActionBarAddon = HasCustomActionBarAddon
Offhand.HasCustomBagAddon = HasCustomBagAddon
Offhand.HasCustomMinimapAddon = HasCustomMinimapAddon
Offhand.HasEllesmerePartyFrames = HasEllesmerePartyFrames

local actionNames = {"MainMenuBar", "MainActionBar", "StatusTrackingBarManager", "MainMenuExpBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    }
local foreverEditModeFrameNames = {
    MainMenuBar = true, MainActionBar = true, StatusTrackingBarManager = true, MainMenuExpBar = true,
    MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarLeft = true, MultiBarRight = true,
    StanceBar = true, PetActionBar = true, PossessActionBar = true,
    MinimapCluster = true, PlayerFrame = true, TargetFrame = true, FocusFrame = true, PetFrame = true,
    BossTargetFrameContainer = true,
    PartyFrame = true, PartyMemberFrame1 = true, CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    BuffFrame = true, BuffCluster = true, CastingBarFrame = true, PlayerCastingBarFrame = true,
    ExtraAbilityContainer = true, ExtraActionBarFrame = true, ZoneAbilityFrame = true,
    EncounterBar = true, UIWidgetPowerBarContainerFrame = true, LossOfControlFrame = true,
    MainMenuBarVehicleLeaveButton = true, VehicleExitButton = true,
    TotemFrame = true, MultiCastActionBarFrame = true, PersonalResourceDisplayFrame = true,
    DurabilityFrame = true, DamageMeter = true,
    UIErrorsFrame = true, RaidWarningFrame = true,
    EssentialCooldownViewer = true, UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true, BottomManagedFrameContainer = true,
}

-- Every modern Blizzard client owns these frames through Edit Mode. They may
-- be unprotected at the instant a load-on-demand module initializes, but that
-- does not make them safe for the generic popup rescue or UIPanel centering
-- paths. In particular, the native Damage Meter rebuilds secure ScrollBox
-- entries while Edit Mode opens; changing its frame tree during that lifecycle
-- can leave Blizzard's element initializer incomplete.
local function IsBlizzardEditModeOwnedFrame(frame, name)
    name = name or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    return name and (name:match("^EditMode") ~= nil
        or name:match("^DamageMeter") ~= nil) or false
end

local function HasBlizzardEditMode()
    if type(Offhand.HasBlizzardEditMode) == "function" then
        return Offhand:HasBlizzardEditMode()
    end
    return Offhand.isRetail or Offhand.isForever
        or C_EditMode ~= nil or EditModeManagerFrame ~= nil
end

local function UsesNativeGamepadInterface()
    local mainhand = Offhand.Mainhand
    return mainhand and type(mainhand.IsNativeGamepadInterface) == "function"
        and mainhand:IsNativeGamepadInterface() or false
end

local function UsesControllerInterface()
    local mainhand = Offhand.Mainhand
    return mainhand and type(mainhand.IsControllerLayout) == "function"
        and mainhand:IsControllerLayout() or false
end

local function HasChattynator()
    return IsAddonPresent("Chattynator")
end

local function UsesForeverEditMode()
    if Offhand.isForever ~= nil then return Offhand.isForever end
    local version = tonumber(Offhand.tocVersion)
    return version and version >= 16000 and version < 17000 or false
end
local function IsForeverEditModeFrame(frame, name)
    if not HasBlizzardEditMode() then return false end
    name = name or (frame and frame.GetName and frame:GetName())
    if IsBlizzardEditModeOwnedFrame(frame, name) then return true end
    if name == "ChatFrame1" and UsesForeverEditMode() and frame
        and type(frame.OnEditModeEnter) == "function"
        and type(frame.OnEditModeExit) == "function" then
        return true
    end
    return name and (foreverEditModeFrameNames[name]
        or name:match("^EditMode")
        or name:match("CooldownViewer")
        or name:match("ManagedFrameContainer")
        or name:match("^PartyMemberFrame")
        or name:match("^CompactPartyFrame")
        or name:match("^CompactRaidFrame")) or false
end

local function RetailEditModeOwnsPrimaryChat(frame)
    return not UsesForeverEditMode() and frame and frame == _G.ChatFrame1
        and frame.isStaticDocked == true
        and type(frame.OnEditModeEnter) == "function"
        and type(frame.OnEditModeExit) == "function"
end

local function GetEditModeLayouts()
    if not C_EditMode or not C_EditMode.GetLayouts then return nil end
    local ok, data = pcall(C_EditMode.GetLayouts)
    if not ok or type(data) ~= "table" or type(data.layouts) ~= "table" then return nil end
    return data
end

local function SelectEditModeLayout(layoutID)
    if not layoutID or not C_EditMode or not C_EditMode.SetActiveLayout then return false end
    return pcall(C_EditMode.SetActiveLayout, layoutID)
end

-- Forever reserves global identifiers 1 and 2 for Modern and Classic and a
-- third internal slot before custom layouts. GetLayouts().layouts contains only
-- custom entries, while activeLayout/SetActiveLayout use the global identifier.
-- For example, layouts[3] named Offhand is activeLayout 6.
local FOREVER_CUSTOM_LAYOUT_OFFSET = 3
local FOREVER_MODERN_LAYOUT_ID = 1
local FOREVER_MISMATCH_GRACE_SECONDS = 8

local function GetForeverLayoutByID(data, layoutID)
    if type(data) ~= "table" or type(data.layouts) ~= "table" then return nil end
    layoutID = tonumber(layoutID)
    if not layoutID or layoutID <= FOREVER_CUSTOM_LAYOUT_OFFSET then return nil end
    return data.layouts[layoutID - FOREVER_CUSTOM_LAYOUT_OFFSET]
end

local function EditModeLayoutNamesMatch(left, right)
    return type(left) == "string" and type(right) == "string"
        and string.lower(left) == string.lower(right)
end

local function GetActiveEditModeLayoutName()
    local manager = _G.EditModeManagerFrame
    if not manager or type(manager.GetActiveLayoutInfo) ~= "function" then return nil end
    local ok, activeInfo = pcall(manager.GetActiveLayoutInfo, manager)
    local name = ok and type(activeInfo) == "table" and activeInfo.layoutName or nil
    if type(name) ~= "string" or not name:match("%S") then return nil end
    return name
end

local function GetEditModeCustomLayoutOffset(data, activeName)
    local manager = _G.EditModePresetLayoutManager
    if manager and type(manager.GetCopyOfPresetLayouts) == "function" then
        local ok, presets = pcall(manager.GetCopyOfPresetLayouts, manager)
        if ok and type(presets) == "table" and #presets > 0 then return #presets end
    end
    -- If the preset manager has not materialized yet, a currently active custom
    -- layout still reveals the namespace offset without hard-coding its slot.
    local activeID = type(data) == "table" and tonumber(data.activeLayout) or nil
    if activeID and type(activeName) == "string" and type(data.layouts) == "table" then
        for index, layout in ipairs(data.layouts) do
            if EditModeLayoutNamesMatch(layout and layout.layoutName, activeName) then
                local offset = activeID - index
                if offset >= 0 then return offset end
            end
        end
    end
    -- All supported Blizzard Edit Mode branches reserve three preset/global
    -- identifiers before custom layouts. The live preset count above remains
    -- authoritative if a future branch changes that topology.
    return FOREVER_CUSTOM_LAYOUT_OFFSET
end

-- Retail and Anniversary can briefly restore the wrong active layout during
-- login. Remember the player's last explicit selection per character so a
-- later mismatch can be repaired without imposing one account-wide layout
-- name on every class. Forever intentionally keeps its separate, click-driven
-- missing-monitor recovery path and never writes this preference.
local function RememberCharacterEditModeLayout(layoutID)
    if UsesForeverEditMode() or type(OffhandCharDB) ~= "table" then return nil end

    local name
    local data = GetEditModeLayouts()
    local index = tonumber(layoutID)
    local layout = data and index and data.layouts[index]
    if layout and type(layout.layoutName) == "string" and layout.layoutName:match("%S") then
        name = layout.layoutName
    else
        name = GetActiveEditModeLayoutName()
    end

    if name then OffhandCharDB.editModeLayoutName = name end
    return name
end

local function HookCharacterEditModeSelection()
    if UsesForeverEditMode() or HUD.characterEditModeSelectionHooked
        or not _G.EditModeManagerFrame
        or type(_G.EditModeManagerFrame.HookScript) ~= "function" then return end

    HUD.characterEditModeSelectionHooked = true
    _G.EditModeManagerFrame:HookScript("OnShow", function()
        HUD.characterEditModeManagerWasShown = true
    end)
    _G.EditModeManagerFrame:HookScript("OnHide", function()
        if not HUD.characterEditModeManagerWasShown then return end
        HUD.characterEditModeManagerWasShown = nil
        -- Read after Blizzard finishes its close/save transaction. Observing
        -- the manager avoids treating login-time API activity as a deliberate
        -- player choice.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() RememberCharacterEditModeLayout() end)
        else
            RememberCharacterEditModeLayout()
        end
    end)
end

local function FindForeverLayoutByName(data, layoutName)
    if type(data) ~= "table" or type(data.layouts) ~= "table" or type(layoutName) ~= "string" then return nil end
    for index, layout in ipairs(data.layouts) do
        if layout and EditModeLayoutNamesMatch(layout.layoutName, layoutName) then
            return layout, index + FOREVER_CUSTOM_LAYOUT_OFFSET
        end
    end
end

local function ResolveForeverLayoutID(data, savedID, savedName)
    local numericID = tonumber(savedID)
    local layout = GetForeverLayoutByID(data, numericID)
    if layout and (not savedName or EditModeLayoutNamesMatch(layout.layoutName, savedName)) then
        return numericID, layout
    end
    local namedLayout, namedID = FindForeverLayoutByName(data, savedName)
    if namedID then return namedID, namedLayout end
    -- A remembered name is stronger evidence than a stale numeric slot. If the
    -- named layout no longer exists, never select whichever unrelated layout
    -- happens to occupy its former ID.
    if type(savedName) == "string" then return nil end
    return numericID, layout
end

local function PersistForeverEditModeState()
    local persistence = Offhand.ForeverPersistence
    if persistence and persistence.SaveProfileSnapshot then
        persistence:SaveProfileSnapshot(true)
    end
end

local function PrepareForeverEditModeState(data, metrics)
    if not UsesForeverEditMode() or type(OffhandCharDB) ~= "table"
        or type(data) ~= "table" then return nil end

    local changed = false
    local activeID = tonumber(data.activeLayout)
    local legacy = OffhandCharDB.foreverEditModeLegacyRecovery
    if type(legacy) == "table" then
        local restoreID, restoreLayout = ResolveForeverLayoutID(
            data, legacy.restoreLayoutID, legacy.restoreLayoutName)
        local fallbackID = tonumber(legacy.fallbackLayoutID) or FOREVER_MODERN_LAYOUT_ID
        if restoreID and restoreLayout
            and (activeID == restoreID or activeID == fallbackID) then
            OffhandCharDB.foreverEditModeLayoutName = restoreLayout.layoutName
            OffhandCharDB.foreverEditModeLayoutID = restoreID
            OffhandCharDB.foreverEditModeRecovery = {
                restoreLayoutID = restoreID,
                restoreLayoutName = restoreLayout.layoutName,
                fallbackLayoutID = fallbackID,
                fallbackLayoutName = type(legacy.fallbackLayoutName) == "string"
                    and legacy.fallbackLayoutName or "Modern",
            }
        end
        OffhandCharDB.foreverEditModeLegacyRecovery = nil
        changed = true
    end

    local preferredName = OffhandCharDB.foreverEditModeLayoutName
    local preferredID, preferredLayout = ResolveForeverLayoutID(
        data, OffhandCharDB.foreverEditModeLayoutID, preferredName)
    if preferredLayout then
        if preferredName ~= preferredLayout.layoutName or preferredID ~= OffhandCharDB.foreverEditModeLayoutID then
            OffhandCharDB.foreverEditModeLayoutName = preferredLayout.layoutName
            OffhandCharDB.foreverEditModeLayoutID = preferredID
            changed = true
        end
    elseif not preferredName and metrics and metrics.companionTopology and metrics.isSpanned then
        -- Safe upgrade path: a healthy exact span with an active custom layout
        -- is unambiguous. Built-in Modern/Classic layouts are never adopted.
        local activeLayout = GetForeverLayoutByID(data, activeID)
        if activeLayout and type(activeLayout.layoutName) == "string" then
            OffhandCharDB.foreverEditModeLayoutName = activeLayout.layoutName
            OffhandCharDB.foreverEditModeLayoutID = activeID
            preferredID, preferredLayout = activeID, activeLayout
            changed = true
        end
    end

    if changed then PersistForeverEditModeState() end
    return preferredID, preferredLayout
end

function HUD:GetForeverEditModeLayoutStatus()
    local data = GetEditModeLayouts()
    local character = type(OffhandCharDB) == "table" and OffhandCharDB or nil
    local activeID = data and tonumber(data.activeLayout) or nil
    local activeLayout = data and GetForeverLayoutByID(data, activeID) or nil
    local preferredName = character and character.foreverEditModeLayoutName or nil
    local preferredID, preferredLayout
    if data then
        preferredID, preferredLayout = ResolveForeverLayoutID(
            data, character and character.foreverEditModeLayoutID, preferredName)
    end
    return {
        preferredName = preferredName,
        preferredID = preferredID,
        preferredAvailable = preferredLayout ~= nil,
        activeName = activeLayout and activeLayout.layoutName or nil,
        activeID = activeID,
        activeIsCustom = activeLayout ~= nil,
        activeMatches = preferredID ~= nil and activeID == preferredID,
        recoveryPending = character and type(character.foreverEditModeRecovery) == "table" or false,
    }
end

function HUD:UseCurrentForeverEditModeLayout()
    if not UsesForeverEditMode() then return false, "client" end
    if InCombatLockdown() then return false, "combat" end
    if type(OffhandCharDB) ~= "table" then return false, "state" end
    local data = GetEditModeLayouts()
    if not data then return false, "unavailable" end
    local activeID = tonumber(data.activeLayout)
    local layout = GetForeverLayoutByID(data, activeID)
    if not layout or type(layout.layoutName) ~= "string" then return false, "builtin" end

    OffhandCharDB.foreverEditModeLayoutName = layout.layoutName
    OffhandCharDB.foreverEditModeLayoutID = activeID
    local generated = OffhandCharDB.mainhandLayout
    if type(generated) == "table"
        and EditModeLayoutNamesMatch(generated.generatedName, layout.layoutName) then
        generated.generatedID = activeID
        generated.activationPending = nil
    end
    OffhandCharDB.foreverEditModeLegacyRecovery = nil
    OffhandCharDB.foreverEditModeRecovery = nil
    self.foreverRecoveryPromptShown = nil
    if Offhand.HideForeverLayoutRecoveryPrompt then
        Offhand:HideForeverLayoutRecoveryPrompt("fallback")
        Offhand:HideForeverLayoutRecoveryPrompt("restore")
    end
    PersistForeverEditModeState()
    return true, layout.layoutName
end

local function IsForeverSingleScreenRecovery(metrics)
    if Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery then
        return Offhand.Viewport:IsSingleScreenRecovery(metrics)
    end
    return metrics and not metrics.isSpanned
        and metrics.topologyStatus == "MISMATCH" or false
end

local function ScheduleForeverRecoveryRetry(self, delay)
    if not C_Timer or not C_Timer.After or self.foreverRecoveryRetryPending then return end
    self.foreverRecoveryRetryPending = true
    C_Timer.After(delay or 1, function()
        self.foreverRecoveryRetryPending = nil
        local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        self:UpdateForeverRecoveryLayout(current)
    end)
end

local function ScheduleForeverMismatchConfirmation(self)
    if not C_Timer or not C_Timer.After or self.foreverMismatchConfirmationPending then return end
    self.foreverMismatchConfirmationPending = true
    C_Timer.After(FOREVER_MISMATCH_GRACE_SECONDS, function()
        self.foreverMismatchConfirmationPending = nil
        local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        if IsForeverSingleScreenRecovery(current) then
            self.foreverMismatchConfirmed = true
            self:UpdateForeverRecoveryLayout(current)
        else
            self.foreverMismatchConfirmed = nil
            self.foreverMismatchDeclined = nil
            if Offhand.HideForeverLayoutRecoveryPrompt then
                Offhand:HideForeverLayoutRecoveryPrompt("fallback")
            end
        end
    end)
end

-- Forever's protected HUD is owned by Blizzard Edit Mode. A layout saved for a
-- 4000x2560 span remains active if a display disappears, so Blizzard clamps its
-- anchors into a readable but malformed single-screen arrangement. Forever only
-- accepts the protected layout change from a hardware event, so remember enough
-- state and present a player-click prompt for both fallback and restoration. If
-- the player chooses another layout during recovery, that explicit choice wins.
function HUD:UpdateForeverRecoveryLayout(metrics)
    if not UsesForeverEditMode() or not Offhand.db or not Offhand.db.enabled
        or InCombatLockdown() or not metrics then return end

    local data = GetEditModeLayouts()
    if not data then
        ScheduleForeverRecoveryRetry(self, 2)
        return
    end

    local activeID = tonumber(data.activeLayout)
    local active = GetForeverLayoutByID(data, activeID)
    local activeName = active and active.layoutName
    local preferredID, preferredLayout = PrepareForeverEditModeState(data, metrics)
    local preferredName = preferredLayout and preferredLayout.layoutName
        or (type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeLayoutName or nil)
    local recovery = type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeRecovery or nil

    if IsForeverSingleScreenRecovery(metrics) then
        if not recovery then
            if not preferredID or activeID ~= preferredID
                or not EditModeLayoutNamesMatch(activeName, preferredName) then return end
            if self.foreverMismatchDeclined then return end
            if not self.foreverMismatchConfirmed then
                ScheduleForeverMismatchConfirmation(self)
                return
            end
            recovery = {
                restoreLayoutID = activeID,
                restoreLayoutName = activeName,
                fallbackLayoutID = FOREVER_MODERN_LAYOUT_ID,
                fallbackLayoutName = "Modern",
            }
            OffhandCharDB.foreverEditModeRecovery = recovery
            PersistForeverEditModeState()
        end
        if activeID == tonumber(recovery.restoreLayoutID)
            and self.foreverRecoveryPromptShown ~= "fallback" then
            self.foreverRecoveryPromptShown = "fallback"
            if Offhand.ShowForeverLayoutRecoveryPrompt then
                Offhand:ShowForeverLayoutRecoveryPrompt("fallback", recovery.restoreLayoutName)
            end
        end
        return
    end


    self.foreverMismatchConfirmed = nil
    self.foreverMismatchDeclined = nil

    if recovery and metrics.companionTopology and metrics.isSpanned then
        local restoreID, restoreLayout = ResolveForeverLayoutID(
            data, recovery.restoreLayoutID, recovery.restoreLayoutName)
        if restoreID and restoreLayout then
            local changed = recovery.restoreLayoutID ~= restoreID
                or recovery.restoreLayoutName ~= restoreLayout.layoutName
            recovery.restoreLayoutID = restoreID
            recovery.restoreLayoutName = restoreLayout.layoutName
            if changed then PersistForeverEditModeState() end
        end
        local fallbackMatches = activeID == tonumber(recovery.fallbackLayoutID)
        if activeID == restoreID then
            OffhandCharDB.foreverEditModeRecovery = nil
            PersistForeverEditModeState()
            self.foreverRecoveryPromptShown = nil
            if Offhand.HideForeverLayoutRecoveryPrompt then
                Offhand:HideForeverLayoutRecoveryPrompt("fallback")
                Offhand:HideForeverLayoutRecoveryPrompt("restore")
            end
            return
        end
        if not fallbackMatches or not restoreID then
            -- A different active layout means the player made an explicit
            -- choice during recovery. Do not replace it.
            OffhandCharDB.foreverEditModeRecovery = nil
            PersistForeverEditModeState()
            self.foreverRecoveryPromptShown = nil
            if Offhand.HideForeverLayoutRecoveryPrompt then
                Offhand:HideForeverLayoutRecoveryPrompt("fallback")
                Offhand:HideForeverLayoutRecoveryPrompt("restore")
            end
            return
        end
        if self.foreverRecoveryPromptShown ~= "restore" then
            self.foreverRecoveryPromptShown = "restore"
            if Offhand.ShowForeverLayoutRecoveryPrompt then
                Offhand:ShowForeverLayoutRecoveryPrompt("restore", recovery.restoreLayoutName)
            end
        end
    end
end

-- Forever marks layout switching AllowedWhenUntainted. Calls made from addon
-- timers are ignored, while the same call succeeds from a player click. These
-- methods are invoked only by the recovery popup buttons.
function HUD:ApplyForeverRecoveryChoice(choice)
    if InCombatLockdown() or type(OffhandCharDB) ~= "table" then return end
    local recovery = OffhandCharDB.foreverEditModeRecovery
    if type(recovery) ~= "table" then return end
    local targetID
    if choice == "restore" then
        local data = GetEditModeLayouts()
        local layout
        targetID, layout = ResolveForeverLayoutID(data, recovery.restoreLayoutID, recovery.restoreLayoutName)
        if targetID and layout then
            recovery.restoreLayoutID = targetID
            recovery.restoreLayoutName = layout.layoutName
        end
    else
        targetID = tonumber(recovery.fallbackLayoutID)
    end
    if not targetID then return end
    SelectEditModeLayout(targetID)
    self.foreverRecoveryPromptShown = nil
    local confirmed = GetEditModeLayouts()
    if choice == "restore" and confirmed and tonumber(confirmed.activeLayout) == targetID then
        OffhandCharDB.foreverEditModeRecovery = nil
        PersistForeverEditModeState()
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            local current = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
            self:UpdateForeverRecoveryLayout(current)
        end)
    end
end

function HUD:CancelForeverRecoveryChoice(kind)
    if type(OffhandCharDB) == "table" then
        OffhandCharDB.foreverEditModeRecovery = nil
        PersistForeverEditModeState()
    end
    self.foreverRecoveryPromptShown = nil
    if kind == "fallback" then self.foreverMismatchDeclined = true end
end

local function FrameFitsPhysicalDisplay(frame, metrics)
    if not frame or not metrics or not frame.GetLeft or not frame.GetBottom
        or not frame.GetWidth or not frame.GetHeight then return true end
    local ok, left, bottom, width, height = pcall(function()
        local parentScale = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
        local factor = frameScale / parentScale
        return frame:GetLeft() * factor, frame:GetBottom() * factor,
            frame:GetWidth() * factor, frame:GetHeight() * factor
    end)
    if not ok or not left or not bottom or not width or not height then return true end
    local right, top = left + width, bottom + height
    local function Fits(l, b, r, t)
        return l and b and r and t and left >= l - 1 and bottom >= b - 1
            and right <= r + 1 and top <= t + 1
    end
    return Fits(metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop)
        or Fits(metrics.workspaceLeft, metrics.workspaceBottom, metrics.workspaceRight, metrics.workspaceTop)
end

local foreverEditModeControlNames = {
    "EditModeSystemSettingsDialog",
    "EditModeLayoutDialog",
    "EditModeImportLayoutDialog",
    "EditModeImportLayoutLinkDialog",
    "EditModeUnsavedChangesDialog",
    "EditModeDialog",
}

-- Transactional layout modals reuse stale anchors while Blizzard changes
-- modes. Observing those anchors must never inject another modal into the
-- save/rename/delete flow. Keep them in the explicit recovery action above,
-- but only auto-offer recovery for persistent Edit Mode control surfaces.
local foreverEditModeAutoRecoveryNames = {
    EditModeSystemSettingsDialog = true,
}

local foreverEditModeTransactionalNames = {
    "EditModeLayoutDialog",
    "EditModeImportLayoutDialog",
    "EditModeImportLayoutLinkDialog",
    "EditModeUnsavedChangesDialog",
    "EditModeDialog",
}

local function CanRecoverForeverEditModeControls(metrics)
    return metrics and (metrics.isSpanned or IsForeverSingleScreenRecovery(metrics)) or false
end

-- Transactional dialogs no longer use this popup path, so the persistent
-- manager/settings controls need only survive one fast recovery scan.
local FOREVER_EDIT_MODE_RECOVERY_SETTLE_SECONDS = 0.15

local function ClearForeverEditModeControlsCandidate(self)
    self.foreverEditModeControlsCandidate = nil
    self.foreverEditModeControlsCandidateConfirmed = nil
    self.foreverEditModeControlsCandidateGeneration =
        (self.foreverEditModeControlsCandidateGeneration or 0) + 1
end

local function CenterUnprotectedEditModeControl(frame, metrics)
    if not frame or not frame.IsShown or not frame:IsShown()
        or (frame.IsForbidden and frame:IsForbidden())
        or (frame.IsProtected and frame:IsProtected())
        or FrameFitsPhysicalDisplay(frame, metrics) then return false end
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
    local factor = parentScale / frameScale
    local centerX = (metrics.gameLeft + metrics.gameRight) / 2
    local centerY = (metrics.gameBottom + metrics.gameTop) / 2
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
        (centerX - UIParent:GetWidth() / 2) * factor,
        (centerY - UIParent:GetHeight() / 2) * factor)
    return true
end

-- Save, rename, import, and delete dialogs are ordinary unprotected control
-- surfaces on Forever. Keep their recovery non-modal: while Edit Mode is open,
-- center only a visible dialog that is genuinely outside both displays. Never
-- hook Blizzard frames or touch protected HUD systems.
function HUD:RecoverForeverTransactionalEditModeDialogs(metrics)
    if not HasBlizzardEditMode() or InCombatLockdown()
        or not Offhand.db or not Offhand.db.enabled then return 0 end
    local manager = _G.EditModeManagerFrame
    if not manager or not manager.IsShown or not manager:IsShown() then return 0 end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics())
    if not CanRecoverForeverEditModeControls(metrics) then return 0 end
    local moved = 0
    for _, name in ipairs(foreverEditModeTransactionalNames) do
        local ok, changed = pcall(CenterUnprotectedEditModeControl, _G[name], metrics)
        if ok and changed then moved = moved + 1 end
    end
    return moved
end

-- Blizzard can anchor its Edit Mode manager outside the physical displays on a
-- mixed-height span. This occurs on Retail as well as Forever. Detection stays
-- read-only until a candidate survives native layout settlement. Only known
-- unprotected controls can then be rescued; the preference retains the manual
-- recovery prompt for players who disable automatic recovery.
function HUD:UpdateForeverEditModeControlsRecovery(metrics)
    if not HasBlizzardEditMode() or not Offhand.db or not Offhand.db.enabled then return end
    local manager = _G.EditModeManagerFrame
    local shown = manager and manager.IsShown and manager:IsShown()
    if not shown then
        if self.foreverEditModeManagerWasShown and Offhand.HideForeverEditModeControlsPrompt then
            Offhand:HideForeverEditModeControlsPrompt()
        end
        self.foreverEditModeManagerWasShown = nil
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = nil
        self.foreverEditModeOutsideControl = nil
        ClearForeverEditModeControlsCandidate(self)
        return
    end

    if not self.foreverEditModeManagerWasShown then
        self.foreverEditModeManagerWasShown = true
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = nil
        ClearForeverEditModeControlsCandidate(self)
    end
    if InCombatLockdown() then return end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics())
    -- A stale spanned layout can strand the manager or its settings dialog
    -- after the Companion restores WoW to one display. That recovery state is
    -- as actionable as the mixed-height span. Controls still pass the same
    -- physical-display, settlement and protected-frame checks before rescue.
    if not CanRecoverForeverEditModeControls(metrics) then
        ClearForeverEditModeControlsCandidate(self)
        return
    end
    self:RecoverForeverTransactionalEditModeDialogs(metrics)

    -- The manager toolbar can be fully visible while the separate settings
    -- dialog opened for a selected HUD element is mostly in the mixed-height
    -- void. Transactional dialogs were handled separately above; protected
    -- HUD systems are never moved by control recovery.
    local outsideControl
    local visibleDialog
    for _, name in ipairs(foreverEditModeControlNames) do
        local frame = _G[name]
        if frame and frame.IsShown and frame:IsShown() then
            visibleDialog = frame
            if foreverEditModeAutoRecoveryNames[name]
                and not FrameFitsPhysicalDisplay(frame, metrics) then
                outsideControl = frame
                break
            end
        end
    end
    -- A reachable Blizzard modal should have exclusive focus. Defer recovery
    -- of an off-screen manager until that save/rename/delete dialog closes;
    -- an off-screen modal itself still takes priority and remains recoverable.
    if not outsideControl and not visibleDialog
        and not FrameFitsPhysicalDisplay(manager, metrics) then
        outsideControl = manager
    end
    if not outsideControl then
        -- Blizzard can finish centering a modal after the scan that raised our
        -- recovery prompt. Dismiss that now-stale prompt so it never obscures
        -- a reachable save/rename/delete dialog. Clearing the decline marker
        -- also lets a later reuse of EditModeLayoutDialog be recovered.
        if self.foreverEditModeControlsPromptShown
            and Offhand.HideForeverEditModeControlsPrompt then
            Offhand:HideForeverEditModeControlsPrompt()
        end
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = nil
        self.foreverEditModeOutsideControl = nil
        ClearForeverEditModeControlsCandidate(self)
        return
    end
    if self.foreverEditModeOutsideControl ~= outsideControl then
        if self.foreverEditModeControlsPromptShown
            and Offhand.HideForeverEditModeControlsPrompt then
            Offhand:HideForeverEditModeControlsPrompt()
        end
        self.foreverEditModeControlsPromptShown = nil
        self.foreverEditModeControlsPromptDeclined = nil
        self.foreverEditModeOutsideControl = outsideControl
        ClearForeverEditModeControlsCandidate(self)
    end
    if self.foreverEditModeControlsPromptShown or self.foreverEditModeControlsPromptDeclined then return end

    -- EditModeLayoutDialog briefly inherits its old/off-screen anchor while
    -- Blizzard changes between save, rename, and delete modes. Wait for that
    -- native positioning pass to settle before offering recovery. This avoids
    -- a one-second popup flash without hooking or writing protected UI.
    if self.foreverEditModeControlsCandidate ~= outsideControl then
        self.foreverEditModeControlsCandidate = outsideControl
        self.foreverEditModeControlsCandidateConfirmed = nil
        self.foreverEditModeControlsCandidateGeneration =
            (self.foreverEditModeControlsCandidateGeneration or 0) + 1
        local generation = self.foreverEditModeControlsCandidateGeneration
        if C_Timer and C_Timer.After then
            C_Timer.After(FOREVER_EDIT_MODE_RECOVERY_SETTLE_SECONDS, function()
                if HUD.foreverEditModeControlsCandidateGeneration ~= generation
                    or HUD.foreverEditModeControlsCandidate ~= outsideControl then return end
                HUD.foreverEditModeControlsCandidateConfirmed = outsideControl
                HUD:UpdateForeverEditModeControlsRecovery()
            end)
            return
        end
        self.foreverEditModeControlsCandidateConfirmed = outsideControl
    end
    if self.foreverEditModeControlsCandidateConfirmed ~= outsideControl then return end
    if Offhand.db.autoRecoverEditModeControls ~= false then
        local ok, moved = pcall(CenterUnprotectedEditModeControl, outsideControl, metrics)
        if ok and moved then
            if Offhand.HideForeverEditModeControlsPrompt then
                Offhand:HideForeverEditModeControlsPrompt()
            end
            self.foreverEditModeControlsPromptShown = nil
            self.foreverEditModeControlsPromptDeclined = nil
            self.foreverEditModeOutsideControl = nil
            ClearForeverEditModeControlsCandidate(self)
            return
        end
    end
    ClearForeverEditModeControlsCandidate(self)
    self.foreverEditModeControlsPromptShown = true
    if Offhand.ShowForeverEditModeControlsPrompt then
        Offhand:ShowForeverEditModeControlsPrompt()
    end
end

-- Supported Blizzard clients accept these unprotected control-surface anchor
-- changes from the recovery control's hardware click. Do not move Edit Mode
-- systems, attach handlers, or alter Blizzard's panel metadata from this path.
function HUD:BringForeverEditModeControlsToMainhand()
    if not HasBlizzardEditMode() or InCombatLockdown() then return false end
    local manager = _G.EditModeManagerFrame
    if not manager or not manager.IsShown or not manager:IsShown()
        or (manager.IsForbidden and manager:IsForbidden())
        or (manager.IsProtected and manager:IsProtected()) then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics()
    if not CanRecoverForeverEditModeControls(metrics) then return false end

    local moved = false
    local function Recover(frame)
        if CenterUnprotectedEditModeControl(frame, metrics) then moved = true end
    end

    Recover(manager)
    for _, name in ipairs(foreverEditModeControlNames) do Recover(_G[name]) end
    if not moved then return false end
    self.foreverEditModeControlsPromptShown = nil
    self.foreverEditModeControlsPromptDeclined = nil
    self.foreverEditModeOutsideControl = nil
    ClearForeverEditModeControlsCandidate(self)
    return true
end

function HUD:DismissForeverEditModeControlsPrompt()
    self.foreverEditModeControlsPromptShown = nil
    self.foreverEditModeControlsPromptDeclined = true
    ClearForeverEditModeControlsCandidate(self)
end

local foreverPartyRaidRecoveryNames = {
    PartyFrame = true, PartyMemberFrame1 = true, CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
}

local function FrameIsActuallyVisible(frame)
    if not frame then return false end
    local method = type(frame.IsVisible) == "function" and frame.IsVisible or frame.IsShown
    if type(method) ~= "function" then return false end
    local ok, visible = pcall(method, frame)
    return ok and visible == true
end

local function VisibleChildFitsPhysicalDisplay(frame, metrics, depth)
    if not frame or type(frame.GetChildren) ~= "function" or (depth or 0) > 2 then
        return false
    end
    local ok, children = pcall(function() return { frame:GetChildren() } end)
    if not ok or type(children) ~= "table" then return false end
    for _, child in ipairs(children) do
        if FrameIsActuallyVisible(child) then
            local dimensionsOK, width, height = pcall(function()
                return child.GetWidth and child:GetWidth() or 0,
                    child.GetHeight and child:GetHeight() or 0
            end)
            if not dimensionsOK then width, height = 0, 0 end
            if width and height and width > 2 and height > 2
                and FrameFitsPhysicalDisplay(child, metrics) then
                return true
            end
            if VisibleChildFitsPhysicalDisplay(child, metrics, (depth or 0) + 1) then
                return true
            end
        end
    end
    return false
end

-- Retail exposes overlapping PartyFrame/CompactPartyFrame ownership roots.
-- A legacy or preview container can retain stale full-canvas bounds even while
-- the actual visible member frames from the selected layout are correctly on
-- Mainhand. Treat a reachable visible group presentation as authoritative so
-- the stale alias cannot create an endless Repair HUD loop.
local function RetailGroupPresentationFits(metrics)
    if UsesForeverEditMode() then return false end
    for name in pairs(foreverPartyRaidRecoveryNames) do
        local frame = _G[name]
        if FrameIsActuallyVisible(frame) and (FrameFitsPhysicalDisplay(frame, metrics)
            or VisibleChildFitsPhysicalDisplay(frame, metrics, 0)) then
            return true
        end
    end
    return false
end

-- Retail's MinimapCluster is another Edit Mode ownership container whose root
-- can retain preview coordinates in mixed-height dead space. The actual
-- Minimap child is the user-visible presentation, so its reachable bounds are
-- authoritative. Unlike the status-bar proxies below, a genuinely unreachable
-- minimap remains eligible for recovery.
local function ProtectedHUDPresentationFits(name, frame, metrics)
    if name ~= "MinimapCluster" then return false end
    local minimap = _G.Minimap
    if FrameIsActuallyVisible(minimap) and (FrameFitsPhysicalDisplay(minimap, metrics)
        or VisibleChildFitsPhysicalDisplay(minimap, metrics, 0)) then
        return true
    end
    return VisibleChildFitsPhysicalDisplay(frame, metrics, 0)
end

-- Explicit roots for protected Edit Mode systems whose previews can expose an
-- unreachable anchor. Keep this bounded: transient tooltips, loot popups and
-- nameplates use separate positioning/scaling lifecycles and do not belong in
-- protected-layout recovery.
local foreverProtectedHUDRecoveryNames = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "BossTargetFrameContainer",
    "PartyFrame", "PartyMemberFrame1", "CompactPartyFrame", "CompactRaidFrameContainer",
    "MainMenuBar", "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight",
    "MultiBarLeft", "MultiBarRight", "StanceBar", "PetActionBar", "PossessActionBar",
    "MinimapCluster", "StatusTrackingBarManager", "MainMenuExpBar",
    "BuffFrame", "BuffCluster", "CastingBarFrame", "PlayerCastingBarFrame",
    "ExtraAbilityContainer", "ExtraActionBarFrame", "ZoneAbilityFrame",
    "EncounterBar", "UIWidgetPowerBarContainerFrame", "LossOfControlFrame",
    "MainMenuBarVehicleLeaveButton", "VehicleExitButton", "TotemFrame",
    "MultiCastActionBarFrame", "PersonalResourceDisplayFrame",
    "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer",
    "DamageMeter", "DurabilityFrame", "RaidWarningFrame", "UIErrorsFrame",
}

-- These containers expose stale or synthetic preview bounds in Edit Mode even
-- when their live XP/reputation bars are correctly placed. Rebuilding the same
-- layout cannot change that ownership-root rectangle, so it must never trigger
-- the automatic Repair HUD transaction.
local unreliableProtectedHUDRecoveryNames = {
    StatusTrackingBarManager = true,
    MainMenuExpBar = true,
}

-- Mixed-height spans contain real UIParent space that is not backed by a
-- physical monitor. Blizzard Edit Mode anchors can land there on Retail and
-- Forever.
-- Detect the condition without writing anchors and explain the player-click
-- recovery once per occurrence.
function HUD:UpdateForeverPartyFrameRecovery(metrics)
    if not HasBlizzardEditMode() or not Offhand.db or not Offhand.db.enabled then return end
    -- Blizzard's Gamepad UI owns these protected HUD systems and its Edit Mode
    -- preset. Inspecting the native frame tree during that focus/layout
    -- transaction can taint secret unit-frame values, and Offhand cannot repair
    -- the controller preset. Clear stale keyboard-mode recovery state instead.
    if UsesControllerInterface() then
        if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
            Offhand:HideForeverPartyFrameRecoveryPrompt()
        end
        self.foreverPartyFrameOutsideDisplays = nil
        self.foreverProtectedHUDDetectedInEditMode = nil
        self.foreverPartyFrameRecoveryPromptShown = nil
        self.foreverPartyFrameRecoveryPromptDeclined = nil
        return
    end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics())
    if not metrics or not metrics.isSpanned then
        if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
            Offhand:HideForeverPartyFrameRecoveryPrompt()
        end
        self.foreverPartyFrameOutsideDisplays = nil
        self.foreverProtectedHUDDetectedInEditMode = nil
        self.foreverPartyFrameRecoveryPromptShown = nil
        self.foreverPartyFrameRecoveryPromptDeclined = nil
        return
    end
    if InCombatLockdown() then return end

    local manager = _G.EditModeManagerFrame
    local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
    local outsideName
    if editModeOpen then
        -- Blizzard retains several dormant ownership roots with stale bounds.
        -- They are not evidence of a lost HUD frame during ordinary play. Only
        -- inspect them while Edit Mode is actively presenting the corresponding
        -- systems, then remember that observed candidate until Edit Mode closes.
        for _, name in ipairs(foreverProtectedHUDRecoveryNames) do
            local frame = _G[name]
            local customPartyFrames = foreverPartyRaidRecoveryNames[name] and HasEllesmerePartyFrames()
            local groupPresentationFits = foreverPartyRaidRecoveryNames[name]
                and RetailGroupPresentationFits(metrics)
            local protectedPresentationFits = ProtectedHUDPresentationFits(name, frame, metrics)
            if not unreliableProtectedHUDRecoveryNames[name]
                and not customPartyFrames and not groupPresentationFits
                and not protectedPresentationFits
                and FrameIsActuallyVisible(frame)
                and not FrameFitsPhysicalDisplay(frame, metrics) then
                outsideName = name
                break
            end
        end
    else
        -- Party/Raid previews can become hidden as soon as Edit Mode closes.
        -- Retain a candidate observed while Edit Mode was open long enough to
        -- offer the repair after Blizzard's layout transaction has finished.
        if self.foreverProtectedHUDDetectedInEditMode
            and self.foreverPartyFrameOutsideDisplays then
            outsideName = self.foreverPartyFrameOutsideDisplays
        end
    end

    if not outsideName then
        if self.foreverPartyFrameOutsideDisplays and Offhand.HideForeverPartyFrameRecoveryPrompt then
            Offhand:HideForeverPartyFrameRecoveryPrompt()
        end
        self.foreverPartyFrameOutsideDisplays = nil
        self.foreverProtectedHUDDetectedInEditMode = nil
        self.foreverPartyFrameRecoveryPromptShown = nil
        self.foreverPartyFrameRecoveryPromptDeclined = nil
        return
    end
    self.foreverPartyFrameOutsideDisplays = outsideName
    if editModeOpen then
        self.foreverProtectedHUDDetectedInEditMode = true
        return
    end
    if self.foreverPartyFrameRecoveryPromptShown
        or self.foreverPartyFrameRecoveryPromptDeclined then return end
    self.foreverPartyFrameRecoveryPromptShown = true
    if Offhand.ShowForeverPartyFrameRecoveryPrompt then
        Offhand:ShowForeverPartyFrameRecoveryPrompt(outsideName)
    end
end

function HUD:DismissForeverPartyFrameRecoveryPrompt()
    self.foreverPartyFrameRecoveryPromptShown = nil
    self.foreverPartyFrameRecoveryPromptDeclined = true
    self.foreverProtectedHUDDetectedInEditMode = nil
end

-- Protected HUD frames cannot be reanchored safely. The recovery popup is a
-- hardware click, so use the same Blizzard Edit Mode layout transaction as the
-- setup wizard, then let Blizzard apply the protected anchors during reload.
function HUD:RepairProtectedHUDLayout()
    if InCombatLockdown() then
        self.foreverPartyFrameRecoveryPromptShown = nil
        return false, "combat"
    end
    if UsesControllerInterface() then
        self:DismissForeverPartyFrameRecoveryPrompt()
        return false, "gamepad"
    end
    local manager = _G.EditModeManagerFrame
    if manager and ((manager.IsShown and manager:IsShown()) or manager.editModeActive) then
        self.foreverPartyFrameRecoveryPromptShown = nil
        return false, "open"
    end
    local mainhand = Offhand.Mainhand
    if not mainhand or type(mainhand.CreateOrUpdateEditModeLayout) ~= "function" then
        self:DismissForeverPartyFrameRecoveryPrompt()
        return false, "unavailable"
    end

    local candidate = self.foreverPartyFrameOutsideDisplays
    local ok, value, moved = mainhand:CreateOrUpdateEditModeLayout({
        repairFrameName = candidate,
    })
    if not ok then
        if value == "combat" or value == "open" then
            self.foreverPartyFrameRecoveryPromptShown = nil
        else
            self:DismissForeverPartyFrameRecoveryPrompt()
        end
        return false, value
    end

    self:DismissForeverPartyFrameRecoveryPrompt()
    if mainhand.PromptReload then mainhand:PromptReload() end
    return true, value, moved
end

-- Read-only evidence for reports where protected group frames appear in Edit
-- Mode but not during play. Blizzard intentionally hides these frames while
-- solo, so diagnostics must distinguish native visibility from an unreachable
-- anchor before recommending recovery.
function HUD:GetForeverGroupFrameDiagnostics()
    if not HasBlizzardEditMode() then return nil end
    local grouped = type(IsInGroup) == "function" and IsInGroup() or false
    local raiding = type(IsInRaid) == "function" and IsInRaid() or false
    local manager = _G.EditModeManagerFrame
    local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
    local states = {}
    for _, name in ipairs({"PartyFrame", "PartyMemberFrame1", "CompactPartyFrame", "CompactRaidFrameContainer"}) do
        local frame = _G[name]
        if not frame then
            states[#states + 1] = name .. "=missing"
        else
            local shown = false
            if frame.IsShown then
                local ok, value = pcall(frame.IsShown, frame)
                shown = ok and value or false
            end
            local bounds = "unresolved"
            if frame.GetLeft and frame.GetBottom and frame.GetRight and frame.GetTop then
                local ok, left, bottom, right, top = pcall(function()
                    return frame:GetLeft(), frame:GetBottom(), frame:GetRight(), frame:GetTop()
                end)
                if ok and left and bottom and right and top then
                    bounds = string.format("%.0f,%.0f-%.0f,%.0f", left, bottom, right, top)
                end
            end
            states[#states + 1] = string.format("%s=%s@%s", name,
                shown and "shown" or "hidden", bounds)
        end
    end
    return string.format("Group=%s | Raid=%s | EditMode=%s | %s",
        grouped and "yes" or "no", raiding and "yes" or "no",
        editModeOpen and "open" or "closed", table.concat(states, ","))
end

function HUD:GetForeverProtectedHUDDiagnostics(metrics)
    if not HasBlizzardEditMode() then return nil end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics())
    local manager = _G.EditModeManagerFrame
    local editModeOpen = manager and manager.IsShown and manager:IsShown() or false
    local visible, outside = 0, {}
    for _, name in ipairs(foreverProtectedHUDRecoveryNames) do
        local frame = _G[name]
        if FrameIsActuallyVisible(frame) then
            visible = visible + 1
            local groupPresentationFits = foreverPartyRaidRecoveryNames[name]
                and RetailGroupPresentationFits(metrics)
            local protectedPresentationFits = ProtectedHUDPresentationFits(name, frame, metrics)
            if editModeOpen and metrics and not unreliableProtectedHUDRecoveryNames[name]
                and not groupPresentationFits and not protectedPresentationFits
                and not FrameFitsPhysicalDisplay(frame, metrics) then
                outside[#outside + 1] = name
            end
        end
    end
    return string.format("EditMode=%s | Visible=%d | Outside=%s | Candidate=%s",
        editModeOpen and "open" or "closed", visible,
        editModeOpen and (#outside > 0 and table.concat(outside, ",") or "none")
            or "not-scanned",
        tostring(self.foreverPartyFrameOutsideDisplays or "none"))
end

local function Remember(frame)
    desiredFrames[frame] = desiredFrames[frame] or {}
    return desiredFrames[frame]
end

-- Rewriting identical anchors dirties Blizzard layout again on the next frame.
local function Points(frame, ...)
    local desired = {...}
    Remember(frame).points = desired
    local same = frame:GetNumPoints() == #desired
    if same then
        for i, point in ipairs(desired) do
            local a, b, c, x, y = frame:GetPoint(i)
            if a ~= point[1] or b ~= point[2] or c ~= point[3]
                or math.abs((x or 0) - point[4]) > 0.001
                or math.abs((y or 0) - point[5]) > 0.001 then
                same = false; break
            end
        end
    end
    if same then return end
    frame:ClearAllPoints()
    for _, point in ipairs(desired) do frame:SetPoint(unpack(point)) end
end

local function ScreenPoint(frame, point, x, y)
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    Points(frame, {point, UIParent, "BOTTOMLEFT", x * factor, y * factor})
end

local function Anchor(frame, point, m, x, y, force)
    if not frame then return end
    if not force and frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if not force and frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    local px = point:find("LEFT") and m.gameLeft or point:find("RIGHT") and m.gameRight
        or (m.gameLeft + m.gameRight) / 2
    local py = point:find("TOP") and m.gameTop or point:find("BOTTOM") and m.gameBottom
        or (m.gameBottom + m.gameTop) / 2
    ScreenPoint(frame, point,
        px + (x or 0) * m.hudScale, py + (y or 0) * m.hudScale)
end

local function Prepare(frame, m)
    if not frame then return end
    frame:SetClampedToScreen(false)
end

-- Blizzard owns the visibility and interaction lifecycle of these transient
-- frames, but their stock anchors are relative to the complete spanned
-- UIParent. Keep only their presentation anchor relative to Mainhand. In
-- particular, do not register them as workspace panels, remember visibility,
-- or add Escape-key protection.
local mainhandTransientFrames = {
    { name = "ZoneTextFrame", point = "TOP", x = 0, y = -128 },
    { name = "SubZoneTextFrame", point = "BOTTOM", x = 0, y = 512 },
    { name = "BossBanner", point = "TOP", x = 0, y = -120 },
    { name = "EventToastManagerFrame", point = "TOP", x = 0, y = -190 },
    { name = "AlertFrame", point = "BOTTOM", x = 0, y = 128 },
    { name = "RolePollPopup", point = "TOP", x = 0, y = -15 },
    { name = "ReadyCheckFrame", point = "CENTER", x = 0, y = -10 },
    { name = "LFGDungeonReadyPopup", point = "CENTER", x = 0, y = -10, hookEvent = true },
    {
        name = "GroupLootContainer", point = "BOTTOM", x = 0, y = 190,
        secure = true, stockPoint = "BOTTOM", stockRelativePoint = "BOTTOM", stockX = 0, stockY = 190,
        allowAnyUIParentAnchor = true, allowUnanchored = true,
        groupLootRows = true,
    },
    -- PetBattleFrame is a full-screen layout root. Its top art, unit panels,
    -- weather display and bottom action tray all inherit this rectangle, so
    -- bounding the root preserves Blizzard's internal layout while moving the
    -- complete pet-battle presentation off the monitor seam.
    { name = "PetBattleFrame", secure = true, petBattleBounds = true },
    -- These overlays opt out of UIParent scaling on some client builds. That
    -- makes Blizzard's text roughly 1/UIParentScale times too large after a
    -- mixed-resolution span. Rejoin the normal scale hierarchy while Offhand
    -- owns their Mainhand presentation rectangle.
    { name = "CombatText", point = "CENTER", x = 0, y = 0, normalizeScale = true },
    { name = "TimerTracker", bounds = true, normalizeScale = true, hookEvent = true },
    -- Battleground objective widgets and score windows are anchored to the
    -- complete UIParent, which puts them on the monitor seam while spanned.
    -- Their widget/score trees can consume secret values in instanced combat,
    -- so adopt only Blizzard's stock anchor and write the replacement through
    -- a restricted secure handler. Never fall back to an insecure SetPoint.
    {
        name = "UIWidgetTopCenterContainerFrame", point = "TOP", x = 0, y = -15,
        secure = true, stockPoint = "TOP", stockRelativePoint = "TOP", stockX = 0, stockY = -15,
    },
    {
        name = "PVPMatchScoreboard", point = "CENTER", x = 0, y = 0,
        secure = true, stockPoint = "CENTER", stockRelativePoint = "CENTER", stockX = 0, stockY = 0,
    },
    {
        name = "PVPMatchResults", point = "CENTER", x = 0, y = 0,
        secure = true, stockPoint = "CENTER", stockRelativePoint = "CENTER", stockX = 0, stockY = 0,
    },
    { name = "HousingControlsFrame", point = "TOP", x = 0, y = -30 },
    {
        name = "HouseEditorFrame.ModeBar",
        point = "BOTTOM", x = 0, y = 0,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.ModeBar
        end,
    },
    {
        name = "HouseEditorFrame.StorageButton",
        point = "LEFT", x = 24, y = 150,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.StorageButton
        end,
    },
    {
        name = "HouseEditorFrame.StoragePanel",
        point = "LEFT", x = 24, y = 150,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.StoragePanel
        end,
    },
    {
        name = "HouseEditorFrame.MarketShoppingCartFrame",
        point = "BOTTOMRIGHT", x = -30, y = 20,
        resolve = function()
            return _G.HouseEditorFrame and _G.HouseEditorFrame.MarketShoppingCartFrame
        end,
    },
}

local transientHooks = {}
local secureTransientOwned = setmetatable({}, { __mode = "k" })
local secureTransientPositioner
local groupLootPreloadAttempted = false
local petBattlePreloadAttempted = false
local petBattleConflict
local groupLootRowsOwned = setmetatable({}, { __mode = "k" })
local groupLootRowMover = {
    active = false,
    hooked = false,
    container = nil,
    physicalX = nil,
    physicalY = nil,
    rowsMoved = 0,
    conflict = nil,
}
local groupLootMoverFrame
local groupLootMoverRequested = false
local groupLootMoverDragging = false

-- Keep /offhand diag focused on the current group-loot QA surface without
-- reading protected frame geometry in combat. These flags describe only the
-- addon-owned secure setup; the tester's screenshot confirms final placement.
function HUD:GetGroupLootDiagnostics()
    local container = _G.GroupLootContainer
    local triggerCount = 0
    for index = 1, 4 do
        if _G["GroupLootFrame" .. index] then triggerCount = triggerCount + 1 end
    end
    return {
        loaded = container ~= nil,
        preloadAttempted = groupLootPreloadAttempted,
        anchorPrepared = container and secureTransientOwned[container] == true or false,
        rowMoverPrepared = groupLootRowMover.hooked,
        rowMoverActive = groupLootRowMover.active,
        rowsMoved = groupLootRowMover.rowsMoved or 0,
        conflict = groupLootRowMover.conflict,
        customPosition = Offhand.db and type(Offhand.db.groupLootPosition) == "table"
            and tonumber(Offhand.db.groupLootPosition.x) ~= nil
            and tonumber(Offhand.db.groupLootPosition.y) ~= nil or false,
        moverShown = groupLootMoverFrame and groupLootMoverFrame.IsShown
            and groupLootMoverFrame:IsShown() or false,
        moverDragging = groupLootMoverDragging,
        stackDirection = Offhand.db and Offhand.db.groupLootStackDirection == "DOWN"
            and "DOWN" or "UP",
        triggerCount = triggerCount,
        inCombat = InCombatLockdown and InCombatLockdown() or false,
    }
end

function HUD:GetPetBattleDiagnostics()
    local frame = _G.PetBattleFrame
    return {
        loaded = frame ~= nil,
        preloadAttempted = petBattlePreloadAttempted,
        boundsPrepared = frame and secureTransientOwned[frame] == true or false,
        conflict = petBattleConflict,
        inCombat = InCombatLockdown and InCombatLockdown() or false,
    }
end

local function PreloadGroupLootForSecurePositioning()
    if groupLootPreloadAttempted or _G.GroupLootContainer or InCombatLockdown()
        or not Offhand.db or not Offhand.db.enabled then return end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if not metrics or not metrics.isSpanned then return end
    local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if type(load) ~= "function" then return end
    groupLootPreloadAttempted = true
    -- Load Blizzard's own LoD module while the player is safe so both the
    -- container fallback anchor and the native roll-update hook exist before
    -- the first in-combat roll of the session.
    pcall(load, "Blizzard_GroupLoot")
end

local function PreloadPetBattleForSecurePositioning()
    if petBattlePreloadAttempted or _G.PetBattleFrame or InCombatLockdown()
        or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if not metrics or not metrics.isSpanned then return end
    local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if type(load) ~= "function" then return end
    petBattlePreloadAttempted = true
    -- Wild pet battles enter combat lockdown. Load Blizzard's LoD module and
    -- establish its root bounds beforehand so no protected anchor write is
    -- needed when the battle starts.
    pcall(load, "Blizzard_PetBattleUI")
end

local function EnsureSecureTransientPositioner()
    if secureTransientPositioner then return secureTransientPositioner end
    if not CreateFrame or not UIParent or InCombatLockdown() then return nil end
    local ok, positioner = pcall(CreateFrame, "Frame", nil, UIParent, "SecureHandlerBaseTemplate")
    if not ok or not positioner or not positioner.SetFrameRef
        or not positioner.SetAttribute or not positioner.Execute then return nil end
    secureTransientPositioner = positioner
    return positioner
end

-- Forever initially anchors the Escape menu to the full spanned UIParent, whose
-- center can be the upper-left corner of Mainhand in a mixed-height topology.
-- Correct it from an external secure post-hook during the same ToggleGameMenu
-- call, before the next rendered frame. Do not replace Blizzard's function or
-- attach scripts to the menu itself.
local function PositionForeverGameMenu()
    if not UsesForeverEditMode() or InCombatLockdown()
        or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
    local frame = _G.GameMenuFrame
    local m = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if not frame or not m or not m.isSpanned or not frame.ClearAllPoints
        or not frame.SetPoint or (frame.IsForbidden and frame:IsForbidden()) then return false end
    if frame.IsProtected then
        local ok, protected = pcall(frame.IsProtected, frame)
        if not ok or protected then return false end
    end
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local cx = (m.gameLeft + m.gameRight) / 2
    local cy = (m.gameBottom + m.gameTop) / 2
    local ok = pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx * factor, cy * factor)
    end)
    return ok
end

local function IsStockSecureTransientAnchor(frame, spec)
    if secureTransientOwned[frame] then return true end
    if frame.IsUserPlaced and frame:IsUserPlaced() then return false end
    if not frame.GetNumPoints or not frame.GetPoint then return false end
    local numPoints = frame:GetNumPoints()
    -- GroupLootContainer is declared hidden without an XML anchor. Its first
    -- BottomManagedFrameContainer anchor is created only when a roll shows it,
    -- which can happen after combat begins. Preloading is useful only if that
    -- pristine zero-point state is eligible for the secure setup.
    if numPoints == 0 then return spec.allowUnanchored == true end
    if numPoints ~= 1 then return false end
    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    if relativeTo ~= nil and relativeTo ~= UIParent then return false end
    -- GroupLootContainer's stock vertical offset varies between client builds.
    -- A single UIParent-relative, non-user-placed anchor is still native stock;
    -- addon/user placements relative to another frame remain untouched.
    if spec.allowAnyUIParentAnchor then return true end
    local tolerance = 0.5
    return point == spec.stockPoint
        and (relativePoint or point) == spec.stockRelativePoint
        and math.abs((tonumber(x) or 0) - spec.stockX) <= tolerance
        and math.abs((tonumber(y) or 0) - spec.stockY) <= tolerance
end

local function SecureScreenPoint(frame, point, x, y)
    if InCombatLockdown() then return false end
    local positioner = EnsureSecureTransientPositioner()
    if not positioner then return false end
    local ok = pcall(function()
        positioner:SetFrameRef("offhandTransient", frame)
        positioner:SetAttribute("offhandPoint", point)
        positioner:SetAttribute("offhandX", x)
        positioner:SetAttribute("offhandY", y)
        positioner:SetAttribute("offhandBounds", false)
        positioner:Execute([[
            local frame = self:GetFrameRef("offhandTransient")
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint(
                    self:GetAttribute("offhandPoint"),
                    self:GetParent(), "BOTTOMLEFT",
                    self:GetAttribute("offhandX"), self:GetAttribute("offhandY"))
            end
        ]])
    end)
    return ok
end

local function PointMatches(point, relativeTo, relativePoint, x, y,
        expectedPoint, expectedRelativePoint, expectedX, expectedY)
    local tolerance = 0.5
    return point == expectedPoint
        and (relativeTo == nil or relativeTo == UIParent)
        and (relativePoint or point) == expectedRelativePoint
        and math.abs((tonumber(x) or 0) - expectedX) <= tolerance
        and math.abs((tonumber(y) or 0) - expectedY) <= tolerance
end

local function IsNativePetBattleBounds(frame, metrics)
    if frame.IsUserPlaced and frame:IsUserPlaced() then return false end
    if not frame.GetNumPoints or not frame.GetPoint or frame:GetNumPoints() ~= 2 then return false end

    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local expected = {
        stockTopLeft = { "TOPLEFT", "TOPLEFT", 0, 0 },
        stockBottomRight = { "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0 },
        mainBottomLeft = {
            "BOTTOMLEFT", "BOTTOMLEFT", metrics.gameLeft * factor, metrics.gameBottom * factor,
        },
        mainTopRight = {
            "TOPRIGHT", "BOTTOMLEFT", metrics.gameRight * factor, metrics.gameTop * factor,
        },
    }
    local matches = {}
    for index = 1, 2 do
        local point, relativeTo, relativePoint, x, y = frame:GetPoint(index)
        for key, value in pairs(expected) do
            if PointMatches(point, relativeTo, relativePoint, x, y,
                    value[1], value[2], value[3], value[4]) then
                matches[key] = true
            end
        end
    end
    return (matches.stockTopLeft and matches.stockBottomRight)
        or (matches.mainBottomLeft and matches.mainTopRight)
end

local function SecureScreenBounds(frame, metrics)
    if InCombatLockdown() then return false end
    local positioner = EnsureSecureTransientPositioner()
    if not positioner then return false end
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local ok = pcall(function()
        positioner:SetFrameRef("offhandTransient", frame)
        positioner:SetAttribute("offhandLeft", metrics.gameLeft * factor)
        positioner:SetAttribute("offhandBottom", metrics.gameBottom * factor)
        positioner:SetAttribute("offhandRight", metrics.gameRight * factor)
        positioner:SetAttribute("offhandTop", metrics.gameTop * factor)
        positioner:SetAttribute("offhandBounds", true)
        positioner:Execute([[
            local frame = self:GetFrameRef("offhandTransient")
            if frame then
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOMLEFT", self:GetParent(), "BOTTOMLEFT",
                    self:GetAttribute("offhandLeft"), self:GetAttribute("offhandBottom"))
                frame:SetPoint("TOPRIGHT", self:GetParent(), "BOTTOMLEFT",
                    self:GetAttribute("offhandRight"), self:GetAttribute("offhandTop"))
            end
        ]])
    end)
    return ok
end

local function IsRetailChatSettlementActive(frame)
    return Offhand.Canvas and Offhand.Canvas.IsRetailEditModeChatSettlementActive
        and Offhand.Canvas:IsRetailEditModeChatSettlementActive(frame) or false
end

-- Blizzard deliberately owns GroupLootContainer through its alert-layout
-- system. Moving that managed container is only a fallback: combat and other
-- alert updates can place it back at the full-canvas center. The roll rows are
-- ordinary, non-protected frames, however, and Blizzard already rebuilds their
-- anchors in GroupLootContainer_Update. Follow Blizzard's native update first,
-- then preserve its ordering and spacing while
-- anchoring the visible rows directly inside Mainhand. A container relocation
-- can no longer carry those rows back to the monitor seam.
local function IsNativeGroupLootRowAnchor(row, container)
    if not row.GetNumPoints or not row.GetPoint then return false end
    local numPoints = row:GetNumPoints()
    if numPoints == 0 then return true end
    if numPoints ~= 1 then return false end
    local _, relativeTo = row:GetPoint(1)
    if relativeTo == container then return true end
    -- UIParent is accepted only after Offhand has adopted this row. A fresh
    -- UIParent-relative point may belong to another mover and must be preserved.
    return relativeTo == UIParent and groupLootRowsOwned[row] == true
end

local function GetSavedGroupLootCenter(metrics)
    local position = Offhand.db and Offhand.db.groupLootPosition
    local xRatio = type(position) == "table" and tonumber(position.x) or nil
    local yRatio = type(position) == "table" and tonumber(position.y) or nil
    if not xRatio or not yRatio or xRatio < 0 or xRatio > 1 or yRatio < 0 or yRatio > 1 then
        return nil, nil
    end
    return metrics.gameLeft + (metrics.gameRight - metrics.gameLeft) * xRatio,
        metrics.gameBottom + (metrics.gameTop - metrics.gameBottom) * yRatio
end

local function GetDefaultGroupLootCenter(metrics, container)
    local row = container and container.rollFrames and container.rollFrames[1]
    local rowScale = row and row.GetEffectiveScale and row:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local factor = parentScale / math.max(tonumber(rowScale) or 1, 0.0001)
    local reservedSize = tonumber(container and container.reservedSize) or 100
    return (metrics.gameLeft + metrics.gameRight) / 2,
        metrics.gameBottom + 190 * metrics.hudScale + (reservedSize * 0.5 / factor)
end

local function GetGroupLootCenter(metrics, container)
    local x, y = GetSavedGroupLootCenter(metrics)
    if x and y then return x, y, true end
    x, y = GetDefaultGroupLootCenter(metrics, container)
    return x, y, false
end

local function GetGroupLootStackDirection()
    return Offhand.db and Offhand.db.groupLootStackDirection == "DOWN"
        and "DOWN" or "UP"
end

local function PositionGroupLootRows(container)
    if not groupLootRowMover.active or container ~= groupLootRowMover.container
        or not Offhand.db or not Offhand.db.enabled or not Offhand.db.seamRedirect then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if not metrics or not metrics.isSpanned then return false end

    local rows = container and container.rollFrames
    if type(rows) ~= "table" then return false end
    local maxIndex = tonumber(container.maxIndex) or 0
    local reservedSize = tonumber(container.reservedSize) or 100
    local centerX, centerY = GetGroupLootCenter(metrics, container)
    local stackStep = GetGroupLootStackDirection() == "DOWN" and -reservedSize or reservedSize

    -- Validate the complete native set before moving anything. This makes an
    -- addon-owned mover (a row relative to its own anchor) an explicit conflict
    -- instead of creating a last-writer contest.
    for index = 1, maxIndex do
        local row = rows[index]
        if row then
            if (row.IsForbidden and row:IsForbidden())
                or (row.IsProtected and row:IsProtected())
                or not IsNativeGroupLootRowAnchor(row, container) then
                local name = row.GetName and row:GetName() or tostring(index)
                groupLootRowMover.active = false
                groupLootRowMover.conflict = "custom-or-protected-row:" .. tostring(name)
                return false
            end
        end
    end

    local moved = 0
    for index = 1, maxIndex do
        local row = rows[index]
        if row and row.ClearAllPoints and row.SetPoint then
            local rowScale = row.GetEffectiveScale and row:GetEffectiveScale() or 1
            local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
            local factor = parentScale / math.max(tonumber(rowScale) or 1, 0.0001)
            row:ClearAllPoints()
            row:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                centerX * factor,
                centerY * factor + stackStep * (index - 1))
            groupLootRowsOwned[row] = true
            moved = moved + 1
        end
    end
    groupLootRowMover.rowsMoved = moved
    groupLootRowMover.conflict = nil
    return true
end

local function ConfigureGroupLootRowMover(container, physicalX, physicalY)
    if InCombatLockdown() or not container then return false end
    groupLootRowMover.container = container
    groupLootRowMover.physicalX = physicalX
    groupLootRowMover.physicalY = physicalY
    groupLootRowMover.active = true
    groupLootRowMover.conflict = nil

    if not groupLootRowMover.hooked and type(_G.GroupLootContainer_Update) == "function"
        and type(hooksecurefunc) == "function" then
        hooksecurefunc("GroupLootContainer_Update", function(updatedContainer)
            PositionGroupLootRows(updatedContainer or _G.GroupLootContainer)
        end)
        groupLootRowMover.hooked = true
    end
    PositionGroupLootRows(container)
    return groupLootRowMover.hooked
end

local function PositionGroupLootMoverFrame(metrics)
    -- Layout, scale and native-alert refreshes may run repeatedly while the
    -- mouse is held. Re-anchoring here would fight StartMoving and make the
    -- preview jump back to its last saved point until mouse release.
    if not groupLootMoverFrame or groupLootMoverDragging then return false end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil)
    if not metrics or not metrics.isSpanned then return false end
    local x, y = GetGroupLootCenter(metrics, groupLootRowMover.container or _G.GroupLootContainer)
    groupLootMoverFrame:ClearAllPoints()
    groupLootMoverFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    return true
end

local function SaveGroupLootMoverPosition(frame)
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if not metrics or not metrics.isSpanned or not frame.GetCenter then return false end
    local centerX, centerY = frame:GetCenter()
    if not centerX or not centerY then return false end

    local halfWidth = ((frame.GetWidth and frame:GetWidth()) or 277) * 0.5
    local halfHeight = ((frame.GetHeight and frame:GetHeight()) or 67) * 0.5
    centerX = math.max(metrics.gameLeft + halfWidth,
        math.min(metrics.gameRight - halfWidth, centerX))
    centerY = math.max(metrics.gameBottom + halfHeight,
        math.min(metrics.gameTop - halfHeight, centerY))

    local width = math.max(metrics.gameRight - metrics.gameLeft, 1)
    local height = math.max(metrics.gameTop - metrics.gameBottom, 1)
    Offhand.db.groupLootPosition = {
        x = math.max(0, math.min(1, (centerX - metrics.gameLeft) / width)),
        y = math.max(0, math.min(1, (centerY - metrics.gameBottom) / height)),
    }
    PositionGroupLootMoverFrame(metrics)
    HUD:PositionMainhandTransientFrames(metrics)
    return true
end

local function EnsureGroupLootMoverFrame()
    if groupLootMoverFrame then return groupLootMoverFrame end
    if not CreateFrame or not UIParent or InCombatLockdown() then return nil end
    local template = not Offhand.isLegacyWrath and "BackdropTemplate" or nil
    groupLootMoverFrame = CreateFrame("Frame", "OffhandGroupLootMover", UIParent, template)
    groupLootMoverFrame:SetSize(277, 67)
    groupLootMoverFrame:SetFrameStrata("DIALOG")
    if groupLootMoverFrame.SetFrameLevel then groupLootMoverFrame:SetFrameLevel(900) end
    groupLootMoverFrame:SetMovable(true)
    groupLootMoverFrame:EnableMouse(true)
    groupLootMoverFrame:RegisterForDrag("LeftButton")
    if groupLootMoverFrame.SetBackdrop then
        groupLootMoverFrame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        groupLootMoverFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
        groupLootMoverFrame:SetBackdropBorderColor(1, 0.82, 0, 1)
    end

    local title = groupLootMoverFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER", groupLootMoverFrame, "CENTER", 0, 8)
    title:SetText((Offhand.L and Offhand.L["GROUP_LOOT_MOVER_TITLE"]) or "Group Loot Rolls")
    local instruction = groupLootMoverFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instruction:SetPoint("TOP", title, "BOTTOM", 0, -3)
    instruction:SetText((Offhand.L and Offhand.L["GROUP_LOOT_MOVER_DRAG"]) or "Drag to move")

    groupLootMoverFrame:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or not groupLootMoverRequested then return end
        groupLootMoverDragging = true
        self:StartMoving()
    end)
    groupLootMoverFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        groupLootMoverDragging = false
        if InCombatLockdown() then return end
        SaveGroupLootMoverPosition(self)
    end)
    if groupLootMoverFrame.RegisterEvent then
        groupLootMoverFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        groupLootMoverFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        groupLootMoverFrame:SetScript("OnEvent", function(self, event)
            if event == "PLAYER_REGEN_DISABLED" then
                if groupLootMoverDragging then self:StopMovingOrSizing() end
                groupLootMoverDragging = false
                self:Hide()
            elseif groupLootMoverRequested then
                PositionGroupLootMoverFrame()
                self:Show()
            end
        end)
    end
    groupLootMoverFrame:Hide()
    return groupLootMoverFrame
end

function HUD:SetGroupLootMoverShown(shown)
    shown = shown == true
    if shown and InCombatLockdown() then return false, "combat" end
    if shown then
        PreloadGroupLootForSecurePositioning()
        self:PositionMainhandTransientFrames()
        if groupLootRowMover.conflict then return false, "conflict" end
        if not groupLootRowMover.hooked or not groupLootRowMover.active then
            return false, "unavailable"
        end
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
            and Offhand.Viewport:GetMetrics() or nil
        if not metrics or not metrics.isSpanned then return false, "span" end
        local mover = EnsureGroupLootMoverFrame()
        if not mover then return false, "unavailable" end
        groupLootMoverRequested = true
        PositionGroupLootMoverFrame(metrics)
        mover:Show()
        return true, "shown"
    end
    groupLootMoverRequested = false
    if groupLootMoverFrame then
        if groupLootMoverDragging then groupLootMoverFrame:StopMovingOrSizing() end
        groupLootMoverDragging = false
        groupLootMoverFrame:Hide()
    end
    return true, "hidden"
end

function HUD:ToggleGroupLootMover()
    return self:SetGroupLootMoverShown(not groupLootMoverRequested)
end

function HUD:ResetGroupLootPosition()
    if not Offhand.db or InCombatLockdown() then return false end
    Offhand.db.groupLootPosition = {}
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    if metrics and metrics.isSpanned then
        PositionGroupLootMoverFrame(metrics)
        self:PositionMainhandTransientFrames(metrics)
    end
    return true
end

function HUD:SetGroupLootStackDirection(direction)
    if not Offhand.db then return false end
    Offhand.db.groupLootStackDirection = direction == "DOWN" and "DOWN" or "UP"
    if groupLootRowMover.active and groupLootRowMover.container then
        PositionGroupLootRows(groupLootRowMover.container)
    end
    return true
end

local function PositionSecureMainhandTransient(frame, spec, m)
    if spec.petBattleBounds then
        if not IsNativePetBattleBounds(frame, m) then
            secureTransientOwned[frame] = nil
            petBattleConflict = "custom-anchor"
            return false
        end
        if SecureScreenBounds(frame, m) then
            secureTransientOwned[frame] = true
            petBattleConflict = nil
            return true
        end
        return false
    end
    if not IsStockSecureTransientAnchor(frame, spec) then return false end
    local px = spec.point:find("LEFT") and m.gameLeft or spec.point:find("RIGHT") and m.gameRight
        or (m.gameLeft + m.gameRight) / 2
    local py = spec.point:find("TOP") and m.gameTop or spec.point:find("BOTTOM") and m.gameBottom
        or (m.gameBottom + m.gameTop) / 2
    local physicalX = px + (spec.x or 0) * m.hudScale
    local physicalY = py + (spec.y or 0) * m.hudScale
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    local x = physicalX * factor
    local y = physicalY * factor
    if spec.groupLootRows then
        ConfigureGroupLootRowMover(frame, physicalX, physicalY)
        if groupLootMoverRequested then PositionGroupLootMoverFrame(m) end
    end
    if SecureScreenPoint(frame, spec.point, x, y) then
        secureTransientOwned[frame] = true
        return true
    end
    return false
end

local function ResolveMainhandTransient(spec)
    if spec.resolve then return spec.resolve() end
    return _G[spec.name]
end

local function CanPositionMainhandTransient(frame, spec)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    -- Protected HUD/action frames remain Blizzard/Edit Mode owned. This keeps
    -- OverrideActionBar and any future secure replacements out of this path.
    if frame.IsProtected and frame:IsProtected() and not (spec and spec.secure) then return false end
    return true
end

local function NormalizeMainhandTransientScale(frame)
    if not frame or not frame.SetIgnoreParentScale or not frame.IsIgnoringParentScale then return end
    local ok, ignoresParent = pcall(frame.IsIgnoringParentScale, frame)
    if ok and ignoresParent then
        frame:SetIgnoreParentScale(false)
    end
end

local function PositionTimerTracker(frame, m)
    local parent = frame.GetParent and frame:GetParent()
    if parent and parent ~= UIParent then
        -- Commentator mode reparents TimerTracker to WorldFrame. Restore native
        -- fill behavior if Offhand previously bounded it, then yield ownership.
        if frame._OffhandMainhandTimerTracker and frame.SetAllPoints then
            frame:ClearAllPoints()
            frame:SetAllPoints(parent)
            frame._OffhandMainhandTimerTracker = nil
        end
        return
    end

    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    Points(frame,
        {"BOTTOMLEFT", UIParent, "BOTTOMLEFT", m.gameLeft * factor, m.gameBottom * factor},
        {"TOPRIGHT", UIParent, "BOTTOMLEFT", m.gameRight * factor, m.gameTop * factor})
    frame._OffhandMainhandTimerTracker = true

    -- The final "Go" texture is explicitly anchored to UIParent in Blizzard's
    -- XML instead of TimerTracker. Reattach only that presentation texture;
    -- its glow remains natively anchored to the texture.
    if type(frame.timerList) == "table" then
        for _, timer in pairs(frame.timerList) do
            local goTexture = timer and timer.GoTexture
            if goTexture and goTexture.ClearAllPoints and goTexture.SetPoint then
                goTexture:ClearAllPoints()
                goTexture:SetPoint("CENTER", frame, "CENTER", 0, 0)
            end
        end
    end
end

function HUD:PositionMainhandTransientFrames(m)
    if not Offhand.db or not Offhand.db.enabled
        or not Offhand.db.seamRedirect then return end
    if InCombatLockdown() then
        if not self.mainhandTransientCombatPending and Offhand.RunOrQueueCombat then
            self.mainhandTransientCombatPending = true
            Offhand:RunOrQueueCombat(function()
                HUD.mainhandTransientCombatPending = false
                HUD:PositionMainhandTransientFrames()
            end)
        end
        return
    end
    m = m or Offhand.Viewport:GetMetrics()
    if not m or not m.isSpanned then return end

    for _, spec in ipairs(mainhandTransientFrames) do
        local frame = ResolveMainhandTransient(spec)
        if CanPositionMainhandTransient(frame, spec) then
            pcall(function()
                if spec.secure then
                    PositionSecureMainhandTransient(frame, spec, m)
                else
                    Prepare(frame, m)
                    if spec.normalizeScale then NormalizeMainhandTransientScale(frame) end
                    if spec.bounds then
                        PositionTimerTracker(frame, m)
                    else
                        Anchor(frame, spec.point, m, spec.x, spec.y, true)
                    end
                end
            end)
        end
    end

    -- Static popups are pooled and Blizzard may restore their stock CENTER
    -- point after OnShow. Reapplying the same desired point is a no-op, while a
    -- later native reset is repaired on the next layout/ticker pass.
    for i = 1, 4 do
        local frame = _G["StaticPopup" .. i]
        if CanPositionMainhandTransient(frame) then
            pcall(function()
                Prepare(frame, m)
                NormalizeMainhandTransientScale(frame)
                Anchor(frame, "CENTER", m, 0, (i - 1) * 120, true)
            end)
        end
    end
end

function HUD:HookMainhandTransientFrames()
    PreloadGroupLootForSecurePositioning()
    PreloadPetBattleForSecurePositioning()
    -- Housing controls and the full-screen House Editor are load-on-demand.
    -- Install the hook as soon as Blizzard creates either module so an already
    -- shown child (notably HouseEditorFrame.ModeBar) is positioned before the
    -- periodic recovery pass. ModeBar does not receive its own OnShow when its
    -- hidden top-level parent becomes visible, so waiting for that script alone
    -- leaves it centered on the complete spanned UIParent.
    if not self.mainhandTransientLoader and CreateFrame then
        local loader = CreateFrame("Frame")
        if loader and loader.RegisterEvent and loader.SetScript then
            self.mainhandTransientLoader = loader
            loader:RegisterEvent("ADDON_LOADED")
            loader:SetScript("OnEvent", function(_, _, addonName)
                if addonName ~= "Blizzard_HousingControls"
                    and addonName ~= "Blizzard_HouseEditor"
                    and addonName ~= "Blizzard_UIWidgets"
                    and addonName ~= "Blizzard_PVPMatch"
                    and addonName ~= "Blizzard_GroupLoot"
                    and addonName ~= "Blizzard_LootUI"
                    and addonName ~= "Blizzard_CombatText"
                    and addonName ~= "Blizzard_PetBattleUI" then return end
                HUD:HookMainhandTransientFrames()
                HUD:PositionMainhandTransientFrames()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        HUD:HookMainhandTransientFrames()
                        HUD:PositionMainhandTransientFrames()
                    end)
                end
            end)
        end
    end

    for _, spec in ipairs(mainhandTransientFrames) do
        local frame = ResolveMainhandTransient(spec)
        -- Do not attach addon scripts to secret-sensitive widget/score trees.
        -- Their stock anchors are adopted before combat and repaired by the
        -- existing layout/ticker pass after combat.
        if not spec.secure and CanPositionMainhandTransient(frame, spec)
            and not transientHooks[frame] and frame.HookScript then
            transientHooks[frame] = true
            frame:HookScript("OnShow", function()
                HUD:PositionMainhandTransientFrames()
                if C_Timer and C_Timer.After then
                    for _, delay in ipairs({0, 0.05, 0.2}) do
                        C_Timer.After(delay, function() HUD:PositionMainhandTransientFrames() end)
                    end
                end
            end)
            if spec.hookEvent then
                frame:HookScript("OnEvent", function()
                    HUD:PositionMainhandTransientFrames()
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function() HUD:PositionMainhandTransientFrames() end)
                    end
                end)
            end
        end
    end
end

function HUD:RequestLayout()
    if aligning or pending or not Offhand.db or not Offhand.db.enabled then return end
    pending = true
    C_Timer.After(0.05, function()
        if not Offhand.db or not Offhand.db.enabled then pending = false; return end
        -- A HUD repair must not resize WorldFrame, the deck or docked modules.
        Offhand:RunOrQueueCombat(function()
            pending = false
            if Offhand.db and Offhand.db.enabled then HUD:AlignHUDFrames() end
        end)
    end)
end

function HUD:AlignChatFrame(m)
    if InCombatLockdown() or not Offhand.db.enabled or not ChatFrame1 or Offhand.db.dockChat == false then return end
    -- Chattynator owns the complete chat layout, including Blizzard's shared
    -- ChatFrame1EditBox.  Touching either its custom windows or that edit box
    -- can leave the visible input without mouse/focus handling.
    if HasChattynator() then return end
    local chat = ChatFrame1
    if IsRetailChatSettlementActive(chat) then return end
    if IsForeverEditModeFrame(chat, "ChatFrame1") then return end
    local chatName = (chat.GetName and chat:GetName()) or "ChatFrame1"
    local native = chat == ChatFrame1
    local retailManaged = native and RetailEditModeOwnsPrimaryChat(chat)
    local editModeActive = retailManaged and ((chat.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown()))
    if chat._OffhandDragging or MOVING_CHATFRAME == chat or editModeActive then return end
    if chat.Selection and chat.IsEditModeDragging and chat:IsEditModeDragging() then return end
    local nativeDefault = native and chat.IsInDefaultPosition and chat:IsInDefaultPosition()
    local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
        or (not native and Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
    -- Retail's primary chat frame is a Blizzard Edit Mode system. Offhand owns
    -- it only after an explicit workspace placement; otherwise Blizzard's
    -- active layout remains authoritative for both position and dimensions.
    if retailManaged and not isWs and Offhand.db.chatPosition ~= "DECK" then
        if Offhand.db.savedMainPositions then Offhand.db.savedMainPositions[chatName] = nil end
        return
    end
    Prepare(chat, m)
    if native then self:RepairChatDock() end
    if isWs then
        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
            Offhand.Canvas:RestoreWorkspacePosition(chat)
        elseif Offhand.Canvas and Offhand.Canvas.OnPanelDragStop and not (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName]) then
            Offhand.Canvas.OnPanelDragStop(chat)
        end
        if ChatFrame1EditBox then
            Points(ChatFrame1EditBox,
                {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
                {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
        end
        return
    end
    local mainPosition = native and Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[chatName]
    if mainPosition and Offhand.db.chatPosition ~= "DECK" then
        ScreenPoint(chat, mainPosition.point or "TOPLEFT", mainPosition.x, mainPosition.y)
        return
    end
    if not nativeDefault and chat.IsUserPlaced and chat:IsUserPlaced() and Offhand.db.chatPosition ~= "DECK" then return end
    if chat ~= ChatFrame1 and not hooks[chat] then
        hooks[chat] = true
        hooksecurefunc(chat, "SetPoint", function()
            local isWorkspace = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
                or (Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
            if not isWorkspace and not (chat.IsUserPlaced and chat:IsUserPlaced()) then
                HUD:RequestLayout()
            end
        end)
    end
    if Offhand.db.chatPosition == "DECK" and Offhand.canvas then
        pcall(function() chat:SetUserPlaced(false) end)
        ScreenPoint(chat, "BOTTOMLEFT",
            m.workspaceLeft + 24 * m.hudScale, m.workspaceBottom + 45 * m.hudScale)
        chat:SetSize(math.min(460, m.workspaceWidth / m.hudScale - 48), 220)
    else
        -- The native button strip sits outside the message frame's left edge.
        local inset = native and 48 or 24
        if native and chat.buttonFrame and chat.buttonFrame.GetWidth then
            inset = math.max(inset, chat.buttonFrame:GetWidth() + 17)
        end
        Anchor(chat, "BOTTOMLEFT", m, inset, 120, nativeDefault)
        local width = math.min(460, m.gameWidth / m.hudScale * 0.40)
        if not chat.GetWidth or not chat.GetHeight
            or math.abs(chat:GetWidth() - width) > 0.001 or math.abs(chat:GetHeight() - 220) > 0.001 then
            chat:SetSize(width, 220)
        end
    end
    if ChatFrame1EditBox then
        Points(ChatFrame1EditBox,
            {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
            {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
    end
end

function HUD:RepairChatDock()
    local dock = GENERAL_CHAT_DOCK or GeneralDockManager
    if not dock or dock.primary ~= ChatFrame1 then return end
    if dock.IsForbidden and dock:IsForbidden() then return end
    if dock.IsProtected and dock:IsProtected() then return end
    for _, key in ipairs({"savedWorkspacePositions", "savedMainPositions", "openWorkspacePanels"}) do
        if Offhand.db[key] then Offhand.db[key].GeneralDockManager = nil end
    end
    -- Tabs are dock children, not chat-frame children. Keep the native dock
    -- attached to chat, including after a former erroneous tab-parent drag.
    Points(dock,
        {"BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 6},
        {"BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 6})
    if not self.chatDockRepaired or (dock.IsShown and not dock:IsShown()) then
        if dock.Show then dock:Show() end
        if dock.SetAlpha then dock:SetAlpha(1) end
        if FCFDock_UpdateTabs and dock.DOCKED_CHAT_FRAMES then
            FCFDock_UpdateTabs(dock, true)
        end
        self.chatDockRepaired = true
    end
end

function HUD:RepairChatButtons(chat)
    if not chat or chat ~= _G.ChatFrame1 or not FCF_SetButtonSide then return end
    -- Forever's Edit Mode owns ChatFrame1ButtonFrame. Replaying the saved side
    -- while that layout is settling can move the channel/menu buttons to the
    -- opposite edge after /reload or an Edit Mode save. Retail still needs the
    -- native helper after Offhand moves a deliberately workspace-owned chat.
    if Offhand.isForever then return end
    -- The channel/menu controls are children of ChatFrame1ButtonFrame. Force
    -- Blizzard's own layout function to reattach that frame after Offhand moves
    -- the message frame into the workspace.
    pcall(function()
        FCF_SetButtonSide(chat, chat.buttonSide or "left", true)
    end)
end

function HUD:AlignHUDFrames(m)
    if aligning or InCombatLockdown() or not Offhand.db.enabled then return end
    aligning = true
    local ok, err = pcall(function()
        m = m or Offhand.Viewport:GetMetrics()
        if not HasBlizzardEditMode() and not HasCustomActionBarAddon() then
            local main = MainMenuBar or MainActionBar

            -- Detect if the action bar is currently centered in the bezel (default Edit Mode behavior for bottom)
            local isBezelCentered = false
            if main and main.GetCenter then
                local cx = main:GetCenter()
                local screenCenter = UIParent:GetWidth() / 2
                if cx and math.abs(cx - screenCenter) < 150 then
                    isBezelCentered = true
                end
            end

            -- If it's in the default Edit Mode position, or it's Classic Era, center it on the game viewport!
            if main and (isBezelCentered or not EditModeManagerFrame) then
                Prepare(main, m)
                Anchor(main, "BOTTOM", m, 0, 0)
            end

            -- For older clients (Classic Era) that don't have Edit Mode, we must manually stack the extra bars
            if not EditModeManagerFrame then
                if MainActionBar and MainActionBar ~= main and (not MainActionBar.IsInDefaultPosition or MainActionBar:IsInDefaultPosition()) then
                    Prepare(MainActionBar, m)
                    Points(MainActionBar, {"BOTTOMLEFT", main, "BOTTOMLEFT", 8, 4})
                end

                local xp = StatusTrackingBarManager or MainMenuExpBar
                Prepare(xp, m)
                if xp and main and (not xp.IsInDefaultPosition or xp:IsInDefaultPosition()) then
                    Points(xp, {"BOTTOM", main, "TOP", 0, -2})
                end

                -- Match Blizzard's compact default stack: the thin XP/reputation
                -- bar sits directly above the main bar, while stance/form buttons
                -- begin above action button 1 on the left. This is a one-pass
                -- legacy default adjustment, not a managed-frame hook: form bars
                -- retain native ownership after the initial layout.
                local stance = StanceBar or ShapeshiftBarFrame
                if stance and main
                    and (not stance.IsInDefaultPosition or stance:IsInDefaultPosition()) then
                    local point, relativeTo, relativePoint, x, y = stance:GetPoint(1)
                    if stance:GetNumPoints() ~= 1 or point ~= "BOTTOMLEFT"
                        or relativeTo ~= main or relativePoint ~= "TOPLEFT"
                        or math.abs((x or 0) - 0) > 0.001
                        or math.abs((y or 0) - 14) > 0.001 then
                        stance:ClearAllPoints()
                        stance:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, 14)
                    end
                end

                local bottomLeft, bottomRight = MultiBarBottomLeft, MultiBarBottomRight
                Prepare(bottomLeft, m)
                Prepare(bottomRight, m)
                if bottomLeft and main and (not bottomLeft.IsInDefaultPosition or bottomLeft:IsInDefaultPosition()) then
                    Points(bottomLeft, {"BOTTOMLEFT", main, "TOPLEFT", 0, 8})
                end
                if bottomRight and main and (not bottomRight.IsInDefaultPosition or bottomRight:IsInDefaultPosition()) then
                    Points(bottomRight, {"BOTTOMLEFT", main, "TOPLEFT", 515, 8})
                end
            end

            -- Right side action bars (Safely dock to the game viewport right edge if they are at the bezel edge)
            local function IsRightBezelAnchored(frame)
                if not frame or not frame.GetCenter then return false end
                local cx = frame:GetCenter()
                local screenCenter = UIParent:GetWidth() / 2

                -- Check if the frame is sitting in the bezel (center of the entire span)
                if cx and math.abs(cx - screenCenter) < 150 then return true end

                -- Also check if it's sitting on the far physical right edge of the screen, BUT the game viewport is on the left
                if cx and m and cx > m.gameRight and cx > (UIParent:GetWidth() - 150) then return true end

                return false
            end

            if MultiBarRight and (IsRightBezelAnchored(MultiBarRight) or not EditModeManagerFrame) then
                Prepare(MultiBarRight, m)
                Anchor(MultiBarRight, "RIGHT", m, -4, 0)
            end

            if MultiBarLeft and (IsRightBezelAnchored(MultiBarLeft) or not EditModeManagerFrame) then
                Prepare(MultiBarLeft, m)
                Anchor(MultiBarLeft, "RIGHT", m, -48, 0)
            end
        end

        for _, item in ipairs({
            {"MinimapCluster", "TOPRIGHT", 0, 0},
            {"PlayerFrame", "TOPLEFT", 16, -16},
            {"TargetFrame", "TOPLEFT", 260, -16},
            {"PartyMemberFrame1", "TOPLEFT", 16, -160},
            {"CompactPartyFrame", "TOPLEFT", 16, -160},
            {"BuffFrame", "TOPRIGHT", -210, -16},
            {"BuffCluster", "TOPRIGHT", -210, -16},
            {"CastingBarFrame", "BOTTOM", 0, 165},
            {"PlayerCastingBarFrame", "BOTTOM", 0, 165},
        }) do
            local frame = _G[item[1]]
            if frame then
                if IsForeverEditModeFrame(frame, item[1]) then
                    -- Forever's saved Edit Mode layout owns these frames. Writing
                    -- their anchors here can taint later Edit Mode/party refreshes.
                elseif item[1] == "MinimapCluster" and HasCustomMinimapAddon() then
                    -- Yield completely to custom minimap addon (e.g. SexyMap, BasicMinimap, ElvUI)
                elseif frame._OffhandDragging then
                    -- Frame is actively being dragged by the player; do not interrupt!
                else
                    Prepare(frame, m)
                    local isWorkspace = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[item[1]]
                    if isWorkspace then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                    else
                        if item[1] == "MinimapCluster" then
                            pcall(function() frame:SetUserPlaced(false) end)
                            Anchor(frame, item[2], m, item[3], item[4], true)
                            if frame.IsShown and not frame:IsShown() and frame.Show then
                                frame:Show()
                            end
                            if frame.SetAlpha then frame:SetAlpha(1) end
                        elseif item[1] == "PartyMemberFrame1" or item[1] == "CompactPartyFrame" then
                            local mainPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[item[1]]
                            local isEditModeCustomized = frame.IsInDefaultPosition and not frame:IsInDefaultPosition()
                            if isEditModeCustomized then
                                -- Yield to Edit Mode
                            elseif mainPos and mainPos.x and mainPos.y then
                                local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                frame:ClearAllPoints()
                                frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", mainPos.x * factor, mainPos.y * factor)
                            elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                                Anchor(frame, item[2], m, item[3], item[4], false)
                            end
                        elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                            Anchor(frame, item[2], m, item[3], item[4], false)
                        end
                    end
                end
            end
        end

        self:AlignChatFrame(m)
        if Offhand.db.seamRedirect then
            for _, item in ipairs({{"UIErrorsFrame", -60}, {"RaidWarningFrame", -100}}) do
                local frame = _G[item[1]]
                Prepare(frame, m)
                if frame then Anchor(frame, "TOP", m, 0, item[2]) end
            end
            self:PositionMainhandTransientFrames(m)
        end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

-- Replay the last committed layout for just the frame Blizzard changed. A timer
-- exposes the reset geometry for several rendered frames even when idle.
-- Cache only layout written by AlignHUDFrames; never replace Blizzard methods or
-- force visibility/action state. The guard prevents our setters from re-entering.
function HUD:RepairFrame(frame)
    if aligning or not Offhand.db or not Offhand.db.enabled then return end
    if IsForeverEditModeFrame(frame) then return end
    if frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if HasCustomActionBarAddon() then return end

    if frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then
        -- Edit Mode marks preset layouts (like "Classic") as non-default.
        -- We must check if it's an action bar sitting in the bezel before yielding!
        local yieldToEditMode = true
        if frame == _G.MainMenuBar or frame == _G.MainActionBar then
            local cx = frame.GetCenter and frame:GetCenter()
            if cx and math.abs(cx - (UIParent:GetWidth() / 2)) < 150 then
                yieldToEditMode = false -- It's sitting in the bezel, let Offhand move it
            end
        elseif frame == _G.MultiBarRight or frame == _G.MultiBarLeft then
            local cx = frame.GetCenter and frame:GetCenter()
            local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
            if cx and (math.abs(cx - UIParent:GetWidth()) < 150 or (m and cx > m.gameRight and cx > (UIParent:GetWidth() - 150))) then
                yieldToEditMode = false -- It's on the far right bezel edge, let Offhand move it
            end
        end

        if yieldToEditMode then return end
    end
    local desired = desiredFrames[frame]
    if not desired then return end
    if InCombatLockdown() then self:RequestLayout(); return end
    aligning = true
    local ok, err = pcall(function()
        if desired.points then Points(frame, unpack(desired.points)) end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

function HUD:IsManagedFrame(frame)
    return desiredFrames[frame] ~= nil
end

-- Repair only the committed native chat anchor before the next rendered frame.
-- Do not run a full HUD layout (or resize chat) from a SetPoint callback.
function HUD:RepairChatAnchor(frame)
    if aligning or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
        or Offhand.db.dockChat == false or HasChattynator() then return end
    if IsRetailChatSettlementActive(frame) then return end
    if frame._OffhandDragging or frame._OffhandApplyingTrackedChatPosition
        or MOVING_CHATFRAME == frame then return end
    local retailManaged = RetailEditModeOwnsPrimaryChat(frame)
    local retailEditModeActive = retailManaged and ((frame and frame.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown
            and EditModeManagerFrame:IsShown()))
    if retailEditModeActive then return end
    if Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions.ChatFrame1 then
        -- Blizzard restores the primary chat anchor late during cold login on
        -- both legacy and Forever clients. The SetPoint hook runs inside that
        -- write, so reanchoring synchronously risks recursion. Reassert the
        -- explicit Offhand placement on the next frame and coalesce bursts of
        -- native layout writes into one repair.
        if self.chatWorkspaceRepairPending or not C_Timer or not C_Timer.After then return end
        self.chatWorkspaceRepairPending = true
        C_Timer.After(0, function()
            self.chatWorkspaceRepairPending = nil
            if aligning or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
                or Offhand.db.dockChat == false or HasChattynator()
                or IsRetailChatSettlementActive(frame)
                or frame._OffhandDragging or MOVING_CHATFRAME == frame
                or (RetailEditModeOwnsPrimaryChat(frame)
                    and ((frame and frame.isInEditMode == true)
                        or (EditModeManagerFrame and EditModeManagerFrame.IsShown
                            and EditModeManagerFrame:IsShown())))
                or not (Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions.ChatFrame1) then return end
            if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                aligning = true
                local ok, err = pcall(Offhand.Canvas.RestoreWorkspacePosition, Offhand.Canvas, frame)
                aligning = false
                if not ok then Offhand:Print("Chat workspace repair error: %s", tostring(err)) end
            end
        end)
        return
    end
    if retailManaged then return end
    if frame.Selection and frame.IsEditModeDragging and frame:IsEditModeDragging() then return end
    if frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    local desired = desiredFrames[frame]
    if not desired or not desired.points then return end
    aligning = true
    local ok, err = pcall(Points, frame, unpack(desired.points))
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end


function HUD:IsRetailEditModePrimaryChat(frame)
    return RetailEditModeOwnsPrimaryChat(frame)
end

function HUD:HookFrames()
    self:HookMainhandTransientFrames()
    if UsesForeverEditMode() then
        -- Seed the hidden frame as soon as it exists, then repair synchronously
        -- after every native toggle in case Blizzard rebuilt its stock anchor.
        PositionForeverGameMenu()
        if hooksecurefunc and ToggleGameMenu and not self.foreverGameMenuHooked then
            self.foreverGameMenuHooked = true
            hooksecurefunc("ToggleGameMenu", function()
                PositionForeverGameMenu()
            end)
        end
    end
    if not HasBlizzardEditMode() and not HasCustomActionBarAddon() then
        if not self.managerHooked and UIParent_ManageFramePositions then
            self.managerHooked = true
            hooksecurefunc("UIParent_ManageFramePositions", function()
                if InCombatLockdown() then return end
                for _, name in ipairs(actionNames) do
                    local frame = _G[name]
                    if frame then HUD:RepairFrame(frame) end
                end
                HUD:RequestLayout()
            end)
        end
        for _, name in ipairs(actionNames) do
            local frame = _G[name]
            if frame and not hooks[frame] then
                hooks[frame] = true
                hooksecurefunc(frame, "SetPoint", function() HUD:RepairFrame(frame) end)
            end
        end
    end
    for _, name in ipairs({"PlayerFrame", "TargetFrame", "PartyMemberFrame1", "CompactPartyFrame", "ChatFrame1",
        "BuffFrame", "UIErrorsFrame", "RaidWarningFrame"}) do
        local frame = _G[name]
        if frame and not IsForeverEditModeFrame(frame, name) and not hooks[frame] then
            hooks[frame] = true
            hooksecurefunc(frame, "SetPoint", function()
                if frame._OffhandDragging or MOVING_CHATFRAME == frame then return end
                if frame == ChatFrame1 then HUD:RepairChatAnchor(frame); return end
                local isWs = Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not isWs and not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                    HUD:RequestLayout()
                end
            end)
        end
    end

    -- Center ordinary menus and settings panels on Mainhand. Edit Mode and its
    -- system dialogs stay entirely Blizzard-owned on every client.
    local menuFrameNames = {
        "GameMenuFrame", "SettingsPanel", "InterfaceOptionsFrame", "VideoOptionsFrame",
        "AddonList", "KeyBindingFrame", "HelpFrame",
        "BugSackFrame", "RedIsFriendFrame",
    }
    local function PrepareForeverEditModeManager()
        -- Forever's Edit Mode manager is part of a secure/secret-value path.
        -- Leave its panel metadata, attributes, scripts and anchors entirely native.
        return
    end

    local function PositionEditMode()
        -- Non-Forever Edit Mode positioning remains disabled. Repeatedly moving the
        -- manager or its dialogs from OnShow taints CompactUnitFrame on some clients.
    end

    local function CenterGameMenu()
        if UsesForeverEditMode() then return end
        PositionEditMode()
        for _, name in ipairs(menuFrameNames) do
            local frame = _G[name]
            if frame and frame:IsShown() and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                local m = Offhand.Viewport:GetMetrics()
                frame:ClearAllPoints()
                local cx = (m.gameLeft + m.gameRight) / 2
                local cy = (m.gameBottom + m.gameTop) / 2
                local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                local offsetX = cx - (UIParent:GetWidth() / 2)
                local offsetY = cy - (UIParent:GetHeight() / 2)
                frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
            end
        end
    end

    local function HookMenuFrame(name)
        if UsesForeverEditMode() then return end
        local frame = _G[name]
        if frame and not hooks[frame] then
            hooks[frame] = true
            if SetUIPanelAttribute then
                pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
            end
            frame:HookScript("OnShow", function(self)
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
            end)
            if name == "AddonList" and UISpecialFrames then
                local found = false
                for _, sName in ipairs(UISpecialFrames) do
                    if sName == "AddonList" then found = true; break end
                end
                if not found then table.insert(UISpecialFrames, "AddonList") end
            end
        end
    end

    if not UsesForeverEditMode() and UIPanelWindows then
        for _, name in ipairs(menuFrameNames) do
            if UIPanelWindows[name] then
                UIPanelWindows[name].area = nil
                UIPanelWindows[name].centerFrameSkipAnchoring = true
            end
        end
    end

    for _, name in ipairs(menuFrameNames) do
        HookMenuFrame(name)
    end

    local function PatchEditModeUtil()
        -- Disabled: Overriding EditModeUtil causes taint in CompactUnitFrame (e.g. party/raid frames)
        -- We no longer attempt to patch GetBottomActionBarHeight.
    end

    local function CheckEditModeHooks()
        PatchEditModeUtil()
        if UsesForeverEditMode() then
            PrepareForeverEditModeManager()
            -- Do not attach addon script handlers to Forever's Edit Mode manager.
            -- Its layout and close/reset path remain Blizzard-owned after the
            -- one-time panel-manager preparation above.
            return
        end
        -- Non-Forever clients also own the manager, dialogs, and managed
        -- systems. Do not attach even a no-op OnShow hook: new Blizzard builds
        -- initialize the Damage Meter from the same secure Edit Mode traversal.
    end
    CheckEditModeHooks()

    -- Universal Void Rescue & Popup Redirection Engine
    -- Rescues frames anchoring into the unrendered black space above the 3D Game Viewport,
    -- and redirects popups that anchor to the bezel seam center.
    local function RedirectExternalPopups()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        -- Forever's native gamepad navigator owns the structure and focus of
        -- visible windows. The broad rescue pass must not enumerate and
        -- re-anchor those roots while SmartNavigation is rebuilding them.
        if UsesNativeGamepadInterface() then return end
        
        local m = Offhand.Viewport:GetMetrics()
        if not m or not m.isSpanned then return end
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        local parentScale = UIParent:GetEffectiveScale() or 1

        local function CenterIsInside(left, top, width, height, areaLeft, areaBottom, areaRight, areaTop)
            if not left or not top or not width or not height
                or areaLeft == nil or areaBottom == nil or areaRight == nil or areaTop == nil then
                return false
            end
            local centerX = left + width / 2
            local centerY = top - height / 2
            return centerX >= areaLeft and centerX <= areaRight
                and centerY >= areaBottom and centerY <= areaTop
        end

        -- 1. Check UISpecialFrames (standard config panels)
        if UISpecialFrames then
            for _, name in ipairs(UISpecialFrames) do
                local frame = _G[name]
                if frame and type(frame) == "table" and frame.GetPoint
                    and not IsBlizzardEditModeOwnedFrame(frame, name)
                    and not hooks[frame] and frame.IsProtected and not frame:IsProtected() then
                    hooks[frame] = true
                    frame:HookScript("OnShow", function(self)
                        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                        local pt, rel = self:GetPoint(1)
                        if (rel == UIParent or rel == nil) and (pt == "CENTER") then
                            self:ClearAllPoints()
                            local factor = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            self:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                        end
                    end)
                end
            end
        end

        -- 2. Void Rescue: Detect any frame on the game monitor side whose top extends into the black void above m.gameTop
        local voidTargets = {
        }
        for _, frame in ipairs(voidTargets) do
            if frame and type(frame) == "table" then
                pcall(function()
                    if frame.IsForbidden and frame:IsForbidden() then return end
                    if frame.IsProtected and frame:IsProtected() then return end
                    if not frame.IsShown or not frame:IsShown() then return end
                    local fScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (frame:GetTop() or 0) * scaleFactor
                    local left = (frame:GetLeft() or 0) * scaleFactor
                    local width = (frame.GetWidth and frame:GetWidth() or 0) * scaleFactor
                    local height = (frame.GetHeight and frame:GetHeight() or 0) * scaleFactor
                    local centerX = left + width / 2
                    local onGameSide = centerX >= m.gameLeft and centerX <= m.gameRight
                    local onWorkspace = CenterIsInside(left, top, width, height,
                        m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
                    if onGameSide and not onWorkspace and top > (m.gameTop + 2) then
                        frame:ClearAllPoints()
                        local invFactor = parentScale / fScale
                        local offsetX = cx - (UIParent:GetWidth() / 2)
                        local offsetY = cy - (UIParent:GetHeight() / 2)
                        frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                    end
                end)
            end
        end

        -- 3. Scan active children of UIParent for rogue centered popup frames or frames in the void
        for _, child in ipairs({UIParent:GetChildren()}) do
            if type(child) == "table" and child ~= WorldFrame and child ~= Offhand.canvas then
                pcall(function()
                    if child.IsForbidden and child:IsForbidden() then return end
                    if not child.IsShown or not child:IsShown() then return end
                    if child.IsProtected and child:IsProtected() then return end

                    local cName
                    if child.GetName then
                        local okName, name = pcall(child.GetName, child)
                        if okName then cName = name end
                    end
                    if cName == "OffhandCanvasFrame" or cName == "OffhandSeamGuideLine" then return end
                    if IsBlizzardEditModeOwnedFrame(child, cName)
                        or IsForeverEditModeFrame(child, cName) then return end
                    -- Native chat owns these linked frames. Moving a dock or tab
                    -- independently separates the headers from the message window.
                    if child == GeneralDockManager or child == GENERAL_CHAT_DOCK
                        or (cName and cName:match("^ChatFrame%d")) then return end

                    -- Void Rescue check for general children on the game side
                    local fScale = (child.GetEffectiveScale and child:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (child.GetTop and child:GetTop() or 0) * scaleFactor
                    local left = (child.GetLeft and child:GetLeft() or 0) * scaleFactor
                    local width = (child.GetWidth and child:GetWidth() or 0) * scaleFactor
                    local height = (child.GetHeight and child:GetHeight() or 0) * scaleFactor
                    local centerX = left + width / 2
                    local onGameSide = centerX >= m.gameLeft and centerX <= m.gameRight
                    local onWorkspace = CenterIsInside(left, top, width, height,
                        m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
                    if onGameSide and not onWorkspace and top > (m.gameTop + 2) then
                        if child.GetPoint and child.ClearAllPoints and child.SetPoint then
                            child:ClearAllPoints()
                            local invFactor = parentScale / fScale
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            child:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                        end
                    end

                    -- Seam centering check
                    if child.GetNumPoints and child:GetNumPoints() == 1 then
                        local pt, rel, relPt, x, y = child:GetPoint(1)
                        if (rel == UIParent or rel == nil) and pt == "CENTER" and relPt == "CENTER" then
                            if (x or 0) == 0 and (y or 0) == 0 then
                                if child.ClearAllPoints and child.SetPoint then
                                    child:ClearAllPoints()
                                    local factor = UIParent:GetEffectiveScale() / child:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    child:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    -- The general scanner is intentionally broad and slow. Blizzard Edit Mode
    -- recovery gets a separate cheap cadence so its entry prompt and native
    -- transactional dialogs become usable in well under a second on every
    -- supported client.
    if HasBlizzardEditMode() and C_Timer and C_Timer.NewTicker
        and not self.foreverEditModeRecoveryTicker then
        self.foreverEditModeRecoveryTicker = C_Timer.NewTicker(0.25, function()
            HUD:UpdateForeverEditModeControlsRecovery()
        end)
    end

    if C_Timer and C_Timer.NewTicker and not self.popupTicker then
        self.popupTicker = C_Timer.NewTicker(2, function()
            RedirectExternalPopups()
            HUD:HookMainhandTransientFrames()
            HUD:PositionMainhandTransientFrames()
            CheckEditModeHooks()
            HUD:UpdateForeverEditModeControlsRecovery()
            HUD:UpdateForeverPartyFrameRecovery()
        end)
    end

    local function AutoLoadEditModeLayout()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        if UsesControllerInterface() then return end
        if not C_EditMode or not C_EditMode.GetLayouts then return end
        
        local layoutData = C_EditMode.GetLayouts()
        if not layoutData or not layoutData.layouts then return end

        local forever = UsesForeverEditMode()
        if forever then
            local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                and Offhand.Viewport:GetMetrics() or nil
            PrepareForeverEditModeState(layoutData, metrics)
        end
        local activeName = not forever and GetActiveEditModeLayoutName() or nil
        local targetName = forever
            and (type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeLayoutName or nil)
            or (type(OffhandCharDB) == "table" and OffhandCharDB.editModeLayoutName or nil)
        if not forever and (type(targetName) ~= "string" or not targetName:match("%S")) then
            -- Upgrade behavior: adopt the layout Blizzard already selected for
            -- this character. Do not replace it merely because a layout named
            -- "Offhand" also exists on the account.
            targetName = activeName
            RememberCharacterEditModeLayout()
        end

        local found = false
        local needsSetup = false
        for index, layout in ipairs(layoutData.layouts) do
            if targetName and EditModeLayoutNamesMatch(layout.layoutName, targetName) then
                found = true
                if forever then
                    -- A newly copied/renamed layout can still contain Blizzard's
                    -- full-canvas default for Action Bar 1. Selecting it would
                    -- appear to move the bar away from the Mainhand viewport.
                    -- Require the player to position the main bar once in Edit
                    -- Mode; this keeps all protected writes inside Blizzard UI.
                    needsSetup = true
                    local actionBarSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
                    local mainBarIndex = Enum and Enum.EditModeActionBarSystemIndices and Enum.EditModeActionBarSystemIndices.MainBar
                    for _, systemInfo in ipairs(layout.systems or {}) do
                        if systemInfo.system == actionBarSystem and systemInfo.systemIndex == mainBarIndex then
                            needsSetup = systemInfo.isInDefaultPosition ~= false
                            break
                        end
                    end
                end
                if not needsSetup and not forever
                    and not EditModeLayoutNamesMatch(activeName, targetName)
                    and C_EditMode.SetActiveLayout then
                    -- GetLayouts().layouts contains only custom entries, while
                    -- SetActiveLayout consumes the global identifier after the
                    -- built-in preset rows. Passing the bare array index can
                    -- silently select Modern/Classic while appearing successful.
                    local targetID = GetEditModeCustomLayoutOffset(layoutData, activeName) + index
                    local ok, result = pcall(C_EditMode.SetActiveLayout, targetID)
                    local confirmed = GetEditModeLayouts()
                    if ok and result ~= false and confirmed
                        and tonumber(confirmed.activeLayout) == targetID then
                        Offhand:Print("Auto-loaded Edit Mode layout: " .. layout.layoutName)
                    end
                end
                break
            end
        end

        if not forever and not found and activeName and type(OffhandCharDB) == "table" then
            -- The remembered layout was renamed or deleted. The currently
            -- active Blizzard choice is the safest replacement; never select
            -- an unrelated layout that inherited the old numeric slot.
            OffhandCharDB.editModeLayoutName = activeName
        end

        local designatedActive = false
        if forever and targetName and found then
            local status = self:GetForeverEditModeLayoutStatus()
            designatedActive = status and status.activeMatches or false
        end
        local needsGuidance = forever
            and (not targetName or not found or (needsSetup and not designatedActive))
            or (Offhand.isRetail and not activeName)
        if needsGuidance and not self.editModeGuidanceShown then
            self.editModeGuidanceShown = true
            local messageKey = HasEllesmerePartyFrames()
                and "COMPAT_ELLESMERE_PARTY" or (UsesForeverEditMode() and "EDIT_MODE_LAYOUT_MISSING" or "EDIT_MODE_LAYOUT_MISSING_RETAIL")
            Offhand:Print((Offhand.L and Offhand.L[messageKey]) or (Offhand.L and Offhand.L["EDIT_MODE_LAYOUT_MISSING"]))
        end
    end

    local function UpdateUIPanelOffsets()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        if HasBlizzardEditMode() then
            -- Forever dispatches UIParent attribute changes through its secure
            -- panel manager and reads layout offsets from UIPanelLayoutFrame.
            -- Avoid this legacy attribute path entirely on that client.
            return
        end
        local m = Offhand.Viewport:GetMetrics()
        if m and m.isSpanned and UIParent.SetAttribute then
            -- Default blizzard panels to the Game World monitor, but add standard 16px left padding
            -- and preserve Blizzard's native -104px top padding (so they don't jam into the absolute corner)
            local left = (m.gameLeft or 0) + 16
            UIParent:SetAttribute("LEFT_OFFSET", left)
            
            local topDelta = (UIParent:GetHeight() or 0) - (m.gameTop or 0)
            UIParent:SetAttribute("TOP_OFFSET", -104 - (topDelta > 0 and topDelta or 0))
        end
    end

    UpdateUIPanelOffsets()
    HookCharacterEditModeSelection()
    if not Offhand.db or not Offhand.db.enabled then
        self.editModeLoadScheduled = nil
    elseif not self.editModeLoadScheduled then
        self.editModeLoadScheduled = true
        C_Timer.After(3, AutoLoadEditModeLayout)
    end

    if not UsesForeverEditMode() and not self.menuHooksInstalled then
        self.menuHooksInstalled = true
        if ToggleGameMenu then
            hooksecurefunc("ToggleGameMenu", function()
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
                C_Timer.After(0.05, CenterGameMenu)
            end)
        end
        if CreateFrame then
            local editModeLoader = CreateFrame("Frame")
            if editModeLoader and editModeLoader.RegisterEvent and editModeLoader.SetScript then
                editModeLoader:RegisterEvent("ADDON_LOADED")
                editModeLoader:SetScript("OnEvent", function(_, _, addonName)
                    if addonName == "Blizzard_EditMode" or addonName == "Blizzard_Settings" then
                        CheckEditModeHooks()
                        HookCharacterEditModeSelection()
                        for _, name in ipairs(menuFrameNames) do HookMenuFrame(name) end
                    end
                end)
            end
        end
        if ShowUIPanel then
            hooksecurefunc("ShowUIPanel", function(frame)
                if frame and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                    local name = frame.GetName and frame:GetName()
                    if name then
                        if IsBlizzardEditModeOwnedFrame(frame, name)
                            or IsForeverEditModeFrame(frame, name) then return end
                        local isMenu = false
                        for _, n in ipairs(menuFrameNames) do
                            if n == name then isMenu = true; break end
                        end
                        
                        local info = UIPanelWindows and UIPanelWindows[name]
                        if isMenu or (info and info.area == "center") then
                            local function DoCenter()
                                if frame:IsShown() and not InCombatLockdown() then
                                    local m = Offhand.Viewport:GetMetrics()
                                    frame:ClearAllPoints()
                                    local cx = (m.gameLeft + m.gameRight) / 2
                                    local cy = (m.gameBottom + m.gameTop) / 2
                                    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                            DoCenter()
                            C_Timer.After(0, DoCenter)
                        end
                    end
                end
            end)
        end
        if UpdateUIPanelPositions then
            hooksecurefunc("UpdateUIPanelPositions", function()
                UpdateUIPanelOffsets()
            end)
        end
    end

    -- Keep bags on regular monitor unless user explicitly dragged them to workspace
    local isArrangingBags = false
    function HUD:LayoutBags()
        if Offhand.isForever or HasCustomBagAddon() or isArrangingBags
            or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        isArrangingBags = true

        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not m then
            isArrangingBags = false
            return
        end

        local deckMinX = m.workspaceLeft + 12
        local deckMaxX = m.workspaceRight - 12
        local deckMinY = m.workspaceBottom + 12
        local deckMaxY = math.max(deckMinY, m.workspaceTop - 30)

        local visibleBackpack = ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown()
            and ContainerFrameCombinedBags
            or (ContainerFrame1 and ContainerFrame1:IsShown() and ContainerFrame1 or nil)
        if visibleBackpack and Offhand.Canvas and Offhand.Canvas.PrepareNativeBackpackFrame then
            Offhand.Canvas:PrepareNativeBackpackFrame(visibleBackpack)
        end

        -- Determine if bags are stationed on the workspace
        local bpPos = Offhand.Canvas and Offhand.Canvas.GetNativeBackpackWorkspacePosition
            and Offhand.Canvas:GetNativeBackpackWorkspacePosition() or (Offhand.db.savedWorkspacePositions and (
            Offhand.db.savedWorkspacePositions["ContainerFrame1"] or 
            Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
        ))
        local bagsOnWorkspace = false
        if bpPos and bpPos.x and bpPos.y then
            bagsOnWorkspace = true
        end

        local bagSpacing = 4
        local defaultBagWidth = 192
        local defaultBagHeight = 250

        if bagsOnWorkspace and bpPos then
            -- Layout on workspace: dock unpositioned bags relative to the backpack on the workspace
            local expandRight = (bpPos.x + (defaultBagWidth + bagSpacing) * 3 <= deckMaxX)
            local currentX = bpPos.x
            local currentY = bpPos.y
            local stackBagCount = 0

            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() then
                    local name = frame:GetName()
                    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if pos and pos.x and pos.y then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                        if frame.SetAlpha then frame:SetAlpha(1) end
                    else
                        local w = frame:GetWidth() or defaultBagWidth
                        local h = frame:GetHeight() or defaultBagHeight
                        local targetX, targetY

                        targetX = currentX
                        targetY = currentY + (h + bagSpacing) * (stackBagCount + 1)
                        if targetY + h > deckMaxY then
                            if expandRight then
                                currentX = currentX + w + bagSpacing
                            else
                                currentX = currentX - w - bagSpacing
                            end
                            stackBagCount = 0
                            targetX = currentX
                            targetY = currentY + (h + bagSpacing) * (stackBagCount + 1)
                        end

                        targetX = math.max(deckMinX, math.min(targetX, deckMaxX - w))
                        targetY = math.max(deckMinY, math.min(targetY, deckMaxY - h))

                        if name and not string.match(name, "^ContainerFrame") then
                            frame:SetUserPlaced(true)
                        end
                        frame:ClearAllPoints()
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        -- Offset X by width so BOTTOMRIGHT anchor acts identically to old TOPLEFT
                        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", (targetX + w) * factor, (targetY - h) * factor)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        stackBagCount = stackBagCount + 1
                    end
                end
            end
            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
                if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                    Offhand.Canvas.RestoreWorkspacePosition(ContainerFrameCombinedBags)
                end
                if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
            end
        else
            -- Standard game view bag layout: Custom collision detection to wrap around action bars
            local right = m.gameRight - 16
            local bottom = m.gameBottom + 32
            
            local function DodgeFrame(f)
                if type(f) == "string" then f = _G[f] end
                if not f or not f.IsShown or not f:IsShown() then return end
                local factor = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / UIParent:GetEffectiveScale()
                local fl = (f:GetLeft() or 0) * factor
                local fr = (f:GetRight() or 0) * factor
                local ft = (f:GetTop() or 0) * factor
                local fb = (f:GetBottom() or 0) * factor
                if fr == 0 and fb == 0 then return end
                                
                -- If it's a vertical bar on the right edge, push bags left
                if fr >= m.gameRight - 200 and fb < m.gameBottom + 500 then
                    if (ft - fb) > (fr - fl) * 1.5 then
                        right = math.min(right, fl - 16)
                    end
                end
                
                -- If it's a horizontal bar in the bottom right quadrant, push bags up
                if fr >= m.gameRight - 400 and fb <= m.gameBottom + 200 then
                      if (fr - fl) > (ft - fb) * 1.5 then
                          bottom = math.max(bottom, ft + 16)
                      end
                  end
            end
            
                        DodgeFrame("MultiBarRight")
                        DodgeFrame("MultiBarLeft")
            DodgeFrame("MultiBar5")
            DodgeFrame("MultiBar6")
            DodgeFrame("MultiBar7")
            DodgeFrame("MicroButtonAndBagsBar")
            DodgeFrame("MicroMenuContainer")
            DodgeFrame("BagsBar")
            DodgeFrame("MainMenuBar")
            DodgeFrame("StanceBar")
            DodgeFrame("PetActionBar")
                        local curColRight = right
            local curColY = bottom
            local nextColRight = right
            
            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame.IsShown and frame:IsShown() then
                    local name = frame.GetName and frame:GetName()
                    local pos = name and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if pos and pos.x and pos.y then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                        if frame.SetAlpha then frame:SetAlpha(1) end
                    else
                        pcall(function() frame:SetUserPlaced(false) end)
                        frame:ClearAllPoints()
                        local rawW = frame:GetWidth() or defaultBagWidth
                        local rawH = frame:GetHeight() or defaultBagHeight
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        
                        -- Convert physical dimensions to UIParent scale for stacking
                        local uiW = rawW / factor
                        local uiH = rawH / factor
                        
                        -- If adding this bag pushes us above the top of the GAME view monitor (not the spanned void)
                        if curColY + uiH > m.gameTop - 32 then
                            curColRight = nextColRight - bagSpacing
                            curColY = bottom
                        end
                        
                        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", curColRight * factor, curColY * factor)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        
                        curColY = curColY + uiH + bagSpacing
                        nextColRight = math.min(nextColRight, curColRight - uiW)
                    end
                end
            end

            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
                local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
                if pos and pos.x and pos.y then
                    if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                        Offhand.Canvas.RestoreWorkspacePosition(ContainerFrameCombinedBags)
                    end
                    if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
                else
                    ContainerFrameCombinedBags:SetUserPlaced(false)
                    ContainerFrameCombinedBags:ClearAllPoints()
                    local factor = UIParent:GetEffectiveScale() / ContainerFrameCombinedBags:GetEffectiveScale()
                    ContainerFrameCombinedBags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right * factor, bottom * factor)
                    if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
                end
            end
        end

        isArrangingBags = false
    end

    -- Legacy clients use the custom bag anchor pass to avoid anchor-family
    -- cycles. Forever keeps Blizzard's function identity to preserve taint safety.
    if _G.UpdateContainerFrameAnchors and not self.anchorsHooked and not UsesForeverEditMode() and not HasBlizzardEditMode() then
        self.anchorsHooked = true
        HUD.origUpdateContainerFrameAnchors = _G.UpdateContainerFrameAnchors
        _G.UpdateContainerFrameAnchors = function(...)
            if HasCustomBagAddon() or not Offhand.db or not Offhand.db.enabled then
                return HUD.origUpdateContainerFrameAnchors(...)
            end
            HUD:LayoutBags()
        end
    end

    -- Forever's native bag frames are protected item-action ancestors. Even an
    -- OnShow observer or a post-toggle layout hook can attribute later
    -- UseContainerItem calls to Offhand, so that client gets no native-bag
    -- hooks at all. Custom bag-addon roots are handled by their own adapters.
    if not Offhand.isForever then
    -- Pre-hook bag OnShow to suppress flicker by setting alpha 0 before positioning
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            frame:HookScript("OnShow", function(self)
                if HasCustomBagAddon() then return end
                if self:GetName() == "ContainerFrame1" and Offhand.Canvas
                    and Offhand.Canvas.PrepareNativeBackpackFrame then
                    Offhand.Canvas:PrepareNativeBackpackFrame(self)
                end
                local name = self:GetName()
                local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not pos then
                    if self.SetAlpha then self:SetAlpha(0) end
                end
                HUD:LayoutBags()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if not HasCustomBagAddon() then
                            HUD:LayoutBags()
                        end
                    end)
                end
            end)
        end
    end
    if ContainerFrameCombinedBags and not hooks[ContainerFrameCombinedBags] then
        hooks[ContainerFrameCombinedBags] = true
        ContainerFrameCombinedBags:HookScript("OnShow", function(self)
            if HasCustomBagAddon() then return end
            if Offhand.Canvas and Offhand.Canvas.PrepareNativeBackpackFrame then
                Offhand.Canvas:PrepareNativeBackpackFrame(self)
            end
            local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
            if not pos then
                if self.SetAlpha then self:SetAlpha(0) end
            end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end)
    end

    if not self.bagHooksInstalled then
        self.bagHooksInstalled = true
        local function TriggerBagLayout()
            if HasCustomBagAddon() then return end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end
        if ContainerFrame_GenerateFrame then
            hooksecurefunc("ContainerFrame_GenerateFrame", TriggerBagLayout)
        end
        if ToggleBag then
            hooksecurefunc("ToggleBag", TriggerBagLayout)
        end
        if ToggleAllBags then
            hooksecurefunc("ToggleAllBags", TriggerBagLayout)
        end
        if OpenAllBags then
            hooksecurefunc("OpenAllBags", TriggerBagLayout)
        end
        if OpenBag then
            hooksecurefunc("OpenBag", TriggerBagLayout)
        end
        if CloseBag then
            hooksecurefunc("CloseBag", TriggerBagLayout)
        end
        if CloseAllBags then
            hooksecurefunc("CloseAllBags", TriggerBagLayout)
        end
    end
    end
    for i = 1, 4 do
        local frame = _G["StaticPopup" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            local index = i
            frame:HookScript("OnShow", function(self)
                if InCombatLockdown() or not Offhand.db.enabled or not Offhand.db.seamRedirect then return end
                local m = Offhand.Viewport:GetMetrics()
                Prepare(self, m)
                NormalizeMainhandTransientScale(self)
                Anchor(self, "CENTER", m, 0, (index - 1) * 120)
                if C_Timer and C_Timer.After then
                    for _, delay in ipairs({0, 0.05, 0.2}) do
                        C_Timer.After(delay, function() HUD:PositionMainhandTransientFrames() end)
                    end
                end
            end)
        end
    end
end

function HUD:GatherLostFrames()
    return Offhand:GatherOffScreenUI()
end

function Offhand:InitializeSeamRedirect()
    HUD:HookFrames()
end
function Offhand:UpdateSeamRedirect()
    HUD:HookFrames()
    HUD:AlignHUDFrames()
end





