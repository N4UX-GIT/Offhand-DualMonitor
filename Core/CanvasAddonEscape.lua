-- Narrow Forever adapters for ordinary addon-owned windows. Native UIPanel
-- registrations, vendor scripts, geometry and explicit close actions stay owned
-- by their creators. See docs/ADDON-WINDOW-TIMING-20261107.md for source scope.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasAddonEscape = Adapter
local catalog = Offhand.AddonWindowCatalog or {}
local states = setmetatable({}, {__mode="k"})
local MAX_SPECIAL, MAX_ROOTS = 256, 64
local openerHooks = setmetatable({}, {__mode="k"})
-- Which roots are addon windows, how they open and close, and which frames
-- their addons keep for themselves come from the bridges: their window index
-- (data.windows) and the frame rule vendorGameplay.

local function Loaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    return type(query) == "function" and query(name) and true or false
end

local function Source(frame)
    if not frame.GetSourceLocation then return nil end
    local value = frame:GetSourceLocation()
    -- ObjectDebug access can return a secret. Never compare or format it first.
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) ~= "string" then return nil end
    return value:gsub("\\", "/"):lower()
end

local function OrdinaryRoot(frame, parent)
    return frame and frame.IsShown and frame.GetParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and frame:GetParent() == (parent or UIParent)
end

-- Frames an addon positions and shows itself (frame rule vendorGameplay):
-- Offhand neither saves nor gathers their placement.
function Adapter:IsVendorGameplayFrame(frame, name)
    if issecretvalue and issecretvalue(name) then return false end
    local bridges = Offhand.Bridges
    return bridges and bridges:MatchFrame("vendorGameplay", frame, name) or false
end

-- The services RetireStalePlacements hands the bridges, over the profile of
-- the refresh in progress.
local retireDb, retireOpenChanged
local retireServices = {
    HasPlacement = function(name)
        local main, workspace, open = retireDb.savedMainPositions, retireDb.savedWorkspacePositions,
            retireDb.openWorkspacePanels
        return ((main and main[name]) or (workspace and workspace[name]) or (open and open[name])) and true or false
    end,
    IsVendorGameplayFrame = function(frame, name) return Adapter:IsVendorGameplayFrame(frame, name) end,
    ForgetPosition = function(name)
        local main, workspace = retireDb.savedMainPositions, retireDb.savedWorkspacePositions
        local persistence = Offhand.ForeverPersistence
        if main then main[name] = nil end
        if workspace and workspace[name] then
            workspace[name] = nil
            if persistence and persistence.ClearPosition then persistence:ClearPosition(name) end
        end
    end,
    ForgetOpen = function(name)
        local open = retireDb.openWorkspacePanels
        if open and open[name] then
            open[name] = nil
            retireOpenChanged = true
        end
    end,
}

local function RetireStalePlacements(db)
    local bridges = Offhand.Bridges
    if not bridges then return end
    retireDb, retireOpenChanged = db, false
    bridges:RetireStalePlacements(retireServices)
    local open, openChanged = db.openWorkspacePanels, retireOpenChanged
    retireDb, retireOpenChanged = nil, nil
    local persistence = Offhand.ForeverPersistence
    if openChanged and persistence and persistence.SaveOpenPanels then persistence:SaveOpenPanels(open) end
end

-- The bridges identify the addon roots their window index names; an exact
-- sourceless name is answered before the source location is read.
local function Identify(frame, name)
    if not OrdinaryRoot(frame) then return nil end
    if name == "OffhandFloatingConfigFrame" then
        local options = Offhand.Options
        return options and options.GetConfigFrame and options:GetConfigFrame() == frame and "Offhand" or nil
    end
    local bridges = Offhand.Bridges
    if not bridges then return nil end
    return bridges:IdentifyWindow(frame, name, Source)
end

function Adapter:CanLearnPlacement(frame, name, owner, file)
    local identified, role = Identify(frame, name)
    local window = identified == owner and catalog[owner] and catalog[owner][role]
    if window and window.learnPlacementFile == file then return true end
    return Offhand.Bridges and Offhand.Bridges:CanLearnPlacement(frame, name, owner, file) or false
end

local function ControllerOwned()
    local compatibility = Offhand.MainhandCompatibility
    return (Offhand.Bridges and Offhand.Bridges:HasRole("hud.controller"))
        or (compatibility and compatibility.IsNativeGamepadInterface
        and compatibility.IsNativeGamepadInterface())
end

local function InstallOpeners()
    if not hooksecurefunc then return end
    local function AfterOpen() Adapter:Refresh() end
    local function Observe(owner, key)
        if not owner or type(owner[key]) ~= "function" then return end
        local hooks = openerHooks[owner]
        if not hooks then hooks = {}; openerHooks[owner] = hooks end
        if hooks[key] == owner[key] then return end
        hooksecurefunc(owner, key, AfterOpen)
        hooks[key] = owner[key]
    end
    -- These public open transactions cover lazy first creation, before there is
    -- a root to observe. No shared CreateFrame/ShowUIPanel/Escape hook is used.
    for _, windows in pairs(catalog) do
        for _, window in pairs(windows) do
            if type(window) == "table" and window.close == "workspace-special-windows" and window.opener then
                Observe(SlashCmdList, window.opener)
            end
        end
    end
    local bridges = Offhand.Bridges
    if bridges then
        bridges:ObserveWindowOpeners("slash", Observe)
        bridges:ObserveWindowOpeners("globals", Observe)
    end
    Observe(Offhand.Options, "Open")
    if not bridges then return end
    bridges:ObserveWindowOpeners("methods", Observe)
    if bridges:HasWindowOpenerLinks() and EventRegistry and EventRegistry.RegisterCallback
        and not Adapter.linkObserved then
        EventRegistry:RegisterCallback("SetItemRef", function(_, link)
            if issecretvalue and issecretvalue(link) then return end
            if bridges:IsWindowOpenerLink(link) then AfterOpen() end
        end, Adapter)
        Adapter.linkObserved = true
    end
end

local function ObserveRoot(frame, state)
    if state.observed or not frame.HookScript then return end
    -- Only source-identified ordinary addon roots reach this path. Keep state
    -- outside the vendor tree and run after its own layout/visibility scripts.
    local function Changed() Adapter:Refresh() end
    state.scripts = state.scripts or {}
    for _, key in ipairs({"OnShow", "OnHide", "OnDragStop"}) do
        if not state.scripts[key] and frame:HookScript(key, Changed) ~= false then
            state.scripts[key] = true
        end
    end
    local bridges = Offhand.Bridges
    if bridges and bridges:WindowUsesHeaderDrag(state.owner) and not state.scripts.headerDrag then
        local header = frame.header
        if header and header.GetParent and header:GetParent() == frame and header.HookScript
            and not (header.IsForbidden and header:IsForbidden())
            and not (header.IsProtected and header:IsProtected())
            and header:HookScript("OnDragStop", Changed) ~= false then
            state.scripts.headerDrag = true
        end
    end
    state.observed = state.scripts.OnShow and state.scripts.OnHide and state.scripts.OnDragStop
end

function Adapter:VisitRoots(callback)
    if not Offhand.isForever or ControllerOwned() then return end
    for frame, state in pairs(states) do
        local ok, valid = pcall(function()
            return _G[state.name] == frame and OrdinaryRoot(frame)
                and (state.owner == "Offhand" or Loaded(state.owner))
        end)
        if ok and valid then callback(frame, state.name) end
    end
end

function Adapter:GetCloseButtons(frame)
    local state = states[frame]
    if not state or not OrdinaryRoot(frame) then return {} end
    if state.owner == "Offhand" then return {frame.workspaceCloseButton} end
    local bridges = Offhand.Bridges
    return bridges and bridges:GetWindowCloseButtons(frame, state.owner, state.name) or {}
end

local function Release(frame, state)
    if not state.removed then return end
    -- Restore only entries we actually removed and only while the global still
    -- resolves to the same root. Vendor reinsertion takes precedence.
    if _G[state.name] == frame then
        local present = false
        for _, name in ipairs(UISpecialFrames) do
            if name == state.name then present = true; break end
        end
        if not present then
            table.insert(UISpecialFrames, math.min(state.index or #UISpecialFrames + 1,
                #UISpecialFrames + 1), state.name)
        end
    end
    state.removed, state.index = nil, nil
end

local function Exclude(state)
    for index = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[index] == state.name then
            state.index = index
            table.remove(UISpecialFrames, index)
            state.removed = true
        end
    end
end

function Adapter:SetSpecialFrameExcluded(frame, state, excluded, parent)
    if InCombatLockdown and InCombatLockdown() then return end
    if type(UISpecialFrames) ~= "table" or #UISpecialFrames > MAX_SPECIAL then return end
    if excluded and _G[state.name] == frame and OrdinaryRoot(frame, parent) then
        Exclude(state)
    else
        Release(frame, state)
    end
end

local function Refresh()
    if InCombatLockdown and InCombatLockdown() then return false end
    if type(UISpecialFrames) ~= "table" or #UISpecialFrames > MAX_SPECIAL then return false end
    local db = Offhand.db
    local enabled = Offhand.isForever and db and db.enabled
        and not ControllerOwned() and not Offhand._displayGeometryTransitionActive
    if enabled then
        -- Older Gather passes saved some vendor anchors and also registered
        -- them for Escape. Installation reloads the Lua-only registry. Retire
        -- the records that can recreate our old placement after that reload.
        RetireStalePlacements(db)
        InstallOpeners()
    end
    if enabled then
        local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
        enabled = metrics and metrics.isSpanned
    end
    if not enabled then
        -- Releasing registration does not inspect controller-owned frame trees.
        for frame, state in pairs(states) do Release(frame, state) end
        return false
    end
    local count = 0
    for _ in pairs(states) do count = count + 1 end
    -- UISpecialFrames is the bounded source of candidates, never the global
    -- namespace or the UIParent child tree. Anonymous addon roots need their
    -- source metadata as well as their specific configuration-panel shape.
    for _, name in ipairs(UISpecialFrames) do
        if type(name) == "string" then
            local frame = _G[name]
            if frame and not states[frame] and count < MAX_ROOTS then
                local ok, owner, role = pcall(Identify, frame, name)
                if ok and owner then
                    local windows = catalog[owner]
                    local window = windows and windows[role]
                    if owner == "Offhand" or (window and window.close == "workspace-special-windows") then
                        states[frame] = {name=name, owner=owner}
                        count = count + 1
                    end
                end
            end
        end
    end
    local active = false
    for frame, state in pairs(states) do
        if _G[state.name] == frame then
            pcall(function() if OrdinaryRoot(frame) then ObserveRoot(frame, state) end end)
        end
        local ok, keep = pcall(function()
            return db.persistentWorkspacePanels ~= false
                and _G[state.name] == frame and (state.owner == "Offhand" or Loaded(state.owner))
                and OrdinaryRoot(frame) and frame:IsShown()
                and Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace
                and Offhand.Canvas.IsFrameOnWorkspace(frame)
        end)
        if ok and keep then
            Exclude(state)
            active = true
        else
            Release(frame, state)
        end
    end
    return active
end

function Adapter:Refresh()
    if self.refreshing then return false end
    self.refreshing = true
    local ok, active = pcall(Refresh)
    self.refreshing = false
    local chrome = Offhand.WorkspaceChrome
    if Offhand.isForever and Offhand.db and not ControllerOwned() and chrome and chrome.Refresh then
        chrome:Refresh()
    end
    return ok and active or false
end
