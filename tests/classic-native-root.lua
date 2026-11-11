-- Native Classic assembly: mutate just the root anchor, never its children.
local combat, writes, customOwner, editOpen = false, 0, false, false
InCombatLockdown=function() return combat end
UIParent={GetEffectiveScale=function() return 0.4 end}
local point={'BOTTOM',UIParent,'BOTTOM',0,0}
local rootScale, visible, userPlaced, customized = 0.4, true, false, false
MainMenuBar={}
function MainMenuBar:IsProtected() return true end
function MainMenuBar:GetNumPoints() return 1 end
function MainMenuBar:GetPoint() return unpack(point) end
function MainMenuBar:ClearAllPoints() assert(not combat); writes=writes+1 end
function MainMenuBar:SetPoint(...) assert(not combat); writes=writes+1; point={...} end
function MainMenuBar:GetEffectiveScale() return rootScale end
function MainMenuBar:GetWidth() return 1024 end
function MainMenuBar:IsShown() return visible end
function MainMenuBar:IsUserPlaced() return userPlaced end
MainActionBar={IsInDefaultPosition=function() return not customized end}
MainMenuBarArtFrame={}
EditModeManagerFrame={IsShown=function() return editOpen end}
for _,frame in ipairs({MainMenuBar,MainActionBar,MainMenuBarArtFrame}) do
    for _,name in ipairs({'SetScale','SetParent','Show','Hide','SetScript','HookScript','SetAttribute','SetClampedToScreen'}) do
        frame[name]=function() error('unexpected native mutation: '..name) end
    end
end
MainActionBar.SetPoint=function() error('must not move protected child') end
local addon={db={enabled=true},HasCustomActionBarAddon=function() return customOwner end,
    HasBlizzardEditMode=function() return true end}
assert(loadfile('Core/MainhandCompatibility.lua'))('Offhand',addon)
local update=addon.MainhandCompatibility.UpdateClassicNativeBar
local m={isSpanned=true,gameLeft=1097,gameRight=3047,gameBottom=5,gameTop=1102}
local function original() assert(point[1]=='BOTTOM' and point[2]==UIParent and point[3]=='BOTTOM' and point[4]==0 and point[5]==0) end
local function moved() assert(point[3]=='BOTTOMLEFT' and point[4]==2072 and point[5]==5) end
addon.HasBlizzardEditMode=function() return false end
assert(not update(m)); original()
addon.HasBlizzardEditMode=function() return true end
combat=true; assert(not update(m)); original(); assert(writes==0)
combat=false; assert(update(m)); moved()
local before=writes; assert(update(m)); assert(writes==before,'identical root anchors must not be rewritten')
combat=true; addon.db.enabled=false; assert(not update(m)); moved(); assert(writes==before)
combat=false; assert(not update(m)); original()
addon.db.enabled=true; assert(update(m)); moved()
m.isSpanned=false; assert(not update(m)); original()
m.isSpanned=true
editOpen=true; assert(not update(m)); original()
editOpen=false
for _,flag in ipairs({'isRetail','isForever','isLegacyWrath'}) do
    addon[flag]=true; assert(not update(m)); original(); addon[flag]=nil
end
ConsolePort={}; assert(not update(m)); original(); ConsolePort=nil
customOwner=true; assert(not update(m)); original(); customOwner=false
userPlaced=true; assert(not update(m)); original(); userPlaced=false
customized=true; assert(not update(m)); original(); customized=false
assert(update(m)); point={'CENTER',UIParent,'CENTER',50,90}; before=writes
assert(not update(m)); assert(writes==before and point[4]==50,'must yield to external anchor changes')
addon.db.enabled=false; assert(not update(m)); assert(point[4]==50,'disable must not overwrite another owner')
addon.db.enabled=true; point={'BOTTOM',UIParent,'BOTTOM',0,0}
rootScale=0.8
assert(not update(m),'oversized assembly must remain native, not overflow Mainhand'); original()
rootScale=0.2; assert(update(m))
assert(point[4]==4144 and point[5]==10,'convert UIParent units into native root units')
addon.db.enabled=false; update(m); original(); addon.db.enabled=true; rootScale=0.4
assert(update(m)); m.gameRight=1800; assert(not update(m)); original()
m.gameRight=3047
assert(update(m)); customOwner=true; assert(not update(m)); original(); customOwner=false
assert(update(m)); visible=false; assert(not update(m)); original(); visible=true
assert(update(m)); editOpen=true; addon.db.enabled=false; assert(not update(m)); original()
print('PASS: native Classic root anchoring, combat deferral, scale, ownership and restoration')
