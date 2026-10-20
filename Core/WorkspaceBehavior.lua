--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/WorkspaceBehavior.lua: bounded lock-open policy and CharacterFrame scaling
--]]

local _, Offhand = ...

local Behavior = {
    characterState = setmetatable({}, { __mode = "k" }),
    refreshQueued = false,
    sessionReady = false,
    enterWorldGeneration = 0,
}
Offhand.WorkspaceBehavior = Behavior

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsVisible(frame)
    if not frame then return false end
    if frame.IsVisible then return frame:IsVisible() end
    return frame.IsShown and frame:IsShown() or false
end

local function IsSpanned()
    local viewport = Offhand.Viewport
    if not viewport or not viewport.GetMetrics then return false end
    local metrics = viewport:GetMetrics()
    return metrics and metrics.isSpanned == true
end

local function IsAddonLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if checker then
        local ok, loaded = pcall(checker, name)
        if ok then return loaded == true end
    end
    return _G[name] ~= nil
end

local function WindowType(name)
    if name == "WorldMapFrame" then return "map" end
    if name == "CharacterFrame" then return "character" end
    if name == "EUI_MainBagFrame"
        or (type(name) == "string" and name:match("^ContainerFrame%d+$"))
        or name == "ContainerFrameCombinedBags"
        or (type(name) == "string" and name:match("^Baganator_.*BackpackViewFrame")) then
        return "bags"
    end
end

local function LockTypes()
    local db = Offhand.db
    if not db then return nil end
    db.lockedWorkspaceWindowTypes = db.lockedWorkspaceWindowTypes or {
        map = true, bags = true, character = true,
    }
    return db.lockedWorkspaceWindowTypes
end

function Behavior:IsLockSupported()
    -- Forever's panel manager participates in protected Edit Mode and secret
    -- value flows. Keep the stronger lock policy out of that client until each
    -- native panel path has passed live taint testing.
    return not Offhand.isForever
end

function Behavior:IsWindowTypeLocked(kind)
    local db = Offhand.db
    local types = LockTypes()
    return self:IsLockSupported() and db and db.enabled
        and db.lockWorkspaceWindows == true and types and types[kind] ~= false
end

function Behavior:IsFrameLocked(frame, name)
    name = name or (frame and frame.GetName and frame:GetName())
    local kind = WindowType(name)
    if not kind or not self:IsWindowTypeLocked(kind) or not IsSpanned() then return false end
    local saved = Offhand.db and Offhand.db.savedWorkspacePositions
    return type(saved) == "table" and saved[name] ~= nil
end

function Behavior:SetLockEnabled(enabled)
    if not Offhand.db then return false end
    enabled = enabled == true and self:IsLockSupported()
    Offhand.db.lockWorkspaceWindows = enabled
    if enabled then
        -- A lock implies both Escape and reload persistence. Keeping those
        -- settings active lets Canvas use its existing client-specific openers.
        Offhand.db.persistentWorkspacePanels = true
        Offhand.db.restoreWorkspaceOnReload = true
    end
    self:Refresh()
    if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.Refresh then
        Offhand.WorkspaceChrome:Refresh()
    end
    return enabled
end

function Behavior:SetWindowTypeLocked(kind, enabled)
    if kind ~= "map" and kind ~= "bags" and kind ~= "character" then return false end
    local types = LockTypes()
    if not types then return false end
    types[kind] = enabled == true
    self:Refresh()
    if Offhand.WorkspaceChrome and Offhand.WorkspaceChrome.Refresh then
        Offhand.WorkspaceChrome:Refresh()
    end
    return types[kind]
end

function Behavior:GetCharacterScale()
    local value = Offhand.db and tonumber(Offhand.db.characterWorkspaceScale) or 1
    return math.max(0.75, math.min(1.50, value or 1))
end

function Behavior:SetCharacterScale(value)
    if not Offhand.db then return false end
    Offhand.db.characterWorkspaceScale = math.max(0.75, math.min(1.50, tonumber(value) or 1))
    self:RefreshCharacterScale()
    return true
end

function Behavior:RefreshCharacterScale()
    local frame = _G.CharacterFrame
    if not frame or not frame.GetScale or not frame.SetScale or InCombat() then return false end
    local state = self.characterState[frame]
    if not state then
        state = { nativeScale = frame:GetScale(), appliedScale = nil }
        self.characterState[frame] = state
    end

    local db = Offhand.db
    local owned = db and db.enabled and IsSpanned()
        and type(db.savedWorkspacePositions) == "table"
        and db.savedWorkspacePositions.CharacterFrame ~= nil
        and not IsAddonLoadedCompat("ClassicUIForever")
    local multiplier = self:GetCharacterScale()

    if owned then
        local current = frame:GetScale()
        if state.appliedScale and math.abs(current - state.appliedScale) > 0.001 then
            -- Blizzard or another owner established a new native baseline.
            state.nativeScale = current
        end
        local desired = state.nativeScale * multiplier
        if math.abs(current - desired) > 0.001 then frame:SetScale(desired) end
        state.appliedScale = desired
        return true
    end

    if state.appliedScale then
        local current = frame:GetScale()
        if math.abs(current - state.appliedScale) <= 0.001
            and math.abs(current - state.nativeScale) > 0.001 then
            frame:SetScale(state.nativeScale)
        end
        state.appliedScale = nil
    else
        state.nativeScale = frame:GetScale()
    end
    return false
end

function Behavior:RestoreLockedWindows()
    if not self.sessionReady or not self:IsLockSupported() or InCombat() or not Offhand.db
        or not Offhand.db.enabled or not Offhand.db.lockWorkspaceWindows
        or not IsSpanned() then return false end
    local saved = Offhand.db.savedWorkspacePositions
    if type(saved) ~= "table" then return false end

    local types = LockTypes()
    local needsRestore = false
    Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
    for name, position in pairs(saved) do
        local kind = WindowType(name)
        if kind and types[kind] ~= false and type(position) == "table" then
            local frame = _G[name]
            Offhand.db.openWorkspacePanels[name] = true
            if kind == "bags" then
                if name == "ContainerFrameCombinedBags" or name:match("^ContainerFrame%d+$") then
                    Offhand.db.nativeBackpackWorkspaceOpen = true
                elseif name == "EUI_MainBagFrame" or name:match("^Baganator_.*BackpackViewFrame") then
                    Offhand.db.baganatorWorkspacePanels = { [name] = position }
                end
            end
            if not IsVisible(frame) then needsRestore = true end
        end
    end

    if needsRestore and Offhand.Canvas and Offhand.Canvas.RestorePersistentFrames then
        -- Use the shorter active-lock settlement path. The normal login/reload
        -- restoration remains owned by Canvas and must complete only once.
        Offhand.Canvas:RestorePersistentFrames("lock")
    end
    return needsRestore
end

function Behavior:Refresh()
    self:RefreshCharacterScale()
    self:RestoreLockedWindows()
end

function Behavior:QueueRefresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    local function Run()
        Behavior.refreshQueued = false
        Behavior:Refresh()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

function Offhand:InitializeWorkspaceBehavior()
    Behavior:Refresh()
    if C_Timer and C_Timer.NewTicker and not Behavior.ticker then
        Behavior.ticker = C_Timer.NewTicker(0.5, function() Behavior:Refresh() end)
    end
end

-- A normal Blizzard binding allows keyboard and PAD assignments without
-- reserving or rewriting any of the player's existing controller buttons.
function Offhand_ToggleSettings()
    if not Offhand.Options then return end
    -- Options:Open already toggles the existing panel when it is visible.
    Offhand.Options:Open()
end

-- Forever already owns the complete UI focus transition behind its hidden
-- TOGGLEUIFOCUS binding. Expose a normal, player-assignable Offhand binding
-- that delegates to that native action during the original hardware event.
-- Do not reproduce the transition or inspect FrameControlsManager state here.
function Offhand_ToggleGamepadUIFocus()
    if not Offhand.isForever or not Offhand.db or not Offhand.db.enabled then
        return false, "disabled"
    end

    local mainhand = Offhand.Mainhand
    if not mainhand or type(mainhand.IsNativeGamepadInterface) ~= "function"
        or not mainhand:IsNativeGamepadInterface() then
        return false, "gamepad"
    end

    if type(RunBinding) ~= "function" then return false, "binding" end
    RunBinding("TOGGLEUIFOCUS")
    return true
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        Behavior.enterWorldGeneration = Behavior.enterWorldGeneration + 1
        Behavior.sessionReady = false
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        Behavior.enterWorldGeneration = Behavior.enterWorldGeneration + 1
        local generation = Behavior.enterWorldGeneration
        Behavior.sessionReady = false
        local function EnableAfterStartupRestore()
            if generation ~= Behavior.enterWorldGeneration then return end
            Behavior.sessionReady = true
            Behavior:Refresh()
        end
        -- Canvas restores the saved reload state at 0.5 to 2.0 seconds.
        -- Begin active lock enforcement only after those native openers and
        -- Blizzard's own panel settlement have completed.
        if C_Timer and C_Timer.After then
            C_Timer.After(2.25, EnableAfterStartupRestore)
        else
            EnableAfterStartupRestore()
        end
        return
    end
    Behavior:QueueRefresh()
end)
