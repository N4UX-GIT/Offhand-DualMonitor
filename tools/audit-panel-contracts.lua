-- Offline audit of local Offhand code only. No Blizzard source is executed.
-- Exit 1 means a contract gap was detected; this is not a game-runtime test.
local findings = 0
local function finding(id, detail)
    findings = findings + 1
    print('DETECTED ' .. id .. ': ' .. detail)
end
local function env()
    local e = {}
    e._G = e
    return setmetatable(e, {__index=_G})
end
local function loadLocal(path, e, addon)
    local chunk = assert(loadfile(path))
    setfenv(chunk,e)
    chunk('Offhand',addon)
end

-- A: Real Classic NPC roots should never become standalone reload candidates
-- or be demodalized/evicted like independent menus.
do
    local e=env()
    local addon={tocVersion=20506,db={}}
    loadLocal('Core/CanvasPanelRegistry.lua',e,addon)
    addon.CanvasCompatibility={HasClassicUIForever=function() return false end}
    addon.CanvasBackpackState={IsRoot=function() return false end}
    addon.CanvasFrameState={IsEvicting=function() return false end}
    e.InCombatLockdown=function() return false end
    e.UIPanelWindows={}
    e.SetUIPanelAttribute=function() end
    loadLocal('Core/CanvasPanelLifecycle.lua',e,addon)
    local _,demodalize=addon.CanvasPanelLifecycle.InstallModality({}, {
        IsFrameOnWorkspace=function() return true end,
        CanManagePanelsFromAddon=function() return true end,
        RegisterSpecialFrame=function() end,UnregisterSpecialFrame=function() end})
    local gaps={}
    for _,name in ipairs({'AuctionFrame','PetStableFrame','TaxiFrame','GossipFrame','QuestFrame'}) do
        local frame={GetName=function() return name end}
        e[name]=frame
        e.UIPanelWindows[name]={area='left'}
        local eligible=addon.CanvasPanelRegistry.IsBasePersistentCandidate(name)
        demodalize(frame)
        if eligible and not e.UIPanelWindows[name] then gaps[#gaps+1]=name end
    end
    if #gaps>0 then finding('NPC-LIFECYCLE',table.concat(gaps,',') .. ' accepted for reload and registry deleted') end
end

-- B: Execute the actual installed close-policy wrapper against a bounded
-- model of the exact build's native slot-based close (cached area attributes).
do
    local e=env()
    local hidden,reopened=0,0
    local addon={tocVersion=20506,db={enabled=true,persistentWorkspacePanels=true,
        savedWorkspacePositions={WorldMapFrame={},SpellBookFrame={}}},
        Viewport={GetMetrics=function() return {isSpanned=true} end},
        CanvasCompatibility={ShouldYieldFrameToClassicUIForever=function() return false end},
        CanvasBackpackState={IsForeverContainerName=function() return false end},
        HasCustomBagAddon=function() return true end}
    loadLocal('Core/CanvasPanelRegistry.lua',e,addon)
    e.InCombatLockdown=function() return false end
    e.UISpecialFrames={}
    e.UIPanelWindows={WorldMapFrame={area='left'},SpellBookFrame={area='left'}}
    local slots={}
    for index,name in ipairs({'WorldMapFrame','SpellBookFrame'}) do
        local frame={shown=true,GetName=function() return name end}
        function frame:IsShown() return self.shown end
        function frame:Show() self.shown=true; reopened=reopened+1 end
        function frame:Hide() self.shown=false; hidden=hidden+1 end
        e[name]=frame
        slots[index]=frame
    end
    e.GetUIPanel=function(slot) return slots[slot=='left' and 1 or (slot=='center' and 2 or 0)] end
    e.HideUIPanel=function(frame) if frame then frame:Hide() end end
    e.CloseWindows=function()
        local closed=false
        for _,frame in ipairs(slots) do
            if frame:IsShown() then frame:Hide(); closed=true end
        end
        return closed
    end
    e.CloseAllWindows=function() return e.CloseWindows() end
    loadLocal('Core/CanvasPanelLifecycle.lua',e,addon)
    addon.CanvasPanelLifecycle.InstallClosePolicy({}, {IsFrameOnWorkspace=function() return true end})
    e.CloseAllWindows()
    if hidden>0 or reopened>0 then finding('ESCAPE-LIFECYCLE',hidden .. ' native hides followed by ' .. reopened .. ' direct shows') end
end

-- C: Use the exact local load method, without loading Canvas's unrelated UI.
do
    local file=assert(io.open('Core/Canvas.lua','rb'))
    local source=file:read('*a'); file:close()
    local method=assert(source:match('(function Canvas:RequestPersistentPanelLoad.-)\r?\nfunction Canvas:GetPersistentPanelLoadDiagnostics'))
    local e=env()
    local addon={tocVersion=20506,db={enabled=true,savedWorkspacePositions={MacroFrame={}},openWorkspacePanels={MacroFrame=true}}}
    loadLocal('Core/CanvasPanelRegistry.lua',e,addon)
    local requests=0
    e.Offhand=addon
    e.PanelRegistry=addon.CanvasPanelRegistry
    e.PanelRegistry.IsAddonLoaded=function() return false end
    e.PanelRegistry.LoadAddon=function() requests=requests+1; return true,true end
    e.CanManagePanelsFromAddon=function() return true end
    e.IsSpannedLayoutActive=function() return true end
    e.IsPersistentPanelLoadCandidate=function() return true end
    e.C_Timer={After=function() end}
    e.Canvas={InitializePanelLoadTracking=function(self) self.panelLoadRequests={} end,
        GetPersistentPanelAddon=function() return 'Blizzard_MacroUI' end}
    local chunk=assert(loadstring(method)); setfenv(chunk,e); chunk()
    local restored=e.Canvas:RequestPersistentPanelLoad('MacroFrame')
    if not restored and requests==0 then finding('TBC-LOAD-RESTORE','saved/open MacroFrame rejected before Blizzard_MacroUI load') end
    requests=0
    addon.isForever=true
    assert(e.Canvas:RequestPersistentPanelLoad('MacroFrame') and requests==1,'positive control for fixture failed')
end

-- D: Test ownership while the workspace policy is active, rather than only
-- testing whether an external change survives final cleanup.
do
    local e=env()
    local attrs={['UIPanelLayout-defined']=true,['UIPanelLayout-area']='left',
        ['UIPanelLayout-pushable']=0,['UIPanelLayout-allowOtherPanels']=0}
    local map={GetAttribute=function(_,key) return attrs[key] end}
    e.WorldMapFrame=map
    e.UIPanelWindows={WorldMapFrame={area='left',pushable=0,allowOtherPanels=0}}
    e.SetUIPanelAttribute=function(_,key,value) attrs['UIPanelLayout-'..key]=value end
    e.InCombatLockdown=function() return false end
    local addon={tocVersion=20506,db={enabled=true,savedWorkspacePositions={WorldMapFrame={}}},
        Viewport={GetMetrics=function() return {isSpanned=true} end}}
    loadLocal('Core/CanvasPanelLifecycle.lua',e,addon)
    local sync=addon.CanvasPanelLifecycle.UpdateTBCWorkspacePanelSlots
    sync()
    attrs['UIPanelLayout-pushable']=5 -- later native/addon writer
    sync()
    if attrs['UIPanelLayout-pushable']==1 then finding('ACTIVE-OWNERSHIP','workspace sync overwrote a later pushable=5 with 1') end
end
print('Audit findings: ' .. findings .. ' (offline source/model evidence only)')
os.exit(findings>0 and 1 or 0)
