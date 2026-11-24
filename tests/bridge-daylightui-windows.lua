-- Regression tests for Bridges/DaylightUI/Windows.lua and Bridges/DaylightUI/Bags.lua:
-- 1. Monitor-confined Win.Room / Win.Feel.Slide (never shunts an Offhand window
--    across the seam into Mainhand or vice versa).
-- 2. DaylightUI_Bags reload/restart persistence via OpenClose.Hold() with
--    Escape protection kept active + single-screen recovery pause.
-- 3. DaylightUI replacement windows (Character, Social, Book, Craft, LFG, Legacy)
--    parked native panel reporting, reload/restart persistence, and hidden
--    UIPanel slot eviction so multiple restored windows coexist.
-- 4. DaylightUI_Skins WindowMove drag forwarding and Forget reset sync.

local function LoadChunk(path, ...)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk(...)
end

local timers = {}
local function FlushTimers()
    local guard = 0
    while #timers > 0 and guard < 64 do
        guard = guard + 1
        local batch = timers
        timers = {}
        table.sort(batch, function(a, b) return a.delay < b.delay end)
        for _, item in ipairs(batch) do item.fn() end
    end
end

local inCombat = false
InCombatLockdown = function() return inCombat end
SlashCmdList = {}
C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { delay = delay or 0, fn = fn }
    end,
}
debugstack = function() return "CloseAllWindows" end
hooksecurefunc = function(tbl, key, hook)
    if type(tbl) == "string" then
        local orig = _G[tbl]
        _G[tbl] = function(...) local r = orig(...); key(...); return r end
    else
        local orig = tbl[key]
        tbl[key] = function(...)
            local a, b, c = orig(...)
            hook(...)
            return a, b, c
        end
    end
end
UIParent = {
    width = 3000, height = 1920,
    GetWidth = function(self) return self.width end,
    GetHeight = function(self) return self.height end,
    GetEffectiveScale = function() return 1 end,
}
CreateFrame = function(_, name, parent)
    local f = { name = name, parent = parent, shown = false, points = {}, scripts = {} }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points = { { ... } } end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:RegisterEvent() end
    function f:SetScript(ev, fn) self.scripts[ev] = fn end
    if name then _G[name] = f end
    return f
end

local function MakeWindow(name, left, top, width, height, parent)
    local f = {
        name = name, left = left, top = top, width = width, height = height,
        shown = false, parent = parent or UIParent, scripts = {}, hooked = {},
        offsetX = 0, offsetY = 0, slideCalls = {},
    }
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    function f:IsShown() return self.shown end
    function f:Show()
        self.shown = true
        for _, fn in ipairs(self.hooked.OnShow or {}) do fn(self) end
    end
    function f:Hide()
        self.shown = false
        for _, fn in ipairs(self.hooked.OnHide or {}) do fn(self) end
    end
    function f:HookScript(ev, fn)
        self.hooked[ev] = self.hooked[ev] or {}
        self.hooked[ev][#self.hooked[ev] + 1] = fn
    end
    function f:GetLeft() return self.left + self.offsetX end
    function f:GetTop() return self.top + self.offsetY end
    function f:GetBottom() return self:GetTop() - self.height end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetEffectiveScale() return 1 end
    function f:FireHook(ev, ...)
        for _, fn in ipairs(self.hooked[ev] or {}) do fn(self, ...) end
    end
    if name then _G[name] = f end
    return f
end

-- Build DaylightUI mock (Room, Feel, Followers, Char, Social, Book, Craft, Bags, Skins WindowMove)
local followersHidden = CreateFrame("Frame", nil, UIParent)
local followersAside = CreateFrame("Frame", nil, UIParent)
local followersVeil = CreateFrame("Frame", nil, UIParent)
local charHidden = CreateFrame("Frame", nil, UIParent)

local Feel = {}
function Feel.OffsetX(f) return f.offsetX or 0 end
function Feel.Offset(f) return f.offsetY or 0 end
function Feel.IsOpen(f) return f and f:IsShown() and not f.__feelClosing end
function Feel.Slide(f, dx)
    f.offsetX = dx
    f.slideCalls[#f.slideCalls + 1] = dx
end
function Feel.Close(f)
    if f then f:Hide() end
end

local roomOrder = {}
local Room = { GAP = 8, EDGE = 4 }
local function roomHome(f)
    local l = f:GetLeft() - Feel.OffsetX(f)
    local t = f:GetTop() - Feel.Offset(f)
    return { l = l, r = l + f:GetWidth(), t = t, b = t - f:GetHeight(), k = 1 }
end
local function roomCovers(a, b) return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t end
local function roomFirst(rect, placed) for _, p in ipairs(placed) do if roomCovers(rect, p) then return p end end end
local function roomAt(r, x) return { l = x, r = x + (r.r - r.l), t = r.t, b = r.b, k = r.k } end
local function roomClear(r, placed, screen)
    if not roomFirst(r, placed) then return r.l end
    local function walk(dir)
        local s = r
        for _ = 1, #placed + 1 do
            local p = roomFirst(s, placed)
            if not p then return s end
            s = roomAt(s, dir > 0 and p.r + Room.GAP or p.l - Room.GAP - (s.r - s.l))
        end
        return s
    end
    local right, left = walk(1), walk(-1)
    local function fits(s) return s.l >= Room.EDGE and s.r <= screen - Room.EDGE and not roomFirst(s, placed) end
    local dr, dl = math.abs(right.l - r.l), math.abs(left.l - r.l)
    if fits(right) and (not fits(left) or dr <= dl) then return right.l end
    if fits(left) then return left.l end
    return right.l
end
function Room.Lay()
    local placed = {}
    local screen = UIParent:GetWidth()
    for _, f in ipairs(roomOrder) do
        local r = roomHome(f)
        local x = #placed > 0 and roomClear(r, placed, screen) or r.l
        Feel.Slide(f, (x - r.l) / r.k)
        placed[#placed + 1] = roomAt(r, x)
    end
end

-- Replacement windows + parked Blizzard frames
local charGame = MakeWindow("CharacterFrame", 16, 1000, 384, 512, charHidden)
local socialGame = MakeWindow("SocialUIFrame", 16, 1000, 384, 512, followersHidden)
local bookGame = MakeWindow("PlayerSpellsFrame", 16, 1000, 600, 600, followersAside)
local craftGame = MakeWindow("ProfessionsFrame", 16, 1000, 720, 560, followersAside)
local trainerGame = MakeWindow("ClassTrainerFrame", 16, 1000, 384, 512, followersVeil)

local duiChar = MakeWindow("DaylightUICharacter", 120, 1200, 460, 560)
local duiSocial = MakeWindow("DaylightUISocial", 80, 900, 520, 600)
local duiBook = MakeWindow("DaylightUIBook", 160, 1200, 600, 600)
local duiCraft = MakeWindow("DaylightUICraft", 200, 1100, 720, 560)

-- Simulated Blizzard UIPanel slot manager (only 2 slots: left + center)
local slots = { left = nil, center = nil }
GetUIPanel = function(slot) return slots[slot] end
ShowUIPanel = function(frame)
    if slots.left and slots.left ~= frame then
        if slots.center and slots.center ~= frame then
            slots.center:Hide()
        end
        slots.center = slots.left
    end
    slots.left = frame
    frame:Show()
end
HideUIPanel = function(frame, skipSetPoint)
    if slots.left == frame then slots.left = nil end
    if slots.center == frame then slots.center = nil end
    frame:Hide()
end

ToggleCharacter = function()
    if charGame:IsShown() then HideUIPanel(charGame) else ShowUIPanel(charGame); duiChar:Show() end
end
ToggleFriendsFrame = function()
    if socialGame:IsShown() then HideUIPanel(socialGame) else ShowUIPanel(socialGame); duiSocial:Show() end
end
PlayerSpellsUtil = {
    ToggleSpellBookFrame = function()
        ShowUIPanel(bookGame); duiBook.current = "spells"; duiBook:Show()
    end,
    ToggleClassTalentOrSpecFrame = function()
        ShowUIPanel(bookGame); duiBook.current = "talents"; duiBook:Show()
    end,
}
ToggleProfessionsBook = function()
    ShowUIPanel(craftGame); duiCraft:Show()
end

-- DaylightUI_Bags mock
local bagHidden = CreateFrame("Frame", nil, UIParent)
local bagProxy = CreateFrame("Frame", "DaylightUIEscape1", UIParent)
local duiBag = MakeWindow("DaylightUIBag", 600, 700, 380, 500)
duiBag.__duiEsc = bagProxy
local bagOpenClose = { hidden = bagHidden, held = nil, closeAllCalls = 0, holdCalls = 0 }
function bagOpenClose.AnyOpen() return false end
function bagOpenClose.GameWindows() return {} end
function bagOpenClose.CloseGame() end
function bagOpenClose.Follow()
    if bagOpenClose.held then duiBag:Show() else duiBag:Hide() end
end
function bagOpenClose.Hold()
    bagOpenClose.holdCalls = bagOpenClose.holdCalls + 1
    bagOpenClose.held = true
    bagOpenClose.Follow()
    return true
end
function bagOpenClose.CloseAll()
    bagOpenClose.closeAllCalls = bagOpenClose.closeAllCalls + 1
    bagOpenClose.held = nil
    bagOpenClose.Follow()
end

-- DaylightUI_Skins WindowMove mock
local collections = MakeWindow("CollectionsJournal", 120, 1000, 700, 600)
local macroFrame = MakeWindow("MacroFrame", 220, 900, 350, 420)
local gameMenu = MakeWindow("GameMenuFrame", 120, 900, 200, 300)
local wmBars = {
    CollectionsJournal = MakeWindow(nil, 120, 1000, 600, 26, collections),
    MacroFrame = MakeWindow(nil, 220, 900, 300, 26, macroFrame),
    GameMenuFrame = MakeWindow(nil, 120, 900, 150, 26, gameMenu),
}
local wmSpots = { CollectionsJournal = { 120, 1000 }, MacroFrame = { 220, 900 }, GameMenuFrame = { 120, 900 } }
local WindowMove = {
    bars = wmBars,
    Spot = function(name) return wmSpots[name] end,
    Forget = function(name) wmSpots[name] = nil end,
}

local loadedAddons = { DaylightUI = true, DaylightUI_Bags = true, DaylightUI_Skins = true }
C_AddOns = {
    IsAddOnLoaded = function(name) return loadedAddons[name] == true end,
    LoadAddOn = function(name) loadedAddons[name] = true; return true end,
}

_G.DaylightUI = {
    IsSecret = function() return false end,
    Win = {
        Feel = Feel,
        Room = Room,
        Followers = { hidden = followersHidden, aside = followersAside, veil = followersVeil },
    },
    Char = {
        Follow = {
            hidden = charHidden,
            Covers = function() return true end,
            Close = function() HideUIPanel(charGame); duiChar:Hide() end,
        },
    },
    Social = {
        Window = {
            Covers = function() return true end,
            Close = function() HideUIPanel(socialGame); duiSocial:Hide() end,
        },
    },
    Book = {
        Window = {
            Covers = function() return true end,
            Show = function(page) duiBook.current = page end,
            Close = function() HideUIPanel(bookGame); duiBook:Hide() end,
        },
    },
    Craft = {
        Window = {
            Covers = function() return true end,
            Close = function() HideUIPanel(craftGame); duiCraft:Hide() end,
        },
    },
    Lfg = { Window = { Covers = function() return false end, Close = function() end } },
    Legacy = { Window = { Covers = function() return false end, Close = function() end } },
    GetModule = function(_, name)
        if name == "Bags" then
            return { enabled = true, ns = { window = duiBag, OpenClose = bagOpenClose } }
        elseif name == "Skins" then
            return { enabled = true, ns = { WindowMove = WindowMove } }
        end
    end,
}

-- Offhand core + Bridges harness
local spanned = true
local wsLeft, wsRight, wsBottom, wsTop = 0, 1080, 0, 1920
local gameLeft, gameRight, gameBottom, gameTop = 1080, 3000, 0, 1080
local externalMoved, externalForgotten = {}, {}

_G.OffhandDB = {}
local Offhand = {
    db = { enabled = true, persistentWorkspacePanels = true, restoreWorkspaceOnReload = true },
    MainhandGeometry = {
        GetCurrentRect = function()
            if not spanned then
                return { left = 0, bottom = 0, right = 1920, top = 1080, width = 1920, height = 1080, screenWidth = 1920, screenHeight = 1080, isSpanned = false }
            end
            return { left = gameLeft, bottom = gameBottom, right = gameRight, top = gameTop, width = gameRight - gameLeft, height = gameTop - gameBottom, screenWidth = UIParent:GetWidth(), screenHeight = UIParent:GetHeight(), isSpanned = true }
        end,
    },
    Viewport = {
        GetMetrics = function()
            if not spanned then return { isSpanned = false } end
            return {
                isSpanned = true,
                workspaceLeft = wsLeft, workspaceRight = wsRight,
                workspaceBottom = wsBottom, workspaceTop = wsTop,
                gameLeft = gameLeft, gameRight = gameRight,
                gameBottom = gameBottom, gameTop = gameTop,
            }
        end,
    },
    Canvas = {
        RecordExternalPanelDrag = function(_, frame)
            externalMoved[#externalMoved + 1] = frame:GetName()
            return true
        end,
        ForgetExternalWorkspacePanel = function(_, name)
            externalForgotten[#externalForgotten + 1] = name
            return true
        end,
    },
    API = {
        RegisterGeometryCallback = function() end,
    },
}

LoadChunk("Core/Bridges.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Core.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Bags.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Windows.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Init.lua", "Offhand", Offhand)

local bridge = assert(Offhand.Bridges:Get("DaylightUI"), "DaylightUI bridge must register")

-- =====================================================================
-- TEST 1 (Bug A): Monitor-confined Win.Room / Win.Feel.Slide
-- =====================================================================

-- 1a. Portrait Offhand (0..1080) + Mainhand (1080..3000): opening Book (width 600)
--     over Character (width 460) cannot fit side-by-side in 1080px, so Character
--     must stay at its Offhand home (dx = 0) instead of shunting into Mainhand!
duiChar.left, duiChar.top, duiChar.offsetX = 120, 1200, 0
duiBook.left, duiBook.top, duiBook.offsetX = 160, 1200, 0
roomOrder = { duiBook, duiChar }
Room.Lay()
assert(duiBook.offsetX == 0, "Newest window keeps its spot")
assert(duiChar.offsetX == 0, "Offhand window must NOT shunt across seam into Mainhand (got dx=" .. tostring(duiChar.offsetX) .. ")")
assert(duiChar:GetLeft() + duiChar:GetWidth() <= wsRight, "Offhand window must stay completely inside Offhand")

-- 1b. Wide Offhand (0..1920): Character at 1380..1840, Book at 1200..1800.
--     Native Room.Lay wants to push Character right (1808..2268, into Mainhand!),
--     but left (732..1192) fits cleanly inside Offhand -> must slide LEFT on Offhand!
wsRight, gameLeft, gameRight, UIParent.width = 1920, 1920, 3840, 3840
duiChar.left, duiChar.top, duiChar.offsetX = 1380, 1000, 0
duiBook.left, duiBook.top, duiBook.offsetX = 1200, 1000, 0
roomOrder = { duiBook, duiChar }
Room.Lay()
assert(duiChar:GetLeft() >= wsLeft + 4 and duiChar:GetLeft() + duiChar:GetWidth() <= wsRight - 4,
    "Wide Offhand must slide left inside Offhand instead of shunting into Mainhand (got left=" .. tostring(duiChar:GetLeft()) .. ")")
assert(duiChar:GetLeft() + duiChar:GetWidth() <= duiBook:GetLeft(), "Should sit cleanly left of Book")

-- 1c. Mainhand window near left seam (1920..3840): Character at 1960..2420, Book at 2000..2600.
--     Native Room.Lay would try left (1532..1992, into Offhand), must slide RIGHT inside Mainhand!
duiChar.left, duiChar.top, duiChar.offsetX = 1960, 1000, 0
duiBook.left, duiBook.top, duiBook.offsetX = 2000, 1000, 0
roomOrder = { duiBook, duiChar }
Room.Lay()
assert(duiChar:GetLeft() >= gameLeft + 4 and duiChar:GetLeft() + duiChar:GetWidth() <= gameRight - 4,
    "Mainhand window must slide right inside Mainhand instead of crossing into Offhand (got left=" .. tostring(duiChar:GetLeft()) .. ")")

-- Restore portrait Offhand geometry for remaining tests
wsLeft, wsRight, gameLeft, gameRight, UIParent.width = 0, 1080, 1080, 3000, 3000

-- =====================================================================
-- TEST 2 (Bug B1): DaylightUI_Bags reload/restart + single-screen recovery + Escape
-- =====================================================================

local escapeRegistered = {}
local bagServices = {
    UpdateEscapeRegistration = function(_, name, supported, _, proxy)
        escapeRegistered[proxy] = supported and true or false
    end,
    IsEscapeRegistered = function(proxy) return escapeRegistered[proxy] == true end,
    CanSuppressVendorClose = function() return true end,
    IsGameMenuBagClose = function() return true end,
}

duiBag.left, duiBag.top = 600, 700
duiBag:Show()
Offhand.Bridges:RefreshBags(bagServices)
assert(_G.OffhandDB.bridges.DaylightUI.openBags == true, "Visible Offhand DaylightUIBag must be recorded open")

-- Single-screen recovery hides bag without clearing openBags
Offhand.Bridges:PrepareSingleScreenRecovery({ isSpanned = false })
assert(duiBag:IsShown() == false, "Single-screen recovery must close Offhand DaylightUIBag")
assert(_G.OffhandDB.bridges.DaylightUI.openBags == true, "Single-screen recovery must preserve openBags intent")

-- Reload / span restore reopens via Hold() and keeps Escape protection active
Offhand.Bridges:RestoreWorkspaceState("reload")
FlushTimers()
assert(bagOpenClose.holdCalls == 1, "DaylightUIBag must reopen via taint-free OpenClose.Hold()")
assert(duiBag:IsShown() == true, "DaylightUIBag must be visible after reload restore")
Offhand.Bridges:RefreshBags(bagServices)
assert(escapeRegistered[bagProxy] == true, "Restored held DaylightUIBag must remain Escape-protected")

-- Explicit user close clears openBags so it will NOT reopen on next reload
duiBag:Hide()
assert(_G.OffhandDB.bridges.DaylightUI.openBags == nil, "Explicit close must clear openBags")

-- =====================================================================
-- TEST 3 (Bug B2): Parked panel detection & multiple DaylightUI windows restore
-- =====================================================================

assert(Offhand.Bridges:IsParkedNativePanel(charGame) == true, "CharacterFrame under Char.Follow.hidden must report parked")
assert(Offhand.Bridges:IsParkedNativePanel(socialGame) == true, "SocialUIFrame under Followers.hidden must report parked")
assert(Offhand.Bridges:IsParkedNativePanel(bookGame) == true, "PlayerSpellsFrame under Followers.aside must report parked")
assert(Offhand.Bridges:IsParkedNativePanel(trainerGame) == true, "ClassTrainerFrame under Followers.veil must report parked")
assert(Offhand.Bridges:IsParkedNativePanel(collections) == false, "Unparked Blizzard frame must not report parked")

duiChar.left, duiChar.top = 120, 1200; duiChar:Show()
duiSocial.left, duiSocial.top = 80, 900; duiSocial:Show()
duiBook.left, duiBook.top, duiBook.current = 160, 1200, "talents"; duiBook:Show()
duiCraft.left, duiCraft.top = 200, 1100; duiCraft:Show()
Offhand.Bridges:CaptureWorkspaceState()

local savedWins = _G.OffhandDB.bridges.DaylightUI.openWindows
assert(savedWins and savedWins.character and savedWins.social and savedWins.book == "talents" and savedWins.craft,
    "All 4 open Offhand DaylightUI windows (including Book talents tab) must be captured")

-- Simulate fresh reload: every frame starts closed and slots empty
duiChar:Hide(); charGame:Hide()
duiSocial:Hide(); socialGame:Hide()
duiBook:Hide(); bookGame:Hide(); duiBook.current = nil
duiCraft:Hide(); craftGame:Hide()
slots.left, slots.center = nil, nil

Offhand.Bridges:RestoreWorkspaceState("reload")
FlushTimers()
assert(duiChar:IsShown() and charGame:IsShown(), "DaylightUICharacter must reopen after reload")
assert(duiSocial:IsShown() and socialGame:IsShown(), "DaylightUISocial must reopen after reload without evicting Character")
assert(duiBook:IsShown() and bookGame:IsShown() and duiBook.current == "talents", "DaylightUIBook must reopen on saved talents tab")
assert(duiCraft:IsShown() and craftGame:IsShown(), "DaylightUICraft must reopen alongside all other windows")

-- Explicit close clears that window from openWindows (after sessionReady)
Feel.Close(duiSocial)
assert(savedWins.social == nil, "Explicit close must clear saved window state")

-- =====================================================================
-- TEST 3b (Live reload startup race): Refresh("layout") / Refresh("tick") /
-- RefreshBags() firing BEFORE RestoreWorkspaceState() on a fresh /reload must
-- NEVER wipe persisted openBags or openWindows!
-- =====================================================================
-- Simulate fresh addon load after /reload (all frames start hidden, hooks fresh)
duiBag:Hide(); bagOpenClose.held = nil; bagOpenClose.holdCalls = 0
duiChar:Hide(); charGame:Hide()
duiSocial:Hide(); socialGame:Hide()
duiBook:Hide(); bookGame:Hide(); duiBook.current = nil
duiCraft:Hide(); craftGame:Hide()
slots.left, slots.center = nil, nil
duiBag.hooked = {}
for _, b in pairs(wmBars) do b.hooked = {} end
WindowMove.Forget = function(name) wmSpots[name] = nil end
Feel._offhandLifecycleWrapped = nil

_G.OffhandDB.bridges.DaylightUI.openBags = true
_G.OffhandDB.bridges.DaylightUI.openWindows = {
    character = "character",
    social = "friends",
    book = "talents",
    craft = true,
}

LoadChunk("Bridges/DaylightUI/Bags.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Windows.lua", "Offhand", Offhand)
LoadChunk("Bridges/DaylightUI/Init.lua", "Offhand", Offhand)

-- Fire every pre-restore startup pass that runs during PLAYER_LOGIN + ApplyFullLayout + 0.5s ticker
Offhand.Bridges:Refresh("layout")
Offhand.Bridges:Refresh("tick")
Offhand.Bridges:RefreshBags(bagServices)
Offhand.Bridges:Refresh("layout")

assert(_G.OffhandDB.bridges.DaylightUI.openBags == true,
    "Startup Refresh/Tick before RestoreWorkspaceState must NEVER wipe openBags")
local preRestoreWins = _G.OffhandDB.bridges.DaylightUI.openWindows
assert(preRestoreWins.character == "character" and preRestoreWins.social == "friends"
    and preRestoreWins.book == "talents" and preRestoreWins.craft == true,
    "Startup Refresh/Tick before RestoreWorkspaceState must NEVER wipe openWindows")

-- Now run RestoreWorkspaceState as Init.lua:1659 does
Offhand.Bridges:RestoreWorkspaceState("reload")
FlushTimers()
assert(bagOpenClose.holdCalls == 1 and duiBag:IsShown(), "DaylightUIBag must reopen after pre-restore startup passes")
assert(duiChar:IsShown() and duiSocial:IsShown() and duiBook:IsShown() and duiCraft:IsShown(),
    "All 4 DaylightUI replacement windows must reopen after pre-restore startup passes")

-- Once restore settles (sessionReady == true), explicit closes must clear state again
duiBag:Hide()
Feel.Close(duiChar)
assert(_G.OffhandDB.bridges.DaylightUI.openBags == nil, "Explicit bag close after restore must clear openBags")
assert(_G.OffhandDB.bridges.DaylightUI.openWindows.character == nil, "Explicit window close after restore must clear openWindows")

-- =====================================================================
-- TEST 4 (Bug B3): DaylightUI_Skins WindowMove drag sync & Forget
-- =====================================================================

collections:Show()
macroFrame:Show()
gameMenu:Show()
Offhand.Bridges:Refresh("tick")

-- Both shown Offhand WindowMove panels must sync; GameMenuFrame must be excluded
local movedSet = {}
for _, name in ipairs(externalMoved) do movedSet[name] = true end
assert(movedSet.CollectionsJournal, "Open Offhand CollectionsJournal under WindowMove must sync to Offhand")
assert(movedSet.MacroFrame, "Open Offhand MacroFrame under WindowMove must sync to Offhand")
assert(not movedSet.GameMenuFrame, "GameMenuFrame must stay excluded from workspace persistence")

-- Dragging CollectionsJournal via WindowMove bar triggers NotifyExternalPanelMoved
local beforeDrag = #externalMoved
wmBars.CollectionsJournal:FireHook("OnDragStop")
assert(#externalMoved == beforeDrag + 1 and externalMoved[#externalMoved] == "CollectionsJournal",
    "WindowMove bar OnDragStop must forward drag completion to Offhand")

-- Right-click reset (WindowMove.Forget) clears Offhand workspace ownership
WindowMove.Forget("CollectionsJournal")
assert(#externalForgotten == 1 and externalForgotten[1] == "CollectionsJournal",
    "WindowMove.Forget must notify Offhand to clear workspace ownership")

print("bridge-daylightui-windows tests passed")
