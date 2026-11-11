local addon={isRetail=true,db={enabled=true,seamRedirect=true},HUDCompatibility={UsesForeverEditMode=function() return false end}}
local combat,queue=false,{}
InCombatLockdown=function() return combat end
addon.RunOrQueueCombat=function(_,fn) queue[#queue+1]=fn end
local m={isSpanned=true,gameLeft=1950,gameRight=3900,gameBottom=0,gameTop=1097,hudScale=1}
addon.Viewport={GetMetrics=function() return m end}
UIParent={GetEffectiveScale=function() return 0.7 end}
local loader
CreateFrame=function()
    loader={RegisterEvent=function() end,SetScript=function(self,_,fn) self.onEvent=fn end}
    return loader
end
local hookCount=0
hooksecurefunc=function(name,fn)
    local native=_G[name];hookCount=hookCount+1
    _G[name]=function(...)
        local result=native(...);fn(...);return result
    end
end
local function Frame()
    local f={points={},shown=false,writes=0,scale=0.7}
    function f:IsShown() return self.shown end
    function f:IsForbidden() return self.forbidden end
    function f:IsProtected() return self.protected end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:GetEffectiveScale() return self.scale end
    function f:ClearAllPoints() self.points={};self.writes=self.writes+1 end
    function f:SetPoint(...) self.points[#self.points+1]={...} end
    function f:HookScript() error('must not hook restricted application ancestry') end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    return f
end
local app,invite=Frame(),Frame()
LFGListApplicationDialog,LFGListInviteDialog=app,invite
StaticPopup_SetUpPosition=function(dialog)
    if dialog~=app and dialog~=invite then
        dialog:ClearAllPoints();dialog:SetPoint('TOP',UIParent,'TOP',0,-135)
        return 'native-position'
    end
    invite:ClearAllPoints();invite:SetPoint('TOP',UIParent,'TOP',0,-135)
    if dialog==app then app:ClearAllPoints();app:SetPoint('TOP',invite,'BOTTOM',0,0) end
    return 'native-position'
end
StaticPopupSpecial_Show=function(dialog) StaticPopup_SetUpPosition(dialog);dialog:Show();return 'native-show' end
StaticPopupSpecial_Hide=function(dialog) dialog:Hide();return 'native-hide' end
StaticPopup_Hide=function() if StaticPopup1 then StaticPopup1:Hide() end;return 'native-ordinary-hide' end
assert(loadfile('Core/HUDTransientPolicy.lua'))('Offhand',addon)
assert(loadfile('Core/HUDTransientFrames.lua'))('Offhand',addon)
local function Points(frame,...)
    local desired={...}
    if #desired==#frame.points then
        local same=true
        for i,point in ipairs(desired) do
            for j=1,5 do if point[j]~=frame.points[i][j] then same=false end end
        end
        if same then return end
    end
    frame:ClearAllPoints();for _,point in ipairs(desired) do frame:SetPoint(unpack(point)) end
end
local hud={}
addon.HUDTransientFrames.Install(hud,{Points=Points,Anchor=function() error('must preserve native stack') end,Prepare=function() end})
hud:HookMainhandTransientFrames();hud:HookMainhandTransientFrames()
assert(hookCount==4,'external native transaction hooks must be idempotent')
assert(StaticPopupSpecial_Show(invite)=='native-show')
local point=invite.points[1]
assert(point[2]==UIParent and point[3]=='BOTTOMLEFT' and point[4]==2925 and point[5]==962)
assert(StaticPopupSpecial_Show(app)=='native-show')
assert(app.points[1][2]==invite,'simultaneous dialogs must retain their native stack relationship')
local writes=invite.writes
hud:PositionMainhandTransientFrames();assert(invite.writes==writes,'periodic recovery must not accumulate translation')
assert(StaticPopupSpecial_Hide(invite)=='native-hide')
assert(invite.points[1][3]=='BOTTOMLEFT' and app.shown,'hidden stack root must remain translated while a visible dialog depends on it')
StaticPopupSpecial_Hide(app)
assert(invite.points[1][3]=='TOP' and invite.points[1][5]==-135,'finished stack restores owned native anchor')
-- Reopening, native rebuilds, and a later scale change.
StaticPopupSpecial_Show(invite);invite.scale=1.4
hud:PositionMainhandTransientFrames()
point=invite.points[1]
assert(point[4]==1462.5 and point[5]==413.5,'frame scale conversion must preserve native local offsets')
addon.db.enabled=false;hud:PositionMainhandTransientFrames()
assert(invite.points[1][3]=='TOP')
addon.db.enabled=true;StaticPopupSpecial_Show(invite)
m.isSpanned=false;hud:PositionMainhandTransientFrames();assert(invite.points[1][3]=='TOP')
m.isSpanned=true;addon.db.seamRedirect=false;hud:PositionMainhandTransientFrames();assert(invite.points[1][3]=='TOP')
addon.db.seamRedirect=true
combat=true;StaticPopupSpecial_Show(invite)
hud:PositionMainhandTransientFrames();hud:PositionMainhandTransientFrames();assert(#queue==1)
assert(invite.points[1][3]=='TOP','no combat writes')
combat=false;queue[1]();assert(invite.points[1][3]=='BOTTOMLEFT')
-- Other owners, protected ancestry and alternate top-level parents are untouched.
local other=Frame();invite.points={{'TOP',other,'TOP',3,4}}
hud:PositionPremadeGroupDialogs();assert(invite.points[1][2]==other)
invite.points={{'TOP',UIParent,'TOP',0,-135}};invite.protected=true
hud:PositionPremadeGroupDialogs();assert(invite.points[1][3]=='TOP')
invite.protected=false;invite.forbidden=true
hud:PositionPremadeGroupDialogs();assert(invite.points[1][3]=='TOP')
invite.forbidden=false;addon.isRetail=false
hud:PositionPremadeGroupDialogs();assert(invite.points[1][3]=='TOP')
-- Every added contextual confirmation uses the native transaction, without
-- hooks on secure-sensitive children or generic independent popup centering.
addon.isRetail=true;app.shown=false;invite.shown=false
for _,name in ipairs({'LFDRoleCheckPopup','LFGReadyCheckPopup','LFGInvitePopup','PVPReadyPopup','PetBattleQueueReadyFrame','RolePollPopup','LFGDungeonReadyPopup'}) do
    local frame=Frame();_G[name]=frame
    assert(StaticPopupSpecial_Show(frame)=='native-show')
    assert(frame.points[1][3]=='BOTTOMLEFT' and frame.points[1][4]==2925)
    hud:PositionMainhandTransientFrames()
    assert(frame.points[1][3]=='BOTTOMLEFT','generic transient placement must not overwrite the native stack policy')
    StaticPopupSpecial_Hide(frame);assert(frame.points[1][3]=='TOP')
end
-- Shared pool first, special child second, then hide in either order.
StaticPopup1=Frame();StaticPopup_SetUpPosition(StaticPopup1);StaticPopup1.shown=true
local child=LFDRoleCheckPopup
child.points={{'TOP',StaticPopup1,'BOTTOM',0,0}};child.shown=true
hud:PositionMainhandTransientFrames()
assert(StaticPopup1.points[1][3]=='BOTTOMLEFT' and child.points[1][2]==StaticPopup1)
assert(StaticPopup_Hide('TEST_DIALOG')=='native-ordinary-hide')
assert(StaticPopup1.points[1][3]=='BOTTOMLEFT','closing ordinary pool root must preserve visible special child')
StaticPopupSpecial_Hide(child);assert(StaticPopup1.points[1][3]=='TOP')
print('PASS: Premade Groups native popup stack, hidden dependencies, scaling, restore, combat and external ownership')
