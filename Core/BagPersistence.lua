-- Addon bag replacements own their visibility and layout. Track only known root
-- backpack windows, never item/button pools, bank windows or settings panels.
local _, Offhand = ...
local Bags = {
    paused = true,
    frames = {},
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

local function ReloadEnabled()
    local db = Offhand.db
    return TrackEnabled() and db.restoreWorkspaceOnReload ~= false
end

local function InputReserved()
    return Offhand.IsBlizzardInputReserved
        and Offhand:IsBlizzardInputReserved() or false
end

local function IsBaganatorRootName(name)
    return type(name) == "string"
        and (name:match("^Baganator_SingleViewBackpackViewFrame")
            or name:match("^Baganator_CategoryViewBackpackViewFrame"))
end

local function IsForeverEllesmereBag(name)
    return Offhand.isForever and name == "EUI_MainBagFrame"
end

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function HasConflictingEllesmereBagToggle()
    return Offhand.isForever and _G.EUI_MainBagFrame and IsAddOnLoadedCompat("Baganator")
end

local function GetBagnonInventoryRoot()
    if not IsAddOnLoadedCompat("Bagnon") then return nil end
    local manager = Bagnon and Bagnon.Frames
    if not manager or type(manager.Get) ~= "function" then return nil end
    local ok, frame = pcall(manager.Get, manager, "inventory")
    if not ok or type(frame) ~= "table" or not frame.GetName then return nil end
    return frame
end

local function IsBagnonInventoryRoot(name, frame)
    if not frame or not frame.GetParent
        or frame:GetParent() ~= UIParent or frame.id ~= "inventory" then
        return false
    end
    return GetBagnonInventoryRoot() == frame
end

local function IsDirectEscapeRoot(name, frame)
    return IsBaganatorRootName(name) or IsBagnonInventoryRoot(name, frame)
end

local function IsSupportedRoot(name, frame)
    if name == "EUI_MainBagFrame" then return true end
    if IsBagnonInventoryRoot(name, frame) then return true end
    if not IsBaganatorRootName(name) then return false end
    -- Baganator derives the names of every child region from the backpack
    -- root. A prefix-only match therefore also catches title text, textures,
    -- and buttons. Its actual backpack roots are direct UIParent children.
    return frame and frame.GetParent and frame:GetParent() == UIParent
end

local function IsSpanned()
    local viewport = Offhand.Viewport
    if not viewport or not viewport.GetMetrics then return true end
    local metrics = viewport:GetMetrics()
    return metrics and metrics.isSpanned == true
end

local function EllesmereExplicitlyClosed(name)
    return name == "EUI_MainBagFrame"
        and type(EllesmereUIDB) == "table"
        and EllesmereUIDB.bagsVisible == false
end

local function CanShowEllesmereBag(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and not frame:IsShown()
        and not (UIParent.IsVisible and not UIParent:IsVisible())
end

local function ShowEllesmereBag(frame)
    if not CanShowEllesmereBag(frame) or type(frame.RefreshInventory) ~= "function" then return end
    frame:Show()
    if frame:IsVisible() then frame:RefreshInventory() end
end

function Bags:ForgetOpenSnapshot(name)
    if not Offhand.db then return end
    local saved = Offhand.db.baganatorWorkspacePanels
    if type(saved) ~= "table" then return end
    if name then saved[name] = nil else wipe(saved) end
end

function Bags:GetSavedPosition()
    local saved = Offhand.db and Offhand.db.baganatorWorkspacePanels or {}
    local ellesmere = Offhand.isForever and saved.EUI_MainBagFrame
    if type(ellesmere) == "table" and ellesmere.x and ellesmere.y then
        return "EUI_MainBagFrame", ellesmere
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

function Bags:RegisterRoot(name, frame)
    if not IsSupportedRoot(name, frame) or type(frame) ~= "table"
        or not frame.GetName or self.frames[name] then
        return false
    end
    self.frames[name] = frame
    if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.RegisterDynamicFrame then
        Offhand.WorkspaceChrome:RegisterDynamicFrame(name)
    end
    -- Bagnon's root participates in Forever's UISpecialFrames and Gamepad
    -- focus lifecycle. Installing scripts on that root can place Offhand in the
    -- execution ancestry of protected FrameControlsManager work. Observe it
    -- only from our own ticker and the secure global Escape transaction hooks.
    if IsBagnonInventoryRoot(name, frame) or IsForeverEllesmereBag(name) then return true end
    if not frame.HookScript then return true end

    local function Changed()
                -- Baganator registers its root in UISpecialFrames, so Forever
                -- can hide it directly before ToggleGameMenu without calling
                -- CloseAllBags. Pair that root hide with the same immediate
                -- Game Menu toggle used by Escape. A bag-key or X close has no
                -- paired toggle and is allowed to expire normally.
                if IsDirectEscapeRoot(name, frame) and not Bags.paused
                    and not Bags.restoring and TrackEnabled() and IsSpanned()
                    and not InCombatLockdown() then
                    local savedName, position = Bags:GetSavedPosition()
                    if position and savedName == name then
                        local pending = {
                            menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                                and GameMenuFrame:IsShown() or false,
                            source = IsBagnonInventoryRoot(name, frame)
                                and "bagnon_root_hide" or "baganator_root_hide",
                        }
                        Bags.escapePending = pending
                        C_Timer.After(0.10, function()
                            if Bags.escapePending == pending then
                                Bags.escapePending = nil
                                Bags:Capture()
                            end
                        end)
                    end
                end
                -- Teardown hides windows synchronously; a deferred sample cannot
                -- erase the last visible state while the UI is being destroyed.
                C_Timer.After(0, function()
                    Bags:Capture()
                end)
    end
    frame:HookScript("OnShow", function() Bags:Capture() end)
    frame:HookScript("OnHide", Changed)
    return true
end

function Bags:Discover(scanBaganatorGlobals)
    if not TrackEnabled() then return false end
    local discovered = false

    -- EllesmereUI exposes a stable root name, so discovery never needs a
    -- global-table walk.
    if _G.EUI_MainBagFrame then
        discovered = self:RegisterRoot("EUI_MainBagFrame", _G.EUI_MainBagFrame) or discovered
    end

    -- Bagnon's inventory root is lazy, but its public manager provides a
    -- constant-time identity lookup after construction. Never scan its child
    -- regions or depend on skin-generated global names.
    local bagnonRoot = GetBagnonInventoryRoot()
    if bagnonRoot then
        discovered = self:RegisterRoot(bagnonRoot:GetName(), bagnonRoot) or discovered
    end

    -- Persisted Baganator root names can also be resolved directly. This is
    -- enough for reload restoration even before Baganator announces a frame
    -- replacement through its callback registry.
    local records = Offhand.db and {
        Offhand.db.savedWorkspacePositions,
        Offhand.db.baganatorWorkspacePanels,
    } or {}
    for _, record in ipairs(records) do
        if type(record) == "table" then
            for name in pairs(record) do
                if IsBaganatorRootName(name) and _G[name] then
                    discovered = self:RegisterRoot(name, _G[name]) or discovered
                end
            end
        end
    end
    if not scanBaganatorGlobals or not IsAddOnLoadedCompat("Baganator") then
        return discovered
    end

    -- Baganator derives root names from its active skin/frame group. A single
    -- lifecycle scan finds roots that predate Offhand's callback subscription;
    -- ongoing changes arrive through BackpackFrameChanged below.
    for name, frame in pairs(_G) do
        if type(name) == "string" and IsBaganatorRootName(name) then
            discovered = self:RegisterRoot(name, frame) or discovered
        end
    end
    return discovered
end

function Bags:InstallBagnonCallbacks()
    -- Deliberately no Bagnon callbacks. Its root and manager can participate in
    -- Forever's Gamepad focus path. Constant-time polling of Frames:Get from
    -- the addon-owned observer discovers the lazy inventory root without
    -- inserting Offhand code into Bagnon's call chain.
    self.bagnonCallbacksInstalled = IsAddOnLoadedCompat("Bagnon") or nil
end

function Bags:OpenSavedRoot(savedName)
    local frame = savedName and self.frames[savedName]
    if frame and IsBagnonInventoryRoot(savedName, frame) then
        local manager = Bagnon and Bagnon.Frames
        if manager and type(manager.Show) == "function" then
            local ok = pcall(manager.Show, manager, "inventory")
            if ok then
                self:Discover(false)
                return true
            end
        end
    end
    if IsForeverEllesmereBag(savedName) and HasConflictingEllesmereBagToggle() then
        -- EllesmereUI 9.7.8 exposes its scale setup in the module namespace.
        -- Use that capability for an already-initialized bag and let its own
        -- show and refresh handlers rebuild it. Neither shared toggle is safe
        -- to call when both providers registered one.
        local eui = _G.EllesmereUI
        local module = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIBags
        local internals = module and module._bagsInternals
        local applyScale = type(internals) == "table" and rawget(internals, "ApplyBagScale")
        local bagsDB = eui and eui._bagsDB
        local profile = bagsDB and bagsDB.profile
        if profile and type(applyScale) == "function"
            and CanShowEllesmereBag(frame) and pcall(applyScale) then
            ShowEllesmereBag(frame)
            if frame:IsVisible() and profile.detachReagentBag then
                ShowEllesmereBag(_G.EUI_ReagentBagFrame)
            end
            return frame:IsVisible()
        end
        return false
    end
    -- Both addons replace this global. Its current target cannot be inferred
    -- from the presence or visibility of either backpack root.
    if HasConflictingEllesmereBagToggle() then return false end
    if ToggleAllBags then
        pcall(ToggleAllBags)
        self:Discover(false)
        return true
    end
    return false
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

local function PanelDefersBagRestore(frame)
    if not frame or not frame.GetName then return false end
    local name = frame:GetName()
    return name == "SettingsPanel" or name == "InterfaceOptionsFrame"
        or name == "VideoOptionsFrame" or name == "AudioOptionsFrame"
end

-- Blizzard closes replacement bags while opening or closing certain UIPanels.
-- Preserve a Bagnon inventory that the user deliberately left on Offhand, but
-- do all work after the native panel transaction and through Bagnon's public
-- manager. The native Gamepad interface remains excluded: live testing showed
-- that reopening Bagnon there taints its protected interact-target path.
function Bags:BeginPanelTransition(panel)
    if not IsPreservingPanel(panel) or not TrackEnabled() or not IsSpanned()
        or InputReserved() or InCombatLockdown() or not CanOpenBagsFromAddon()
        or not C_Timer or not C_Timer.After then return false end
    self:Discover(false)
    local savedName, position = self:GetSavedPosition()
    local frame = savedName and self.frames[savedName]
    if not position or not IsBagnonInventoryRoot(savedName, frame) then return false end

    local token = {}
    self.panelTransition = token
    self.restoring = true
    local function Restore()
        if Bags.panelTransition ~= token or InputReserved() or InCombatLockdown()
            or not CanOpenBagsFromAddon() then return end
        -- Options deliberately hides replacement bags while it owns the main
        -- panel slot. Do not fight that transaction or play Bagnon's opening
        -- cue behind the visible Settings panel. Its HideUIPanel observer will
        -- start a fresh transition and restore the saved bag afterwards.
        if PanelDefersBagRestore(panel) and panel.IsShown and panel:IsShown() then return end
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
            Offhand.db.baganatorWorkspacePanels = { [savedName] = position }
            Offhand.Canvas:RestoreWorkspacePosition(root)
        end
    end
    C_Timer.After(0, Restore)
    C_Timer.After(0.10, Restore)
    C_Timer.After(0.35, Restore)
    C_Timer.After(0.60, function()
        if Bags.panelTransition ~= token then return end
        Bags.panelTransition = nil
        Bags.restoring = false
        if not (PanelDefersBagRestore(panel) and panel.IsShown and panel:IsShown()) then
            Bags:Capture()
        end
    end)
    return true
end

function Bags:InstallBaganatorCallbacks()
    if self.baganatorCallbacksInstalled or not IsAddOnLoadedCompat("Baganator") then return end
    local registry = Baganator and Baganator.CallbackRegistry
    if not registry or not registry.RegisterCallback then return end
    self.baganatorCallbacksInstalled = true
    registry:RegisterCallback("BackpackFrameChanged", function(_, frame)
        if not TrackEnabled() or not frame or not frame.GetName then return end
        Bags:RegisterRoot(frame:GetName(), frame)
    end)
    registry:RegisterCallback("BagShow", function()
        if not TrackEnabled() then return end
        for name in pairs(Bags.frames) do
            if IsBaganatorRootName(name) then return end
        end
        -- Fallback for load orders where Baganator creates its first frame
        -- after Offhand's PLAYER_LOGIN handler. This runs at most until the
        -- first root is found, never on a timer.
        C_Timer.After(0, function() Bags:Discover(true) end)
    end)
end

function Bags:Capture()
    if self.paused or self.restoring or self.escapePending or not Offhand.db
        or not CanOpenBagsFromAddon() then return end
    local currentMetrics=Offhand.Viewport and Offhand.Viewport:GetMetrics()
    -- Single-screen recovery is a temporary loss of usable workspace geometry.
    -- Visible bags there do not revoke saved workspace ownership or open intent.
    if currentMetrics and currentMetrics.isSpanned==false then return end
    self:Discover(false)
    local snapshot
    if TrackEnabled() then
        for name, frame in pairs(self.frames) do
            if not (frame.IsForbidden and frame:IsForbidden()) and frame:IsVisible() then
                local previous=Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                local fitFallback=Offhand.CanvasPersistence and Offhand.CanvasPersistence.PreservedFitFallback
                    and Offhand.CanvasPersistence.PreservedFitFallback(frame,currentMetrics,previous)
                if fitFallback then
                    snapshot=snapshot or {};snapshot[name]=fitFallback
                elseif Offhand.Canvas.IsFrameOnWorkspace(frame) then
                    local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    local x = frame:GetLeft()
                    local y = frame.GetTop and frame:GetTop() or nil
                    if not y and frame.GetBottom and frame.GetHeight then
                        y = frame:GetBottom() + frame:GetHeight()
                    end
                    if x and y then
                        local metrics = currentMetrics
                        if Offhand.WorkspaceRegions then metrics=Offhand.WorkspaceRegions:ForFrame(metrics,frame) end
                        local previous=Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
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
                        if IsForeverEllesmereBag(name) then
                            local reagent = _G.EUI_ReagentBagFrame
                            position.reagentOpen = reagent and not (reagent.IsForbidden and reagent:IsForbidden())
                                and reagent:IsVisible()
                                and Offhand.Canvas.IsFrameOnWorkspace(reagent) or nil
                        else
                            Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
                            Offhand.db.savedWorkspacePositions[name] = position
                        end
                    end
                else
                    -- EllesmereUI and Baganator can move their root without
                    -- firing Offhand's drag-stop callback. Retire the stale
                    -- workspace record immediately when their visible root is
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
        Offhand.db.baganatorWorkspacePanels = snapshot
    elseif type(Offhand.db.baganatorWorkspacePanels) ~= "table"
        or next(Offhand.db.baganatorWorkspacePanels) then
        -- Five polls per second should not allocate a new empty saved-state
        -- table while no replacement bag is open. Clear old intent once.
        Offhand.db.baganatorWorkspacePanels = {}
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

function Bags:RestoreAfterEscape(pending)
    if self.escapePending ~= pending then return false end
    self.escapePending = nil
    if InputReserved() or not TrackEnabled() or not IsSpanned() or InCombatLockdown()
        or not CanOpenBagsFromAddon() then
        self:Capture()
        return false
    end

    local savedName, position = self:GetSavedPosition()
    if not position or IsForeverEllesmereBag(savedName)
        or (IsBaganatorRootName(savedName) and HasConflictingEllesmereBagToggle()) then return false end
    if EllesmereExplicitlyClosed(savedName) then
        self:ForgetOpenSnapshot(savedName)
        return false
    end
    self.restoring = true
    self:Discover()
    local exact = HasConflictingEllesmereBagToggle() and savedName or nil
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
        Offhand.db.baganatorWorkspacePanels = { [name] = position }
        Offhand.Canvas:RestoreWorkspacePosition(visible)
    end

    RestoreGameMenuAfterEscape(pending.menuWasShown)
    self.restoring = false
    self:Capture()
    return visible ~= nil
end

local function CanRestoreEllesmereEscape(frame)
    local canvas = Offhand.Canvas
    return frame == _G.EUI_MainBagFrame and CanShowEllesmereBag(frame)
        and type(EllesmereUIDB) == "table" and EllesmereUIDB.bagsVisible == true
        and canvas and canvas.IsFrameOnWorkspace(frame)
        and not IsPreservingPanelShown()
end

function Bags:RestoreEllesmereAfterEscape(pending)
    local frame = pending.frame
    if self.paused or self.restoring or not TrackEnabled() or not IsSpanned()
        or InputReserved() or InCombatLockdown() or not CanOpenBagsFromAddon()
        or not CanRestoreEllesmereEscape(frame) then return end
    -- This root was already initialized and open before native Escape closed
    -- it. Use the same root's show lifecycle without toggling another provider.
    ShowEllesmereBag(frame)
    if not frame:IsVisible() then return end
    local reagent = _G.EUI_ReagentBagFrame
    if pending.reagentOpen and CanShowEllesmereBag(reagent)
        and Offhand.Canvas.IsFrameOnWorkspace(reagent) then
        ShowEllesmereBag(reagent)
    end
    -- Forever counts hiding EllesmereUI's Escape proxy as a handled press.
    -- Reopening the bag alone would let that proxy claim every subsequent press.
    RestoreGameMenuAfterEscape(pending.menuWasShown)
    self:Capture()
end

function Bags:InstallEscapeHooks()
    if not hooksecurefunc then return end
    if Offhand.isForever and CloseSpecialWindows and not self.ellesmereEscapeHooked then
        self.ellesmereEscapeHooked = true
        hooksecurefunc("CloseSpecialWindows", function()
            if Bags.paused or Bags.restoring or not CanOpenBagsFromAddon()
                or not TrackEnabled() or not IsSpanned() or InputReserved() or InCombatLockdown() then return end
            local name, position = Bags:GetSavedPosition()
            local frame = IsForeverEllesmereBag(name) and Bags.frames[name]
            if not position or not CanRestoreEllesmereEscape(frame) then return end
            local pending = {
                frame = frame, reagentOpen = position.reagentOpen,
                menuWasShown = GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown(),
            }
            Bags.ellesmereEscapePending = pending
            C_Timer.After(0, function()
                if Bags.ellesmereEscapePending == pending then Bags.ellesmereEscapePending = nil end
            end)
        end)
    end
    if CloseAllBags and not self.closeAllBagsHooked then
        self.closeAllBagsHooked = true
        hooksecurefunc("CloseAllBags", function()
            if Bags.restoring or InputReserved() or not TrackEnabled() or not IsSpanned()
                or InCombatLockdown() or Bags:GetVisibleFrame() then return end
            local savedName, position = Bags:GetSavedPosition()
            if not position then return end
            if IsForeverEllesmereBag(savedName) then return end
            -- EllesmereUI distinguishes a user-requested bag close from its
            -- Escape proxy hiding the frame. Respect the former even if an
            -- older Offhand open-state sample has not yet been retired.
            if EllesmereExplicitlyClosed(savedName) then
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
            local ellesmere = Bags.ellesmereEscapePending
            Bags.ellesmereEscapePending = nil
            if ellesmere then
                local generation = Bags.generation
                C_Timer.After(0, function()
                    if generation == Bags.generation then Bags:RestoreEllesmereAfterEscape(ellesmere) end
                end)
            end
            if InputReserved() then
                Bags.escapePending = nil
                return
            end
            local pending = Bags.escapePending
            if not pending and CanOpenBagsFromAddon() then
                local savedName, position = Bags:GetSavedPosition()
                local frame = savedName and Bags.frames[savedName]
                local visible = frame and frame.IsVisible and frame:IsVisible() or false
                if position and frame and IsDirectEscapeRoot(savedName, frame) and not visible
                    and not HasConflictingEllesmereBagToggle() then
                    local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
                        and GameMenuFrame:IsShown() or false
                    pending = {
                        menuWasShown = not menuIsShown,
                        source = IsBagnonInventoryRoot(savedName, frame)
                            and "bagnon_toggle_observer" or "baganator_toggle_observer",
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

function Bags:PruneInvalidBaganatorRecords()
    if not Offhand.db then return end
    local records = {
        Offhand.db.savedWorkspacePositions,
        Offhand.db.openWorkspacePanels,
        Offhand.db.baganatorWorkspacePanels,
    }
    for _, record in ipairs(records) do
        if type(record) == "table" then
            for name in pairs(record) do
                if IsBaganatorRootName(name) and _G[name] ~= nil
                    and not IsSupportedRoot(name, _G[name]) then
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
    local euiIntent = type(EllesmereUIDB) == "table"
        and tostring(EllesmereUIDB.bagsVisible) or "unavailable"
    return string.format("Roots=%d | Visible=%d | Saved=%s | EscapeHook=%s/%s | Pending=%s | EUIOpen=%s",
        roots, visible, tostring(savedName or "none"),
        self.closeAllBagsHooked and "yes" or "no",
        self.toggleGameMenuHooked and "yes" or "no",
        self.escapePending and "yes" or "no", euiIntent)
end

function Bags:Resume()
    self.generation = self.generation + 1
    local generation = self.generation
    self.paused = true
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
        Bags:PruneInvalidBaganatorRecords()
        if InputReserved() then
            Bags.waitingForInput = true
            return
        end
        Bags.waitingForInput = false
        local savedName, position = Bags:GetSavedPosition()
        if position and type(position) == "table" and position.x and position.y then
            if EllesmereExplicitlyClosed(savedName) then
                Bags:ForgetOpenSnapshot(savedName)
                Bags.paused = false
                Bags:Capture()
                return
            end
            if IsForeverEllesmereBag(savedName) then
                local frame = Bags.frames[savedName]
                -- The frame exists before EllesmereUI installs its bag
                -- opener and loads the native position on its startup timer.
                if IsPreservingPanelShown() or not (frame and frame.GetNumPoints and frame:GetNumPoints() > 0) then
                    attempts = attempts + 1
                    if attempts < 20 then C_Timer.After(0.25, Restore); return end
                elseif IsSpanned() and not frame:IsShown()
                    and EllesmereUIDB and EllesmereUIDB.bagsVisible == true then
                    local bagsDB = _G.EllesmereUI and _G.EllesmereUI._bagsDB
                    local profile = bagsDB and bagsDB.profile
                    if profile and profile.enhancedBags ~= false then Bags:OpenSavedRoot(savedName) end
                end
                Bags.paused = false
                Bags:Capture()
                return
            end
            local exact = HasConflictingEllesmereBagToggle() and savedName or nil
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
                Offhand.db.baganatorWorkspacePanels = { [visible:GetName()] = position }
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

local events = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "CINEMATIC_STOP"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" or event == "PLAYER_CONTROL_LOST" then
        Bags.paused = true
        Bags.generation = Bags.generation + 1
        Bags.escapePending = nil
        Bags.ellesmereEscapePending = nil
    elseif event == "PLAYER_ENTERING_WORLD"
        or (event == "PLAYER_REGEN_ENABLED" and Bags.waitingForCombat)
        or (event == "PLAYER_CONTROL_GAINED" and Bags.waitingForInput)
        or (event == "CINEMATIC_STOP" and Bags.waitingForInput) then
        Bags:Resume()
    elseif event == "ADDON_LOADED" then
        -- Constant-time EllesmereUI lookup is safe for every addon load. Only
        -- Baganator's own lifecycle is allowed to perform the one global scan.
        Bags:Discover(false)
        if addonName == "Baganator" then
            Bags:InstallBaganatorCallbacks()
            C_Timer.After(0, function() Bags:Discover(true) end)
        elseif addonName == "Bagnon" then
            Bags:InstallBagnonCallbacks()
            C_Timer.After(0, function() Bags:Discover(false) end)
        end
    elseif event == "PLAYER_LOGIN" then
        Bags:InstallBaganatorCallbacks()
        Bags:InstallBagnonCallbacks()
        Bags:Discover(false)
        -- Run after every PLAYER_LOGIN handler so Baganator's initial frame
        -- group exists regardless of addon load order.
        C_Timer.After(0, function() Bags:Discover(true) end)
        Bags:PruneInvalidBaganatorRecords()
        Bags:InstallEscapeHooks()
        if not Bags.ticker then
            Bags.ticker = C_Timer.NewTicker(0.2, function()
                if not Bags.paused then
                    Bags:Capture()
                end
            end)
        end
    end
end)
