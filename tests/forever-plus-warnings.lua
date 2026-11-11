local addon = {isForever = true, db = {enabled = true, seamRedirect = true}}
local combat, hookCount, gamepad = false, 0, true
InCombatLockdown = function() return combat end
addon.Mainhand = {IsNativeGamepadInterface = function() return gamepad end}
UIParent = {GetEffectiveScale = function() return 0.7 end,
    GetHeight = function() return 2560 end}
local metrics = {isSpanned = true, gameLeft = 1440, gameRight = 4000,
    gameBottom = 6, gameTop = 1446}
addon.Viewport = {GetMetrics = function() return metrics end}
hooksecurefunc = function(owner, key, callback)
    hookCount = hookCount + 1
    local original = owner[key]
    owner[key] = function(...)
        local result = original(...)
        callback(...)
        return result
    end
end
local function frame()
    local f = {points = {}, writes = 0, scale = 0.7, parent = UIParent}
    function f:GetParent() return self.parent end
    function f:IsMouseEnabled() return self.mouse == true end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:IsUserPlaced() return self.userPlaced end
    function f:GetEffectiveScale() return self.scale end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints()
        self.writes = self.writes + 1
        self.points = {}
    end
    function f:SetPoint(...) self.points[#self.points + 1] = {...} end
    function f:HookScript() error("vendor scripts remain untouched") end
    function f:Show() error("vendor visibility remains untouched") end
    function f:Hide() error("vendor visibility remains untouched") end
    return f
end
assert(loadfile("Core/ForeverPlusWarnings.lua"))("Offhand", addon)
assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
local adapter = addon.ForeverPlusWarnings
adapter:Hook()
assert(hookCount == 0, "late vendor loading remains supported")
ForeverPlus = {TimerRoom = function() return 18 end,
PlaceAsBar = function(self, target, id, bar, store)
    target:ClearAllPoints()
    if bar.positioned then
        target:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -80)
    else
        -- Vendor 1.0.6 replays this canvas-relative default on every redraw.
        local y = 2560 * 0.22
        if id == "consumables" then
            y = math.max(2560 * 0.30, y + store.list.general.size / 2
                + bar.size / 2 + self.TimerRoom() + 8)
        end
        target:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    end
    return "native-result"
end}
adapter:Hook(); adapter:Hook()
assert(hookCount == 1)
local warning, bar = frame(), {}
assert(ForeverPlus:PlaceAsBar(warning, "general", bar) == "native-result")
local point = warning.points[1]
assert(point[3] == "BOTTOMLEFT" and point[4] == 2720
    and math.abs(point[5] - 1042.8) < 0.001,
    "default warnings must use Mainhand center and proportional height in native Gamepad mode")
assert(next(bar) == nil, "the vendor profile must not receive translated points")
assert(addon.HUDCompatibility.IsExternallyOwnedHUDFrame(warning),
    "generic rescue and panel movement must yield observed vendor bars")
local writes = warning.writes
adapter:ApplyLayout()
assert(warning.writes == writes, "stable geometry must not write again")
ForeverPlus:PlaceAsBar(warning, "general", bar)
assert(warning.points[1][4] == 2720, "each native redraw must settle before rendering")

bar.positioned = true
ForeverPlus:PlaceAsBar(warning, "general", bar)
assert(warning.points[1][1] == "TOPLEFT" and warning.points[1][4] == 40)
adapter:ApplyLayout()
assert(warning.points[1][4] == 40, "explicit vendor positions win")
bar.positioned = nil
ForeverPlus.movingBars = true
local preview = frame()
ForeverPlus:PlaceAsBar(preview, "general", bar)
assert(not adapter:IsOwnedFrame(preview) and preview.points[1][3] == "CENTER",
    "interactive mover previews must remain entirely vendor-owned")
ForeverPlus.movingBars = false

ForeverPlus:PlaceAsBar(warning, "general", bar)
addon.db.seamRedirect = false
adapter:ApplyLayout()
assert(warning.points[1][3] == "CENTER" and warning.points[1][5] == 2560 * 0.22,
    "feature-off restores still-owned native anchors")
addon.db.seamRedirect = true
adapter:ApplyLayout()
warning:ClearAllPoints(); warning:SetPoint("LEFT", UIParent, "LEFT", 90, 30)
addon.db.enabled = false
adapter:ApplyLayout()
assert(warning.points[1][1] == "LEFT" and warning.points[1][4] == 90,
    "disable must preserve an intervening external anchor")
addon.db.enabled = true

combat = true
ForeverPlus:PlaceAsBar(warning, "general", bar)
writes = warning.writes
adapter:ApplyLayout()
assert(warning.writes == writes and warning.points[1][3] == "CENTER",
    "the addon performs no combat anchor writes")
combat = false
adapter:ApplyLayout()
assert(warning.points[1][4] == 2720)
metrics.isSpanned = false
adapter:ApplyLayout()
assert(warning.points[1][3] == "CENTER", "window Restore releases native placement")
metrics.isSpanned = true

warning.scale = 0.35
ForeverPlus:PlaceAsBar(warning, "general", bar)
assert(warning.points[1][4] == 5440 and math.abs(warning.points[1][5] - 1768.8) < 0.001,
    "UIParent and frame coordinates must convert at the scale boundary")
for _, kind in ipairs({"protected", "forbidden", "mouse", "userPlaced"}) do
    local excluded = frame(); excluded[kind] = true
    ForeverPlus:PlaceAsBar(excluded, "general", bar)
    assert(excluded.points[1][3] == "CENTER", kind .. " frame must not be changed")
end
local unrelated = frame()
assert(not adapter:IsOwnedFrame(unrelated), "anonymous unrelated roots cannot be inferred as vendor bars")

-- Vendor 1.0.6 keeps fixed icon/countdown clearance between these defaults.
-- Scaling the whole native offset collapses that clearance on a shorter game.
metrics.gameTop = metrics.gameBottom + 720
local store = {list={general={size=128},consumables={size=128}}}
local general, consumables = frame(), frame()
ForeverPlus:PlaceAsBar(general, "general", store.list.general, store)
ForeverPlus:PlaceAsBar(consumables, "consumables", store.list.consumables, store)
assert(consumables.points[1][5] - general.points[1][5] >= 154 - 0.001,
    "Mainhand translation must preserve fixed native icon, timer and row clearance")
local savedY = consumables.points[1][5]
adapter:ApplyLayout()
assert(consumables.points[1][5] == savedY, "stack clearance must remain stable between redraws")
store.list.general.size, store.list.consumables.size = 64, 96
ForeverPlus:PlaceAsBar(general, "general", store.list.general, store)
ForeverPlus:PlaceAsBar(consumables, "consumables", store.list.consumables, store)
assert(consumables.points[1][5] - general.points[1][5] >= 106 - 0.001,
    "vendor redraw must use the current independent icon sizes")
addon.db.seamRedirect = false
adapter:ApplyLayout()
assert(consumables.points[1][3] == "CENTER" and consumables.points[1][5] == 768,
    "Restore must retain the actual original native default offset")
assert(store.list.general.positioned == nil and store.list.consumables.positioned == nil,
    "clearance correction must not store vendor positions")
print("PASS: ForeverPlus defaults follow Mainhand without profile, mover, combat or input ownership changes")
