-- Blizzard's empty EncounterBar remains shown without a visible preview.
local combat, gamepad, editMode, preview, content = false, false, true, false, false
local prompts, reloads, externalBars = 0, 0, true
local addon = {
    db={enabled=true}, isForever=true,
    HUDCompatibility={
        HasBlizzardEditMode=function() return true end,
        HasEllesmerePartyFrames=function() return false end,
        UsesControllerInterface=function() return gamepad end,
        UsesForeverEditMode=function() return true end,
        IsExternallyOwnedEditModeSystem=function(entry)
            return externalBars and entry.system == 123
        end,
    },
    ShowForeverPartyFrameRecoveryPrompt=function(_, name)
        prompts=prompts+1; assert(name=='EncounterBar')
    end,
}
UIParent={GetEffectiveScale=function() return 1 end}
InCombatLockdown=function() return combat end
EditModeManagerFrame={IsShown=function() return editMode end}
local x,y=200,1500
EncounterBar={
    IsShown=function() return true end,
    GetLeft=function() return x end, GetBottom=function() return y end,
    GetWidth=function() return preview and 230 or 1 end,
    GetHeight=function() return preview and 30 or 1 end,
    HasContentShowing=function() return content end,
    Selection={IsShown=function() return preview end},
    ClearAllPoints=function() error('protected native frame write') end,
    SetPoint=function() error('protected native frame write') end,
}
UIWidgetPowerBarContainerFrame={
    IsShown=function() return true end,
    GetLeft=function() return -9000 end, GetBottom=function() return -9000 end,
    GetWidth=function() return 1 end, GetHeight=function() return 1 end,
}
-- Borrowed action-bar previews precede EncounterBar in the recovery registry.
-- A replacement owner must not produce an unrepairable prompt or hide the
-- native EncounterBar candidate behind its stale preview bounds.
MainActionBar={system=123,systemIndex=1,
    IsShown=function() return true end,
    GetLeft=function() return -9000 end, GetBottom=function() return -9000 end,
    GetWidth=function() return 600 end, GetHeight=function() return 40 end,
}
local metrics={isSpanned=true,gameLeft=1920,gameBottom=0,gameRight=5760,gameTop=2160,
    workspaceLeft=0,workspaceBottom=0,workspaceRight=1920,workspaceTop=1080}
assert(loadfile('Core/HUDRecovery.lua'))('Offhand',addon)
local hud={}
addon.HUDRecovery.Install(hud)
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(not hud.foreverPartyFrameOutsideDisplays,
    'dormant EncounterBar/widget ownership roots must not request repair')
preview=true
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(hud.foreverPartyFrameOutsideDisplays=='EncounterBar' and prompts==0,
    'a genuine unreachable EncounterBar preview must remain detectable')
editMode=false
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(prompts==1,'offer the observed repair after Edit Mode closes')
addon.Mainhand={
    CreateOrUpdateEditModeLayout=function(_, options)
        assert(options.repairFrameName=='EncounterBar'); return true,'Offhand test',1
    end,
    PromptReload=function() reloads=reloads+1 end,
}
assert(hud:RepairProtectedHUDLayout() and reloads==1)
-- Simulate native reload application and fresh addon session state.
x,y=3000,1200
editMode=true
hud={}; addon.HUDRecovery.Install(hud)
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(not hud.foreverPartyFrameOutsideDisplays,
    'reachable EncounterBar must not be diagnosed through its widget child alias')
x,y=200,1500
preview,content=false,true
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(hud.foreverPartyFrameOutsideDisplays=='EncounterBar',
    'actual encounter content remains eligible without an Edit Mode highlight')
gamepad=true
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(not hud.foreverPartyFrameOutsideDisplays,'native Gamepad owner must retain the recovery exclusion')
gamepad,externalBars=true,false
hud:UpdateForeverPartyFrameRecovery(metrics)
gamepad,editMode=false,true
hud:UpdateForeverPartyFrameRecovery(metrics)
assert(hud.foreverPartyFrameOutsideDisplays=='MainActionBar',
    'a native action bar must remain eligible when no replacement owns it')
print('PASS: EncounterBar preview/content detection, dormant-root exclusion and reload lifecycle')
