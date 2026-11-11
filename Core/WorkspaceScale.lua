-- Region sizing is opt-in. Geometry stays in physical pixels/UIParent units.
local _, Offhand = ...
local Scale = { MIN=0.40, MAX=1.50, generation=0,
    state=setmetatable({}, {__mode="k"}), released=setmetatable({}, {__mode="k"}),
    watched=setmetatable({}, {__mode="k"}), pending=setmetatable({}, {__mode="k"}),
    maps=setmetatable({}, {__mode="k"}) }
Offhand.WorkspaceScale=Scale
local function Combat()
    local geometry=Offhand.MainhandGeometry
    if geometry and geometry.IsPlayerCombatRestricted then return geometry.IsPlayerCombatRestricted() end
    return InCombatLockdown and InCombatLockdown()
end
local function Number(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return type(v)=="number" and v==v and v>0 and v<math.huge and v or nil
end
local function Text(v,limit) return type(v)=="string" and #v>0 and #v<=(limit or 256) and not v:find("[%c]") end
local function Read(frame,method)
    if not frame or type(frame[method])~="function" then return nil end
    local ok,v=pcall(frame[method],frame);return ok and v or nil
end
local function Name(f) local n=Read(f,"GetName");return Text(n) and n or nil end
local function Near(a,b) return a and b and math.abs(a-b)<0.001 end
local function Clamp(v) return math.max(Scale.MIN,math.min(Scale.MAX,v)) end
local function Token(v) v=tostring(v or "");return #v..":"..v end

-- Optional metadata is copied only after the topology itself was accepted.
-- A bad scale record cannot invalidate otherwise usable display geometry.
function Scale:ApplyTopologyMetrics(m,t)
    local meta=t.panelScaleMetadata
    local game=t.mainhandDevice
    local rawRegions=t.workspaces or {{id="workspace",device=t.workspaceDevice}}
    local scales={}
    m.workspaceScaleGame=nil
    if type(meta)=="table" and meta.version==1 and type(meta.game)=="table"
        and Text(game) and meta.game.device==game then
        local function Record(r,device)
            if type(r)~="table" or r.device~=device then return nil end
            local percent=Number(r.percent)
            return {device=device,identity=Text(r.identity) and r.identity or device,
                percent=percent and percent>=25 and percent<=1000 and percent or nil}
        end
        m.workspaceScaleGame=Record(meta.game,game)
        if type(meta.workspaces)=="table" then
            for _,r in ipairs(rawRegions) do
                local raw=meta.workspaces[r.id]
                -- Legacy topology did not carry workspaceDevice; the metadata
                -- must still name one of the accepted selected devices.
                local device=r.device
                if not device and type(raw)=="table" then
                    for _,selected in ipairs(t.selectedDevices or {}) do
                        if selected==raw.device then device=selected end
                    end
                end
                if device then scales[r.id]=Record(raw,device) end
            end
        end
    end
    m.workspaceScaleDisplays=scales
    local key
    if Text(t.workspaceProfileID,64) then
        -- Companion preset identities survive renames and display enumeration.
        key={"companion",Token(t.workspaceProfileID)}
    else
        key={Token(t.schema),Token(t.mode),Token(game)}
        for _,r in ipairs(rawRegions) do
            key[#key+1]=Token(r.id)..Token(r.device)..Token(r.x)..Token(r.y)..Token(r.width)..Token(r.height)
        end
        key[#key+1]=Token(t.game.x)..Token(t.game.y)..Token(t.game.width)..Token(t.game.height)
    end
    m.workspaceScaleLayout=table.concat(key,"|")
    return m
end

function Scale:Destinations(m)
    if not m or not m.isSpanned then return {} end
    return m.workspaceRegions or {{id="workspace",x=m.workspaceLeft,y=m.workspaceBottom,
        width=m.workspaceWidth,height=m.workspaceHeight}}
end
function Scale:Keys(m,id)
    if not m or not m.isSpanned then return nil end
    id=id or m.workspaceRegionID or m.primaryWorkspaceRegion or "workspace"
    local found
    for _,r in ipairs(self:Destinations(m)) do if r.id==id then found=true end end
    if not found then return nil end
    -- Preset state owns this table; the layout key also isolates unsaved plans.
    local layout=m.workspaceScaleLayout or ("manual:"..Token(m.preset)..Token(m.workspacePixelLeft)
        ..Token(m.workspacePixelBottom)..Token(m.workspacePixelWidth)..Token(m.workspacePixelHeight))
    return layout,id
end
function Scale:ValidSettings(store)
    if store==nil then return true end
    if type(store)~="table" or store.version~=1 or type(store.layouts)~="table" then return false end
    local count=0
    for key,regions in pairs(store.layouts) do
        count=count+1
        if count>64 or not Text(key,2048) or type(regions)~="table" then return false end
        local n=0
        for id,r in pairs(regions) do
            n=n+1
            if n>16 or not Text(id,64) or type(r)~="table" or type(r.chat)~="boolean"
                or not (r.size=="AUTO" or Number(r.size) and r.size>=self.MIN and r.size<=self.MAX) then return false end
        end
    end
    return true
end
function Scale:GetSetting(m,id)
    local layout,region=self:Keys(m,id)
    local store=Offhand.db and Offhand.db.workspaceRegionScales
    if layout and self:ValidSettings(store) and store then
        local regions=store.layouts[layout];local value=regions and regions[region]
        if value then return value.size,value.chat end
    end
    return 1,false
end
function Scale:GetMultiplier(m,id)
    local setting=self:GetSetting(m,id)
    if setting~="AUTO" then return setting,"MANUAL" end
    id=id or m.workspaceRegionID or m.primaryWorkspaceRegion or "workspace"
    local game=m.workspaceScaleGame
    local work=m.workspaceScaleDisplays and m.workspaceScaleDisplays[id]
    if not m.companionTopology or not game or not work or not game.percent or not work.percent then
        return 1,"UNAVAILABLE"
    end
    local raw=work.percent/game.percent
    return Clamp(raw),Near(Clamp(raw),raw) and "AUTO" or "BOUNDED",game.percent,work.percent
end
function Scale:SetSetting(m,id,value,chat)
    local layout,region=self:Keys(m,id)
    if not Offhand.db or not layout or not (value=="AUTO" or Number(value)) then return false end
    local store=Offhand.db.workspaceRegionScales
    if not self:ValidSettings(store) then return false end
    store=store or {version=1,layouts={}}
    local size=value=="AUTO" and value or Clamp(value)
    local _,oldChat=self:GetSetting(m,id)
    local regions=store.layouts[layout]
    if not regions then
        local count=0;for _ in pairs(store.layouts) do count=count+1 end
        if count>=64 then return false end
        regions={};store.layouts[layout]=regions
    end
    regions[region]={size=size,chat=chat==nil and oldChat or chat==true}
    Offhand.db.workspaceRegionScales=store
    self.generation=self.generation+1
    self.lastFailure=nil
    self.released=setmetatable({}, {__mode="k"})
    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
        Offhand.ForeverPersistence:SaveProfileSnapshot(true)
    end
    self:Refresh()
    return true
end

function Scale:Allowed(f)
    if Combat() or not f or not f.SetScale or not f.GetScale then return false end
    if Read(f,"IsForbidden") then return false end
    local canvas=Offhand.Canvas
    return canvas and canvas.CanScaleWorkspacePanel and canvas:CanScaleWorkspacePanel(f) or false
end
function Scale:Write(f,value)
    self.writing=f
    local ok=pcall(f.SetScale,f,value)
    self.writing=nil
    ok=ok and Near(Number(Read(f,"GetScale")),value)
    if not ok then self.lastFailure=Name(f) or "unknown" end
    return ok
end
function Scale:WriteKeepingTopLeft(f,value)
    local left,top=Read(f,"GetLeft"),Read(f,"GetTop")
    local before=Number(Read(f,"GetEffectiveScale"))
    if not self:Write(f,value) then return false end
    local after=Number(Read(f,"GetEffectiveScale"))
    if type(left)=="number" and type(top)=="number" and before and after
        and not (issecretvalue and (issecretvalue(left) or issecretvalue(top)))
        and f.ClearAllPoints and f.SetPoint then
        pcall(function()
            f:ClearAllPoints();f:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",left*before/after,top*before/after)
        end)
    end
    return true
end
function Scale:Release(f,preserveAnchor)
    local state=self.state[f];if not state then return true end
    if Combat() then return false end
    local current=Number(Read(f,"GetScale"))
    if not self:Allowed(f) or not Near(current,state.applied) then
        self.state[f]=nil;self.released[f]=true;return true
    end
    local write=preserveAnchor and self.WriteKeepingTopLeft or self.Write
    if not write(self,f,state.native) then return false end
    self.state[f]=nil;return true
end
function Scale:ApplySingle(f,m,multiplier,owner)
    if not self:Allowed(f) then
        if self.state[f] then self.state[f]=nil;self.released[f]=true end
        return true
    end
    if self.released[f] then return true end
    local current=Number(Read(f,"GetScale"));if not current then return false end
    local state=self.state[f]
    if state and not Near(current,state.applied) then
        -- Native bag reopen resets are recognizable. Other writers own their
        -- final scale, rather than becoming a baseline to multiply repeatedly.
        if not (Name(f) or ""):match("^ContainerFrame") or not Near(current,state.native) then
            self.state[f]=nil;self.released[f]=true;return true
        end
    end
    local native=state and state.native or current
    local desired=native*multiplier
    if not Near(current,desired) and not self:Write(f,desired) then return false end
    if Near(multiplier,1) then self.state[f]=nil
    else
        self.state[f]={native=native,applied=desired,owner=owner or f,db=Offhand.db}
        -- Forever's bag controller already observes reopen/reset geometry.
        -- Do not install hooks or scripts on its native item-action ancestry.
        if not (Offhand.isForever and (Name(f) or ""):match("^ContainerFrame")) then self:Watch(f) end
    end
    return true
end

local excluded={WorldMapFrame=true,CharacterFrame=true,PlayerSpellsFrame=true}
function Scale:Apply(f,onWorkspace,m)
    if Combat() then return false end
    local name=Name(f)
    if not name or excluded[name] then return true end
    if name:match("^ChatFrame%d+$") then return self:ApplyChat(f,onWorkspace,m) end
    local multiplier=onWorkspace and m and m.isSpanned and Offhand.db and Offhand.db.enabled
        and self:GetMultiplier(m) or 1
    if Near(multiplier,1) then return self:Release(f) end
    return self:ApplySingle(f,m,multiplier)
end

function Scale:ChatMembers(f)
    local dock=_G.GENERAL_CHAT_DOCK or _G.GeneralDockManager
    local primary=dock and dock.primary or _G.ChatFrame1
    local members={f};local inherited={}
    local docked=dock and dock.DOCKED_CHAT_FRAMES or {}
    if dock and f~=primary then
        for _,member in pairs(docked) do if member==f then return nil,primary end end
    end
    if dock and f==primary then
        members[#members+1]=dock
        for _,member in pairs(docked) do if member~=f then members[#members+1]=member end end
    end
    local windows={};for _,member in ipairs(members) do windows[#windows+1]=member end
    for _,window in ipairs(windows) do
        local name=Name(window)
        if name and name:match("^ChatFrame%d+$") then
            for _,suffix in ipairs({"Tab","EditBox"}) do
                local child=_G[name..suffix]
                if child then
                    local parent=Read(child,"GetParent")
                    if parent==window or (dock and f==primary and parent==dock) then inherited[child]=true
                    else members[#members+1]=child end
                end
            end
        end
    end
    return members,nil,inherited
end
function Scale:ApplyChat(f,onWorkspace,m)
    local members,primary,inherited=self:ChatMembers(f)
    if not members then return true end -- the dock primary owns this cluster
    local include=false
    if m then local setting;setting,include=self:GetSetting(m) end
    local multiplier=onWorkspace and include and Offhand.db.enabled and self:GetMultiplier(m) or 1
    local wanted={}
    for _,member in ipairs(members) do wanted[member]=true end
    -- Restore members that left a floating/docked cluster, including edit boxes.
    local stale={}
    for member,state in pairs(self.state) do
        if (state.owner==f and not wanted[member]) or inherited[member] then stale[#stale+1]=member end
    end
    for _,member in ipairs(stale) do if not self:Release(member) then return false end end
    for _,member in ipairs(members) do
        if not self:Allowed(member) or Read(member,"IsProtected") then return true end
    end
    for _,member in ipairs(members) do
        if Near(multiplier,1) then
            if not self:Release(member) then return false end
        elseif not self:ApplySingle(member,m,multiplier,f) then return false end
    end
    return true
end

function Scale:Schedule(f)
    if self.pending[f] then return end
    local db,generation=Offhand.db,self.generation
    local metrics=Offhand.Viewport and Offhand.Viewport:GetMetrics()
    local layout=metrics and self:Keys(metrics)
    self.pending[f]=true
    local function run()
        Scale.pending[f]=nil
        if db~=Offhand.db or generation~=Scale.generation then return end
        if Combat() then
            Scale:Defer("refresh")
            return
        end
        local m=Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not db or not db.enabled or not m or not m.isSpanned or layout~=Scale:Keys(m)
            or not Read(f,"IsShown") or not Scale:Allowed(f) then return end
        local name=Name(f);local pos=db.savedWorkspacePositions and db.savedWorkspacePositions[name]
        if not pos then return end
        if Offhand.CanvasPersistence and Offhand.CanvasPersistence.PreservedFitFallback(f,m,pos) then return end
        -- Re-enter all placement guards and fit checks. Never anchor in a hook.
        local canvas=Offhand.Canvas
        if canvas.RestoreRegionScaledPanel then canvas:RestoreRegionScaledPanel(f)
        else canvas:RestoreWorkspacePosition(f) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,run) else self.pending[f]=nil end
end
function Scale:Defer(kind)
    self.deferredDB,self.deferredGeneration=Offhand.db,self.generation
    local already=self.refreshQueued or self.restoreQueued
    self[kind.."Queued"]=true
    local function drain()
        if not (Scale.refreshQueued or Scale.restoreQueued) or Combat() then return end
        Scale.refreshQueued,Scale.restoreQueued=nil,nil
        if Scale.deferredDB~=Offhand.db or Scale.deferredGeneration~=Scale.generation then return end
        if Offhand.db and Offhand.db.enabled then Scale:Refresh() else Scale:RestoreAll() end
    end
    -- Some Forever transitions expose player combat before lockdown. Observe
    -- regeneration on an addon-owned frame instead of recursively queueing work
    -- through a lockdown-only queue that could run immediately.
    if not self.combatListener and CreateFrame then
        self.combatListener=CreateFrame("Frame")
        self.combatListener:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.combatListener:SetScript("OnEvent",drain)
    end
    if not already and InCombatLockdown and InCombatLockdown() and Offhand.RunOrQueueCombat then
        Offhand:RunOrQueueCombat(drain)
    end
end
function Scale:Watch(f)
    if self.watched[f] or not hooksecurefunc then return end
    local ok=pcall(hooksecurefunc,f,"SetScale",function(frame)
        if Scale.writing==frame then return end
        local state=Scale.state[frame]
        if state then Scale:Schedule(state.owner) end
    end)
    if ok then self.watched[f]=true end
end
function Scale:RestoreAll()
    self.generation=self.generation+1
    if Combat() then
        self:Defer("restore")
        return
    end
    local frames={};for f in pairs(self.state) do frames[#frames+1]=f end
    for _,f in ipairs(frames) do
        local state=self.state[f]
        self:Release(f,state and state.owner==f and not (Name(f) or ""):match("^ChatFrame"))
    end
    for f,state in pairs(self.maps) do
        if self:Allowed(f) and Near(Number(Read(f,"GetScale")),state.applied) then self:WriteKeepingTopLeft(f,state.native) end
        self.maps[f]=nil
    end
end
function Scale:RememberMap(f,native,applied)
    if not Near(Number(Read(f,"GetScale")),applied) then self.lastFailure=Name(f);return end
    self.maps[f]=not Near(native,applied) and {native=native,applied=applied} or nil
end
function Scale:InstallChatHooks()
    if not hooksecurefunc then return end
    self.chatHooks=self.chatHooks or {}
    for _,name in ipairs({"FCF_DockFrame","FCF_UnDockFrame"}) do
        if not self.chatHooks[name] and type(_G[name])=="function" then
            local ok=pcall(hooksecurefunc,name,function()
                if Scale.chatPending or not next(Scale.state) or not (C_Timer and C_Timer.After) then return end
                Scale.chatPending=true
                local db,generation=Offhand.db,Scale.generation
                C_Timer.After(0,function()
                    Scale.chatPending=nil
                    if db==Offhand.db and generation==Scale.generation then Scale:Refresh() end
                end)
            end)
            if ok then self.chatHooks[name]=true end
        end
    end
end
function Scale:Refresh()
    if Combat() then
        self:Defer("refresh")
        return
    end
    self:InstallChatHooks()
    local db=Offhand.db;local m=Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not db or not db.enabled or not m or not m.isSpanned then self:RestoreAll();return end
    local saved=db.savedWorkspacePositions or {};local stale={}
    for f,state in pairs(self.state) do
        if state.db~=db or not saved[Name(state.owner)] then stale[#stale+1]=f end
    end
    for _,f in ipairs(stale) do self:Release(f) end
    local canvas=Offhand.Canvas
    if canvas and canvas.RestoreWorkspacePosition then
        for name in pairs(saved) do
            local f=_G[name]
            if f and Read(f,"IsShown") then
                if canvas.RestoreRegionScaledPanel then canvas:RestoreRegionScaledPanel(f)
                else canvas:RestoreWorkspacePosition(f) end
            end
        end
    end
    if canvas and canvas.ConfigureWorldMap and Read(_G.WorldMapFrame,"IsShown") and not saved.WorldMapFrame then
        canvas:ConfigureWorldMap()
    end
end

function Scale:GetDiagnostics(m)
    local result={regions={},scaled=0,released=0,lastFailure=self.lastFailure}
    for _ in pairs(self.state) do result.scaled=result.scaled+1 end
    for _ in pairs(self.released) do result.released=result.released+1 end
    for _,r in ipairs(self:Destinations(m)) do
        local value,source,game,work=self:GetMultiplier(m,r.id)
        local setting,chat=self:GetSetting(m,r.id)
        result.regions[#result.regions+1]={id=r.id,setting=setting,multiplier=value,source=source,
            gamePercent=game,workspacePercent=work,chat=chat}
    end
    return result
end
