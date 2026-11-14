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
    DebuffFrame = true,
    ExternalDefensivesFrame = true,
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

function Compatibility.IsForeverEllesmereBag(name)
    return Offhand.isForever
        and (name == "EUI_MainBagFrame" or name == "EUI_ReagentBagFrame" or name == "EUI_BagsWindowFrame")
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

function Compatibility.GetWorldMapFadeAddon()
    if Compatibility.IsAddonLoaded("OpenMap") then return "OpenMap" end
    if Compatibility.IsAddonLoaded("MapUtils") then return "MapUtils" end
    if Compatibility.IsAddonLoaded("MapWise") then return "MapWise" end
    if Compatibility.HasLeatrixMaps() then return "Leatrix_Maps" end
end

function Compatibility.GetOpenMapWorldMapModule()
    local namespace, api = _G.OpenMap, _G.OpenMapAPI
    if type(namespace) ~= "table" or type(namespace.GetModule) ~= "function"
        or type(api) ~= "table" or api.major ~= 1 or api.version ~= 4 then return end
    local version = namespace.version
    if version ~= "v0.7.5-beta" and version ~= "v0.8.6" and version ~= "v0.8.7" then return end
    local module = namespace:GetModule("worldmap")
    local db = type(module) == "table" and module.db
    if type(db) ~= "table" or db.enabled == false or type(_G.OpenMapDB) ~= "table"
        or db ~= _G.OpenMapDB.worldmap then return end
    return module, db
end

-- Placement and scaling require the stitched map's geometry contract.
function Compatibility.GetOpenMapWindowModule()
    if not Offhand.isForever or Compatibility.GetWorldMapExternalOwner() ~= "OpenMap" then return end
    local module, db = Compatibility.GetOpenMapWorldMapModule()
    local api = _G.OpenMapAPI
    if not module or type(api.IsStitched) ~= "function" or not api.IsStitched() then return end
    if type(module.MoveAnyOn) == "function" and module.MoveAnyOn() then return end
    return module, db
end

local function IsWorldMapFrame(frameOrName)
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName ~= nil and frameOrName == _G.WorldMapFrame
end

function Compatibility.IsExternallyPositionedWorldMap(frameOrName)
    local owner = Compatibility.GetWorldMapExternalOwner()
    return (owner == "LeatrixMaps" or owner == "OpenMap") and IsWorldMapFrame(frameOrName)
end

function Compatibility.SupportsExternalWorldMapEscapeProtection(frameOrName)
    local owner = Compatibility.GetWorldMapExternalOwner()
    -- MoveAny continues to own the map's placement and reopening on Forever.
    return (owner == "LeatrixMaps" or owner == "OpenMap" or (Offhand.isForever and owner == "MoveAny"))
        and IsWorldMapFrame(frameOrName)
end

function Compatibility.ShouldYieldWorldMap(frameOrName)
    if not Compatibility.GetWorldMapExternalOwner() then return false end
    return IsWorldMapFrame(frameOrName)
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
    local openMapStatus = ""
    if Offhand.isForever and mapOwner == "OpenMap" then
        local ok, status = pcall(function()
            local namespace, data = _G.OpenMap, _G.OpenMapDB
            local version = type(namespace) == "table" and namespace.version
            local db = type(data) == "table" and data.worldmap
            if type(version) ~= "string" or type(db) ~= "table" then return end
            local getCVar = C_CVar and C_CVar.GetCVar or _G.GetCVar
            local cap = tonumber(db.mapFpsCap)
            local current = type(getCVar) == "function" and tonumber(getCVar("maxFPS"))
            return string.format(" | OpenMap=%s | MapFPSCap=%s | maxFPS=%s | OpenMapWindow=%s",
                version, cap or "unavailable", current or "unavailable",
                type(db.window) == "table" and "saved" or "none")
        end)
        if ok and status then openMapStatus = status end
    end
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
        Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner)
        .. leatrixStatus .. spellbookStatus .. bagStatus .. openMapStatus
end

-- Support-only inspection. Never move, show, hook or read guide contents from
-- third-party frames. A missing named root is not proof that an addon is absent.
function Compatibility.GetGuideAddonDiagnostics()
    local loaded = Compatibility.IsAddonLoaded("ZygorGuidesViewer")
        or Compatibility.IsAddonLoaded("ZygorGuidesViewerClassic")
    local namespace = type(_G.ZygorGuidesViewer) == "table"
    local reports, seen, scanned, truncated = {}, {}, 0, false
    local function Public(value)
        if type(issecretvalue) == "function" then
            local ok, secret = pcall(issecretvalue, value)
            if not ok or secret then return nil end
        end
        return value
    end
    local function Read(frame, method)
        local ok, value = pcall(function()
            local getter = frame and frame[method]
            if type(getter) == "function" then return getter(frame) end
        end)
        if ok then return Public(value) end
    end
    local function Value(value)
        if type(value) == "boolean" then return value and "1" or "0" end
        if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
            return string.format("%.2f", value)
        end
        return "unavailable"
    end
    for _, parent in pairs({UIParent, WorldFrame}) do
        if parent and type(parent.GetChildren) == "function" then
            local ok, children = pcall(function() return {parent:GetChildren()} end)
            if ok then
                if #children > 256 then truncated = true end
                for index = 1, math.min(#children, 256) do
                    local frame = children[index]
                    scanned = scanned + 1
                    local name = Read(frame, "GetName")
                    if type(name) == "string" and name:lower():find("zygor", 1, true) and not seen[frame] then
                        seen[frame] = true
                        if #reports < 8 then
                            local strata = Read(frame, "GetFrameStrata")
                            reports[#reports + 1] = string.format(
                                "%s parent=%s shown=%s visible=%s alpha=%s effectiveAlpha=%s strata=%s level=%s scale=%s bounds=%s/%s/%s/%s",
                                name:sub(1, 96), parent == UIParent and "UIParent" or "WorldFrame",
                                Value(Read(frame, "IsShown")), Value(Read(frame, "IsVisible")),
                                Value(Read(frame, "GetAlpha")), Value(Read(frame, "GetEffectiveAlpha")),
                                type(strata) == "string" and strata:sub(1, 32) or "unavailable",
                                Value(Read(frame, "GetFrameLevel")),
                                Value(Read(frame, "GetEffectiveScale")), Value(Read(frame, "GetLeft")),
                                Value(Read(frame, "GetBottom")), Value(Read(frame, "GetRight")), Value(Read(frame, "GetTop")))
                        else truncated = true end
                    end
                end
            end
        end
    end
    if not loaded and not namespace and #reports == 0 then return nil end
    table.insert(reports, 1, string.format("Zygor probes: knownAddonID=%s namespace=%s namedRoots=%d scanned=%d truncated=%s",
        loaded and "loaded" or "not-observed", namespace and "present" or "not-observed",
        #reports, scanned, truncated and "yes" or "no"))
    return reports
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
