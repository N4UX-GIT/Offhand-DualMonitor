local addon = { modules = {}, db = { enabled = true }, isRetail = true }
local uiScale = 0.39375
UIParent = {
    GetEffectiveScale = function() return uiScale end,
    GetObjectType = function() return "Frame" end,
}

local spanned, inInstance = true, false
local metrics = { isSpanned = true }
addon.Viewport = {
    GetMetrics = function() return metrics end,
    GetWorldTextScaleControl = function() return nil, nil end,
}
IsInInstance = function() return inInstance, inInstance and "party" or "none" end

local font = { file = "Fonts\\FRIZQT__.TTF", height = 13, flags = "OUTLINE", writes = 0 }
ChatBubbleFont = {
    GetFont = function() return font.file, font.height, font.flags end,
    SetFont = function(_, file, height, flags)
        font.file, font.height, font.flags = file, height, flags
        font.writes = font.writes + 1
        return true
    end,
}

local function NewFontString()
    local fs = { text = "", width = 220, height = 13, shown = true }
    function fs:GetObjectType() return "FontString" end
    function fs:SetFont(file, height, flags)
        self.file, self.fontHeight, self.flags = file, height, flags
        self.height = height
        return true
    end
    function fs:GetFont() return self.file or font.file, self.fontHeight or 13, self.flags or "" end
    function fs:SetText(value) self.text = value end
    function fs:GetText() return self.text end
    function fs:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
    function fs:GetTextColor() return 1, 1, 1, 1 end
    function fs:SetWidth(value) self.width = value end
    function fs:GetUnboundedStringWidth() return #self.text * 7 end
    function fs:GetStringWidth() return math.min(self.width, #self.text * 7) end
    function fs:GetStringHeight()
        local lines = math.max(1, math.ceil((#self.text * 7) / math.max(1, self.width)))
        return lines * (self.fontHeight or 13)
    end
    function fs:SetJustifyH() end
    function fs:SetJustifyV() end
    function fs:SetWordWrap() end
    function fs:SetNonSpaceWrap() end
    function fs:SetPoint() end
    return fs
end

local createdFrames, eventFrames, replacementFrames = {}, {}, {}
local function NewTexture()
    local t = { shown = false }
    function t:SetAtlas(name, useSize) self.atlas, self.useAtlasSize = name, useSize end
    function t:SetTexture(path) self.texture = path end
    function t:SetSize(w, h) self.width, self.height = w, h end
    function t:ClearAllPoints() self.points = {} end
    function t:SetPoint(...) self.points = { ... } end
    function t:Show() self.shown = true end
    return t
end

function CreateFrame(_, _, parent, template)
    local f = { parent = parent, template = template, shown = false, points = {}, scripts = {} }
    createdFrames[#createdFrames + 1] = f
    function f:RegisterEvent(event) self.registered = self.registered or {}; self.registered[event] = true end
    function f:SetScript(name, callback) self.scripts[name] = callback end
    function f:SetBackdrop(info) self.backdrop = info end
    function f:SetBackdropColor(...) self.backdropColor = { ... } end
    function f:SetBackdropBorderColor(...) self.borderColor = { ... } end
    function f:SetFrameStrata(value) self.strata = value end
    function f:SetFrameLevel(value) self.level = value end
    function f:EnableMouse(value) self.mouse = value end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    function f:SetAlpha(value) self.alpha = value end
    function f:SetScale(value) self.scale = value end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetScale() return self.scale or 1 end
    function f:GetEffectiveScale() return (self.scale or 1) * uiScale end
    function f:GetObjectType() return "Frame" end
    function f:CreateFontString() self.createdFont = NewFontString(); return self.createdFont end
    function f:CreateTexture() self.createdTexture = NewTexture(); return self.createdTexture end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points = { ... } end
    function f:GetNumPoints() return #self.points > 0 and 1 or 0 end
    function f:GetPoint() return unpack(self.points) end
    if parent == UIParent and template == "BackdropTemplate" then
        replacementFrames[#replacementFrames + 1] = f
    else
        eventFrames[#eventFrames + 1] = f
    end
    return f
end

local function Bubble(scale, inherited)
    return {
        scale = scale,
        writes = 0,
        inherited = inherited or function() return 1 end,
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

local function ForeverBubble(text, alpha)
    local fs = NewFontString()
    fs:SetText(text)
    fs:SetFont(font.file, 13, font.flags)
    local child = {
        alpha = alpha or 1,
        alphaWrites = 0,
        points = { "CENTER", nil, "CENTER", 0, 0 },
    }
    child.String = fs
    function child:GetRegions() return fs end
    function child:GetAlpha() return self.alpha end
    function child:SetAlpha(value) self.alpha, self.alphaWrites = value, self.alphaWrites + 1 end
    function child:GetObjectType() return "Frame" end
    function child:GetWidth() return 64 end
    function child:GetHeight() return 44 end
    function child:GetScale() return 1 end
    function child:GetEffectiveScale() return 1 end
    function child:GetNumPoints() return 1 end
    function child:GetPoint() return unpack(self.points) end

    local outer = Bubble(1)
    outer.child = child
    outer.hooks = {}
    outer.points = { "CENTER", UIParent, "CENTER", 50, 80 }
    function outer:GetChildren() return self.child end
    function outer:GetParent() return UIParent end
    function outer:GetObjectType() return "Frame" end
    function outer:GetWidth() return 64 end
    function outer:GetHeight() return 44 end
    function outer:GetNumPoints() return 1 end
    function outer:GetPoint() return unpack(self.points) end
    function outer:HookScript(name, callback) self.hooks[name] = callback end
    return outer, child, fs
end

local bubbles, ticks, tick = {}, 0
C_ChatBubbles = {
    GetAllChatBubbles = function() return bubbles end,
}
C_Timer = {
    NewTicker = function(interval, callback)
        assert(interval >= 0.1)
        ticks, tick = ticks + 1, callback
        return {}
    end,
    After = function(_, callback) callback() end,
}

local function Near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001,
        string.format("expected %.5f, got %.5f", expected, actual))
end

assert(loadfile("Core/ChatBubbles.lua"))("Offhand", addon)
local module = addon.modules.ChatBubbles
module:Initialize(); module:Initialize()
assert(ticks == 1, "Initialization must not duplicate the watcher")
assert(#eventFrames == 1, "The lifecycle event frame must be created once")
for _, event in ipairs({
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_MONSTER_SAY",
    "CHAT_MSG_MONSTER_YELL", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT",
}) do
    assert(eventFrames[1].registered[event], event .. " must trigger immediate bubble acquisition")
end

-- Existing non-Forever behavior remains unchanged.
local native = Bubble(1)
local inherited = Bubble(1, function() return uiScale end)
local custom = Bubble(0.8)
bubbles = { native, inherited, custom }
tick()
Near(native.scale, uiScale); Near(inherited.scale, 1); Near(custom.scale, uiScale * 0.8)
for _ = 1, 20 do tick() end
assert(native.writes == 1 and custom.writes == 1 and inherited.writes == 0,
    "Stable scales must not be rewritten or compounded")
uiScale = 0.5
module:ApplyLayout()
Near(native.scale, 0.5); Near(inherited.scale, 1); Near(custom.scale, 0.4)

-- Retail's forbidden instance path still uses and restores the shared font.
inInstance = true
tick()
Near(native.scale, 1); Near(inherited.scale, 1); Near(custom.scale, 0.8)
Near(font.height, 6.5)
local fontWrites = font.writes
tick()
assert(font.writes == fontWrites, "Stable instance font must not be rewritten")
inInstance = false
tick()
Near(font.height, 13)

-- Forever equal-height spans stay entirely native, protecting unaffected users.
addon.isRetail, addon.isForever = false, true
addon.Viewport.GetWorldTextScaleControl = function() return "WorldTextScale_v2", 0.5 end
metrics = { isSpanned = true, physicalHeight = 1080, gamePixelHeight = 1080,
    gamePixelLeft = 0, gamePixelBottom = 0 }
addon.db.speechBubbleCompensation = true
addon.db.speechBubbleScale = 1
local outer, child, nativeFS = ForeverBubble("Test")
bubbles = { outer }
tick()
Near(outer.scale, 1); Near(child.alpha, 1)
assert(#replacementFrames == 0, "Equal-height users must retain native bubbles")
local diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementMode == "equal-height-native"
    and diagnostics.visualManaged == 0)

-- A mixed-height span receives one UIParent-owned classic replacement. Only
-- native alpha changes; Blizzard's root scale, points and dimensions do not.
metrics = { isSpanned = true, physicalHeight = 2560, gamePixelHeight = 1440,
    gamePixelLeft = 1440, gamePixelBottom = 6 }
addon.db.speechBubbleScale = 1.1
eventFrames[1].scripts.OnEvent(nil, "CHAT_MSG_SAY")
assert(#replacementFrames == 1, "Mixed-height span must create one replacement")
local replacement = replacementFrames[1]
assert(replacement.shown and replacement.alpha == 1 and replacement.scale == 1.1)
assert(replacement.points[1] == "CENTER" and replacement.points[2] == outer
    and replacement.points[3] == "CENTER", "Replacement must borrow Blizzard's center anchor")
assert(replacement.text.text == "Test" and replacement.text.fontHeight == 13)
assert(replacement.backdrop.bgFile == "Interface\\Tooltips\\ChatBubble-Background"
    and replacement.backdrop.edgeFile == "Interface\\Tooltips\\ChatBubble-Backdrop")
assert(replacement.tail.atlas == "ChatBubble-NineSlice-Tail")
Near(child.alpha, 0); Near(outer.scale, 1)
assert(outer.writes == 0, "Forever's native root must never be scaled")
local alphaWrites = child.alphaWrites
tick()
assert(#replacementFrames == 1 and child.alphaWrites == alphaWrites,
    "Stable replacements must be pooled and must not rewrite native alpha")

nativeFS:SetText("A longer test line")
tick()
assert(replacement.text.text == "A longer test line" and replacement.width > 48,
    "Reused native frames must refresh replacement text and dimensions")
diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementEligible and diagnostics.visualManaged == 1
    and diagnostics.visualNativeAnchors and diagnostics.replacementConflict == "none")

-- User disable is fail-open and restores Blizzard's child exactly once.
addon.db.speechBubbleCompensation = false
tick()
Near(child.alpha, 1)
assert(not replacement.shown)
diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementMode == "user-disabled" and diagnostics.visualManaged == 0)

-- The pool is reused when compensation returns.
addon.db.speechBubbleCompensation = true
tick()
assert(#replacementFrames == 1 and replacement.shown)
Near(child.alpha, 0)

-- EllesmereUI explicitly owns bubbles when its customization is enabled.
EllesmereUI = { GetActiveProfileData = function()
    return { chatBubbles = { enabled = true } }
end }
tick()
Near(child.alpha, 1)
assert(not replacement.shown)
diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementMode == "yielding"
    and diagnostics.replacementConflict == "EllesmereUI")
EllesmereUI = nil

-- Restoring the window or entering an instance always hands native ownership back.
tick(); Near(child.alpha, 0)
metrics.isSpanned = false
tick(); Near(child.alpha, 1)
assert(not replacement.shown)
metrics.isSpanned = true
inInstance = true
tick(); Near(child.alpha, 1)
diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementMode == "instance-native")
inInstance = false

-- An already-hidden child is assumed to belong to another addon and is never claimed.
local ownedOuter, ownedChild = ForeverBubble("Owned elsewhere", 0)
bubbles = { ownedOuter }
tick()
Near(ownedChild.alpha, 0)
assert(not replacement.shown, "Unknown alpha ownership must remain untouched")

-- Recover legacy persisted font mutations without changing the new replacement font.
font.height = 3.25
module:ApplyLayout()
Near(font.height, 13)
assert(addon.db.originalChatBubbleFontHeight == 13)

addon.db.enabled = false
bubbles = { outer }
tick()
Near(child.alpha, 1); Near(outer.scale, 1)
diagnostics = module:GetDiagnostics()
assert(diagnostics.replacementMode == "offhand-disabled")

C_ChatBubbles = nil
addon.db.enabled = true
tick()
diagnostics = module:GetDiagnostics()
assert(not diagnostics.supported and diagnostics.visible == 0)

print("PASS: native client scaling, Retail font fallback, immediate topology-scoped Forever replacement, classic assets, pooling, ownership yielding, diagnostics and restoration")

-- Accessible native bubbles clamp against Mainhand rather than the full stacked
-- window. No world-space anchor, child, font or text mutation is needed.
addon.isForever, addon.isRetail = false, true
inInstance, uiScale = false, 0.5
addon.db.speechBubbleCompensation = true
EllesmereUI = nil
UIParent.GetWidth = function() return 1000 end
UIParent.GetHeight = function() return 800 end
metrics = {isSpanned=true, gameLeft=0,gameRight=1000,gameBottom=0,gameTop=400}
local bounded = Bubble(1)
local bubbleInsets, clampWrites, bubbleClamped = {0,0,0,0}, 0, false
bounded.GetClampRectInsets = function() return unpack(bubbleInsets) end
bounded.SetClampRectInsets = function(_, ...) bubbleInsets={...}; clampWrites=clampWrites+1 end
bounded.IsClampedToScreen = function() return bubbleClamped end
bounded.SetClampedToScreen = function(_, value) bubbleClamped=value end
bounded.SetPoint = function() error("native bubble anchor must remain engine-owned") end
C_ChatBubbles = {GetAllChatBubbles=function() return {bounded} end}
module:ApplyLayout()
assert(bubbleClamped and bubbleInsets[3] == 400,
    "stacked bubbles must reserve the upper workspace with physical-scale-aware clamp bounds")
local unchanged = clampWrites
module:ApplyLayout()
assert(clampWrites == unchanged, "unchanged bubble bounds must not churn")
bounded.protected = true
metrics.gameTop = 350
module:ApplyLayout()
assert(clampWrites == unchanged, "protected bubbles must receive no clamp writes")
bounded.protected = false
addon.db.speechBubbleCompensation = false
module:ApplyLayout()
assert(not bubbleClamped and bubbleInsets[3] == 0,
    "turning off compensation must restore the original native clamp")
addon.db.speechBubbleCompensation = true
module:ApplyLayout()
metrics.isSpanned = false
module:ApplyLayout()
assert(not bubbleClamped and bubbleInsets[3] == 0, "restored windows must restore native bubble bounds")
print("PASS: stacked native bubble clamping, protection, idempotence and restoration")
