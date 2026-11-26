-- Gathercraft bridge (built into Offhand).
-- Gathercraft makes one frame per gathering node for the world map, for every
-- zone it knows, each a child of UIParent (Pins.lua CreatePin, Route.lua GetDot
-- and MakeDot). HereBeDragons (Libs\HereBeDragons\HereBeDragons-Pins-2.0.lua)
-- only moves a pin under the map while that map shows it, and puts it back
-- under UIParent afterwards. With several thousand nodes UIParent ends up with
-- more children than one UIParent:GetChildren() call can return, and every pass
-- that walks UIParent's children fails with "stack overflow". This file moves
-- every pin Gathercraft hands to HereBeDragons for the world map under a holder
-- frame of its own, and back there whenever HereBeDragons returns it to
-- UIParent. Minimap pins are left alone: HereBeDragons keeps those under the
-- minimap once they have been near the player.
--
-- Gathercraft also opens its windows (Welcome.lua Card: welcome, what's new,
-- run summary; Planner.lua skill plan; PlanFarm.lua plan hints; UI.lua farm
-- panel and arrow; Main.lua main window) around the centre of UIParent, which
-- is the seam between monitors under Offhand. Each one still at Gathercraft's
-- own default spot is moved to the same spot of the game rectangle. A window
-- the player dragged (Gathercraft saves the panel, arrow and main window when
-- dragged) is left alone.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("Gathercraft") then return end

-- frame name -> { point, relativePoint, x, y }: Gathercraft's own default anchor on UIParent.
local fitter = Shared.NewAnchorFitter({
    GathercraftRunSummary = { "CENTER", "CENTER", 0, 120 },     -- Welcome.lua Card()
    GathercraftSkillPlan = { "CENTER", "CENTER", 0, 120 },      -- Planner.lua via ns.MakeCard (Card)
    GathercraftWelcome = { "CENTER", "CENTER", 0, 120 },        -- Welcome.lua Card()
    GathercraftWhatsNew = { "CENTER", "CENTER", 0, 120 },       -- Welcome.lua Card()
    GathercraftPlanHint = { "CENTER", "CENTER", 0, 140 },       -- PlanFarm.lua
    GathercraftPlanGathered = { "CENTER", "CENTER", 0, 140 },   -- PlanFarm.lua
    GathercraftPlanZones = { "CENTER", "CENTER", 0, 60 },       -- PlanFarm.lua
    GathercraftPanel = { "CENTER", "CENTER", 0, 200 },          -- UI.lua, saved when dragged
    GathercraftArrow = { "CENTER", "CENTER", 0, 300 },          -- UI.lua, saved when dragged
    GathercraftMain = { "CENTER", "CENTER", 0, 0 },             -- Main.lua, saved when dragged
})
local bridge = {}

-- ---------------------------------------------------------------------
-- World-map pins kept off UIParent
-- ---------------------------------------------------------------------

local OWNER = "Gathercraft"          -- Gathercraft's HereBeDragons refs all start with its name

local holder = Shared.NewParentHolder("OffhandGathercraftPins")
local hooked = false

local function mine(ref)
    return type(ref) == "string" and string.sub(ref, 1, #OWNER) == OWNER
end

local function start()
    local Pins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
    if type(Pins) ~= "table" then return end
    if not hooked then
        hooked = true
        local function added(_, ref, icon)
            if mine(ref) then pcall(holder.Adopt, holder, icon) end
        end
        if type(Pins.AddWorldMapIconMap) == "function" then hooksecurefunc(Pins, "AddWorldMapIconMap", added) end
        if type(Pins.AddWorldMapIconWorld) == "function" then hooksecurefunc(Pins, "AddWorldMapIconWorld", added) end
    end
    if type(Pins.worldmapPinRegistry) ~= "table" then return end
    for ref, icons in pairs(Pins.worldmapPinRegistry) do
        if mine(ref) and type(icons) == "table" then
            for icon in pairs(icons) do pcall(holder.Adopt, holder, icon) end
        end
    end
end

function bridge:Refresh(reason)
    fitter:Refresh()
    -- The registry sweep loops over every pin, too heavy for twice a second:
    -- once the hooks are in, only other refreshes sweep.
    if not hooked or reason ~= "tick" then pcall(start) end
end

function bridge:GetDiagnostics()
    return Shared.Describe("GathercraftAnchors", fitter) .. " GathercraftPins=" .. tostring(holder.taken)
end

if Shared.Register("Gathercraft", bridge) then bridge:Refresh("load") end
