local addon = {isForever=true, db={enabled=true, savedMainPositions={}, savedWorkspacePositions={}}}
local combat, writes = false, 0
InCombatLockdown = function() return combat end
local offsets = {LEFT_OFFSET=16, TOP_OFFSET=-116, RIGHT_OFFSET_BUFFER=80}
local layout = {CanChangeProtectedState=function() return true end}
GetUIPanelLayoutFrame = function() return layout end
GetUIPanelLayoutAttribute = function(name) return offsets[name] end
SetUIPanelLayoutAttribute = function(name, value)
    assert(not combat, "native defaults must be prepared before combat")
    writes = writes + 1
    offsets[name] = value
end
UIParent = {GetRight=function() return 3048 end, GetTop=function() return 1950 end,
    GetEffectiveScale=function() return 1 end, GetHeight=function() return 1950 end,
    GetWidth=function() return 3048 end}
local metrics = {isSpanned=true, gameLeft=1097, gameRight=3048, gameBottom=4, gameTop=1102,
    workspaceLeft=0, workspaceRight=1097, workspaceBottom=0, workspaceTop=1950}
addon.Viewport = {GetMetrics=function() return metrics end}
assert(loadfile("Core/CanvasPanelPlacement.lua"))("Offhand", addon)
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
local placement = addon.CanvasPanelPlacement

placement.RefreshNativeMainhandOrigin(metrics, true)
assert(offsets.LEFT_OFFSET == 1113 and offsets.TOP_OFFSET == -964 and offsets.RIGHT_OFFSET_BUFFER == 80)
local initialWrites = writes
placement.RefreshNativeMainhandOrigin(metrics, true)
assert(writes == initialWrites, "unchanged geometry should not rewrite native offsets")
combat = true
placement.RefreshNativeMainhandOrigin(metrics, false)
assert(writes == initialWrites)
combat = false
local leftMainhand = {isSpanned=true, gameLeft=0, gameRight=1700, gameTop=1950}
placement.RefreshNativeMainhandOrigin(leftMainhand, true)
assert(offsets.LEFT_OFFSET == 16 and offsets.TOP_OFFSET == -116 and offsets.RIGHT_OFFSET_BUFFER == 1428,
    "when Mainhand is on the left, native width checks must reserve the workspace")
local topMainhand = {isSpanned=true, gameLeft=0, gameRight=3048, gameTop=1950}
placement.RefreshNativeMainhandOrigin(topMainhand, true)
assert(offsets.LEFT_OFFSET == 16 and offsets.TOP_OFFSET == -116 and offsets.RIGHT_OFFSET_BUFFER == 80)
placement.RefreshNativeMainhandOrigin(metrics, true)
offsets.LEFT_OFFSET = 900
placement.RefreshNativeMainhandOrigin(metrics, true)
assert(offsets.LEFT_OFFSET == 900 and offsets.TOP_OFFSET == -116, "yield to a competing offset owner")
offsets.LEFT_OFFSET = 16
placement.RefreshNativeMainhandOrigin(metrics, true)
placement.RefreshNativeMainhandOrigin({isSpanned=false}, true)
assert(offsets.LEFT_OFFSET == 16 and offsets.TOP_OFFSET == -116 and offsets.RIGHT_OFFSET_BUFFER == 80)

addon.CanvasFrameState = {IsDragging=function() return false end}
addon.CanvasCompatibility = {HasPanelSlotRepairOwner=function() return false end, HasPanelManagementOwner=function() return false end}
addon.CanvasPanelRegistry = {
    GetPositionRoot=function(frame) return frame end,
    IsContextBoundPanel=function(name) return name == "MerchantFrame" end,
}
local slots = {}
GetUIPanel = function(slot) return slots[slot] end
local restores, defaultRepairs = 0, 0
local canvas = {
    CanManagePanelsFromAddon=function() return true end,
    GetPanelController=function() return "generic" end,
    RepairDefaultForeverSlots=function() defaultRepairs = defaultRepairs + 1 end,
}
placement.Install(canvas, {
    WithWorkspace=function(m) return m end,
    RestoreWorkspacePosition=function()
        assert(not combat, "must not run generic workspace restoration during combat")
        restores = restores + 1
    end,
    IsUnsafeForPanelMutation=function() return false end,
})
local social = {x=1113,y=986,moves=0}
SocialUIFrame = social
function social:GetName() return "SocialUIFrame" end
function social:IsShown() return true end
function social:IsForbidden() return false end
function social:IsProtected() return self.protected == true end
function social:CanChangeProtectedState() return not self.protected end
function social:IsAnchoringRestricted() return false end
function social:IsAnchoringSecret() return false end
function social:GetParent() return UIParent end
function social:GetLeft() return self.x end
function social:GetTop() return self.y end
function social:GetWidth() return self.width or 410 end
function social:GetHeight() return self.height or 675 end
function social:GetEffectiveScale() return 1 end
function social:ClearAllPoints() end
function social:SetPoint(_, _, _, x, y) self.x, self.y = x, y; self.moves = self.moves + 1 end
combat = true
canvas:RepairShownSocialCommunityPanels()
assert(social.moves == 0, "leave the unsaved native Mainhand position alone")
addon.db.savedMainPositions.SocialUIFrame = {x=1476,y=1055}
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 1476 and social.y == 1055 and social.moves == 1, "restore explicit Mainhand placement during combat")
canvas:RepairShownSocialCommunityPanels()
assert(social.moves == 1, "a matched anchor should avoid another SetPoint")
addon.db.savedWorkspacePositions.SocialUIFrame = {x=18,y=1500}
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 18 and social.y == 1500 and social.moves == 2, "honor an explicit Offhand placement")
do
    local map = setmetatable({x=260,y=1697,width=1000,height=534,moves=0}, {__index=social})
    WorldMapFrame = map
    function map:GetName() return "WorldMapFrame" end
    function map:IsMaximized() return self.maximized == true end
    addon.CanvasCompatibility.ShouldYieldWorldMap=function() return false end
    addon.CanvasCompatibility.IsAddonLoaded=function() return false end
    addon.db.keepMapToggleOpen=true
    addon.db.savedWorkspacePositions.WorldMapFrame={x=12,y=1800}
    assert(canvas:RepairCombatWorldMapAnchor(map) and map.x==12 and map.y==1800 and map.moves==1)
    map.protected=true; map.x=260
    assert(not canvas:RepairCombatWorldMapAnchor(map) and map.moves==1)
    map.protected=false;map.maximized=true
    assert(not canvas:RepairCombatWorldMapAnchor(map) and map.moves==1)
    WorldMapFrame=nil
    addon.db.savedWorkspacePositions.WorldMapFrame=nil
    addon.db.keepMapToggleOpen=nil
end
social.protected = true; social.x = 1113
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 1113 and social.moves == 2, "yield to combat protection")
social.protected = false
metrics.workspaceTop = 457
social.x, social.y = 530, 687
canvas:RepairShownSocialCommunityPanels()
assert(social.x >= metrics.gameLeft and social.y <= metrics.gameTop
    and social.y - social:GetHeight() >= metrics.gameBottom,
    "a native-size Social panel that exceeds Offhand stays reachable during combat")
local beforeSocialRestore = restores
combat = false
canvas:ReleaseCombatPanelClamps()
assert(restores == beforeSocialRestore + 1, "refit visible workspace Social immediately at combat exit")
restores, social.moves = beforeSocialRestore, 2
metrics.workspaceTop = 1950
combat = true
addon.db.savedWorkspacePositions.SocialUIFrame = nil
social.x, social.y = 1113, 986
local character = setmetatable({x=1617,y=986,width=631,height=484,moves=0}, {__index=social})
CharacterFrame = character
function character:GetName() return "CharacterFrame" end
slots.left, slots.center = social, character
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 1113 and social.moves == 2, "a saved Social anchor must not overlap a native peer")
combat = false
assert(canvas:ShouldDeferCombatSocialAnchor(social), "keep the current slot when combat ends with the peer still open")
slots.center = nil
assert(not canvas:ShouldDeferCombatSocialAnchor(social), "release the saved anchor once the peer is closed")

combat = true
slots.left = character
addon.db.savedWorkspacePositions.CharacterFrame = {x=46,y=1510,autoRoute=true}
canvas:RepairCombatWorkspaceSlots()
assert(character.moves == 0, "automatic routing is not an explicit Offhand placement")
addon.db.savedWorkspacePositions.CharacterFrame = {x=46,y=1510}
canvas:RepairCombatWorkspaceSlots()
assert(character.x == 46 and character.y == 1510 and character.moves == 1,
    "restore an unprotected Character panel reopened during combat")
character.x, character.protected = 1113, true
canvas:RepairCombatWorkspaceSlots()
assert(character.x == 1113 and character.moves == 1, "never write a protected slot's anchor during combat")
-- A fitted Character root can still cover Social and its tabs at their solo anchors.
assert(loadfile("Core/WorkspaceRegions.lua"))("Offhand", addon)
metrics.workspaceTop = 457
character.x, character.y, character.width, character.height = 91, 445, 565, 433
CharacterFrameModeTabs = {IsShown=function() return true end, GetWidth=function() return 57 end}
social.x, social.y, social.width, social.height = 530, 445, 263, 433
addon.db.savedWorkspacePositions.SocialUIFrame = {x=530,y=445}
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 721 and social.y == 445 and character.moves == 1,
    "place Social beside Character's tab strip without moving the protected peer")
assert(addon.db.savedWorkspacePositions.SocialUIFrame.x == 530, "keep the saved solo anchor")
metrics.workspaceTop = 1950
character.protected = false
MerchantFrame = character
function character:GetName() return "MerchantFrame" end
addon.db.savedWorkspacePositions.MerchantFrame = {x=46,y=1510}
canvas:RepairCombatWorkspaceSlots()
assert(character.moves == 1, "leave NPC-owned panels in native slots during combat")
local spellbook = setmetatable({protected=true,x=162,y=1623,width=577,height=720,
    insets={0,0,0,0},clamped=false}, {__index=social})
PlayerSpellsFrame = spellbook
UIPanelWindows = {PlayerSpellsFrame={area="left"}, MerchantFrame={area="left"}}
function spellbook:GetName() return "PlayerSpellsFrame" end
function spellbook:CanChangeProtectedState() return not combat end
function spellbook:GetClampRectInsets() return unpack(self.insets) end
function spellbook:IsClampedToScreen() return self.clamped end
function spellbook:SetClampRectInsets(...)
    assert(not combat, "protected frame clamp insets must be set before lockdown")
    self.insets = {...}
end
function spellbook:SetClampedToScreen(value)
    assert(not combat, "protected frame clamp flag must be set before lockdown")
    self.clamped = value
end

addon.db.savedWorkspacePositions.PlayerSpellsFrame = {x=162,y=1623}
canvas:PrepareCombatPanelClamps()
assert(not spellbook.clamped, "skip preparation if lockdown is already in effect")
combat = false
canvas:PrepareCombatPanelClamps()
assert(spellbook.clamped and spellbook.insets[1] == -162 and spellbook.insets[2] == 2309
    and spellbook.insets[3] == 327 and spellbook.insets[4] == -903,
    "constrain the protected Spellbook to its saved workspace rectangle")
canvas:PrepareCombatPanelClamps()
combat = true
canvas:ReleaseCombatPanelClamps()
assert(spellbook.clamped and restores == 0, "retain the saved clamp until lockdown ends")
combat = false
canvas:ReleaseCombatPanelClamps()
assert(not spellbook.clamped and spellbook.insets[1] == 0 and spellbook.insets[2] == 0 and restores == 1,
    "restore the native clamp and saved anchor after combat")

addon.db.savedWorkspacePositions.PlayerSpellsFrame = nil
spellbook.width = 1154
canvas:PrepareCombatPanelClamps()
assert(spellbook.clamped and spellbook.insets[1] == -1097 and spellbook.insets[2] == 0
    and spellbook.insets[3] == 848 and spellbook.insets[4] == -4,
    "constrain an expanded default Spellbook to Mainhand")
canvas:ReleaseCombatPanelClamps()
assert(not spellbook.clamped and defaultRepairs == 1)

addon.db.savedMainPositions.PlayerSpellsFrame = {x=1310,y=1000}
canvas:PrepareCombatPanelClamps()
canvas:ReleaseCombatPanelClamps()
assert(restores == 2 and defaultRepairs == 1, "restore an explicit Mainhand anchor after releasing combat bounds")

canvas:PrepareCombatPanelClamps()
spellbook.insets[1] = -500
canvas:ReleaseCombatPanelClamps()
assert(spellbook.clamped and spellbook.insets[1] == -500 and defaultRepairs == 1,
    "release ownership if an external controller has changed the bounds")
print("PASS: native Mainhand offsets, collision-free Social placement and protected combat bounds")

-- OneForAll moves the book by its body. Resizing subsequently re-shows the
-- panel and asks both addons to restore their saved positions.
assert(loadfile("Core/CanvasPanelMotion.lua"))("Offhand", addon)
local callbacks, timers, drops = {}, {}, 0
hooksecurefunc = function(_, method, fn) callbacks[method] = fn end
C_Timer = {After=function(_, fn) table.insert(timers, fn) end}
function spellbook:HookScript(event, fn) callbacks[event] = fn end
function spellbook:IsShown() return true end
function spellbook:StartMoving() end
function spellbook:StopMovingOrSizing() end
addon.CanvasCompatibility.IsForeverProfessionsPanel = function() return false end
local function unused() error("unexpected motion service") end
local hooks = addon.CanvasPanelMotion.Install(canvas, {
    RestoreSavedPositionAfterShow=unused, RestoreWorkspacePosition=function()
        local p = addon.db.savedWorkspacePositions.PlayerSpellsFrame or addon.db.savedMainPositions.PlayerSpellsFrame
        spellbook.x, spellbook.y = p.x, p.y
    end,
    IsUnsafeForPanelMutation=unused, CanManagePanelsFromAddon=function() return true end,
    OnPanelDragStop=function(f, alreadyStopped)
        assert(f == spellbook and alreadyStopped == true)
        drops = drops + 1
        addon.db.savedWorkspacePositions.PlayerSpellsFrame = nil
        addon.db.savedMainPositions.PlayerSpellsFrame = {x=f.x, y=f.y}
    end,
    HookPanelCloseButton=unused,
})
hooks.HookKnownPanelAnchorResets(spellbook, "PlayerSpellsFrame")
local saved = {x=87, y=1085}
addon.db.savedWorkspacePositions.PlayerSpellsFrame = saved
addon.db.savedMainPositions.PlayerSpellsFrame = nil
spellbook.x, spellbook.y = saved.x, saved.y
callbacks.StartMoving()
callbacks.StopMovingOrSizing()
assert(drops == 0, "clicking the parchment must not save a new position")
callbacks.StartMoving()
spellbook.x, spellbook.y = 1363, 806
callbacks.SetPoint(spellbook)
assert(#timers == 0, "anchor repairs must wait while the external mover owns the drag")
callbacks.StopMovingOrSizing()
callbacks.StopMovingOrSizing()
assert(drops == 1, "only the completed movement should transfer placement")
local function resize(width, anchorFirst)
    spellbook.width = width
    spellbook.x, spellbook.y = 1113, 980 -- native panel slot during re-show
    if anchorFirst then callbacks.SetPoint(spellbook) end
    callbacks.OnSizeChanged(spellbook)
    if not anchorFirst then callbacks.SetPoint(spellbook) end
    assert(#timers == 1)
    table.remove(timers)()
    assert(spellbook.x == 1363 and spellbook.y == 806, "restore the most recent Mainhand drop")
end
resize(1154, true)
resize(577, false)
callbacks.StartMoving()
callbacks.OnHide()
spellbook.x = 1500
callbacks.StopMovingOrSizing()
assert(drops == 1, "hiding the book cancels an unfinished move")
