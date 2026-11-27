-- Addon bag replacements own their visibility and layout. Track only known root
-- backpack windows, never item/button pools, bank windows or settings panels.
local _, Offhand = ...
local Bags = {
    paused = true,
    frames = {},
    escapeRegistrations = {},
    generation = 0,
    restoring = false,
}
Offhand.BagPersistence = Bags

local function CanOpenBagsFromAddon()
    return not Offhand.Canvas or not Offhand.Canvas.CanManagePanelsFromAddon
        or Offhand.Canvas.CanManagePanelsFromAddon()
end

local function TrackEnabled()
    local db = Offhand.db
    return db and db.enabled and db.persistentWorkspacePanels ~= false
end

local function DiscoverEnabled()
    local db = Offhand.db
    return TrackEnabled() or (Offhand.isForever and db and db.enabled and db.keepBagToggleOpen == true)
end

local function ReloadEnabled()
    local db = Offhand.db
    return TrackEnabled() and db.restoreWorkspaceOnReload ~= false
end

local function InputReserved()
    return Offhand.IsBlizzardInputReserved
        and Offhand:IsBlizzardInputReserved() or false
end

-- Bag providers (bridge.bagProvider, docs/BRIDGES.md) own the persistent
-- backpack roots this engine tracks. They are asked in provider order, each
-- call one pcall through Bridges:CallBagProvider.
local NO_PROVIDERS = {}

local function Providers()
    local bridges = Offhand.Bridges
    return bridges and bridges.GetBagProviders and bridges:GetBagProviders() or NO_PROVIDERS
end

local function CallProvider(entry, method, ...)
    return Offhand.Bridges:CallBagProvider(entry, method, ...)
end

-- The first provider, in provider order, whose method(...) returns a true value.
local function FirstProvider(method, ...)
    for _, entry in ipairs(Providers()) do
        local ok, result = CallProvider(entry, method, ...)
        if ok and result then return entry end
    end
    return nil
end

-- The provider that restores this root itself through its own show and
-- Escape paths (its GetManagedRoot() names the root).
local function ManagedEntry(name)
    if name == nil then return nil end
    for _, entry in ipairs(Providers()) do
        local ok, root = CallProvider(entry, "GetManagedRoot")
        if ok and root ~= nil and root == name then return entry end
    end
    return nil
end

-- The saved root's provider records a deliberate close by the player.
local function ExplicitlyClosed(name)
    return FirstProvider("ExplicitlyClosed", name) ~= nil
end

-- The provider whose root family this name belongs to, judged by name alone
-- (IsRootName; child regions named after a root match as well).
local function NameOwner(name)
    return FirstProvider("IsRootName", name)
end

-- Two providers replaced the shared bag toggle global (ClaimsSharedToggle),
-- so its current target cannot be inferred. Claims are asked in provider
-- order and the test stops as soon as its answer is known.
local function HasSharedToggleConflict()
    local providers = Providers()
    local remaining = 0
    for _, entry in ipairs(providers) do
        if type(entry.provider.ClaimsSharedToggle) == "function" then remaining = remaining + 1 end
    end
    local claims = 0
    for _, entry in ipairs(providers) do
        if type(entry.provider.ClaimsSharedToggle) == "function" then
            if claims + remaining < 2 then return false end
            remaining = remaining - 1
            local ok, claimed = CallProvider(entry, "ClaimsSharedToggle")
            if ok and claimed then
                claims = claims + 1
                if claims >= 2 then return true end
            end
        end
    end
    return false
end

-- The providers whose roots keep their own native Escape registration, so
-- Escape can hide them directly (IsDirectEscapeRoot), in their escapeOrder.
-- Rebuilt only when the provider list changes.
local escapeEntries, escapeSource, escapeCount = {}, nil, -1

local function EscapeEntries()
    local providers = Providers()
    if providers == escapeSource and #providers == escapeCount then return escapeEntries end
    local ranked = {}
    for index, entry in ipairs(providers) do
        local provider = entry.provider
        if type(provider.IsDirectEscapeRoot) == "function" then
            ranked[#ranked + 1] = { entry = entry, index = index,
                order = type(provider.escapeOrder) == "number" and provider.escapeOrder or math.huge }
        end
    end
    table.sort(ranked, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.index < b.index
    end)
    escapeEntries, escapeSource, escapeCount = {}, providers, #providers
    for index, item in ipairs(ranked) do escapeEntries[index] = item.entry end
    return escapeEntries
end

-- The first provider, in escape order, whose IsDirectEscapeRoot(name, frame) holds.
local function DirectEscapeOwner(name, frame)
    for _, entry in ipairs(EscapeEntries()) do
        local ok, result = CallProvider(entry, "IsDirectEscapeRoot", name, frame)
        if ok and result then return entry end
    end
    return nil
end

-- The provider owning a persistent root: the first whose IsRoot(name, frame)
-- holds.
local function RootOwner(name, frame)
    return FirstProvider("IsRoot", name, frame)
end

-- A persistent root that keeps its own native anchor and Escape registration
-- (its provider sets selfAnchored), so workspace restoration and popup
-- ownership leave both to the vendor.
function Bags.IsSelfAnchoredRoot(frame, name)
    for _, entry in ipairs(Providers()) do
        if entry.provider.selfAnchored == true then
            local ok, root = CallProvider(entry, "IsRoot", name, frame)
            if ok and root then return true end
        end
    end
    return false
end

-- The first provider, in provider order, that sets flag and whose root
-- family (IsRootName) this name belongs to. flag "rebuildsAnchors": its addon
-- can briefly clear a root's anchors during a bag rebuild; "reportsRootHide":
-- on Forever its addon reports its root's actual hide.
local function FlaggedNameOwner(flag, name)
    for _, entry in ipairs(Providers()) do
        if entry.provider[flag] == true then
            local ok, owned = CallProvider(entry, "IsRootName", name)
            if ok and owned then return entry end
        end
    end
    return nil
end

local function IsSpanned()
    local viewport = Offhand.Viewport
    if not viewport or not viewport.GetMetrics then return true end
    local metrics = viewport:GetMetrics()
    return metrics and metrics.isSpanned == true
end

-- The custom bag workspace record: the open position of the replacement bag
-- root on the workspace, stored under the key a bag bridge declares for the
-- setting customBagWorkspacePanels. Without that bridge there is no record.
local function RecordKey()
    local bridges = Offhand.Bridges
    return bridges and bridges:GetSettingKey("customBagWorkspacePanels") or nil
end

local function GetRecord(db)
    local key = RecordKey()
    return key and db[key] or nil
end

local function SetRecord(db, value)
    local key = RecordKey()
    if key then db[key] = value end
end

function Bags:ForgetOpenSnapshot(name)
    if not Offhand.db then return end
    local saved = GetRecord(Offhand.db)
    if type(saved) ~= "table" then return end
    if name then saved[name] = nil else wipe(saved) end
end

function Bags:GetSavedPosition()
    local saved = Offhand.db and GetRecord(Offhand.db) or {}
    -- A root its provider restores itself wins over any other saved root.
    for _, entry in ipairs(Providers()) do
        local ok, managed = CallProvider(entry, "GetManagedRoot")
        local position = ok and managed ~= nil and saved[managed]
        if type(position) == "table" and position.x and position.y then
            return managed, position
        end
    end
    for name, position in pairs(saved) do
        if type(position) == "table" and position.x and position.y then
            return name, position
        end
    end
end

function Bags:GetVisibleFrame(name)
    if name then
        local frame = self.frames[name]
        return frame and frame:IsVisible() and frame or nil
    end
    for _, frame in pairs(self.frames) do
        if frame.IsVisible and frame:IsVisible() then return frame end
    end
end

-- The provider whose RoutesInventoryBindings() holds, the first in provider
-- order: its addon routes the stock inventory bindings (the backpack, all
-- bags and the numbered bag keys) through its own root. Called directly: the
-- workspace toggle keys poll it inside their own pcall.
local function BindingProvider()
    for _, entry in ipairs(Providers()) do
        local routes = entry.provider.RoutesInventoryBindings
        if type(routes) == "function" and routes() then return entry end
    end
    return nil
end

-- The same question outside that pcall (each provider asked in its own).
function Bags:RoutesInventoryBindings()
    return FirstProvider("RoutesInventoryBindings") ~= nil
end

-- That provider's visible root (IsRoot), or nil.
function Bags:GetVisibleBindingRoot()
    local entry = BindingProvider()
    local isRoot = entry and entry.provider.IsRoot
    if type(isRoot) ~= "function" then return nil end
    for name, frame in pairs(self.frames) do
        if _G[name] == frame and not (frame.IsForbidden and frame:IsForbidden())
            and isRoot(name, frame) and frame:IsVisible() then return frame end
    end
end

local function CopyPosition(position)
    local copy = {}
    for key, value in pairs(position or {}) do copy[key] = value end
    return copy
end

-- Beta 18 stored the bag's bottom edge in `y`, while Canvas workspace records
-- use the top edge. Upgrade an old snapshot once the real root exists and its
-- rendered height/scale can be measured.
function Bags:NormalizePosition(position, frame)
    if type(position) ~= "table" or not position.x or not position.y then return position end
    if position.coordinateVersion == 2 then return position end
    local normalized = CopyPosition(position)
    local frameScale = frame and frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local height = frame and frame.GetHeight and frame:GetHeight() or 0
    if parentScale > 0 then normalized.y = normalized.y + height * frameScale / parentScale end
    normalized.coordinateVersion = 2
    return normalized
end

local function UpdateBagEscapeRegistration(frame, name, supported, parent, proxy)
    local adapter = Offhand.CanvasAddonEscape
    if not Offhand.isForever or not (adapter and adapter.SetSpecialFrameExcluded)
        or InCombatLockdown() then return end
    local registration = proxy or frame
    local state = Bags.escapeRegistrations[registration]
    local canvas = Offhand.Canvas
    local canPreserve = supported and not Bags.paused and TrackEnabled() and IsSpanned()
        and CanOpenBagsFromAddon() and not InputReserved()
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
    local exclude = false
    if canPreserve and frame:IsVisible() and canvas and canvas.IsFrameOnWorkspace then
        if state and state.removed
            and (not frame:GetLeft() or (frame.GetBottom and not frame:GetBottom()))
            and FlaggedNameOwner("rebuildsAnchors", name) then
            -- The vendor can briefly clear its anchors during a bag rebuild.
            -- That intermediate rectangle does not move the bag to Mainhand.
            exclude = true
        else
            local ok, workspace = pcall(canvas.IsFrameOnWorkspace, frame)
            exclude = ok and workspace == true
        end
    end
    if not state and not exclude then return end
    state = state or { name = name }
    -- Closing the protected bag with B can also open the parked native bag.
    local closedWorkspaceBag = canPreserve and state.removed and not frame:IsShown()
    -- Options and Escape both close UISpecialFrames before proceeding. Leave
    -- the visible Offhand backpack out so Blizzard can reach its target handler
    -- and the bag addon retains its own explicit close controls.
    adapter:SetSpecialFrameExcluded(registration, state, exclude, parent)
    Bags.escapeRegistrations[registration] = state.removed and state or nil
    return closedWorkspaceBag or (exclude and state.removed)
end

local function CloseParkedNativeBags(parkingParent, frameCount, lastBagID)
    if not parkingParent or parkingParent == UIParent or parkingParent == _G.ContainerFrameContainer
        or (parkingParent.IsForbidden and parkingParent:IsForbidden()) or parkingParent:IsShown() then return end

    -- The bag binding can leave a parked native root logically open. Clear
    -- its state before Escape, outside the Blizzard input transaction.
    local combined = _G.ContainerFrameCombinedBags
    if CloseBackpack and combined and not (combined.IsForbidden and combined:IsForbidden())
        and combined:GetParent() == parkingParent and combined:IsShown() then
        CloseBackpack()
    end
    if not CloseBag then return end
    for index = 1, frameCount do
        local container = _G["ContainerFrame" .. index]
        if container and not (container.IsForbidden and container:IsForbidden())
            and container:GetParent() == parkingParent and container:IsShown()
            and container.GetBagID then
            local id = container:GetBagID()
            if not lastBagID or (type(id) == "number" and id >= 0 and id <= lastBagID) then
                CloseBag(id)
            end
        end
    end
end

local function IsGameMenuBagClose(stack)
    return type(stack) == "string"
        and stack:find("Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua", 1, true)
        and (stack:find("in function 'CloseAllBags'", 1, true)
            or stack:find("in function 'GameMenuFrame_Show'", 1, true))
end

local function IsSettingsBagClose(stack)
    if type(stack) ~= "string" then return false end
    if stack:find("Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua", 1, true)
        and (stack:find("in function 'ShowUIPanel'", 1, true)
            or stack:find("in function 'CloseAllBags'", 1, true)
            or stack:find("in function 'CloseAllWindows'", 1, true)
            or stack:find("in function 'ToggleAllBags'", 1, true)) then
        return true
    end
    if stack:find("Blizzard_GameMenu/", 1, true)
        and (stack:find("in function 'CloseAllBags'", 1, true)
            or stack:find("in function 'CloseAllWindows'", 1, true)
            or stack:find("in function 'ShowUIPanel'", 1, true)) then
        return true
    end
    return false
end

local function CanSuppressVendorBagClose(frame, proxy)
    return Bags.escapeRegistrations[proxy or frame] and not Bags.paused
        and not InCombatLockdown() and not InputReserved() and TrackEnabled() and IsSpanned()
        and CanOpenBagsFromAddon() and frame:IsVisible() and Offhand.Canvas.IsFrameOnWorkspace(frame)
end

local function IsPreservingPanel(frame)
    local canvas = Offhand.Canvas
    return canvas and canvas.IsForeverBagPreservingPanel
        and canvas:IsForeverBagPreservingPanel(frame) or false
end

local function IsPreservingPanelShown()
    local canvas = Offhand.Canvas
    return canvas and canvas.IsForeverBagPreservingPanelShown
        and canvas:IsForeverBagPreservingPanelShown() or false
end

-- Bag Escape and persistent-root helpers handed to bag providers, bridge
-- modules and addons (docs/BRIDGES.md).
local bridgeBagServices = {
    UpdateEscapeRegistration = function(frame, name, supported, parent, proxy)
        return UpdateBagEscapeRegistration(frame, name, supported, parent, proxy)
    end,
    IsEscapeRegistered = function(registration)
        return Bags.escapeRegistrations[registration] ~= nil
    end,
    CanSuppressVendorClose = function(frame, proxy)
        return CanSuppressVendorBagClose(frame, proxy) and true or false
    end,
    IsGameMenuBagClose = function(stack)
        return IsGameMenuBagClose(stack) and true or false
    end,
    IsSettingsBagClose = function(stack)
        return IsSettingsBagClose(stack) and true or false
    end,
    IsPaused = function() return Bags.paused end,
    TrackEnabled = function() return TrackEnabled() end,
    DiscoverEnabled = function() return DiscoverEnabled() end,
    IsSpanned = function() return IsSpanned() end,
    InputReserved = function() return InputReserved() end,
    CanOpenBagsFromAddon = function() return CanOpenBagsFromAddon() end,
    IsFrameOnWorkspace = function(frame)
        local canvas = Offhand.Canvas
        return canvas and canvas.IsFrameOnWorkspace(frame)
    end,
    CloseParkedNativeBags = function(parkingParent, frameCount, lastBagID)
        return CloseParkedNativeBags(parkingParent, frameCount, lastBagID)
    end,
    KeepsIndependentPanels = function()
        return Offhand.db and Offhand.db.independentWorkspacePanels ~= false
    end,
    KeepsBagToggleOpen = function()
        return Offhand.db and Offhand.db.keepBagToggleOpen == true or false
    end,
    IsPreservingPanelShown = function() return IsPreservingPanelShown() end,
    HasSharedToggleConflict = function() return HasSharedToggleConflict() and true or false end,
    OpenSavedRoot = function(name) return Bags:OpenSavedRoot(name) end,
    RegisterRoot = function(name, frame) return Bags:RegisterRoot(name, frame) end,
    Discover = function(deep) return Bags:Discover(deep) end,
    -- The tracked roots by name. Read only.
    GetRoots = function() return Bags.frames end,
    -- The saved open root and its position (Bags:GetSavedPosition()).
    GetSavedPosition = function() return Bags:GetSavedPosition() end,
    -- The saved workspace positions and the custom bag workspace record.
    GetSavedRecords = function()
        return Offhand.db and { Offhand.db.savedWorkspacePositions, GetRecord(Offhand.db) } or {}
    end,
}

-- A provider's hookScripts: absent or true hooks the root's scripts, false
-- never does, and a function decides per root (a literal true hooks).
local function HooksScripts(owner, name, frame)
    local hook = owner.provider.hookScripts
    if hook == nil or hook == true then return true end
    if type(hook) ~= "function" then return false end
    local ok, allowed = CallProvider(owner, "hookScripts", name, frame)
    return ok and allowed == true
end

function Bags:RegisterRoot(name, frame)
    local owner = RootOwner(name, frame)
    if not owner or type(frame) ~= "table" or not frame.GetName or self.frames[name] then
        return false
    end
    self.frames[name] = frame
    if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.RegisterDynamicFrame then
        Offhand.WorkspaceChrome:RegisterDynamicFrame(name)
    end
    -- A provider's root can participate in Forever's UISpecialFrames and
    -- Gamepad focus lifecycle. Installing scripts on such a root can place
    -- Offhand in the execution ancestry of protected FrameControlsManager work.
    -- Its provider declares hookScripts, and such a root is observed only from
    -- our own ticker and the secure global Escape transaction hooks.
    if not HooksScripts(owner, name, frame) then return true end
    if not frame.HookScript then return true end

    local function CaptureAfterLayout()
        Bags:Capture()
        if Offhand.WorkspaceToggleKeys then Offhand.WorkspaceToggleKeys:Update(frame) end
    end
    local function Changed()
        -- A registered backpack can be hidden during the native Escape stack.
        -- A locally hidden, excluded backpack has no such native close route.
        -- Mark that close for the current turn and defer any SavedVariables
        -- change so the logout event can still preserve the last open state.
        if DirectEscapeOwner(name, frame) and not Bags.paused
            and not Bags.restoring and TrackEnabled() and IsSpanned()
            and not InCombatLockdown() then
            local savedName, position = Bags:GetSavedPosition()
            if position and savedName == name then
                local explicit = Bags.escapeRegistrations[frame] ~= nil and not frame:IsShown()
                local pending = {
                    explicit = explicit,
                    menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                        and GameMenuFrame:IsShown() or false,
                }
                Bags.escapePending = pending
                C_Timer.After(explicit and 0 or 0.10, function()
                    if Bags.escapePending == pending then
                        Bags.escapePending = nil
                        Bags:Capture()
                    end
                end)
            end
        end
        C_Timer.After(0, CaptureAfterLayout)
    end
    -- A bag addon can show its root before laying out its contents. Sample
    -- after that callback returns so the pre-layout size cannot revoke placement.
    frame:HookScript("OnShow", function()
        UpdateBagEscapeRegistration(frame, name, DirectEscapeOwner(name, frame) ~= nil)
        C_Timer.After(0, CaptureAfterLayout)
    end)
    frame:HookScript("OnHide", Changed)
    if Offhand.isForever and owner.provider.dragStopCapture == true then
        frame:HookScript("OnDragStop", function()
            -- The bag addon has already saved its new anchor. Reconcile ownership
            -- before an Escape that arrives ahead of the capture ticker.
            if not InCombatLockdown() and not InputReserved() then
                CaptureAfterLayout()
            end
        end)
    end
    return true
end

local function RegisterDiscoveredRoot(name, frame)
    return Bags:RegisterRoot(name, frame)
end

-- deep: the lifecycle pass in which a provider may walk the global table
-- once (after its own addon load and after login); every other pass, the
-- ticker's included, uses constant-time lookups only.
function Bags:Discover(deep)
    if not DiscoverEnabled() then return false end
    local discovered = false
    -- Each bag provider finds its own roots, in provider order.
    for _, entry in ipairs(Providers()) do
        local ok, found = CallProvider(entry, "Discover", RegisterDiscoveredRoot,
            deep and true or false, bridgeBagServices)
        discovered = (ok and found == true) or discovered
    end
    return discovered
end

-- A provider's InstallCallbacks(services) result is kept per bridge id in
-- callbacksInstalled (true while its vendor callbacks or observer are on).
Bags.callbacksInstalled = {}

local function InstallProviderCallbacks(entry)
    local ok, installed = CallProvider(entry, "InstallCallbacks", bridgeBagServices)
    if ok then Bags.callbacksInstalled[entry.id] = installed end
end

function Bags:OpenSavedRoot(savedName)
    local frame = savedName and self.frames[savedName]
    -- A provider opens the saved root itself (Show returns whether it did),
    -- or returns nil to leave it to the shared bag toggle below.
    for _, entry in ipairs(Providers()) do
        local ok, opened = CallProvider(entry, "Show", savedName, frame, bridgeBagServices)
        if ok and opened ~= nil then return opened end
    end
    -- Two providers replaced this global. Its current target cannot be inferred
    -- from the presence or visibility of either backpack root.
    if HasSharedToggleConflict() then return false end
    if ToggleAllBags then
        pcall(ToggleAllBags)
        self:Discover(false)
        return true
    end
    return false
end

local function PanelDefersBagRestore(frame)
    if not frame or not frame.GetName then return false end
    local name = frame:GetName()
    return name == "SettingsPanel" or name == "InterfaceOptionsFrame"
        or name == "VideoOptionsFrame" or name == "AudioOptionsFrame"
end

-- The saved root's provider preserves it through this panel transition:
-- panelTransitions "all" for every preserving panel, "options" for Options
-- only, tried in provider order.
local function PreservedThroughPanel(savedName, frame, options)
    for _, entry in ipairs(Providers()) do
        local through = entry.provider.panelTransitions
        if through == "all" or (through == "options" and options) then
            local ok, root = CallProvider(entry, "IsRoot", savedName, frame)
            if ok and root then return true end
        end
    end
    return false
end

-- Blizzard closes replacement bags while opening or closing certain UIPanels.
-- Preserve tracked replacement bags through Options, and some through other
-- supported panels (their provider's panelTransitions). Native Gamepad mode
-- owns these windows' visibility.
function Bags:BeginPanelTransition(panel)
    if self.paused or not IsPreservingPanel(panel) or not TrackEnabled() or not IsSpanned()
        or InputReserved() or InCombatLockdown() or not CanOpenBagsFromAddon()
        or not C_Timer or not C_Timer.After then return false end
    self:Discover(false)
    local savedName, position = self:GetSavedPosition()
    local frame = savedName and self.frames[savedName]
    local options = PanelDefersBagRestore(panel)
    if not position or not frame or not PreservedThroughPanel(savedName, frame, options) then return false end

    if options and panel:IsShown() then
        if not frame:IsVisible() then
            -- The modal can stay open indefinitely. Hold the snapshot until its
            -- close transaction instead of relying on the short restore timers.
            self.optionsPanel = panel
            self.escapePending = nil
        end
        return true
    end
    if options then
        if self.optionsPanel ~= panel then return false end
        self.optionsPanel = nil
    end

    local token = { returningFromOptions = options }
    self.panelTransition = token
    self.restoring = true
    local function Restore()
        if Bags.panelTransition ~= token or Bags.paused or InputReserved() or InCombatLockdown()
            or not CanOpenBagsFromAddon() then return end
        if options and panel:IsShown() then return end
        Bags:Discover(false)
        local root = Bags.frames[savedName]
        if root and root.IsVisible and not root:IsVisible() then
            Bags:OpenSavedRoot(savedName)
            root = Bags.frames[savedName]
        end
        if root and root.IsVisible and root:IsVisible() then
            position = Bags:NormalizePosition(position, root)
            Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
            Offhand.db.savedWorkspacePositions[savedName] = position
            SetRecord(Offhand.db, { [savedName] = position })
            Offhand.Canvas:RestoreWorkspacePosition(root)
            if options then
                Bags.panelTransition = nil
                Bags.restoring = false
                Bags:Capture()
            end
        end
    end
    C_Timer.After(0, Restore)
    C_Timer.After(0.10, Restore)
    C_Timer.After(0.35, Restore)
    C_Timer.After(0.60, function()
        if Bags.panelTransition ~= token then return end
        Bags.panelTransition = nil
        Bags.restoring = false
        Bags:Capture()
    end)
    return true
end

-- The direct-Escape providers whose root left its native Escape registration
-- in this capture pass.
local parkedOwners = {}

function Bags:Capture()
    for entry in pairs(parkedOwners) do parkedOwners[entry] = nil end
    -- The registration only changes on Forever, so only Forever asks which
    -- provider's root keeps its own Escape registration.
    for name, frame in pairs(self.frames) do
        local owner = Offhand.isForever and DirectEscapeOwner(name, frame) or nil
        if UpdateBagEscapeRegistration(frame, name, owner ~= nil) and owner then
            parkedOwners[owner] = true
        end
    end
    -- Each such provider closes the native bags it parks, in escape order.
    for _, entry in ipairs(EscapeEntries()) do
        if parkedOwners[entry] then CallProvider(entry, "CloseParkedBags", bridgeBagServices) end
    end
    -- The bag providers' Escape adapters, then the bridges' own (one fixed
    -- sequence, so UISpecialFrames registrations keep their order).
    if Offhand.isForever and Offhand.Bridges then Offhand.Bridges:RefreshBags(bridgeBagServices) end
    if self.paused or self.restoring or self.escapePending or not Offhand.db
        or not CanOpenBagsFromAddon() then return end
    if self.optionsPanel then
        if self.optionsPanel:IsShown() and not self:GetVisibleFrame() then return end
        -- A deliberate reopen gives visibility back to the bag addon.
        self.optionsPanel = nil
    end
    local currentMetrics=Offhand.Viewport and Offhand.Viewport:GetMetrics()
    -- Single-screen recovery is a temporary loss of usable workspace geometry.
    -- Visible bags there do not revoke saved workspace ownership or open intent.
    if currentMetrics and currentMetrics.isSpanned==false then return end
    self:Discover(false)
    local snapshot
    if TrackEnabled() then
        for name, frame in pairs(self.frames) do
            if not (frame.IsForbidden and frame:IsForbidden()) and frame:IsVisible() then
                local x = frame:GetLeft()
                local y = frame.GetTop and frame:GetTop()
                if not y and frame.GetBottom and frame.GetHeight then
                    local bottom = frame:GetBottom()
                    if bottom then y = bottom + frame:GetHeight() end
                end
                local previous=Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                local fitFallback=Offhand.CanvasPersistence and Offhand.CanvasPersistence.PreservedFitFallback
                    and Offhand.CanvasPersistence.PreservedFitFallback(frame,currentMetrics,previous)
                if fitFallback then
                    snapshot=snapshot or {};snapshot[name]=fitFallback
                elseif (not x or not y) and NameOwner(name) then
                    -- A visible backpack can still lack an actual rectangle
                    -- while its vendor-owned anchor is being rebuilt.
                    local saved = GetRecord(Offhand.db)
                    if type(saved) == "table" and saved[name] then
                        snapshot = snapshot or {}
                        snapshot[name] = saved[name]
                    end
                elseif Offhand.Canvas.IsFrameOnWorkspace(frame) then
                    local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    if x and y then
                        local metrics = currentMetrics
                        if Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,frame) end
                        local position=Offhand.WorkspaceRegions and Offhand.WorkspaceRegions:PreservedFallbackPosition(frame,metrics,previous)
                        if not position then position = {
                            x = x * factor, y = y * factor,
                            coordinateVersion = 2,
                            canvasWidth = metrics and metrics.workspaceWidth or nil,
                            canvasHeight = metrics and metrics.workspaceHeight or nil,
                            canvasLeft = metrics and metrics.workspaceLeft or nil,
                            canvasBottom = metrics and metrics.workspaceBottom or nil,
                        }
                        if Offhand.WorkspaceRegions and metrics then Offhand.WorkspaceRegions:SavePosition(position,metrics) end
                        end
                        snapshot = snapshot or {}
                        snapshot[name] = position
                        -- A root its provider restores itself keeps only this
                        -- open snapshot, with what the provider adds to it.
                        local managed = ManagedEntry(name)
                        if managed then
                            CallProvider(managed, "CapturePosition", position, frame, bridgeBagServices)
                        else
                            Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
                            Offhand.db.savedWorkspacePositions[name] = position
                        end
                    end
                else
                    -- A bag provider can move its root without firing
                    -- Offhand's drag-stop callback. Retire the stale
                    -- workspace record immediately when its visible root is
                    -- now on Mainhand, or the next map repair pass moves it back.
                    if Offhand.db.savedWorkspacePositions then
                        Offhand.db.savedWorkspacePositions[name] = nil
                    end
                    if Offhand.db.openWorkspacePanels then
                        Offhand.db.openWorkspacePanels[name] = nil
                    end
                    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
                        Offhand.ForeverPersistence:ClearPosition(name)
                    end
                end
            end
        end
    end
    if snapshot then
        SetRecord(Offhand.db, snapshot)
    elseif type(GetRecord(Offhand.db)) ~= "table"
        or next(GetRecord(Offhand.db)) then
        -- Five polls per second should not allocate a new empty saved-state
        -- table while no replacement bag is open. Clear old intent once.
        SetRecord(Offhand.db, {})
    end
end

local function RestoreGameMenuAfterEscape(menuWasShown)
    -- Recover the requested menu state without running Blizzard's Escape
    -- dispatcher a second time, which would close the restored bag again.
    local menuShouldBeShown = not menuWasShown
    local menu = GameMenuFrame
    if not menu or not menu.IsShown or menuShouldBeShown == menu:IsShown() then return end
    local change = menu[menuShouldBeShown and "Show" or "Hide"]
    if change then pcall(change, menu) end
end

local function CanRestoreBagThroughEscape(name)
    if Offhand.isForever and not Offhand.CanvasForeverBags.CanPreserveBagThroughEscape() then
        -- Let the native bag close stand so the next Escape reaches the
        -- target. Keep the bag's position for the next deliberate open.
        Bags:ForgetOpenSnapshot(name)
        return false
    end
    return true
end

function Bags:RestoreAfterEscape(pending)
    if self.escapePending ~= pending then return false end
    self.escapePending = nil
    if InputReserved() or not TrackEnabled() or not IsSpanned() or InCombatLockdown()
        or not CanOpenBagsFromAddon() then
        self:Capture()
        return false
    end

    local savedName, position = self:GetSavedPosition()
    if not position or ManagedEntry(savedName)
        or (NameOwner(savedName) and HasSharedToggleConflict()) then return false end
    if ExplicitlyClosed(savedName) then
        self:ForgetOpenSnapshot(savedName)
        return false
    end
    if not CanRestoreBagThroughEscape(savedName) then return false end
    self.restoring = true
    self:Discover()
    local exact = HasSharedToggleConflict() and savedName or nil
    local visible = self:GetVisibleFrame(exact)
    if not visible then
        self:OpenSavedRoot(savedName)
        visible = self:GetVisibleFrame(exact)
    end

    if visible then
        local name = visible:GetName()
        position = self:NormalizePosition(position, visible)
        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
        Offhand.db.savedWorkspacePositions[name] = position
        SetRecord(Offhand.db, { [name] = position })
        Offhand.Canvas:RestoreWorkspacePosition(visible)
        RestoreGameMenuAfterEscape(pending.menuWasShown)
    end

    self.restoring = false
    self:Capture()
    return visible ~= nil
end

-- A root its provider restores itself (ManagedEntry) is reopened after a
-- native transition hid it through the provider's CanRestore(frame, services)
-- and Restore(frame, position, services). pending is { entry, name, frame,
-- position, menuWasShown }, position a copy of the saved open snapshot.
local function CanRestoreManagedRoot(entry, frame)
    if not entry then return false end
    local ok, allowed = CallProvider(entry, "CanRestore", frame, bridgeBagServices)
    return ok and allowed and true or false
end

local function RestoreManagedRoot(pending, throughEscape)
    local frame = pending.frame
    if Bags.paused or Bags.restoring or not TrackEnabled() or not IsSpanned()
        or InputReserved() or InCombatLockdown() or not CanOpenBagsFromAddon()
        or not CanRestoreManagedRoot(pending.entry, frame) then return false end
    if throughEscape and not CanRestoreBagThroughEscape(pending.name) then return false end
    local ok, restored = CallProvider(pending.entry, "Restore", frame, pending.position, bridgeBagServices)
    return ok and restored == true
end

function Bags:RestoreManagedAfterEscape(pending)
    if not RestoreManagedRoot(pending, true) then return end
    -- Forever counts hiding a provider's own Escape proxy as a handled press.
    -- Reopening the bag alone would let that proxy claim every subsequent press.
    RestoreGameMenuAfterEscape(pending.menuWasShown)
    self:Capture()
end

local function InstallTalentsObserver()
    if not Offhand.isForever or Bags.talentsObserved or not EventRegistry
        or not EventRegistry.RegisterCallback or not C_Timer or not C_Timer.After then return end
    Bags.talentsObserved = true
    EventRegistry:RegisterCallback("PlayerSpellsFrame.OpenFrame", function()
        if Bags.paused or Bags.restoring or not TrackEnabled() or not IsSpanned() then return end
        local name, position = Bags:GetSavedPosition()
        local entry = ManagedEntry(name)
        local frame = entry and Bags.frames[name]
        local panel = _G.PlayerSpellsFrame
        if not position or not frame or not panel or not panel.talentTabID or not panel.GetTab then return end
        local generation = Bags.generation
        local pending = {entry = entry, name = name, frame = frame, position = CopyPosition(position)}
        -- Let the native panel transaction settle before reading the selected
        -- tab or restoring the provider's own bag roots.
        C_Timer.After(0, function()
            if generation ~= Bags.generation or panel ~= _G.PlayerSpellsFrame
                or not panel:IsShown() or panel:GetTab() ~= panel.talentTabID then return end
            if RestoreManagedRoot(pending) then Bags:Capture() end
        end)
    end, Bags)
end

function Bags:InstallEscapeHooks()
    if not hooksecurefunc then return end
    if Offhand.isForever and CloseSpecialWindows and not self.managedEscapeHooked then
        self.managedEscapeHooked = true
        hooksecurefunc("CloseSpecialWindows", function()
            if Bags.paused or Bags.restoring or not CanOpenBagsFromAddon()
                or not TrackEnabled() or not IsSpanned() or InputReserved() or InCombatLockdown() then return end
            local name, position = Bags:GetSavedPosition()
            local entry = ManagedEntry(name)
            local frame = entry and Bags.frames[name]
            if not position or not CanRestoreManagedRoot(entry, frame) then return end
            local pending = {
                entry = entry, name = name, frame = frame, position = CopyPosition(position),
                menuWasShown = GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown(),
            }
            Bags.managedEscapePending = pending
            C_Timer.After(0, function()
                if Bags.managedEscapePending == pending then Bags.managedEscapePending = nil end
            end)
        end)
    end
    if CloseAllBags and not self.closeAllBagsHooked then
        self.closeAllBagsHooked = true
        hooksecurefunc("CloseAllBags", function()
            if Bags.restoring or InputReserved() or not TrackEnabled() or not IsSpanned()
                or InCombatLockdown() or Bags:GetVisibleFrame() then return end
            if Bags.escapePending and Bags.escapePending.explicit then return end
            local savedName, position = Bags:GetSavedPosition()
            if not position then return end
            -- A provider can report its root's actual hide on Forever. A
            -- native CloseAllBags by itself may only be closing parked
            -- containers or ending a bank/merchant interaction.
            if ManagedEntry(savedName)
                or (Offhand.isForever and FlaggedNameOwner("reportsRootHide", savedName)) then return end
            -- A provider can distinguish a user-requested bag close from its
            -- Escape proxy hiding the frame. Respect the former even if an
            -- older Offhand open-state sample has not yet been retired.
            if ExplicitlyClosed(savedName) then
                Bags:ForgetOpenSnapshot(savedName)
                return
            end
            local pending = {
                menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                    and GameMenuFrame:IsShown() or false,
            }
            Bags.escapePending = pending
            -- A CloseAllBags call not followed by ToggleGameMenu is an explicit
            -- close or another system transition, so allow the normal hide
            -- capture to clear the open snapshot after the pairing window.
            C_Timer.After(0.10, function()
                if Bags.escapePending == pending then
                    Bags.escapePending = nil
                    Bags:Capture()
                end
            end)
        end)
    end
    if ToggleGameMenu and not self.toggleGameMenuHooked then
        self.toggleGameMenuHooked = true
        hooksecurefunc("ToggleGameMenu", function()
            if Bags.optionsPanel or (Bags.panelTransition and Bags.panelTransition.returningFromOptions) then
                -- Settings returns to the Game Menu through this same function.
                -- The Options transition owns the reopen even with a target selected.
                Bags.escapePending = nil
                if Offhand.Bridges then Offhand.Bridges:NotifyBagProviders("CancelEscape") end
                return
            end
            -- A bag provider whose vendor queued its own Escape close keeps
            -- its workspace backpack open now.
            if Offhand.Bridges then Offhand.Bridges:NotifyBagProviders("PreserveThroughEscape", bridgeBagServices) end
            local managed = Bags.managedEscapePending
            Bags.managedEscapePending = nil
            if managed then
                local generation = Bags.generation
                C_Timer.After(0, function()
                    if generation == Bags.generation then Bags:RestoreManagedAfterEscape(managed) end
                end)
            end
            if InputReserved() then
                Bags.escapePending = nil
                return
            end
            local pending = Bags.escapePending
            if pending and pending.explicit then return end
            if not pending and CanOpenBagsFromAddon() then
                local savedName, position = Bags:GetSavedPosition()
                local frame = savedName and Bags.frames[savedName]
                local visible = frame and frame.IsVisible and frame:IsVisible() or false
                local owner = position and frame and DirectEscapeOwner(savedName, frame)
                if owner and not visible
                    and not (Offhand.isForever and FlaggedNameOwner("reportsRootHide", savedName))
                    and not HasSharedToggleConflict() then
                    local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
                        and GameMenuFrame:IsShown() or false
                    pending = {
                        menuWasShown = not menuIsShown,
                        source = owner.provider.escapeSource,
                    }
                    Bags.escapePending = pending
                end
            end
            if not pending then return end
            C_Timer.After(0, function() Bags:RestoreAfterEscape(pending) end)
        end)
    end
    if ShowUIPanel and not self.showUIPanelHooked then
        self.showUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(panel)
            -- A center panel shown inside a bag provider's queued Escape close.
            if Offhand.Bridges then
                Offhand.Bridges:NotifyBagProviders("PreserveThroughPanelShow", panel, bridgeBagServices)
            end
            if IsPreservingPanel(panel) then Bags:BeginPanelTransition(panel) end
        end)
    end
    if HideUIPanel and not self.hideUIPanelHooked then
        self.hideUIPanelHooked = true
        hooksecurefunc("HideUIPanel", function(panel)
            if IsPreservingPanel(panel) then Bags:BeginPanelTransition(panel) end
        end)
    end
end

-- Removes records under a name of a provider's root family (by name alone)
-- whose frame is not one of its roots, such as a child region's.
function Bags:PruneInvalidRootRecords()
    if not Offhand.db then return end
    local records = {
        Offhand.db.savedWorkspacePositions,
        Offhand.db.openWorkspacePanels,
        GetRecord(Offhand.db),
    }
    for _, record in ipairs(records) do
        if type(record) == "table" then
            for name in pairs(record) do
                if NameOwner(name) and _G[name] ~= nil
                    and not RootOwner(name, _G[name]) then
                    record[name] = nil
                end
            end
        end
    end
end

function Bags:GetDiagnostics()
    self:Discover(false)
    local roots, visible = 0, 0
    for _, frame in pairs(self.frames) do
        roots = roots + 1
        if frame.IsVisible and frame:IsVisible() then visible = visible + 1 end
    end
    local savedName = self:GetSavedPosition()
    local text = string.format("Roots=%d | Visible=%d | Saved=%s | EscapeHook=%s/%s | Pending=%s",
        roots, visible, tostring(savedName or "none"),
        self.closeAllBagsHooked and "yes" or "no",
        self.toggleGameMenuHooked and "yes" or "no",
        self.escapePending and "yes" or "no")
    -- Each provider's own segment, in provider order.
    for _, entry in ipairs(Providers()) do
        local ok, segment = CallProvider(entry, "GetRootDiagnostics")
        if ok and type(segment) == "string" and segment ~= "" then text = text .. " | " .. segment end
    end
    return text
end

-- Each provider's own report for the panels diagnostics (GetPanelDiagnostics),
-- in provider order, as { label = bridge id, text }.
function Bags:GetPanelDiagnostics()
    local reports = {}
    for _, entry in ipairs(Providers()) do
        local ok, text = CallProvider(entry, "GetPanelDiagnostics", bridgeBagServices)
        if ok and type(text) == "string" and text ~= "" then
            reports[#reports + 1] = { label = entry.id, text = text }
        end
    end
    return reports
end

function Bags:Resume()
    self.generation = self.generation + 1
    local generation = self.generation
    self.paused = true
    self.waitingForWorkspace = nil
    local attempts, toggled = 0, false
    local function Restore()
        if generation ~= Bags.generation then return end
        if not ReloadEnabled() then Bags.paused = false; Bags:Capture(); return end
        if InCombatLockdown() then
            Bags.waitingForCombat = true
            return
        end
        Bags.waitingForCombat = false
        if not CanOpenBagsFromAddon() then
            -- Native Gamepad UI owns third-party window visibility and focus.
            -- Retain the saved intent for a later player-driven open, but do
            -- not inspect, open, reanchor, or attach code to the bag root.
            Bags.waitingForInput = true
            Bags.paused = false
            return
        end
        Bags:Discover(false)
        Bags:PruneInvalidRootRecords()
        if InputReserved() then
            Bags.waitingForInput = true
            return
        end
        Bags.waitingForInput = false
        local savedName, position = Bags:GetSavedPosition()
        if position and type(position) == "table" and position.x and position.y then
            if ExplicitlyClosed(savedName) then
                Bags:ForgetOpenSnapshot(savedName)
                Bags.paused = false
                Bags:Capture()
                return
            end
            if Offhand.isForever and not IsSpanned() then
                -- Companion can span the display after login. Retain the open
                -- snapshot until the real workspace is ready for restoration.
                Bags.waitingForWorkspace = true
                return
            end
            local managed = ManagedEntry(savedName)
            if managed then
                -- The provider reopens its own root; "wait" retries while
                -- the root is not ready for that yet.
                local ok, state = CallProvider(managed, "Resume", savedName, Bags.frames[savedName],
                    bridgeBagServices)
                if ok and state == "wait" then
                    attempts = attempts + 1
                    if attempts < 20 then C_Timer.After(0.25, Restore); return end
                end
                Bags.paused = false
                Bags:Capture()
                return
            end
            local exact = HasSharedToggleConflict() and savedName or nil
            local visible = Bags:GetVisibleFrame(exact)
            if not visible and not CanOpenBagsFromAddon() then
                -- Keep the reload-open snapshot. A later player-driven open
                -- applies its saved workspace position through the normal hook.
                Bags.paused = false
                return
            end
            if not visible and next(Bags.frames) and not toggled then
                toggled = true
                Bags:OpenSavedRoot(savedName)
                visible = Bags:GetVisibleFrame(exact)
            end
            if visible then
                position = Bags:NormalizePosition(position, visible)
                Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
                SetRecord(Offhand.db, { [visible:GetName()] = position })
                Offhand.db.savedWorkspacePositions[visible:GetName()] = position
                Offhand.Canvas:RestoreWorkspacePosition(visible)
            else
                attempts = attempts + 1
                if attempts < 20 then C_Timer.After(0.25, Restore); return end
            end
        end
        Bags.paused = false
        Bags:Capture()
    end
    C_Timer.After(0.5, Restore)
end

function Bags:ResumeWhenWorkspaceReady()
    if self.waitingForWorkspace and IsSpanned() then self:Resume() end
end

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "CINEMATIC_STOP"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" or event == "PLAYER_CONTROL_LOST" then
        Bags.paused = true
        Bags.generation = Bags.generation + 1
        Bags.escapePending = nil
        Bags.managedEscapePending = nil
        if Offhand.Bridges then Offhand.Bridges:NotifyBagProviders("CancelEscape") end
        Bags.optionsPanel = nil
        Bags.waitingForWorkspace = nil
    elseif event == "PLAYER_ENTERING_WORLD"
        or (event == "PLAYER_REGEN_ENABLED" and Bags.waitingForCombat)
        or (event == "PLAYER_CONTROL_GAINED" and Bags.waitingForInput)
        or (event == "CINEMATIC_STOP" and Bags.waitingForInput) then
        Bags:Resume()
    elseif event == "ADDON_LOADED" then
        -- Constant-time provider lookups are safe for every addon load. Only
        -- a provider's own addon load may run its one deep discovery: that
        -- provider installs its callbacks, then one discovery pass follows
        -- (deep only if the provider declares deepDiscovery).
        Bags:Discover(false)
        for _, entry in ipairs(Providers()) do
            if entry.provider.loadAddon ~= nil and entry.provider.loadAddon == addonName then
                InstallProviderCallbacks(entry)
                local deep = entry.provider.deepDiscovery == true
                C_Timer.After(0, function() Bags:Discover(deep) end)
                break
            end
        end
    elseif event == "PLAYER_LOGIN" then
        for _, entry in ipairs(Providers()) do InstallProviderCallbacks(entry) end
        Bags:Discover(false)
        -- Run after every PLAYER_LOGIN handler so a provider's initial frame
        -- group exists regardless of addon load order.
        C_Timer.After(0, function() Bags:Discover(true) end)
        Bags:PruneInvalidRootRecords()
        Bags:InstallEscapeHooks()
        InstallTalentsObserver()
        if not Bags.ticker then
            Bags.ticker = C_Timer.NewTicker(0.2, function()
                if not Bags.paused then
                    Bags:Capture()
                end
            end)
        end
    end
end)
