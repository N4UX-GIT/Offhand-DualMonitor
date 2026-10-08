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

local function IsSupportedRoot(name, frame)
    if name == "EUI_MainBagFrame" then return true end
    if not IsBaganatorRootName(name) then return false end
    -- Baganator derives the names of every child region from the backpack
    -- root. A prefix-only match therefore also catches title text, textures,
    -- and buttons. Its actual backpack roots are direct UIParent children.
    return frame and frame.GetParent and frame:GetParent() == UIParent
end

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
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

function Bags:ForgetOpenSnapshot(name)
    if not Offhand.db then return end
    local saved = Offhand.db.baganatorWorkspacePanels
    if type(saved) ~= "table" then return end
    if name then saved[name] = nil else wipe(saved) end
end

function Bags:GetSavedPosition()
    local saved = Offhand.db and Offhand.db.baganatorWorkspacePanels or {}
    for name, position in pairs(saved) do
        if type(position) == "table" and position.x and position.y then
            return name, position
        end
    end
end

function Bags:GetVisibleFrame()
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
        or not frame.GetName or not frame.HookScript or self.frames[name] then
        return false
    end
    self.frames[name] = frame
    if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.RegisterDynamicFrame then
        Offhand.WorkspaceChrome:RegisterDynamicFrame(name)
    end
    local function Changed()
                -- Baganator registers its root in UISpecialFrames, so Forever
                -- can hide it directly before ToggleGameMenu without calling
                -- CloseAllBags. Pair that root hide with the same immediate
                -- Game Menu toggle used by Escape. A bag-key or X close has no
                -- paired toggle and is allowed to expire normally.
                if IsBaganatorRootName(name) and not Bags.paused
                    and not Bags.restoring and TrackEnabled() and IsSpanned()
                    and not InCombatLockdown() then
                    local savedName, position = Bags:GetSavedPosition()
                    if position and savedName == name then
                        local pending = {
                            menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                                and GameMenuFrame:IsShown() or false,
                            source = "baganator_root_hide",
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
    if self.paused or self.restoring or self.escapePending or not Offhand.db then return end
    local snapshot = {}
    if TrackEnabled() then
        for name, frame in pairs(self.frames) do
            if not (frame.IsForbidden and frame:IsForbidden()) and frame:IsVisible() then
                if Offhand.Canvas.IsFrameOnWorkspace(frame) then
                    local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    local x = frame:GetLeft()
                    local y = frame.GetTop and frame:GetTop() or nil
                    if not y and frame.GetBottom and frame.GetHeight then
                        y = frame:GetBottom() + frame:GetHeight()
                    end
                    if x and y then
                        local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
                        local position = {
                            x = x * factor, y = y * factor,
                            coordinateVersion = 2,
                            canvasWidth = metrics and metrics.workspaceWidth or nil,
                            canvasHeight = metrics and metrics.workspaceHeight or nil,
                            canvasLeft = metrics and metrics.workspaceLeft or nil,
                            canvasBottom = metrics and metrics.workspaceBottom or nil,
                        }
                        snapshot[name] = position
                        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
                        Offhand.db.savedWorkspacePositions[name] = position
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
    Offhand.db.baganatorWorkspacePanels = snapshot
end

function Bags:RestoreAfterEscape(pending)
    if self.escapePending ~= pending then return false end
    self.escapePending = nil
    if InputReserved() or not TrackEnabled() or not IsSpanned() or InCombatLockdown() then
        self:Capture()
        return false
    end

    local savedName, position = self:GetSavedPosition()
    if not position then return false end
    if EllesmereExplicitlyClosed(savedName) then
        self:ForgetOpenSnapshot(savedName)
        return false
    end
    self.restoring = true
    self:Discover()
    local visible = self:GetVisibleFrame()
    if not visible and ToggleAllBags then
        pcall(ToggleAllBags)
        self:Discover()
        visible = self:GetVisibleFrame()
    end

    if visible then
        local name = visible:GetName()
        position = self:NormalizePosition(position, visible)
        Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
        Offhand.db.savedWorkspacePositions[name] = position
        Offhand.db.baganatorWorkspacePanels = { [name] = position }
        Offhand.Canvas:RestoreWorkspacePosition(visible)
    end

    -- Opening a bag can dismiss Forever's Game Menu. Restore the state that the
    -- Escape press itself requested without invoking ToggleGameMenu a second time.
    local menuShouldBeShown = not pending.menuWasShown
    local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
        and GameMenuFrame:IsShown() or false
    if menuShouldBeShown ~= menuIsShown and GameMenuFrame then
        if menuShouldBeShown and GameMenuFrame.Show then
            pcall(GameMenuFrame.Show, GameMenuFrame)
        elseif GameMenuFrame.Hide then
            pcall(GameMenuFrame.Hide, GameMenuFrame)
        end
    end

    self.restoring = false
    self:Capture()
    return visible ~= nil
end

function Bags:InstallEscapeHooks()
    if not hooksecurefunc then return end
    if CloseAllBags and not self.closeAllBagsHooked then
        self.closeAllBagsHooked = true
        hooksecurefunc("CloseAllBags", function()
            if Bags.restoring or InputReserved() or not TrackEnabled() or not IsSpanned()
                or InCombatLockdown() or Bags:GetVisibleFrame() then return end
            local savedName, position = Bags:GetSavedPosition()
            if not position then return end
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
            if InputReserved() then
                Bags.escapePending = nil
                return
            end
            local pending = Bags.escapePending
            if not pending then return end
            C_Timer.After(0, function() Bags:RestoreAfterEscape(pending) end)
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
        Bags:Discover(false)
        Bags:PruneInvalidBaganatorRecords()
        if InputReserved() then
            Bags.waitingForInput = true
            return
        end
        Bags.waitingForInput = false
        local saved = Offhand.db.baganatorWorkspacePanels or {}
        local savedName, position = next(saved)
        if position and type(position) == "table" and position.x and position.y then
            if EllesmereExplicitlyClosed(savedName) then
                Bags:ForgetOpenSnapshot(savedName)
                Bags.paused = false
                Bags:Capture()
                return
            end
            local visible
            for _, frame in pairs(Bags.frames) do
                if frame:IsVisible() then visible = frame; break end
            end
            if not visible and next(Bags.frames) and ToggleAllBags and not toggled then
                toggled = true
                ToggleAllBags()
                for _, frame in pairs(Bags.frames) do
                    if frame:IsVisible() then visible = frame; break end
                end
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
        end
    elseif event == "PLAYER_LOGIN" then
        Bags:InstallBaganatorCallbacks()
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
