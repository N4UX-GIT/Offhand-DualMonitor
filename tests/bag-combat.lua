local combat=true
local nativeCalls=0
InCombatLockdown=function() return combat end
CloseAllBags=function(arg) nativeCalls=nativeCalls+1; return arg, "native" end
local addon={db={enabled=true,persistentWorkspacePanels=true,
    savedWorkspacePositions={ContainerFrame1={x=20,y=30}}}}
ContainerFrame1={IsShown=function() return true end, GetName=function() return "ContainerFrame1" end,
    Hide=function() error("Workspace bag must not be hidden by persistence") end}
NUM_CONTAINER_FRAMES=1
assert(loadfile("Core/Canvas.lua"))("Offhand",addon)
local value,origin=CloseAllBags("combat")
assert(nativeCalls==1 and value=="combat" and origin=="native", "Combat lost native arguments/results")
combat=false
assert(CloseAllBags()==false and nativeCalls==1, "Workspace bag was not preserved outside combat")
addon.db.enabled=false
assert(CloseAllBags("disabled")=="disabled" and nativeCalls==2)
print("PASS: native bag closure in combat/disabled, workspace persistence outside combat")

