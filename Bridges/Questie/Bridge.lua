-- Questie bridge (built into Offhand).
-- With UIParent spanning every monitor, its middle is the seam between them. Questie puts several things
-- there: the first-run "choose objective type" window (Modules\Tutorial\ChooseObjectiveType.lua), the
-- profiler indicator (Modules\Profiler\QuestieProfilerUI.lua), its confirmation dialogs, which
-- LibPopupStack-1.0 stacks at the top centre of UIParent, and QuestieTrace's consent prompt
-- (QuestieTrace\Widgets\Dialog.lua), which places itself the same way. Each is moved to the same spot of the
-- game rectangle, but only while it is still exactly where its owner put it: a dragged window is left alone,
-- and so is a dialog placed beside a Blizzard popup. The owners' position caches are never written.
-- Questie's map icons (Modules\FramePool\QuestieFrame.lua) are sent back to UIParent by HereBeDragons
-- whenever a world-map pin is released; hidden icons pile up under UIParent until UIParent:GetChildren()
-- overflows, so each icon is kept under a holder frame instead.
-- The tracker caps its automatic width at GetScreenWidth() * trackerWidthRatio (Modules\Tracker\
-- QuestieTracker.lua, TrackerLayout.lua), and GetScreenWidth() is the whole spanned width; during those two
-- calls the ratio is scaled to the game rectangle's share of the screen and restored right after.
-- The quest item buttons (Modules\Tracker\LinePool\TrackerItemButton.lua) pick their tooltip side from
-- half of GetScreenWidth(); on the game monitor the side is corrected to its own middle.
-- Left alone on purpose: the tracker's position ("Reset Tracker" centres it on the whole screen), the
-- minimap button tooltip, the sticky Durability/VoiceOver frames and AceGUI's released widgets.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("Questie") then return end

local fitter = Shared.NewAnchorFitter({
    QuestieTutorialChooseObjectiveType = { "CENTER", "CENTER", 0, 50 },
    QuestieProfilerIndicator = { "TOP", "TOP", 0, -4 },
})
local bridge = {}

local function horizontallySpanned(l, r, sw)
    return l > 0 or r < sw
end

-- ---------------------------------------------------------------------
-- Dialogs (LibPopupStack-1.0). The library anchors each one with
-- SetPoint("TOP", UIParent, "BOTTOMLEFT", fx, fy) and remembers fx, fy in
-- lib.anchors; fx is the seam unless a Blizzard popup is showing.
-- ---------------------------------------------------------------------

local dialogsHooked = false

local function fitDialogs()
    local lib = LibStub and LibStub("LibPopupStack-1.0", true)
    if type(lib) ~= "table" or type(lib.frames) ~= "table" or type(lib.anchors) ~= "table" then return end
    local l, _, r, t, sw, sh = Shared.GameRect()
    if not horizontallySpanned(l, r, sw) then return end
    local base = UIParent:GetEffectiveScale()
    if type(base) ~= "number" or base <= 0 then return end
    for _, frame in ipairs(lib.frames) do
        local a = lib.anchors[frame]
        if type(a) == "table" and frame:GetNumPoints() == 1 then
            local point, rel, relPoint, x, y = frame:GetPoint(1)
            local scale = frame:GetEffectiveScale()
            -- only when the frame is still exactly where the library put it, and that is the seam
            if point == "TOP" and rel == UIParent and relPoint == "BOTTOMLEFT"
                and Shared.Near(x, a.x) and Shared.Near(y, a.y) and type(scale) == "number" and scale > 0 then
                local ratio = scale / base
                local nx = ((l + r) / 2) / ratio
                if math.abs(a.x * ratio - sw / 2) < 1 and not Shared.Near(nx, a.x) then
                    frame:ClearAllPoints()
                    frame:SetPoint("TOP", UIParent, "BOTTOMLEFT", nx, a.y + (t - sh) / ratio)
                end
            end
        end
    end
end

local function hookDialogs()
    if dialogsHooked then return end
    local lib = LibStub and LibStub("LibPopupStack-1.0", true)
    if type(lib) ~= "table" or type(lib.Layout) ~= "function" then return end
    dialogsHooked = true
    hooksecurefunc(lib, "Layout", function() pcall(fitDialogs) end)
end

-- ---------------------------------------------------------------------
-- QuestieTrace's consent prompt. It anchors itself with
-- SetPoint("TOP", UIParent, "BOTTOMLEFT", x, y) in its own units and remembers
-- x, y in popupAnchorX/Y; x is the seam unless a Blizzard popup is showing.
-- ---------------------------------------------------------------------

local consentHooked = false

local function fitConsent()
    local f = _G.QuestieTraceConsentFrame
    if type(f) ~= "table" or type(f.GetPoint) ~= "function" then return end
    if type(f.popupAnchorX) ~= "number" or type(f.popupAnchorY) ~= "number" then return end
    if f:GetNumPoints() ~= 1 then return end
    local point, rel, relPoint, x, y = f:GetPoint(1)
    if point ~= "TOP" or rel ~= UIParent or relPoint ~= "BOTTOMLEFT" then return end
    if not (Shared.Near(x, f.popupAnchorX) and Shared.Near(y, f.popupAnchorY)) then return end
    local l, _, r, t, sw, sh = Shared.GameRect()
    if not horizontallySpanned(l, r, sw) then return end
    local scale, base = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 or type(base) ~= "number" then return end
    local pr = base / scale
    local nx = ((l + r) / 2) * pr
    if math.abs(x - sw * pr / 2) >= 1 or Shared.Near(nx, x) then return end
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "BOTTOMLEFT", nx, f.popupAnchorY + (t - sh) * pr)
end

local function hookConsent()
    if consentHooked then return end
    local f = _G.QuestieTraceConsentFrame
    if type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    consentHooked = true
    f:HookScript("OnShow", function() pcall(fitConsent) end)
    f:HookScript("OnUpdate", function() pcall(fitConsent) end)
    pcall(fitConsent)
end

-- ---------------------------------------------------------------------
-- Map icons (QuestieFrame1, QuestieFrame2, ...), kept under a holder
-- instead of UIParent.
-- ---------------------------------------------------------------------

local holder = Shared.NewParentHolder("OffhandQuestieIcons")
local nextIcon = 1                   -- Questie only ever adds QuestieFrame<n> with the next n

local function adoptNew()
    while true do
        local f = _G["QuestieFrame" .. nextIcon]
        if type(f) ~= "table" then break end
        pcall(holder.Adopt, holder, f)
        nextIcon = nextIcon + 1
    end
end

-- ---------------------------------------------------------------------
-- Tracker width cap: GetScreenWidth() * trackerWidthRatio, scaled to the
-- game rectangle's share of the screen for the duration of each call.
-- ---------------------------------------------------------------------

local wrapped = 0
local wrappedKeys = {}               -- module -> { [key] = true }
local scaling = false

local function pack(...)
    return select("#", ...), { ... }
end

local function widthFactor()
    local l, _, r, _, sw = Shared.GameRect()
    if sw <= 0 then return 1 end
    local f = (r - l) / sw
    if f > 0 and f < 1 then return f end
    return 1
end

local function widthProfile()
    local questie = _G.Questie
    local db = type(questie) == "table" and questie.db
    local profile = type(db) == "table" and db.profile
    if type(profile) == "table" and type(profile.trackerWidthRatio) == "number" then return profile end
end

local function wrapWidth(module, key)
    local keys = wrappedKeys[module]
    if keys and keys[key] then return end
    local original = module[key]
    if type(original) ~= "function" then return end
    module[key] = function(...)
        if scaling then return original(...) end
        local factor = widthFactor()
        if factor >= 1 then return original(...) end
        local ok, profile = pcall(widthProfile)
        if not ok or not profile then return original(...) end
        local ratio = profile.trackerWidthRatio
        profile.trackerWidthRatio = ratio * factor
        scaling = true
        local n, values = pack(pcall(original, ...))
        profile.trackerWidthRatio = ratio
        scaling = false
        if not values[1] then error(values[2], 0) end
        return unpack(values, 2, n)
    end
    wrappedKeys[module] = keys or {}
    wrappedKeys[module][key] = true
    wrapped = wrapped + 1
end

local function wrapTracker()
    local loader = _G.QuestieLoader
    if type(loader) ~= "table" or type(loader.ImportModule) ~= "function" then return end
    local ok, tracker = pcall(loader.ImportModule, loader, "QuestieTracker")
    if ok and type(tracker) == "table" then wrapWidth(tracker, "UpdateWidth") end
    local layoutOk, layout = pcall(loader.ImportModule, loader, "TrackerLayout")
    if layoutOk and type(layout) == "table" then wrapWidth(layout, "UpdateLineWidth") end
end

-- ---------------------------------------------------------------------
-- Quest item button tooltips (Questie_ItemButton<n>). Questie anchors the
-- tooltip right of a button left of half of GetScreenWidth(), else left of
-- it; on the game monitor the game rectangle's own middle decides instead.
-- ---------------------------------------------------------------------

local nextButton = 1
local tooltipFixes = 0

local function fixTooltip(btn)
    if type(GameTooltip) ~= "table" or GameTooltip:GetOwner() ~= btn then return end
    if not Shared.IsSpanned() then return end
    local cx = btn:GetCenter()
    if type(cx) ~= "number" then return end
    local scale, base = btn:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or type(base) ~= "number" or base <= 0 then return end
    local ux = cx * scale / base
    local left, _, right = Shared.GameRect()
    if ux < left or ux > right then return end   -- the tracker lives on another monitor: Questie's choice stands
    local wantRight = ux < (left + right) / 2
    local screenWidth = type(GetScreenWidth) == "function" and GetScreenWidth() or nil
    local hadRight = cx < (screenWidth or UIParent:GetWidth()) / 2
    if wantRight == hadRight or type(GameTooltip.SetAnchorType) ~= "function" then return end
    GameTooltip:SetAnchorType(wantRight and "ANCHOR_RIGHT" or "ANCHOR_LEFT", wantRight and 8 or -8, -25)
    tooltipFixes = tooltipFixes + 1
end

local function onEnter(self)
    pcall(fixTooltip, self)
end

-- Questie re-installs self.OnEnter as the script on every SetItem, so the
-- hooked field is what later runs; HookScript covers the script already set.
local function watchButtons()
    while true do
        local btn = _G["Questie_ItemButton" .. nextButton]
        if type(btn) ~= "table" or InCombatLockdown() then return end
        if type(btn.OnEnter) == "function" then pcall(hooksecurefunc, btn, "OnEnter", onEnter) end
        if type(btn.HookScript) == "function" then pcall(btn.HookScript, btn, "OnEnter", onEnter) end
        nextButton = nextButton + 1
    end
end

-- ---------------------------------------------------------------------

function bridge:Refresh(reason)
    fitter:Refresh()
    if not dialogsHooked then pcall(hookDialogs) end
    if not consentHooked then pcall(hookConsent) end
    pcall(adoptNew)
    if wrapped < 2 then pcall(wrapTracker) end
    pcall(watchButtons)
end

function bridge:GetDiagnostics()
    return Shared.Describe("QuestieAnchors", fitter)
        .. " QuestieIcons=" .. tostring(holder.taken)
        .. " QuestieWidth=" .. tostring(wrapped) .. "/2"
        .. " QuestieTooltips=" .. tostring(tooltipFixes)
end

if Shared.Register("Questie", bridge, fitter,
    { "OffhandQuestieIcons", "QuestieTraceConsentFrame", "^QuestieFrame%d+$" }) then bridge:Refresh("load") end
