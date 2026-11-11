local addon = {db = {savedWorkspacePositions = {MinimapCluster = {x = 5, y = 8}}, savedMainPositions = {}}}
local combat, loaded, forbidden, reads = false, true, false, 0
InCombatLockdown = function() return combat end
local secret = setmetatable({}, {__tostring = function() error("secret must not be formatted") end})
issecretvalue = function(value) return value == secret end
addon.HUDCompatibility = {IsAddonPresent = function(name)
    return name == "EllesmereUIOptions" or (name == "SexyMap" and loaded)
end}
local alpha, shown, visible = 1, true, false
local function noWrite() error("diagnostics must not mutate native or addon frames") end
local parent = {GetName = function() return "GameMenuFrame" end,
    IsShown = function() return false end, IsVisible = function() return false end}
MinimapCluster = {IsForbidden = function() return forbidden end,
    IsShown = function() reads = reads + 1; assert(not forbidden); return shown end,
    IsVisible = function() assert(not forbidden); return visible end,
    GetAlpha = function() assert(not forbidden); return alpha end,
    GetEffectiveAlpha = function() assert(not forbidden); return alpha end,
    GetEffectiveScale = function() assert(not forbidden); return 0.35 end,
    IsUserPlaced = function() assert(not forbidden); return true end,
    GetParent = function() assert(not forbidden); return parent end,
    Hide = noWrite, Show = noWrite, SetParent = noWrite, SetAlpha = noWrite,
    SetPoint = noWrite, HookScript = noWrite, SetScript = noWrite}
Minimap = MinimapCluster
UISpecialFrames = {secret, "MinimapCluster"}
assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
local function snapshot() return table.concat(addon.HUDRecovery.GetMinimapVisibilityDiagnostics(), "\n") end
local report = snapshot()
assert(report:find("SexyMap:yes", 1, true))
assert(report:find("EllesmereOptions:yes",1,true), "Options diagnostics must use the actual addon folder name")
assert(report:find("shown:yes,visible:no", 1, true))
assert(report:find("parent:GameMenuFrame,parentShown:no,parentVisible:no", 1, true))
assert(report:find("savedWorkspace:yes,savedMainhand:no,escapeRegistered:yes", 1, true))
assert(report:find("Minimap.state", 1, true), "the visible map must be inspected separately from its container")
local queueWidth = 45
QueueStatusButton = {
    IsShown = function() return true end, IsVisible = function() return true end,
    GetParent = function() return Minimap end,
    GetRect = function() reads = reads + 1; return 1350, 1200, queueWidth, 45 end,
    Hide = noWrite, Show = noWrite, SetPoint = noWrite,
}
local queueReport = snapshot():match("QueueStatusButton%.state=[^\n]+")
assert(queueReport and queueReport:find("shown:yes,visible:yes", 1, true)
    and queueReport:find("rectLocal:1350.000/1200.000/45.000/45.000", 1, true),
    "the queue button must report visibility and geometry independently of the minimap")
queueWidth = secret
assert(snapshot():match("QueueStatusButton%.state=[^\n]+"):find("rectLocal:unknown", 1, true),
    "secret queue geometry must remain unreadable in diagnostics")
EllesmereUI = {Lite={GetAddon=function(name,silent)
    assert(name=="EllesmereUIMinimap" and silent)
    return {db={profile={minimap={enabled=true}}}}
end},_unlockRegisteredElements={EBS_Minimap={}}}
assert(snapshot():find("EllesmereMover:registered,EllesmereProfileEnabled:yes",1,true))
EllesmereUI = nil
loaded, shown, visible = false, false, false
alpha = secret
report = snapshot()
assert(report:find("SexyMap:no", 1, true) and report:find("shown:no,visible:no,alpha:unknown", 1, true))
forbidden = true
report = snapshot()
assert(report:find("shown:unknown", 1, true), "forbidden roots must not be inspected")
combat = true
local before = reads
assert(snapshot() == "minimap=deferred:combat" and reads == before)
combat, forbidden = false, false
Minimap, MinimapCluster = nil, nil
assert(snapshot():find("Minimap.state=absent", 1, true))
assert(addon.db.savedWorkspacePositions.MinimapCluster.x == 5, "saved settings must remain unchanged")
print("PASS: read-only minimap visibility, parent, alpha, ownership and secret/combat diagnostics")
