-- Lua 5.1 regression coverage for Retail full-screen frame confinement.
local addon = {
    isRetail = true,
    db = {enabled = true},
    RunOrQueueCombat = function(_, callback) callback() end,
}

local uiScale = 0.394
UIParent = {GetEffectiveScale = function() return uiScale end}
local metrics = {
    isSpanned = true,
    physicalHeight = 2560,
    gamePixelHeight = 1440,
    gameLeft = 1097,
    gameBottom = 4.57,
    gameRight = 3047,
    gameTop = 1101.57,
}
addon.Viewport = {
    GetMetrics = function() return metrics end,
    SetPoint = function(_, frame, point, relativePoint, x, y)
        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        frame:SetPoint(point, UIParent, relativePoint, x * factor, y * factor)
    end,
}

local combat = false
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, callback) callback() end}

local loader
CreateFrame = function()
    loader = {
        RegisterEvent = function() end,
        SetScript = function(self, _, callback) self.callback = callback end,
    }
    return loader
end

local function NewFrame()
    local frame = {scale = 0.64, points = {}, scripts = {}, shown = false}
    function frame:GetScale() return self.scale end
    function frame:SetScale(value) self.scale = value end
    function frame:GetEffectiveScale() return self.scale end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) self.points[#self.points + 1] = {...} end
    function frame:SetAllPoints(relativeTo)
        self.points = {
            {"TOPLEFT", relativeTo, "TOPLEFT", 0, 0},
            {"BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0},
        }
    end
    function frame:HookScript(name, callback) self.scripts[name] = callback end
    function frame:IsShown() return self.shown end
    frame:SetAllPoints(UIParent)
    return frame
end

PerksProgramFrame = NewFrame()
assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", addon)
assert(addon.RetailFullscreen.frame == PerksProgramFrame,
    "Trading Post frame was not attached")

PerksProgramFrame.shown = true
PerksProgramFrame.scripts.OnShow()
assert(addon.RetailFullscreen.modified, "Trading Post frame was not constrained")
assert(PerksProgramFrame:GetNumPoints() == 2, "Trading Post frame did not retain two anchors")
local expectedScale = 0.64 * 1440 / 2560
assert(math.abs(PerksProgramFrame:GetScale() - expectedScale) < 0.001,
    "Trading Post scale was not compensated for the taller spanned canvas")

local expectedFactor = uiScale / PerksProgramFrame:GetEffectiveScale()
local points = {}
for index = 1, PerksProgramFrame:GetNumPoints() do
    local point, relativeTo, relativePoint, x, y = PerksProgramFrame:GetPoint(index)
    points[point] = {relativeTo, relativePoint, x, y}
end
local bottomLeft, topRight = points.BOTTOMLEFT, points.TOPRIGHT
assert(bottomLeft and bottomLeft[1] == UIParent and bottomLeft[2] == "BOTTOMLEFT")
assert(topRight and topRight[1] == UIParent and topRight[2] == "BOTTOMLEFT")
assert(math.abs(bottomLeft[3] - metrics.gameLeft * expectedFactor) < 0.001)
assert(math.abs(bottomLeft[4] - metrics.gameBottom * expectedFactor) < 0.001)
assert(math.abs(topRight[3] - metrics.gameRight * expectedFactor) < 0.001)
assert(math.abs(topRight[4] - metrics.gameTop * expectedFactor) < 0.001)

-- A later Blizzard full-screen reset is repaired by the settling passes.
PerksProgramFrame:SetAllPoints(UIParent)
PerksProgramFrame:SetScale(0.64) -- Blizzard's DefaultScaleFrame layout pass.
addon.RetailFullscreen:Schedule()
assert(PerksProgramFrame:GetPoint(1) ~= "TOPLEFT",
    "Trading Post full-screen reset was not repaired")
assert(math.abs(PerksProgramFrame:GetScale() - expectedScale) < 0.001,
    "Blizzard Trading Post scale reset was not repaired")

-- Disabling Offhand restores Blizzard's original full-screen anchors.
addon.db.enabled = false
addon.RetailFullscreen:Apply()
assert(not addon.RetailFullscreen.modified, "native Trading Post anchors remained marked modified")
assert(PerksProgramFrame:GetNumPoints() == 2)
local firstPoint, firstRelative, firstRelativePoint = PerksProgramFrame:GetPoint(1)
assert(firstPoint == "TOPLEFT" and firstRelative == UIParent and firstRelativePoint == "TOPLEFT",
    "native Trading Post anchors were not restored")
assert(math.abs(PerksProgramFrame:GetScale() - 0.64) < 0.001,
    "native Trading Post scale was not restored")

-- Equal-height side-by-side displays retain Blizzard's native scale.
addon.db.enabled = true
metrics.physicalHeight = 1440
metrics.gamePixelHeight = 1440
addon.RetailFullscreen:Apply()
assert(math.abs(PerksProgramFrame:GetScale() - 0.64) < 0.001,
    "equal-height layout unnecessarily changed the Trading Post scale")

do
    metrics.physicalHeight, metrics.gamePixelHeight = 2560, 1440
    local frame = PerksProgramFrame
    local externalOwner = {}
    for _, change in ipairs({ "anchor", "scale", "both" }) do
        addon.db.enabled = true
        frame:SetAllPoints(UIParent)
        frame:SetScale(0.64)
        addon.RetailFullscreen:Apply()
        if change ~= "scale" then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", externalOwner, "CENTER", 40, 20)
        end
        if change ~= "anchor" then frame:SetScale(0.8) end
        addon.RetailFullscreen:Apply()
        if change ~= "scale" then
            assert(select(2, frame:GetPoint(1)) == externalOwner, "active placement overwrote external anchor")
        end
        if change ~= "anchor" then assert(frame:GetScale() == 0.8, "active placement overwrote external scale") end
        addon.db.enabled = false
        addon.RetailFullscreen:Apply()
        if change == "scale" then
            assert(frame:GetPoint(1) == "TOPLEFT", "still-owned anchors must restore independently")
        else
            assert(select(2, frame:GetPoint(1)) == externalOwner, "cleanup overwrote external anchor")
        end
        if change == "anchor" then
            assert(frame:GetScale() == 0.64, "still-owned scale must restore independently")
        else
            assert(frame:GetScale() == 0.8, "cleanup overwrote external scale")
        end
        addon.db.enabled = true
        addon.RetailFullscreen:Apply()
        if change ~= "scale" then assert(select(2, frame:GetPoint(1)) == externalOwner) end
        if change ~= "anchor" then assert(frame:GetScale() == 0.8, "re-enable reclaimed external scale") end
    end

    -- The combat callback resolves current intent instead of replaying an old
    -- Restore request after the player has already re-enabled the feature.
    frame:SetAllPoints(UIParent)
    frame:SetScale(0.64)
    addon.RetailFullscreen:Apply()
    local queue = {}
    addon.RunOrQueueCombat = function(_, callback) queue[#queue + 1] = callback end
    combat = true
    addon.db.enabled = false
    addon.RetailFullscreen:Apply()
    addon.RetailFullscreen:Apply()
    assert(#queue == 1, "Trading Post cleanup must coalesce in combat")
    addon.db.enabled = true
    combat = false
    queue[1]()
    assert(frame:GetPoint(1) == "BOTTOMLEFT" and addon.RetailFullscreen.modified,
        "stale combat cleanup ran after re-enable")
end

-- Non-Retail clients load the shared file but never attach or mutate the frame.
local classicAddon = {isRetail = false, db = {enabled = true}}
local classicFrame = NewFrame()
PerksProgramFrame = classicFrame
assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", classicAddon)
assert(classicAddon.RetailFullscreen.frame == nil, "non-Retail client attached the Trading Post handler")
assert(classicFrame:GetPoint(1) == "TOPLEFT", "non-Retail frame placement was mutated")

-- Forever & Retail full-screen Barbershop (TopLevelParentScaleFrameTemplate +
-- attached CharCustomizeFrame) must be confined to Mainhand without double-
-- scaling, reflow option spacing, and restore nil-parent anchors on disable.
do
    local function NewBarberFrame(parent, isTopLevelScale)
        local frame = NewFrame()
        frame.parent = parent
        frame.scale = isTopLevelScale and uiScale or 0.64
        if isTopLevelScale then
            frame.OnScaleFrameLoad = function() end
            frame.OnScaleFrameShow = function() end
        else
            frame.OnDefaultScaleFrameLoad = function() end
            frame.maxScale = 0.75
        end
        function frame:GetParent() return self.parent end
        function frame:GetEffectiveScale()
            if self.parent and self.parent.GetEffectiveScale then
                return self.scale * self.parent:GetEffectiveScale()
            end
            return self.scale
        end
        function frame:SetAllPoints(relativeTo)
            self.points = {
                {"TOPLEFT", relativeTo, "TOPLEFT", 0, 0},
                {"BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0},
            }
        end
        frame:SetAllPoints(parent)
        return frame
    end

    local function NewCustomizeFrame(barberFrame)
        local customize = NewFrame()
        customize.parent = barberFrame
        customize.scale = 1
        customize.Options = {}
        customize.layoutCount = 0
        function customize:GetParent() return self.parent end
        function customize:GetEffectiveScale()
            return self.scale * self.parent:GetEffectiveScale()
        end
        function customize:UpdateOptionsContainer()
            self.layoutCount = self.layoutCount + 1
        end
        -- Mirrors Blizzard_CharacterCustomize.xml: parent="UIParent" setAllPoints="true"
        -- before BarberShopMixin:OnLoad reparents it without changing anchors.
        customize:SetAllPoints(UIParent)
        return customize
    end

    metrics.physicalHeight, metrics.gamePixelHeight = 2560, 1440
    UIPanelWindows = {
        BarberShopFrame = { area = "full", pushable = 0 },
    }
    PerksProgramFrame = nil
    BarberShopFrame = nil
    CharCustomizeFrame = nil

    local foreverAddon = {
        isRetail = false,
        isForever = true,
        db = {enabled = true},
        Viewport = addon.Viewport,
        RunOrQueueCombat = function(_, callback) callback() end,
    }
    assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", foreverAddon)
    assert(foreverAddon.RetailFullscreen.entries.barbershop.frame == nil,
        "Barbershop should wait for load-on-demand Blizzard_BarbershopUI")

    -- Simulate Blizzard_BarbershopUI loading on BARBER_SHOP_OPEN.
    BarberShopFrame = NewBarberFrame(nil, true)
    CharCustomizeFrame = NewCustomizeFrame(BarberShopFrame)
    loader.callback(loader, "ADDON_LOADED", "Blizzard_BarbershopUI")
    assert(foreverAddon.RetailFullscreen.entries.barbershop.frame == BarberShopFrame,
        "Forever client failed to attach load-on-demand Barbershop frame")

    BarberShopFrame.shown = true
    CharCustomizeFrame.shown = true
    BarberShopFrame.scripts.OnShow()
    assert(foreverAddon.RetailFullscreen.entries.barbershop.modified,
        "Barbershop frame was not confined to Mainhand")
    assert(math.abs(BarberShopFrame:GetScale() - uiScale) < 0.001,
        "TopLevelParentScaleFrameTemplate Barbershop must not double-shrink scale")
    assert(BarberShopFrame:GetNumPoints() == 2, "Barbershop must keep opposing corner anchors")
    local bp1, br1, brp1, bx1, by1 = BarberShopFrame:GetPoint(1)
    local bp2, br2, brp2, bx2, by2 = BarberShopFrame:GetPoint(2)
    assert(bp1 == "BOTTOMLEFT" and br1 == UIParent and brp1 == "BOTTOMLEFT"
        and math.abs(bx1 - metrics.gameLeft) < 0.001 and math.abs(by1 - metrics.gameBottom) < 0.001,
        "Barbershop BOTTOMLEFT did not match Mainhand")
    assert(bp2 == "TOPRIGHT" and br2 == UIParent and brp2 == "BOTTOMLEFT"
        and math.abs(bx2 - metrics.gameRight) < 0.001 and math.abs(by2 - metrics.gameTop) < 0.001,
        "Barbershop TOPRIGHT did not match Mainhand")

    local cp1, cr1, crp1 = CharCustomizeFrame:GetPoint(1)
    local cp2, cr2, crp2 = CharCustomizeFrame:GetPoint(2)
    assert(cp1 == "TOPLEFT" and cr1 == BarberShopFrame and crp1 == "TOPLEFT"
        and cp2 == "BOTTOMRIGHT" and cr2 == BarberShopFrame and crp2 == "BOTTOMRIGHT",
        "CharCustomizeFrame was not anchored to confined BarberShopFrame")
    assert(CharCustomizeFrame.layoutCount == 1,
        "CharCustomizeFrame options spacing did not reflow after Mainhand confinement")

    -- Re-applying without anchor drift must not spam options reflow.
    foreverAddon.RetailFullscreen:Apply()
    assert(CharCustomizeFrame.layoutCount == 1,
        "steady-state Barbershop apply unnecessarily reflowed options")

    -- Disabling Offhand restores nil-relativeTo Barbershop points and UIParent
    -- CharCustomizeFrame points without truncating unpack at nil.
    foreverAddon.db.enabled = false
    foreverAddon.RetailFullscreen:Apply()
    assert(not foreverAddon.RetailFullscreen.entries.barbershop.modified,
        "Barbershop remained marked modified after disable")
    local r1p, r1rel, r1rp, r1x, r1y = BarberShopFrame:GetPoint(1)
    local r2p, r2rel, r2rp, r2x, r2y = BarberShopFrame:GetPoint(2)
    assert(r1p == "TOPLEFT" and r1rel == nil and r1rp == "TOPLEFT" and r1x == 0 and r1y == 0
        and r2p == "BOTTOMRIGHT" and r2rel == nil and r2rp == "BOTTOMRIGHT" and r2x == 0 and r2y == 0,
        "nil-parent Barbershop anchors were not restored intact")
    local cr1p, cr1rel = CharCustomizeFrame:GetPoint(1)
    assert(cr1p == "TOPLEFT" and cr1rel == UIParent,
        "CharCustomizeFrame native UIParent anchors were not restored")

    -- DefaultScaleFrame Barbershop variant (10.x) still applies height compensation.
    local retailBarber = NewBarberFrame(nil, false)
    BarberShopFrame = retailBarber
    CharCustomizeFrame = NewCustomizeFrame(retailBarber)
    local retailBarberAddon = {
        isRetail = true,
        db = {enabled = true},
        Viewport = addon.Viewport,
        RunOrQueueCombat = function(_, callback) callback() end,
    }
    assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", retailBarberAddon)
    retailBarber.shown = true
    CharCustomizeFrame.shown = true
    retailBarber.scripts.OnShow()
    assert(math.abs(retailBarber:GetScale() - (0.64 * 1440 / 2560)) < 0.001,
        "DefaultScaleFrame Barbershop variant was not height-compensated")

    -- Floating Classic-style BarberShopFrame (parent=UIParent, not area=full)
    -- must never be captured as a full-screen frame.
    UIPanelWindows = { BarberShopFrame = { area = "right", pushable = 0 } }
    local floatingBarber = NewBarberFrame(UIParent, true)
    BarberShopFrame = floatingBarber
    CharCustomizeFrame = nil
    local floatingAddon = {
        isRetail = false,
        isForever = true,
        db = {enabled = true},
        Viewport = addon.Viewport,
        RunOrQueueCombat = function(_, callback) callback() end,
    }
    assert(loadfile("Core/RetailFullscreen.lua"))("Offhand", floatingAddon)
    assert(floatingAddon.RetailFullscreen.entries.barbershop.frame == nil,
        "floating UIParent-anchored Barbershop frame was wrongly treated as fullscreen")
    UIPanelWindows = nil
    BarberShopFrame = nil
    CharCustomizeFrame = nil
end

-- Canvas placement and void rescue must ignore full-screen UIPanelWindows
-- takeover modes so BarberShopFrame is never collapsed to a single TOPLEFT point.
do
    local placementAddon = {
        isForever = true,
        db = { enabled = true, savedWorkspacePositions = {}, savedMainPositions = {}, openWorkspacePanels = {} },
        Viewport = { GetMetrics = function() return metrics end },
        CanvasPanelRegistry = {
            GetPositionRoot = function(f) return f end,
            IsBasePersistentCandidate = function() return true end,
            IsContextBoundPanel = function() return false end,
        },
        CanvasCompatibility = {
            IsForeverEllesmereBag = function() return false end,
            HasMoveAny = function() return false end,
            HasClassicUIForever = function() return false end,
            IsPersistentForeverProfessionsPanelName = function() return false end,
        },
        CanvasFrameState = { IsDragging = function() return false end },
        CanvasPersistence = {
            CharacterOpenSize = function(_, w, h) return w, h end,
            FitsWorkspace = function() return true end,
            ResolveWorkspacePosition = function() return 0, 0 end,
        },
    }
    assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", placementAddon)
    local fakeCanvas = { CanManagePanelsFromAddon = function() return true end }
    local barber = NewFrame()
    barber.shown = true
    function barber:GetName() return "BarberShopFrame" end
    function barber:GetParent() return nil end
    function barber:GetWidth() return 4000 end
    function barber:GetHeight() return 2560 end
    function barber:GetLeft() return 0 end
    function barber:GetTop() return 2560 end
    barber:SetAllPoints(nil)
    UIPanelWindows = { BarberShopFrame = { area = "full", pushable = 0 } }
    local function IsFullScreen(frame, name)
        return (name and UIPanelWindows[name] and UIPanelWindows[name].area == "full")
            or (name == "BarberShopFrame" and frame and frame:GetParent() ~= UIParent)
    end
    local services = {
        RemodalizePanel = function() end,
        ShouldYieldFrameToClassicUIForever = function() return false end,
        ShouldYieldWorldMapToMoveAny = function() return false end,
        IsForeverProfessionsPanel = function() return false end,
        IsForeverEditModeFrame = function() return false end,
        IsWorldMapMaximized = function() return false end,
        WithWorkspace = function(m) return m end,
        IsForeverSocialPositionRoot = function() return false end,
        IsUnsafeForPanelMutation = function() return false end,
        RegisterSpecialFrame = function() end,
        SaveOpenWorkspacePanels = function() end,
        SaveForeverPanelOwnership = function() end,
        IsBackpackRoot = function() return false end,
        ClearOtherBackpackRootState = function() return false end,
        IsFrameOnWorkspace = function() return false end,
        GetNonMovablePanels = function() return {} end,
        NonMovablePanels = {},
        IsFullScreenUIPanel = IsFullScreen,
    }
    placementAddon.CanvasPanelPlacement.InstallMainhand(fakeCanvas, services)
    placementAddon.CanvasPanelPlacement.InstallVoid(fakeCanvas, services)
    assert(not fakeCanvas:PlacePanelOnMainhand(barber, metrics, nil, true, true),
        "PlacePanelOnMainhand mutated full-screen BarberShopFrame")
    assert(not fakeCanvas:RescuePanelFromVoid(barber, metrics),
        "RescuePanelFromVoid mutated full-screen BarberShopFrame")
    assert(barber:GetNumPoints() == 2 and barber:GetPoint(1) == "TOPLEFT",
        "full-screen BarberShopFrame anchors were collapsed")
    UIPanelWindows = nil
end

print("PASS: Retail/Forever fullscreen Trading Post & Barbershop confinement, scale conversion, reset repair, native restore, Canvas exclusion, client isolation")
