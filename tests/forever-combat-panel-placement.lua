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
addon.CanvasCompatibility = {HasMoveAny=function() return false end, HasClassicUIForever=function() return false end}
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
social.protected = true; social.x = 1113
canvas:RepairShownSocialCommunityPanels()
assert(social.x == 1113 and social.moves == 2, "yield to combat protection")
social.protected = false
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
