-- Use the established frame harness and the real shared controls/callbacks.
dofile('tests/themes-and-canvas.lua')
local a=_G.Offhand
assert(loadfile('Core/WorkspaceScale.lua'))('Offhand',a)
assert(loadfile('UI/WorkspaceScaleControls.lua'))('Offhand',a)
local C,S=a.UIControls,a.WorkspaceScale
local factory=C.CreateFrame
local function Font(f)
    f.ClearAllPoints=function()end
    f.GetStringHeight=function(self)return math.ceil(#(self.text or '')*7/math.max(1,self.width or 600))*16 end
    return f
end
C.CreateFrame=function(...)
    local f=factory(...)
    local font=f.CreateFontString
    function f:CreateFontString(...)return Font(font(self,...))end
    local texture=f.CreateTexture
    function f:CreateTexture(...)
        local t=texture(self,...);t.ClearAllPoints=function()end
        t.Hide=function(self)self.hidden=true end;t.Show=function(self)self.hidden=false end;return t
    end
    function f:GetValue()return self.val end
    function f:SetScale(v)self.scale=v end
    function f:SetAlpha(v)self.alpha=v end
    function f:GetFontString()if not self.label then self.label=self:CreateFontString()end;self.label:SetText(self:GetText());return self.label end
    local set=f.SetValue
    function f:SetValue(v)set(self,v);if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v)end end
    return f
end
local m={isSpanned=true,companionTopology=true,workspaceScaleLayout='desktop',primaryWorkspaceRegion='a',
    screenWidth=3000,screenHeight=1200,gameLeft=1000,gameBottom=0,gameWidth=1000,gameHeight=1200,
    workspaceRegions={{id='a',x=0,y=0,width=1000,height=1200},{id='b',x=2000,y=0,width=1000,height=1200}},
    workspaceScaleGame={percent=200},workspaceScaleDisplays={a={percent=100},b={percent=150}}}
a.Viewport={GetMetrics=function()return m end};a.db={enabled=true,savedWorkspacePositions={}}
local layoutCalls=0
a.Canvas=nil;a.WorkspaceOptions=nil;a.ApplyFullLayout=function()layoutCalls=layoutCalls+1 end
InCombatLockdown=function()return false end
local parent=C.CreateFrame('Frame',nil,UIParent)
local nativeSlider=C.CreateNativeSlider
C.CreateNativeSlider=function(...)
    local slider=nativeSlider(...)
    function slider:GetValue()return self.val end
    local set=slider.SetValue
    function slider:SetValue(v)set(self,v);if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v)end end
    return slider
end
local function click(b)b.scripts.OnClick(b)end
local control=a.WorkspaceScaleControls:Build(parent,600);local c=control.controls
local getHeight=control.GetHeight
function control:GetHeight() return getHeight(self)-.0001 end
local resizeCalls=0
control.onResize=function()
    resizeCalls=resizeCalls+1
    assert(resizeCalls==1,'Calibration parent layout recursively resized the region control')
    control:Refresh()
end
assert(a.db.workspaceRegionScales==nil,'Opening calibration opted an existing user in')
click(c.auto);assert(a.db.workspaceRegionScales==nil and c.sample.scale==.5,'Preview changed persisted size')
assert(resizeCalls==1,'Wrapped Auto status did not reflow calibration')
control.onResize=nil
control.GetHeight=getHeight
click(c.cancel);assert(c.sample.scale==1 and a.db.workspaceRegionScales==nil)
click(c.chat.labelButton)
assert(layoutCalls==0 and a.db.workspaceRegionScales==nil,'A preview checkbox committed native layout work')
click(c.cancel)
click(c.auto);click(c.apply)
assert(S:GetMultiplier(m,'a')==.5 and S:GetMultiplier(m,'b')==1,'Apply leaked into another region')
click(c.picker);assert(c.sample.scale==1)
c.slider:SetValue(.8);assert(S:GetMultiplier(m,'b')==1,'Manual preview saved before Apply')
click(c.apply);assert(S:GetMultiplier(m,'b')==.8)
click(c.reset);assert(S:GetMultiplier(m,'b')==.8 and c.sample.scale==1)
click(c.cancel);assert(c.sample.scale==.8)
-- A second surface reconciles applied changes without invoking its setter.
local other=a.WorkspaceScaleControls:Build(parent,600)
assert(S:SetSetting(m,'a',.9));other:Refresh();assert(other.controls.sample.scale==.9)
-- Switching layout while a draft exists must discard that draft.
c.slider:SetValue(.7);m.workspaceScaleLayout='different';control:Refresh()
assert(c.sample.scale==1 and S:GetMultiplier(m,'b')==1)
m.isSpanned=false;control:Refresh();assert(c.apply.enabled==false and c.auto.enabled==false)
-- The same disclosure is used by the settings page and calibration.
m.isSpanned=true
m.workspaceScaleLayout='desktop'
local frames, createFrame={},C.CreateFrame
C.CreateFrame=function(...)
    local frame=createFrame(...)
    frames[#frames+1]=frame
    return frame
end
local advanced=a.WorkspaceScaleControls:BuildAdvanced(parent,600,true)
C.CreateFrame=createFrame
local toggle, editor
for _,child in ipairs(frames) do
    if child.parent==advanced then
        if child:GetText()==a.L.ADVANCED_SHOW then toggle=child end
        if child.controls and child.controls.apply then editor=child end
    end
end
assert(toggle and editor and not editor:IsShown(),'Sizing editor must start collapsed')
local collapsedHeight=advanced:GetHeight()
click(toggle)
assert(editor:IsShown() and advanced:GetHeight()>collapsedHeight and editor.controls.apply.enabled==false)
click(editor.controls.reset)
assert(editor.controls.apply.enabled==true and S:GetMultiplier(m,'a')==.9)
click(toggle)
click(toggle)
assert(editor.controls.sample.scale==.9 and editor.controls.apply.enabled==false,
    'Collapsing advanced sizing must discard its draft and preserve the saved size')
-- Expanded translated labels/status messages must reflow the same control.
m.isSpanned=true
for _,locale in ipairs({'enUS','deDE','frFR','itIT','esES','esMX','ptBR','ruRU','koKR','zhCN','zhTW'})do
    GetLocale=function()return locale end
    assert(loadfile('Locales/enUS.lua'))('Offhand',a)
    if locale~='enUS' then assert(loadfile('Locales/'..locale..'.lua'))('Offhand',a)end
    local widget=a.WorkspaceScaleControls:Build(parent,600)
    click(widget.controls.auto)
    assert(widget:GetHeight()>250 and widget.controls.apply:GetHeight()>=28,locale..': sizing controls did not reflow')
end
C.CreateFrame=factory
print('PASS: real shared calibration/settings callbacks, explicit Apply/cancel, independent regions, stale drafts and 11-locale reflow')
