-- Rules select destinations only for the existing guarded Canvas restore path.
-- Native ownership, panel registration, combat and size policy remain there.
local _, Offhand = ...
local Routing={}
Offhand.WorkspaceRouting=Routing
local groups={
    {id="map",label="WORKSPACE_ROUTE_MAP",frames={"WorldMapFrame"}},
    {id="character",label="WORKSPACE_ROUTE_CHARACTER",frames={"CharacterFrame"}},
    {id="spells",label="WORKSPACE_ROUTE_SPELLS",frames={"PlayerSpellsFrame","SpellBookFrame"}},
    {id="collections",label="WORKSPACE_ROUTE_COLLECTIONS",frames={"CollectionsJournal","CollectionsJournalFrame"}},
    {id="achievements",label="WORKSPACE_ROUTE_ACHIEVEMENTS",frames={"AchievementFrame"}},
    {id="journal",label="WORKSPACE_ROUTE_JOURNAL",frames={"EncounterJournal"}},
}
local byName,byID={},{}
for _,group in ipairs(groups) do
    byID[group.id]=group
    for _,name in ipairs(group.frames) do byName[name]=group.id end
end
function Routing:GetGroups() return groups end
local function ValidTarget(target)
    return target==nil or target=="MAINHAND" or type(target)=="string"
        and #target>0 and #target<=32 and target:match("^[%w_-]+$")~=nil
end
local function Editable()
    return Offhand.db and not (InCombatLockdown and InCombatLockdown())
end
function Routing:HasRule(name,metrics)
    local group=byName[name]
    local routes=Offhand.db and Offhand.db.workspacePanelRoutes
    local target=group and type(routes)=="table" and routes[group]
    return metrics and metrics.workspaceRegions and metrics.isSpanned
        and target~=nil and ValidTarget(target) or false
end
function Routing:SetRule(group,target)
    if not Editable() then return false,"WORKSPACE_COMBAT" end
    if not byID[group] or not ValidTarget(target) then return false,"WORKSPACE_PROFILE_INVALID" end
    if Offhand.db.workspacePanelRoutes~=nil and type(Offhand.db.workspacePanelRoutes)~="table" then return false,"WORKSPACE_PROFILE_INVALID" end
    Offhand.db.workspacePanelRoutes=Offhand.db.workspacePanelRoutes or {}
    Offhand.db.workspacePanelRoutes[group]=target
    self:Refresh()
    return true
end
function Routing:ResetManual(group)
    if not Editable() then return false,"WORKSPACE_COMBAT" end
    if not byID[group] then return false,"WORKSPACE_PROFILE_INVALID" end
    if Offhand.db.savedWorkspacePositions~=nil and type(Offhand.db.savedWorkspacePositions)~="table"
        or Offhand.db.savedMainPositions~=nil and type(Offhand.db.savedMainPositions)~="table" then return false,"WORKSPACE_PROFILE_INVALID" end
    for _,name in ipairs(byID[group].frames) do
        if Offhand.db.savedWorkspacePositions then Offhand.db.savedWorkspacePositions[name]=nil end
        if Offhand.db.savedMainPositions then Offhand.db.savedMainPositions[name]=nil end
    end
    self:Refresh()
    return true
end

-- Called after Canvas has rejected forbidden/protected/external-owned frames.
-- Persist generated anchors with a marker so a later rule edit can update them.
-- A real drag writes a normal record, which always takes precedence thereafter.
function Routing:Resolve(frame,metrics)
    if not Editable() or not frame or not metrics or not metrics.isSpanned
        or not metrics.workspaceRegions or not Offhand.db.enabled then return end
    local name=frame.GetName and frame:GetName()
    local group=byName[name]; if not group then return end
    local db=Offhand.db
    if db.savedWorkspacePositions~=nil and type(db.savedWorkspacePositions)~="table"
        or db.savedMainPositions~=nil and type(db.savedMainPositions)~="table" then return end
    local work=db.savedWorkspacePositions or {}; local main=db.savedMainPositions or {}
    local w,m=work[name],main[name]
    if w and (type(w)~="table" or w.autoRoute~=group)
        or m and (type(m)~="table" or m.autoRoute~=group) then return end
    local target=type(db.workspacePanelRoutes)=="table" and db.workspacePanelRoutes[group]
    if not ValidTarget(target) then return end
    if not target then
        if w and w.autoRoute==group then work[name]=nil end
        if m and m.autoRoute==group then main[name]=nil end
        if w or m then return "MAINHAND" end
        return
    end
    db.savedWorkspacePositions,db.savedMainPositions=work,main
    if target=="MAINHAND" then
        work[name]=nil
        -- Canvas computes the native-size centered Mainhand anchor each time.
        main[name]={autoRoute=group,routeTarget=target}
        return "MAINHAND"
    end
    main[name]=nil
    if w and w.routeTarget==target then return end
    local destination=Offhand.WorkspaceRegions:ForRegion(metrics,target)
    work[name]={autoRoute=group,routeTarget=target,regionId=target,
        regionX=0.02,regionY=0.98,
        x=destination.workspaceLeft+12,y=destination.workspaceTop-12,
        canvasLeft=destination.workspaceLeft,canvasBottom=destination.workspaceBottom,
        canvasWidth=destination.workspaceWidth,canvasHeight=destination.workspaceHeight}
end
function Routing:Refresh()
    if not Editable() or not Offhand.Canvas or not Offhand.Canvas.RestoreWorkspacePosition then return end
    for name in pairs(byName) do
        local frame=_G[name]
        if frame and not (frame.IsForbidden and frame:IsForbidden())
            and frame.IsShown and frame:IsShown() then Offhand.Canvas:RestoreWorkspacePosition(frame) end
    end
end
