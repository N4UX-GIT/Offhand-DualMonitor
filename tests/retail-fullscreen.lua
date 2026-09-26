-- Lua 5.1 regression coverage for Retail full-screen frame confinement.
local addon = {
    isRetail = true,
    db = {enabled = true},
    RunOrQueueCombat = function(_, callback) callback() end,
}

local uiScale = 0.394
UIParent = {GetEffectiveScale = function() return uiScale end}
local metrics = {
    isSpanned = true,
    physicalHeight = 2560,
    gamePixelHeight = 1440,
    gameLeft = 1097,
    gameBottom = 4.57,
    gameRight = 3047,
    gameTop = 1101.57,
}
addon.Viewport = {
    GetMetrics = function() return metrics end,
    SetPoint = function(_, frame, point, relativePoint, x, y)
        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        frame:SetPoint(point, UIParent, relativePoint, x * factor, y * factor)
    end,
}

local combat = false
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, callback) callback() end}

local loader
CreateFrame = function()
    loader = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
    return loader
end

local function NewFrame()
    local frame = {scale = 0.64, points = {}, scripts = {}, shown = false}
    function frame:GetScale() return self.scale end
    function frame:SetScale(value) self.scale = value end
    function frame:GetEffectiveScale() return self.scale end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = {...} end
    function frame:SetAllPoints(relativeTo)
        self.points = {
            {"TOPLEFT", relativeTo, "TOPLEFT", 0, 0},
            {"BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0},
        }
    end
    function frame:HookScript(name, callback) self.scripts[name] = callback end
    function frame:IsShown() return self.shown end
    frame:SetAllPoints(UIParent)
    return frame
end

PerksProgramFrame = NewFrame()
assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", addon)
assert(addon.RetailFullscreen.frame == PerksProgramFrame,
    "Trading Post frame was not attached")

PerksProgramFrame.shown = true
PerksProgramFrame.scripts.OnShow()
assert(addon.RetailFullscreen.modified, "Trading Post frame was not constrained")
assert(PerksProgramFrame:GetNumPoints() == 2, "Trading Post frame did not retain two anchors")
local expectedScale = 0.64 * 1440 / 2560
assert(math.abs(PerksProgramFrame:GetScale() - expectedScale) < 0.001,
    "Trading Post scale was not compensated for the taller spanned canvas")

local expectedFactor = uiScale / PerksProgramFrame:GetEffectiveScale()
local points = {}
for index = 1, PerksProgramFrame:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = PerksProgramFrame:GetPoint(index)
    points[point] = {relativeTo, relativePoint, x, y}
end
local bottomLeft, topRight = points.BOTTOMLEFT, points.TOPRIGHT
assert(bottomLeft and bottomLeft[1] == UIParent and bottomLeft[2] == "BOTTOMLEFT")
assert(topRight and topRight[1] == UIParent and topRight[2] == "BOTTOMLEFT")
assert(math.abs(bottomLeft[3] - metrics.gameLeft * expectedFactor) < 0.001)
assert(math.abs(bottomLeft[4] - metrics.gameBottom * expectedFactor) < 0.001)
assert(math.abs(topRight[3] - metrics.gameRight * expectedFactor) < 0.001)
assert(math.abs(topRight[4] - metrics.gameTop * expectedFactor) < 0.001)

-- A later Blizzard full-screen reset is repaired by the settling passes.
PerksProgramFrame:SetAllPoints(UIParent)
PerksProgramFrame:SetScale(0.64) -- Blizzard's DefaultScaleFrame layout pass.
addon.RetailFullscreen:Schedule()
assert(PerksProgramFrame:GetPoint(1) ~= "TOPLEFT",
    "Trading Post full-screen reset was not repaired")
assert(math.abs(PerksProgramFrame:GetScale() - expectedScale) < 0.001,
    "Blizzard Trading Post scale reset was not repaired")

-- Disabling Offhand restores Blizzard's original full-screen anchors.
addon.db.enabled = false
addon.RetailFullscreen:Apply()
assert(not addon.RetailFullscreen.modified, "native Trading Post anchors remained marked modified")
assert(PerksProgramFrame:GetNumPoints() == 2)
local firstPoint, firstRelative, firstRelativePoint = PerksProgramFrame:GetPoint(1)
assert(firstPoint == "TOPLEFT" and firstRelative == UIParent and firstRelativePoint == "TOPLEFT",
    "native Trading Post anchors were not restored")
assert(math.abs(PerksProgramFrame:GetScale() - 0.64) < 0.001,
    "native Trading Post scale was not restored")

-- Equal-height side-by-side displays retain Blizzard's native scale.
addon.db.enabled = true
metrics.physicalHeight = 1440
metrics.gamePixelHeight = 1440
addon.RetailFullscreen:Apply()
assert(math.abs(PerksProgramFrame:GetScale() - 0.64) < 0.001,
    "equal-height layout unnecessarily changed the Trading Post scale")

-- Non-Retail clients load the shared file but never attach or mutate the frame.
local classicAddon = {isRetail = false, db = {enabled = true}}
local classicFrame = NewFrame()
PerksProgramFrame = classicFrame
assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", classicAddon)
assert(classicAddon.RetailFullscreen.frame == nil, "non-Retail client attached the Trading Post handler")
assert(classicFrame:GetPoint(1) == "TOPLEFT", "non-Retail frame placement was mutated")

print("PASS: Retail Trading Post confinement, scale conversion, reset repair, native restore, client isolation")
