-- ForeverXPbar data bridge (built into Offhand). Facts only: no frame, hook or timer.
-- ForeverXPbar owns its saved UIParent point, even when that point looks like a newly opened
-- popup or falls in a gap between displays, so automatic popup recovery leaves
-- ForeverXPBarMainFrame alone (frame rule preservePopup). The panel placement diagnostics report
-- the bar (frame rule diagnosticFrame) with the point ForeverXPBarDB saved (diagnostics slot
-- panelPlacement: ForeverXPBarSave=point/relPoint/x/y, or unavailable), read without writing.
-- Registered on every client, like the checks it replaces; the saved table is read when asked.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterAddonData) ~= "function" then return end

local BAR = "ForeverXPBarMainFrame"

local function IsPublic(value)
    return type(issecretvalue) ~= "function" or not issecretvalue(value)
end

local function IsPublicNumber(value)
    return IsPublic(value) and type(value) == "number" and value > -math.huge and value < math.huge
end

local function DescribeForeverXPBarSave()
    local db = _G.ForeverXPBarDB
    if type(db) ~= "table" then return "unavailable" end
    local point, relativePoint, x, y = db.point, db.relPoint, db.x, db.y
    if not IsPublic(point) or not IsPublic(relativePoint) or type(point) ~= "string"
        or type(relativePoint) ~= "string" or not IsPublicNumber(x) or not IsPublicNumber(y) then
        return "unavailable"
    end
    return string.format("%s/%s/%.1f/%.1f", point, relativePoint, x, y)
end

API.RegisterAddonData("ForeverXPBar", {
    frameRules = {
        preservePopup = { BAR },
        diagnosticFrame = { BAR },
    },
    diagnostics = {
        { slot = "panelPlacement", frame = BAR, label = "ForeverXPBarSave", value = DescribeForeverXPBarSave },
    },
})
