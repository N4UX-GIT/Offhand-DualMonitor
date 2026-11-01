-- Native TBC bags share a group layout, so panel recovery must not move a
-- newly shown pooled container between the immediate and deferred bag passes.
local f=assert(io.open('tests/escape-and-bags.lua','rb'))
local source=f:read('*a'); f:close()
source=source:sub(1,assert(source:find('-- TEST 1:',1,true))-1)
source=source:gsub('local addon = {','local addon = { tocVersion=20506,',1)
local addon,flush=assert(loadstring(source..'\nreturn addon,flushTimers'))()
for _=1,8 do flush() end
addon.db.nativeBackpackWorkspacePosition={x=700,y=900}
addon.db.savedWorkspacePositions.ContainerFrame1={x=700,y=900}
addon.db.savedWorkspacePositions.ContainerFrame2=nil
local rescues=0
local original=addon.Canvas.RescuePanelFromVoid
addon.Canvas.RescuePanelFromVoid=function(self,frame,...)
    if frame==ContainerFrame2 then rescues=rescues+1 end
    return original(self,frame,...)
end
ContainerFrame1:Show()
for _=1,8 do flush() end
ContainerFrame2:Show()
local point=ContainerFrame2.points[1]
assert(point and point[1]=='BOTTOMRIGHT','equipped bag must be grouped immediately')
local x,y=point[4],point[5]
for _=1,8 do
    flush()
    point=ContainerFrame2.points[1]
    assert(point[1]=='BOTTOMRIGHT' and point[4]==x and point[5]==y,
        'deferred panel callbacks must not move the visible bag away from its group')
end
assert(rescues==0,'native TBC bags must not enter generic void recovery on show')
ContainerFrame2:Hide()
ContainerFrame2:Show()
for _=1,8 do flush() end
assert(rescues==0,'reopened pooled bags must retain bag layout ownership')
print('PASS: TBC bag show layout ownership')
