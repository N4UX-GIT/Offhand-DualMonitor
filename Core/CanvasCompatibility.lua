--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasCompatibility.lua: External frame ownership detection for Canvas
--]]

local _, Offhand = ...

local Compatibility = {}
Offhand.CanvasCompatibility = Compatibility

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
    PetFrame = true,
    BossTargetFrameContainer = true,
    PartyFrame = true,
    PartyMemberFrame1 = true,
    CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    BuffFrame = true,
    BuffCluster = true,
    CastingBarFrame = true,
    PlayerCastingBarFrame = true,
    ExtraAbilityContainer = true,
    ExtraActionBarFrame = true,
    ZoneAbilityFrame = true,
    EncounterBar = true,
    UIWidgetPowerBarContainerFrame = true,
    LossOfControlFrame = true,
    MainMenuBarVehicleLeaveButton = true,
    VehicleExitButton = true,
    TotemFrame = true,
    MultiCastActionBarFrame = true,
    PersonalResourceDisplayFrame = true,
    DurabilityFrame = true,
    DamageMeter = true,
    UIErrorsFrame = true,
    RaidWarningFrame = true,
    EssentialCooldownViewer = true,
    UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true,
    BottomManagedFrameContainer = true,
}

function Compatibility.IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

function Compatibility.HasLeatrixMaps()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Maps")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Maps")
    end
    return false
end

-- MoveAny registers and manages WorldMapFrame on every supported modern client.
-- Canvas must leave scale, anchor, persistence, drag, and post-toggle behavior
-- to a single owner while retaining dormant Offhand coordinates.
function Compatibility.HasMoveAny()
    return _G.MoveAny ~= nil or _G.MoveAnything ~= nil
        or Compatibility.IsAddonLoaded("MoveAny")
        or Compatibility.IsAddonLoaded("MoveAnything")
end

function Compatibility.HasClassicUIForever()
    return Compatibility.IsAddonLoaded("ClassicUIForever")
end

-- ClassicUI Forever has its own persistent movement for these native frames.
-- The addon name is independent of Offhand.isForever, which identifies a
-- client family rather than a frame owner.
function Compatibility.ShouldYieldFrameToClassicUIForever(frameOrName, suppliedName)
    if not Compatibility.HasClassicUIForever() then return false end
    local name = suppliedName
        or (type(frameOrName) == "string" and frameOrName)
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    return name == "WorldMapFrame" or name == "CharacterFrame"
end

function Compatibility.GetWorldMapExternalOwner()
    if Compatibility.HasMoveAny() then return "MoveAny" end
    if Compatibility.HasClassicUIForever() then return "ClassicUIForever" end
    -- OpenMap restores its private anchor and scale after native writes. Keep
    -- it ahead of Leatrix so diagnostics identify the active geometry owner
    -- when both addons are loaded.
    if Compatibility.IsAddonLoaded("OpenMap") then return "OpenMap" end
    if Compatibility.HasLeatrixMaps() then return "LeatrixMaps" end
    return nil
end

function Compatibility.IsExternallyPositionedWorldMap(frameOrName)
    local owner = Compatibility.GetWorldMapExternalOwner()
    if owner ~= "LeatrixMaps" and owner ~= "OpenMap" then return false end
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName == _G.WorldMapFrame
end

function Compatibility.ShouldYieldWorldMap(frameOrName)
    if not Compatibility.GetWorldMapExternalOwner() then return false end
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName == _G.WorldMapFrame
end

function Compatibility.GetTBCSpellbookDiagnostics()
    local toc = tonumber(Offhand.tocVersion) or 0
    if Offhand.isForever or toc < 20500 or toc >= 20600 then return "" end
    if InCombatLockdown and InCombatLockdown() then return " | Spellbook=combat-deferred" end
    local frame = _G.SpellBookFrame
    if not frame then return " | Spellbook=absent" end
    local ok, report = pcall(function()
        if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
        local function Read(method)
            if type(frame[method]) ~= "function" then return "unknown" end
            local read, value = pcall(frame[method], frame)
            return read and tostring(value) or "unresolved"
        end
        local registration = UIPanelWindows and UIPanelWindows.SpellBookFrame
        local area = "unknown"
        if type(frame.GetAttribute) == "function" then
            local read, value = pcall(frame.GetAttribute, frame, "UIPanelLayout-area")
            if read then area = tostring(value) end
        end
        local db = Offhand.db or {}
        return string.format("shown=%s,visible=%s,protected=%s,alpha=%s,rect=%s/%s/%s/%s,scale=%s,points=%s,registered=%s,area=%s,saved=%s",
            Read("IsShown"), Read("IsVisible"), Read("IsProtected"), Read("GetEffectiveAlpha"),
            Read("GetLeft"), Read("GetBottom"), Read("GetWidth"), Read("GetHeight"),
            Read("GetEffectiveScale"), Read("GetNumPoints"), tostring(registration ~= nil), area,
            db.savedWorkspacePositions and db.savedWorkspacePositions.SpellBookFrame and "workspace"
                or (db.savedMainPositions and db.savedMainPositions.SpellBookFrame and "mainhand" or "none"))
    end)
    return " | Spellbook=" .. (ok and report or "unresolved")
end

function Compatibility.GetDiagnostics(compact, coordinateFontRefreshCount)
    local mapOwner = Compatibility.GetWorldMapExternalOwner() or "Offhand"
    if compact then
        return string.format("WorldMapOwner=%s | LeatrixMaps=%s | OpenMap=%s",
            mapOwner, Compatibility.HasLeatrixMaps() and "loaded" or "absent",
            Compatibility.IsAddonLoaded("OpenMap") and "loaded" or "absent")
    end
    local leatrixStatus = Compatibility.HasLeatrixMaps() and string.format(
        " | LeatrixMaps=loaded | CoordinateFontRefresh=%s",
        tostring(coordinateFontRefreshCount or "pending")) or ""
    local spellbookStatus = Compatibility.GetTBCSpellbookDiagnostics()
    local bagStatus = ""
    if Offhand.CanvasPanelRegistry and Offhand.CanvasPanelRegistry.IsTBCPanelRuntime() then
        local snapshot = Offhand.db and Offhand.db.tbcWorkspaceBagSnapshot
        local ids = {}
        if type(snapshot) == "table" and snapshot.schema == 1 and type(snapshot.open) == "table" then
            for id = 0, 4 do if snapshot.open[tostring(id)] then ids[#ids+1] = tostring(id) end end
        end
        bagStatus = " | TBCBags=" .. (type(snapshot) == "table" and snapshot.schema == 1 and "v1:" or "legacy:")
            .. (#ids > 0 and table.concat(ids, ",") or "none") .. ","
            .. tostring(Offhand.Canvas and Offhand.Canvas.tbcBagIDRestoreStatus or "idle")
            .. ",capture=" .. tostring(Offhand.Canvas and Offhand.Canvas.tbcBagCaptureStatus or "idle")
    end
    if Compatibility.HasClassicUIForever() then
        return string.format(
            "MoveAny=%s | ClassicUIForever=loaded | WorldMapOwner=%s | CharacterFrameOwner=ClassicUIForever",
            Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner) .. leatrixStatus .. spellbookStatus .. bagStatus
    end
    return string.format("MoveAny=%s | WorldMapOwner=%s",
        Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner) .. leatrixStatus .. spellbookStatus .. bagStatus
end

function Compatibility.IsForeverProfessionsPanel(frame, suppliedName)
    if not Offhand.isForever then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if not name then return false end
    return name == "TradeSkillFrame" or name == "CraftFrame"
        or name:match("^Professions") ~= nil
        or name:match("^Profession") ~= nil
        or name:match("TradeSkill") ~= nil
end

function Compatibility.IsExperimentalForeverProfessionsMovementEnabled()
    return Offhand.isForever
        and Offhand.IsExperimentalForeverProfessionsMovementEnabled
        and Offhand:IsExperimentalForeverProfessionsMovementEnabled() or false
end

function Compatibility.ShouldYieldForeverProfessionsPanel(frame, suppliedName)
    return Compatibility.IsForeverProfessionsPanel(frame, suppliedName)
        and not Compatibility.IsExperimentalForeverProfessionsMovementEnabled()
end

function Compatibility.IsPersistentForeverProfessionsPanelName(name)
    return Compatibility.IsExperimentalForeverProfessionsMovementEnabled()
        and (name == "ProfessionsFrame" or name == "ProfessionsBookFrame")
end

function Compatibility.IsBlizzardEditModeOwnedFrame(frame, suppliedName)
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    return name and (name:match("^EditMode") ~= nil
        or name:match("^DamageMeter") ~= nil) or false
end

function Compatibility.HasBlizzardEditMode()
    if type(Offhand.HasBlizzardEditMode) == "function" then
        return Offhand:HasBlizzardEditMode()
    end
    return Offhand.isRetail or Offhand.isForever
        or C_EditMode ~= nil or EditModeManagerFrame ~= nil
end

function Compatibility.IsForeverEditModeFrame(frame, suppliedName)
    if not Compatibility.HasBlizzardEditMode() then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if Compatibility.IsBlizzardEditModeOwnedFrame(frame, name) then return true end
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
