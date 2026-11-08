-- Compare real website TOC output with the production Lua texture consumer.
local metadata={}
for line in io.lines(arg[1]) do
    local key,value=line:match('^## ([^:]+): (.-)\r?$')
    if key then metadata[key]=value end
end
C_AddOns={GetAddOnMetadata=function(_,key)return metadata[key]end,
    LoadAddOn=function()error('Media must remain code free')end}
local addon={db={userMediaEnabled=true,userMediaFitMode=arg[4]}}
local function Texture()
    local t={}
    function t:SetTexCoord(...)self.coords={...}end
    function t:SetSize(w,h)self.width,self.height=w,h end
    for _,key in ipairs({'SetTexture','SetVertexColor','SetColorTexture','SetAlpha','ClearAllPoints','SetAllPoints','SetPoint','Show','Hide'}) do t[key]=function()end end
    return t
end
local canvas={GetWidth=function()return tonumber(arg[2])end,GetHeight=function()return tonumber(arg[3])end,CreateTexture=Texture}
assert(loadfile('Core/UserMedia.lua'))('Offhand',addon)
addon:InitializeUserMedia();assert(addon.UserMedia:IsAvailable())
assert(addon.UserMedia:ApplyToCanvas(canvas))
local t=canvas.userMediaTexture
for _,v in ipairs(t.coords) do io.write(string.format('%.14f ',v)) end
io.write(string.format('%.14f %.14f\n',t.width or 0,t.height or 0))
