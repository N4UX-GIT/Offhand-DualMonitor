-- Narrow Forever adapters for ordinary addon-owned windows. Native UIPanel
-- registrations, vendor scripts, geometry and explicit close actions stay owned
-- by their creators. See docs/ADDON-WINDOW-TIMING-20261107.md for source scope.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasAddonEscape = Adapter
local states = setmetatable({}, {__mode="k"})
local MAX_SPECIAL, MAX_ROOTS = 256, 64
local openerHooks = setmetatable({}, {__mode="k"})

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

local function OrdinaryRoot(frame)
    return frame and frame.IsShown and frame.GetParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and frame:GetParent() == UIParent
end

local function Identify(frame, name)
    if not OrdinaryRoot(frame) then return nil end
    if name == "OffhandFloatingConfigFrame" then
        local options = Offhand.Options
        return options and options.GetConfigFrame and options:GetConfigFrame() == frame and "Offhand" or nil
    end
    if name == "ForeverDungeonJournalFrame" and Loaded("ForeverDungeonJournal") then
        return "ForeverDungeonJournal"
    end
    local source = Source(frame)
    if not source then return nil end
    if name:match("^PlatynatorCustomiseDialog[%w_]+$") and Loaded("Platynator")
        and source:find("/platynator/customisedialog/main.lua:", 1, true)
        and frame.Tabs and frame.CloseButton then return "Platynator" end
    if #name ~= 17 or not name:match("^F%w+$") or not frame.GetFrameStrata
        or frame:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then return nil end
    for _, vendor in ipairs({"Leatrix_Maps", "Leatrix_Plus", "Leatrix_Sounds"}) do
        local lower = vendor:lower()
        if Loaded(vendor) and source:find("/" .. lower .. "/" .. lower .. ".lua:", 1, true) then
            if vendor == "Leatrix_Sounds" then
                if frame.cb and frame.mainTex and frame.footTex then return vendor end
            elseif (frame.mt and frame.v) or (frame.c and frame.r and frame.b) then
                return vendor
            end
        end
    end
end

local function ControllerOwned()
    local compatibility = Offhand.MainhandCompatibility
    return _G.ConsolePort ~= nil or (compatibility and compatibility.IsNativeGamepadInterface
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
    for _, key in ipairs({"Leatrix_Maps", "Leatrix_Plus", "Leatrix_Sounds",
        "Platynator", "FOREVERDUNGEONJOURNAL"}) do Observe(SlashCmdList, key) end
    Observe(_G, "Platynator_AddonCompartmentCallback")
    Observe(Offhand.Options, "Open")
    if Loaded("Platynator") and EventRegistry and EventRegistry.RegisterCallback
        and not Adapter.linkObserved then
        EventRegistry:RegisterCallback("SetItemRef", function(_, link)
            if issecretvalue and issecretvalue(link) then return end
            if link == "addon:platynatorsettings" then AfterOpen() end
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
    if state.owner == "Platynator" then return {frame.CloseButton} end
    if state.owner == "ForeverDungeonJournal" then return {frame.closeButton} end
    if state.owner == "Offhand" then return {frame.workspaceCloseButton} end
    if state.owner == "Leatrix_Sounds" then return {frame.cb} end
    if frame.c then return {frame.c} end
    -- Maps/Plus main X buttons are anonymous helper-created children. Inspect
    -- only this verified root's bounded direct children, not its whole tree.
    if not frame.GetNumChildren or frame:GetNumChildren() > 128 or not frame.GetChildren then return {} end
    local result = {}
    for _, child in ipairs({frame:GetChildren()}) do
        if child and not (child.IsForbidden and child:IsForbidden())
            and not (child.IsProtected and child:IsProtected())
            and child.GetObjectType and child:GetObjectType() == "Button"
            and child.GetParent and child:GetParent() == frame and child.GetPoint then
            local point, relative, relativePoint, x, y = child:GetPoint(1)
            local source = Source(child)
            local vendor = state.owner:lower()
            if point == "TOPRIGHT" and relative == frame and relativePoint == "TOPRIGHT"
                and x == 0 and y == 0 and source
                and source:find("/" .. vendor .. "/" .. vendor .. ".lua:", 1, true)
                -- Native scaled dimensions contain small floating-point drift.
                and child.GetWidth and math.abs(child:GetWidth() - 30) < .01
                and child.GetHeight and math.abs(child:GetHeight() - 30) < .01 then
                result[#result + 1] = child
            end
        end
    end
    return result
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

local function Refresh()
    if InCombatLockdown and InCombatLockdown() then return false end
    if type(UISpecialFrames) ~= "table" or #UISpecialFrames > MAX_SPECIAL then return false end
    local db = Offhand.db
    local enabled = Offhand.isForever and db and db.enabled
        and not ControllerOwned() and not Offhand._displayGeometryTransitionActive
    if enabled then InstallOpeners() end
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
    -- namespace or the UIParent child tree. Anonymous Leatrix roots need their
    -- source metadata as well as their specific configuration-panel shape.
    for _, name in ipairs(UISpecialFrames) do
        if type(name) == "string" then
            local frame = _G[name]
            if frame and not states[frame] and count < MAX_ROOTS then
                local ok, owner = pcall(Identify, frame, name)
                if ok and owner then
                    states[frame] = {name=name, owner=owner}
                    count = count + 1
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
            for index = #UISpecialFrames, 1, -1 do
                if UISpecialFrames[index] == state.name then
                    state.index = index
                    table.remove(UISpecialFrames, index)
                    state.removed = true
                end
            end
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
