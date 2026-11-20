-- The Forever client reissues TOPLEFT on the manager for mouse and gamepad.
-- GetPoint can round the native -200 / -140 offsets when the UI is scaled.
local spanned, locked, geometryChanged, onEvent
local region = {}
UIParent = {}
local function noop() end
local offhand = {
    isForever = true,
    MainhandGeometry = {},
    Mainhand = {
        Update = noop, CreateAnchor = function() return region end,
        GetRect = function() return {isSpanned = spanned} end,
        EnableForeverGamepadMainMenuAdapter = noop,
    },
    API = {RegisterGeometryCallback = function(_, callback) geometryChanged = callback end},
}
CreateFrame = function()
    return {
        RegisterEvent = noop, SetScript = function(_, _, fn) onEvent = fn end,
        SetFrameStrata = function(self, strata) self.strata = strata end,
        EnableMouse = function(self, mouse) self.mouse = mouse end,
        SetAllPoints = function(self, frame) self.bounds = frame end,
        SetClipsChildren = function(self, clip) self.clips = clip end,
    }
end
InCombatLockdown = function() return locked end
hooksecurefunc = function(frame, method, hook)
    local original = frame[method]
    frame[method] = function(...) original(...) hook(...) end
end
assert(loadfile("Core/Mainhand.lua"))("Offhand", offhand)
spanned = true
geometryChanged() -- Blizzard's module can load after the span.
local manager = {
    parent = UIParent, point = {"TOPLEFT", UIParent, "TOPLEFT", -199.99997, -139.99998},
    GetNumPoints = function() return 1 end,
    GetPoint = function(self) return unpack(self.point) end,
    GetParent = function(self) return self.parent end,
    IsProtected = function(self) return self.protected end,
    IsForbidden = function(self) return self.forbidden end,
    SetParent = function(self, parent) assert(not locked) self.parent = parent end,
    SetPoint = function(self, ...) self.point = {...} end,
}
CompactRaidFrameManager = manager
onEvent(nil, "ADDON_LOADED", "Blizzard_CompactRaidFrames")
local clip = manager.parent
assert(clip ~= UIParent and clip.bounds == region and clip.clips and clip.mouse == false)
assert(clip.strata == "DIALOG" and manager.point[2] == clip)
local function native(x) manager:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, -140) end
native(0)
assert(manager.point[2] == clip and manager.point[4] == 0)
locked = true
native(-200)
assert(manager.point[2] == clip)
manager.protected = true
native(0)
assert(manager.point[2] == UIParent)
locked = false
onEvent(nil, "PLAYER_REGEN_ENABLED")
assert(manager.point[2] == clip)
spanned = false
geometryChanged()
assert(manager.parent == UIParent and manager.point[2] == UIParent and manager.point[4] == 0)
spanned = true
geometryChanged()
manager:SetPoint("CENTER", UIParent, "CENTER", 42, 10)
geometryChanged()
assert(manager.parent == UIParent and manager.point[1] == "CENTER" and manager.point[4] == 42)
manager.forbidden = true
native(0)
assert(manager.parent == UIParent)
print("PASS Forever party dock ownership, scaled anchors, clipping, combat deferral and restore")
