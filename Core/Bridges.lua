--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Bridges.lua: registry and public services for bridge modules and addons

    A bridge adapts one third-party addon to Offhand. Core modules stay free of
    bridged addon specifics: a bridge registers through Offhand.API and the core
    calls it at fixed, pcall-isolated points. See docs/BRIDGES.md for the contract.

    Bridge contract originally contributed by Kintrok (@DCtheGeek).
--]]

local _, Offhand = ...

local Bridges = { CONTRACT = 1, errors = {} }
Offhand.Bridges = Bridges
Offhand.API = Offhand.API or {}
Offhand.API.BRIDGE_CONTRACT = Bridges.CONTRACT

local registry, order = {}, {}
local namespaces, fallbackStorage = {}, {}
local mapProviders = {}

-- Returns true, or false and one of "id", "bridge", "contract", "duplicate".
-- bridge.data is merged like Offhand.API.RegisterAddonData(id, bridge.data),
-- and bridge.mapProvider claims its owner for Bridges:CallMap (first wins).
function Bridges:Register(id, bridge)
    if type(id) ~= "string" or id == "" then return false, "id" end
    if type(bridge) ~= "table" then return false, "bridge" end
    if bridge.contract ~= self.CONTRACT then return false, "contract" end
    if registry[id] and registry[id] ~= bridge then return false, "duplicate" end
    if not registry[id] then
        registry[id] = bridge
        order[#order + 1] = id
    end
    bridge.id = id
    if type(bridge.catalog) == "table" and type(Offhand.AddonWindowCatalog) == "table" then
        Offhand.AddonWindowCatalog[id] = bridge.catalog
    end
    if type(bridge.data) == "table" then self:MergeData(id, bridge.data) end
    local provider = bridge.mapProvider
    if type(provider) == "table" and type(provider.owner) == "string" and provider.owner ~= ""
        and not mapProviders[provider.owner] then
        mapProviders[provider.owner] = { id = id, provider = provider }
    end
    return true
end

function Bridges:Get(id)
    return registry[id]
end

function Bridges:List()
    local ids = {}
    for index, id in ipairs(order) do ids[index] = id end
    return ids
end

-- A failing bridge never breaks Offhand or another bridge. Its latest error is
-- kept for diagnostics and the bridge stays registered.
local function Call(id, method, ...)
    local bridge = registry[id]
    local handler = bridge and bridge[method]
    if type(handler) ~= "function" then return false end
    local ok, result = pcall(handler, bridge, ...)
    if not ok then
        Bridges.errors[id] = tostring(result)
        return false
    end
    return true, result
end

-- reason: "layout" (Canvas:UpdateLayout), "map" (Canvas:ConfigureWorldMap) or
-- "tick" (the Forever position ticker, twice a second). Can run in combat.
function Bridges:Refresh(reason)
    for _, id in ipairs(order) do Call(id, "Refresh", reason) end
end

-- services: the bag Escape helpers documented in docs/BRIDGES.md.
function Bridges:RefreshBags(services)
    for _, id in ipairs(order) do Call(id, "RefreshBags", services) end
end

function Bridges:GetDiagnostics()
    local parts = {}
    for _, id in ipairs(order) do
        local ok, text = Call(id, "GetDiagnostics")
        if ok and type(text) == "string" and text ~= "" then parts[#parts + 1] = text end
        if self.errors[id] then parts[#parts + 1] = "Bridge:" .. id .. "=error" end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, " | ")
end

-- Long per-bridge reports for the debug diagnostics mode only; they never
-- join the compact line above. Each entry is { label = ..., text = ... }.
function Bridges:GetDebugDiagnostics()
    local reports = {}
    for _, id in ipairs(order) do
        local handler = registry[id].GetDebugDiagnostics
        if type(handler) == "function" then
            local ok, label, text = pcall(handler, registry[id])
            if not ok then
                self.errors[id] = tostring(label)
            elseif type(label) == "string" and label ~= "" and type(text) == "string" and text ~= "" then
                reports[#reports + 1] = { label = label, text = text }
            end
        end
    end
    return reports
end

-- True when a bridge's addon has just restored its own single-screen position
-- for this frame, so generic single-screen recovery must leave it alone.
function Bridges:ShouldPreserveSingleScreenPosition(frame, metrics)
    for _, id in ipairs(order) do
        local ok, keep = Call(id, "ShouldPreserveSingleScreenPosition", frame, metrics)
        if ok and keep == true then return true end
    end
    return false
end

-- onWorkspace(frame) is the caller's own test; bridges only name their frames.
function Bridges:IsBagOnWorkspace(onWorkspace)
    if type(onWorkspace) ~= "function" then return false end
    for _, id in ipairs(order) do
        local ok, frames = Call(id, "GetBagFrames")
        if ok and type(frames) == "table" then
            for _, frame in pairs(frames) do
                if onWorkspace(frame) then return true end
            end
        end
    end
    return false
end

-- True when any registered bridge currently provides a live replacement bag frame.
function Bridges:HasCustomBag()
    for _, id in ipairs(order) do
        local ok, frames = Call(id, "GetBagFrames")
        if ok and type(frames) == "table" then
            for _, frame in pairs(frames) do
                if frame ~= nil then return true, id end
            end
        end
    end
    return false
end

-- True while a bridged addon's own unlock/edit mode is active, so Offhand's
-- generic window selection pauses cleanly just like Blizzard Edit Mode.
function Bridges:IsEditModeActive()
    for _, id in ipairs(order) do
        local ok, active = Call(id, "IsEditModeActive")
        if ok and active == true then return true end
    end
    return false
end

-- Optional bridge opt-in for learned placement of a reviewed standalone window
-- belonging to a cataloged bridge addon.
function Bridges:CanLearnPlacement(frame, name, owner, file)
    local bridge = registry[owner]
    if not bridge or type(bridge.catalog) ~= "table" then return false end
    local ok, role = Call(owner, "IdentifyLearnPlacement", frame, name, file)
    if not ok or type(role) ~= "string" then return false end
    local entry = bridge.catalog[role]
    return type(entry) == "table" and entry.learnPlacementFile == file or false
end

-- Snapshot any bridge-owned workspace open state before reload/logout.
function Bridges:CaptureWorkspaceState()
    for _, id in ipairs(order) do Call(id, "CaptureWorkspaceState") end
end

-- Restore bridge-owned workspace open state once the span is active.
function Bridges:RestoreWorkspaceState(mode)
    for _, id in ipairs(order) do Call(id, "RestoreWorkspaceState", mode) end
end

-- Pause/hide bridge-owned workspace windows during single-screen recovery
-- without discarding their workspace open intent.
function Bridges:PrepareSingleScreenRecovery(metrics)
    for _, id in ipairs(order) do Call(id, "PrepareSingleScreenRecovery", metrics) end
end

-- True when a bridge currently parks this native Blizzard panel out of sight
-- under its own holder so Offhand's core must leave its anchor/visibility alone.
function Bridges:IsParkedNativePanel(frame)
    if not frame then return false end
    for _, id in ipairs(order) do
        local ok, parked = Call(id, "IsParkedNativePanel", frame)
        if ok and parked == true then return true end
    end
    return false
end

-- True when a bridge has placed this vendor HUD root itself, so generic popup
-- rescue and panel movement must leave it alone.
function Bridges:IsExternallyOwnedFrame(frame, name)
    if not frame then return false end
    for _, id in ipairs(order) do
        local ok, owned = Call(id, "IsExternallyOwnedFrame", frame, name)
        if ok and owned == true then return true end
    end
    return false
end

-- Runs with the Mainhand transient passes (popups, alerts, toasts), ahead of
-- core's own frames. phase: "hook" (discovery only) or "position". A separate
-- callback rather than a Refresh reason, so other bridges keep their cadence.
function Bridges:RefreshTransientFrames(phase)
    for _, id in ipairs(order) do Call(id, "RefreshTransientFrames", phase) end
end

-- Optional HUD alignment/reset actions offered by active bridges for Offhand's
-- Settings panel, keeping bridge-specific UI text out of core options code.
function Bridges:GetHUDLayoutActions()
    local actions = {}
    for _, id in ipairs(order) do
        local ok, list = Call(id, "GetHUDLayoutActions")
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= "" then
                    actions[#actions + 1] = entry
                end
            end
        end
    end
    return actions
end

-- Addon names whose versions belong in the map integration diagnostics.
function Bridges:GetMapAddons()
    local names, seen = {}, {}
    for _, id in ipairs(order) do
        local list = registry[id].mapAddons
        if type(list) == "table" then
            for _, name in ipairs(list) do
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
        end
    end
    return names
end

-- Settings controls a bridge adds to one Options slot ("map", "alerts",
-- "recovery", "help:EDIT_MODE", "mapScaleTitle", "mapDescription"). Each entry
-- needs a non-empty id; entries come out by their order field (unordered ones
-- last), then in bridge registration order.
function Bridges:GetSettingsContributions(slot)
    local found = {}
    for _, id in ipairs(order) do
        local ok, list = Call(id, "GetSettingsContributions", slot)
        if ok and type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and type(entry.id) == "string" and entry.id ~= "" then
                    found[#found + 1] = { entry = entry, index = #found + 1,
                        order = type(entry.order) == "number" and entry.order or math.huge }
                end
            end
        end
    end
    table.sort(found, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    local contributions = {}
    for index, item in ipairs(found) do contributions[index] = item.entry end
    return contributions
end

-- Runs a bridge's slashCommands[cmd](arg) for a command core does not handle
-- itself. The first registered bridge naming cmd wins. True when a bridge
-- claimed the command, even if its handler failed (the error is recorded).
function Bridges:RunSlashCommand(cmd, arg)
    if type(cmd) ~= "string" or cmd == "" then return false end
    for _, id in ipairs(order) do
        local commands = registry[id].slashCommands
        local handler = type(commands) == "table" and commands[cmd]
        if type(handler) == "function" then
            local ok, problem = pcall(handler, arg)
            if not ok then self.errors[id] = tostring(problem) end
            return true
        end
    end
    return false
end

local function MapResult(id, ok, ...)
    if not ok then
        Bridges.errors[id] = tostring((...))
        return
    end
    return ...
end

-- One call into the map provider of the world map owner the caller already
-- resolved: no loop over bridges. Returns the method's own results, or
-- nothing when that owner has no provider or method, or the method failed.
function Bridges:CallMap(owner, method, ...)
    local entry = owner ~= nil and mapProviders[owner]
    local handler = entry and entry.provider[method]
    if type(handler) ~= "function" then return end
    return MapResult(entry.id, pcall(handler, entry.provider, ...))
end

-- ---------------------------------------------------------------------
-- Declarative addon data (Offhand.API.RegisterAddonData and bridge.data)
-- ---------------------------------------------------------------------

-- Facts are merged once into the lookup tables below, so the core consumers
-- that read them cost a table read and a short loop, never a pcall per bridge.
-- Only a detector's active or a matcher's verify function runs in pcall, and
-- only after the declarative part has passed.
local merged, sequence = {}, 0
local roles, rules, settings = {}, {}, {}
local resetKeys, movableFields, movingFields = {}, {}, {}

local function NonEmpty(value)
    return type(value) == "string" and value ~= ""
end

-- A failing data function counts as false and is recorded under its addon.
local function Guarded(addon, fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, ...)
    if not ok then
        Bridges.errors[addon] = tostring(result)
        return false
    end
    return result == true
end

local function AddonLoaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

-- Detector: loaded="Folder", global="Name", present="Name" (loaded or a global
-- of that name), anyOf={Detector, ...}, forever=true, active=function(). Every
-- field given must pass. No detector means always present.
local function Detect(spec, addon)
    if spec == nil then return true end
    if type(spec) ~= "table" then return false end
    if spec.forever and Offhand.isForever ~= true then return false end
    if spec.global ~= nil and _G[spec.global] == nil then return false end
    if spec.loaded ~= nil and not AddonLoaded(spec.loaded) then return false end
    if spec.present ~= nil and not AddonLoaded(spec.present) and _G[spec.present] == nil then
        return false
    end
    if type(spec.anyOf) == "table" then
        local any = false
        for _, option in ipairs(spec.anyOf) do
            if Detect(option, addon) then any = true; break end
        end
        if not any then return false end
    end
    if spec.active ~= nil then return Guarded(addon, spec.active) end
    return true
end

-- FrameMatcher selectors (any one selects the frame): names, patterns,
-- identity={"Global", ...}, widget={global, key}, index={global, key},
-- field="key", fieldTrue="key". Qualifiers (all must pass): when=Detector,
-- parent="GlobalFrame", then verify=function(frame, name).
local function Selects(matcher, names, frame, name)
    if type(name) == "string" then
        if names[name] then return true end
        if type(matcher.patterns) == "table" then
            for _, pattern in ipairs(matcher.patterns) do
                if name:match(pattern) then return true end
            end
        end
    end
    if frame == nil then return false end
    if type(matcher.identity) == "table" then
        for _, global in ipairs(matcher.identity) do
            if _G[global] == frame then return true end
        end
    end
    local widget = matcher.widget
    if type(widget) == "table" then
        local holder = _G[widget[1]]
        if type(holder) == "table" and rawget(holder, widget[2]) == frame then return true end
    end
    local index = matcher.index
    if type(index) == "table" and type(name) == "string" and _G[name] == frame then
        local store = _G[index[1]]
        local entry = type(store) == "table" and store[name]
        if type(entry) == "table" and entry[index[2]] == name then return true end
    end
    if type(frame) == "table" then
        if matcher.field ~= nil and frame[matcher.field] ~= nil then return true end
        if matcher.fieldTrue ~= nil and frame[matcher.fieldTrue] == true then return true end
    end
    return false
end

local function Matches(compiled, frame, name)
    local matcher = compiled.matcher
    if not Selects(matcher, compiled.names, frame, name) then return false end
    if matcher.when ~= nil and not Detect(matcher.when, compiled.addon) then return false end
    if matcher.parent ~= nil and (type(frame) ~= "table" or type(frame.GetParent) ~= "function"
        or frame:GetParent() ~= _G[matcher.parent]) then return false end
    if matcher.verify ~= nil then return Guarded(compiled.addon, matcher.verify, frame, name) end
    return true
end

local function Rule(ruleName)
    local rule = rules[ruleName]
    if not rule then
        rule = { set = {}, list = {}, names = {}, listed = {} }
        rules[ruleName] = rule
    end
    return rule
end

local function ListName(rule, name)
    if not rule.listed[name] then
        rule.listed[name] = true
        rule.names[#rule.names + 1] = name
    end
end

-- A plain name, or a matcher with only names, compiles into the rule's name
-- set; every other matcher goes into the rule's short list.
local function CompileMatcher(rule, matcher, addon)
    if NonEmpty(matcher) then
        rule.set[matcher] = true
        ListName(rule, matcher)
        return
    end
    if type(matcher) ~= "table" then return end
    local plain, names = true, {}
    for key in pairs(matcher) do
        if key ~= "names" then plain = false; break end
    end
    if type(matcher.names) == "table" then
        for _, name in ipairs(matcher.names) do
            if NonEmpty(name) then
                names[name] = true
                ListName(rule, name)
            end
        end
    end
    if plain then
        for name in pairs(names) do rule.set[name] = true end
    else
        rule.list[#rule.list + 1] = { matcher = matcher, names = names, addon = addon }
    end
end

local function AddField(list, field)
    if not NonEmpty(field) then return end
    for _, known in ipairs(list) do
        if known == field then return end
    end
    list[#list + 1] = field
end

local function ByOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    return a.sequence < b.sequence
end

-- data: ownership, frameRules, moverFields, catalogs and settings (see
-- docs/BRIDGES.md). Unknown keys are ignored. A data table merges only once.
-- Returns true, or false and one of "id", "data".
function Bridges:MergeData(addon, data)
    if not NonEmpty(addon) then return false, "id" end
    if type(data) ~= "table" then return false, "data" end
    if merged[data] then return true end
    merged[data] = true
    if type(data.ownership) == "table" then
        for _, entry in ipairs(data.ownership) do
            if type(entry) == "table" and NonEmpty(entry.role) and NonEmpty(entry.name) then
                sequence = sequence + 1
                local list = roles[entry.role] or {}
                roles[entry.role] = list
                list[#list + 1] = { entry = entry, addon = addon, sequence = sequence,
                    order = type(entry.order) == "number" and entry.order or math.huge }
                table.sort(list, ByOrder)
            end
        end
    end
    if type(data.frameRules) == "table" then
        for ruleName, matchers in pairs(data.frameRules) do
            if NonEmpty(ruleName) and type(matchers) == "table" then
                local rule = Rule(ruleName)
                for _, matcher in ipairs(matchers) do CompileMatcher(rule, matcher, addon) end
            end
        end
    end
    local fields = data.moverFields
    if type(fields) == "table" then
        for _, field in ipairs(type(fields.movable) == "table" and fields.movable or {}) do
            AddField(movableFields, field)
        end
        for _, field in ipairs(type(fields.moving) == "table" and fields.moving or {}) do
            AddField(movingFields, field)
        end
    end
    if type(data.catalogs) == "table" and type(Offhand.AddonWindowCatalog) == "table" then
        for folder, catalog in pairs(data.catalogs) do
            if NonEmpty(folder) and type(catalog) == "table" then
                Offhand.AddonWindowCatalog[folder] = catalog
            end
        end
    end
    if type(data.settings) == "table" then
        local own = settings[addon] or {}
        settings[addon] = own
        for key, spec in pairs(data.settings) do
            if NonEmpty(key) and type(spec) == "table" and not own[key] then
                local compiled = {
                    key = NonEmpty(spec.legacyKey) and spec.legacyKey or key,
                    store = spec.store == "character" and "character" or "profile",
                    default = spec.default,
                }
                own[key] = compiled
                if compiled.store == "character" and spec.resetOnCharacterChange == true then
                    resetKeys[#resetKeys + 1] = compiled.key
                end
            end
        end
    end
    return true
end

-- Ownership roles: entries come in (order, registration) order, and only
-- entries whose detector passes count.
function Bridges:HasRole(role)
    local list = roles[role]
    if not list then return false end
    for _, item in ipairs(list) do
        if Detect(item.entry.detect, item.addon) then return true end
    end
    return false
end

-- Returns the names of the present owners of role and their entries.
function Bridges:GetRoleOwners(role)
    local names, entries = {}, {}
    for _, item in ipairs(roles[role] or {}) do
        if Detect(item.entry.detect, item.addon) then
            names[#names + 1] = item.entry.name
            entries[#entries + 1] = item.entry
        end
    end
    return names, entries
end

-- Returns the name and entry of the first present owner of role, or nil.
function Bridges:FirstRoleOwner(role)
    for _, item in ipairs(roles[role] or {}) do
        if Detect(item.entry.detect, item.addon) then return item.entry.name, item.entry end
    end
    return nil
end

-- True when a frame rule matches. The name set is one table read; the other
-- matchers of the rule are tried in registration order.
function Bridges:MatchFrame(ruleName, frame, name)
    local rule = rules[ruleName]
    if not rule then return false end
    if type(name) == "string" and rule.set[name] then return true end
    for _, compiled in ipairs(rule.list) do
        if Matches(compiled, frame, name) then return true end
    end
    return false
end

-- The same rule tested by name alone: frame selectors and parent never match.
function Bridges:MatchName(ruleName, name)
    return self:MatchFrame(ruleName, nil, name)
end

-- Every literal name the rule's matchers list, in registration order, without
-- evaluating qualifiers.
function Bridges:GetRuleNames(ruleName)
    local copy = {}
    for index, name in ipairs(rules[ruleName] and rules[ruleName].names or {}) do copy[index] = name end
    return copy
end

-- True when an external mover marks the frame movable (a field equal to
-- true) or moving (a set field). Plain field reads, no pcall: hot path.
function Bridges.IsExternallyMovable(frame)
    if not frame then return false end
    for index = 1, #movableFields do
        if frame[movableFields[index]] == true then return true end
    end
    return false
end

function Bridges.IsExternallyMoving(frame)
    if not frame then return false end
    for index = 1, #movingFields do
        if frame[movingFields[index]] then return true end
    end
    return false
end

-- Stored keys of character settings that a character change clears.
function Bridges:GetCharacterResetKeys()
    local copy = {}
    for index, key in ipairs(resetKeys) do copy[index] = key end
    return copy
end

-- Stored key to declared default for every profile setting with a default.
function Bridges:GetSettingDefaults()
    local defaults = {}
    for _, own in pairs(settings) do
        for _, spec in pairs(own) do
            if spec.store == "profile" and spec.default ~= nil then defaults[spec.key] = spec.default end
        end
    end
    return defaults
end

local function SettingSpec(id, key, store)
    local own = settings[id]
    local spec = own and own[key]
    if spec and spec.store == store then return spec end
end

local function ReadSetting(spec, store)
    if not spec then return nil end
    local value
    if type(store) == "table" then value = store[spec.key] end
    if value == nil then return spec.default end
    return value
end

local function WriteSetting(spec, store, value)
    if not spec or type(store) ~= "table" then return false end
    store[spec.key] = value
    return true
end

-- ---------------------------------------------------------------------
-- Public services for bridges (Offhand.API)
-- ---------------------------------------------------------------------

function Offhand.API.RegisterBridge(id, bridge)
    return Bridges:Register(id, bridge)
end

-- Facts about an addon without a bridge object: it never appears in
-- Bridges:List() and needs no Refresh. Returns true, or false and one of
-- "id", "data".
function Offhand.API.RegisterAddonData(addon, data)
    return Bridges:MergeData(addon, data)
end

-- The one HUD layout transfer provider (an addon suite whose layout Offhand
-- can import). Returns true, or false and one of "provider", "duplicate".
function Offhand.API.RegisterHUDTransfer(provider)
    if type(provider) ~= "table" or not NonEmpty(provider.id) then return false, "provider" end
    if Offhand.HUDTransfer and Offhand.HUDTransfer ~= provider then return false, "duplicate" end
    Offhand.HUDTransfer = provider
    return true
end

-- Settings a bridge declared in data.settings, read from and written to the
-- same profile (Offhand's settings) or character (OffhandCharDB) key as
-- before, so nothing migrates. A read of an unset key gives the declared
-- default; an undeclared key or a key of the other store reads nil and does
-- not write. A write returns true when it was stored.
function Offhand.API.GetBridgeSetting(id, key)
    return ReadSetting(SettingSpec(id, key, "profile"), Offhand.db)
end

function Offhand.API.SetBridgeSetting(id, key, value)
    return WriteSetting(SettingSpec(id, key, "profile"), Offhand.db, value)
end

function Offhand.API.GetBridgeCharacterSetting(id, key)
    return ReadSetting(SettingSpec(id, key, "character"), _G.OffhandCharDB)
end

function Offhand.API.SetBridgeCharacterSetting(id, key, value)
    return WriteSetting(SettingSpec(id, key, "character"), _G.OffhandCharDB, value)
end

-- Core state a bridge needs, each read the way core itself reads it.
function Offhand.API.IsEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled and true or false
end

function Offhand.API.IsForeverClient()
    return Offhand.isForever == true
end

-- Blizzard owns keyboard input (cinematic, movie or lost player control).
function Offhand.API.IsInputReserved()
    return Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() or false
end

function Offhand.API.IsGamepadUIEnabled()
    return type(Offhand.IsGamepadUIEnabled) == "function" and Offhand:IsGamepadUIEnabled() or false
end

function Offhand.API.IsNativeGamepadInterface()
    local compatibility = Offhand.MainhandCompatibility
    return compatibility and type(compatibility.IsNativeGamepadInterface) == "function"
        and compatibility.IsNativeGamepadInterface() and true or false
end

-- True while Offhand is switching between a single window and a span.
function Offhand.API.IsGeometryTransitionActive()
    return Offhand._displayGeometryTransitionActive and true or false
end

function Offhand.API.IsLoggingOut()
    return Offhand._loggingOut and true or false
end

-- Offhand's own chat line, with its prefix and safe formatting.
function Offhand.API.Print(fmt, ...)
    if type(Offhand.Print) == "function" then Offhand:Print(fmt, ...) end
end

-- Offhand's localized text for key (the locale table's own fallback applies).
function Offhand.API.GetText(key)
    local L = Offhand.L
    if type(L) == "table" then return L[key] end
end

-- Shows one of Offhand's own popups: ShowPopup(popupKey, textArg1, textArg2, data).
function Offhand.API.ShowPopup(...)
    if type(Offhand.ShowPopup) == "function" then return Offhand:ShowPopup(...) end
end

-- Offhand's full layout pass; preserveScale keeps the player's UI scale.
-- True when the request reached the layout code.
function Offhand.API.RequestFullLayout(preserveScale)
    if type(Offhand.ApplyFullLayout) ~= "function" then return false end
    Offhand:ApplyFullLayout(preserveScale)
    return true
end

-- Re-applies workspace close and map maximize button hiding now.
function Offhand.API.RefreshWorkspaceChrome()
    local chrome = Offhand.WorkspaceChrome
    if not chrome or type(chrome.Refresh) ~= "function" then return false end
    chrome:Refresh()
    return true
end

-- Adds a named addon window to the workspace close button handling.
function Offhand.API.RegisterDynamicChromeFrame(name)
    local chrome = Offhand.WorkspaceChrome
    if not chrome or type(chrome.RegisterDynamicFrame) ~= "function" then return false end
    chrome:RegisterDynamicFrame(name)
    return true
end

-- The addon that owns world map geometry, or nil when Offhand does.
function Offhand.API.GetExternalMapOwner()
    local compatibility = Offhand.CanvasCompatibility
    if compatibility and type(compatibility.GetWorldMapExternalOwner) == "function" then
        return compatibility.GetWorldMapExternalOwner()
    end
end

-- The reload function to call from a live click, or nil where a reload must
-- be done by hand (Forever controller UI, or no reload API).
function Offhand.API.GetReloadFunction()
    if type(Offhand.GetReloadUIFunction) == "function" then return Offhand:GetReloadUIFunction() end
end

-- Offhand's UI control factory (UI/Controls.lua), or nil before it loads.
function Offhand.API.GetControls()
    return Offhand.UIControls
end

-- Viewport metrics while Offhand is enabled and spanned, else nil; the same
-- table addon options windows are fitted with.
function Offhand.API.GetOptionsMetrics()
    local viewport = Offhand.Viewport
    local metrics = Offhand.db and Offhand.db.enabled and viewport and viewport:GetMetrics()
    return metrics and metrics.isSpanned and metrics or nil
end

-- Private shared namespace for multi-file built-in bridges hosted inside
-- Offhand's own addon folder so they do not pollute Offhand's root table.
function Offhand.API.GetBridgeNamespace(id)
    if type(id) ~= "string" or id == "" then return {} end
    if not namespaces[id] then namespaces[id] = {} end
    return namespaces[id]
end

-- Account-wide persistent storage for built-in bridges under OffhandDB.bridges,
-- avoiding separate SavedVariables files.
function Offhand.API.GetBridgeStorage(id)
    if type(id) ~= "string" or id == "" then return {} end
    local account = _G.OffhandDB
    if type(account) == "table" then
        if type(account.bridges) ~= "table" then account.bridges = {} end
        if type(account.bridges[id]) ~= "table" then
            account.bridges[id] = fallbackStorage[id] or {}
        end
        fallbackStorage[id] = account.bridges[id]
        return account.bridges[id]
    end
    if not fallbackStorage[id] then fallbackStorage[id] = {} end
    return fallbackStorage[id]
end

function Offhand.API.FlushBridgeStorage()
    local persistence = Offhand.ForeverPersistence
    if persistence and type(persistence.SaveProfileSnapshot) == "function" then
        pcall(persistence.SaveProfileSnapshot, persistence, true)
    end
end

-- The game rectangle as it is now, in UIParent units from its bottom-left
-- corner: left, bottom, right, top, width, height, screenWidth, screenHeight,
-- isSpanned. The whole screen when Offhand is off or WoW is not spanned.
-- Unlike GetMainhandRect this is never a cached value.
function Offhand.API.GetGameRect()
    local geometry = Offhand.MainhandGeometry
    if geometry and geometry.GetCurrentRect then
        local ok, rect = pcall(geometry.GetCurrentRect)
        if ok and type(rect) == "table" then return rect end
    end
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    return {
        left = 0, bottom = 0, right = width, top = height,
        width = width, height = height,
        screenWidth = width, screenHeight = height,
        isSpanned = false,
    }
end

-- True when (x, y) in UIParent units from bottom-left lands inside Mainhand
-- or any active Offhand workspace region (false inside L/T-shaped dead voids).
function Offhand.API.IsPointVisible(x, y)
    if type(x) ~= "number" or type(y) ~= "number"
        or x ~= x or y ~= y or math.abs(x) == math.huge or math.abs(y) == math.huge then
        return false
    end
    local rect = Offhand.API.GetGameRect()
    if x >= rect.left and x <= rect.right and y >= rect.bottom and y <= rect.top then
        return true
    end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if type(metrics) ~= "table" or not metrics.isSpanned then return false end
    if type(metrics.workspaceRegions) == "table" then
        for _, r in ipairs(metrics.workspaceRegions) do
            if type(r) == "table" and type(r.x) == "number" and type(r.y) == "number"
                and type(r.width) == "number" and type(r.height) == "number"
                and x >= r.x and x <= r.x + r.width and y >= r.y and y <= r.y + r.height then
                return true
            end
        end
        return false
    end
    return type(metrics.workspaceLeft) == "number" and type(metrics.workspaceRight) == "number"
        and type(metrics.workspaceBottom) == "number" and type(metrics.workspaceTop) == "number"
        and x >= metrics.workspaceLeft and x <= metrics.workspaceRight
        and y >= metrics.workspaceBottom and y <= metrics.workspaceTop
end

-- Whether Offhand is placing the compact world map itself right now: it is
-- enabled and spanned, may manage panels, has a saved map position, and no
-- other map addon owns the geometry. A bridge for an addon with its own map
-- mover stands that mover aside while this is true.
function Offhand.API.OwnsWorldMapPlacement()
    local db, map = Offhand.db, _G.WorldMapFrame
    if not db or not db.enabled or not map or type(map.GetScale) ~= "function"
        or (map.IsForbidden and map:IsForbidden()) then return false end
    if map.IsMaximized and map:IsMaximized() then return false end
    local canvas = Offhand.Canvas
    if not canvas or not canvas.CanManagePanelsFromAddon
        or not canvas.CanManagePanelsFromAddon() then return false end
    local compatibility = Offhand.CanvasCompatibility
    if compatibility and compatibility.GetWorldMapExternalOwner() then return false end
    local persistence = Offhand.CanvasPersistence
    if not persistence or not (persistence.IsPosition(db.savedWorkspacePositions
        and db.savedWorkspacePositions.WorldMapFrame)
        or persistence.IsPosition(db.savedMainPositions and db.savedMainPositions.WorldMapFrame)) then
        return false
    end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return false end
    return true
end

-- True when Offhand is enabled and its popup and alert redirection is on. A
-- bridge that re-anchors a vendor's alerts releases them when this is false.
function Offhand.API.IsPopupRedirectEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled and db.seamRedirect and true or false
end

-- Mainhand's share of the physical window height (game pixel height over
-- physical height) while WoW is spanned, else 1. A bridge multiplies a
-- vendor's native frame scale by it to keep the frame's on-screen size.
function Offhand.API.GetMainhandPixelHeightRatio()
    local viewport = Offhand.Viewport
    if not viewport or not viewport.GetMetrics then return 1 end
    local ok, metrics = pcall(viewport.GetMetrics, viewport)
    if not ok or not metrics or metrics.isSpanned ~= true then return 1 end
    local canvasHeight = tonumber(metrics.physicalHeight)
    local gameHeight = tonumber(metrics.gamePixelHeight)
    if not canvasHeight or canvasHeight <= 0 or not gameHeight or gameHeight <= 0 then
        return 1
    end
    return gameHeight / canvasHeight
end

-- Queue a tooltip-like frame for Offhand's popup bounds pass, which fits it
-- inside the game rectangle on the next frame while popup redirection is on.
-- True when it was queued.
function Offhand.API.QueuePopupBounds(frame)
    local bounds = Offhand.PopupBounds
    if not frame or not bounds or type(bounds.Queue) ~= "function" then return false end
    return pcall(bounds.Queue, bounds, frame) == true
end

-- Where Offhand puts group loot roll pop-ups: the centre of a slot of the
-- given height, in UIParent units from its bottom-left corner. The player's
-- own Group Loot Rolls position if one was saved, else the middle of the game
-- rectangle, 190 HUD units up. Nil when the game rectangle is the whole screen.
function Offhand.API.GetGroupLootSpot(height)
    local rect = Offhand.API.GetGameRect()
    if rect.left <= 0 and rect.right >= rect.screenWidth
        and rect.bottom <= 0 and rect.top >= rect.screenHeight then return nil end
    local db = type(Offhand.db) == "table" and Offhand.db or nil
    local position = db and db.groupLootPosition
    local x = type(position) == "table" and tonumber(position.x) or nil
    local y = type(position) == "table" and tonumber(position.y) or nil
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
        return rect.left + (rect.right - rect.left) * x, rect.bottom + (rect.top - rect.bottom) * y
    end
    local hud = 1
    if db and Offhand.Viewport and Offhand.Viewport.GetMetrics then
        local ok, metrics = pcall(Offhand.Viewport.GetMetrics, Offhand.Viewport)
        if ok and type(metrics) == "table" and type(metrics.hudScale) == "number"
            and metrics.hudScale > 0 then hud = metrics.hudScale end
    end
    return (rect.left + rect.right) / 2,
        rect.bottom + 190 * hud + (type(height) == "number" and height or 100) / 2
end

-- Active Offhand workspace monitor rectangles in UIParent units from
-- bottom-left. Empty when Offhand is disabled or the client is not spanned.
function Offhand.API.GetWorkspaceRects()
    local rects = {}
    if not Offhand.db or not Offhand.db.enabled then return rects end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if type(metrics) ~= "table" or not metrics.isSpanned then return rects end
    if type(metrics.workspaceRegions) == "table" and #metrics.workspaceRegions > 0 then
        for _, r in ipairs(metrics.workspaceRegions) do
            if type(r) == "table" and type(r.x) == "number" and type(r.y) == "number"
                and type(r.width) == "number" and type(r.height) == "number"
                and r.width > 0 and r.height > 0 then
                rects[#rects + 1] = {
                    id = r.id,
                    left = r.x, bottom = r.y,
                    right = r.x + r.width, top = r.y + r.height,
                    width = r.width, height = r.height,
                }
            end
        end
        return rects
    end
    if type(metrics.workspaceLeft) == "number" and type(metrics.workspaceRight) == "number"
        and type(metrics.workspaceBottom) == "number" and type(metrics.workspaceTop) == "number"
        and metrics.workspaceRight > metrics.workspaceLeft and metrics.workspaceTop > metrics.workspaceBottom then
        rects[1] = {
            id = "WORKSPACE",
            left = metrics.workspaceLeft, bottom = metrics.workspaceBottom,
            right = metrics.workspaceRight, top = metrics.workspaceTop,
            width = metrics.workspaceRight - metrics.workspaceLeft,
            height = metrics.workspaceTop - metrics.workspaceBottom,
        }
    end
    return rects
end

-- True when frame's current center sits on an active Offhand workspace monitor.
function Offhand.API.IsFrameOnWorkspace(frame)
    if not frame or type(frame) ~= "table" then return false end
    if Offhand.Canvas and type(Offhand.Canvas.IsFrameOnWorkspace) == "function" then
        local ok, onWorkspace = pcall(Offhand.Canvas.IsFrameOnWorkspace, frame)
        if ok then return onWorkspace == true end
    end
    local rects = Offhand.API.GetWorkspaceRects()
    if #rects == 0 then return false end
    local ok, cx, cy = pcall(function()
        if frame.IsForbidden and frame:IsForbidden() then return nil end
        local left, bottom = frame.GetLeft and frame:GetLeft(), frame.GetBottom and frame:GetBottom()
        local w, h = frame.GetWidth and frame:GetWidth(), frame.GetHeight and frame:GetHeight()
        if type(left) ~= "number" or type(bottom) ~= "number" or type(w) ~= "number" or type(h) ~= "number" then
            return nil
        end
        local fs = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local ps = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if fs <= 0 or ps <= 0 then return nil end
        local k = fs / ps
        return (left + w / 2) * k, (bottom + h / 2) * k
    end)
    if not ok or type(cx) ~= "number" or type(cy) ~= "number" then return false end
    for _, r in ipairs(rects) do
        if cx >= r.left and cx <= r.right and cy >= r.bottom and cy <= r.top then return true end
    end
    return false
end

-- True when Offhand is configured to keep Offhand workspace panels open on Escape.
function Offhand.API.IsEscapeProtectionEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled == true
        and db.persistentWorkspacePanels ~= false
end

-- True when Offhand is configured to keep and restore Offhand workspace panels
-- across Escape and UI reloads.
function Offhand.API.IsWorkspacePersistenceEnabled()
    local db = Offhand.db
    return type(db) == "table" and db.enabled == true
        and db.persistentWorkspacePanels ~= false
        and db.restoreWorkspaceOnReload ~= false
end

-- Notify Offhand after a bridged addon's drag bar moves a standard Blizzard
-- panel so Offhand records workspace/Mainhand ownership and reload open state.
function Offhand.API.NotifyExternalPanelMoved(frame)
    local canvas = Offhand.Canvas
    if not canvas or type(canvas.RecordExternalPanelDrag) ~= "function" then return false end
    local ok, recorded = pcall(canvas.RecordExternalPanelDrag, canvas, frame)
    return ok and recorded == true
end

-- Clear Offhand's workspace ownership for a standard Blizzard panel when a
-- bridged addon resets that panel back to Blizzard's default anchor.
function Offhand.API.ForgetExternalWorkspacePanel(name)
    local canvas = Offhand.Canvas
    if not canvas or type(canvas.ForgetExternalWorkspacePanel) ~= "function" then return false end
    local ok, cleared = pcall(canvas.ForgetExternalWorkspacePanel, canvas, name)
    return ok and cleared == true
end
