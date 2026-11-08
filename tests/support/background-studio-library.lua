local metadata={}
for line in io.lines(assert(arg[1])) do
    local key,value=line:match('^## ([^:]+):%s*(.-)%s*$')
    if key then metadata[key]=value end
end
C_AddOns={GetAddOnMetadata=function(_,key)return metadata[key]end,LoadAddOn=function()error('Media code executed')end}
local a={db={userMediaEnabled=false,userMediaFitMode='PACKAGE'}}
assert(loadfile('Core/UserMedia.lua'))('Offhand',a)
assert(loadfile('UI/Themes.lua'))('Offhand',a)
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
local function Texture()
    local t={}
    function t:SetTexture(v)self.path=v end
    function t:SetColorTexture(...)self.color={...}end
    function t:SetVertexColor()end
    function t:SetAlpha(v)self.alpha=v end
    function t:SetTexCoord(...)self.uv={...}end
    function t:ClearAllPoints()end
    function t:SetAllPoints(v)self.all=v end
    function t:SetPoint()end
    function t:SetSize(w,h)self.w=w;self.h=h end
    function t:Show()self.shown=true end
    function t:Hide()self.shown=false end
    return t
end
local function Canvas(w,h)
    local c={bgTexture=Texture()}
    function c:GetWidth()return w end
    function c:GetHeight()return h end
    function c:CreateTexture()return Texture()end
    function c:SetBackdrop()end
    function c:SetBackdropColor(...)self.backdrop={...}end
    return c
end
local x,y=Canvas(480,600),Canvas(960,240)
a.canvases={a=x,b=y}
a.WorkspaceRegions={IsCanvas=function(_,c)return c==x or c==y end}
a.UserMedia:Refresh()
assert(a.UserMedia:IsAvailable() and #a.UserMedia:GetAssets()==2)
assert(a.Themes:SetRegionMediaMode('a','IMAGE') and a.Themes:SetRegionMediaMode('b','IMAGE'))
assert(a.Themes:SetRegionMediaAsset('a','first') and a.Themes:SetRegionMediaAsset('b','second'))
assert(x.userMediaTexture.path:match('Background.tga$') and y.userMediaTexture.path:match('Background2.tga$'))
assert(x.userMediaTexture~=y.userMediaTexture and x.userMediaTexture.alpha==.8 and y.userMediaTexture.alpha==.6)
assert(y.userMediaTexture.w==120 and y.userMediaTexture.h==240,'Second asset recommendation was not used')
assert(a.Themes:SetRegionMediaFit('a','STRETCH'))
assert(x.userMediaTexture.all==x and y.userMediaTexture.w==120,'Region fit leaked')
local p=a.WorkspaceProfiles;p:List();assert(p:Create('Two images'));local _,id=p:List()
assert(a.Themes:SetRegionMediaAsset('b','missing'))
assert(not y.userMediaTexture.shown and y.backdrop[4]>.9 and x.userMediaTexture.shown)
assert(p:Activate('default'))
assert(a.db.workspaceRegionThemes.b.userMediaAssetID=='second','Profile lost image ID')
assert(p:Activate(id))
assert(a.db.workspaceRegionThemes.b.userMediaAssetID=='missing','Missing assignment was silently changed')
assert(loadfile('Core/WorkspaceProfiles.lua'))('Offhand',a)
assert(a.WorkspaceProfiles:Activate('default'))
a.Themes:ApplyCanvasTheme();assert(y.userMediaTexture.shown)
metadata['X-Offhand-Asset-2-ID']='first'
assert(not a.UserMedia:Refresh() and a.UserMedia.reason=='DUPLICATE_ID')
a.Themes:ApplyCanvasTheme();assert(not x.userMediaTexture.shown and not y.userMediaTexture.shown)
metadata['X-Offhand-Asset-2-ID']='second';metadata['X-Offhand-Asset-Count']='3'
assert(not a.UserMedia:Refresh() and a.UserMedia.reason=='ASSET_COUNT')
metadata['X-Offhand-Asset-Count']='2';metadata['X-Offhand-Asset-2-Texture-Width']='4096'
metadata['X-Offhand-Asset-2-Texture-Height']='4096'
assert(not a.UserMedia:Refresh() and a.UserMedia.reason=='PIXEL_BUDGET')
metadata['X-Offhand-Asset-2-Texture-Width']='128';metadata['X-Offhand-Asset-2-Texture-Height']='256'
assert(a.UserMedia:Refresh());a.Themes:ApplyCanvasTheme();assert(y.userMediaTexture.shown)
assert(a.db.userMediaEnabled==false,'Region choice changed global background preference')
print('PASS: producer TOC to Lua two-image routing, independent fit, named profiles, reload, missing-ID fallback and malformed metadata')
