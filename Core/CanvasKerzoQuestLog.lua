-- Kerzo 6.1.4 owns its geometry, visibility and modal Escape ordering.
-- Adapt its root's Escape registration and explicit workspace reload intent.
local _, Offhand = ...
local Adapter = {}
Offhand.CanvasKerzoQuestLog = Adapter
local states = setmetatable({}, {__mode="k"})
local refreshing = false
local name = "KerzosQuestLog"
local sessionReady, paused, restorePending, restoreDeadline

local function SaveOpenIntent(open)
    if type(OffhandCharDB) ~= "table" then return end
    local value = open and true or nil
    if OffhandCharDB.kerzoQuestLogOpen == value then return end
    OffhandCharDB.kerzoQuestLogOpen = value
    -- Forever can restore stale ordinary SavedVariables during /reload. Use
    -- its existing character-scoped profile snapshot as well as disk state.
    local persistence = Offhand.ForeverPersistence
    if persistence and persistence.SaveProfileSnapshot then persistence:SaveProfileSnapshot(true) end
end

function Adapter:BeginSession()
    paused = false
    if sessionReady then return end
    sessionReady = true
    restorePending = type(OffhandCharDB) == "table" and OffhandCharDB.kerzoQuestLogOpen == true
    restoreDeadline = GetTime() + 15
end

function Adapter:PauseForTransition()
    -- Preserve the last observed user intent before teardown hides the root.
    paused = true
    restorePending = false
end

local function Accessible(frame)
    return frame and frame.IsShown and frame.GetParent and frame:GetParent() == UIParent
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and type(frame.ActualizarEstadoEscapeModal) == "function"
end

local function ControllerOwned()
    local compatibility = Offhand.MainhandCompatibility
    return _G.ConsolePort ~= nil or (compatibility and compatibility.IsNativeGamepadInterface
        and compatibility.IsNativeGamepadInterface())
end

local function Refresh()
    if paused or (InCombatLockdown and InCombatLockdown()) then return false end
    if restorePending and GetTime() > restoreDeadline then restorePending = false end
    local frame = _G[name]
    if not Accessible(frame) or type(UISpecialFrames) ~= "table" then return false end
    local state = states[frame]
    if not state then
        if not Offhand.isForever or ControllerOwned() or not hooksecurefunc then return false end
        state = {}
        states[frame] = state
    end
    local function AfterVendorLayout(self)
        if self == _G[name] then
            Adapter:Refresh()
            if Offhand.WorkspaceChrome then Offhand.WorkspaceChrome:Refresh() end
        end
    end
    if not state.escapeHooked then
        hooksecurefunc(frame, "ActualizarEstadoEscapeModal", AfterVendorLayout)
        state.escapeHooked = true
    end
    if not state.positionHooked and type(frame.MemorizarPosicion) == "function" then
        hooksecurefunc(frame, "MemorizarPosicion", AfterVendorLayout)
        state.positionHooked = true
    end
    if not state.chromeHooked and type(frame.CalibrarCabeceraYCierre) == "function" then
        hooksecurefunc(frame, "CalibrarCabeceraYCierre", AfterVendorLayout)
        state.chromeHooked = true
    end
    local db = Offhand.db
    local canvas = Offhand.Canvas
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    local workspace = Offhand.isForever and db and db.enabled
        and db.persistentWorkspacePanels ~= false and not ControllerOwned()
        and metrics and metrics.isSpanned
        and not Offhand._displayGeometryTransitionActive
        and canvas and canvas.IsFrameOnWorkspace and canvas.IsFrameOnWorkspace(frame)
    local reloadEnabled = db and db.enabled and db.persistentWorkspacePanels ~= false
        and db.restoreWorkspaceOnReload ~= false
    if restorePending then
        if not reloadEnabled or ControllerOwned() or not Offhand.isForever then
            restorePending = false
        elseif frame:IsShown() then
            -- A manual open wins over the queued startup restoration.
            restorePending = false
        elseif workspace and frame.cfg and type(frame.CambiarVisibilidad) == "function"
            and not (GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown())
            and not (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then
            -- The vendor's opener runs its normal OnShow initialization and
            -- retains its own saved geometry. Never restore a bare frame shell.
            frame:CambiarVisibilidad()
            restorePending = not frame:IsShown()
        end
    end
    if sessionReady and not restorePending then
        SaveOpenIntent(workspace and reloadEnabled and frame:IsShown())
    end
    local active = workspace and frame:IsShown()
    if active then
        -- Do not touch modal entries. Kerzo will register/remove those itself.
        for index = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[index] == name then
                table.remove(UISpecialFrames, index)
                state.suppressed = true
            end
        end
    elseif state.suppressed then
        state.suppressed = nil
        -- Ask the vendor to recompute its own current modal/visibility state.
        -- Blindly adding the root would break Escape priority for its dialogs.
        frame:ActualizarEstadoEscapeModal()
    end
    return active and true or false
end

function Adapter:Refresh()
    if refreshing then return false end
    refreshing = true
    local ok, active = pcall(Refresh)
    refreshing = false
    return ok and active or false
end
