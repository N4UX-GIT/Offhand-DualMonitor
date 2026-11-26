--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/KerzoQuestLog/Bridge.lua: built-in bridge for Kerzo Classic Quest Log

    This is the former Core/CanvasKerzoQuestLog.lua moved behind the bridge
    contract; its behaviour is unchanged. It reads Offhand's state, the workspace
    test and the character's saved open intent (stored under its old key,
    kerzoQuestLogOpen) through Offhand.API only. Its data supplies the addon
    window catalog entry, the workspace close button frame and that setting.

    Like the core module it registers on every client before Kerzo exists and
    looks the quest log up on every refresh, so a Kerzo that loads after Offhand
    is still handled. Hooks are installed only on the Forever client.
--]]

-- Kerzo 6.1.4 owns its geometry, visibility and modal Escape ordering.
-- Adapt its root's Escape registration and explicit workspace reload intent.
local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.GetBridgeNamespace) ~= "function" or type(API.GetBridgeCharacterSetting) ~= "function"
    or type(API.SetBridgeCharacterSetting) ~= "function" or type(API.IsFrameOnWorkspace) ~= "function"
    or type(API.GetOptionsMetrics) ~= "function" then return end

local ID, SETTING = "KerzoQuestLog", "kerzoQuestLogOpen"
local Adapter = API.GetBridgeNamespace(ID)
local states = setmetatable({}, {__mode="k"})
local refreshing = false
local name = "KerzosQuestLog"
local sessionReady, paused, restorePending, restoreDeadline

local function SaveOpenIntent(open)
    local value = open and true or nil
    if API.GetBridgeCharacterSetting(ID, SETTING) == value then return end
    -- No write without the character table, as before.
    if not API.SetBridgeCharacterSetting(ID, SETTING, value) then return end
    -- Forever can restore stale ordinary SavedVariables during /reload. Use
    -- its existing character-scoped profile snapshot as well as disk state.
    API.FlushBridgeStorage()
end

function Adapter:BeginSession()
    paused = false
    if sessionReady then return end
    sessionReady = true
    restorePending = API.GetBridgeCharacterSetting(ID, SETTING) == true
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
    return API.IsControllerOwned() or API.IsNativeGamepadInterface()
end

local function Refresh()
    if paused or (InCombatLockdown and InCombatLockdown()) then return false end
    if restorePending and GetTime() > restoreDeadline then restorePending = false end
    local frame = _G[name]
    if not Accessible(frame) or type(UISpecialFrames) ~= "table" then return false end
    local state = states[frame]
    if not state then
        if not API.IsForeverClient() or ControllerOwned() or not hooksecurefunc then return false end
        state = {}
        states[frame] = state
    end
    local function AfterVendorLayout(self)
        if self == _G[name] then
            Adapter:Refresh()
            API.RefreshWorkspaceChrome()
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
    -- Escape protection: enabled with persistent workspace panels; options
    -- metrics: enabled and spanned.
    local workspace = API.IsForeverClient() and API.IsEscapeProtectionEnabled()
        and not ControllerOwned()
        and API.GetOptionsMetrics() ~= nil
        and not API.IsGeometryTransitionActive()
        and API.IsFrameOnWorkspace(frame)
    local reloadEnabled = API.IsWorkspacePersistenceEnabled()
    if restorePending then
        if not reloadEnabled or ControllerOwned() or not API.IsForeverClient() then
            restorePending = false
        elseif frame:IsShown() then
            -- A manual open wins over the queued startup restoration.
            restorePending = false
        elseif workspace and frame.cfg and type(frame.CambiarVisibilidad) == "function"
            and not (GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown())
            and not API.IsInputReserved() then
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

local bridge = {
    contract = API.BRIDGE_CONTRACT,
    data = {
        catalogs = {
            ["Kerzo Classic Quest Log"] = {
                questLog = {position = "addon", close = "quest-log-adapter", restoreOpen = "adapter"},
            },
        },
        frameRules = {
            workspaceChrome = { name },
        },
        settings = {
            [SETTING] = { store = "character", legacyKey = SETTING, resetOnCharacterChange = true },
        },
    },
}

-- The persistence pass and the Forever position ticker ran the adapter; the
-- ticker skipped it during a geometry transition.
function bridge:Refresh(reason)
    if reason == "persistence" or (reason == "tick" and not API.IsGeometryTransitionActive()) then
        Adapter:Refresh()
    end
end

function bridge:PrepareTransition()
    Adapter:PauseForTransition()
end

function bridge:BeginSession()
    Adapter:BeginSession()
end

API.RegisterBridge(ID, bridge)
