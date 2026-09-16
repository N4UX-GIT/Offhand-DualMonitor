local addon={modules={},db={enabled=true,dockMap=true,preventMapCloseOnMove=true}}
local combat=false
local timers={}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
InCombatLockdown=function() return combat end
function addon:Print(_,err) error(err) end
local cvars={miniWorldMap="0"}
GetCVar=function(name) return cvars[name] end
SetCVar=function(name,value) cvars[name]=value end
UIParent={GetEffectiveScale=function() return 1 end}
addon.Viewport={GetMetrics=function() return {deckWidth=1097,screenHeight=1950} end}
local function object()
    local f={shown=true,width=610,height=438,scripts={},attrs={area="left"},moving=true}
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:GetEffectiveScale() return 1 end
    function f:IsShown() return self.shown end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false end
    function f:IsEventRegistered() return self.moving end
    function f:UnregisterEvent() self.moving=false end
    function f:RegisterEvent() self.moving=true end
    function f:Minimize() self.maximized=false end
    function f:IsMaximized() return self.maximized end
    function f:SetResizable() end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint() end
    function f:SetHeight(h) self.height=h end
    function f:GetFrameLevel() return 1 end
    function f:SetFrameLevel() end
    function f:EnableMouse() end
    function f:RegisterForDrag() end
    function f:SetNormalTexture() end
    function f:SetHighlightTexture() end
    function f:SetPushedTexture() end
    function f:SetScript(e,fn) self.scripts[e]=fn end
    function f:HookScript(e,fn) self.scripts[e]=fn end
    function f:SetResizeBounds() end
    function f:StartSizing() self.sizing=true end
    function f:StopMovingOrSizing() self.sizing=false end
    function f:OnFrameSizeChanged() self.refreshed=true end
    return f
end
CreateFrame=function() return object() end
hooksecurefunc=function() end
WorldMapFrame=object();WorldMapFrame.minimizedWidth=610;WorldMapFrame.minimizedHeight=438
UIPanelWindows={WorldMapFrame={area="left"},CharacterFrame={area="left"}}
SetUIPanelAttribute=function(f,k,v) f.attrs[k]=v end
local stack=WorldMapFrame
HideUIPanel=function(f) if stack==f then stack=nil end;f:Hide() end
ShowUIPanel=function(f)
    if f.attrs.area then if stack then stack:Hide() end;stack=f end
    f:Show()
end
assert(loadfile("Modules/MapDock.lua"))("Offhand",addon)
local map=addon.modules.MapDock
map:Initialize()
WorldMapFrame.maximized=true
WorldMapFrame.scripts.OnShow()
assert(WorldMapFrame.maximized,"map was reconfigured during OnShow")
for _,fn in ipairs(timers) do fn() end
timers={}
assert(not WorldMapFrame.maximized)
assert(WorldMapFrame:IsShown() and WorldMapFrame.attrs.area==nil and stack==nil)
local character=object();ShowUIPanel(character)
assert(WorldMapFrame:IsShown() and character:IsShown(),"opening character closed independent map")
assert(UIPanelWindows.CharacterFrame.area=="left")
assert(not WorldMapFrame.moving and cvars.miniWorldMap=="1")
map.grip.scripts.OnMouseDown(nil,"LeftButton")
WorldMapFrame:SetSize(800,600)
map.grip.scripts.OnMouseUp()
assert(addon.db.mapWindowSize.width==800 and addon.db.mapWindowSize.height==600)
WorldMapFrame:SetSize(610,438);map:Configure()
assert(WorldMapFrame:GetWidth()==800 and WorldMapFrame:GetHeight()==600)
combat=true;map.grip.scripts.OnMouseDown(nil,"LeftButton");assert(not WorldMapFrame.sizing)
combat=false;addon.db.dockMap=false;map:Configure()
assert(WorldMapFrame.attrs.area=="left" and not map.grip:IsShown())
assert(cvars.miniWorldMap=="0" and WorldMapFrame.moving)
print("PASS: map independent of character panel, saved resize, combat guard, restore")
