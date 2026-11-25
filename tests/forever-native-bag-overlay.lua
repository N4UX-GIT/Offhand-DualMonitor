-- Regression test: Forever native separate backpack (ContainerFrame1) must
-- clear WoW's user-placed flag after dragging so layout-local.txt never traps
-- ContainerFrame1 at FrameLevel: 1, and must heal stale FlatPanelBackgroundTemplate
-- (Bg) layering immediately out of combat without touching protected/combat frames.

local function LoadChunk(path, ...)
    local chunk, err = loadfile(path)
    assert(chunk, err)
    return chunk(...)
end

local inCombat = false
InCombatLockdown = function() return inCombat end
UnitAffectingCombat = function() return inCombat end
GetTime = function() return 100 end
C_Timer = { After = function(_, fn) fn() end }
UIParent = {
    GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 3000 end,
    GetHeight = function() return 1920 end,
}

local created = {}
CreateFrame = function(_, name, parent)
    local f = {
        name = name, parent = parent, points = {}, scripts = {},
        width = 100, height = 24, shown = false,
    }
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetFrameStrata() end
    function f:SetFrameLevel(lvl) self.level = lvl end
    function f:GetFrameLevel() return self.level or 1 end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(...) self.points = { { ... } } end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i or 1] or {}) end
    function f:SetScript(ev, fn) self.scripts[ev] = fn end
    created[#created + 1] = f
    return f
end

local function MakeBag(name, left, top, frameLevel, bgLevel, userPlaced, bgProtected)
    local bg = {
        level = bgLevel,
        protected = bgProtected == true,
        setLevelCalls = 0,
    }
    function bg:IsForbidden() return false end
    function bg:IsProtected() return self.protected end
    function bg:GetFrameLevel() return self.level end
    function bg:SetFrameLevel(lvl)
        self.setLevelCalls = self.setLevelCalls + 1
        self.level = lvl
    end

    local f = {
        name = name, left = left, top = top, width = 256, height = 256,
        shown = true, level = frameLevel, userPlaced = userPlaced == true,
        setUserPlacedCalls = {}, Bg = bg, points = {},
    }
    function f:GetName() return self.name end
    function f:IsShown() return self.shown end
    function f:IsForbidden() return false end
    function f:IsProtected() return false end
    function f:IsAnchoringRestricted() return false end
    function f:GetEffectiveScale() return 1 end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetLeft() return self.left end
    function f:GetTop() return self.top end
    function f:GetBottom() return self.top - self.height end
    function f:GetFrameLevel() return self.level end
    function f:IsUserPlaced() return self.userPlaced end
    function f:SetUserPlaced(flag)
        self.userPlaced = flag == true
        self.setUserPlacedCalls[#self.setUserPlacedCalls + 1] = self.userPlaced
    end
    function f:SetMovable() end
    function f:StartMoving() self.userPlaced = true end
    function f:StopMovingOrSizing() end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(_, _, _, x, y)
        self.left, self.top = x, y
        self.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", x, y } }
    end
    return f
end

local Offhand = {
    isForever = true,
    db = {
        enabled = true,
        persistentWorkspacePanels = true,
        keepBagToggleOpen = true,
        savedWorkspacePositions = {},
        savedMainPositions = {},
        openWorkspacePanels = {},
    },
    Viewport = {
        GetMetrics = function()
            return {
                isSpanned = true,
                screenWidth = 3000, screenHeight = 1920,
                workspaceLeft = 0, workspaceRight = 1080,
                workspaceBottom = 0, workspaceTop = 1920,
                workspaceWidth = 1080, workspaceHeight = 1920,
                gameLeft = 1080, gameRight = 3000,
                gameBottom = 0, gameTop = 1080,
            }
        end,
    },
    CanvasBackpackState = {
        RootNames = { "ContainerFrameCombinedBags", "ContainerFrame1" },
        UsesForeverSeparateBags = function() return true end,
    },
}

LoadChunk("Core/CanvasForeverBags.lua", "Offhand", Offhand)

local Canvas = { SetWorkspacePanelOpen = function() end }
Offhand.CanvasForeverBags.Install(Canvas, {
    WithWorkspace = function(m) return m end,
    CanManagePanelsFromAddon = function() return true end,
    IsBackpackRoot = function(name) return name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" end,
    IsSpannedLayoutActive = function() return true end,
    IsFrameOnWorkspace = function(frame)
        local cx = (frame:GetLeft() or 0) + (frame:GetWidth() or 0) / 2
        return cx >= 0 and cx <= 1080
    end,
    GetNativeBackpackWorkspacePosition = function() return Offhand.db.nativeBackpackWorkspacePosition end,
    IsNativeBackpackTrackedOpen = function() return Offhand.db.nativeBackpackWorkspaceOpen == true end,
    ClearNativeBackpackOpenState = function() Offhand.db.nativeBackpackWorkspaceOpen = nil end,
    ClearOtherBackpackRootState = function() end,
    SaveOpenWorkspacePanels = function() end,
    SaveForeverPanelOwnership = function() end,
    GetShownNativeBackpackRoot = function() return _G.ContainerFrame1 end,
    IsForeverProfessionsPanel = function() return false end,
})

-- 1. Stale layout-local.txt state (userPlaced=true, frameLevel=1, Bg level=12)
--    heals immediately out of combat, even when already at target coordinates.
local bag1 = MakeBag("ContainerFrame1", 400, 900, 1, 12, true, false)
_G.ContainerFrame1 = bag1
Offhand.db.savedWorkspacePositions.ContainerFrame1 = { x = 400, y = 900, canvasWidth = 1080, canvasHeight = 1920, canvasLeft = 0, canvasBottom = 0 }
assert(Canvas:RefreshForeverNativeBagPlacement(bag1) == true, "Refresh should succeed out of combat")
assert(bag1.userPlaced == false, "Stale userPlaced flag must be cleared out of combat")
assert(bag1.Bg.level == 1, "Stale Bg level above frame level must be lowered to match root frame level")
assert(bag1.Bg.setLevelCalls == 1, "Bg SetFrameLevel should run once to repair broken layering")

-- 2. Healthy layering (Bg level <= frameLevel, userPlaced=false) must be a no-op.
assert(Canvas:RefreshForeverNativeBagPlacement(bag1) == true)
assert(bag1.Bg.setLevelCalls == 1, "Healthy Bg must not be touched again")
assert(#bag1.setUserPlacedCalls == 1, "Clean userPlaced=false must not rewrite SetUserPlaced")

-- 3. Dragging via the Offhand grip clears StartMoving's userPlaced flag before restoring.
assert(Canvas:EnableForeverNativeBagProxy() == true, "Controller must initialize")
local controller = created[#created]
controller.scripts.OnUpdate(controller)
local handle = created[#created]
assert(handle and handle.scripts.OnDragStart and handle.scripts.OnDragStop, "Bag grip handle must be created on tick")
handle.scripts.OnDragStart()
assert(bag1.userPlaced == true, "StartMoving marks root userPlaced during drag")
bag1.left, bag1.top = 260, 820
handle.scripts.OnDragStop()
assert(bag1.userPlaced == false, "SaveForeverNativeBagRoot must clear userPlaced after drag")
assert(Offhand.db.savedWorkspacePositions.ContainerFrame1.x == 260, "Dragged Offhand X must be persisted")

-- 4. Protected Bg must never be mutated, even if its level is higher.
local protectedBag = MakeBag("ContainerFrame1", 300, 700, 1, 15, true, true)
_G.ContainerFrame1 = protectedBag
assert(Canvas:RefreshForeverNativeBagPlacement(protectedBag) == true)
assert(protectedBag.Bg.setLevelCalls == 0, "Protected Bg must never receive SetFrameLevel")
assert(protectedBag.userPlaced == false, "Non-forbidden root still clears userPlaced")

-- 5. Combat must never touch SetUserPlaced or Bg:SetFrameLevel.
local combatBag = MakeBag("ContainerFrame1", 100, 700, 1, 15, true, false)
_G.ContainerFrame1 = combatBag
inCombat = true
Canvas:RefreshForeverNativeBagPlacement(combatBag)
assert(combatBag.userPlaced == true, "Combat must never call SetUserPlaced")
assert(combatBag.Bg.setLevelCalls == 0, "Combat must never call Bg:SetFrameLevel")

print("forever-native-bag-overlay tests passed")
