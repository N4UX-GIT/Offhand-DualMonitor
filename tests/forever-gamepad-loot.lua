-- Native loot bounds, ownership exclusions, and bounded opening observation.
-- This models geometry/lifecycle decisions, not native focus or taint safety.
local rect = { left = 1440, right = 4000, bottom = 0, top = 1440,
    width = 2560, height = 1440, isSpanned = true }
local gamepad, combat = true, false
UIParent = { GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end, GetHeight = function() return 2560 end }
LootFrameMixin = { Open = function() end, FocusGamepad = function() end }
local function loot()
    local f = { left = 1400, top = 900, width = 220, height = 290,
        scale = 1, isOpen = true, shown = true, writes = 0,
        Open = LootFrameMixin.Open, FocusGamepad = LootFrameMixin.FocusGamepad }
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:IsUserPlaced() return self.userPlaced end
    function f:IsShown() return self.shown end
    function f:GetParent() return UIParent end
    function f:GetEffectiveScale() return self.scale end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:ClearAllPoints() self.writes = self.writes + 1 end
    function f:SetPoint(point, relative, relativePoint, x, y)
        assert(point == "TOPLEFT" and relative == UIParent and relativePoint == "BOTTOMLEFT")
        self.writes = self.writes + 1
        self.left, self.top = x, y
    end
    setmetatable(f, { __index = function(_, name)
        if name == "SetScript" or name == "HookScript" or name == "SetScale"
            or name == "SetMovable" or name == "Show" or name == "Hide" then
            return function() error("must not mutate native loot lifecycle") end
        end
    end })
    return f
end
local addon = { isForever = true, db = { enabled = true },
    Mainhand = { GetRect = function() return rect end },
    MainhandGeometry = { Number = tonumber, IsPlayerCombatRestricted = function() return combat end },
    MainhandCompatibility = { IsNativeGamepadInterface = function() return gamepad end } }
assert(loadfile("Core/MainhandGamepad.lua"))("Offhand", addon)
local function correct(expected, reason)
    local moved, status = addon.Mainhand:ConstrainForeverGamepadLoot()
    assert(moved == expected and (not reason or reason == status),
        "unexpected loot correction: " .. tostring(status))
end
LootFrame = loot()
correct(true, "clamped")
assert(LootFrame.left == 1448 and LootFrame.top == 900, "left seam must use the smallest correction")
correct(false, "contained")
assert(LootFrame.writes == 2, "contained loot must not receive repeated anchor writes")

-- All four edges, mirrored/stacked Mainhand, and differing frame/UIParent scales.
for _, geometry in ipairs({
    { 1440, 0, 4000, 1440 }, { 0, 1120, 1440, 2560 }, { 0, 0, 1920, 1080 },
}) do
    rect.left, rect.bottom, rect.right, rect.top = unpack(geometry)
    rect.width, rect.height = rect.right - rect.left, rect.top - rect.bottom
    for _, scale in ipairs({ 0.5, 1, 1.5 }) do
        for _, edge in ipairs({ "left", "right", "top", "bottom" }) do
            LootFrame = loot()
            LootFrame.scale = scale
            LootFrame.left, LootFrame.top = (rect.left + 100) / scale, (rect.top - 100) / scale
            if edge == "left" then LootFrame.left = (rect.left - 30) / scale end
            if edge == "right" then LootFrame.left = (rect.right - 10) / scale end
            if edge == "top" then LootFrame.top = (rect.top + 30) / scale end
            if edge == "bottom" then LootFrame.top = (rect.bottom + 10) / scale end
            correct(true, "clamped")
            local left, top = LootFrame.left * scale, LootFrame.top * scale
            assert(left >= rect.left and left + LootFrame.width * scale <= rect.right
                and top <= rect.top and top - LootFrame.height * scale >= rect.bottom,
                "loot overflow at " .. edge)
        end
    end
end
UIParent.GetEffectiveScale = function() return 0.5 end
LootFrame = loot()
LootFrame.left, LootFrame.top = -20, 200
correct(true, "clamped")
assert(LootFrame.left * 2 == rect.left + 8, "inherited UIParent scale was ignored")
UIParent.GetEffectiveScale = function() return 1 end

for field, reason in pairs({ forbidden = "forbidden", protected = "protected",
    userPlaced = "external-owner", isInEditMode = "edit-mode" }) do
    LootFrame = loot()
    LootFrame[field] = true
    correct(false, reason)
    assert(LootFrame.writes == 0, "excluded loot root was written")
end
LootFrame = loot()
LootFrame.editModeManuallyShown = true
LootFrame.left = -20
correct(true, "clamped")
LootFrame = loot()
LootFrame.Open = function() end
correct(false, "external-owner")
LootFrame = loot()
LootFrame.FocusGamepad = function() end
correct(false, "external-owner")
LootFrame = loot()
LootFrame.isOpen = false
correct(false, "hidden")
LootFrame.shown = false
correct(false, "hidden")
LootFrame = loot()
EditModeManagerFrame = { IsShown = function() return true end }
correct(false, "edit-mode")
EditModeManagerFrame = nil
combat = true
correct(false, "combat")
combat, gamepad = false, false
correct(false, "inactive")
gamepad, addon.isForever = true, false
correct(false, "inactive")
addon.isForever, addon.db.enabled = true, false
correct(false, "inactive")
addon.db.enabled, rect.isSpanned = true, false
correct(false, "span")
rect.isSpanned = true
ConsolePort = {}
correct(false, "inactive")
ConsolePort = nil
LootFrame = loot()
LootFrame.width = rect.width + 1
correct(false, "oversized")
LootFrame = loot()
LootFrame.scale = 0
correct(false, "geometry")
LootFrame = loot()
LootFrame.top = 0 / 0
correct(false, "geometry")
LootFrame = loot()
issecretvalue = function(value) return value == LootFrame.left end
correct(false, "geometry")
issecretvalue = nil

-- An addon-owned controller watches only opening, never installs native hooks.
rect.left, rect.bottom, rect.right, rect.top = 1440, 0, 4000, 1440
rect.width, rect.height = 2560, 1440
local controller = { scripts = {}, events = {} }
function controller:SetScript(event, fn) self.scripts[event] = fn end
function controller:RegisterEvent(event) self.events[event] = true end
CreateFrame = function() return controller end
GamepadMainMenuFrame = { GetWidth = function() return 600 end,
    GetHeight = function() return 600 end, ClearAllPoints = function() end, SetPoint = function() end }
addon.Mainhand.CenterForeverGamepadMainMenu = function() end
addon.Mainhand.CenterForeverGamepadDestinationPanels = function() end
addon.Mainhand.CenterForeverGamepadReticle = function() end
assert(addon.Mainhand:EnableForeverGamepadMainMenuAdapter())
assert(controller.events.LOOT_OPENED and controller.events.LOOT_CLOSED)
controller.scripts.OnUpdate(controller, 1.1) -- initial interface settlement
LootFrame = loot()
controller.scripts.OnUpdate(controller, 0.1)
assert(LootFrame.writes == 0, "idle observer must not inspect/move loot without an open event")
controller.scripts.OnEvent(controller, "LOOT_OPENED")
controller.scripts.OnUpdate(controller, 0.1)
assert(LootFrame.writes == 2)
controller.scripts.OnUpdate(controller, 0.6)
LootFrame.left = -20
controller.scripts.OnUpdate(controller, 1)
assert(LootFrame.writes == 2, "observer must stop after the opening interval")
controller.scripts.OnEvent(controller, "LOOT_OPENED")
controller.scripts.OnEvent(controller, "LOOT_CLOSED")
controller.scripts.OnUpdate(controller, 0.1)
assert(LootFrame.writes == 2, "closed loot must cancel pending correction")
controller.scripts.OnEvent(controller, "LOOT_OPENED")
controller.scripts.OnUpdate(controller, 0.6)
assert(LootFrame.writes == 2, "a stalled frame must not apply an expired correction")
controller.scripts.OnEvent(controller, "LOOT_OPENED")
gamepad = false
controller.scripts.OnUpdate(controller, 0.1)
gamepad = true
controller.scripts.OnUpdate(controller, 0.1)
controller.scripts.OnUpdate(controller, 1.1)
assert(LootFrame.writes == 2, "interface changes must cancel pending correction")
assert(LootFrame.SetPoint and addon.Mainhand:GetForeverGamepadLootDiagnostics())
print("PASS: Forever loot bounds, ownership, scaling and bounded observation")
