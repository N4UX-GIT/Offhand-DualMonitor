-- Separate UI sessions model saved character intent and vendor-owned startup.
local function Session(saved, options)
    options=options or {}
    local s={time=0,shown=false,workspace=options.workspace~=false,combat=false,
        opens=0,snapshots=0,gamepad=options.gamepad,menu=false,reserved=false}
    OffhandCharDB=saved or {}
    GetTime=function() return s.time end
    InCombatLockdown=function() return s.combat end
    UIParent={}
    UISpecialFrames={}
    GameMenuFrame={IsShown=function() return s.menu end}
    hooksecurefunc=function(owner,key,callback)
        local original=owner[key]
        owner[key]=function(...)
            local result=original(...); callback(...); return result
        end
    end
    local frame={cfg={},
        GetParent=function() return UIParent end,
        IsShown=function() return s.shown end,
        IsProtected=function() return options.protected end,
        IsForbidden=function() return options.forbidden end,
        ActualizarEstadoEscapeModal=function() end,
        MemorizarPosicion=function() end,
        SetPoint=function() error('reload must retain vendor-owned geometry') end,
        SetScript=function() error('reload must not replace native/vendor scripts') end,
    }
    if options.notReady then frame.cfg=nil end
    function frame:Show() s.shown=true; self:ActualizarEstadoEscapeModal() end
    function frame:Hide() s.shown=false; self:ActualizarEstadoEscapeModal() end
    function frame:CambiarVisibilidad()
        assert(self.cfg,'vendor must finish login before opening')
        if self:IsShown() then self:Hide()
        else s.opens=s.opens+1; self:Show() end
    end
    KerzosQuestLog=frame
    if options.absent then KerzosQuestLog=nil end
    local metrics={isSpanned=options.spanned~=false}
    local addon={isForever=true,db={enabled=true,persistentWorkspacePanels=true,
        restoreWorkspaceOnReload=options.reload~=false},
        MainhandCompatibility={IsNativeGamepadInterface=function() return s.gamepad end},
        Canvas={IsFrameOnWorkspace=function() return s.workspace end},
        Viewport={GetMetrics=function() return metrics end},
        IsBlizzardInputReserved=function() return s.reserved end,
        ForeverPersistence={SaveProfileSnapshot=function(_,increment)
            assert(increment); s.snapshots=s.snapshots+1
        end},
    }
    assert(loadfile('Core/CanvasKerzoQuestLog.lua'))('Offhand',addon)
    s.adapter,s.frame,s.addon,s.metrics=addon.CanvasKerzoQuestLog,frame,addon,metrics
    return s
end

local s=Session({})
s.adapter:Refresh() -- Hooks before vendor login, without recording initial hide.
s.frame:ActualizarEstadoEscapeModal()
s.adapter:BeginSession(); s.adapter:Refresh()
assert(s.opens==0,'a new character must not inherit another quest-log open state')
s.frame:Show()
assert(OffhandCharDB.kerzoQuestLogOpen==true and s.snapshots==1,
    'an intentional workspace open must persist in character state and Forever snapshot')
for i=1,10 do s.adapter:Refresh() end
assert(s.snapshots==1,'steady-state sampling must not rewrite the profile')
s.adapter:PauseForTransition()
s.frame:Hide()
assert(OffhandCharDB.kerzoQuestLogOpen==true,'teardown hide must not erase open intent')
local saved={kerzoQuestLogOpen=OffhandCharDB.kerzoQuestLogOpen}
s=Session(saved)
s.adapter:Refresh()
assert(OffhandCharDB.kerzoQuestLogOpen==true and s.opens==0,
    'initial hidden construction must not clear or consume saved intent')
s.adapter:BeginSession(); s.adapter:Refresh()
assert(s.shown and s.opens==1,'reload must reopen through the vendor opener')
for i=1,10 do s.adapter:Refresh() end
assert(s.opens==1,'startup restoration must happen only once')
s.frame:Hide()
assert(not OffhandCharDB.kerzoQuestLogOpen and s.snapshots==1,'explicit X/toggle close must clear persisted intent')
for i=1,10 do s.adapter:Refresh() end
assert(not s.shown and s.opens==1,'explicit close must not resurrect during the session')
s.adapter:PauseForTransition(); s.adapter:BeginSession(); s.adapter:Refresh()
assert(s.opens==1,'a zone transition must not rearm reload restoration')
s=Session({}); s.adapter:BeginSession(); s.adapter:Refresh()
assert(not s.shown,'a closed log must stay closed in the next UI session')

for _,option in ipairs({'reload','workspace','spanned'}) do
    s=Session({kerzoQuestLogOpen=true},{[option]=false})
    s.adapter:BeginSession(); s.adapter:Refresh()
    assert(s.opens==0,option..' must gate automatic opening')
    s.time=16; s.adapter:Refresh()
    s.workspace=true; s.metrics.isSpanned=true; s.addon.db.restoreWorkspaceOnReload=true
    s.adapter:Refresh()
    assert(s.opens==0,'a late layout/preference change must not resurrect an expired request')
end
for _,option in ipairs({'gamepad','protected','forbidden'}) do
    s=Session({kerzoQuestLogOpen=true},{[option]=true})
    s.adapter:BeginSession(); s.adapter:Refresh()
    assert(s.opens==0,option..' owner must not be opened')
end
for _,gate in ipairs({'combat','menu','reserved'}) do
    s=Session({kerzoQuestLogOpen=true}); s[gate]=true
    s.adapter:BeginSession(); s.adapter:Refresh()
    assert(s.opens==0,gate..' must defer restoration')
    s.time=3; s[gate]=false; s.adapter:Refresh()
    assert(s.opens==1 and s.shown,'eligible startup should resume after '..gate)
end
s=Session({kerzoQuestLogOpen=true},{notReady=true,absent=true})
s.adapter:BeginSession(); s.adapter:Refresh()
KerzosQuestLog=s.frame; s.adapter:Refresh()
assert(s.opens==0,'an XML root alone is not a ready vendor window')
s.frame.cfg={}; s.time=4; s.adapter:Refresh()
assert(s.opens==1,'late vendor initialization should restore within the startup deadline')
s.frame:Hide(); s.frame:Show(); s.workspace=false; s.frame:MemorizarPosicion()
assert(not OffhandCharDB.kerzoQuestLogOpen,'moving to Mainhand must clear workspace reload intent')
print('PASS: Kerzo character reload intent, vendor opener, explicit closure, teardown, startup limits and owner gates')
