-- Original contract fixture by default. Optional argument: explicit installed
-- DaylightUI_Skins/MapMove.lua, executed only in this isolated Lua mock runtime.
-- No third-party source is included or copied into the test/package.
local addon = {isForever = true, db = {enabled = true,
    savedWorkspacePositions = {WorldMapFrame = {x = 1056, y = 540}}, savedMainPositions = {}}}
local combat, gamepad, external = false, false, nil
local metrics = {isSpanned = true}
InCombatLockdown = function() return combat end
UIParent = {GetEffectiveScale = function() return 1 end}
addon.Viewport = {GetMetrics = function() return metrics end}
addon.Canvas = {CanManagePanelsFromAddon = function() return not gamepad end}
addon.CanvasCompatibility = {GetWorldMapExternalOwner = function() return external end}
addon.CanvasPersistence = {IsPosition = function(p)
    return type(p) == "table" and tonumber(p.x) ~= nil and tonumber(p.y) ~= nil
end}
local function control(alpha, mouse)
    local f = {alpha = alpha or 1, mouse = mouse ~= false, writes = 0, shown = true}
    function f:GetAlpha() return self.alpha end
    function f:SetAlpha(value) assert(not combat); self.alpha = value; self.writes = self.writes + 1 end
    function f:IsMouseEnabled() return self.mouse end
    function f:EnableMouse(value) assert(not combat); self.mouse = value; self.writes = self.writes + 1 end
    function f:IsProtected() return self.protected end
    function f:IsForbidden() return false end
    function f:SetShown(value) self.shown = value end
    function f:Hide() self.shown = false end
    return f
end
local map = {scale = 1.86, spot = {1056, 540}, scaleWrites = 0, pointWrites = 0}
WorldMapFrame = map
function map:GetScale() return self.scale end
function map:GetEffectiveScale() return self.scale end
function map:SetScale(value) self.scale = value; self.scaleWrites = self.scaleWrites + 1 end
function map:ClearAllPoints() end
function map:SetPoint(_, _, _, x, y) self.spot = {x * self.scale, y * self.scale}; self.pointWrites = self.pointWrites + 1 end
function map:IsShown() return not self.hidden end
function map:IsMaximized() return self.big end
function map:IsProtected() return true end
function map:IsForbidden() return false end

local module = {db = {mapSpot = {19, 1141}, mapScale = 0.86, skin = true}, enabled = true, ns = {}}
DaylightUI = {GetModule = function(_, name) assert(name == "Skins"); return module end,
    Movers = {onResetAll = {}}, OpenMap = {Loaded = function() return external == "OpenMap" end},
    AfterCombat = function() end}
local mover, backing
if arg and arg[1] then
    -- The inspected public entry points suffice; Engine.Register is recorded
    -- without constructing frames, installing hooks or executing client code.
    module.ns.Engine = {Register = function() end}
    assert(loadfile(arg[1]))("DaylightUI_Skins", module.ns)
    mover = module.ns.MapMove
else
    mover = {}
    module.ns.MapMove = mover
    function mover.Scale() return math.max(0.6, math.min(1.4, backing and backing.mapScale or 1)) end
    function mover.Apply()
        if external == "OpenMap" or map.hidden or combat then return end
        mover.Slim()
        local scale = map.big and 1 or mover.Scale()
        if scale ~= map.scale then map:SetScale(scale) end
        mover.grip:SetShown(not map.big)
        local position = backing and backing.mapSpot
        if not map.big and position then map:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", position[1] / map.scale, position[2] / map.scale) end
    end
    function mover.Start(config) backing = config; mover.Apply() end
    function mover.Reset() backing.mapSpot = nil; backing.mapScale = nil; mover.Apply() end
end
local skinCalls = 0
mover.Slim = function() skinCalls = skinCalls + 1 end
mover.bar, mover.grip = control(0.7), control(0.8)
local originalSpot, config = module.db.mapSpot, module.db
mover.Start(config)
assert(map.scale == 0.86 and map.spot[1] == 19, "fixture must reproduce competing vendor placement")
local retainedApply = mover.Apply -- registered panel callbacks retain this identity
local nativeSetPoint, nativeSetScale = map.SetPoint, map.SetScale
local function offhandPlacement()
    map.scale, map.spot = 1.86, {1056, 540}
end
offhandPlacement()
assert(loadfile("Core/DaylightMapCompatibility.lua"))("Offhand", addon)
local adapter = addon.DaylightMapCompatibility
adapter:Refresh()
local wrappedStart, wrappedScale = mover.Start, mover.Scale
local sw, pw = map.scaleWrites, map.pointWrites
for i = 1, 6 do retainedApply(); adapter:Refresh() end
assert(map.scale == 1.86 and map.spot[1] == 1056 and map.spot[2] == 540,
    "retained panel callbacks must preserve Offhand scale and anchor synchronously")
assert(map.scaleWrites == sw and map.pointWrites == pw, "suppression must avoid transient native geometry writes")
assert(skinCalls > 6, "vendor map skin must continue to apply")
assert(module.db == config and config.mapSpot == originalSpot and config.mapScale == 0.86,
    "acquisition must never change or replace vendor SavedVariables")
assert(not mover.bar.mouse and not mover.grip.mouse and mover.grip.alpha == 0,
    "competing vendor drag/resize input and grip must be suppressed")
assert(adapter:GetDiagnostics() == "DaylightMap=Offhand")
assert(mover.Start == wrappedStart and mover.Scale == wrappedScale, "refresh must not multiply wrappers")
assert(map.SetPoint == nativeSetPoint and map.SetScale == nativeSetScale,
    "the adapter must not replace native map methods")

local function releaseAndCheck()
    adapter:Refresh()
    assert(map.scale == config.mapScale and map.spot[1] == config.mapSpot[1], "release must replay current vendor settings")
    assert(mover.bar.mouse and mover.grip.mouse and mover.grip.alpha == 0.8, "release must restore vendor controls")
    assert(module.db == config and config.mapSpot == originalSpot, "release must preserve saved-table identity")
end
addon.db.enabled = false; releaseAndCheck()
addon.db.enabled = true; offhandPlacement(); adapter:Refresh()
metrics.isSpanned = false; releaseAndCheck()
assert(adapter:ShouldPreserveSingleScreenPosition(map,metrics),
    "released Daylight anchor must remain owned during single-screen recovery")
assert(not adapter:ShouldPreserveSingleScreenPosition({},metrics), "another panel inherited map ownership")
local releasedSpot = module.db.mapSpot
module.db.mapSpot = {0/0,1141}
assert(not adapter:ShouldPreserveSingleScreenPosition(map,metrics), "invalid vendor coordinates bypassed recovery")
module.db.mapSpot = releasedSpot
module.enabled = false
assert(not adapter:ShouldPreserveSingleScreenPosition(map,metrics), "disabled vendor bypassed recovery")
module.enabled = true
metrics.isSpanned = true; offhandPlacement(); adapter:Refresh()
assert(not adapter:ShouldPreserveSingleScreenPosition(map,metrics), "spanned Offhand map yielded its saved placement")
gamepad = true; releaseAndCheck()
gamepad = false; offhandPlacement(); adapter:Refresh()
local saved = addon.db.savedWorkspacePositions.WorldMapFrame
addon.db.savedWorkspacePositions.WorldMapFrame = nil; releaseAndCheck()
addon.db.savedMainPositions.WorldMapFrame = saved; offhandPlacement(); adapter:Refresh()
retainedApply(); assert(map.scale == 1.86, "saved Mainhand geometry must also retain Offhand ownership")
addon.db.savedMainPositions.WorldMapFrame = nil
addon.db.savedWorkspacePositions.WorldMapFrame = saved

-- Release must also take effect inside a vendor callback, before any timer.
addon.db.enabled = false; retainedApply()
assert(map.scale == 0.86 and map.spot[1] == 19 and mover.grip.alpha == 0.8)
addon.db.enabled = true; offhandPlacement(); adapter:Refresh()

-- A profile change forwards a view of the new DB to the mover only.
local oldConfig = config
config = {mapSpot = {77, 222}, mapScale = 1.2, skin = false}
module.db = config; originalSpot = config.mapSpot
mover.Start(config); retainedApply()
assert(map.scale == 1.86 and map.spot[1] == 1056 and oldConfig.mapSpot[1] == 19)
addon.db.enabled = false; releaseAndCheck()
addon.db.enabled = true; offhandPlacement(); adapter:Refresh()
-- In-place edits made through settings remain the values restored later.
config.mapScale = 0.95; config.mapSpot = {333, 444}; originalSpot = config.mapSpot
retainedApply(); assert(map.scale == 1.86)
addon.db.enabled = false; releaseAndCheck()
addon.db.enabled = true; offhandPlacement(); adapter:Refresh()

-- Explicit vendor Reset writes through to the real DB; no parked snapshot
-- may resurrect settings the user deliberately removed.
mover.Reset()
assert(config.mapSpot == nil and config.mapScale == nil)
config.mapSpot, config.mapScale = {19, 1141}, 0.86; originalSpot = config.mapSpot

map.big = true; retainedApply()
assert(map.scale == 1 and mover.grip.shown == false and mover.bar.mouse,
    "maximized presentation must remain vendor/native-owned")
map.big = false; offhandPlacement(); adapter:Refresh(); retainedApply()
assert(map.scale == 1.86 and map.spot[1] == 1056)

-- Another map owner causes this adapter to stand down too.
external = "MoveAny"; releaseAndCheck()
external = nil; offhandPlacement(); adapter:Refresh()
external = "OpenMap"; adapter:Refresh()
assert(mover.bar.mouse and mover.grip.alpha == 0.8)
external = nil; offhandPlacement(); adapter:Refresh()

combat = true; addon.db.enabled = false
local writes = mover.grip.writes + mover.bar.writes
adapter:Refresh()
assert(mover.grip.writes + mover.bar.writes == writes, "control restoration must defer combat")
combat = false; releaseAndCheck()
combat = true; addon.db.enabled = true; offhandPlacement(); adapter:Refresh()
assert(adapter:GetDiagnostics() == "DaylightMap=DaylightUI", "new ownership must defer combat")
combat = false; adapter:Refresh(); retainedApply(); assert(map.scale == 1.86)

-- Intervening control properties belong to their latest writer.
mover.grip.alpha = 0.4; mover.bar.mouse = true
addon.db.enabled = false; adapter:Refresh()
assert(mover.grip.alpha == 0.4 and mover.bar.mouse == true)

-- Do not replace a later compatibility layer or run a disabled module.
addon.db.enabled = true; offhandPlacement(); adapter:Refresh()
local calls, publicApply = 0, mover.Apply
mover.Apply = function() calls = calls + 1; return publicApply() end
module.enabled = false; adapter:Refresh()
assert(calls == 0 and mover.grip.alpha == 0.4, "disabled vendor modules must not be replayed")
module.enabled = true; adapter:Refresh()
local newerScale = function() return 1.1 end
mover.Scale = newerScale; adapter:Refresh()
assert(mover.Scale == newerScale and adapter:GetDiagnostics() == "DaylightMap=DaylightUI",
    "another plugin's function replacement must be preserved")
mover.Scale = wrappedScale; offhandPlacement(); adapter:Refresh()

-- Late module readiness, missing vendors and unsupported public contracts.
DaylightUI = nil; adapter:Refresh(); assert(adapter:GetDiagnostics() == nil)
module.db = nil
DaylightUI = {GetModule = function() return module end}
adapter:Refresh(); assert(adapter:GetDiagnostics() ~= "DaylightMap=Offhand")
module.db = config
offhandPlacement()
adapter:Refresh(); retainedApply()
assert(map.scale == 1.86 and module.db == config,
    "late vendor configuration must acquire ownership without replacing its DB")
DaylightUI = {GetModule = function() return {ns = {MapMove = {}}, db = {}} end}
adapter:Refresh(); assert(adapter:GetDiagnostics() == nil)
DaylightUI = {GetModule = function() error("not ready") end}
adapter:Refresh(); assert(adapter:GetDiagnostics() == nil)
print("PASS: Daylight map ownership, synchronous suppression, saved settings, profiles, controls and release" .. (arg and arg[1] and " (installed vendor source)" or ""))
