-- The bag-provider decision must remain local through native close post-scan.
local addon = {db={enabled=true,persistentWorkspacePanels=true},isRetail=true,
    CanvasCompatibility={ShouldYieldFrameToClassicUIForever=function() return false end},
    CanvasBackpackState={IsForeverContainerName=function() return false end}}
local reads=0
addon.HasCustomBagAddon=function() reads=reads+1; return true end
local env={InCombatLockdown=function() return false end,UISpecialFrames={},UIPanelWindows={},
    NUM_CONTAINER_FRAMES=1,CloseAllWindows=function() return true end}
env._G=env
setmetatable(env,{__index=function(_,key)
    assert(key~='hasCustomBags','close policy must not read a global bag-provider decision')
    return _G[key]
end})
local chunk=assert(loadfile('Core/CanvasPanelLifecycle.lua'))
setfenv(chunk,env)
chunk('Offhand',addon)
addon.CanvasPanelLifecycle.InstallClosePolicy({}, {IsFrameOnWorkspace=function() return false end})
assert(env.CloseAllWindows()==true,'native close result must be retained')
assert(reads==1,'one stable bag-provider decision per close transaction')
print('PASS: legacy close policy retains local bag ownership through post-scan')
