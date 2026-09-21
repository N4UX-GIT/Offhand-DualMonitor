-- Calculate in physical pixels, then convert into UIParent units.
local _, Offhand = ...
local Viewport = {}
Offhand.Viewport = Viewport

local function Number(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = fallback end
    return math.max(low, math.min(high, value))
end

local function ValidRect(rect, pw, ph)
    if type(rect) ~= "table" then return false end
    local x, y, w, h = tonumber(rect.x), tonumber(rect.y), tonumber(rect.width), tonumber(rect.height)
    return x and y and w and h and w > 0 and h > 0 and x >= 0 and y >= 0
        and x + w <= pw + 2 and y + h <= ph + 2
end

function Viewport:GetCompanionTopology(pw, ph)
    local topology = _G.OffhandCompanionTopology
    if type(topology) ~= "table" or tonumber(topology.schema) ~= 1 then return nil, "ABSENT" end
    if math.abs((tonumber(topology.physicalWidth) or -1) - pw) > 2
        or math.abs((tonumber(topology.physicalHeight) or -1) - ph) > 2
        or not ValidRect(topology.game, pw, ph)
        or not ValidRect(topology.workspace, pw, ph) then
        return nil, "MISMATCH"
    end
    return topology, "READY"
end

-- SetPoint offsets belong to the receiving frame, not its relative frame.
function Viewport:SetPoint(frame, point, relativePoint, x, y)
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    frame:SetPoint(point, UIParent, relativePoint, x * factor, y * factor)
end

function Viewport:GetMetrics()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local pw, ph = GetPhysicalScreenSize()
    if not pw or pw <= 0 or not ph or ph <= 0 then pw, ph = sw, sh end
    local db = Offhand.db
    local preset = db.layoutPreset or "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
    local ux, uy = sw / pw, sh / ph
    local topology, topologyStatus = self:GetCompanionTopology(pw, ph)
    if topology then
        local game, workspace = topology.game, topology.workspace
        local width, height = tonumber(game.width), tonumber(game.height)
        local left, bottom = tonumber(game.x), tonumber(game.y)
        local workspaceLeft, workspaceBottom = tonumber(workspace.x), tonumber(workspace.y)
        local workspaceWidth, workspaceHeight = tonumber(workspace.width), tonumber(workspace.height)
        return {
            screenWidth = sw, screenHeight = sh, physicalWidth = pw, physicalHeight = ph,
            deckWidth = workspaceWidth * ux,
            workspaceWidth = workspaceWidth * ux, workspaceHeight = workspaceHeight * uy,
            workspaceLeft = workspaceLeft * ux, workspaceBottom = workspaceBottom * uy,
            workspaceRight = (workspaceLeft + workspaceWidth) * ux,
            workspaceTop = (workspaceBottom + workspaceHeight) * uy,
            workspacePixelLeft = workspaceLeft, workspacePixelBottom = workspaceBottom,
            workspacePixelWidth = workspaceWidth, workspacePixelHeight = workspaceHeight,
            gameWidth = width * ux, gameHeight = height * uy,
            gameLeft = left * ux, gameBottom = bottom * uy,
            gameRight = (left + width) * ux, gameTop = (bottom + height) * uy,
            gamePixelLeft = left, gamePixelBottom = bottom,
            gamePixelWidth = width, gamePixelHeight = height,
            hudScale = 1, bezel = 0, preset = preset,
            actualAR = width / height, arMode = "NATIVE", isSpanned = true,
            companionTopology = true, topologyMode = topology.mode, topologyStatus = "READY",
        }
    elseif topologyStatus == "MISMATCH" then
        return {
            screenWidth = sw, screenHeight = sh, physicalWidth = pw, physicalHeight = ph,
            deckWidth = 0, workspaceWidth = 0, workspaceHeight = 0,
            workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 0, workspaceTop = 0,
            gameWidth = sw, gameHeight = sh, gameLeft = 0, gameBottom = 0,
            gameRight = sw, gameTop = sh, gamePixelLeft = 0, gamePixelBottom = 0,
            gamePixelWidth = pw, gamePixelHeight = ph, hudScale = 1, bezel = 0,
            preset = preset, actualAR = pw / ph, arMode = "NATIVE", isSpanned = false,
            companionTopology = false, topologyStatus = "MISMATCH",
        }
    end
    
    local isVertical = (db.primaryPosition == "TOP" or db.primaryPosition == "BOTTOM")
    
    local ratio = Number(db.deckWidthRatio, preset == "LANDSCAPE_DUAL" and 0.5 or 0.36, 0.15, 0.80)
    local deck = isVertical and math.floor(ph * ratio + 0.5) or math.floor(pw * ratio + 0.5)
    local bezel = isVertical and math.floor(Number(db.bezelGap, 0, 0, ph - deck - 1) + 0.5) or math.floor(Number(db.bezelGap, 0, 0, pw - deck - 1) + 0.5)
    
    local width = isVertical and pw or (pw - deck - bezel)
    local height = isVertical and (ph - deck - bezel) or ph
    
    local bottom = 0
    if isVertical then
        bottom = db.primaryPosition == "TOP" and (deck + bezel) or 0
    else
        bottom = math.floor(Number(db.gameBottomPixels, 0, 0, ph - 1) + 0.5)
        local mode = db.aspectRatioMode or "16_9"
        if mode == "FILL" then
            height = ph * Number(db.gameHeightRatio, 0.5625, 0.05, 1)
        else
            local ar = mode == "16_9" and 16 / 9 or mode == "21_9" and 21 / 9 or mode == "32_9" and 32 / 9
                or Number(db.customAspectRatio, 16 / 9, 0.25, 8)
            height = width / ar
        end
        height = math.max(1, math.min(math.floor(height + 0.5), ph - bottom))
    end
    
    local left = 0
    if not isVertical then
        left = db.primaryPosition == "LEFT" and 0 or deck + bezel
    else
        left = math.floor(Number(db.gameLeftPixels, 0, 0, pw - 1) + 0.5)
    end
    
    local gameHeight = height * uy
    local workspaceLeft, workspaceBottom, workspaceWidth, workspaceHeight
    if isVertical then
        workspaceLeft, workspaceWidth = 0, pw
        workspaceBottom = db.primaryPosition == "TOP" and 0 or (bottom + height + bezel)
        workspaceHeight = deck
    else
        workspaceLeft = db.primaryPosition == "LEFT" and (left + width + bezel) or 0
        workspaceBottom, workspaceWidth, workspaceHeight = 0, deck, ph
    end
    local hudScale = 1
    return {
        screenWidth = sw, screenHeight = sh, physicalWidth = pw, physicalHeight = ph,
        deckWidth = isVertical and (deck * uy) or (deck * ux), gameWidth = width * ux, gameHeight = gameHeight,
        workspaceWidth = workspaceWidth * ux, workspaceHeight = workspaceHeight * uy,
        workspaceLeft = workspaceLeft * ux, workspaceBottom = workspaceBottom * uy,
        workspaceRight = (workspaceLeft + workspaceWidth) * ux,
        workspaceTop = (workspaceBottom + workspaceHeight) * uy,
        workspacePixelLeft = workspaceLeft, workspacePixelBottom = workspaceBottom,
        workspacePixelWidth = workspaceWidth, workspacePixelHeight = workspaceHeight,
        gameLeft = left * ux, gameBottom = bottom * uy,
        gameRight = (left + width) * ux, gameTop = (bottom + height) * uy,
        gamePixelLeft = left, gamePixelBottom = bottom,
        gamePixelWidth = width, gamePixelHeight = height,
        hudScale = hudScale, bezel = isVertical and (bezel * uy) or (bezel * ux), preset = preset,
        actualAR = width / height, arMode = db.aspectRatioMode or "16_9", isSpanned = true,
        companionTopology = false, topologyStatus = topologyStatus,
    }
end

-- This is the sole scale owner. Never call it from HUD/frame-position hooks.
function Viewport:ApplyGlobalScale()
    if InCombatLockdown() or self.scaling then return end
    local db=Offhand.db
    if not db then return end
    local metrics = db.enabled and self:GetMetrics() or nil
    if not db.enabled or (metrics and not metrics.isSpanned) then
        if self.originalScale or db.originalUiScale then
            self.scaling=true
            pcall(function() 
                if db.originalUiScale then
                    if SetCVar then SetCVar("uiScale", db.originalUiScale) end
                    UIParent:SetScale(tonumber(db.originalUiScale) or 1)
                elseif self.originalScale then
                    UIParent:SetScale(self.originalScale)
                end
                
                if db.originalUseUiScale then
                    if SetCVar then SetCVar("useUiScale", db.originalUseUiScale) end
                end
                if WorldFrame and WorldFrame.SetScale then
                    WorldFrame:SetScale(1)
                end
            end)
            self.originalScale = nil
            db.originalUiScale = nil
            db.originalUseUiScale = nil
            self.scaling=false
        end
        return
    end
    local m=metrics or self:GetMetrics()
    local desired=math.min(m.gamePixelHeight/m.physicalHeight,
        m.gamePixelWidth*768/(1100*m.physicalHeight)) * Number(db.hudScale,0.70,0.25,1.25)
    
    if not self.originalScale then
        self.originalScale = UIParent:GetScale()
    end
    
    if math.abs(UIParent:GetScale()-desired)<0.00001 then return end
    self.scaling=true
    local ok,err=pcall(function() 
        -- Keep the native CVar separate: client clamping can otherwise cause
        -- every display notification to write it again. Children inherit UIParent.
        UIParent:SetScale(desired) 
        if WorldFrame and WorldFrame.SetScale then
            WorldFrame:SetScale(1)
        end
    end)
    self.scaling=false
    if not ok then error(err) end
end

function Viewport:IsDualActive()
    return Offhand.db and Offhand.db.enabled
end

function Viewport:CaptureDiagnostics()
    local m = self:GetMetrics()
    local snapshot = { metrics = m, frames = {} }
    for _, name in ipairs({"WorldFrame", "OffhandCanvasFrame", "MainMenuBar",
        "MainActionBar", "ActionButton1", "PlayerFrame", "MinimapCluster"}) do
        local frame = _G[name]
        if frame then
            local x, y, w, h = frame:GetRect()
            if x and y and w and h then
                local factor = frame:GetEffectiveScale() * m.physicalHeight / 768
                snapshot.frames[name] = {x=x*factor, y=y*factor,
                    width=w*factor, height=h*factor, scale=frame:GetEffectiveScale()}
            end
        end
    end
    local world = snapshot.frames.WorldFrame
    snapshot.viewportMatches = world and math.abs(world.x - m.gamePixelLeft) < 1
        and math.abs(world.y - m.gamePixelBottom) < 1
        and math.abs(world.width - m.gamePixelWidth) < 1
        and math.abs(world.height - m.gamePixelHeight) < 1 or false
    Offhand.db.lastGeometryCheck = snapshot
    return snapshot
end

function Viewport:Apply()
    if InCombatLockdown() then
        Offhand:RunOrQueueCombat(function() Viewport:Apply() end)
        return
    end
    if not Offhand.db.enabled then self:Reset(); return end
    local m = self:GetMetrics()
    if not m.isSpanned then self:Reset(); return end
    WorldFrame:ClearAllPoints()
    self:SetPoint(WorldFrame, "BOTTOMLEFT", "BOTTOMLEFT", m.gameLeft, m.gameBottom)
    self:SetPoint(WorldFrame, "TOPRIGHT", "BOTTOMLEFT", m.gameRight, m.gameTop)
    Offhand:Debug("Viewport: %dx%d pixels at (%d, %d).", m.gamePixelWidth,
        m.gamePixelHeight, m.gamePixelLeft, m.gamePixelBottom)
end

function Viewport:Reset()
    if InCombatLockdown() then
        Offhand:RunOrQueueCombat(function() Viewport:Reset() end)
        return
    end
    WorldFrame:ClearAllPoints()
    WorldFrame:SetAllPoints(UIParent)
end

function Offhand:InitializeViewport() end
function Offhand:UpdateViewport() Viewport:Apply() end
