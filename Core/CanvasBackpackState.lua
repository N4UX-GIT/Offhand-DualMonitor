--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasBackpackState.lua: Native backpack root and profile state policy
--]]

local _, Offhand = ...

local BackpackState = {}
Offhand.CanvasBackpackState = BackpackState

function BackpackState.UsesTBCBagIDs()
    local registry = Offhand.CanvasPanelRegistry
    return registry and registry.IsTBCPanelRuntime and registry.IsTBCPanelRuntime()
        and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon())
end

local function TBCBagPolicyEnabled(Canvas)
    local db = Offhand.db
    if not BackpackState.UsesTBCBagIDs() or not db or not db.enabled
        or db.persistentWorkspacePanels == false or db.restoreWorkspaceOnReload == false
        or (Canvas.CanManagePanelsFromAddon and not Canvas.CanManagePanelsFromAddon()) then return false end
    local viewport = Offhand.Viewport
    local metrics = viewport and viewport.GetMetrics and viewport:GetMetrics()
    return metrics and metrics.isSpanned == true
end

local function CopyPosition(position)
    if type(position) ~= "table" then return nil end
    local x, y = tonumber(position.x), tonumber(position.y)
    if not x or not y or x ~= x or y ~= y or math.abs(x) >= math.huge or math.abs(y) >= math.huge then return nil end
    local copy = {}
    for k, v in pairs(position) do copy[k] = v end
    copy.x, copy.y = x, y
    return copy
end

local function ReadTBCBagIDs(Canvas)
    local snapshot = {schema=1, open={}}
    local saved = Offhand.db.savedWorkspacePositions or {}
    for index = 1, math.min(tonumber(NUM_CONTAINER_FRAMES) or 13, 40) do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.IsShown and frame.GetID and frame.GetName then
            pcall(function()
                if frame.IsForbidden and frame:IsForbidden() then return end
                if not frame:IsShown() then return end
                local id = frame:GetID()
                if type(id) ~= "number" or id < 0 or id > 4 or id ~= math.floor(id) then return end
                if Canvas.IsFrameOnWorkspace and Canvas.IsFrameOnWorkspace(frame) then
                    local position = CopyPosition(saved[frame:GetName()])
                    -- Grouped bag layout intentionally removes individual frame
                    -- records. A visible workspace bag still has a real position.
                    if not position and Offhand.CanvasPersistence and frame.GetLeft and frame.GetTop
                        and frame.GetWidth and frame.GetHeight and frame.GetEffectiveScale
                        and UIParent and UIParent.GetEffectiveScale then
                        local parentScale, frameScale = UIParent:GetEffectiveScale(), frame:GetEffectiveScale()
                        local left, top = frame:GetLeft(), frame:GetTop()
                        if parentScale > 0 and frameScale > 0 and left and top then
                            local factor = frameScale / parentScale
                            local metrics = Offhand.Viewport:GetMetrics()
                            position = Offhand.CanvasPersistence.CreateWorkspacePosition(metrics,
                                left * factor, top * factor, frame:GetWidth() * factor, frame:GetHeight() * factor,
                                false, UIParent.GetHeight and UIParent:GetHeight() or 1080)
                        end
                    end
                    if position then snapshot.open[tostring(id)] = {position=position} end
                end
            end)
        end
    end
    return snapshot
end

local function BagSignature(snapshot)
    local entries = {}
    for id = 0, 4 do
        local entry = snapshot.open[tostring(id)]
        if entry then entries[#entries+1] = id .. ":" .. tostring(entry.position.x) .. "/" .. tostring(entry.position.y) end
    end
    return table.concat(entries, ",")
end

function BackpackState.CaptureTBCBagIDs(Canvas, changedOnly)
    if not TBCBagPolicyEnabled(Canvas) then return end
    local snapshot = ReadTBCBagIDs(Canvas)
    local signature = BagSignature(snapshot)
    if changedOnly and signature == Canvas.tbcBagObservedSignature then
        Canvas.tbcBagCaptureStatus = "unchanged"
        return
    end
    Canvas.tbcBagObservedSignature = signature
    Canvas.tbcBagCaptureStatus = "recorded"
    Offhand.db.tbcWorkspaceBagSnapshot = snapshot
    Canvas.tbcBagRestoreGeneration = (Canvas.tbcBagRestoreGeneration or 0) + 1
end

function BackpackState.InstallTBCBagIDTracking(Canvas)
    if not TBCBagPolicyEnabled(Canvas) or not hooksecurefunc then return end
    -- A fresh UI initially has no visible bags, even if the persisted snapshot
    -- asks to reopen one. Record that observed baseline without replacing intent.
    if Canvas.tbcBagObservedSignature == nil then
        Canvas.tbcBagObservedSignature = BagSignature(ReadTBCBagIDs(Canvas))
    end
    Canvas.tbcBagIDHooks = Canvas.tbcBagIDHooks or {}
    for _, name in ipairs({"OpenBag", "CloseBag", "OpenBackpack", "CloseBackpack", "ToggleBag",
        "ToggleBackpack", "ToggleAllBags", "OpenAllBags", "CloseAllBags", "ContainerFrame_OnHide"}) do
        if type(_G[name]) == "function" and not Canvas.tbcBagIDHooks[name] then
            Canvas.tbcBagIDHooks[name] = true
            hooksecurefunc(name, function()
                if Canvas.tbcBagIDRestoring or Canvas.tbcBagIDCapturePending
                    or Offhand._openPanelsCapturedForTransition or not C_Timer or not C_Timer.After then return end
                Canvas.tbcBagIDCapturePending = true
                C_Timer.After(0, function()
                    Canvas.tbcBagIDCapturePending = nil
                    if not Offhand._openPanelsCapturedForTransition then BackpackState.CaptureTBCBagIDs(Canvas, true) end
                end)
            end)
        end
    end
end

function BackpackState.QueueTBCBagIDRestore(Canvas, delay)
    if not TBCBagPolicyEnabled(Canvas) or not C_Timer or not C_Timer.After then return end
    local snapshot = Offhand.db.tbcWorkspaceBagSnapshot
    if type(snapshot) ~= "table" or snapshot.schema ~= 1 or type(snapshot.open) ~= "table" then
        Canvas.tbcBagIDRestoreStatus = "legacy-frame-intent-ignored"
        return
    end
    Canvas.tbcBagRestoreGeneration = (Canvas.tbcBagRestoreGeneration or 0) + 1
    local generation = Canvas.tbcBagRestoreGeneration
    C_Timer.After(delay or 1.5, function()
        if generation ~= Canvas.tbcBagRestoreGeneration or not TBCBagPolicyEnabled(Canvas)
            or Offhand.db.tbcWorkspaceBagSnapshot ~= snapshot then return end
        if InCombatLockdown and InCombatLockdown() then
            if Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(function()
                    if generation == Canvas.tbcBagRestoreGeneration then BackpackState.QueueTBCBagIDRestore(Canvas, 0) end
                end)
            end
            return
        end
        if type(OpenBag) ~= "function" or type(IsBagOpen) ~= "function" then
            Canvas.tbcBagIDRestoreStatus = "native-api-unavailable"
            return
        end
        local requested, shown, workspace = 0, 0, 0
        Canvas.tbcBagIDRestoring = true
        for id = 0, 4 do
            local entry = snapshot.open[tostring(id)]
            local position = type(entry) == "table" and CopyPosition(entry.position)
            if position then
                if not IsBagOpen(id) then pcall(OpenBag, id); requested = requested + 1 end
                -- IsBagOpen returns the allocated frame index, which can differ
                -- from the previous session. Follow the bag ID to its new root.
                local index = IsBagOpen(id)
                local frame = type(index) == "number" and _G["ContainerFrame" .. index]
                if frame and frame.GetName and frame.GetID and frame:GetID() == id then
                    shown = shown + 1
                    local name = frame:GetName()
                    Offhand.db.savedWorkspacePositions[name] = position
                    if Canvas.RestoreWorkspacePosition then pcall(Canvas.RestoreWorkspacePosition, frame) end
                    if Canvas.IsFrameOnWorkspace and Canvas.IsFrameOnWorkspace(frame) then workspace = workspace + 1 end
                end
            end
        end
        Canvas.tbcBagIDRestoring = nil
        Canvas.tbcBagObservedSignature = BagSignature(ReadTBCBagIDs(Canvas))
        Canvas.tbcBagIDRestoreStatus = "requested=" .. requested .. ",shown=" .. shown .. ",workspace=" .. workspace
    end)
end

BackpackState.RootNames = {
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
}

function BackpackState.IsForeverContainerName(name)
    return Offhand.isForever and type(name) == "string"
        and name:match("^ContainerFrame") ~= nil
end

function BackpackState.IsRoot(name)
    return name == "ContainerFrame1" or name == "ContainerFrameCombinedBags"
end

function BackpackState.IsRestorableRootName(name)
    if type(name) ~= "string" then return false end
    return name:match("^ContainerFrame%d+$") ~= nil
        or name == "ContainerFrameCombinedBags"
        or name == "EUI_MainBagFrame"
        or name:match("^Baganator_SingleViewBackpackViewFrame") ~= nil
        or name:match("^Baganator_CategoryViewBackpackViewFrame") ~= nil
        or name:match("^Baginator") ~= nil
        or name:match("^BGR") ~= nil
        or name:match("^Bagnon") ~= nil
        or name:match("^AdiBags") ~= nil
        or name:match("^BetterBags") ~= nil
        or name:match("^ArkInventory") ~= nil
        or name == "CustomBagRestorer"
end

function BackpackState.ClearOtherRoots(db, keepName)
    if type(db) ~= "table" then return false end
    local changedOpenState = false
    for _, rootName in ipairs(BackpackState.RootNames) do
        if rootName ~= keepName then
            if type(db.savedWorkspacePositions) == "table" then
                db.savedWorkspacePositions[rootName] = nil
            end
            if type(db.savedMainPositions) == "table" then
                db.savedMainPositions[rootName] = nil
            end
            if type(db.openWorkspacePanels) == "table" and db.openWorkspacePanels[rootName] then
                db.openWorkspacePanels[rootName] = nil
                changedOpenState = true
            end
        end
    end
    return changedOpenState
end

function BackpackState.GetWorkspacePosition(db)
    if type(db) ~= "table" then return nil end
    local position = db.nativeBackpackWorkspacePosition
    if type(position) == "table" and position.x and position.y then
        return position
    end
    local saved = db.savedWorkspacePositions
    if type(saved) ~= "table" then return nil end
    for _, rootName in ipairs(BackpackState.RootNames) do
        position = saved[rootName]
        if type(position) == "table" and position.x and position.y then
            db.nativeBackpackWorkspacePosition = position
            return position
        end
    end
    return nil
end

function BackpackState.IsTrackedOpen(db)
    if type(db) ~= "table" then return false end
    if db.nativeBackpackWorkspaceOpen == true then return true end
    local openPanels = db.openWorkspacePanels
    if type(openPanels) ~= "table" then return false end
    for _, rootName in ipairs(BackpackState.RootNames) do
        if openPanels[rootName] then
            db.nativeBackpackWorkspaceOpen = true
            return true
        end
    end
    return false
end

function BackpackState.ClearOpenState(db)
    if type(db) ~= "table" then return false end
    local changed = db.nativeBackpackWorkspaceOpen ~= nil
    db.nativeBackpackWorkspaceOpen = nil
    db.openWorkspacePanels = db.openWorkspacePanels or {}
    for _, rootName in ipairs(BackpackState.RootNames) do
        if db.openWorkspacePanels[rootName] ~= nil then changed = true end
        db.openWorkspacePanels[rootName] = nil
    end
    return changed
end

function BackpackState.GetShownRoot()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.IsShown and combined:IsShown() then return combined end
    local individual = _G.ContainerFrame1
    if individual and individual.IsShown and individual:IsShown() then return individual end
    return nil
end

function BackpackState.GetPreferredRoot(db)
    local saved = type(db) == "table" and db.savedWorkspacePositions or nil
    if saved and saved.ContainerFrameCombinedBags then return _G.ContainerFrameCombinedBags end
    if saved and saved.ContainerFrame1 then return _G.ContainerFrame1 end
    local prefersCombined = GetCVarBool and GetCVarBool("combinedBags")
    return prefersCombined and _G.ContainerFrameCombinedBags or _G.ContainerFrame1
end

