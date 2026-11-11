-- Exercise native OnHide -> UpdateContainerFrameAnchors without a ToggleBag
-- posthook. Close buttons and native close-all paths can take this route.
local f=assert(io.open('tests/escape-and-bags.lua','rb'))
local source=f:read('*a'); f:close()
source=source:sub(1,assert(source:find('-- TEST 1:',1,true))-1)
source=source:gsub('local addon = {','local addon = { tocVersion=20506,',1)
local setup=[[
C_EditMode={} -- Anniversary exposes Edit Mode, bypassing the legacy replacement.
nativeAnchorCalls=0
function UpdateContainerFrameAnchors()
    nativeAnchorCalls=nativeAnchorCalls+1
    for _,frame in ipairs({ContainerFrame1,ContainerFrame2}) do
        if frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint('BOTTOMRIGHT',UIParent,'BOTTOMRIGHT',-16,70)
        end
    end
end
for _,frame in ipairs({ContainerFrame1,ContainerFrame2}) do
    frame:HookScript('OnHide',function() UpdateContainerFrameAnchors() end)
end
]]
local start=assert(source:find('-- Load Offhand files',1,true))
source=source:sub(1,start-1)..setup..source:sub(start)
local addon,flush=assert(loadstring(source..'\nreturn addon,flushTimers'))()
for _=1,8 do flush() end
addon.db.nativeBackpackWorkspacePosition={x=700,y=900}
addon.db.savedWorkspacePositions.ContainerFrame1={x=700,y=900}
local function IsGrouped(frame)
    local p=frame.points[1]
    return p and p[3]=='BOTTOMLEFT' and p[4]<1440
end
local function OpenBoth()
    ContainerFrame1:Show(); ContainerFrame2:Show()
    for _=1,8 do flush() end
    assert(IsGrouped(ContainerFrame1) and IsGrouped(ContainerFrame2))
end
OpenBoth()
local calls=nativeAnchorCalls
ContainerFrame2:Hide()
assert(nativeAnchorCalls==calls+1,'native close anchor pass must still execute')
assert(IsGrouped(ContainerFrame1),'close must correct native anchors before returning, without a timer')
OpenBoth()
ContainerFrame1:Hide()
assert(IsGrouped(ContainerFrame2),'closing the first pooled root must retain the surviving bag on Offhand')
ContainerFrame2:Hide()
for _=1,8 do flush() end
assert(not ContainerFrame1:IsShown() and not ContainerFrame2:IsShown(),'close-all must not reopen bags')
OpenBoth()
UpdateContainerFrameAnchors()
assert(IsGrouped(ContainerFrame1) and IsGrouped(ContainerFrame2),'native refresh must settle inline')
for _,name in ipairs({'Bagnon','Baganator'}) do
    _G[name]={}
    UpdateContainerFrameAnchors()
    assert(not IsGrouped(ContainerFrame1),name..' ownership must retain native anchors')
    _G[name]=nil
end
InCombatLockdown=function() return true end
UpdateContainerFrameAnchors()
assert(not IsGrouped(ContainerFrame1),'combat must skip direct bag mutations')
InCombatLockdown=function() return false end
addon.SeamRedirect:HookFrames()
local layouts=0
local layout=addon.SeamRedirect.LayoutBags
addon.SeamRedirect.LayoutBags=function(self,...)
    layouts=layouts+1
    return layout(self,...)
end
UpdateContainerFrameAnchors()
assert(layouts==1 and IsGrouped(ContainerFrame1),'reinitialization must not duplicate the native anchor hook')
addon.db.enabled=false
UpdateContainerFrameAnchors()
assert(not IsGrouped(ContainerFrame1),'disabled Offhand must leave native placement alone')
print('PASS: TBC native close/anchor layout correction')
