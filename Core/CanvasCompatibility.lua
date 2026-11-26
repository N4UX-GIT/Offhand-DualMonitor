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

function Compatibility.HasMoveMyBags()
    return Compatibility.IsAddonLoaded("MoveMyBags") or rawget(_G, "MoveMyBags") ~= nil
end

-- An addon that moves Blizzard's native ContainerFrame windows directly can
-- need every native container left to it (rule yieldNativeContainer). Yield
-- drag, persistence, layout, and recovery for those containers while retaining
-- dormant Offhand coordinates.
function Compatibility.ShouldYieldNativeContainer(frameOrName, suppliedName)
    local name = suppliedName
        or (type(frameOrName) == "string" and frameOrName)
        or (type(frameOrName) == "table" and frameOrName.GetName and frameOrName:GetName())
    if type(name) ~= "string" then return false end
    if name ~= "ContainerFrameCombinedBags" and not name:match("^ContainerFrame%d+$") then
        return false
    end
    local bridges = Offhand.Bridges
    return bridges ~= nil and bridges:MatchFrame("yieldNativeContainer",
        type(frameOrName) == "table" and frameOrName or nil, name)
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

local mapAddons = {"OpenMap", "MapWise", "MapUtils", "Leatrix_Maps",
    "BlizzMove", "MoveAny", "MoveAnything", "ClassicUIForever"}
local mapVersionNamespaces = {OpenMap = "OpenMap", MapWise = "MapWiseAPI"}

local function DiagnosticVersion(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then return end
    local version = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
    if version ~= "" then return version:sub(1, 64) end
end

function Compatibility.GetMapIntegrationDiagnostics()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local detected, seen = {}, {}
    local function Report(name)
        if seen[name] then return end
        seen[name] = true
        if Compatibility.IsAddonLoaded(name) then
            local namespaceName = mapVersionNamespaces[name]
            local namespace = namespaceName and rawget(_G, namespaceName)
            local version
            if type(namespace) == "table" then version = DiagnosticVersion(rawget(namespace, "version")) end
            if not version and type(getMetadata) == "function" then
                local ok, value = pcall(getMetadata, name, "Version")
                if ok then version = DiagnosticVersion(value) end
            end
            detected[#detected + 1] = name .. "=" .. (version or "unknown version")
        end
    end
    for _, name in ipairs(mapAddons) do Report(name) end
    for _, name in ipairs(Offhand.Bridges and Offhand.Bridges:GetMapAddons() or {}) do Report(name) end
    return #detected > 0 and table.concat(detected, " | ") or "none detected"
end

local function IsFiniteNumber(value)
    if type(issecretvalue) == "function" then
        local ok, secret = pcall(issecretvalue, value)
        if not ok or secret then return false end
    end
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function ValidOpenMapWindowSchema(db, requireWindowFields)
    if type(db) ~= "table" then return false end
    if db.windowScale ~= nil or requireWindowFields then
        if not IsFiniteNumber(db.windowScale) or db.windowScale <= 0 then return false end
    end
    local win = db.window
    if win ~= nil and win ~= false then
        if type(win) ~= "table" or type(win[1]) ~= "string" or type(win[2]) ~= "string"
            or not IsFiniteNumber(win[3]) or not IsFiniteNumber(win[4]) then
            return false
        end
    end
    local size = db.windowSize
    if size ~= nil and size ~= false then
        if type(size) ~= "table" or not IsFiniteNumber(size[1]) or not IsFiniteNumber(size[2])
            or size[1] <= 0 or size[2] <= 0 then
            return false
        end
    end
    return true
end

-- Read-only contract check (safe for diagnostics; never calls GetModule).
-- Uses OpenMapAPI.major == 1 (OpenMap's documented semver boundary) and
-- version >= 4 plus runtime OpenMapDB.worldmap schema validation instead of
-- pinning exact patch strings.
function Compatibility.InspectOpenMapContract()
    local namespace, api = _G.OpenMap, _G.OpenMapAPI
    if type(namespace) ~= "table" or type(namespace.GetModule) ~= "function"
        or type(api) ~= "table" then return "absent" end
    if api.major ~= 1 then return "unsupported-major" end
    if type(api.version) ~= "number" or api.version < 4 then return "unsupported-api" end
    local db = type(_G.OpenMapDB) == "table" and _G.OpenMapDB.worldmap
    if type(db) ~= "table" then return "schema-mismatch" end
    if db.enabled == false then return "disabled" end
    if not ValidOpenMapWindowSchema(db) then return "schema-mismatch" end
    return "ok"
end

function Compatibility.GetOpenMapWorldMapModule()
    if Compatibility.InspectOpenMapContract() ~= "ok" then return end
    local namespace = _G.OpenMap
    local ok, module = pcall(namespace.GetModule, namespace, "worldmap")
    local db = ok and type(module) == "table" and module.db
    if type(db) ~= "table" or db.enabled == false or db ~= _G.OpenMapDB.worldmap
        or not ValidOpenMapWindowSchema(db) then return end
    return module, db
end

-- Placement and expanded-map recovery require the stitched map; windowScale
-- itself applies to every windowed OpenMap view (allowUnstitched = true).
function Compatibility.GetOpenMapWindowModule(allowUnstitched)
    if not Offhand.isForever or Compatibility.GetWorldMapExternalOwner() ~= "OpenMap" then return end
    local module, db = Compatibility.GetOpenMapWorldMapModule()
    local api = _G.OpenMapAPI
    if not module or not ValidOpenMapWindowSchema(db, true) then return end
    if not allowUnstitched and (type(api.IsStitched) ~= "function" or not api.IsStitched()) then return end
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

local function FormatMapOwnerLabel(owner)
    if owner == "LeatrixMaps" then return "Leatrix Maps" end
    if owner == "ClassicUIForever" then return "ClassicUI Forever" end
    return owner
end

local function IsOneForAllMoveWindowsDisabled()
    local db = rawget(_G, "OneForAllDB")
    local qol = type(db) == "table" and rawget(db, "qol")
    return type(qol) == "table" and qol.moveWindows == false
end

local function IsOneForAllMovingFrame(frameName)
    if not Compatibility.IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return false
    end
    local frame = rawget(_G, frameName)
    return type(frame) == "table" and frame.ofaMovable == true
end

local function IsOneForAllMovingWorldMap()
    return IsOneForAllMovingFrame("WorldMapFrame")
end

local oneForAllDiagnosticFrameNames = {
    "WorldMapFrame", "ContainerFrameCombinedBags", "SettingsPanel",
    "CooldownViewerSettings", "AddonList", "MerchantFrame", "CharacterFrame",
    "PlayerSpellsFrame", "GameMenuFrame",
}

local function IsOneForAllMovingAnyWindow()
    if not Compatibility.IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return false
    end
    for _, frameName in ipairs(oneForAllDiagnosticFrameNames) do
        if IsOneForAllMovingFrame(frameName) then return true end
    end
    return false
end

local function GetOneForAllUnmitigatedMoverTargets(mapOwner, bagOwners)
    if not Compatibility.IsAddonLoaded("OneForAll") or IsOneForAllMoveWindowsDisabled() then
        return nil
    end
    local targets = {}
    if not mapOwner and IsOneForAllMovingFrame("WorldMapFrame") then
        targets[#targets + 1] = "WorldMapFrame"
    end
    if (#bagOwners == 0) and IsOneForAllMovingFrame("ContainerFrameCombinedBags") then
        targets[#targets + 1] = "ContainerFrameCombinedBags"
    end
    if Offhand.isForever then
        if IsOneForAllMovingFrame("SettingsPanel") then
            targets[#targets + 1] = "SettingsPanel"
        end
        if IsOneForAllMovingFrame("CooldownViewerSettings") then
            targets[#targets + 1] = "CooldownViewerSettings"
        end
    end
    return #targets > 0 and targets or nil
end

local function IsElvUIBagsActive()
    local elv = rawget(_G, "ElvUI")
    if elv == nil then return false end
    if rawget(_G, "ElvUI_ContainerFrame") ~= nil then return true end
    local core = type(elv) == "table" and elv[1]
    local bags = type(core) == "table" and type(core.private) == "table" and core.private.bags
    return type(bags) == "table" and bags.enable == true
end

local function IsTukuiBagsActive()
    local tuk = rawget(_G, "Tukui")
    if tuk == nil then return false end
    if rawget(_G, "TukuiBag") ~= nil then return true end
    local cfg = type(tuk) == "table" and tuk[2]
    local bags = type(cfg) == "table" and cfg.Bags
    return type(bags) == "table" and bags.Enable == true
end

function Compatibility.GetActiveBagOwners()
    local owners, seen = {}, {}
    local function Add(name)
        if name and not seen[name] then
            seen[name] = true
            owners[#owners + 1] = name
        end
    end
    if Compatibility.IsAddonLoaded("EllesmereUIBags")
        and not (Offhand.isForever and Offhand.HUDCompatibility
            and Offhand.HUDCompatibility.UsesNativeGamepadInterface
            and Offhand.HUDCompatibility.UsesNativeGamepadInterface()) then
        Add("EllesmereUIBags")
    end
    for _, candidate in ipairs({"MoveMyBags", "Baganator", "Bagnon", "ArkInventory", "BetterBags", "Bagnaros", "AdiBags", "Inventorian"}) do
        if Compatibility.IsAddonLoaded(candidate) or rawget(_G, candidate) ~= nil then
            Add(candidate)
        end
    end
    if Offhand.HUDCompatibility and Offhand.HUDCompatibility.GetBagSmithParkingParent
        and Offhand.HUDCompatibility.GetBagSmithParkingParent() then
        Add("BagSmith")
    end
    if IsElvUIBagsActive() then Add("ElvUI") end
    if IsTukuiBagsActive() then Add("Tukui") end
    if Offhand.Bridges and Offhand.Bridges.HasCustomBag then
        local hasBridgeBag, bridgeId = Offhand.Bridges:HasCustomBag()
        if hasBridgeBag and bridgeId then Add(bridgeId) end
    end
    return owners
end

-- Present owners of a report role in role order, each name once.
local function ReportOwners(role)
    local owners, seen = {}, {}
    for _, name in ipairs(Offhand.Bridges and Offhand.Bridges:GetRoleOwners(role) or {}) do
        if not seen[name] then
            seen[name] = true
            owners[#owners + 1] = name
        end
    end
    return owners
end

function Compatibility.GetActiveExternalOwners()
    local owners = {}
    local mapOwner = Compatibility.GetWorldMapExternalOwner()
    if mapOwner then owners.map = FormatMapOwnerLabel(mapOwner) end
    local bags = Compatibility.GetActiveBagOwners()
    if #bags > 0 then owners.bags = bags end
    local chat = ReportOwners("report.chat")
    if #chat > 0 then owners.chat = chat end
    local minimap = Offhand.Bridges and Offhand.Bridges:FirstRoleOwner("report.minimap")
    if minimap then owners.minimap = minimap end
    local unitFrames = ReportOwners("report.unitFrames")
    if #unitFrames > 0 then owners.unitFrames = unitFrames end
    local actionBars = ReportOwners("report.actionBars")
    if #actionBars > 0 then owners.actionBars = actionBars end
    local movers = ReportOwners("report.movers")
    if #movers > 0 then owners.movers = movers end
    return owners
end

-- Actionable guidance for external addons that legitimately own specific HUD or
-- UI frames (never treated as chat-spam conflicts, surfaced in Options/diag).
-- Each bridge guidance entry is shown when any owner its when table names
-- ({ [ownersList] = name }) is in that list of GetActiveExternalOwners.
function Compatibility.GetExternalControlGuidance()
    local L = Offhand.L or {}
    local owners = Compatibility.GetActiveExternalOwners()
    local guidance, seen = {}, {}
    local function Add(id, addon, text)
        if not seen[id] and text then
            seen[id] = true
            guidance[#guidance + 1] = { id = id, addon = addon, text = text }
        end
    end
    local active = {}
    for list, names in pairs(owners) do
        if type(names) == "table" then
            active[list] = {}
            for _, name in ipairs(names) do active[list][name] = true end
        end
    end
    if not Offhand.Bridges then return guidance end
    local entries, suffixes = Offhand.Bridges:GetGuidanceEntries()
    for index, entry in ipairs(entries) do
        local shown = false
        for list, name in pairs(type(entry.when) == "table" and entry.when or {}) do
            if active[list] and active[list][name] then shown = true; break end
        end
        if shown then
            local text = L[entry.key] or entry.fallback
            if entry.args == 2 and type(text) == "string" then
                text = string.format(text, entry.addon, entry.addon)
            end
            if suffixes[index] and type(text) == "string" then
                text = text .. " " .. (L[entry.suffixKey] or entry.suffixFallback)
            end
            Add(entry.id, entry.addon, text)
        end
    end
    return guidance
end

-- Returns genuine active conflicts only (never normal single-addon coexistence).
function Compatibility.GetOwnershipConflicts()
    local conflicts = {}
    local mapOwner = Compatibility.GetWorldMapExternalOwner()
    local openMapContract = (Offhand.isForever and mapOwner == "OpenMap")
        and Compatibility.InspectOpenMapContract() or nil
    if openMapContract and openMapContract ~= "ok" and openMapContract ~= "absent" and openMapContract ~= "disabled" then
        conflicts[#conflicts + 1] = {
            id = "openmap-contract:" .. openMapContract,
            kind = "openmap-contract",
            reason = openMapContract,
        }
    end
    if (mapOwner == "LeatrixMaps" or mapOwner == "OpenMap") and IsOneForAllMovingWorldMap() then
        local mitigated = (mapOwner == "OpenMap" and openMapContract == "ok")
        if not mitigated then
            conflicts[#conflicts + 1] = {
                id = "worldmap-mover:OneForAll+" .. mapOwner,
                kind = "worldmap-mover",
                mover = "OneForAll",
                owner = FormatMapOwnerLabel(mapOwner),
            }
        end
    end
    local bags = Compatibility.GetActiveBagOwners()
    if #bags >= 2 then
        conflicts[#conflicts + 1] = {
            id = "bags-conflict:" .. table.concat(bags, "+"),
            kind = "bags-conflict",
            addons = table.concat(bags, ", "),
        }
    end
    local ofaTargets = GetOneForAllUnmitigatedMoverTargets(mapOwner, bags)
    if ofaTargets then
        conflicts[#conflicts + 1] = {
            id = "window-mover:OneForAll",
            kind = "window-mover",
            mover = "OneForAll",
            targets = table.concat(ofaTargets, ","),
        }
    end
    return conflicts
end

local notifiedConflicts = {}

function Compatibility.FormatConflictMessage(conflict)
    local L = Offhand.L or {}
    if conflict.kind == "worldmap-mover" then
        local fmt = L["COMPAT_CONFLICT_WORLDMAP_MOVER"]
            or "Conflict: %s is moving the World Map ahead of %s. Disable %s's window movement option if the map snaps back."
        return string.format(fmt, conflict.mover, conflict.owner, conflict.mover)
    elseif conflict.kind == "window-mover" then
        local fmt = L["COMPAT_CONFLICT_WINDOW_MOVER"]
            or "Conflict: %s's Move Blizzard windows option is active alongside Offhand. Disable Move Blizzard windows in %s if windows, bags, or the World Map flicker or snap back."
        return string.format(fmt, conflict.mover, conflict.mover)
    elseif conflict.kind == "openmap-contract" then
        local fmt = L["COMPAT_CONFLICT_OPENMAP_CONTRACT"]
            or "Notice: OpenMap updated to an unsupported contract (%s). Offhand stood down its OpenMap drag sync and recovery helpers."
        return string.format(fmt, conflict.reason)
    elseif conflict.kind == "bags-conflict" then
        local fmt = L["COMPAT_CONFLICT_BAGS"]
            or "Conflict: multiple bag addons are active (%s). Keep only one bag addon enabled for reliable Offhand bag persistence."
        return string.format(fmt, conflict.addons)
    end
end

function Compatibility.NotifyActiveConflicts()
    if not Offhand.db or not Offhand.db.enabled then return 0 end
    if InCombatLockdown and InCombatLockdown() then return 0 end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return 0 end
    local printed = 0
    for _, conflict in ipairs(Compatibility.GetOwnershipConflicts()) do
        if not notifiedConflicts[conflict.id] then
            notifiedConflicts[conflict.id] = true
            local text = Compatibility.FormatConflictMessage(conflict)
            if text and Offhand.Print then
                Offhand:Print(text)
                printed = printed + 1
            end
        end
    end
    return printed
end

function Compatibility.ResetConflictNotifications()
    notifiedConflicts = {}
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
            local contract = Compatibility.InspectOpenMapContract()
            return string.format(" | OpenMap=%s | MapFPSCap=%s | maxFPS=%s | OpenMapWindow=%s | OpenMapContract=%s",
                version, cap or "unavailable", current or "unavailable",
                type(db.window) == "table" and "saved" or "none", contract)
        end)
        if ok and status then openMapStatus = status end
    end
    local moverStatus = ""
    if (mapOwner == "OpenMap" or mapOwner == "LeatrixMaps") and IsOneForAllMovingWorldMap() then
        local mitigated = (mapOwner == "OpenMap" and Compatibility.InspectOpenMapContract() == "ok")
        moverStatus = " | WorldMapMover=OneForAll(" .. (mitigated and "synced" or "conflict") .. ")"
    end
    if IsOneForAllMovingAnyWindow() then
        moverStatus = moverStatus .. " | OneForAllMover=active"
    end
    local conflictList = Compatibility.GetOwnershipConflicts()
    local conflictStatus = ""
    if #conflictList > 0 then
        local ids = {}
        for _, c in ipairs(conflictList) do ids[#ids + 1] = c.id end
        conflictStatus = " | Conflicts=" .. table.concat(ids, ",")
    end
    local controllerStatus = ""
    local owners = Compatibility.GetActiveExternalOwners()
    local controllers, seenCtrl = {}, {}
    for _, list in ipairs({owners.unitFrames, owners.actionBars, owners.movers}) do
        for _, name in ipairs(list or {}) do
            if not seenCtrl[name] then
                seenCtrl[name] = true
                controllers[#controllers + 1] = name
            end
        end
    end
    if #controllers > 0 then
        controllerStatus = " | FrameControllers=" .. table.concat(controllers, ",")
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
            Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner)
            .. leatrixStatus .. spellbookStatus .. bagStatus .. moverStatus .. controllerStatus .. conflictStatus
    end
    return string.format("MoveAny=%s | WorldMapOwner=%s",
        Compatibility.HasMoveAny() and "loaded" or "absent", mapOwner)
        .. leatrixStatus .. spellbookStatus .. bagStatus .. openMapStatus .. moverStatus .. controllerStatus .. conflictStatus
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
