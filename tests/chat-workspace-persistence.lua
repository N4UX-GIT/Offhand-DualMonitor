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
FCF_IsDocked = function(cf)
    return cf and (cf.isDocked == true or cf.isDocked == 1) or false
end
FCF_DockFrame = function(cf)
    cf.isDocked = 1
end
local undockRefreshes = 0
FCF_UnDockFrame = function(cf)
    undockRefreshes = undockRefreshes + 1
    cf.isDocked = nil
    cf.isStaticDocked = nil
    cf.floatingPresentation = true
end
FCF_SetLocked = function(cf, locked)
    cf.isLocked = locked
end
local chatWindowPresentation = {
    [2] = {name="Combat Log", r=0.08, g=0.09, b=0.10, alpha=0.35},
    [3] = {name="1", r=0.08, g=0.09, b=0.10, alpha=0.35},
}
OffhandDB = { compatibility = {} }
FCF_GetChatWindowInfo = function(id)
    local info = chatWindowPresentation[id] or chatWindowPresentation[2]
    return info.name, 14, info.r, info.g, info.b, info.alpha,
        info.shown ~= false, true, info.docked == true
end
FCF_SetWindowColor = function(cf, r, g, b, doNotSave)
    local id = tonumber(cf:GetName():match("(%d+)$"))
    if not doNotSave then
        chatWindowPresentation[id].r = r
        chatWindowPresentation[id].g = g
        chatWindowPresentation[id].b = b
    end
    cf.floatingColor = {r, g, b}
end
FCF_SetWindowAlpha = function(cf, alpha, doNotSave)
    local id = tonumber(cf:GetName():match("(%d+)$"))
    if not doNotSave then chatWindowPresentation[id].alpha = alpha end
    cf.floatingAlpha = alpha
end
local shownChatWindows = {}
local chatStateWrites = {}
SetChatWindowShown = function(id, shown)
    shownChatWindows[id] = shown
    if chatWindowPresentation[id] then chatWindowPresentation[id].shown = shown end
    chatStateWrites[#chatStateWrites + 1] = {"shown", id, shown}
end
SetChatWindowDocked = function(id, docked)
    chatStateWrites[#chatStateWrites + 1] = {"docked", id, docked}
end
FCF_CheckShowChatFrame = function(frame)
    frame:Show()
end
FCF_FadeInChatFrame = function(frame)
    frame.floatingFadedIn = true
end

ChatFrame1 = makeMockFrame("ChatFrame1", 400, 220)
ChatFrame1Tab = makeMockFrame("ChatFrame1Tab", 60, 24)
ChatFrame1Tab.GetParent = function() return ChatFrame1 end
ChatFrame1EditBox = makeMockFrame("ChatFrame1EditBox", 400, 30)
ChatFrame1.isLocked = true
ChatFrame1.isDocked = 1
ChatFrame1.SetMovable = function()
    error("Offhand must not override Blizzard's locked chat movable state")
end
ChatFrame1.StartMoving = function()
    error("Offhand must not force StartMoving on a locked or docked chat frame")
end
ChatFrame1Tab.RegisterForDrag = function()
    error("Offhand must not override Blizzard's native chat-tab drag registration")
end

-- A detached chat window explicitly placed on Mainhand must be restored just
-- like an Offhand-side window. Forever otherwise rebuilds it at the full-span
-- center during login/reload, causing detached windows to stack.
ChatFrame2 = makeMockFrame("ChatFrame2", 520, 240)
ChatFrame2Tab = makeMockFrame("ChatFrame2Tab", 60, 24)
ChatFrame2Tab.GetParent = function() return ChatFrame2 end
ChatFrame2:ClearAllPoints()
ChatFrame2:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
addon.db.savedMainPositions.ChatFrame2 = {
    point = "TOPLEFT", x = 2860, y = 1120,
}

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
assert(select(1, ChatFrame2:GetPoint(1)) == "TOPLEFT"
    and select(4, ChatFrame2:GetPoint(1)) == 2860
    and select(5, ChatFrame2:GetPoint(1)) == 1120,
    "Detached Mainhand chat must restore its explicit position during initialization")
local lockedDragOk, lockedDragError = pcall(ChatFrame1Tab.scripts.OnDragStart, ChatFrame1Tab)
assert(lockedDragOk, "Locked/docked ChatFrame1 drag observation must not force movement: " .. tostring(lockedDragError))
ChatFrame1._OffhandDragging = false

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

-- Recover a custom detached window damaged by the reverted undock-based beta.
-- Unlike built-in Combat Log, a custom frame may return with both legacy dock
-- flags nil, so live dock membership alone must select visibility recovery.
ChatFrame3 = makeMockFrame("ChatFrame3", 430, 210)
ChatFrame3Tab = makeMockFrame("ChatFrame3Tab", 60, 24)
ChatFrame3Tab.GetParent = function() return ChatFrame3 end
ChatFrame3:Hide()
ChatFrame3Tab:Hide()
addon.db.savedMainPositions.ChatFrame3 = {
    point = "TOPLEFT", x = 3100, y = 1040,
}
addon.Canvas:EnableFreeDragging()
assert(ChatFrame3:IsShown() and ChatFrame3Tab:IsShown()
    and shownChatWindows[3] == true
    and ChatFrame3.isDocked == nil and ChatFrame3.isStaticDocked == nil
    and select(4, ChatFrame3:GetPoint(1)) == 3100
    and ChatFrame3.floatingFadedIn == true,
    "A tracked custom chat with no dock flags must recover visibility and position")
assert(undockRefreshes == 0,
    "Custom chat recovery must never call FCF_UnDockFrame")

-- Changing a tracked floating window through Blizzard's color picker must
-- retain the newly selected values after its later dock-oriented fade update.
ChatFrame3.floatingFadedIn = false
local appearanceTimers = {}
local immediateAfter = C_Timer.After
C_Timer.After = function(delay, fn)
    appearanceTimers[#appearanceTimers + 1] = {delay=delay, callback=fn}
end
FCF_SetWindowColor(ChatFrame3, 0.45, 0.25, 0.15, false)
FCF_SetWindowAlpha(ChatFrame3, 0.72, false)
assert(#appearanceTimers == 2 and appearanceTimers[1].delay == 0
        and appearanceTimers[2].delay > 0,
    "Color and opacity changes must share immediate and settlement refreshes")
appearanceTimers[1].callback()
-- Forever performs this late fade after the setters and their next-frame
-- callbacks, which used to erase the detached frame background again.
ChatFrame3.floatingColor = nil
ChatFrame3.floatingAlpha = 0
ChatFrame3.floatingFadedIn = false
appearanceTimers[2].callback()
assert(ChatFrame3.floatingColor[1] == 0.45
    and ChatFrame3.floatingColor[2] == 0.25
    and ChatFrame3.floatingAlpha == 0.72
    and chatWindowPresentation[3].alpha == 0.72
    and ChatFrame3.floatingFadedIn == true,
    "Color-picker changes must survive the detached chat presentation refresh")

-- Opening Settings can run the same setter with doNotSave=true before its
-- dock-oriented fade. It still needs a presentation replay, while Offhand's
-- guarded replay must not recursively enqueue itself.
appearanceTimers = {}
FCF_SetWindowAlpha(ChatFrame3, 0, true)
assert(#appearanceTimers == 2,
    "Settings initialization must schedule detached presentation settlement")
appearanceTimers[1].callback()
ChatFrame3.floatingAlpha = 0
ChatFrame3.floatingFadedIn = false
appearanceTimers[2].callback()
C_Timer.After = immediateAfter
assert(ChatFrame3.floatingAlpha == 0.72 and ChatFrame3.floatingFadedIn == true,
    "Opening chat Settings must not erase the saved background opacity")

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

-- Forever's chat size control saves through Blizzard's native FCF function.
-- Capture that explicit size once, then prove a stale runtime width is repaired
-- from the Offhand workspace snapshot during reload restoration.
addon.isForever = true
addon.ForeverPersistence = {
    SaveWorkspacePosition = function() end,
    ClearPosition = function() end,
    SaveOpenPanels = function() end,
}

-- Repair the exact Beta 19 loss signature once: native Combat Log remains
-- detached with a valid Blizzard position, but both SHOWN and Offhand's saved
-- Mainhand snapshot were cleared by the transient-dock misclassification.
local originalCombatPosition = addon.db.savedMainPositions.ChatFrame2
addon.db.savedMainPositions.ChatFrame2 = nil
ChatFrame2:Hide()
ChatFrame2Tab:Hide()
chatWindowPresentation[2].shown = false
chatWindowPresentation[2].docked = false
assert(addon.Canvas:RecoverLostForeverCombatLog()
        and ChatFrame2:IsShown() and ChatFrame2Tab:IsShown()
        and addon.db.savedMainPositions.ChatFrame2 ~= nil
        and OffhandDB.compatibility.detachedCombatLogRecoveryVersion == 1,
    "Forever must recover and recapture the Combat Log snapshot erased by the affected beta")
addon.db.savedMainPositions.ChatFrame2 = originalCombatPosition

-- Chat Settings may fade detached windows without calling either FCF setter.
-- The Forever-owned observer must repair presentation while the panel is open
-- and once more on the transition back to gameplay.
ChatConfigFrame = makeMockFrame("ChatConfigFrame", 600, 500)
ChatConfigFrame:Show()
ChatFrame3.floatingAlpha = 0
ChatFrame3.floatingFadedIn = false
addon.Canvas:MonitorDetachedChatSettingsPresentation()
assert(ChatFrame3.floatingAlpha == 0.72 and ChatFrame3.floatingFadedIn == true,
    "Chat Settings observer must restore detached presentation without setter callbacks")
ChatConfigFrame:Hide()
ChatFrame3.floatingAlpha = 0
ChatFrame3.floatingFadedIn = false
addon.Canvas:MonitorDetachedChatSettingsPresentation()
assert(ChatFrame3.floatingAlpha == 0.72 and ChatFrame3.floatingFadedIn == true,
    "Closing Chat Settings must perform a final detached presentation repair")

ChatFrame1:SetSize(800, 257)
FCF_SavePositionAndDimensions(ChatFrame1)
assert(addon.db.savedWorkspacePositions.ChatFrame1.width == 800
    and addon.db.savedWorkspacePositions.ChatFrame1.height == 257,
    "An explicit Forever chat resize must update the workspace dimensions")

-- 3. Run AlignChatFrame and AlignHUDFrames - verify ChatFrame1 is NOT moved to game view screen
addon.HUD:AlignHUDFrames()
local lastPt = ChatFrame1.points[#ChatFrame1.points]
print("LASTPT IS:", lastPt[1]); assert(lastPt[1] == "TOPLEFT", "ChatFrame1 must be anchored at BOTTOMLEFT")
assert(lastPt[4] < metrics.deckWidth, "ChatFrame1 must remain on workspace monitor (< deckWidth), got x=" .. tostring(lastPt[4]))

-- 4. Simulate /reload
addon.db.openWorkspacePanels["ChatFrame1"] = true
ChatFrame1:SetSize(460, 220)
addon.Canvas:EnableFreeDragging()
addon.HUD:AlignHUDFrames()
addon.Canvas:RestorePersistentFrames()

local reloadPt = ChatFrame1.points[#ChatFrame1.points]
assert(reloadPt[1] == "TOPLEFT", "ChatFrame1 point after reload must be BOTTOMLEFT")
assert(reloadPt[4] < metrics.deckWidth, "ChatFrame1 must remain on workspace monitor after reload, got x=" .. tostring(reloadPt[4]))
assert(addon.db.savedWorkspacePositions["ChatFrame1"] ~= nil, "savedWorkspacePositions for ChatFrame1 must still exist")
assert(ChatFrame1:GetWidth() == 800 and ChatFrame1:GetHeight() == 257,
    "Reload restoration must reapply the last explicitly saved chat dimensions")

-- Simulate Forever's late native chat rebuild after the first Offhand pass.
-- Its save callback must reassert the committed Mainhand placement rather than
-- accepting the full-span centered anchor as a new user choice.
-- Forever may leave its legacy dock flags set on a visually detached frame;
-- current membership in the dock manager is the authoritative topology.
table.insert(GeneralDockManager.DOCKED_CHAT_FRAMES, ChatFrame2)
FCF_DockFrame(ChatFrame2)
FCF_SavePositionAndDimensions(ChatFrame2)
assert(addon.db.savedMainPositions.ChatFrame2 ~= nil,
    "Transient reload-time dock and save callbacks must not delete detached chat state")
table.remove(GeneralDockManager.DOCKED_CHAT_FRAMES)
ChatFrame2.isDocked = 1
ChatFrame2.isStaticDocked = true
ChatFrame2.isLocked = true
ChatFrame2:Hide()
ChatFrame2Tab:Hide()
ChatFrame2:ClearAllPoints()
ChatFrame2:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
FCF_SavePositionAndDimensions(ChatFrame2)
assert(select(1, ChatFrame2:GetPoint(1)) == "TOPLEFT"
    and select(4, ChatFrame2:GetPoint(1)) == 2860
    and select(5, ChatFrame2:GetPoint(1)) == 1120,
    "Late Forever chat layout must not overwrite a detached Mainhand position")
local shownWrite, dockedWrite
for index, write in ipairs(chatStateWrites) do
    if write[2] == 2 and write[1] == "shown" then shownWrite = index end
    if write[2] == 2 and write[1] == "docked" then dockedWrite = index end
end
assert(undockRefreshes == 0 and ChatFrame2.isDocked == nil
    and ChatFrame2.isStaticDocked == true and ChatFrame2.isLocked == true
    and ChatFrame2.floatingAlpha == 0.35 and ChatFrame2.floatingColor[1] == 0.08
    and ChatFrame2.floatingFadedIn == true
    and ChatFrame2:IsShown() and ChatFrame2Tab:IsShown()
    and shownChatWindows[2] == true and shownWrite and dockedWrite
    and shownWrite < dockedWrite,
    "A detached Forever chat must commit shown before detached, then refresh presentation safely")

-- Returning a detached chat to Blizzard's primary dock relinquishes Offhand's
-- monitor snapshot and normalizes the tab to the primary chat dimensions.
ChatFrame1:SetSize(760, 280)
ChatFrame2:SetSize(520, 240)
table.insert(GeneralDockManager.DOCKED_CHAT_FRAMES, ChatFrame2)
ChatFrame2._OffhandDragging = true
MOVING_CHATFRAME = ChatFrame2
FCF_DockFrame(ChatFrame2)
ChatFrame2._OffhandDragging = false
MOVING_CHATFRAME = nil
assert(addon.db.savedMainPositions.ChatFrame2 == nil
    and addon.db.savedWorkspacePositions.ChatFrame2 == nil,
    "Docking a detached chat must clear its Offhand monitor snapshot")
assert(ChatFrame2:GetWidth() == ChatFrame1:GetWidth()
    and ChatFrame2:GetHeight() == ChatFrame1:GetHeight(),
    "Docked chat tabs must inherit the primary chat frame size")

-- Chattynator reuses ChatFrame1EditBox but anchors it to its own chat window.
-- Offhand must not move that shared edit box back to Blizzard's hidden frame.
local chattynatorFrame = makeMockFrame("ChattynatorPrimaryTestFrame", 800, 257)
ChatFrame1EditBox:ClearAllPoints()
ChatFrame1EditBox:SetPoint("TOPLEFT", chattynatorFrame, "BOTTOMLEFT", 0, 30)
C_AddOns = { IsAddOnLoaded = function(name) return name == "Chattynator" end }
addon.Canvas:RestoreWorkspacePosition(ChatFrame1)
local _, chatEditRelative = ChatFrame1EditBox:GetPoint(1)
assert(chatEditRelative == chattynatorFrame,
    "Offhand must preserve Chattynator's ChatFrame1EditBox anchor")
local chattyPrimaryPoints = chattynatorFrame:GetNumPoints()
local chattyEditPoints = ChatFrame1EditBox:GetNumPoints()
addon.HUD:AlignChatFrame(metrics)
assert(chattynatorFrame:GetNumPoints() == chattyPrimaryPoints
    and ChatFrame1EditBox:GetNumPoints() == chattyEditPoints
    and select(2, ChatFrame1EditBox:GetPoint(1)) == chattynatorFrame,
    "HUD alignment must fully yield Chattynator's window and shared edit box")

ChatFrame2.isDocked = 1
ChatFrame2:ClearAllPoints()
ChatFrame2:SetPoint("TOPLEFT", chattynatorFrame, "TOPLEFT", 0, -22)
ChatFrame2:SetPoint("BOTTOMRIGHT", chattynatorFrame, "BOTTOMRIGHT", -15, 0)
ChatFrame2:SetSize(615, 330)
addon.db.savedMainPositions.ChatFrame2 = {point="TOPLEFT", x=2860, y=1120}
local chattyCombatPoints = ChatFrame2:GetNumPoints()
addon.Canvas:RestoreWorkspacePosition(ChatFrame2)
assert(ChatFrame2:GetNumPoints() == chattyCombatPoints
    and ChatFrame2:GetWidth() == 615 and ChatFrame2:GetHeight() == 330,
    "Offhand must not reanchor or resize Chattynator's borrowed ChatFrame2")
assert(addon.db.savedMainPositions.ChatFrame2 == nil,
    "Chattynator ownership must clear stale native chat persistence")
C_AddOns = nil

-- 5. Test dragging ChatFrame1 back to game view screen (x = 2000 >= deckWidth)
MOVING_CHATFRAME = ChatFrame1
ChatFrame1Tab.scripts.OnDragStart(ChatFrame1Tab)
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2000, 300)
FCF_StopDragging(ChatFrame1)
  ChatFrame1Tab.scripts.OnDragStop(ChatFrame1Tab)
  MOVING_CHATFRAME=nil

assert(addon.db.savedWorkspacePositions["ChatFrame1"] == nil, "savedWorkspacePositions for ChatFrame1 must be cleared when on game view screen")
local savedMainTop = addon.db.savedMainPositions.ChatFrame1.y
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == 2000,
    "Deliberate game-view placement must survive default-layout refresh; got "
        .. tostring(select(4, ChatFrame1:GetPoint(1))))
assert(select(1, ChatFrame1:GetPoint(1)) == "TOPLEFT"
    and select(5, ChatFrame1:GetPoint(1)) == savedMainTop,
    "Mainhand chat restoration must preserve the saved top edge instead of treating it as a bottom edge")

-- Newer Forever builds expose the primary chat as a native Edit Mode system.
-- Once that contract is present, Blizzard's active profile must be authoritative
-- and any historical Offhand coordinates must be discarded.
ChatFrame1.OnEditModeEnter = function(self) self.isInEditMode = true end
ChatFrame1.OnEditModeExit = function(self) self.isInEditMode = false end
addon.db.savedWorkspacePositions.ChatFrame1 = {x=100, y=300, width=800, height=257}
addon.db.savedMainPositions.ChatFrame1 = {point="TOPLEFT", x=2000, y=900}
addon.db.openWorkspacePanels.ChatFrame1 = true
local beforeForeverEditModePoint = {ChatFrame1:GetPoint(1)}
addon.Canvas:EnableFreeDragging()
assert(addon.db.savedWorkspacePositions.ChatFrame1 == nil
        and addon.db.savedMainPositions.ChatFrame1 == nil
        and addon.db.openWorkspacePanels.ChatFrame1 == nil,
    "Forever Edit Mode chat must relinquish historical Offhand persistence")
addon.HUD:AlignChatFrame(metrics)
assert(select(1, ChatFrame1:GetPoint(1)) == beforeForeverEditModePoint[1]
        and select(4, ChatFrame1:GetPoint(1)) == beforeForeverEditModePoint[4]
        and select(5, ChatFrame1:GetPoint(1)) == beforeForeverEditModePoint[5],
    "Forever Edit Mode chat must remain entirely Blizzard-owned")

-- Respect customized Edit Mode positions and avoid mutations during combat.
ChatFrame1.IsInDefaultPosition = function() return false end
local _, _, _, customX = ChatFrame1:GetPoint(1)
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == customX)
InCombatLockdown = function() return true end
ChatFrame1.IsInDefaultPosition = function() return true end
addon.HUD:AlignChatFrame(metrics)
assert(select(4, ChatFrame1:GetPoint(1)) == customX, "Chat relocation must wait until combat ends")

-- 6. Retail owns the primary chat frame while it remains on Mainhand. Offhand
-- must neither replay a legacy coordinate nor resize it after Edit Mode exits.
InCombatLockdown = function() return false end
addon.isForever = false
ChatFrame1.isStaticDocked = true
ChatFrame1.isInEditMode = true
ChatFrame1.OnEditModeEnter = function(self) self.isInEditMode = true end
ChatFrame1.OnEditModeExit = function(self) self.isInEditMode = false end
EditModeManagerFrame = makeMockFrame("EditModeManagerFrame", 510, 248)
EditModeManagerFrame.shown = true
addon.Canvas:EnableFreeDragging()
assert(EditModeManagerFrame._OffhandRetailChatExitHooked == true,
    "Retail Edit Mode exit must be observed")

addon.db.savedWorkspacePositions.ChatFrame1 = nil
addon.db.savedMainPositions.ChatFrame1 = {point="TOPLEFT", x=1750, y=1000}
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 2300, 180)
ChatFrame1:SetSize(640, 260)
addon.HUD:AlignChatFrame(metrics)
assert(select(1, ChatFrame1:GetPoint(1)) == "BOTTOMLEFT"
    and select(4, ChatFrame1:GetPoint(1)) == 2300
    and select(5, ChatFrame1:GetPoint(1)) == 180,
    "Offhand must yield to Retail Edit Mode while the primary chat is on Mainhand")
assert(ChatFrame1:GetWidth() == 640 and ChatFrame1:GetHeight() == 260,
    "Offhand must preserve Retail Edit Mode chat dimensions")

ChatFrame1.isInEditMode = false
EditModeManagerFrame.shown = false
EditModeManagerFrame.scripts.OnHide(EditModeManagerFrame)
assert(addon.db.savedMainPositions.ChatFrame1 == nil
    and addon.db.savedWorkspacePositions.ChatFrame1 == nil,
    "Retail Mainhand placement must clear stale Offhand chat coordinates")
addon.HUD:AlignChatFrame(metrics)
assert(select(1, ChatFrame1:GetPoint(1)) == "BOTTOMLEFT"
    and select(4, ChatFrame1:GetPoint(1)) == 2300
    and select(5, ChatFrame1:GetPoint(1)) == 180,
    "Retail Edit Mode chat placement must survive save-and-exit")

-- A deliberate workspace placement remains Offhand-owned. Capture it only
-- after Edit Mode exits, then use Blizzard's button-layout helper so the
-- channel/menu controls follow the primary chat frame.
local buttonRepairs = 0
FCF_SetButtonSide = function(frame, side, forceUpdate)
    assert(frame == ChatFrame1 and side == "left" and forceUpdate == true)
    buttonRepairs = buttonRepairs + 1
end
ChatFrame1.buttonSide = "left"
ChatFrame1.isInEditMode = true
EditModeManagerFrame.shown = true
ChatFrame1:ClearAllPoints()
ChatFrame1:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 100, 300)
addon.HUD:AlignChatFrame(metrics)
assert(addon.db.savedWorkspacePositions.ChatFrame1 == nil,
    "Workspace chat placement must not be captured mid-Edit-Mode")
ChatFrame1.isInEditMode = false
EditModeManagerFrame.shown = false
EditModeManagerFrame.scripts.OnHide(EditModeManagerFrame)
assert(addon.db.savedWorkspacePositions.ChatFrame1 ~= nil,
    "Retail workspace chat placement must be captured after Edit Mode exits")
assert(select(1, ChatFrame1:GetPoint(1)) == "TOPLEFT"
    and select(4, ChatFrame1:GetPoint(1)) < metrics.deckWidth,
    "Retail workspace chat must remain in the workspace after Edit Mode exits")
assert(buttonRepairs > 0, "Blizzard's chat-button layout must be repaired after a workspace move")

print("PASS: ChatFrame1 workspace persistence and Retail Edit Mode ownership verified!")

