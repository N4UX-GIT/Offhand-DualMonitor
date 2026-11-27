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

local function HasRole(role)
    local bridges = Offhand.Bridges
    return bridges ~= nil and bridges:HasRole(role)
end

-- An addon that owns the World Map's own configuration (scale, anchors,
-- scripts and settings) keeps Offhand's map configuration and cursor
-- conversion away (role map.configurationOwner).
function Compatibility.HasWorldMapConfigurationOwner()
    return HasRole("map.configurationOwner")
end

-- An addon that manages the native panels themselves (role
-- map.blocksPanelManagement) keeps Offhand's native panel origin, cold combat
-- panel loading, combat clamps and combat anchor repair away. Canvas leaves
-- scale, anchor, persistence, drag, and post-toggle behavior to a single
-- owner while retaining dormant Offhand coordinates.
function Compatibility.HasPanelManagementOwner()
    return HasRole("map.blocksPanelManagement")
end

-- Role map.blocksSlotRepair: an addon whose panel movement replaces Offhand's
-- default native slot repair.
function Compatibility.HasPanelSlotRepairOwner()
    return HasRole("map.blocksSlotRepair")
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

-- A bag addon whose roots own their visibility, layout and Escape proxy on
-- Forever (rule selfManagedBag): the generic panel passes leave them alone.
function Compatibility.IsForeverSelfManagedBag(name)
    local bridges = Offhand.Bridges
    return Offhand.isForever and bridges ~= nil and bridges:MatchName("selfManagedBag", name)
end

-- An addon with its own persistent movement for some native frames (role
-- panels.externalOwner, the first present owner's frames list) keeps them.
-- The owner is independent of Offhand.isForever, which identifies a client
-- family rather than a frame owner.
function Compatibility.ShouldYieldFrameToExternalOwner(frameOrName, suppliedName)
    local bridges = Offhand.Bridges
    if not bridges then return false end
    local _, owner = bridges:FirstRoleOwner("panels.externalOwner")
    if not owner or type(owner.frames) ~= "table" then return false end
    local name = suppliedName
        or (type(frameOrName) == "string" and frameOrName)
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    for _, frameName in ipairs(owner.frames) do
        if name == frameName then return true end
    end
    return false
end

-- The names of the frames that owner keeps, in its order, or nil when no
-- such owner is present.
function Compatibility.GetExternalOwnerFrames()
    local bridges = Offhand.Bridges
    if not bridges then return nil end
    local _, owner = bridges:FirstRoleOwner("panels.externalOwner")
    if not owner or type(owner.frames) ~= "table" then return nil end
    return owner.frames
end

-- The World Map's geometry owner: the first present owner of role map.owner
-- in its fixed order, or nil when Offhand owns the map.
function Compatibility.GetWorldMapExternalOwner()
    local bridges = Offhand.Bridges
    return bridges and bridges:FirstRoleOwner("map.owner") or nil
end

-- Facts the map.owner entry of owner declares (positionsMap,
-- escapeProtection, bootstrapsAnchor, label), or nil.
local function MapOwnerFacts(owner)
    local bridges = Offhand.Bridges
    return owner ~= nil and bridges and bridges:GetRoleEntry("map.owner", owner) or nil
end
Compatibility.GetWorldMapOwnerFacts = MapOwnerFacts

function Compatibility.GetWorldMapFadeAddon()
    local bridges = Offhand.Bridges
    return bridges and bridges:FirstRoleOwner("map.fade") or nil
end

local function DiagnosticVersion(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then return end
    local version = value:gsub("[%c|]", ""):match("^%s*(.-)%s*$")
    if version ~= "" then return version:sub(1, 64) end
end

-- Map addons come from role map.integration in its fixed order (present or
-- not; each is reported only while loaded), then from the bridges' mapAddons.
-- An entry's versionNamespace names a global table whose version field wins
-- over the addon's metadata.
function Compatibility.GetMapIntegrationDiagnostics()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local bridges = Offhand.Bridges
    local integrations = bridges and bridges:GetRoleEntries("map.integration") or {}
    local versionNamespaces = {}
    for _, entry in ipairs(integrations) do
        if versionNamespaces[entry.name] == nil and type(entry.versionNamespace) == "string" then
            versionNamespaces[entry.name] = entry.versionNamespace
        end
    end
    local detected, seen = {}, {}
    local function Report(name)
        if seen[name] then return end
        seen[name] = true
        if Compatibility.IsAddonLoaded(name) then
            local namespaceName = versionNamespaces[name]
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
    for _, entry in ipairs(integrations) do Report(entry.name) end
    for _, name in ipairs(bridges and bridges:GetMapAddons() or {}) do Report(name) end
    return #detected > 0 and table.concat(detected, " | ") or "none detected"
end

local function IsWorldMapFrame(frameOrName)
    if type(frameOrName) == "string" then return frameOrName == "WorldMapFrame" end
    return frameOrName ~= nil and frameOrName == _G.WorldMapFrame
end

-- The owner positions the map itself (its map.owner entry's positionsMap).
function Compatibility.IsExternallyPositionedWorldMap(frameOrName)
    local facts = MapOwnerFacts(Compatibility.GetWorldMapExternalOwner())
    return (facts ~= nil and facts.positionsMap == true) and IsWorldMapFrame(frameOrName)
end

-- The owner keeps Offhand's Escape protection for the map: escapeProtection
-- true, or "forever" on the Forever client only, where such an owner keeps
-- the map's placement and reopening.
function Compatibility.SupportsExternalWorldMapEscapeProtection(frameOrName)
    local facts = MapOwnerFacts(Compatibility.GetWorldMapExternalOwner())
    local protection = facts and facts.escapeProtection
    return (protection == true or (Offhand.isForever and protection == "forever"))
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

-- The owner's display label (its map.owner entry's label), else its name.
local function FormatMapOwnerLabel(owner)
    local facts = MapOwnerFacts(owner)
    if facts and type(facts.label) == "string" then return facts.label end
    return owner
end

-- " | "-separable "label=text" parts of a diagnostics slot, in order. A
-- segment with a detector shows text (default "loaded") while it passes,
-- else its absent text, and is skipped when it has none; a value function is
-- called with ... in pcall ("unavailable" when it fails or is not a string).
local function DiagnosticParts(parts, slot, ...)
    local bridges = Offhand.Bridges
    if not bridges then return parts end
    local entries, present = bridges:GetDiagnosticSegments(slot)
    for index, entry in ipairs(entries) do
        local text
        if entry.detect ~= nil and not present[index] then
            text = entry.absent
        elseif type(entry.value) == "function" then
            local ok, value = pcall(entry.value, ...)
            text = ok and type(value) == "string" and value or "unavailable"
        else
            text = entry.text or "loaded"
        end
        if type(text) == "string" then parts[#parts + 1] = entry.label .. "=" .. text end
    end
    return parts
end

-- A report.bags owner whose entry says yieldsToNativeGamepad is left out on
-- Forever while the native Gamepad interface is in use.
local function AcceptsBagOwner(entry)
    return not (entry.yieldsToNativeGamepad and Offhand.isForever and Offhand.HUDCompatibility
        and Offhand.HUDCompatibility.UsesNativeGamepadInterface
        and Offhand.HUDCompatibility.UsesNativeGamepadInterface())
end

-- Replacement bag owners: role report.bags in its fixed order (the order is
-- part of the bags-conflict id), then a bridge's live replacement bag.
function Compatibility.GetActiveBagOwners()
    local owners, seen = {}, {}
    local function Add(name)
        if name and not seen[name] then
            seen[name] = true
            owners[#owners + 1] = name
        end
    end
    for _, name in ipairs(Offhand.Bridges and Offhand.Bridges:GetRoleOwners("report.bags", AcceptsBagOwner) or {}) do
        Add(name)
    end
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

local function ByConflictOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.index < b.index
end

-- Returns genuine active conflicts only (never normal single-addon coexistence).
-- The map owner's contract notice comes first (order 10) and the multiple bag
-- addon conflict at order 30; window mover bridges add theirs through
-- GetOwnershipConflicts(context), each carrying its own order.
function Compatibility.GetOwnershipConflicts()
    local found = {}
    local function Add(order, conflict)
        found[#found + 1] = { conflict = conflict, index = #found + 1,
            order = type(order) == "number" and order or math.huge }
    end
    local mapOwner = Compatibility.GetWorldMapExternalOwner()
    local bridges = Offhand.Bridges
    -- On Forever the map owner's provider reports its own contract notice and
    -- whether it keeps a window mover's writes in sync.
    local ownerConflict = Offhand.isForever and bridges and bridges:CallMap(mapOwner, "GetContractConflict") or nil
    if type(ownerConflict) == "table" then Add(10, ownerConflict) end
    local bags = Compatibility.GetActiveBagOwners()
    if bridges and bridges.GetOwnershipConflicts then
        local mapFacts = MapOwnerFacts(mapOwner)
        local context = {
            mapOwner = mapOwner,
            mapLabel = mapOwner and FormatMapOwnerLabel(mapOwner) or nil,
            positionsMap = mapFacts ~= nil and mapFacts.positionsMap == true,
            bagOwners = bags,
            SyncsWorldMapMover = function()
                return Offhand.isForever and bridges:CallMap(mapOwner, "SyncsWorldMapMover") == true
            end,
        }
        for _, conflict in ipairs(bridges:GetOwnershipConflicts(context)) do Add(conflict.order, conflict) end
    end
    if #bags >= 2 then
        Add(30, {
            id = "bags-conflict:" .. table.concat(bags, "+"),
            kind = "bags-conflict",
            addons = table.concat(bags, ", "),
        })
    end
    table.sort(found, ByConflictOrder)
    local conflicts = {}
    for index, item in ipairs(found) do conflicts[index] = item.conflict end
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
    elseif conflict.kind == "bags-conflict" then
        local fmt = L["COMPAT_CONFLICT_BAGS"]
            or "Conflict: multiple bag addons are active (%s). Keep only one bag addon enabled for reliable Offhand bag persistence."
        return string.format(fmt, conflict.addons)
    end
    -- A conflict the map owner's provider reported is worded by that provider.
    local bridges = Offhand.Bridges
    if bridges then return bridges:CallMap(Compatibility.GetWorldMapExternalOwner(), "FormatConflict", conflict) end
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

-- The map owner's segments come from the bridges' diagnostics slots:
-- "compact" after WorldMapOwner in the compact line; "compat.head" before it
-- and "compat.map" after it in the full line, whose value functions receive
-- coordinateFontRefreshCount (the last external map coordinate font refresh).
function Compatibility.GetDiagnostics(compact, coordinateFontRefreshCount)
    local externalOwner = Compatibility.GetWorldMapExternalOwner()
    local mapOwner = externalOwner or "Offhand"
    if compact then
        return table.concat(DiagnosticParts({"WorldMapOwner=" .. mapOwner}, "compact"), " | ")
    end
    local head = DiagnosticParts({}, "compat.head")
    head[#head + 1] = "WorldMapOwner=" .. mapOwner
    local ownerStatus = table.concat(DiagnosticParts(head, "compat.map", coordinateFontRefreshCount), " | ")
    local spellbookStatus = Compatibility.GetTBCSpellbookDiagnostics()
    -- On Forever the map owner's provider adds its own part of the line.
    local bridges = Offhand.Bridges
    local ownerDetail = ""
    local status = Offhand.isForever and bridges and bridges:CallMap(mapOwner, "GetOwnerDiagnostics") or nil
    if type(status) == "string" then ownerDetail = " | " .. status end
    -- Window mover bridges add their own segments after the owner's part.
    local moverStatus = ""
    if bridges and bridges.GetMoverDiagnostics then
        local mapFacts = MapOwnerFacts(mapOwner)
        local context = {
            mapOwner = externalOwner,
            positionsMap = mapFacts ~= nil and mapFacts.positionsMap == true,
            SyncsWorldMapMover = function()
                return bridges:CallMap(mapOwner, "SyncsWorldMapMover") == true
            end,
        }
        for _, text in ipairs(bridges:GetMoverDiagnostics(context)) do
            moverStatus = moverStatus .. " | " .. text
        end
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
    return ownerStatus .. spellbookStatus .. bagStatus .. ownerDetail .. moverStatus .. controllerStatus .. conflictStatus
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
