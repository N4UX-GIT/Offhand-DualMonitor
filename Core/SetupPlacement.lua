-- Guide checkpoint. A reload request cannot count as a completed UI reload in
-- the same Lua session. Physical monitor coverage still needs player review.
local _, Offhand = ...
local Placement = {}
Offhand.SetupPlacement = Placement
local acknowledged, issued

local function Dimension(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return end
    if type(value) == "number" and value > 0 and value < math.huge then return math.floor(value + .5) end
end

local function LayoutIdentity(metrics)
    if not metrics or not metrics.companionTopology then return end
    local fields = {}
    local function Rectangle(left, bottom, width, height)
        local values = {left, bottom, width, height}
        for index = 1, 4 do
            local value = values[index]
            if type(value) ~= "number" or value ~= value
                or value == math.huge or value == -math.huge then return false end
            fields[#fields + 1] = tostring(math.floor(value + 0.5))
        end
        return true
    end
    if not Rectangle(metrics.gamePixelLeft, metrics.gamePixelBottom,
        metrics.gamePixelWidth, metrics.gamePixelHeight) then return end
    if not Rectangle(metrics.workspacePixelLeft, metrics.workspacePixelBottom,
        metrics.workspacePixelWidth, metrics.workspacePixelHeight) then return end
    local regions = {}
    for _, region in ipairs(metrics.workspaceRegions or {}) do regions[#regions + 1] = region end
    table.sort(regions, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, region in ipairs(regions) do
        fields[#fields + 1] = tostring(region.id)
        if not Rectangle(region.pixelX, region.pixelY, region.pixelWidth, region.pixelHeight) then return end
    end
    if #regions > 0 then fields[#fields + 1] = tostring(metrics.primaryWorkspaceRegion) end
    return table.concat(fields, ",")
end

function Placement:Signature()
    if Offhand._displayGeometryTransitionActive then return end
    local method = Offhand.GetOnboardingSetupMethod and Offhand:GetOnboardingSetupMethod()
    if method ~= "COMPANION" and method ~= "FANCYZONES" and method ~= "MANUAL" then return end
    local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    local w, h = m and Dimension(m.physicalWidth), m and Dimension(m.physicalHeight)
    if (not w or not h) and GetPhysicalScreenSize then
        local pw, ph = GetPhysicalScreenSize()
        w, h = Dimension(pw), Dimension(ph)
    end
    if not w or not h then return end
    local canvas = method .. "|" .. w .. "|" .. h
    local identity = method == "COMPANION" and LayoutIdentity(m)
    return identity and canvas .. "|T:" .. identity or canvas, canvas
end

function Placement:GetStage()
    local signature, canvas = self:Signature()
    if not signature then return "SPAN" end
    local record = Offhand:GetPlacementCheckpoint()
    if record == "V1|" .. signature .. "|C" then return "READY", signature end
    if record == "V1|" .. signature .. "|R" then
        return record == issued and "RELOAD" or "CONFIRM", signature
    end
    -- Upgrade dimension-only checkpoints by asking for placement confirmation.
    -- A reload requested before exact geometry arrived also resumes here.
    if signature ~= canvas and record ~= issued
        and (record == "V1|" .. canvas .. "|C" or record == "V1|" .. canvas .. "|R") then
        return "CONFIRM", signature
    end
    return acknowledged == signature and "RELOAD" or "SPAN", signature
end

function Placement:Reset()
    acknowledged, issued = nil, nil
    Offhand:SetPlacementCheckpoint("")
end

function Placement:AcknowledgeSpan()
    if InCombatLockdown and InCombatLockdown() then return false end
    local signature = self:Signature()
    if not signature then return false end
    -- Restarting this step invalidates any earlier completed checkpoint.
    self:Reset()
    acknowledged = signature
    return true
end

function Placement:RequestReload()
    if InCombatLockdown and InCombatLockdown() then return false end
    local stage, signature = self:GetStage()
    if (stage ~= "RELOAD" and stage ~= "CONFIRM" and stage ~= "READY") or not signature then return false end
    issued = "V1|" .. signature .. "|R"
    Offhand:SetPlacementCheckpoint(issued)
    return Offhand:GetPlacementCheckpoint() == issued
end

function Placement:Confirm(signature)
    if InCombatLockdown and InCombatLockdown() then return false end
    local stage, current = self:GetStage()
    if (stage ~= "CONFIRM" and stage ~= "READY") or current ~= signature then return false end
    Offhand:SetPlacementCheckpoint("V1|" .. signature .. "|C")
    return true
end
