local addon={db={theme='CLASSIC',trimColor='GOLD',canvasColor='CLASSIC_STONE',canvasAlpha=.8}}
local combat=false
InCombatLockdown=function()return combat end
assert(loadfile('UI/Themes.lua'))('Offhand',addon)
local themes=addon.Themes
local function Canvas()
 local f={}
 function f:SetBackdrop(v)self.backdrop=v end
 function f:SetBackdropColor(...)self.color={...}end
 function f:SetBackdropBorderColor(...)self.border={...}end
 function f:CreateTexture()return {SetAllPoints=function()end,SetColorTexture=function()end,Show=function()end}end
 return f
end
local a,b=Canvas(),Canvas();addon.canvases={a=a,b=b}
assert(themes:SetRegionTheme('b','PITCH_BLACK'))
assert(a.color[1]==.72 and b.color[1]==0 and a.color[4]==.8 and b.color[4]==.8)
assert(addon.db.theme=='CLASSIC' and addon.db.canvasColor=='CLASSIC_STONE','Region settings changed global appearance')
assert(themes:SetRegionTheme('a','GNOMISH_TINKER'));assert(a.color[3]==.64 and b.color[1]==0)
combat=true;assert(not themes:SetRegionTheme('b','OBSIDIAN'));assert(b.color[1]==0)
combat=false
assert(themes:SetRegionTheme('b',nil));assert(b.color[1]==.72)
addon.db.workspaceRegionThemes.b={theme='UNKNOWN',canvasAlpha=0/0,trimColor='UNKNOWN'}
local settings=themes:GetRegionSettings('b');assert(settings.theme=='CLASSIC' and settings.canvasAlpha==.8)
addon.canvases=nil;addon.canvas=a;OffhandCanvasFrame=a
themes:ApplyCanvasTheme(a)
assert(a.color[1]==.72,'Returning to a legacy canvas leaked a region appearance')
print('PASS: independent region canvases, inherited appearance, global isolation, combat refusal, malformed overrides and legacy fallback')
