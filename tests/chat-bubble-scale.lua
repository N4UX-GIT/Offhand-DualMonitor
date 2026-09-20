local addon = { modules = {}, db = { enabled = true } }
local uiScale = 0.39375 -- 1440 / 2560 * 70%
UIParent = { GetEffectiveScale = function() return uiScale end }
local bubbles, ticks, tick = {}, 0
C_ChatBubbles = { GetAllChatBubbles = function(includeForbidden)
    assert(not includeForbidden, "Must not request forbidden bubble access")
    return bubbles
end }
C_Timer = { NewTicker = function(interval, callback)
    assert(interval >= 0.1)
    ticks, tick = ticks + 1, callback
    return {}
end }
local function Bubble(scale, inherited)
    return {
        scale = scale, writes = 0, inherited = inherited or function() return 1 end,
        IsForbidden = function(self) return self.forbidden end,
        IsProtected = function(self) return self.protected end,
        IsShown = function(self) return not self.hidden end,
        GetScale = function(self) return self.scale end,
        GetEffectiveScale = function(self) return self.scale * self.inherited() end,
        SetScale = function(self, value)
            assert(not self.forbidden and not self.protected)
            self.scale, self.writes = value, self.writes + 1
        end,
    }
end
local function Near(actual, expected) assert(math.abs(actual - expected) < 0.00001) end
assert(loadfile("Core/ChatBubbles.lua"))("Offhand", addon)
local module = addon.modules.ChatBubbles
module:Initialize(); module:Initialize()
assert(ticks == 1, "Initialization must not duplicate the watcher")
local native, inherited, custom = Bubble(1), Bubble(1, function() return uiScale end), Bubble(0.8)
bubbles = {native, inherited, custom}
tick()
Near(native.scale, uiScale); Near(inherited.scale, 1); Near(custom.scale, uiScale * 0.8)
for i = 1, 20 do tick() end
assert(native.writes == 1 and custom.writes == 1 and inherited.writes == 0, "Stable scales must not be rewritten or compounded")
uiScale = 0.5
module:ApplyLayout()
Near(native.scale, 0.5); Near(inherited.scale, 1); Near(custom.scale, 0.4)
native.scale = 1 -- engine reuses the frame with its native scale
tick(); Near(native.scale, 0.5)
local newBubble = Bubble(1)
table.insert(bubbles, newBubble)
tick(); Near(newBubble.scale, 0.5)
local forbidden, protected, invalid = Bubble(1), Bubble(1), Bubble(0)
forbidden.forbidden, protected.protected = true, true
forbidden.GetScale = function() error("Forbidden frame was inspected") end
bubbles = {forbidden, protected, invalid, newBubble}
tick()
assert(forbidden.writes == 0 and protected.writes == 0 and invalid.writes == 0)
custom.scale = 0.9 -- external ownership change must survive disabling
addon.db.enabled = false
tick()
Near(native.scale, 1); Near(newBubble.scale, 1); Near(custom.scale, 0.9)
local restoredWrites = native.writes
tick(); assert(native.writes == restoredWrites)
C_ChatBubbles = nil
addon.db.enabled = true
tick() -- unsupported clients must remain usable
print("PASS: speech bubble baseline, inherited/custom scales, no feedback, pooled/new frames, protected guards and disable restoration")

