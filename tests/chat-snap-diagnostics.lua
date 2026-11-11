local combat, writes = false, 0
local addon = {db = {savedWorkspacePositions = {ChatFrame3 = {x=20}}, savedMainPositions = {ChatFrame1 = {x=80}}}}
InCombatLockdown = function() return combat end
local secret = setmetatable({}, {__index=function()error('secret field read')end,
    __tostring=function()error('secret string conversion')end})
issecretvalue = function(value) return rawequal(value, secret) end
local function Frame(name, shown, forbidden)
    return setmetatable({GetName=function()return name end, IsForbidden=function()return forbidden or false end,
        IsShown=function()return shown end, GetParent=function()return UIParent end,
        GetLeft=function()return 30 end,GetBottom=function()return 40 end,
        GetWidth=function()return 450 end,GetHeight=function()return 200 end,
        GetEffectiveScale=function()return .355 end,GetNumPoints=function()return 1 end,
        GetPoint=function()return 'TOPLEFT',UIParent,'TOPLEFT',-2400,1800 end},
        {__newindex=function()writes=writes+1;error('native frame mutated')end})
end
UIParent = Frame('UIParent',true)
ChatFrame1, ChatFrame3 = Frame('ChatFrame1',true), Frame('ChatFrame3',false)
rawset(ChatFrame1,'snappedToFrame',Frame('MainActionBar',true))
rawset(ChatFrame1,'isDocked',true)
EditModeManagerFrame = {IsShown=function()return true end,IsSnapEnabled=function()return true end}
assert(loadfile('Core/CanvasChat.lua'))('Offhand',addon)
local lines = addon.CanvasChat:GetPlacementDiagnostics()
assert(#lines==3 and lines[1]:find('SnapToElements=yes',1,true))
assert(lines[2]:find('snapTarget=MainActionBar',1,true) and lines[2]:find('saved=mainhand',1,true))
assert(lines[2]:find('TOPLEFT:UIParent:TOPLEFT:-2400.000/1800.000',1,true))
assert(lines[3]:find('shown=no',1,true)and lines[3]:find('saved=workspace',1,true),'hidden extra chat omitted')
ChatFrame5, ChatFrame6 = Frame('ChatFrame5',false), Frame('ChatFrame6',false)
rawset(ChatFrame5,'isDocked',0)
rawset(ChatFrame6,'isDocked',true)
rawset(ChatFrame5,'GetPoint',function()error('untracked hidden window probed')end)
local compact = table.concat(addon.CanvasChat:GetPlacementDiagnostics(true),' ')
assert(not compact:find('ChatFrame5 ',1,true) and compact:find('Other hidden/untracked windows=1',1,true))
assert(compact:find('ChatFrame3 shown=no',1,true) and compact:find('ChatFrame6 shown=no',1,true),
    'support summary lost tracked or docked hidden windows')
assert(table.concat(addon.CanvasChat:GetPlacementDiagnostics(),' '):find('ChatFrame5 shown=no',1,true),
    'focused report lost hidden window evidence')
rawset(ChatFrame3,'GetPoint',function()return secret,secret,secret,secret,secret end)
rawset(ChatFrame3,'GetWidth',function()return secret end)
rawset(ChatFrame3,'snappedToFrame',secret)
assert(pcall(addon.CanvasChat.GetPlacementDiagnostics,addon.CanvasChat),'secret data inspected')
ChatFrame4 = Frame('Forbidden',false,true)
rawset(ChatFrame4,'GetPoint',function()error('forbidden frame inspected')end)
assert(table.concat(addon.CanvasChat:GetPlacementDiagnostics(),' '):find('ChatFrame4=forbidden',1,true))
rawset(ChatFrame3,'GetPoint',function()error('unresolved native anchor')end)
assert(table.concat(addon.CanvasChat:GetPlacementDiagnostics(),' '):find('anchors=unresolved',1,true))
combat=true
EditModeManagerFrame.IsSnapEnabled=function()error('combat native state read')end
assert(addon.CanvasChat:GetPlacementDiagnostics()[1]=='state=combat-deferred')
assert(writes==0,'read-only diagnostics changed native frames')
print('PASS: read-only snapping/chat diagnostics, hidden extras, secret/forbidden/unresolved frames and combat deferral')
