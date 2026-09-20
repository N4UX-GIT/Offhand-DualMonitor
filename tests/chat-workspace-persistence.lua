-- Test ChatFrame1 workspace dragging, FCF_StopDragging hooks, and reload persistence
local addon = {
    modules = {},
    db = {
        enabled = true,
        seamRedirect = true,
        independentWorkspacePanels = true,
        persistentWorkspacePanels = true,
        restoreWorkspaceOnReload = true,
        dockChat = true,
        chatPosition = "GAME",
        primaryPosition = "RIGHT",
        theme = "CLASSIC",
        trimColor = "GOLD",
        savedWorkspacePositions = {},
        savedMainPositions = {},
        openWorkspacePanels = {}
    }
}

UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 4000 end,
    GetHeight = function() return 2560 end,
    GetLeft = function() return 0 end,
    GetRight = function() return 4000 end,
    GetTop = function() return 2560 end,
    GetBottom = function() return 0 end,
    GetScale = function() return 1 end,
    SetScale = function() end,
}

local metrics = {
    gameLeft = 1440, gameRight = 4000, gameBottom = 6, gameTop = 1446,
    gameWidth = 2560, gameHeight = 1440, deckWidth = 1440, hudScale = 1,
    screenWidth = 4000, screenHeight = 2560, isSpanned = true,
    bezel = 0
}
addon.Viewport = { GetMetrics = function() return metrics end }
addon.Print = function() end
addon.RunOrQueueCombat = function(self, fn) fn() end
InCombatLockdown = function() return false end

hooksecurefunc = function(t, name, fn)
    if type(t) == "string" then
        local funcName = t
        local callback = name
        local orig = _G[funcName]
        _G[funcName] = function(...)
            local r = orig and orig(...)
            callback(...)
            return r
        end
        return
    end
    local orig = t[name]
    t[name] = function(...)
        local r = orig and orig(...)
        fn(...)
        return r
    end
end

C_Timer = {
    After = function(_, fn) fn() end,
}

UISpecialFrames = {}
UIPanelWindows = {}

local function makeMockFrame(name, w, h)
    local f = {
        name = name,
        points = {},
        scripts = {},
        shown = true,
        width = w or 300,
        height = h or 200,
        scale = 1,
        effectiveScale = 1,
        clamped = true,
        userPlaced = false, SetMovable = function(self, b) end,
        GetName = function(self) return self.name end,
        GetLeft = function(self)
            local p = self.points[#self.points]
            return p and p[4] or 0
        end,
        GetBottom = function(self)
            local p = self.points[#self.points]
            return p and p[5] or 0
        end,
        GetRight = function(self)
            return self:GetLeft() + self.width
        end,
        GetTop = function(self)
            return self:GetBottom() + self.height
        end,
        GetWidth = function(self) return self.width end,
        GetHeight = function(self) return self.height end,
        SetSize = function(self, nw, nh) self.width = nw; self.height = nh end,
        GetScale = function(self) return self.scale end,
        SetScale = function(self, s) self.scale = s end,
        GetEffectiveScale = function(self) return self.effectiveScale end,
        SetPoint = function(self, pt, rel, relPt, x, y)
            table.insert(self.points, { pt, rel, relPt, x, y })
        end,
        ClearAllPoints = function(self) self.points = {} end,
        GetNumPoints = function(self) return #self.points end,
        GetPoint = function(self, i)
            local p = self.points[i or 1]
            if p then return p[1], p[2], p[3], p[4], p[5] end
        end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        IsShown = function(self) return self.shown end,
        IsVisible = function(self) return self.shown end,
        HookScript = function(self, script, fn)
            local orig = self.scripts[script]
            self.scripts[script] = function(...)
                if orig then orig(...) end
                fn(...)
            end
        end,
        GetScript = function(self, script) return self.scripts[script] end,
        SetScript = function(self, script, fn) self.scripts[script] = fn end,
        SetClampedToScreen = function(self, val) self.clamped = val end,
        IsUserPlaced = function(self) return self.userPlaced end,
        SetUserPlaced = function(self, val) self.userPlaced = val end,
        StartMoving = function() end,
        StopMovingOrSizing = function() end,
        EnableMouse = function() end,
        RegisterForDrag = function() end,
    }
    _G[name] = f
    return f
end

FCF_SavePositionAndDimensions = function() end
FCF_StopDragging = function(cf)
    if cf then cf:StopMovingOrSizing() end
    MOVING_CHATFRAME = nil
end

ChatFrame1 = makeMockFrame("ChatFrame1", 400, 220)
ChatFrame1Tab = makeMockFrame("ChatFrame1Tab", 60, 24)
ChatFrame1Tab.GetParent = function() return ChatFrame1 end
ChatFrame1EditBox = makeMockFrame("ChatFrame1EditBox", 400, 30)

-- Load Offhand modules
assert(loadfile("UI/Themes.lua"))("Offhand", addon)
assert(loadfile("Core/Canvas.lua"))("Offhand", addon)
assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)

-- 1. Initialize dragging
addon.Canvas:EnableFreeDragging()
addon.SeamRedirect:HookFrames()

assert(ChatFrame1._OffhandChatHooked == true, "ChatFrame1 must be hooked for workspace dragging")
assert(ChatFrame1Tab._OffhandTabHooked == true, "ChatFrame1Tab must be hooked for workspace dragging")
assert(ChatFrame1.clamped == false, "ChatFrame1 must be unclamped from screen")

-- Blizzard's default anchor starts over the workspace. Position alone must not
-- turn that default into an explicit workspace placement, even if userPlaced is set.
ChatFrame1.IsInDefaultPosition = function() return true end
ChatFrame1:SetUserPlaced(true)
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 120)
GeneralDockManager = makeMockFrame("GeneralDockManager", 400, 24)
GENERAL_CHAT_DOCK = GeneralDockManager
GeneralDockManager.primary = ChatFrame1
GeneralDockManager.DOCKED_CHAT_FRAMES = {ChatFrame1}
GeneralDockManager:Hide()
ChatFrame1Tab:Hide()
ChatFrame1Tab.GetParent = function() return GeneralDockManager end
local dockUpdates = 0
FCFDock_UpdateTabs = function(dock, force)
    assert(dock == GeneralDockManager and force)
    dockUpdates = dockUpdates + 1
    ChatFrame1Tab:Show()
end
addon.db.savedWorkspacePositions.GeneralDockManager = {x=10,y=10}
addon.HUD:AlignChatFrame(metrics)
local _, _, _, defaultX, defaultY = ChatFrame1:GetPoint(1)
assert(defaultX == metrics.gameLeft + 48 and defaultY == metrics.gameBottom + 120,
    "Classic default must use bottom-left of game view despite userPlaced")
assert(not addon.db.savedWorkspacePositions.ChatFrame1, "Default alignment must not save a workspace preference")
assert(not addon.db.savedWorkspacePositions.GeneralDockManager, "Invalid old dock-container position must be cleared")
assert(ChatFrame1Tab:IsShown() and GeneralDockManager:IsShown(), "Native dock update must restore missing tab visibility")
local dockPoint, dockRelative, dockRelativePoint = GeneralDockManager:GetPoint(1)
assert(dockPoint == "BOTTOMLEFT" and dockRelative == ChatFrame1 and dockRelativePoint == "TOPLEFT")
addon.HUD:AlignChatFrame(metrics)
assert(dockUpdates == 1, "Do not continuously rebuild chat tabs")

-- Blizzard can replay its default anchor between rendered frames. Repair must
-- complete synchronously, without scheduling another full layout or resizing.
local oldAfter = C_Timer.After
C_Timer.After = function() error("Native anchor repair must not use a delayed timer") end
local oldSetSize = ChatFrame1.SetSize
ChatFrame1.SetSize = function() error("Anchor repair must not resize chat") end
for i = 1, 10 do
    ChatFrame1:ClearAllPoints()
    ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 120)
    assert(select(4, ChatFrame1:GetPoint(1)) == metrics.gameLeft + 48,
        "Default anchor must be corrected before SetPoint returns")
end
C_Timer.After = oldAfter
ChatFrame1.SetSize = oldSetSize

-- 2. Simulate dragging ChatFrame1 to workspace (x = 100, y = 300; deckWidth is 1440)
MOVING_CHATFRAME = ChatFrame1
ChatFrame1Tab.scripts.OnDragStart(ChatFrame1Tab)
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 300)
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == 100, "Layout must not interrupt a native tab drag")
FCF_StopDragging(ChatFrame1)
  ChatFrame1Tab.scripts.OnDragStop(ChatFrame1Tab)
  MOVING_CHATFRAME=nil
ChatFrame1Tab.scripts.OnDragStop(ChatFrame1Tab)
assert(not addon.db.savedWorkspacePositions.GeneralDockManager, "A tab drag must not persist its dock parent")

assert(addon.db.savedWorkspacePositions["ChatFrame1"] ~= nil, "ChatFrame1 must be saved to savedWorkspacePositions")
assert(addon.db.savedWorkspacePositions["ChatFrame1"].x >= 12, "ChatFrame1 x must be clamped within workspace")
assert(addon.db.savedWorkspacePositions["ChatFrame1"].x < metrics.deckWidth, "ChatFrame1 x must be on workspace")

-- 3. Run AlignChatFrame and AlignHUDFrames - verify ChatFrame1 is NOT moved to game view screen
addon.HUD:AlignHUDFrames()
local lastPt = ChatFrame1.points[#ChatFrame1.points]
print("LASTPT IS:", lastPt[1]); assert(lastPt[1] == "TOPLEFT", "ChatFrame1 must be anchored at BOTTOMLEFT")
assert(lastPt[4] < metrics.deckWidth, "ChatFrame1 must remain on workspace monitor (< deckWidth), got x=" .. tostring(lastPt[4]))

-- 4. Simulate /reload
addon.db.openWorkspacePanels["ChatFrame1"] = true
addon.Canvas:EnableFreeDragging()
addon.HUD:AlignHUDFrames()
addon.Canvas:RestorePersistentFrames()

local reloadPt = ChatFrame1.points[#ChatFrame1.points]
assert(reloadPt[1] == "TOPLEFT", "ChatFrame1 point after reload must be BOTTOMLEFT")
assert(reloadPt[4] < metrics.deckWidth, "ChatFrame1 must remain on workspace monitor after reload, got x=" .. tostring(reloadPt[4]))
assert(addon.db.savedWorkspacePositions["ChatFrame1"] ~= nil, "savedWorkspacePositions for ChatFrame1 must still exist")

-- 5. Test dragging ChatFrame1 back to game view screen (x = 2000 >= deckWidth)
MOVING_CHATFRAME = ChatFrame1
ChatFrame1Tab.scripts.OnDragStart(ChatFrame1Tab)
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 300)
FCF_StopDragging(ChatFrame1)
  ChatFrame1Tab.scripts.OnDragStop(ChatFrame1Tab)
  MOVING_CHATFRAME=nil

assert(addon.db.savedWorkspacePositions["ChatFrame1"] == nil, "savedWorkspacePositions for ChatFrame1 must be cleared when on game view screen")
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == 2000, "Deliberate game-view placement must survive default-layout refresh")

-- Respect customized Edit Mode positions and avoid mutations during combat.
ChatFrame1.IsInDefaultPosition = function() return false end
local _, _, _, customX = ChatFrame1:GetPoint(1)
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == customX)
InCombatLockdown = function() return true end
ChatFrame1.IsInDefaultPosition = function() return true end
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == customX, "Chat relocation must wait until combat ends")

print("PASS: ChatFrame1 workspace dragging, FCF_StopDragging hook, and reload persistence verified!")
