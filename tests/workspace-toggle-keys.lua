local addon = {isForever=true, db={enabled=true}, Canvas={}, Viewport={}}
local combat, spanned, controller, reserved = false, true, false, false
local overrides, native, vendor, observer, owner, driver, dispatched = {}, {}, {}, nil, nil, nil, {}
local keys = {TOGGLEWORLDMAP={"M", "CTRL-M"}, TOGGLEBACKPACK={"SHIFT-B"}, OPENALLBAGS={"B","PAD2"}}
for action, assigned in pairs(keys) do for _, key in ipairs(assigned) do native[key]=action end end
function GetBindingKey(action) return unpack(keys[action] or {}) end
function GetBindingAction(key, check) return check and (overrides[key] or vendor[key]) or native[key] end
function InCombatLockdown() return combat end
function addon.Canvas.CanManagePanelsFromAddon() return not controller end
function addon:IsBlizzardInputReserved() return reserved end
function addon.Viewport:GetMetrics() return {isSpanned=spanned} end
function addon.Canvas.IsFrameOnWorkspace(frame) return frame.workspace end
function CreateFrame(kind, name, _, template)
    local frame = {scripts={}}
    function frame:RegisterEvent() end
    function frame:SetScript(key, fn) self.scripts[key]=fn end
    function frame:SetAttribute(_, code) self.combatSnippet=code end
    if name then assert(template=="SecureHandlerStateTemplate");owner=frame else observer=frame end
    return frame
end
function ClearOverrideBindings(button)
    assert(button==owner and not combat)
    for key, action in pairs(overrides) do if action:match("^CLICK OffhandWorkspaceToggleKey:") then overrides[key]=nil end end
end
function SetOverrideBindingClick(button, priority, key, name, action)
    assert(not combat and button==owner and priority==true and action=="LeftButton")
    overrides[key]="CLICK "..name..":"..action
end
function RegisterStateDriver(button, state, spec)
    assert(button==owner and state=="combat" and spec=="[combat] combat; nocombat")
    driver=button.combatSnippet
end
local function root(id)
    return {shown=false,workspace=true,IsVisible=function(self) return self.shown end,
        GetID=function() return id end, IsForbidden=function() return false end,
        GetEffectiveScale=function() return 1 end,
        GetRect=function(self) return self.workspace and 1800 or 10,20,400,300 end}
end
WorldMapFrame,ContainerFrame1,ContainerFrame2,ContainerFrameCombinedBags=root(),root(0),root(1),root()
function RunBinding(action)
    dispatched[#dispatched+1]=action
    local f=action=="TOGGLEWORLDMAP" and WorldMapFrame or ContainerFrame1
    f.shown=not f.shown
end
local function press(key)
    local binding=GetBindingAction(key,true)
    if binding~="CLICK OffhandWorkspaceToggleKey:LeftButton" then RunBinding(binding) end
    if observer.scripts.OnUpdate then observer.scripts.OnUpdate(observer,0.06) end
end
assert(loadfile("Core/WorkspaceToggleKeys.lua"))("Offhand",addon)
local module=addon.WorkspaceToggleKeys
module:Refresh(); assert(not owner and not next(overrides))
addon.db.keepMapToggleOpen=true; module:Refresh()
assert(not overrides.M,"opening uses the original binding")
press("M"); press("CTRL-M")
assert(WorldMapFrame.shown and #dispatched==1 and not overrides.B, "closed map opens, second key preserves it")
WorldMapFrame.workspace=false; module:Refresh(); press("M"); assert(not WorldMapFrame.shown,"Mainhand toggle must close")
WorldMapFrame.workspace=true; WorldMapFrame.shown=true
WorldMapFrame.shown=false; module:Refresh(); press("M"); assert(WorldMapFrame.shown,"explicit close must allow the next open")
addon.db.keepBagToggleOpen=true; module:Refresh()
assert(not overrides.PAD2)
press("B"); press("B"); press("SHIFT-B"); assert(ContainerFrame1.shown,"both normal bag keys must preserve the workspace backpack")
ContainerFrame2.shown=true; ContainerFrame2.workspace=false; module:Refresh()
press("B"); assert(not ContainerFrame1.shown,"mixed-screen all-bags group must yield")
ContainerFrame2.shown=false; ContainerFrameCombinedBags.shown=true;module:Refresh()
local count=#dispatched; press("B");assert(#dispatched==count,"combined bag")
addon.HasCustomBagAddon=function() return true end
local bag=root(); bag.shown=true; addon.BagPersistence={frames={inventory=bag}};module:Refresh()
press("SHIFT-B");assert(#dispatched==count,"replacement inventory")
vendor.B="BETTERBAGS_TOGGLEBAGS"
addon.BagPersistence.betterBags={Bags={Backpack={frame=bag}}}
addon.db.keepBagToggleOpen=false;module:Refresh()
assert(GetBindingAction("B",true)=="BETTERBAGS_TOGGLEBAGS")
addon.db.keepBagToggleOpen=true;module:Refresh()
assert(overrides.B,"the reviewed BetterBags inventory toggle must be maskable")
bag.workspace=false;observer.scripts.OnUpdate(observer,0.06)
assert(GetBindingAction("B",true)=="BETTERBAGS_TOGGLEBAGS","dragging restores the original vendor override")
bag.workspace=true;vendor.B=nil;module:Refresh()
reserved=true; module:Refresh(); press("B"); assert(#dispatched==count+1); reserved=false
overrides.B="CLICK OtherAddon:Open";keys.TOGGLEWORLDMAP={"F8"};native.M=nil;native["F8"]="TOGGLEWORLDMAP"
observer.scripts.OnEvent()
assert(not overrides.M and overrides.F8 and overrides.B=="CLICK OtherAddon:Open","rebind and competing owner")
combat=true
assert(driver:find("self:ClearBindings()",1,true))
for key, action in pairs(overrides) do if action:find("OffhandWorkspaceToggleKey",1,true) then overrides[key]=nil end end
module:Refresh();assert(not overrides.F8)
combat=false;observer.scripts.OnEvent();assert(overrides.F8,"restore after secure combat cleanup")
spanned=false;module:Refresh();assert(not overrides.F8)
spanned=true;controller=true;module:Refresh();assert(not overrides.F8)
controller=false;module:Refresh();assert(overrides.F8)
addon.db={enabled=true};module:Refresh()
assert(not overrides.F8 and overrides.B=="CLICK OtherAddon:Open","profile switch releases only Offhand overrides")

-- In Forever the first binding addresses bag 4, while the fourth addresses bag 1.
local combinedIDs={}
ContainerFrameSettingsManager={IsUsingCombinedBags=function(_,id) return combinedIDs[id] end}
function ContainerFrameUtil_GetShownFrameForID() error("poll must leave native container enumeration to Blizzard") end
local slotKeys={"F6","F7","F8","F9","F12"}
local slotActions={"TOGGLEBAG1","TOGGLEBAG2","TOGGLEBAG3","TOGGLEBAG4","TOGGLEREAGENTBAG1"}
for i,action in ipairs(slotActions) do keys[action]={slotKeys[i]};native[slotKeys[i]]=action end
addon.db.keepBagToggleOpen=true
ContainerFrameCombinedBags.shown=true
bag.shown=true -- Another inventory on Offhand must not mask an unrelated individual key.
local ids={4,3,2,1,5}
for i,id in ipairs(ids) do
    ContainerFrame2=nil;module:Refresh()
    assert(not overrides[slotKeys[i]],"a stale combined frame must not mask a separate slot")
    ContainerFrame2=root(id);ContainerFrame2.shown=true
    module:Refresh()
    for j,key in ipairs(slotKeys) do assert((overrides[key]~=nil)==(i==j),"wrong separate bag binding") end
    ContainerFrame2.workspace=false;module:Refresh();assert(not overrides[slotKeys[i]])
    ContainerFrame2=nil;combinedIDs[id]=true
    module:Refresh();assert(overrides[slotKeys[i]],"combined owner on Offhand")
    ContainerFrameCombinedBags.workspace=false;module:Refresh();assert(not overrides[slotKeys[i]])
    ContainerFrameCombinedBags.workspace=true;combinedIDs[id]=nil
    module:Refresh();assert(not overrides[slotKeys[i]],"closed separate bag must open normally")
end

-- Bridge-provided replacement bag (e.g. DaylightUI_Bags): masking B when
-- keepBagToggleOpen is true, and immediately unbinding B (while preserving M)
-- when keepBagToggleOpen is toggled off.
local bridgeBag = root(); bridgeBag.shown = true
addon.BagPersistence = { frames = {} }
addon.Bridges = { IsBagOnWorkspace = function(_, fn) return fn(bridgeBag) end }
ContainerFrameCombinedBags.shown = false
ContainerFrame1.shown = false
WorldMapFrame.shown = true; WorldMapFrame.workspace = true
keys.TOGGLEWORLDMAP = { "M" }; native.M = "TOGGLEWORLDMAP"
keys.OPENALLBAGS = { "B" }; native.B = "OPENALLBAGS"
overrides.B = nil; overrides.M = nil
addon.db.keepMapToggleOpen = true
addon.db.keepBagToggleOpen = true
module:Refresh()
assert(overrides.B and overrides.M, "bridge bag on Offhand must mask B when keepBagToggleOpen is enabled")
addon.db.keepBagToggleOpen = false
module:Refresh()
assert(not overrides.B and overrides.M, "disabling keepBagToggleOpen must immediately unbind B while keeping M")

print("PASS: map, backpack and individual bag keys, window ownership, rebinding and combat cleanup")
