-- Workspace presets are separate from display calibration and character HUDs.
-- Only addon-owned data is copied here. Native frame writes use Canvas guards.
local _, Offhand = ...
local Profiles = {}
Offhand.WorkspaceProfiles = Profiles

local fields = {
    "savedWorkspacePositions", "savedMainPositions", "openWorkspacePanels",
    "workspacePanelLoadAddons", "workspaceRegionThemes", "workspacePanelRoutes",
    "nativeBackpackWorkspacePosition", "nativeBackpackWorkspaceOpen",
    "workspacePlayerSpellsTab", "workspaceMapScale", "mainMapScale",
    "userMediaEnabled", "userMediaFitMode", "workspaceRegionScales",
}
local mediaFields={userMediaEnabled=true,userMediaFitMode=true}
local function Copy(value, depth)
    if type(value) ~= "table" then
        if type(value) == "string" or type(value) == "boolean"
            or type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
        return nil
    end
    if (depth or 0) >= 8 then return nil end
    local result = {}
    for k, v in pairs(value) do
        if type(k) == "string" or type(k) == "number" then result[k] = Copy(v, (depth or 0) + 1) end
    end
    return result
end
local function Snapshot()
    local result = {}
    for _, key in ipairs(fields) do result[key] = Copy(Offhand.db[key]) end
    result.mediaSettingsVersion=1
    return result
end
local tableFields={savedWorkspacePositions=true,savedMainPositions=true,openWorkspacePanels=true,
    workspacePanelLoadAddons=true,workspaceRegionThemes=true,workspacePanelRoutes=true,nativeBackpackWorkspacePosition=true}
local function ValidState(state)
    if type(state)~="table" then return false end
    if Offhand.WorkspaceScale and not Offhand.WorkspaceScale:ValidSettings(state.workspaceRegionScales) then return false end
    if state.mediaSettingsVersion~=nil and state.mediaSettingsVersion~=1 then return false end
    if state.userMediaEnabled~=nil and type(state.userMediaEnabled)~="boolean" then return false end
    local fit=state.userMediaFitMode
    if fit~=nil and fit~="PACKAGE" and fit~="FILL" and fit~="FIT" and fit~="STRETCH" then return false end
    for key in pairs(tableFields) do if state[key]~=nil and type(state[key])~="table" then return false end end
    for _,key in ipairs({"savedWorkspacePositions","savedMainPositions"}) do
        for name,position in pairs(state[key] or {}) do
            if type(name)~="string" or type(position)~="table" then return false end
            for _,field in ipairs({"x","y","regionX","regionY","width","height","canvasLeft","canvasBottom","canvasWidth","canvasHeight"}) do
                local value=position[field]
                if value~=nil and (type(value)~="number" or value~=value or math.abs(value)==math.huge) then return false end
            end
            if position.regionId~=nil and type(position.regionId)~="string" then return false end
        end
    end
    for _,key in ipairs({"workspaceMapScale","mainMapScale"}) do
        local value=state[key]
        if value~=nil and value~="AUTO"
            and (type(value)~="number" or value~=value or value<=0 or value==math.huge) then return false end
    end
    return true
end
local function Name(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    local _,characters=name:gsub("[^\128-\191]","")
    if name == "" or #name > 192 or characters>48 or name:find("[%c|]") then return nil end
    return name
end
local function Store()
    local db = Offhand.db
    if not db then return nil end
    if db.workspaceProfiles == nil then
        db.workspaceProfiles = {version=1, active="default", nextID=0,
            items={default={name="Default", state=Snapshot()}}}
    end
    local store = db.workspaceProfiles
    if type(store) ~= "table" or store.version ~= 1 or type(store.items) ~= "table"
        or type(store.items[store.active]) ~= "table" then return nil end
    local count=0
    for id,item in pairs(store.items) do
        count=count+1
        if count>24 or type(id)~="string" or #id>64 or not id:match("^[%w_]+$")
            or type(item)~="table" or not Name(item.name) or not ValidState(item.state) then return nil end
    end
    return store
end
local function Editable()
    return not (InCombatLockdown and InCombatLockdown())
end
local function Count(store)
    local count=0; for _ in pairs(store.items) do count=count+1 end; return count
end
local function Failure(key) return false, (Offhand.L and Offhand.L[key]) or key end

function Profiles:List()
    local store=Store(); local list={}
    if store then
        for id, item in pairs(store.items) do
            if type(item)=="table" and Name(item.name) then list[#list+1]={id=id,name=item.name} end
        end
        table.sort(list,function(a,b) if a.name==b.name then return a.id<b.id end; return a.name<b.name end)
    end
    return list, store and store.active
end
function Profiles:Save()
    if not Editable() then return Failure("WORKSPACE_COMBAT") end
    local store=Store()
    if not store then return Failure("WORKSPACE_PROFILE_INVALID") end
    store.items[store.active].state=Snapshot()
    return true
end
function Profiles:Activate(id, deferLayout)
    if not Editable() then return Failure("WORKSPACE_COMBAT") end
    local store=Store(); local item=store and store.items[id]
    if type(item)~="table" or not ValidState(item.state) then return Failure("WORKSPACE_PROFILE_INVALID") end
    local previous={}
    if store.active~=id then
        if Offhand.WorkspaceScale then Offhand.WorkspaceScale.generation=Offhand.WorkspaceScale.generation+1 end
        for name in pairs(Offhand.db.savedWorkspacePositions or {}) do previous[name]=true end
        for name in pairs(Offhand.db.savedMainPositions or {}) do previous[name]=true end
        store.items[store.active].state=Snapshot()
        local state=Copy(item.state)
        for _,key in ipairs(fields) do
            -- Older workspace snapshots did not own global media preferences.
            if not mediaFields[key] or state.mediaSettingsVersion==1 then Offhand.db[key]=state[key] end
        end
        Offhand.db.savedWorkspacePositions=Offhand.db.savedWorkspacePositions or {}
        Offhand.db.savedMainPositions=Offhand.db.savedMainPositions or {}
        Offhand.db.openWorkspacePanels=Offhand.db.openWorkspacePanels or {}
        store.active=id
    end
    self.pendingNames,self.pendingDB=previous,Offhand.db
    if not deferLayout then
        if Offhand.ApplyFullLayout then Offhand:ApplyFullLayout() end
        self:Refresh()
    end
    return true
end
function Profiles:Refresh()
    if not Editable() or not self.pendingNames or self.pendingDB~=Offhand.db then return end
    local previous=self.pendingNames
    self.pendingNames,self.pendingDB=nil,nil
        local canvas=Offhand.Canvas
        if canvas and canvas.RestoreWorkspacePosition then
            for name in pairs(Offhand.db.savedWorkspacePositions) do previous[name]=true end
            for name in pairs(Offhand.db.savedMainPositions) do previous[name]=true end
            for name in pairs(previous) do
                local frame=_G[name]
                if frame and not (frame.IsForbidden and frame:IsForbidden()) and frame.IsShown and frame:IsShown() then
                    if Offhand.db.savedWorkspacePositions[name] or Offhand.db.savedMainPositions[name] then canvas:RestoreWorkspacePosition(frame)
                    elseif canvas.PlacePanelOnMainhand then canvas:PlacePanelOnMainhand(frame) end
                end
            end
        end
        if Offhand.Canvas and Offhand.Canvas.RestorePersistentFrames then Offhand.Canvas:RestorePersistentFrames() end
        if Offhand.WorkspaceRouting then Offhand.WorkspaceRouting:Refresh() end
end
function Profiles:Create(name)
    if not Editable() then return Failure("WORKSPACE_COMBAT") end
    local store=Store(); name=Name(name)
    if not store or not name then return Failure("WORKSPACE_PROFILE_INVALID") end
    for _,item in pairs(store.items) do if item.name==name then return Failure("PROFILES_WARN_EXISTS") end end
    if Count(store)>=24 then return Failure("WORKSPACE_PROFILE_LIMIT") end
    local nextID=tonumber(store.nextID) or 0
    if nextID<0 or nextID>1000000 or nextID~=nextID then nextID=0 end
    store.nextID=math.floor(nextID)+1
    local id="local_"..store.nextID
    while store.items[id] do store.nextID=store.nextID+1; id="local_"..store.nextID end
    store.items[id]={name=name,state=Snapshot()}
    return self:Activate(id)
end
function Profiles:Rename(id,name)
    if not Editable() then return Failure("WORKSPACE_COMBAT") end
    local store=Store(); name=Name(name)
    if not store or not store.items[id] or not name then return Failure("WORKSPACE_PROFILE_INVALID") end
    for other,item in pairs(store.items) do if other~=id and item.name==name then return Failure("PROFILES_WARN_EXISTS") end end
    store.items[id].name=name
    return true
end
function Profiles:Delete(id)
    if not Editable() then return Failure("WORKSPACE_COMBAT") end
    local store=Store()
    if not store or id=="default" or id==store.active then return Failure("PROFILES_WARN_DELETE_ACTIVE") end
    store.items[id]=nil
    return true
end

-- A manually selected Companion plan carries a stable ID. Renaming keeps that
-- ID. Repeated layout passes and reloads never override a later in-game choice.
function Profiles:SyncCompanion(metrics)
    if not Editable() or not metrics or (metrics.topologySchema~=2 and metrics.topologySchema~=3) or not metrics.isSpanned then return end
    local raw=_G.OffhandCompanionTopology
    local id=type(raw)=="table" and raw.workspaceProfileID
    local name=type(raw)=="table" and Name(raw.workspaceProfileName)
    if type(id)~="string" or not id:match("^[a-f0-9]+$") or #id~=32 or not name then return end
    local store=Store(); if not store then return end
    id="companion_"..id
    if store.lastCompanionID==id then
        if store.items[id] and store.lastCompanionName~=name then store.items[id].name=name end
        store.lastCompanionName=name
        return
    end
    if not store.items[id] then
        if Count(store)>=24 then return end
        store.items[id]={name=name,state=Snapshot()}
    end
    if self:Activate(id,true) then store.lastCompanionID=id;store.lastCompanionName=name end
end
