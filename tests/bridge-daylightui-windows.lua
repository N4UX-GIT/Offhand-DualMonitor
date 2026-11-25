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
function Feel.Open(f)
    if f then f.__feelClosing = nil; f:Show() end
end
function Feel.Close(f)
    if f then f:Hide() end
end

local roomOrder = {}
local Room = { GAP = 8, EDGE = 4 }
function Room.Changed() end
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
local baseFeelOpen, baseFeelClose, baseFeelSlide = Feel.Open, Feel.Close, Feel.Slide
local baseRoomLay, baseRoomChanged = Room.Lay, Room.Changed

-- Replacement windows + parked Blizzard frames
local charGame = MakeWindow("CharacterFrame", 16, 1000, 384, 512, charHidden)
local socialGame = MakeWindow("SocialUIFrame", 16, 1000, 384, 512, followersHidden)
local lfgGame = MakeWindow("LFGParentFrame", 16, 1000, 384, 512, followersHidden)
local legacyGame = MakeWindow("LegacySystemFrame", 16, 1000, 780, 580, followersAside)
local bookGame = MakeWindow("PlayerSpellsFrame", 16, 1000, 600, 600, followersAside)
local craftGame = MakeWindow("ProfessionsFrame", 16, 1000, 720, 560, followersAside)
craftGame.CraftingPage = MakeWindow(nil, 0, 0, 720, 560, craftGame)
craftGame.BookPage = MakeWindow(nil, 0, 0, 720, 560, craftGame)
local craftNativeCloseCalls = 0
local function craftNativeClose()
    craftNativeCloseCalls = craftNativeCloseCalls + 1
    HideUIPanel(craftGame)
end
craftGame.CheckConfirmClose = craftNativeClose
local trainerGame = MakeWindow("ClassTrainerFrame", 16, 1000, 384, 512, followersVeil)

local duiChar = MakeWindow("DaylightUICharacter", 120, 1200, 460, 560)
local duiSocial = MakeWindow("DaylightUISocial", 80, 900, 520, 600)
local duiLfg = MakeWindow("DaylightUILfg", 100, 1000, 460, 560)
local duiLegacy = MakeWindow("DaylightUILegacy", 140, 1100, 780, 580)
local duiBook = MakeWindow("DaylightUIBook", 160, 1200, 600, 600)
local duiCraft = MakeWindow("DaylightUICraft", 200, 1100, 720, 560)

-- Simulated Blizzard UIPanel slot manager (only 2 slots: left + center) + UISpecialFrames
UISpecialFrames = {}
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
ToggleGameMenu = function()
    if GameMenuFrame:IsShown() then GameMenuFrame:Hide() else GameMenuFrame:Show() end
end

ToggleCharacter = function()
    if charGame:IsShown() then HideUIPanel(charGame) else ShowUIPanel(charGame); Feel.Open(duiChar) end
end
ToggleFriendsFrame = function()
    if socialGame:IsShown() then HideUIPanel(socialGame) else ShowUIPanel(socialGame); Feel.Open(duiSocial) end
end
ToggleLFGParentFrame = function()
    if lfgGame:IsShown() then HideUIPanel(lfgGame) else ShowUIPanel(lfgGame); Feel.Open(duiLfg) end
end
ToggleLegacySystemUI = function()
    if legacyGame:IsShown() then HideUIPanel(legacyGame) else ShowUIPanel(legacyGame); Feel.Open(duiLegacy) end
end
PlayerSpellsUtil = {
    ToggleSpellBookFrame = function()
        ShowUIPanel(bookGame); duiBook.current = "spells"; Feel.Open(duiBook)
    end,
    ToggleClassTalentOrSpecFrame = function()
        ShowUIPanel(bookGame); duiBook.current = "talents"; Feel.Open(duiBook)
    end,
}
ToggleProfessionsBook = function()
    craftGame.BookPage:Show()
    craftGame.CraftingPage:Hide()
    ShowUIPanel(craftGame); Feel.Open(duiCraft)
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
local auctionFrame = MakeWindow("AuctionHouseFrame", 150, 900, 600, 500)
local gameMenu = MakeWindow("GameMenuFrame", 120, 900, 200, 300)
local wmBars = {
    CollectionsJournal = MakeWindow(nil, 120, 1000, 600, 26, collections),
    MacroFrame = MakeWindow(nil, 220, 900, 300, 26, macroFrame),
    AuctionHouseFrame = MakeWindow(nil, 150, 900, 500, 26, auctionFrame),
    GameMenuFrame = MakeWindow(nil, 120, 900, 150, 26, gameMenu),
}
local wmSpots = {
    CollectionsJournal = { 120, 1000 },
    MacroFrame = { 220, 900 },
    AuctionHouseFrame = { 150, 900 },
    GameMenuFrame = { 120, 900 },
}
local WindowMove = {
    bars = wmBars,
    Spot = function(name) return wmSpots[name] end,
    Apply = function(name)
        local f, s = _G[name], wmSpots[name]
        if f and s and f:IsShown() then f.left, f.top = s[1], s[2] end
    end,
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
    Lfg = {
        Window = {
            Covers = function() return true end,
            Close = function() HideUIPanel(lfgGame); Feel.Close(duiLfg) end,
        },
    },
    Legacy = {
        Window = {
            Covers = function() return true end,
            ShowTab = function(page) duiLegacy.current = page end,
            Close = function() HideUIPanel(legacyGame); Feel.Close(duiLegacy) end,
        },
    },
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
local Offhand
Offhand = {
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
            local name = frame:GetName()
            if name == "AuctionHouseFrame" then return false end
            externalMoved[#externalMoved + 1] = name
            if Offhand.db.persistentWorkspacePanels ~= false and Offhand.API.IsFrameOnWorkspace(frame) then
                if slots.left == frame or slots.center == frame then
                    HideUIPanel(frame, 1)
                    frame:Show()
                end
                for i = #UISpecialFrames, 1, -1 do
                    if UISpecialFrames[i] == name then table.remove(UISpecialFrames, i) end
                end
            end
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
duiLfg:Hide(); lfgGame:Hide()
duiLegacy:Hide(); legacyGame:Hide()
duiBook:Hide(); bookGame:Hide(); duiBook.current = nil
duiCraft:Hide(); craftGame:Hide()
slots.left, slots.center = nil, nil
duiBag.hooked = {}
for _, b in pairs(wmBars) do b.hooked = {} end
WindowMove.Forget = function(name) wmSpots[name] = nil end
WindowMove.Apply = function(name)
    local f, s = _G[name], wmSpots[name]
    if f and s and f:IsShown() then f.left, f.top = s[1], s[2] end
end
craftGame.CheckConfirmClose = craftNativeClose
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
ToggleGameMenu = function()
    if GameMenuFrame:IsShown() then GameMenuFrame:Hide() else GameMenuFrame:Show() end
end
Feel.Open, Feel.Close, Feel.Slide = baseFeelOpen, baseFeelClose, baseFeelSlide
Room.Lay, Room.Changed = baseRoomLay, baseRoomChanged
Feel._offhandLifecycleWrapped = nil
Feel._offhandSlideWrapped = nil
Room._offhandLayWrapped = nil
Room._offhandRoomChangedWrapped = nil

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

-- =====================================================================
-- TEST 5: Escape protection for DaylightUI replacement windows & WindowMove
-- =====================================================================

-- Simulate Blizzard's Escape key press on Forever:
-- 1. If GameMenuFrame is shown -> close it.
-- 2. If ProfessionsFrame is shown -> Blizzard_ProfessionsRegistration calls CheckConfirmClose().
-- 3. Otherwise CloseWindows() hides left/center UIPanel slots + UISpecialFrames;
--    if anything closed, stop; else ToggleGameMenu() opens GameMenuFrame.
local function SimulateBlizzardEscape(syncFollowers)
    if gameMenu:IsShown() then
        gameMenu:Hide()
        return "closed-menu"
    end
    if craftGame:IsShown() then
        local prevStack = debugstack
        debugstack = function() return "Blizzard_Professions/Blizzard_ProfessionsRegistration.lua:42" end
        craftGame:CheckConfirmClose()
        debugstack = prevStack
        if syncFollowers then syncFollowers() end
        return gameMenu:IsShown() and "opened-menu" or "craft-escape"
    end
    local closedAny = false
    for _, slot in ipairs({ "left", "center" }) do
        local p = GetUIPanel(slot)
        if p and p:IsShown() then
            HideUIPanel(p)
            closedAny = true
        end
    end
    for i = #UISpecialFrames, 1, -1 do
        local p = _G[UISpecialFrames[i]]
        if p and p:IsShown() then
            p:Hide()
            closedAny = true
        end
    end
    if syncFollowers then syncFollowers() end
    if closedAny then return "closed-window" end
    ToggleGameMenu()
    return "opened-menu"
end

-- Simulates DaylightUI's Follow.Tick closing any replacement whose parked game frame hid
local function SyncFollowers()
    if not charGame:IsShown() and duiChar:IsShown() then Feel.Close(duiChar) end
    if not socialGame:IsShown() and duiSocial:IsShown() then Feel.Close(duiSocial) end
    if not lfgGame:IsShown() and duiLfg:IsShown() then Feel.Close(duiLfg) end
    if not legacyGame:IsShown() and duiLegacy:IsShown() then Feel.Close(duiLegacy) end
    if not bookGame:IsShown() and duiBook:IsShown() then Feel.Close(duiBook) end
    if not craftGame:IsShown() and duiCraft:IsShown() then Feel.Close(duiCraft) end
end

-- Reset all windows cleanly; verify Escape protection works even with restoreWorkspaceOnReload = false!
Offhand.db.persistentWorkspacePanels = true
Offhand.db.restoreWorkspaceOnReload = false
gameMenu:Hide()
collections:Hide(); macroFrame:Hide(); auctionFrame:Hide()
duiChar:Hide(); charGame:Hide()
duiSocial:Hide(); socialGame:Hide()
duiLfg:Hide(); lfgGame:Hide()
duiLegacy:Hide(); legacyGame:Hide()
duiBook:Hide(); bookGame:Hide()
duiCraft:Hide(); craftGame:Hide()
slots.left, slots.center = nil, nil
UISpecialFrames = {}

-- 5a. Open all 5 slot-vacating DaylightUI windows on Offhand via hotkeys (including aside-parked Legacy & Book!)
duiChar.left, duiChar.top = 120, 1200
duiSocial.left, duiSocial.top = 80, 900
duiLfg.left, duiLfg.top = 100, 1000
duiLegacy.left, duiLegacy.top, duiLegacy.current = 140, 1100, "challenges"
duiBook.left, duiBook.top = 160, 1200

ToggleCharacter()
ToggleFriendsFrame()
ToggleLFGParentFrame()
ToggleLegacySystemUI()
PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
FlushTimers()

assert(duiChar:IsShown() and duiSocial:IsShown() and duiLfg:IsShown()
    and duiLegacy:IsShown() and duiBook:IsShown(),
    "All 5 Offhand DaylightUI windows must be open together without evicting each other")
assert(duiBook.current == "talents" and duiLegacy.current == "challenges",
    "Vacating aside-parked slots must preserve active Book and Legacy tabs")
assert(slots.left == nil and slots.center == nil,
    "All 5 Offhand DaylightUI windows must vacate Blizzard UIPanel slots")

-- Press Escape: ALL 5 Offhand panels stay open AND GameMenuFrame opens on the FIRST press!
assert(SimulateBlizzardEscape(SyncFollowers) == "opened-menu",
    "First Escape with only Offhand DaylightUI panels open must open Game Menu")
assert(gameMenu:IsShown(), "GameMenuFrame must be shown on first Escape")
assert(duiChar:IsShown() and duiSocial:IsShown() and duiLfg:IsShown()
    and duiLegacy:IsShown() and duiBook:IsShown(),
    "Escape must NOT close Character, Social, LFG, Legacy, or Book on Offhand")
-- Second Escape closes GameMenuFrame without touching Offhand panels
assert(SimulateBlizzardEscape(SyncFollowers) == "closed-menu" and not gameMenu:IsShown())
assert(duiChar:IsShown() and duiBook:IsShown(), "Closing GameMenu must leave Offhand panels open")

-- Tab switch on Character (ShowUIPanel re-called on already-open CharacterFrame) must re-vacate immediately
ShowUIPanel(charGame)
FlushTimers()
assert(slots.left == nil and slots.center == nil,
    "CharacterFrame tab switch (ShowUIPanel) must immediately re-vacate UIPanel slot")

-- Dragging Character from Offhand -> Mainhand (Room.Changed) must re-attach its UIPanel slot so Escape closes it!
duiChar.left, duiChar.top = 1400, 900
Room.Changed(duiChar)
assert(slots.left == charGame, "Dragging DaylightUICharacter to Mainhand must re-attach CharacterFrame slot")
assert(SimulateBlizzardEscape(SyncFollowers) == "closed-window",
    "Escape must close DaylightUICharacter after it is dragged to Mainhand")
assert(not duiChar:IsShown() and not charGame:IsShown(), "Mainhand Character must close on Escape")
assert(duiSocial:IsShown() and duiLfg:IsShown() and duiLegacy:IsShown() and duiBook:IsShown(),
    "Other Offhand windows must remain open when Mainhand Character closes on Escape")

-- Re-open Character on Offhand, then toggle Escape protection OFF -> Escape must close all Offhand windows
duiChar.left, duiChar.top = 120, 1200
ToggleCharacter()
FlushTimers()
assert(duiChar:IsShown() and slots.left == nil)
Offhand.db.persistentWorkspacePanels = false
Offhand.Bridges:Refresh("persistence")
assert(slots.left ~= nil, "Disabling Escape protection must re-attach open DaylightUI windows to Blizzard slots")
SimulateBlizzardEscape(SyncFollowers)
assert(not (duiChar:IsShown() and duiSocial:IsShown() and duiLfg:IsShown()
    and duiLegacy:IsShown() and duiBook:IsShown()),
    "Escape must close Offhand DaylightUI windows when Escape protection is toggled OFF")

-- Explicit X / hotkey close still works cleanly with Escape protection back ON
Offhand.db.persistentWorkspacePanels = true
Offhand.db.restoreWorkspaceOnReload = true
duiChar:Hide(); charGame:Hide()
duiSocial:Hide(); socialGame:Hide()
duiLfg:Hide(); lfgGame:Hide()
duiLegacy:Hide(); legacyGame:Hide()
duiBook:Hide(); bookGame:Hide()
slots.left, slots.center = nil, nil
ToggleCharacter()
FlushTimers()
assert(duiChar:IsShown() and slots.left == nil)
ToggleCharacter()
SyncFollowers()
assert(not duiChar:IsShown() and not charGame:IsShown(), "Hotkey toggle (C) must still close Offhand DaylightUICharacter")

-- 5b. DaylightUICraft (ProfessionsFrame, aside-parked): live CraftingPage session survives Escape!
duiCraft.left, duiCraft.top = 200, 1100
craftGame.CraftingPage:Show()
craftGame.BookPage:Hide()
ShowUIPanel(craftGame)
Feel.Open(duiCraft)
FlushTimers()
Offhand.Bridges:Refresh("tick")

local beforeNativeClose = craftNativeCloseCalls
-- With a Mainhand panel also open, Escape while Craft is on Offhand closes the Mainhand panel first!
local mainPanel = MakeWindow("MerchantFrame", 1400, 900, 400, 500)
ShowUIPanel(mainPanel)
SimulateBlizzardEscape(SyncFollowers)
assert(not mainPanel:IsShown(), "Escape with Offhand Craft + Mainhand panel must close the Mainhand panel first")
assert(craftGame:IsShown() and duiCraft:IsShown() and craftNativeCloseCalls == beforeNativeClose,
    "Offhand DaylightUICraft live crafting session must stay open when Mainhand panel closes")
assert(not gameMenu:IsShown(), "Game Menu must not open while closing a Mainhand panel")

-- Next Escape with no Mainhand panels opens GameMenuFrame while keeping live crafting session intact!
assert(SimulateBlizzardEscape(SyncFollowers) == "opened-menu",
    "Escape with only Offhand DaylightUICraft open must open GameMenuFrame")
assert(gameMenu:IsShown() and craftGame:IsShown() and duiCraft:IsShown()
    and craftGame.CraftingPage:IsShown() and craftNativeCloseCalls == beforeNativeClose,
    "Live crafting session must never run CheckConfirmClose native close on Escape")
gameMenu:Hide()

-- Explicit non-Registration close reaches nativeClose
debugstack = function() return "CloseButton:OnClick" end
craftGame:CheckConfirmClose()
SyncFollowers()
assert(craftNativeCloseCalls == beforeNativeClose + 1 and not craftGame:IsShown() and not duiCraft:IsShown(),
    "Explicit close of DaylightUICraft must still close normally")

-- Overview (BookPage) HideUIPanel + ToggleGameMenu fallback recovers Escape while explicit X stays closed
ToggleProfessionsBook()
FlushTimers()
assert(duiCraft:IsShown() and craftGame:IsShown() and craftGame.BookPage:IsShown())
HideUIPanel(craftGame)
ToggleGameMenu()
FlushTimers()
assert(craftGame:IsShown() and duiCraft:IsShown() and gameMenu:IsShown(),
    "Escape HideUIPanel + ToggleGameMenu on Craft overview must recover Craft and keep GameMenu shown")
gameMenu:Hide()
-- Explicit X close (Craft.Close calls Feel.Close before HideUIPanel, no ToggleGameMenu) stays closed
Feel.Close(duiCraft)
HideUIPanel(craftGame)
FlushTimers()
assert(not craftGame:IsShown() and not duiCraft:IsShown(), "Explicit Craft X close must remain closed")

-- Dragging Craft to Mainhand lets Escape close it normally
duiCraft.left, duiCraft.top = 1400, 900
craftGame.CraftingPage:Show()
ShowUIPanel(craftGame)
Feel.Open(duiCraft)
FlushTimers()
local beforeMainCraftClose = craftNativeCloseCalls
SimulateBlizzardEscape(SyncFollowers)
assert(craftNativeCloseCalls == beforeMainCraftClose + 1 and not duiCraft:IsShown(),
    "Mainhand DaylightUICraft must still close on Escape")

-- 5c. DaylightUI_Skins WindowMove standard Blizzard panels (reopen after prior sync + Escape!)
wmSpots.CollectionsJournal = { 120, 1000 }
wmSpots.AuctionHouseFrame = { 150, 900 }
collections:Hide(); slots.left, slots.center = nil, nil
UISpecialFrames = { "CollectionsJournal" }
-- Open CollectionsJournal via ShowUIPanel + WindowMove.Apply (same saved spot as earlier sync!)
ShowUIPanel(collections)
WindowMove.Apply("CollectionsJournal")
FlushTimers()
assert(slots.left == nil and slots.center == nil and #UISpecialFrames == 0,
    "Reopened Offhand WindowMove panel must evict its Blizzard UIPanel slot and UISpecialFrames entry")
assert(SimulateBlizzardEscape(SyncFollowers) == "opened-menu" and collections:IsShown(),
    "Escape must NOT close reopened Offhand WindowMove CollectionsJournal")
gameMenu:Hide()

-- Context-bound panel (AuctionHouseFrame rejected by RecordExternalPanelDrag) must NOT loop on ticks
ShowUIPanel(auctionFrame)
WindowMove.Apply("AuctionHouseFrame")
FlushTimers()
local movedCount = #externalMoved
Offhand.Bridges:Refresh("tick")
Offhand.Bridges:Refresh("tick")
assert(#externalMoved == movedCount and slots.left == auctionFrame,
    "Context-bound AuctionHouseFrame must keep its native slot without looping")

-- =====================================================================
-- TEST 6: DaylightUI_Bags survives navigating to Blizzard Options from
-- Game Menu (even right after /reload Hold() restore!) and reopens if
-- Options closed it through an untracked path.
-- =====================================================================
local simTime = 100
GetTime = function() return simTime end
local settingsPanel = MakeWindow("SettingsPanel", 1200, 900, 900, 700)
local openSettingsCalls = 0
C_SettingsUtil = {
    OpenSettingsPanel = function()
        openSettingsCalls = openSettingsCalls + 1
        ShowUIPanel(settingsPanel)
    end,
}

-- Simulate fresh reload with openBags = true -> Hold() opens DaylightUIBag with AnyOpen() == false!
duiBag:Hide(); bagOpenClose.held = nil; bagOpenClose.holdCalls = 0
duiBag.hooked = {}
function bagOpenClose.Follow()
    if bagOpenClose.held then duiBag:Show() else duiBag:Hide() end
end
_G.OffhandDB.bridges.DaylightUI.openBags = true
LoadChunk("Bridges/DaylightUI/Bags.lua", "Offhand", Offhand)
Offhand.Bridges:RestoreWorkspaceState("reload")
FlushTimers()
assert(bagOpenClose.holdCalls == 1 and bagOpenClose.held == true and duiBag:IsShown(),
    "Post-reload DaylightUIBag must open via Hold()")

-- RefreshBags MUST wrap openClose.Follow even though openClose.held is already true & AnyOpen() is false!
local settingsBagServices = {
    UpdateEscapeRegistration = function(_, name, supported, _, proxy)
        escapeRegistered[proxy] = supported and true or false
    end,
    IsEscapeRegistered = function(proxy) return escapeRegistered[proxy] == true end,
    CanSuppressVendorClose = function() return Offhand.db.persistentWorkspacePanels ~= false end,
    IsGameMenuBagClose = function(stack)
        return type(stack) == "string" and stack:find("Blizzard_GameMenuEsc/Blizzard_GameMenuEsc.lua", 1, true) ~= nil
    end,
    IsSettingsBagClose = function(stack)
        return type(stack) == "string"
            and stack:find("Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua", 1, true) ~= nil
            and stack:find("ShowUIPanel", 1, true) ~= nil
    end,
}
Offhand.Bridges:RefreshBags(settingsBagServices)

-- 6a. Clicking Options -> SettingsPanel ShowUIPanel -> CloseAllBags clears held and calls Follow():
--     wrapped Follow suppresses the close so DaylightUIBag never even closes!
local prevStack = debugstack
debugstack = function()
    return "Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua in function 'ShowUIPanel'\n"
        .. "Blizzard_Settings_Shared/Blizzard_SettingsPanel.lua:88"
end
bagOpenClose.held = nil
bagOpenClose.Follow()
debugstack = prevStack
assert(duiBag:IsShown() and bagOpenClose.held == true,
    "Post-reload held DaylightUIBag must stay open when Blizzard Options triggers CloseAllBags")

-- 6b. Fallback: if Blizzard Options closes DaylightUIBag right before/during OpenSettingsPanel
--     through a path that did not match SettingsPanel in stack, closing Options reopens DaylightUIBag!
local beforeFallbackHolds = bagOpenClose.holdCalls
simTime = 110
duiBag:Hide() -- simulates Blizzard closing bag right before OpenSettingsPanel shows SettingsPanel
C_SettingsUtil.OpenSettingsPanel()
assert(settingsPanel:IsShown() and not duiBag:IsShown())
assert(_G.OffhandDB.bridges.DaylightUI.openBags == true,
    "Closing DaylightUIBag during Options open must preserve openBags")
-- Closing Options (HideUIPanel(SettingsPanel)) immediately restores DaylightUIBag!
HideUIPanel(settingsPanel)
FlushTimers()
assert(not settingsPanel:IsShown() and duiBag:IsShown() and bagOpenClose.holdCalls == beforeFallbackHolds + 1,
    "Closing Blizzard Options must restore and reopen DaylightUIBag on Offhand")

-- 6c. Deliberate user bag close well AFTER Options opened must NOT reopen when Options closes!
simTime = 120
ShowUIPanel(settingsPanel)
Offhand.Bridges:Refresh("tick")
simTime = 125 -- 5 seconds later while Options is sitting open
bagOpenClose.CloseAll() -- user clicks X on bag
assert(not duiBag:IsShown() and _G.OffhandDB.bridges.DaylightUI.openBags == nil,
    "Explicit bag close while Options is open must clear openBags")
HideUIPanel(settingsPanel)
FlushTimers()
Offhand.Bridges:Refresh("tick")
assert(not duiBag:IsShown(), "Explicitly closed DaylightUIBag must stay closed after Options closes")

-- =====================================================================
-- TEST 7: DaylightUI_Bags B-key toggle (ToggleAllBags / ToggleBackpack /
-- ToggleBag) works cleanly when keepBagToggleOpen is off while the bag
-- stays on Offhand in held mode (both Combined Bags and Individual Bags),
-- and OpenAllBags (vendor/bank/mailbox) / direct OpenBackpack keep it open.
-- =====================================================================
local usingCombinedBags = true
local parkedCombined = MakeWindow("ContainerFrameCombinedBags", 0, 0, 200, 200, bagOpenClose.hidden)
local parkedBags = {
    [0] = MakeWindow("ContainerFrame1", 0, 0, 200, 200, bagOpenClose.hidden),
    [1] = MakeWindow("ContainerFrame2", 0, 0, 200, 200, bagOpenClose.hidden),
    [2] = MakeWindow("ContainerFrame3", 0, 0, 200, 200, bagOpenClose.hidden),
}
local function AnyParkedBagOpen()
    if parkedCombined:IsShown() then return true end
    for i = 0, 2 do
        if parkedBags[i]:IsShown() then return true end
    end
    return false
end
local function CloseAllParkedBags()
    parkedCombined:Hide()
    for i = 0, 2 do parkedBags[i]:Hide() end
end

local followPending = false
bagOpenClose.held = nil
bagOpenClose.AnyOpen = AnyParkedBagOpen
bagOpenClose.GameWindows = function() return { parkedCombined, parkedBags[0], parkedBags[1], parkedBags[2] } end
bagOpenClose.CloseGame = CloseAllParkedBags
bagOpenClose.Follow = function()
    if followPending then return end
    followPending = true
    C_Timer.After(0, function()
        followPending = false
        if bagOpenClose.AnyOpen() or bagOpenClose.held then
            duiBag:Show()
        else
            duiBag:Hide()
        end
    end)
end
bagOpenClose.CloseAll = function()
    bagOpenClose.held = nil
    bagOpenClose.CloseGame()
    bagOpenClose.Follow()
end
bagOpenClose.Hold = function()
    if bagOpenClose.held or bagOpenClose.AnyOpen() or duiBag:IsShown() then return false end
    bagOpenClose.held = true
    bagOpenClose.Follow()
    return true
end

local simStack = {}
local function WithStack(fnName, fn)
    simStack[#simStack + 1] = fnName
    local ok, err = pcall(fn)
    simStack[#simStack] = nil
    if not ok then error(err, 0) end
end
debugstack = function()
    local lines = {}
    for i = #simStack, 1, -1 do
        lines[#lines + 1] = "[C]: in function '" .. simStack[i] .. "'"
    end
    return table.concat(lines, "\n")
end

-- Mirror Blizzard's ContainerFrame.lua + DaylightUI_Bags/OpenClose.lua RELEASE hooks!
local function DuiAfter(how)
    if bagOpenClose.held then
        if how == "open" then
            if bagOpenClose.AnyOpen() then bagOpenClose.held = nil end
        elseif how == "toggle" then
            bagOpenClose.held = nil
            if bagOpenClose.AnyOpen() then bagOpenClose.CloseGame() end
        end
    end
    bagOpenClose.Follow()
end

OpenBag = function(id)
    WithStack("OpenBag", function()
        if usingCombinedBags then
            parkedCombined:Show()
        elseif parkedBags[id] then
            parkedBags[id]:Show()
        end
        DuiAfter("open")
    end)
end
OpenBackpack = function()
    WithStack("OpenBackpack", function()
        if usingCombinedBags then
            OpenBag(0)
        elseif not parkedBags[0]:IsShown() then
            ToggleBackpack()
        end
        DuiAfter("open")
    end)
end
local function OpenAllBagsInternal()
    OpenBackpack()
    if not usingCombinedBags then
        for i = 1, 2 do OpenBag(i) end
    end
end
OpenAllBags = function()
    WithStack("OpenAllBags", function()
        if not AnyParkedBagOpen() then OpenAllBagsInternal() end
        DuiAfter("open")
    end)
end
ToggleBag = function(id)
    WithStack("ToggleBag", function()
        if usingCombinedBags then
            if AnyParkedBagOpen() then
                parkedCombined:Hide()
            else
                OpenBackpack()
            end
        else
            if parkedBags[id] and parkedBags[id]:IsShown() then
                if id == 0 then CloseAllParkedBags() else parkedBags[id]:Hide() end
            elseif parkedBags[id] then
                parkedBags[id]:Show()
            end
        end
        DuiAfter("toggle")
    end)
end
ToggleBackpack = function()
    WithStack("ToggleBackpack", function()
        if usingCombinedBags then
            if AnyParkedBagOpen() then
                parkedCombined:Hide()
            else
                OpenBackpack()
            end
        else
            if parkedBags[0]:IsShown() then
                CloseAllParkedBags()
            else
                ToggleBag(0)
            end
        end
        DuiAfter("toggle")
    end)
end
ToggleAllBags = function()
    WithStack("ToggleAllBags", function()
        local openCount = 0
        local total = usingCombinedBags and 1 or 3
        if usingCombinedBags then
            if parkedCombined:IsShown() then
                openCount = 1
                parkedCombined:Hide()
            end
        else
            for i = 0, 2 do
                if parkedBags[i]:IsShown() then
                    openCount = openCount + 1
                    parkedBags[i]:Hide()
                end
            end
        end
        if openCount < total then
            OpenAllBagsInternal()
        end
        DuiAfter("toggle")
    end)
end

-- Reload Bags bridge so it installs fresh hooks on our simulated ToggleAllBags/ToggleBackpack/ToggleBag
duiBag:Hide(); duiBag.hooked = {}; CloseAllParkedBags(); bagOpenClose.held = nil
_G.OffhandDB.bridges.DaylightUI.openBags = nil
LoadChunk("Bridges/DaylightUI/Bags.lua", "Offhand", Offhand)
Offhand.Bridges:RestoreWorkspaceState("login")
FlushTimers()
Offhand.Bridges:RefreshBags(settingsBagServices)

-- 7a. Combined Bags mode: B opens -> RefreshBags puts it in held mode -> B closes -> B reopens -> B closes!
usingCombinedBags = true
ToggleAllBags()
FlushTimers()
assert(duiBag:IsShown() and parkedCombined:IsShown(), "First B press must open DaylightUIBag")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true and not parkedCombined:IsShown() and duiBag:IsShown(),
    "RefreshBags must arm held mode while keeping DaylightUIBag open on Offhand")

ToggleAllBags()
FlushTimers()
assert(not duiBag:IsShown() and not parkedCombined:IsShown() and not bagOpenClose.held,
    "Pressing B while DaylightUIBag is held open on Offhand (Combined Bags) must close it")
assert(_G.OffhandDB.bridges.DaylightUI.openBags == nil,
    "Closing DaylightUIBag via B must clear openBags")

ToggleAllBags()
FlushTimers()
assert(duiBag:IsShown() and parkedCombined:IsShown(),
    "Pressing B again after closing must reopen DaylightUIBag cleanly")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true and not parkedCombined:IsShown())

-- 7b. ToggleBackpack() and ToggleBag(0) in Combined Bags mode also close held DaylightUIBag cleanly!
ToggleBackpack()
FlushTimers()
assert(not duiBag:IsShown() and not parkedCombined:IsShown(),
    "ToggleBackpack while held open in Combined Bags mode must close DaylightUIBag")
ToggleBackpack()
FlushTimers()
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(duiBag:IsShown() and bagOpenClose.held == true)
ToggleBag(0)
FlushTimers()
assert(not duiBag:IsShown() and not parkedCombined:IsShown(),
    "ToggleBag while held open in Combined Bags mode must close DaylightUIBag")

-- 7c. Individual Bags mode: ToggleAllBags opens bags 1..2 after ToggleBag(0) — outer ToggleAllBags hook must close all!
usingCombinedBags = false
ToggleAllBags()
FlushTimers()
assert(duiBag:IsShown() and parkedBags[0]:IsShown() and parkedBags[1]:IsShown() and parkedBags[2]:IsShown())
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true and not AnyParkedBagOpen() and duiBag:IsShown())

ToggleAllBags()
FlushTimers()
assert(not duiBag:IsShown() and not AnyParkedBagOpen() and not bagOpenClose.held,
    "Pressing B while DaylightUIBag is held open on Offhand (Individual Bags) must close it and all parked bags")
ToggleAllBags()
FlushTimers()
assert(duiBag:IsShown() and AnyParkedBagOpen(),
    "Pressing B again in Individual Bags mode must reopen DaylightUIBag")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true and not AnyParkedBagOpen())

-- 7d. OpenAllBags (vendor/bank/mailbox) and direct OpenBackpack MUST keep held DaylightUIBag open!
usingCombinedBags = true
OpenAllBags()
FlushTimers()
assert(duiBag:IsShown() and parkedCombined:IsShown(),
    "OpenAllBags (vendor/mailbox) while held open must keep DaylightUIBag open")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true)

usingCombinedBags = false
OpenAllBags()
FlushTimers()
assert(duiBag:IsShown() and AnyParkedBagOpen(),
    "OpenAllBags in Individual Bags mode while held open must keep DaylightUIBag open")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true)

OpenBackpack()
FlushTimers()
assert(duiBag:IsShown() and (AnyParkedBagOpen() or bagOpenClose.held == true),
    "Direct OpenBackpack in Individual Bags mode while held open must keep DaylightUIBag open")
Offhand.Bridges:RefreshBags(settingsBagServices)
assert(bagOpenClose.held == true)

-- 7e. Closing Options then immediately pressing B (<0.5s) must close DaylightUIBag (optionsOpeningAt cleared)!
usingCombinedBags = true
simTime = 200
C_SettingsUtil.OpenSettingsPanel()
simTime = 200.1
HideUIPanel(settingsPanel)
FlushTimers()
simTime = 200.2
ToggleAllBags()
FlushTimers()
assert(not duiBag:IsShown(), "Pressing B immediately after closing Options must close DaylightUIBag")

assert(next(Offhand.Bridges.errors) == nil, "DaylightUI bridge must produce zero errors")
print("bridge-daylightui-windows tests passed")
