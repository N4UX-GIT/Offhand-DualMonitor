-- Regression suite for synchronous panel anchor flicker defense, OneForAll
-- coexistence, LoD RegisterUIPanel first-open placement, and SeamRedirect
-- center-panel ownership handoff.

local hooks = {}
local function HookSecure(target, name, fn)
    if type(target) == "string" then
        fn = name
        name = target
        local orig = _G[name]
        assert(type(orig) == "function", "Cannot hook missing global: " .. tostring(name))
        _G[name] = function(...)
            local a, b, c = orig(...)
            fn(...)
            return a, b, c
        end
        return
    end
    local orig = target[name]
    assert(type(orig) == "function", "Cannot hook missing method: " .. tostring(name))
    target[name] = function(...)
        local a, b, c = orig(...)
        fn(...)
        return a, b, c
    end
end
hooksecurefunc = HookSecure

local combat = false
InCombatLockdown = function() return combat end
UnitAffectingCombat = function() return combat end
IsMouseButtonDown = function() return false end
RegisterStateDriver = function() return true end
UnregisterStateDriver = function() return true end

local timers = {}
C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { delay = delay, fn = fn }
    end,
    NewTicker = function()
        return { Cancel = function() end }
    end,
}
local function FlushTimers(maxDelay)
    local batch = timers
    timers = {}
    for _, item in ipairs(batch) do
        if maxDelay == nil or item.delay <= maxDelay then
            item.fn()
        else
            timers[#timers + 1] = item
        end
    end
end

UIParent = {
    width = 3048,
    height = 1950,
    scale = 1,
    GetWidth = function(self) return self.width end,
    GetHeight = function(self) return self.height end,
    GetEffectiveScale = function(self) return self.scale end,
    GetLeft = function() return 0 end,
    GetRight = function(self) return self.width end,
    GetTop = function(self) return self.height end,
    GetBottom = function() return 0 end,
    GetAttribute = function() return nil end,
    SetAttribute = function() end,
    GetChildren = function() return end,
}

local function MakeFrame(name, width, height)
    local f = {
        name = name,
        width = width or 500,
        height = height or 550,
        scale = 1,
        shown = false,
        movable = false,
        clamped = false,
        userPlaced = false,
        points = {},
        scripts = {},
        attributes = {},
        setPointLog = {},
        left = 1113,
        top = 985,
    }
    function f:GetName() return self.name end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetScale() return self.scale end
    function f:SetScale(s) self.scale = s end
    function f:GetEffectiveScale() return self.scale end
    function f:GetParent() return UIParent end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:IsForbidden() return false end
    function f:IsProtected() return self.protected == true end
    function f:CanChangeProtectedState() return not self.protected or not combat end
    function f:IsMovable() return self.movable end
    function f:SetMovable(v) self.movable = v and true or false end
    function f:IsClampedToScreen() return self.clamped end
    function f:SetClampedToScreen(v) self.clamped = v and true or false end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetUserPlaced(v) self.userPlaced = v and true or false end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:GetFrameLevel() return self.level or 10 end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetHeight(h) self.height = h end
    function f:SetWidth(w) self.width = w end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetLeft() return self.left end
    function f:GetRight() return self.left + self.width end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.top - self.height end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i] or {}) end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(point, rel, relPoint, x, y)
        self.points[1] = { point, rel, relPoint, x, y }
        if point == "TOPLEFT" and relPoint == "BOTTOMLEFT" then
            self.left = x or 0
            self.top = y or 0
        elseif point == "TOPLEFT" and relPoint == "TOPLEFT" then
            self.left = x or 0
            self.top = UIParent:GetHeight() + (y or 0)
        elseif point == "CENTER" then
            self.left = UIParent:GetWidth() / 2 + (x or 0) - self.width / 2
            self.top = UIParent:GetHeight() / 2 + (y or 0) + self.height / 2
        elseif point == "TOP" then
            self.left = UIParent:GetWidth() / 2 + (x or 0) - self.width / 2
            self.top = UIParent:GetHeight() + (y or 0)
        end
        self.setPointLog[#self.setPointLog + 1] = { point = point, x = self.left, y = self.top }
    end
    function f:HookScript(event, fn)
        self.scripts[event] = self.scripts[event] or {}
        table.insert(self.scripts[event], fn)
    end
    function f:SetScript(event, fn)
        self.scripts[event] = fn and { fn } or {}
    end
    function f:Fire(event, ...)
        for _, fn in ipairs(self.scripts[event] or {}) do fn(self, ...) end
    end
    function f:Show()
        self.shown = true
        self:Fire("OnShow")
    end
    function f:Hide()
        self.shown = false
        self:Fire("OnHide")
    end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    if name then _G[name] = f end
    return f
end

CreateFrame = function(_, name, _, _)
    return MakeFrame(name, 100, 32)
end

-- ============================================================================
-- PART 1: Forever guarded UIPanels vs OneForAll synchronous SetPoint defense,
-- body-drag adoption, solo ShowUIPanel repair, and LoD RegisterUIPanel open.
-- ============================================================================
do
    local metrics = {
        isSpanned = true,
        screenWidth = 3048, screenHeight = 1950,
        gameLeft = 1097, gameRight = 3048, gameBottom = 4, gameTop = 1102,
        gameWidth = 1951, gameHeight = 1098,
        workspaceLeft = 0, workspaceRight = 1097, workspaceBottom = 0, workspaceTop = 1950,
        workspaceWidth = 1097, workspaceHeight = 1950,
        deckWidth = 1097, deckHeight = 1950,
    }
    local addon = {
        isForever = true,
        tocVersion = 16001,
        modules = {},
        db = {
            enabled = true,
            persistentWorkspacePanels = true,
            independentWorkspacePanels = true,
            restoreWorkspaceOnReload = true,
            savedWorkspacePositions = {},
            savedMainPositions = {},
            openWorkspacePanels = {},
        },
        Viewport = { GetMetrics = function() return metrics end },
        HasBlizzardEditMode = function() return true end,
    }

    UISpecialFrames = {}
    UIPanelWindows = {
        AddonList = { area = "center", pushable = 0 },
        MerchantFrame = { area = "left", pushable = 0 },
        CharacterFrame = { area = "left", pushable = 3 },
        CommunitiesFrame = { area = "left", pushable = 1 },
    }
    local slots = {}
    GetUIPanel = function(slot) return slots[slot] end
    UpdateUIPanelPositions = function() end
    ShowUIPanel = function(frame)
        if not frame then return end
        local name = frame:GetName()
        local area = UIPanelWindows[name] and UIPanelWindows[name].area or "left"
        slots[area] = frame
        -- Blizzard sets default Mainhand top-left anchor while hidden, then shows.
        if area == "center" then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", UIParent, "TOP", 0, -965)
        else
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 1113, -965)
        end
        frame:Show()
    end
    HideUIPanel = function(frame)
        for k, v in pairs(slots) do if v == frame then slots[k] = nil end end
        frame:Hide()
    end
    RegisterUIPanel = function(frame)
        local name = frame and frame:GetName()
        if name then UIPanelWindows[name] = UIPanelWindows[name] or { area = "left", pushable = 1 } end
    end

    local addonList = MakeFrame("AddonList", 500, 550)
    local merchant = MakeFrame("MerchantFrame", 336, 444)
    local character = MakeFrame("CharacterFrame", 338, 424)
    local communities = MakeFrame("CommunitiesFrame", 814, 426)

    assert(loadfile("Core/PanelMotion.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
    dofile("tests/support/core-bridges.lua").Load(addon, { "Bridges/OneForAll/Data.lua" })
    assert(loadfile("Core/Canvas.lua"))("Offhand", addon)

    addon.db.savedMainPositions.AddonList = { x = 1716, y = 896 }
    addon.db.savedMainPositions.MerchantFrame = { x = 1633, y = 742 }
    addon.db.savedWorkspacePositions.CharacterFrame = {
        x = 120, y = 1600, canvasLeft = 0, canvasBottom = 0,
        canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
    }
    addon.db.savedMainPositions.CommunitiesFrame = { x = 1500, y = 920 }

    addon.Canvas:EnableFreeDragging()

    -- Simulate OneForAll loading AFTER Offhand and attaching its OnShow + After(0)
    -- + UpdateUIPanelPositions mover (QoL.lua:1717, 1865-1884) with stale Mainhand coords.
    local ofaSaved = {
        AddonList = { 1275, 1088 },
        MerchantFrame = { 1113, 985 },
        CharacterFrame = { 1113, 985 },
        CommunitiesFrame = { 1113, 985 },
    }
    local function AttachOneForAllMock(frame)
        local name = frame:GetName()
        frame.ofaMovable = true
        local function applyPos(self)
            local p = ofaSaved[name]
            if not p or (combat and self:IsProtected()) then return end
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
        end
        frame:HookScript("OnShow", function(self)
            applyPos(self)
            C_Timer.After(0, function() applyPos(self) end)
        end)
    end
    AttachOneForAllMock(addonList)
    AttachOneForAllMock(merchant)
    AttachOneForAllMock(character)
    AttachOneForAllMock(communities)

    -- 1A. AddonList: Frame 0 and Frame 1 must end at Offhand's saved position
    -- synchronously BEFORE render (never lingering at OneForAll's 1275, 1088).
    ShowUIPanel(addonList)
    assert(addonList:GetLeft() == 1716 and addonList:GetTop() == 896,
        string.format("AddonList Frame 0 must repair synchronously over OneForAll (got %.0f,%.0f)",
            addonList:GetLeft(), addonList:GetTop()))
    FlushTimers(0)
    assert(addonList:GetLeft() == 1716 and addonList:GetTop() == 896,
        string.format("AddonList Frame 1 must repair synchronously over OneForAll After(0) (got %.0f,%.0f)",
            addonList:GetLeft(), addonList:GetTop()))
    addonList:Hide()
    FlushTimers()

    -- 1B. MerchantFrame (solo open, no other panel closing!): must hold 1633, 742 on Frame 0 & 1.
    ShowUIPanel(merchant)
    assert(merchant:GetLeft() == 1633 and merchant:GetTop() == 742,
        string.format("MerchantFrame Frame 0 must repair synchronously over OneForAll (got %.0f,%.0f)",
            merchant:GetLeft(), merchant:GetTop()))
    FlushTimers(0)
    assert(merchant:GetLeft() == 1633 and merchant:GetTop() == 742,
        string.format("MerchantFrame Frame 1 must hold saved position on solo open (got %.0f,%.0f)",
            merchant:GetLeft(), merchant:GetTop()))

    -- 1C. CommunitiesFrame: synchronous SetPoint repair over native/OneForAll reset.
    ShowUIPanel(communities)
    assert(communities:GetLeft() == 1500 and communities:GetTop() == 920,
        "CommunitiesFrame must repair synchronously on Frame 0 instead of flickering 1 frame")
    FlushTimers()
    communities:Hide()

    -- 1D. External body drag via OneForAll (frame.ofaMoving = true):
    -- Offhand must yield during the drag and adopt the drop on StopMovingOrSizing.
    merchant.ofaMoving = true
    merchant:StartMoving()
    merchant:ClearAllPoints()
    merchant:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1820, 810)
    assert(merchant:GetLeft() == 1820 and merchant:GetTop() == 810,
        "SetPoint guard must yield while OneForAll is actively dragging the panel")
    merchant.ofaMoving = nil
    merchant:StopMovingOrSizing()
    assert(addon.db.savedMainPositions.MerchantFrame.x == 1820
        and addon.db.savedMainPositions.MerchantFrame.y == 810,
        "Offhand must adopt a completed external body drag")
    merchant:Hide()
    FlushTimers()

    -- 1E. Combat guard: no SetPoint mutations while InCombatLockdown() is true.
    ShowUIPanel(character)
    assert(character:GetLeft() == 120 and character:GetTop() == 1600,
        "CharacterFrame workspace restore failed before combat test")
    FlushTimers()
    combat = true
    local logCountBefore = #character.setPointLog
    character:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 1113, 985)
    assert(#character.setPointLog == logCountBefore + 1,
        "SetPoint guard must never rewrite anchors during combat lockdown")
    combat = false
    character:Hide()
    FlushTimers()

    -- 1F. LoD RegisterUIPanel first-open: Blizzard registers a LoD panel and immediately
    -- calls Show() in the same turn. Position must restore synchronously on Frame 0.
    local lodFrame = MakeFrame("EncounterJournal", 800, 500)
    addon.db.savedWorkspacePositions.EncounterJournal = {
        x = 90, y = 1700, canvasLeft = 0, canvasBottom = 0,
        canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
    }
    RegisterUIPanel(lodFrame)
    assert(not lodFrame:IsShown(), "RegisterUIPanel must not auto-open a panel synchronously")
    lodFrame:ClearAllPoints()
    lodFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 1113, -965)
    lodFrame:Show()
    assert(lodFrame:GetLeft() == 90 and lodFrame:GetTop() == 1700,
        string.format("LoD panel must restore saved position on its very first Frame 0 open (got %.0f,%.0f)",
            lodFrame:GetLeft(), lodFrame:GetTop()))
    lodFrame:Hide()
    FlushTimers()
end

-- ============================================================================
-- PART 2: Retail/Classic SeamRedirect vs Canvas center-panel ownership handoff
-- and Retail synchronous RequiresNativePanelRegistration SetPoint repair.
-- ============================================================================
do
    timers = {}
    local metrics = {
        isSpanned = true,
        screenWidth = 3840, screenHeight = 1080,
        gameLeft = 1920, gameRight = 3840, gameBottom = 0, gameTop = 1080,
        gameWidth = 1920, gameHeight = 1080,
        workspaceLeft = 0, workspaceRight = 1920, workspaceBottom = 0, workspaceTop = 1080,
        workspaceWidth = 1920, workspaceHeight = 1080,
        deckWidth = 1920, deckHeight = 1080,
    }
    UIParent.width, UIParent.height = 3840, 1080
    local addon = {
        isRetail = true,
        isForever = false,
        tocVersion = 120107,
        modules = {},
        db = {
            enabled = true,
            seamRedirect = true,
            persistentWorkspacePanels = true,
            independentWorkspacePanels = true,
            savedWorkspacePositions = {},
            savedMainPositions = {},
            openWorkspacePanels = {},
        },
        Viewport = { GetMetrics = function() return metrics end },
        HasBlizzardEditMode = function() return true end,
    }

    UISpecialFrames = {}
    UIPanelWindows = {
        AddonList = { area = "center", pushable = 0 },
        HelpFrame = { area = "center", pushable = 0 },
        MerchantFrame = { area = "left", pushable = 0 },
    }
    GetUIPanel = function() return nil end
    UpdateUIPanelPositions = function() end
    ShowUIPanel = function(frame)
        if frame then frame:Show() end
    end
    HideUIPanel = function(frame)
        if frame then frame:Hide() end
    end
    ToggleGameMenu = function() end
    RegisterUIPanel = function() end
    SetUIPanelAttribute = function(frame, k, v)
        if frame and frame.SetAttribute then frame:SetAttribute("UIPanelLayout-" .. k, v) end
    end

    local retailAddonList = MakeFrame("AddonList", 500, 550)
    local retailHelp = MakeFrame("HelpFrame", 600, 500)
    local retailMerchant = MakeFrame("MerchantFrame", 336, 444)

    assert(loadfile("Core/MenuPlacement.lua"))("Offhand", addon)
    assert(loadfile("Core/HUDCompatibility.lua"))("Offhand", addon)
    assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
    assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
    assert(loadfile("Core/HUDTransientFrames.lua"))("Offhand", addon)
    assert(loadfile("Core/SeamRedirect.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasFrameState.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelRegistry.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasForeverBags.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasForeverMap.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasChat.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasProfessions.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasMapPresentation.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelLifecycle.lua"))("Offhand", addon)
    assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
    dofile("tests/support/core-bridges.lua").Load(addon, { "Bridges/OneForAll/Data.lua" })
    assert(loadfile("Core/Canvas.lua"))("Offhand", addon)

    addon.Canvas:EnableFreeDragging()
    addon.SeamRedirect:HookFrames()

    -- 2A. Unsaved AddonList still centers on Mainhand via SeamRedirect.
    ShowUIPanel(retailAddonList)
    FlushTimers()
    assert(retailAddonList.points[1][1] == "CENTER",
        "unsaved AddonList must still be centered on Mainhand by SeamRedirect")
    retailAddonList:Hide()

    -- 2B. Once Canvas has a saved position for AddonList or an area=='center' panel,
    -- SeamRedirect must yield on Frame 0 and Frame 1 so there is zero ownership flicker.
    addon.db.savedWorkspacePositions.AddonList = {
        x = 240, y = 900, canvasLeft = 0, canvasBottom = 0,
        canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
    }
    addon.db.savedMainPositions.HelpFrame = { x = 2100, y = 960 }
    ShowUIPanel(retailAddonList)
    assert(retailAddonList.points[1][1] == "TOPLEFT"
        and retailAddonList:GetLeft() == 240 and retailAddonList:GetTop() == 900,
        "SeamRedirect must yield Frame 0 to Canvas when AddonList has a saved workspace position")
    FlushTimers()
    assert(retailAddonList.points[1][1] == "TOPLEFT"
        and retailAddonList:GetLeft() == 240 and retailAddonList:GetTop() == 900,
        "SeamRedirect After(0) must yield to Canvas when AddonList has a saved workspace position")
    retailAddonList:Hide()

    ShowUIPanel(retailHelp)
    assert(retailHelp.points[1][1] == "TOPLEFT"
        and retailHelp:GetLeft() == 2100 and retailHelp:GetTop() == 960,
        "SeamRedirect must yield Frame 0 to Canvas for saved Mainhand center panels")
    FlushTimers()
    assert(retailHelp.points[1][1] == "TOPLEFT"
        and retailHelp:GetLeft() == 2100 and retailHelp:GetTop() == 960,
        "SeamRedirect After(0) must yield to Canvas for saved Mainhand center panels")
    retailHelp:Hide()

    -- 2C. Retail interaction panel (MerchantFrame): synchronous SetPoint repair.
    addon.db.savedWorkspacePositions.MerchantFrame = {
        x = 310, y = 860, canvasLeft = 0, canvasBottom = 0,
        canvasWidth = metrics.workspaceWidth, canvasHeight = metrics.workspaceHeight,
    }
    ShowUIPanel(retailMerchant)
    retailMerchant:ClearAllPoints()
    retailMerchant:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    assert(retailMerchant:GetLeft() == 310 and retailMerchant:GetTop() == 860,
        "Retail MerchantFrame must repair Blizzard SetPoint resets synchronously before render")
    FlushTimers()
    assert(retailMerchant:GetLeft() == 310 and retailMerchant:GetTop() == 860)
end

print("PASS: synchronous SetPoint flicker defense, OneForAll coexistence, LoD first-open, and SeamRedirect handoff")
