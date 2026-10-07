-- Guarded title grips must preserve Blizzard template behavior, avoid panel-body
-- mouse ownership, and remain unavailable in combat.

local addon = {}
local inCombat = false
InCombatLockdown = function() return inCombat end

local function makeFrame(name)
    local frame = {
        name = name,
        shown = true,
        mouseWrites = 0,
        points = {},
        level = 10,
        movable = false,
    }
    function frame:GetName() return self.name end
    function frame:IsForbidden() return false end
    function frame:SetMovable(value) self.movable = value == true end
    function frame:IsMovable() return self.movable end
    function frame:SetClampedToScreen(value) self.clamped = value == true end
    function frame:EnableMouse() self.mouseWrites = self.mouseWrites + 1 end
    function frame:GetFrameLevel() return self.level end
    function frame:StartMoving() self.starts = (self.starts or 0) + 1 end
    function frame:StopMovingOrSizing() self.stops = (self.stops or 0) + 1 end
    return frame
end

local function makeGrip(parent, template)
    local grip = { parent = parent, template = template, scripts = {}, points = {}, shown = true }
    function grip:ClearAllPoints() self.points = {} end
    function grip:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function grip:SetHeight(value) self.height = value end
    function grip:SetFrameLevel(value) self.level = value end
    function grip:EnableMouse(value) self.mouse = value == true end
    function grip:Show() self.shown = true end
    function grip:Hide() self.shown = false end
    function grip:HookScript(name, callback)
        local native = self.scripts[name]
        self.scripts[name] = function(...)
            if native then native(...) end
            callback(...)
        end
    end
    grip.scripts.OnDragStart = function(self) self.parent:StartMoving() end
    grip.scripts.OnDragStop = function(self) self.parent:StopMovingOrSizing() end
    return grip
end

CreateFrame = function(_, _, parent, template)
    assert(template == "PanelDragBarTemplate", "only Blizzard's title-drag template is expected")
    return makeGrip(parent, template)
end
RegisterStateDriver = function(frame, state, condition)
    frame.stateDrivers = frame.stateDrivers or {}
    frame.stateDrivers[state] = condition
end
UnregisterStateDriver = function(frame, state)
    if frame.stateDrivers then frame.stateDrivers[state] = nil end
end

assert(loadfile("Core/PanelMotion.lua"))("Offhand", addon)
local motion = addon.PanelMotion

local blocked = makeFrame("BlockedInCombat")
inCombat = true
local blockedGrip, blockedStatus = motion:AttachGuardedTitleGrip(blocked)
assert(blockedGrip == nil and blockedStatus == "combat_deferred",
    "title grips must never be configured during combat")
inCombat = false

local panel = makeFrame("ExperimentalPanel")
local began, finished = 0, 0
local grip, status = motion:AttachGuardedTitleGrip(panel, {
    onBegin = function() began = began + 1 end,
    onFinish = function() finished = finished + 1 end,
})
assert(grip and status == "active" and grip.template == "PanelDragBarTemplate",
    "a guarded grip must be created from the Blizzard template")
assert(panel.mouseWrites == 0,
    "attaching a title grip must not enable mouse input on the panel body")
assert(grip.stateDrivers.visibility == "[combat] hide; show",
    "the grip must use secure combat visibility")
assert(#grip.points == 2 and grip.height == 32,
    "the grip must remain constrained to a narrow title region")

grip.scripts.OnDragStart(grip)
grip.scripts.OnDragStop(grip)
assert(panel.starts == 1 and panel.stops == 1,
    "the Blizzard template's native gesture scripts must remain intact")
assert(began == 1 and finished == 1,
    "Offhand must observe the gesture without replacing native scripts")

local deactivated, inactiveStatus = motion:SetTitleGripActive(panel, false)
assert(deactivated and inactiveStatus == "inactive" and not grip.shown and not grip.mouse,
    "deactivation must hide the grip and release mouse ownership")
assert(not grip.stateDrivers.visibility,
    "deactivation must unregister secure visibility state")

local reactivated, activeStatus = motion:SetTitleGripActive(panel, true)
assert(reactivated and activeStatus == "active" and grip.shown and grip.mouse,
    "an existing grip must reactivate without creating another frame")

inCombat = true
local changed, deferredStatus = motion:SetTitleGripActive(panel, false)
assert(not changed and deferredStatus == "combat_deferred" and grip.shown,
    "combat-time changes must defer without mutating the protected grip")
inCombat = false

local noGuardPanel = makeFrame("NoCombatGuard")
RegisterStateDriver = nil
local noGuardGrip, noGuardStatus = motion:AttachGuardedTitleGrip(noGuardPanel)
assert(noGuardGrip == nil and noGuardStatus == "combat_guard_unavailable",
    "attachment must fail closed when secure combat visibility is unavailable")
assert(not noGuardPanel.movable and noGuardPanel.mouseWrites == 0,
    "a failed secure grip must leave the Blizzard panel itself untouched")

print("PASS: guarded title motion preserves native scripts and fails closed")
