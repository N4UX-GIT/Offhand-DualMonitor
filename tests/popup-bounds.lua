local addon = {
    modules = {},
    db = { enabled = true, seamRedirect = true },
}

UIParent = { GetEffectiveScale = function() return 0.5 end }
InCombatLockdown = function() return false end
C_Timer = { After = function(_, fn) fn() end }
addon.Viewport = {
    GetMetrics = function()
        return {
            isSpanned = true, hudScale = 1,
            gameLeft = 1000, gameRight = 3000,
            gameBottom = 100, gameTop = 1100,
        }
    end,
}

local modifiedMenus = {}
Menu = {
    ModifyMenu = function(tag, callback) modifiedMenus[tag] = callback end,
}

local secureHooks = {}
hooksecurefunc = function(name, callback)
    local original = _G[name]
    _G[name] = function(...)
        local result = original and original(...)
        callback(...)
        return result
    end
    secureHooks[name] = callback
end
ToggleDropDownMenu = function() end

local function menuFrame()
    local frame = {
        shown = true, left = 2800, right = 3100, top = 200, bottom = 0,
        points = {},
    }
    function frame:GetEffectiveScale() return 0.5 end
    function frame:GetLeft() return self.left end
    function frame:GetRight() return self.right end
    function frame:GetTop() return self.top end
    function frame:GetBottom() return self.bottom end
    function frame:IsShown() return self.shown end
    function frame:IsForbidden() return false end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...)
        self.points[#self.points + 1] = {...}
    end
    return frame
end

assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
addon.PopupBounds:Initialize()

local modern = menuFrame()
local acquired
local rootDescription = {
    AddMenuAcquiredCallback = function(_, callback) acquired = callback end,
}
assert(modifiedMenus.MENU_UNIT_TARGET, "modern unit-menu tag was not registered")
modifiedMenus.MENU_UNIT_TARGET(nil, rootDescription)
assert(acquired, "modern menu did not register its acquired-frame callback")
acquired(modern)
local point = modern.points[1]
assert(point and point[1] == "TOPLEFT" and point[2] == UIParent
        and point[3] == "BOTTOMLEFT" and math.abs(point[4] - 2696) < 0.01
        and math.abs(point[5] - 304) < 0.01,
    "modern context menu was not moved up and left inside Mainhand")

local legacy = menuFrame()
DropDownList1 = legacy
ToggleDropDownMenu(1, nil, { unit = "target" })
assert(#legacy.points == 1,
    "legacy unit dropdown was not constrained after Blizzard positioned it")

local unrelated = menuFrame()
DropDownList1 = unrelated
ToggleDropDownMenu(1, nil, {})
assert(#unrelated.points == 0, "unrelated legacy dropdown was moved")

local inside = menuFrame()
inside.left, inside.right, inside.top, inside.bottom = 1500, 1700, 600, 400
assert(not addon.PopupBounds:Constrain(inside) and #inside.points == 0,
    "already visible context menu was unnecessarily reanchored")

InCombatLockdown = function() return true end
local combat = menuFrame()
assert(not addon.PopupBounds:Constrain(combat) and #combat.points == 0,
    "context menu was mutated during combat")

print("PASS: modern and legacy unit context menus stay inside the physical Mainhand bounds")
