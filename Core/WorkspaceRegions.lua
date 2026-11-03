-- Pure geometry for independent workspace destinations. No native frame writes.
local _, Offhand = ...
local Regions = {}
Offhand.WorkspaceRegions = Regions

local function Integer(v)
    return type(v) == "number" and v == v and v >= 0 and v < math.huge
        and v == math.floor(v)
end
local function Rect(r, width, height)
    return type(r) == "table" and Integer(r.x) and Integer(r.y)
        and Integer(r.width) and Integer(r.height) and r.width > 0 and r.height > 0
        and r.x + r.width <= width and r.y + r.height <= height
end
local function Overlap(a, b)
    return math.max(0, math.min(a.x+a.width, b.x+b.width)-math.max(a.x,b.x))
        * math.max(0, math.min(a.y+a.height,b.y+b.height)-math.max(a.y,b.y))
end
local function ID(id)
    return type(id) == "string" and #id > 0 and #id <= 32
        and id:match("^[%w_-]+$") ~= nil
end

-- Keep the one-game/two-workspace prototype bounded. These conservative limits
-- are allocation guardrails, not a promise of a renderer's supported maximum.
function Regions:ValidateTopology(raw)
    if type(raw) ~= "table" or raw.schema ~= 2 or raw.mode ~= "CUSTOM_REGIONS" then return nil end
    local width, height = raw.physicalWidth, raw.physicalHeight
    if not Integer(width) or not Integer(height) or width < 1 or height < 1
        or width > 16384 or height > 16384 or not Rect(raw.game,width,height)
        or raw.game.width < 960 or raw.game.height < 600
        or width*height > raw.game.width*raw.game.height*4
        or type(raw.workspaces) ~= "table" or not ID(raw.primaryWorkspace)
        or type(raw.mainhandDevice) ~= "string" or raw.mainhandDevice == "" then return nil end
    local count = 0
    for key in pairs(raw.workspaces) do
        if not Integer(key) or key < 1 or key > 2 then return nil end
        count = count+1
    end
    if count < 1 or count > 2 or #raw.workspaces ~= count then return nil end
    local ids, devices, primary = {}, {[raw.mainhandDevice:lower()]=true}
    for _, r in ipairs(raw.workspaces) do
        if not Rect(r,width,height) or r.width < 480 or r.height < 600 or not ID(r.id)
            or ids[r.id] or type(r.device) ~= "string" or r.device == ""
            or devices[r.device:lower()] or Overlap(r,raw.game)>0 then return nil end
        for _, other in ipairs(ids) do if Overlap(r,other)>0 then return nil end end
        ids[r.id], ids[#ids+1], devices[r.device:lower()] = true, r, true
        if r.id == raw.primaryWorkspace then primary = r end
    end
    if not primary then return nil end
    -- Do not mutate the generated bridge or alias user data into applied metrics.
    local result = {}
    for key,value in pairs(raw) do result[key]=value end
    result.workspace = primary
    return result
end

function Regions:ApplyMetrics(metrics, topology)
    if topology.schema ~= 2 then return metrics end
    local ux, uy = metrics.screenWidth/metrics.physicalWidth, metrics.screenHeight/metrics.physicalHeight
    local regions = {}
    for _, raw in ipairs(topology.workspaces) do
        local r={id=raw.id, device=raw.device, x=raw.x*ux, y=raw.y*uy,
            width=raw.width*ux, height=raw.height*uy,
            pixelX=raw.x, pixelY=raw.y, pixelWidth=raw.width, pixelHeight=raw.height}
        regions[#regions+1]=r
    end
    metrics.topologySchema, metrics.workspaceRegions = 2, regions
    metrics.primaryWorkspaceRegion = topology.primaryWorkspace
    return metrics
end

function Regions:Get(metrics, id)
    for _, r in ipairs(metrics and metrics.workspaceRegions or {}) do
        if r.id == (id or metrics.primaryWorkspaceRegion) then return r end
    end
end

function Regions:IsCanvas(frame)
    for _,canvas in pairs(Offhand.canvases or {}) do if canvas==frame then return true end end
    return frame~=nil and frame==Offhand.canvas
end

function Regions:ContainsPoint(metrics,x,y)
    for _,r in ipairs(metrics.workspaceRegions or {}) do
        if x>=r.x and x<=r.x+r.width and y>=r.y and y<=r.y+r.height then return true end
    end
    return false
end

function Regions:ForRegion(metrics, id)
    local r=self:Get(metrics,id) or self:Get(metrics)
    if not r then return metrics end
    local copy={}
    for key,value in pairs(metrics) do copy[key]=value end
    copy.workspaceRegionID=r.id
    copy.workspaceLeft, copy.workspaceBottom=r.x,r.y
    copy.workspaceRight, copy.workspaceTop=r.x+r.width,r.y+r.height
    copy.workspaceWidth, copy.workspaceHeight=r.width,r.height
    copy.workspacePixelLeft, copy.workspacePixelBottom=r.pixelX,r.pixelY
    copy.workspacePixelWidth, copy.workspacePixelHeight=r.pixelWidth,r.pixelHeight
    return copy
end

local function Inside(r,x,y)
    return x >= r.x and x <= r.x+r.width and y >= r.y and y <= r.y+r.height
end

-- Input is a UIParent-space TOPLEFT and size. Centre wins, then overlap.
-- Game is a separate destination so crossing its edge does not claim workspace.
function Regions:Destination(metrics,x,top,width,height)
    if not metrics or not metrics.workspaceRegions then return nil end
    local cx,cy=x+width/2,top-height/2
    local game={x=metrics.gameLeft,y=metrics.gameBottom,
        width=metrics.gameRight-metrics.gameLeft,height=metrics.gameTop-metrics.gameBottom}
    if Inside(game,cx,cy) then return "MAINHAND" end
    local chosen, best
    for _,r in ipairs(metrics.workspaceRegions) do
        if Inside(r,cx,cy) then return r.id end
        local overlap=Overlap({x=x,y=top-height,width=width,height=height},r)
        if overlap>0 and (not best or overlap>best or (overlap==best and r.id<chosen)) then
            chosen,best=r.id,overlap
        end
    end
    return chosen
end

function Regions:FrameRect(frame)
    if not frame or not frame.GetLeft or not frame.GetTop then return nil end
    local scale=(frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parent=(UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if parent<=0 or scale<=0 then return nil end
    local left,top=frame:GetLeft(),frame:GetTop()
    if not left or not top then return nil end
    local factor=scale/parent
    return left*factor,top*factor,((frame.GetWidth and frame:GetWidth()) or 0)*factor,
        ((frame.GetHeight and frame:GetHeight()) or 0)*factor
end

function Regions:ForFrame(metrics,frame,position)
    if not metrics or not metrics.workspaceRegions then return metrics end
    local x,y,w,h=self:FrameRect(frame)
    if position then return self:ForPosition(metrics,position,w,h) end
    local id=x and self:Destination(metrics,x,y,w,h)
    return self:ForRegion(metrics,id~="MAINHAND" and id or nil)
end

function Regions:ForPosition(metrics,position,width,height)
    if not metrics or not metrics.workspaceRegions then return metrics end
    local id=position and position.regionId
    if not id and position and tonumber(position.x) and tonumber(position.y) then
        id=self:Destination(metrics,tonumber(position.x),tonumber(position.y),width or 1,height or 1)
    end
    return self:ForRegion(metrics,id~="MAINHAND" and id or nil)
end

function Regions:ContainsFrame(metrics,frame,whole)
    local x,y,w,h=self:FrameRect(frame)
    if not x then return false end
    for _,r in ipairs(metrics.workspaceRegions or {}) do
        if whole then
            if x>=r.x and x+w<=r.x+r.width and y-h>=r.y and y<=r.y+r.height then return true,r.id end
        elseif Inside(r,x+w/2,y-h/2) then return true,r.id end
    end
    return false
end

function Regions:SavePosition(position,metrics)
    local r=self:Get(metrics,metrics.workspaceRegionID)
    if r then
        position.regionId=r.id
        position.regionX=(position.x-r.x)/r.width
        position.regionY=(position.y-r.y)/r.height
    end
    return position
end

function Regions:Seams(metrics)
    local seams={}
    for _,r in ipairs(metrics.workspaceRegions or {}) do
        local bottom,top=math.max(r.y,metrics.gameBottom),math.min(r.y+r.height,metrics.gameTop)
        local left,right=math.max(r.x,metrics.gameLeft),math.min(r.x+r.width,metrics.gameRight)
        if top>bottom and (math.abs(r.x+r.width-metrics.gameLeft)<=2 or math.abs(r.x-metrics.gameRight)<=2) then
            local x=math.abs(r.x+r.width-metrics.gameLeft)<=2 and metrics.gameLeft or metrics.gameRight
            seams[#seams+1]={x=x-2,y=bottom,width=4,height=top-bottom}
        elseif right>left and (math.abs(r.y+r.height-metrics.gameBottom)<=2 or math.abs(r.y-metrics.gameTop)<=2) then
            local y=math.abs(r.y+r.height-metrics.gameBottom)<=2 and metrics.gameBottom or metrics.gameTop
            seams[#seams+1]={x=left,y=y-2,width=right-left,height=4}
        end
    end
    return seams
end
