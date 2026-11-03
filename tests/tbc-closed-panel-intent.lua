-- Reuse the shared Canvas fixture setup, stopping before its client-specific
-- assertions. Run real TBC Canvas hook installation and restore entry points.
local f=assert(io.open('tests/escape-and-bags.lua','rb'))
local source=f:read('*a'); f:close()
source=source:sub(1,assert(source:find('-- TEST 1:',1,true))-1)
source=source:gsub('local addon = {','local addon = { tocVersion=20506,',1)
local setup=[[
local function Toggle(frame)
    if frame:IsShown() then HideUIPanel(frame) else ShowUIPanel(frame) end
end
SpellBookFrame=makeMockFrame('SpellBookFrame',384,512)
MacroFrame=makeMockFrame('MacroFrame',384,512)
QuestLogFrame=makeMockFrame('QuestLogFrame',384,512)
for _,name in ipairs({'SpellBookFrame','MacroFrame','QuestLogFrame','ContainerFrame1','ContainerFrame2'}) do
    addon.db.savedWorkspacePositions[name]={x=40,y=700}
    UIPanelWindows[name]={area='left',pushable=0}
    _G[name]:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',40,700)
end
ToggleSpellBook=function() Toggle(SpellBookFrame) end
ToggleQuestLog=function() Toggle(QuestLogFrame) end
auditBagOpens=0
ToggleAllBags=function()
    auditBagOpens=auditBagOpens+1
    ContainerFrame1:Show(); ContainerFrame2:Show()
end
OpenAllBags=ToggleAllBags
CloseAllBags=function() ContainerFrame1:Hide(); ContainerFrame2:Hide() end
]]
local start=assert(source:find('-- Load Offhand files',1,true))
source=source:sub(1,start-1)..setup..source:sub(start)
local addon,flush,makeFrame,metrics=assert(loadstring(source..'\nreturn addon,flushTimers,makeMockFrame,metrics'))()
local canvas=addon.Canvas
local function Settle() for _=1,8 do flush() end end
Settle()
assert(not canvas._closeAllBagsEscapeHooked and not canvas._toggleGameMenuEscapeHooked,
    'TBC must not install the broad ToggleAllBags recovery path')
addon.db.nativeBackpackWorkspacePosition={x=40,y=700}
addon.db.nativeBackpackWorkspaceOpen=true -- reproduce the old stale marker
addon.db.openWorkspacePanels=addon.db.openWorkspacePanels or {}
ContainerFrame1:Hide(); ContainerFrame2:Hide()
CloseAllBags(); ToggleGameMenu(); Settle()
assert(auditBagOpens==0 and not ContainerFrame1:IsShown() and not ContainerFrame2:IsShown(),
    'Game Menu must not open any initially closed bag, even with stale backpack intent')
ContainerFrame1:Show()
CloseAllBags(); ToggleGameMenu(); Settle()
assert(ContainerFrame1:IsShown() and not ContainerFrame2:IsShown() and auditBagOpens==0,
    'visible workspace backpack must survive without opening independent bags')

WorldMapFrame:Show()
ToggleSpellBook(); Settle()
assert(addon.db.openWorkspacePanels.SpellBookFrame)
ToggleSpellBook(); Settle()
assert(not SpellBookFrame:IsShown() and not addon.db.openWorkspacePanels.SpellBookFrame)
local mapIntent=addon.db.openWorkspacePanels.WorldMapFrame
ToggleQuestLog(); Settle()
assert(QuestLogFrame:IsShown() and addon.db.openWorkspacePanels.QuestLogFrame)
ToggleQuestLog(); Settle()
assert(not QuestLogFrame:IsShown() and not addon.db.openWorkspacePanels.QuestLogFrame)
assert(addon.db.openWorkspacePanels.WorldMapFrame==mapIntent, 'L must not alter map open intent on TBC')
MacroFrame:Show(); Settle()
assert(addon.db.openWorkspacePanels.MacroFrame)
HideUIPanel(MacroFrame); Settle()
assert(not addon.db.openWorkspacePanels.MacroFrame, 'native X/HideUIPanel must clear stale reload intent')
MacroFrame:Show(); Settle()
addon.CanvasFrameState.SetEvicting(MacroFrame,true)
HideUIPanel(MacroFrame)
assert(addon.db.openWorkspacePanels.MacroFrame, 'synthetic slot eviction must not count as an explicit close')
addon.CanvasFrameState.SetEvicting(MacroFrame,false)
MacroFrame:Hide()
-- Reproduce stale flags from the older build for every known closed root.
for name in pairs(addon.db.savedWorkspacePositions) do
    local frame=_G[name]
    if frame and frame.Hide then frame:Hide() end
    addon.db.openWorkspacePanels[name]=true
end
local pos=addon.db.savedWorkspacePositions.MacroFrame
addon.CanvasPanelLifecycle.CaptureTBCPanelOpenState(canvas)
for name in pairs(addon.db.savedWorkspacePositions) do
    assert(not addon.db.openWorkspacePanels[name], 'closed transition snapshot must replace stale intent: '..name)
end
assert(addon.db.savedWorkspacePositions.MacroFrame==pos, 'closing must preserve geometry')
-- A closed pooled container may not exist by its old name in the next session.
addon.db.savedWorkspacePositions.ContainerFrame9={x=40,y=700}
addon.db.savedWorkspacePositions.ContainerFrame10={x=40,y=700}
addon.db.openWorkspacePanels.ContainerFrame9=true
addon.db.openWorkspacePanels.ContainerFrame10=false
addon.db.nativeBackpackWorkspaceOpen=true
canvas:RestorePersistentFrames(); Settle()
assert(auditBagOpens==0 and not MacroFrame:IsShown() and not SpellBookFrame:IsShown()
    and not QuestLogFrame:IsShown() and not WorldMapFrame:IsShown(), 'reload must not resurrect known closed roots')
MacroFrame:Show(); Settle()
MacroFrame.IsVisible=function() return false end -- UIParent hidden during teardown
addon.CanvasPanelLifecycle.CaptureTBCPanelOpenState(canvas)
assert(addon.db.openWorkspacePanels.MacroFrame, 'logical shown state must survive hidden-parent teardown')
MacroFrame:Hide()
metrics.isSpanned=false
addon.CanvasPanelLifecycle.CaptureTBCPanelOpenState(canvas)
assert(addon.db.openWorkspacePanels.MacroFrame, 'missing workspace recovery must preserve the saved snapshot')
metrics.isSpanned=true
addon.db.enabled=false
addon.CanvasPanelLifecycle.CaptureTBCPanelOpenState(canvas)
assert(addon.db.openWorkspacePanels.MacroFrame, 'disabled profile must remain inert')
print('PASS: TBC Game Menu does not open bags; key/X/transition closures survive reload')
