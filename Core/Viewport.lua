-- Calculate in physical pixels, then convert into UIParent units.
local _, Offhand = ...
local Viewport = {}
Offhand.Viewport = Viewport

local function Number(value, fallback, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = fallback end
    return math.max(low, math.min(high, value))
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
    local ratio = Number(db.deckWidthRatio, preset == "LANDSCAPE_DUAL" and 0.5 or 0.36, 0.15, 0.80)
    local deck = math.floor(pw * ratio + 0.5)
    local bezel = math.floor(Number(db.bezelGap, 0, 0, pw - deck - 1) + 0.5)
    local width = pw - deck - bezel
    local bottom = math.floor(Number(db.gameBottomPixels, 0, 0, ph - 1) + 0.5)
    local mode = db.aspectRatioMode or "16_9"
    local height
    if mode == "FILL" then
        height = ph * Number(db.gameHeightRatio, 0.5625, 0.05, 1)
    else
        local ar = mode == "16_9" and 16 / 9 or mode == "21_9" and 21 / 9
            or Number(db.customAspectRatio, 16 / 9, 0.25, 8)
        height = width / ar
    end
    height = math.max(1, math.min(math.floor(height + 0.5), ph - bottom))
    local left = db.primaryPosition == "LEFT" and 0 or deck + bezel
    local ux, uy = sw / pw, sh / ph
    local gameHeight = height * uy
    -- Children inherit the global UIParent baseline; HUD offsets use native units.
    local hudScale = 1
    return {
        screenWidth = sw, screenHeight = sh, physicalWidth = pw, physicalHeight = ph,
        deckWidth = deck * ux, gameWidth = width * ux, gameHeight = gameHeight,
        gameLeft = left * ux, gameBottom = bottom * uy,
        gameRight = (left + width) * ux, gameTop = (bottom + height) * uy,
        gamePixelLeft = left, gamePixelBottom = bottom,
        gamePixelWidth = width, gamePixelHeight = height,
        hudScale = hudScale, bezel = bezel * ux, preset = preset,
        actualAR = width / height, arMode = mode, isSpanned = true,
    }
end

-- This is the sole scale owner. Never call it from HUD/frame-position hooks.
function Viewport:ApplyGlobalScale()
    if InCombatLockdown() or self.scaling then return end
    local db=Offhand.db
    if not db then return end
    if not db.enabled then
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
            end)
            self.originalScale = nil
            db.originalUiScale = nil
            db.originalUseUiScale = nil
            self.scaling=false
        end
        return
    end
    local m=self:GetMetrics()
    local desired=math.min(m.gamePixelHeight/m.physicalHeight,
        m.gamePixelWidth*768/(1100*m.physicalHeight)) * Number(db.hudScale,0.70,0.25,1.25)
    
    if not self.originalScale and not db.originalUiScale then 
        self.originalScale = UIParent:GetScale() 
        if GetCVar then
            db.originalUiScale = GetCVar("uiScale")
            db.originalUseUiScale = GetCVar("useUiScale")
        end
    end
    
    local cvarScale = GetCVar and tonumber(GetCVar("uiScale")) or 1
    if math.abs(UIParent:GetScale()-desired)<0.00001 and math.abs(cvarScale - desired) < 0.00001 then return end
    self.scaling=true
    local ok,err=pcall(function() 
        if GetCVar and GetCVar("useUiScale") ~= "1" then
            if SetCVar then SetCVar("useUiScale", "1") end
        end
        if SetCVar then SetCVar("uiScale", desired) end
        UIParent:SetScale(desired) 
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
