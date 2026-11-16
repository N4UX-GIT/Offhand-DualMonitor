local addon = {isForever = true, modules = {}, db = {enabled = true}}
local metrics = {
    isSpanned = true, physicalHeight = 2560, gamePixelHeight = 1440,
    gameLeft = 1000, gameRight = 3000, gameBottom = 100, gameTop = 1100,
    workspaceLeft = 0, workspaceRight = 1000, workspaceBottom = 0, workspaceTop = 1200,
}
addon.Viewport = {GetMetrics = function() return metrics end}
UIParent = {
    GetEffectiveScale = function() return 0.5 end,
    GetHeight = function() return 1000 end,
}

local combat = false
InCombatLockdown = function() return combat end
local observer = {}
CreateFrame = function() return observer end
function observer:RegisterEvent() end
function observer:SetScript(_, script) self.onEvent = script end
hooksecurefunc = function(target, key, after)
    local native = target[key]
    target[key] = function(...)
        native(...)
        after(...)
    end
end

local function frame(parent, scale, width, height, left, top)
    local f = {
        parent = parent, scale = scale, width = width, height = height,
        left = left, top = top, shown = true, protected = false,
        anchor = {"CENTER", UIParent, "CENTER", 0, 0},
    }
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale()
        return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.left + self.width end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.top - self.height end
    function f:GetParent() return self.parent end
    function f:GetName() return self.name end
    function f:GetNumPoints() return self.anchor and 1 or 0 end
    function f:GetPoint() return unpack(self.anchor, 1, 5) end
    function f:IsShown() return self.shown end
    f.IsVisible = f.IsShown
    function f:IsProtected() return self.protected end
    function f:IsForbidden() return false end
    function f:SetScale(value) self.scale = value end
    function f:SetHeight(value) self.height = value end
    function f:ClearAllPoints() self.anchor = nil end
    function f:SetPoint(...) self.anchor = {...} end
    return f
end

assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
addon.PopupBounds:Initialize()

-- ItemRackOptions loads on demand and resets its scale every time it opens.
ItemRackOptFrame = frame(nil, 1, 288, 348, 780, 750)
ItemRackUser = {OptScale = 1}
ItemRackOpt = {ReflectOptScale = function(scale) ItemRackOptFrame:SetScale(scale or ItemRackUser.OptScale) end}
local leftDock = {xoff = 0, yoff = 8, xstart = -44, ystart = -8, xdir = -1, ydir = -1}
local rightDock = {xoff = 0, yoff = 8, xstart = 8, ystart = -8, xdir = 1, ydir = -1}
local slot = frame(ItemRackOptFrame, 1, 36, 36, 920, 500)
slot.name = "ItemRackOptInv4"
ItemRackMenuFrame = frame(slot, 0.85, 92, 52, 710, 602)
ItemRackMenu1 = frame(ItemRackMenuFrame, 1, 36, 36, 710, 602)
ItemRack = {
    DockInfo = {TOPLEFTTOPRIGHT = leftDock, TOPRIGHTTOPLEFT = rightDock},
    currentDock = "TOPLEFTTOPRIGHT", menuDock = "TOPRIGHT", mainDock = "TOPLEFT", Menu = {100},
    MenuOnHide = function() ItemRackMenuFrame.shown = false end,
    ReflectMenuScale = function(scale) ItemRackMenuFrame:SetScale(scale) end,
    BuildMenu = function()
        ItemRackMenu1:SetPoint("TOPLEFT", ItemRackMenuFrame, "TOPRIGHT", -44, -8)
    end,
}
-- Calculate the mirror's geometry for the placement check after anchoring.
function ItemRackMenuFrame:SetPoint(point, relative, relativePoint, x, y)
    self.anchor = {point, relative, relativePoint, x, y}
    self.left = point == "TOPLEFT" and 1100 or 710
end
ItemRackMenuFrame:SetPoint("TOPRIGHT", slot, "TOPLEFT", 0, 8)
observer.onEvent(observer, "ADDON_LOADED", "ItemRackOptions")
ItemRackOpt.ReflectOptScale()
assert(ItemRackOptFrame.scale == 0.5625 and ItemRackUser.OptScale == 1,
    "parentless Options did not preserve its native preset while spanning")
assert(ItemRackOptFrame.anchor[1] == "TOPLEFT", "Options overlapping the seam was not fitted")
ItemRack.BuildMenu()
assert(ItemRackMenuFrame.anchor[1] == "TOPLEFT" and ItemRackMenuFrame.anchor[2] == slot
        and ItemRackMenu1.anchor[3] == "TOPLEFT" and ItemRackMenu1.anchor[4] == 8,
    "seam-facing flyout did not mirror its dock and item together")
ItemRack.BuildMenu()
assert(ItemRackMenuFrame.anchor[1] == "TOPLEFT" and ItemRackMenu1.anchor[4] == 8,
    "rebuilding a mirrored flyout lost its inward layout")

-- A vertical wrap chosen against the whole canvas can be taller than Mainhand.
ItemRackMenuFrame.height = 1300
ItemRackMenuFrame:SetPoint("TOPRIGHT", slot, "TOPLEFT", 0, 8)
ItemRack.BuildMenu()
local fitScale = ItemRackMenuFrame:GetScale()
assert(fitScale < 0.85 and ItemRackMenuFrame.height * ItemRackMenuFrame:GetEffectiveScale()
        / UIParent:GetEffectiveScale() < metrics.gameTop - metrics.gameBottom,
    "an oversized wrapped flyout exceeded the physical display")
ItemRack.BuildMenu()
assert(ItemRackMenuFrame:GetScale() == fitScale, "rebuilding repeatedly shrank the same flyout")
ItemRack.MenuOnHide()
assert(ItemRackMenuFrame:GetScale() == 0.85, "closing a large flyout retained Offhand's scale")
ItemRackMenuFrame.shown = true
ItemRack.BuildMenu()
ItemRack.ReflectMenuScale(0.95)
ItemRack.MenuOnHide()
assert(ItemRackMenuFrame:GetScale() == 0.95, "closing restored a stale vendor scale")

local engine = {}
function engine:ShowFrame()
    QuestieStandaloneSettings = QuestieStandaloneSettings or frame(UIParent, 1, 675, 1365, 720, 1300)
end
QuestieLoader = {_modules = {QuestieOptionsEngine = engine}}
observer.onEvent(observer, "ADDON_LOADED", "Questie")
engine:ShowFrame()
local questie = QuestieStandaloneSettings
assert(questie.height == 700 and questie.anchor[1] == "TOPLEFT",
    "Questie's lazily created Options did not use Mainhand's height")

-- Preserve a dragged anchor and restore both vendor sizes when the span ends.
questie:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 1300, 100)
ItemRackUser.OptScale = 1.6
ItemRackOpt.ReflectOptScale()
assert(math.abs(ItemRackOptFrame.scale - 0.9) < 0.0001 and ItemRackUser.OptScale == 1.6)
combat = true
metrics.isSpanned = false
addon.PopupBounds:ApplyLayout()
assert(questie.height == 700 and math.abs(ItemRackOptFrame.scale - 0.9) < 0.0001,
    "Options layout was changed in combat")
combat = false
UIParent.GetHeight = function() return 1200 end
observer.onEvent(observer, "PLAYER_REGEN_ENABLED")
assert(questie.height == 840 and questie.anchor[1] == "BOTTOMLEFT"
        and ItemRackOptFrame.scale == 1.6 and ItemRackOptFrame.anchor[1] == "CENTER",
    "unspanning failed to release owned sizing and preserve user placement")

print("PASS: ItemRack and Questie Options follow physical display bounds and release their state")
