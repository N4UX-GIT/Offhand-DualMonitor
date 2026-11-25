local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local ns = shared
if type(shared) == "table" and shared.API and shared.API.GetBridgeNamespace then
    ns = shared.API.GetBridgeNamespace("DaylightUI")
end
if type(ns) ~= "table" or not ns.active then return end

-- DaylightUI window coordination on spanned monitors:
-- 1. Keep DaylightUI's Win.Room side-by-side slides inside each window's own
--    monitor so opening a panel on Offhand never shunts another Offhand window
--    across the seam into Mainhand (or vice versa).
-- 2. Report every parked Blizzard frame (hidden/aside/veil) to Offhand so core
--    placement leaves them untouched while this bridge persists and restores
--    Offhand DaylightUI replacement windows across reload/restart and single-
--    screen recovery.
-- 3. Forward DaylightUI_Skins WindowMove drags and right-click resets to
--    Offhand so skinned Blizzard panels keep Offhand workspace persistence.
local Windows = {}
ns.Windows = Windows

local DUI = ns.DUI
local Win = type(DUI) == "table" and DUI.Win or nil
local Feel = type(Win) == "table" and Win.Feel or nil
local Room = type(Win) == "table" and Win.Room or nil

local function num(v)
    if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then return false end
    if type(DUI) == "table" and type(DUI.IsSecret) == "function" then
        return not DUI.IsSecret(v)
    end
    return true
end

local function IsSpanned()
    local api = Offhand and Offhand.API
    local rect = api and type(api.GetGameRect) == "function" and api.GetGameRect()
    return type(rect) == "table" and rect.isSpanned == true
end

local function IsOnWorkspace(frame)
    local api = Offhand and Offhand.API
    if not frame or not api or type(api.IsFrameOnWorkspace) ~= "function" then return false end
    return api.IsFrameOnWorkspace(frame) == true
end

local function PersistenceEnabled()
    local api = Offhand and Offhand.API
    if not api or type(api.IsWorkspacePersistenceEnabled) ~= "function" then return true end
    return api.IsWorkspacePersistenceEnabled() == true
end

local function EscapeProtectionEnabled()
    local api = Offhand and Offhand.API
    if api and type(api.IsEscapeProtectionEnabled) == "function" then
        return api.IsEscapeProtectionEnabled() == true
    end
    return PersistenceEnabled()
end

-- ---------------------------------------------------------------------
-- 1. Monitor-confined Win.Room / Win.Feel.Slide
-- ---------------------------------------------------------------------

local function GetMonitors()
    local api = Offhand and Offhand.API
    if not api or type(api.GetGameRect) ~= "function" or type(api.GetWorkspaceRects) ~= "function" then
        return nil
    end
    local game = api.GetGameRect()
    if type(game) ~= "table" or not game.isSpanned then return nil end
    local workspaces = api.GetWorkspaceRects()
    if type(workspaces) ~= "table" or #workspaces == 0 then return nil end
    local monitors = {
        { left = game.left, bottom = game.bottom, right = game.right, top = game.top },
    }
    for _, ws in ipairs(workspaces) do
        monitors[#monitors + 1] = { left = ws.left, bottom = ws.bottom, right = ws.right, top = ws.top }
    end
    return monitors
end

local function HomeRect(frame)
    if type(frame) ~= "table" or type(frame.GetLeft) ~= "function" or type(frame.GetTop) ~= "function" then
        return nil
    end
    local l, t = frame:GetLeft(), frame:GetTop()
    local w = num(frame.goalW) and frame.goalW or (frame.GetWidth and frame:GetWidth())
    local h = num(frame.goalH) and frame.goalH or (frame.GetHeight and frame:GetHeight())
    if not (num(l) and num(t) and num(w) and num(h) and w > 0 and h > 0) then return nil end
    local fs = frame.GetEffectiveScale and frame:GetEffectiveScale()
    local ps = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
    if not (num(fs) and num(ps) and fs > 0 and ps > 0) then return nil end
    local k = fs / ps
    local ox = Feel and type(Feel.OffsetX) == "function" and Feel.OffsetX(frame) or 0
    local oy = Feel and type(Feel.Offset) == "function" and Feel.Offset(frame) or 0
    if not num(ox) then ox = 0 end
    if not num(oy) then oy = 0 end
    l = (l - ox) * k
    t = (t - oy) * k
    return { l = l, r = l + w * k, t = t, b = t - h * k, k = k }
end

local function FindMonitor(rect, monitors)
    local cx, cy = (rect.l + rect.r) / 2, (rect.b + rect.t) / 2
    for _, mon in ipairs(monitors) do
        if cx >= mon.left and cx <= mon.right and cy >= mon.bottom and cy <= mon.top then
            return mon
        end
    end
    local best, bestArea = nil, 0
    for _, mon in ipairs(monitors) do
        local ow = math.max(0, math.min(rect.r, mon.right) - math.max(rect.l, mon.left))
        local oh = math.max(0, math.min(rect.t, mon.top) - math.max(rect.b, mon.bottom))
        local area = ow * oh
        if area > bestArea then best, bestArea = mon, area end
    end
    return best
end

local function Covers(a, b)
    return a.l < b.r and b.l < a.r and a.b < b.t and b.b < a.t
end

local function FirstOverlap(rect, placed)
    for _, p in ipairs(placed) do
        if Covers(rect, p) then return p end
    end
    return nil
end

local function ShiftRect(r, x)
    local w = r.r - r.l
    return { l = x, r = x + w, t = r.t, b = r.b, k = r.k }
end

local function ClearInMonitor(r, placed, mon, gap, edge)
    if not placed or #placed == 0 or not FirstOverlap(r, placed) then return r.l end
    local function walk(dir)
        local s = r
        for _ = 1, #placed + 1 do
            local p = FirstOverlap(s, placed)
            if not p then return s end
            s = ShiftRect(s, dir > 0 and (p.r + gap) or (p.l - gap - (s.r - s.l)))
        end
        return s
    end
    local function fits(s)
        return s.l >= mon.left + edge and s.r <= mon.right - edge and not FirstOverlap(s, placed)
    end
    local right, left = walk(1), walk(-1)
    local dr, dl = math.abs(right.l - r.l), math.abs(left.l - r.l)
    if fits(right) and (not fits(left) or dr <= dl) then return right.l end
    if fits(left) then return left.l end
    -- Neither side fits inside this window's own monitor. Keep it calmly at
    -- its saved home spot instead of shunting it across the seam.
    return r.l
end

local laying = false
local placedInPass = nil

local function InstallRoomGuard()
    if not (Room and Feel and type(Feel.Slide) == "function") then return end
    if Feel._offhandSlideWrapped then return end
    Feel._offhandSlideWrapped = true

    if type(Room.Lay) == "function" and not Room._offhandLayWrapped then
        Room._offhandLayWrapped = true
        local origLay = Room.Lay
        function Room.Lay(...)
            local monitors = GetMonitors()
            if not monitors then return origLay(...) end
            local prevLaying, prevPlaced = laying, placedInPass
            laying, placedInPass = true, {}
            local ok, err = pcall(origLay, ...)
            laying, placedInPass = prevLaying, prevPlaced
            if not ok then error(err, 0) end
        end
    end

    local origSlide = Feel.Slide
    function Feel.Slide(frame, dx, ...)
        local monitors = GetMonitors()
        if not monitors or not frame or not num(dx) then
            return origSlide(frame, dx, ...)
        end
        local r = HomeRect(frame)
        local mon = r and FindMonitor(r, monitors)
        if not mon then
            return origSlide(frame, dx, ...)
        end
        local edge = num(Room.EDGE) and Room.EDGE or 4
        local gap = num(Room.GAP) and Room.GAP or 8
        local targetL = r.l + dx * r.k
        local targetR = r.r + dx * r.k
        local finalDx = dx
        if dx ~= 0 and (targetL < mon.left + edge or targetR > mon.right - edge) then
            local confinedL = laying and ClearInMonitor(r, placedInPass, mon, gap, edge) or r.l
            targetL = confinedL
            targetR = confinedL + (r.r - r.l)
            finalDx = (confinedL - r.l) / r.k
        end
        if laying and placedInPass then
            placedInPass[#placedInPass + 1] = { l = targetL, r = targetR, t = r.t, b = r.b }
        end
        return origSlide(frame, finalDx, ...)
    end
end

-- ---------------------------------------------------------------------
-- 2. Parked native panel detection & DaylightUI window reload persistence
-- ---------------------------------------------------------------------

function Windows.IsParkedNativePanel(frame)
    if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok or not parent then return false end
    local followers = Win and Win.Followers
    if type(followers) == "table" and (parent == followers.hidden or parent == followers.aside or parent == followers.veil) then
        return true
    end
    local charFollow = type(DUI) == "table" and type(DUI.Char) == "table" and DUI.Char.Follow
    if type(charFollow) == "table" and parent == charFollow.hidden then
        return true
    end
    return false
end

local function IsHiddenParkedFrame(frame)
    if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then return false end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok or not parent then return false end
    local followers = Win and Win.Followers
    local charFollow = type(DUI) == "table" and type(DUI.Char) == "table" and DUI.Char.Follow
    return (type(followers) == "table" and parent == followers.hidden)
        or (type(charFollow) == "table" and parent == charFollow.hidden)
end

local function IsAsideParkedFrame(frame)
    if type(frame) ~= "table" or type(frame.GetParent) ~= "function" then return false end
    local ok, parent = pcall(frame.GetParent, frame)
    if not ok or not parent then return false end
    local followers = Win and Win.Followers
    return type(followers) == "table" and parent == followers.aside
end

local function IsParkedGameFrame(frame)
    return IsHiddenParkedFrame(frame) or IsAsideParkedFrame(frame)
end

local function EnsureAddonLoaded(addonName)
    if type(addonName) ~= "string" or addonName == "" then return end
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
    if type(isLoaded) == "function" then
        local ok, loaded = pcall(isLoaded, addonName)
        if ok and loaded then return end
    end
    local loadAddon = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if type(loadAddon) == "function" then pcall(loadAddon, addonName) end
end

local function IsDaylightWindowOpen(frame)
    if type(frame) ~= "table" then return false end
    if Feel and type(Feel.IsOpen) == "function" then
        local ok, open = pcall(Feel.IsOpen, frame)
        if ok then return open == true end
    end
    return frame.IsShown and frame:IsShown() == true and not frame.__feelClosing
end

-- Restorable DaylightUI replacement windows. Slot-vacating windows restore
-- before Craft so Blizzard's UIPanel manager never closes earlier Offhand
-- windows before Craft opens, and Escape protection covers all six windows.
local MANAGED_WINDOWS = {
    {
        key = "character",
        order = 1,
        hidden = true,
        escapeMode = "vacate-slot",
        frame = function() return _G.DaylightUICharacter end,
        game = function() return _G.CharacterFrame end,
        covers = function()
            local follow = DUI and DUI.Char and DUI.Char.Follow
            return type(follow) == "table" and type(follow.Covers) == "function" and follow.Covers() == true
        end,
        page = function(f) return f and f.current or "character" end,
        open = function()
            local follow = DUI and DUI.Char and DUI.Char.Follow
            if type(follow) == "table" and not follow.parked and type(follow.Park) == "function" then
                pcall(follow.Park)
            end
            local g = _G.CharacterFrame
            if g and g.IsShown and g:IsShown() then return true end
            if type(ToggleCharacter) == "function" then
                pcall(ToggleCharacter, "PaperDollFrame")
                return true
            end
            if type(ShowUIPanel) == "function" and g then
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        close = function()
            local follow = DUI and DUI.Char and DUI.Char.Follow
            if type(follow) == "table" and type(follow.Close) == "function" then pcall(follow.Close) end
        end,
    },
    {
        key = "social",
        order = 2,
        hidden = true,
        escapeMode = "vacate-slot",
        addon = "Blizzard_SocialUI",
        frame = function() return _G.DaylightUISocial end,
        game = function() return _G.SocialUIFrame end,
        covers = function()
            local mod = DUI and DUI.Social and DUI.Social.Window
            return type(mod) == "table" and type(mod.Covers) == "function" and mod.Covers() == true
        end,
        page = function(f) return f and f.current or "friends" end,
        open = function()
            EnsureAddonLoaded("Blizzard_SocialUI")
            local g = _G.SocialUIFrame
            if g and g.IsShown and g:IsShown() then return true end
            if type(ToggleFriendsFrame) == "function" then
                pcall(ToggleFriendsFrame)
                return true
            end
            if type(ShowUIPanel) == "function" and g then
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        close = function()
            local mod = DUI and DUI.Social and DUI.Social.Window
            if type(mod) == "table" and type(mod.Close) == "function" then pcall(mod.Close) end
        end,
    },
    {
        key = "lfg",
        order = 3,
        hidden = true,
        escapeMode = "vacate-slot",
        addon = "Blizzard_GroupFinder_VanillaStyle",
        frame = function() return _G.DaylightUILfg end,
        game = function() return _G.LFGParentFrame end,
        covers = function()
            local mod = DUI and DUI.Lfg and DUI.Lfg.Window
            return type(mod) == "table" and type(mod.Covers) == "function" and mod.Covers() == true
        end,
        page = function(f) return f and f.current or "list" end,
        open = function()
            EnsureAddonLoaded("Blizzard_GroupFinder_VanillaStyle")
            local g = _G.LFGParentFrame
            if g and g.IsShown and g:IsShown() then return true end
            if type(ToggleLFGParentFrame) == "function" then
                pcall(ToggleLFGParentFrame)
                return true
            end
            if type(ShowUIPanel) == "function" and g then
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        close = function()
            local mod = DUI and DUI.Lfg and DUI.Lfg.Window
            if type(mod) == "table" and type(mod.Close) == "function" then pcall(mod.Close) end
        end,
    },
    {
        key = "legacy",
        order = 4,
        hidden = false,
        escapeMode = "vacate-slot",
        addon = "Blizzard_LegacySystem",
        frame = function() return _G.DaylightUILegacy end,
        game = function() return _G.LegacySystemFrame end,
        covers = function()
            local mod = DUI and DUI.Legacy and DUI.Legacy.Window
            return type(mod) == "table" and type(mod.Covers) == "function" and mod.Covers() == true
        end,
        page = function(f) return f and f.current or "progress" end,
        open = function()
            EnsureAddonLoaded("Blizzard_LegacySystem")
            local g = _G.LegacySystemFrame
            if g and g.IsShown and g:IsShown() then return true end
            if type(ToggleLegacySystemUI) == "function" then
                pcall(ToggleLegacySystemUI)
                return true
            end
            if type(ShowUIPanel) == "function" and g then
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        afterOpen = function(savedPage)
            local mod = DUI and DUI.Legacy and DUI.Legacy.Window
            if type(savedPage) == "string" and type(mod) == "table" and type(mod.ShowTab) == "function"
                and _G.DaylightUILegacy and _G.DaylightUILegacy.current ~= savedPage then
                pcall(mod.ShowTab, savedPage)
            end
        end,
        close = function()
            local mod = DUI and DUI.Legacy and DUI.Legacy.Window
            if type(mod) == "table" and type(mod.Close) == "function" then pcall(mod.Close) end
        end,
    },
    {
        key = "book",
        order = 5,
        hidden = false,
        escapeMode = "vacate-slot",
        addon = "Blizzard_PlayerSpells",
        frame = function() return _G.DaylightUIBook end,
        game = function() return _G.PlayerSpellsFrame end,
        covers = function()
            local mod = DUI and DUI.Book and DUI.Book.Window
            return type(mod) == "table" and type(mod.Covers) == "function" and mod.Covers() == true
        end,
        page = function(f) return f and f.current or "spells" end,
        open = function(savedPage)
            EnsureAddonLoaded("Blizzard_PlayerSpells")
            local g = _G.PlayerSpellsFrame
            if g and g.IsShown and g:IsShown() then return true end
            if savedPage == "talents" and PlayerSpellsUtil and type(PlayerSpellsUtil.ToggleClassTalentOrSpecFrame) == "function" then
                pcall(PlayerSpellsUtil.ToggleClassTalentOrSpecFrame)
                return true
            elseif savedPage == "talents" and type(ToggleTalentFrame) == "function" then
                pcall(ToggleTalentFrame)
                return true
            elseif PlayerSpellsUtil and type(PlayerSpellsUtil.ToggleSpellBookFrame) == "function" then
                pcall(PlayerSpellsUtil.ToggleSpellBookFrame)
                return true
            elseif type(ToggleSpellBookFrame) == "function" then
                pcall(ToggleSpellBookFrame)
                return true
            elseif type(ToggleSpellBook) == "function" then
                pcall(ToggleSpellBook, BOOKTYPE_SPELL or "spell")
                return true
            elseif type(ShowUIPanel) == "function" and g then
                if type(g.SetTab) == "function" then
                    local tabID = savedPage == "talents" and (g.talentTabID or 2) or (g.spellBookTabID or 3)
                    pcall(g.SetTab, g, tabID)
                end
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        afterOpen = function(savedPage)
            local mod = DUI and DUI.Book and DUI.Book.Window
            if type(savedPage) == "string" and type(mod) == "table" and type(mod.Show) == "function"
                and _G.DaylightUIBook and _G.DaylightUIBook.current ~= savedPage then
                pcall(mod.Show, savedPage)
            end
        end,
        close = function()
            local mod = DUI and DUI.Book and DUI.Book.Window
            if type(mod) == "table" and type(mod.Close) == "function" then pcall(mod.Close) end
        end,
    },
    {
        key = "craft",
        order = 6,
        hidden = false,
        escapeMode = "craft-escape",
        addon = "Blizzard_Professions",
        frame = function() return _G.DaylightUICraft end,
        game = function() return _G.ProfessionsFrame end,
        covers = function()
            local mod = DUI and DUI.Craft and DUI.Craft.Window
            return type(mod) == "table" and type(mod.Covers) == "function" and mod.Covers() == true
        end,
        page = function() return true end,
        open = function()
            EnsureAddonLoaded("Blizzard_Professions")
            local g = _G.ProfessionsFrame
            if g and g.IsShown and g:IsShown() then return true end
            if type(ToggleProfessionsBook) == "function" then
                pcall(ToggleProfessionsBook)
                return true
            end
            if type(ToggleSpellBook) == "function" and BOOKTYPE_PROFESSION then
                pcall(ToggleSpellBook, BOOKTYPE_PROFESSION)
                if g and g.IsShown and g:IsShown() then return true end
            end
            if type(ShowUIPanel) == "function" and g then
                if type(g.BookPage) == "table" and type(g.BookPage.Show) == "function" then
                    pcall(g.BookPage.Show, g.BookPage)
                end
                pcall(ShowUIPanel, g)
                return true
            end
            return false
        end,
        close = function()
            local mod = DUI and DUI.Craft and DUI.Craft.Window
            if type(mod) == "table" and type(mod.Close) == "function" then pcall(mod.Close) end
        end,
    },
}

local byKey = {}
for _, desc in ipairs(MANAGED_WINDOWS) do byKey[desc.key] = desc end

local transitioning, singleScreenPaused, restoring, sessionReady = false, false, false, false
local PANEL_SLOTS = { "left", "center", "right", "doublewide", "fullscreen" }
local vacating = setmetatable({}, { __mode = "k" })
local vacatedPanels = {}
local removedSpecial = {}
local craftEscapeState = {}
local pendingCraftEscape = nil
local hookedShowUIPanel, hookedHideUIPanel, hookedToggleGameMenu = false, false, false

local function GetOpenWindowsStore(create)
    local db = ns.DB and ns.DB()
    if type(db) ~= "table" then return nil end
    if type(db.openWindows) ~= "table" then
        if not create then return nil end
        db.openWindows = {}
    end
    return db.openWindows
end

local function DescriptorForFrame(frame)
    if not frame then return nil end
    for _, desc in ipairs(MANAGED_WINDOWS) do
        if desc.frame() == frame then return desc end
    end
    return nil
end

local function DescriptorForGameFrame(gameFrame)
    if not gameFrame then return nil end
    for _, desc in ipairs(MANAGED_WINDOWS) do
        if desc.game() == gameFrame then return desc end
    end
    return nil
end

local function OccupiesPanelSlot(frame)
    if not frame or type(GetUIPanel) ~= "function" then return false end
    for _, slot in ipairs(PANEL_SLOTS) do
        if GetUIPanel(slot) == frame then return true end
    end
    return false
end

local function IsInSpecialFrames(name)
    if type(name) ~= "string" or type(UISpecialFrames) ~= "table" then return false end
    for _, entry in ipairs(UISpecialFrames) do
        if entry == name then return true end
    end
    return false
end

local function ExcludeSpecialFrame(name)
    if InCombatLockdown() or type(name) ~= "string" or type(UISpecialFrames) ~= "table" then return false end
    local removed = false
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            if not removedSpecial[name] then removedSpecial[name] = i end
            table.remove(UISpecialFrames, i)
            removed = true
        end
    end
    return removed
end

local function RestoreSpecialFrame(name)
    if InCombatLockdown() or type(name) ~= "string" then return false end
    local index = removedSpecial[name]
    if not index or type(UISpecialFrames) ~= "table" then return false end
    removedSpecial[name] = nil
    if not IsInSpecialFrames(name) then
        table.insert(UISpecialFrames, math.min(index, #UISpecialFrames + 1), name)
    end
    return true
end

local function IsProtectedWorkspacePanel(panel)
    local desc = DescriptorForGameFrame(panel)
    if desc then
        local f = desc.frame()
        return f ~= nil and IsDaylightWindowOpen(f) and IsOnWorkspace(f)
    end
    if Windows.IsParkedNativePanel(panel) then return false end
    return IsOnWorkspace(panel)
end

local function CloseMainhandPanelsExcept(exceptFrame)
    local closed = false
    if type(GetUIPanel) == "function" and type(HideUIPanel) == "function" then
        local seen = {}
        for _, slot in ipairs(PANEL_SLOTS) do
            local p = GetUIPanel(slot)
            if p and p ~= exceptFrame and not seen[p] and p.IsShown and p:IsShown()
                and not IsProtectedWorkspacePanel(p) then
                seen[p] = true
                pcall(HideUIPanel, p)
                closed = true
            end
        end
    end
    if type(UISpecialFrames) == "table" then
        for _, name in ipairs(UISpecialFrames) do
            local p = type(name) == "string" and _G[name] or nil
            if p and p ~= exceptFrame and p ~= _G.GameMenuFrame and p.IsShown and p:IsShown()
                and not IsProtectedWorkspacePanel(p) and p.Hide then
                pcall(p.Hide, p)
                closed = true
            end
        end
    end
    return closed
end

local function VacatePanelSlot(desc, frame, gameFrame)
    if InCombatLockdown() or not desc or desc.escapeMode ~= "vacate-slot" then return false end
    if not gameFrame or type(HideUIPanel) ~= "function" or vacating[gameFrame] then return false end
    if not IsParkedGameFrame(gameFrame) then return false end
    if not (gameFrame.IsShown and gameFrame:IsShown()) then return false end
    local didVacate = false
    if OccupiesPanelSlot(gameFrame) then
        local savedPage = frame and frame.current
        vacating[gameFrame] = true
        pcall(HideUIPanel, gameFrame, 1)
        if gameFrame.Show and not gameFrame:IsShown() then
            pcall(gameFrame.Show, gameFrame)
        end
        vacating[gameFrame] = nil
        if savedPage and frame and frame.current ~= savedPage and desc.afterOpen then
            pcall(desc.afterOpen, savedPage)
        end
        vacatedPanels[desc.key] = true
        didVacate = true
    end
    local gName = gameFrame.GetName and gameFrame:GetName()
    if gName and ExcludeSpecialFrame(gName) then didVacate = true end
    return didVacate
end

local function ReattachPanelSlot(desc, frame, gameFrame)
    if not desc then return false end
    local gName = gameFrame and gameFrame.GetName and gameFrame:GetName()
    if gName and not InCombatLockdown() then RestoreSpecialFrame(gName) end
    if not vacatedPanels[desc.key] then return false end
    local open = frame ~= nil and IsDaylightWindowOpen(frame)
    local parkedShown = gameFrame ~= nil and IsParkedGameFrame(gameFrame)
        and gameFrame.IsShown and gameFrame:IsShown()
    if not open or not parkedShown then
        if not restoring then vacatedPanels[desc.key] = nil end
        return false
    end
    if InCombatLockdown() then return false end
    if type(GetUIPanel) == "function" and GetUIPanel("left") and GetUIPanel("center") then
        -- Wait for a free native panel slot instead of letting ShowUIPanel
        -- immediately close another open window while toggling settings.
        return false
    end
    vacatedPanels[desc.key] = nil
    if not OccupiesPanelSlot(gameFrame) and type(ShowUIPanel) == "function" and not vacating[gameFrame] then
        local savedPage = frame.current
        vacating[gameFrame] = true
        if gameFrame.Hide then pcall(gameFrame.Hide, gameFrame) end
        pcall(ShowUIPanel, gameFrame)
        if gameFrame.Show and not gameFrame:IsShown() then
            pcall(gameFrame.Show, gameFrame)
        end
        vacating[gameFrame] = nil
        if savedPage and frame.current ~= savedPage and desc.afterOpen then
            pcall(desc.afterOpen, savedPage)
        end
        return true
    end
    return false
end

local function InstallCraftEscapeGuard()
    if InCombatLockdown() or type(debugstack) ~= "function" then return end
    local g = _G.ProfessionsFrame
    if type(g) ~= "table" or type(g.CheckConfirmClose) ~= "function" then return end
    if craftEscapeState.frame == g and g.CheckConfirmClose == craftEscapeState.wrapper then return end
    local nativeClose = g.CheckConfirmClose
    local function wrapper(self, ...)
        local f = _G.DaylightUICraft
        if self == g
            and EscapeProtectionEnabled()
            and IsSpanned()
            and not InCombatLockdown()
            and IsAsideParkedFrame(g)
            and f and IsDaylightWindowOpen(f) and IsOnWorkspace(f)
            and ((self.CraftingPage and self.CraftingPage.IsShown and self.CraftingPage:IsShown())
                or (self.BookPage and self.BookPage.IsShown and self.BookPage:IsShown()))
            and debugstack(2, 3, 0):find("Blizzard_ProfessionsRegistration.lua", 1, true) then
            if GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() then
                if GameMenuFrame.Hide then pcall(GameMenuFrame.Hide, GameMenuFrame) end
            elseif not CloseMainhandPanelsExcept(g) and GameMenuFrame and GameMenuFrame.Show then
                pcall(GameMenuFrame.Show, GameMenuFrame)
            end
            return
        end
        return nativeClose(self, ...)
    end
    g.CheckConfirmClose = wrapper
    craftEscapeState.frame = g
    craftEscapeState.native = nativeClose
    craftEscapeState.wrapper = wrapper
end

local function ProtectManagedWindow(desc)
    if not desc then return end
    local f, g = desc.frame(), desc.game()
    local shouldProtect = EscapeProtectionEnabled()
        and IsSpanned()
        and f ~= nil and IsDaylightWindowOpen(f) and IsOnWorkspace(f)
        and g ~= nil and IsParkedGameFrame(g) and g.IsShown and g:IsShown()
    if desc.escapeMode == "vacate-slot" then
        if shouldProtect then
            VacatePanelSlot(desc, f, g)
        else
            ReattachPanelSlot(desc, f, g)
        end
    elseif desc.escapeMode == "craft-escape" then
        InstallCraftEscapeGuard()
        local gName = g and g.GetName and g:GetName()
        if shouldProtect then
            if gName then ExcludeSpecialFrame(gName) end
        else
            if gName then RestoreSpecialFrame(gName) end
        end
    end
end

local function SyncEscapeProtection()
    InstallCraftEscapeGuard()
    for _, desc in ipairs(MANAGED_WINDOWS) do
        ProtectManagedWindow(desc)
    end
end

local function ObserveCraftOverviewEscapeHide(panel)
    if InCombatLockdown() or not panel or panel ~= _G.ProfessionsFrame or vacating[panel] then return end
    if not EscapeProtectionEnabled() or not IsSpanned() or not IsAsideParkedFrame(panel) then return end
    if panel.IsShown and panel:IsShown() then return end
    local f = _G.DaylightUICraft
    if not (f and IsDaylightWindowOpen(f) and IsOnWorkspace(f)) then return end
    -- Only recover overview closes when Blizzard hides ProfessionsFrame via
    -- HideUIPanel during Escape. CraftingPage is protected pre-hide by
    -- CheckConfirmClose so live trade-skill sessions never end.
    local craftingShown = panel.CraftingPage and panel.CraftingPage.IsShown and panel.CraftingPage:IsShown()
    if craftingShown then return end
    local pending = {
        frame = panel,
        menuWasShown = GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() or false,
    }
    pendingCraftEscape = pending
    if C_Timer and C_Timer.After then
        C_Timer.After(0.10, function()
            if pendingCraftEscape == pending then pendingCraftEscape = nil end
        end)
    end
end

local function RestoreCraftOverviewAfterEscape(pending)
    if not pending or InCombatLockdown() or not EscapeProtectionEnabled() or not IsSpanned() then return end
    local desc = byKey.craft
    local g = desc and desc.game()
    if not g or g ~= pending.frame or not IsAsideParkedFrame(g) then return end
    if not (g.IsShown and g:IsShown()) then desc.open() end
    local menuShouldBeShown = not pending.menuWasShown
    local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown and GameMenuFrame:IsShown() or false
    if GameMenuFrame and menuShouldBeShown ~= menuIsShown then
        if menuShouldBeShown and GameMenuFrame.Show then
            pcall(GameMenuFrame.Show, GameMenuFrame)
        elseif GameMenuFrame.Hide then
            pcall(GameMenuFrame.Hide, GameMenuFrame)
        end
    end
end

local function InstallLifecycleHooks()
    if Feel and not Feel._offhandLifecycleWrapped then
        Feel._offhandLifecycleWrapped = true
        if type(Feel.Open) == "function" then
            local origOpen = Feel.Open
            function Feel.Open(frame, ...)
                local r1, r2 = origOpen(frame, ...)
                local desc = DescriptorForFrame(frame)
                if desc then
                    ProtectManagedWindow(desc)
                    if sessionReady and not transitioning and not singleScreenPaused and not restoring
                        and IsSpanned() and IsOnWorkspace(frame) then
                        local store = GetOpenWindowsStore(true)
                        if store then store[desc.key] = desc.page and desc.page(frame) or true end
                    end
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, function() ProtectManagedWindow(desc) end)
                    end
                end
                return r1, r2
            end
        end
        if type(Feel.Close) == "function" then
            local origClose = Feel.Close
            function Feel.Close(frame, ...)
                local desc = DescriptorForFrame(frame)
                if desc then
                    vacatedPanels[desc.key] = nil
                    local g = desc.game()
                    local gName = g and g.GetName and g:GetName()
                    if gName and not InCombatLockdown() then RestoreSpecialFrame(gName) end
                    if sessionReady and not transitioning and not singleScreenPaused and not restoring and IsSpanned() then
                        local store = GetOpenWindowsStore(false)
                        if store then store[desc.key] = nil end
                    end
                end
                return origClose(frame, ...)
            end
        end
    end
    if Room and type(Room.Changed) == "function" and not Room._offhandRoomChangedWrapped then
        Room._offhandRoomChangedWrapped = true
        local origChanged = Room.Changed
        function Room.Changed(frame, ...)
            local r1, r2 = origChanged(frame, ...)
            local desc = DescriptorForFrame(frame)
            if desc then
                ProtectManagedWindow(desc)
                if sessionReady and not transitioning and not singleScreenPaused and not restoring and IsSpanned() then
                    local store = GetOpenWindowsStore(true)
                    if store then
                        if IsDaylightWindowOpen(frame) and IsOnWorkspace(frame) then
                            store[desc.key] = desc.page and desc.page(frame) or true
                        else
                            store[desc.key] = nil
                        end
                    end
                end
            end
            return r1, r2
        end
    end
    if type(hooksecurefunc) == "function" then
        if type(ShowUIPanel) == "function" and not hookedShowUIPanel then
            hookedShowUIPanel = true
            hooksecurefunc("ShowUIPanel", function(panel)
                if not panel or vacating[panel] then return end
                local desc = DescriptorForGameFrame(panel)
                if not desc then return end
                ProtectManagedWindow(desc)
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() ProtectManagedWindow(desc) end)
                end
            end)
        end
        if type(HideUIPanel) == "function" and not hookedHideUIPanel then
            hookedHideUIPanel = true
            hooksecurefunc("HideUIPanel", function(panel)
                ObserveCraftOverviewEscapeHide(panel)
            end)
        end
        if type(ToggleGameMenu) == "function" and not hookedToggleGameMenu then
            hookedToggleGameMenu = true
            hooksecurefunc("ToggleGameMenu", function()
                local pending = pendingCraftEscape
                if not pending then return end
                pendingCraftEscape = nil
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function() RestoreCraftOverviewAfterEscape(pending) end)
                else
                    RestoreCraftOverviewAfterEscape(pending)
                end
            end)
        end
    end
end

local function SyncManagedWindows(preserveMissing)
    if not IsSpanned() then return end
    local keepMissing = preserveMissing or not sessionReady
    if not keepMissing and (transitioning or singleScreenPaused or restoring) then return end
    local store = GetOpenWindowsStore(true)
    if not store then return end
    for _, desc in ipairs(MANAGED_WINDOWS) do
        local f = desc.frame()
        if f and IsDaylightWindowOpen(f) and IsOnWorkspace(f) then
            store[desc.key] = desc.page and desc.page(f) or true
        elseif not keepMissing then
            store[desc.key] = nil
        end
    end
end

-- ---------------------------------------------------------------------
-- 3. DaylightUI_Skins WindowMove sync for standard Blizzard panels
-- ---------------------------------------------------------------------

local EXCLUDED_WINDOW_MOVE = {
    GameMenuFrame = true,
    AddonList = true,
}

local hookedMoveBars = setmetatable({}, { __mode = "k" })
local hookedWindowMoveForget = setmetatable({}, { __mode = "k" })
local hookedWindowMoveApply = setmetatable({}, { __mode = "k" })
local windowMoveEvictGuard = setmetatable({}, { __mode = "k" })
local pendingWindowMoveSync = {}
local syncedWindowSpots = {}

local function GetWindowMove()
    local skins = type(DUI) == "table" and type(DUI.GetModule) == "function" and DUI:GetModule("Skins")
    local wm = type(skins) == "table" and type(skins.ns) == "table" and skins.ns.WindowMove
    return type(wm) == "table" and wm or nil
end

local function NotifyMoved(frame)
    local api = Offhand and Offhand.API
    if not frame or not api or type(api.NotifyExternalPanelMoved) ~= "function" then return false end
    if InCombatLockdown() or not IsSpanned() then return false end
    if Windows.IsParkedNativePanel(frame) then return false end
    return api.NotifyExternalPanelMoved(frame) == true
end

local function SyncWindowMoveFrame(wm, name, forceCapture)
    if type(name) ~= "string" or EXCLUDED_WINDOW_MOVE[name] then return end
    local f = _G[name]
    if not (f and f.IsShown and f:IsShown()) then
        if f then windowMoveEvictGuard[f] = nil end
        return
    end
    if not IsSpanned() or Windows.IsParkedNativePanel(f) or not IsOnWorkspace(f) then
        windowMoveEvictGuard[f] = nil
        return
    end
    local spot = type(wm.Spot) == "function" and wm.Spot(name) or nil
    local token = type(spot) == "table" and (tostring(spot[1]) .. "," .. tostring(spot[2])) or "shown"
    local occupied = OccupiesPanelSlot(f)
    local inSpecial = IsInSpecialFrames(name)
    local needsEscapeSync = EscapeProtectionEnabled() and (occupied or inSpecial)
    local guardKey = token .. ":" .. tostring(occupied) .. ":" .. tostring(inSpecial)
    if forceCapture or syncedWindowSpots[name] ~= token
        or (needsEscapeSync and windowMoveEvictGuard[f] ~= guardKey) then
        syncedWindowSpots[name] = token
        windowMoveEvictGuard[f] = guardKey
        NotifyMoved(f)
        if not OccupiesPanelSlot(f) and not IsInSpecialFrames(name) then
            windowMoveEvictGuard[f] = nil
        end
    end
end

local function SyncWindowMove(forceCapture)
    local wm = GetWindowMove()
    if not wm then return end
    if type(wm.Forget) == "function" and not hookedWindowMoveForget[wm] then
        hookedWindowMoveForget[wm] = true
        local origForget = wm.Forget
        wm.Forget = function(name, ...)
            local r1, r2 = origForget(name, ...)
            local api = Offhand and Offhand.API
            if type(name) == "string" and not EXCLUDED_WINDOW_MOVE[name]
                and api and type(api.ForgetExternalWorkspacePanel) == "function" then
                syncedWindowSpots[name] = nil
                local f = _G[name]
                if f then windowMoveEvictGuard[f] = nil end
                api.ForgetExternalWorkspacePanel(name)
            end
            return r1, r2
        end
    end
    if type(wm.Apply) == "function" and not hookedWindowMoveApply[wm] then
        hookedWindowMoveApply[wm] = true
        local origApply = wm.Apply
        wm.Apply = function(name, ...)
            local r1, r2 = origApply(name, ...)
            if type(name) == "string" and not EXCLUDED_WINDOW_MOVE[name]
                and IsSpanned() and not InCombatLockdown() then
                if C_Timer and C_Timer.After then
                    if not pendingWindowMoveSync[name] then
                        pendingWindowMoveSync[name] = true
                        C_Timer.After(0, function()
                            pendingWindowMoveSync[name] = nil
                            SyncWindowMoveFrame(wm, name, false)
                        end)
                    end
                else
                    SyncWindowMoveFrame(wm, name, false)
                end
            end
            return r1, r2
        end
    end
    if type(wm.bars) ~= "table" then return end
    for name, bar in pairs(wm.bars) do
        if type(name) == "string" and not EXCLUDED_WINDOW_MOVE[name] then
            if type(bar) == "table" and type(bar.HookScript) == "function" and not hookedMoveBars[bar] then
                hookedMoveBars[bar] = true
                bar:HookScript("OnDragStop", function()
                    local f = _G[name]
                    if f then
                        syncedWindowSpots[name] = nil
                        windowMoveEvictGuard[f] = nil
                        NotifyMoved(f)
                    end
                end)
            end
            SyncWindowMoveFrame(wm, name, forceCapture)
        end
    end
end

-- ---------------------------------------------------------------------
-- Lifecycle hooks called by Bridges/DaylightUI/Init.lua
-- ---------------------------------------------------------------------

function Windows.Refresh()
    InstallRoomGuard()
    InstallLifecycleHooks()
    SyncManagedWindows(false)
    SyncEscapeProtection()
    SyncWindowMove(false)
end

function Windows.CaptureWorkspaceState()
    transitioning = true
    SyncWindowMove(true)
    SyncManagedWindows(true)
end

function Windows.PrepareSingleScreenRecovery()
    if not IsSpanned() then
        SyncManagedWindows(true)
    end
    local store = GetOpenWindowsStore(true)
    local closedAny = false
    for _, desc in ipairs(MANAGED_WINDOWS) do
        local f = desc.frame()
        if f and IsDaylightWindowOpen(f) and IsOnWorkspace(f) then
            if store then store[desc.key] = desc.page and desc.page(f) or true end
            closedAny = true
            if not InCombatLockdown() and desc.close then desc.close() end
        end
    end
    if closedAny then
        singleScreenPaused = true
        sessionReady = false
    end
end

function Windows.RestoreWorkspaceState()
    transitioning = false
    singleScreenPaused = false
    InstallRoomGuard()
    InstallLifecycleHooks()
    InstallCraftEscapeGuard()
    if restoring then return end
    if InCombatLockdown() or not IsSpanned() then return end
    if not PersistenceEnabled() then
        sessionReady = true
        SyncEscapeProtection()
        return
    end
    local store = GetOpenWindowsStore(false)
    if not store then
        sessionReady = true
        SyncEscapeProtection()
        return
    end
    local queue = {}
    for _, desc in ipairs(MANAGED_WINDOWS) do
        if store[desc.key] ~= nil then
            queue[#queue + 1] = { desc = desc, page = store[desc.key] }
        end
    end
    if #queue == 0 then
        sessionReady = true
        SyncEscapeProtection()
        return
    end
    restoring = true
    local remaining = #queue
    for index, item in ipairs(queue) do
        local desc = item.desc
        local delay = 0.25 + (index - 1) * 0.25
        local function runRestore()
            local function doneOne()
                remaining = remaining - 1
                if remaining <= 0 then
                    restoring = false
                    sessionReady = true
                end
            end
            if InCombatLockdown() or not IsSpanned() or not PersistenceEnabled() then
                doneOne()
                return
            end
            local currentStore = GetOpenWindowsStore(false)
            if not currentStore or currentStore[desc.key] == nil then
                doneOne()
                return
            end
            if desc.addon then EnsureAddonLoaded(desc.addon) end
            if desc.covers and not desc.covers() then
                doneOne()
                return
            end
            desc.open(item.page)
            if desc.escapeMode == "vacate-slot" and EscapeProtectionEnabled() then
                VacatePanelSlot(desc, desc.frame(), desc.game())
            elseif desc.escapeMode == "craft-escape" then
                InstallCraftEscapeGuard()
            end
            local function settle()
                if desc.afterOpen then desc.afterOpen(item.page) end
                local f = desc.frame()
                if f and IsDaylightWindowOpen(f) and not IsOnWorkspace(f) then
                    currentStore[desc.key] = nil
                end
                ProtectManagedWindow(desc)
                doneOne()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0.25, settle)
            else
                settle()
            end
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, runRestore)
        else
            runRestore()
        end
    end
end

InstallRoomGuard()
InstallLifecycleHooks()
InstallCraftEscapeGuard()
