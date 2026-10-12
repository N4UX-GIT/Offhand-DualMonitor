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

local function Near(value, expected)
    return math.abs((tonumber(value) or -1) - expected) <= 2
end

function Viewport:GetCompanionTopology(pw, ph, sw, sh)
    local topology = _G.OffhandCompanionTopology
    if type(topology) ~= "table" or tonumber(topology.schema) ~= 1 then return nil, "ABSENT" end
    local topologyWidth = tonumber(topology.physicalWidth)
    local topologyHeight = tonumber(topology.physicalHeight)
    if not topologyWidth or not topologyHeight or topologyWidth <= 0 or topologyHeight <= 0
        or not ValidRect(topology.game, topologyWidth, topologyHeight)
        or not ValidRect(topology.workspace, topologyWidth, topologyHeight) then
        return nil, "MISMATCH"
    end

    if Near(topologyWidth, pw) and Near(topologyHeight, ph) then
        return topology, "READY"
    end

    -- Classic Era and Anniversary clients can keep reporting the native size
    -- of one monitor after an external borderless window resize. Their UIParent
    -- aspect ratio still reflects the complete spanned canvas. Accept the
    -- Companion rectangle only when both signals agree; after Restore Window,
    -- the canvas aspect returns to the single-monitor ratio and this safely
    -- becomes MISMATCH again. Forever retains the stricter exact-size guard.
    local reportedDisplay = (Near(topology.game.width, pw) and Near(topology.game.height, ph))
        or (Near(topology.workspace.width, pw) and Near(topology.workspace.height, ph))
    local canvasAspect = tonumber(sw) and tonumber(sh) and sh > 0 and (sw / sh) or nil
    local topologyAspect = topologyWidth / topologyHeight
    if not Offhand.isForever and reportedDisplay and canvasAspect
        and math.abs(canvasAspect - topologyAspect) <= 0.01 then
        return topology, "READY"
    end
    return nil, "MISMATCH"
end

local function ReadCVarNumber(name, allowZero)
    local function read(getter, setter)
        if type(getter) ~= "function" then return nil end
        local ok, value = pcall(getter, name)
        value = ok and tonumber(value) or nil
        local minimum = allowZero and 0 or 0.0000001
        if value and value == value and value >= minimum and value < math.huge then
            return value, type(setter) == "function" and setter or nil
        end
    end
    local value, setter = read(GetCVar, SetCVar)
    if value ~= nil then return value, setter end
    -- Some hybrid clients retain the legacy global API while exposing a
    -- particular CVar only through C_CVar. Do not let a legacy nil prevent the
    -- namespaced probe.
    return read(C_CVar and C_CVar.GetCVar, C_CVar and C_CVar.SetCVar)
end

local function ReadNumericCVar(name)
    return ReadCVarNumber(name, false)
end

local WORLD_TEXT_SCALE_CVARS = {"WorldTextScale_v2", "WorldTextScale"}

local function ReadWorldTextScale()
    for _, name in ipairs(WORLD_TEXT_SCALE_CVARS) do
        local value = ReadNumericCVar(name)
        if value then return value, name end
    end
end

-- Expose only the selected native control, not the implementation details of
-- reading or writing it. Forever's versioned control also owns native speech-
-- bubble presentation, so ChatBubbles uses this capability signal to avoid
-- applying a second frame scale that changes the engine's screen anchor.
function Viewport:GetWorldTextScaleControl()
    local value, name = ReadWorldTextScale()
    return name, value
end

local function ReadNonNegativeCVar(name)
    return ReadCVarNumber(name, true)
end

local function WriteNumericCVar(name, value)
    local _, setter = ReadCVarNumber(name, false)
    setter = setter or SetCVar or (C_CVar and C_CVar.SetCVar)
    if not setter or not value then return false end
    return pcall(setter, name, string.format("%.6f", value))
end

local function WriteBooleanCVar(name, value)
    local _, setter = ReadCVarNumber(name, true)
    setter = setter or SetCVar or (C_CVar and C_CVar.SetCVar)
    if not setter or value == nil then return false end
    return pcall(setter, name, tonumber(value) and tonumber(value) >= 0.5 and "1" or "0")
end

local function ManageFriendlyPlayerNames(db)
    local friendlyNames = ReadNonNegativeCVar("UnitNameFriendlyPlayerName")
    local shouldManage = db and db.enabled and Offhand.isRetail and not Offhand.isForever
        and friendlyNames ~= nil
    if shouldManage then
        if db.originalFriendlyPlayerName == nil then
            db.originalFriendlyPlayerName = friendlyNames
        end
        if friendlyNames < 0.5 then
            WriteBooleanCVar("UnitNameFriendlyPlayerName", 1)
        end
    elseif db and db.originalFriendlyPlayerName ~= nil then
        WriteBooleanCVar("UnitNameFriendlyPlayerName", db.originalFriendlyPlayerName)
        db.originalFriendlyPlayerName = nil
    end
end

local function ValidPositive(value)
    value = tonumber(value)
    return value and value == value and value > 0 and value < math.huge
end

local function ReadNamePlateDimensions()
    if not C_NamePlate or type(C_NamePlate.GetNamePlateSize) ~= "function" then return nil end
    local ok, width, height = pcall(C_NamePlate.GetNamePlateSize)
    if not ok or not ValidPositive(width) or not ValidPositive(height) then return nil end
    return width, height
end

local trackedNamePlateFrames = setmetatable({}, { __mode = "k" })

local function ParseReleaseVersion(value)
    if type(value) ~= "string" then return nil end
    local major, minor, patch, label, number = string.lower(value):match(
        "^v?(%d+)%.(%d+)%.(%d+)%-?([%a]*)[%.%-]?(%d*)$")
    if not major then return nil end
    if label ~= "" and label ~= "beta" then return nil end
    if label == "beta" and number == "" then return nil end
    return {
        major = tonumber(major), minor = tonumber(minor), patch = tonumber(patch),
        beta = label == "beta" and tonumber(number) or nil,
        stable = label == "",
    }
end

local function ReleaseAtLeast(actual, minimum)
    local left, right = ParseReleaseVersion(actual), ParseReleaseVersion(minimum)
    if not left or not right then return nil end
    for _, field in ipairs({"major", "minor", "patch"}) do
        if left[field] ~= right[field] then return left[field] > right[field] end
    end
    if left.stable ~= right.stable then return left.stable end
    if left.stable then return true end
    return left.beta >= right.beta
end

local function CompanionVersionStatus(topology)
    local actual = topology and type(topology.companionVersion) == "string"
        and topology.companionVersion or nil
    local expected = type(Offhand.companionMinVersion) == "string"
        and Offhand.companionMinVersion ~= "" and Offhand.companionMinVersion
        or (type(Offhand.companionFullVersion) == "string"
            and Offhand.companionFullVersion or nil)
    if not actual or actual == "" then return "UNKNOWN", nil, expected end
    if not expected or expected == "" then return "UNKNOWN", actual, nil end
    local compatible = ReleaseAtLeast(actual, expected)
    if compatible == nil then
        return string.lower(actual) == string.lower(expected) and "MATCH" or "UNKNOWN",
            actual, expected
    end
    return compatible and "MATCH" or "MISMATCH", actual, expected
end

-- A stale exact topology is unsafe on every client. An absent topology is
-- different: it is the packaged state for users who deliberately span the WoW
-- window themselves, so the saved percentage geometry remains authoritative.
function Viewport:IsRecoveryTopologyStatus(topologyStatus)
    return topologyStatus == "MISMATCH"
end

function Viewport:IsSingleScreenRecovery(metrics)
    return metrics and not metrics.isSpanned
        and self:IsRecoveryTopologyStatus(metrics.topologyStatus) or false
end

local function NamePlateScaleFrame(namePlate)
    local unitFrame = namePlate and namePlate.UnitFrame
    if not unitFrame or type(unitFrame.GetScale) ~= "function"
        or type(unitFrame.SetScale) ~= "function"
        or type(unitFrame.ClearAllPoints) ~= "function"
        or type(unitFrame.SetPoint) ~= "function"
        or type(unitFrame.SetSize) ~= "function"
        or type(unitFrame.SetAllPoints) ~= "function" then return nil end
    if type(unitFrame.IsForbidden) == "function" then
        local ok, forbidden = pcall(unitFrame.IsForbidden, unitFrame)
        if not ok or forbidden then return nil end
    end
    return unitFrame
end

local function ReadFrameScale(frame)
    local ok, scale = pcall(frame.GetScale, frame)
    scale = ok and tonumber(scale) or nil
    return ValidPositive(scale) and scale or nil
end

local function ReadFrameEffectiveScale(frame)
    if not frame or type(frame.GetEffectiveScale) ~= "function" then return nil end
    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    scale = ok and tonumber(scale) or nil
    return ValidPositive(scale) and scale or nil
end

local function RestoreTrackedNamePlateFrame(scaleFrame, state)
    local restored = false
    local current = ReadFrameScale(scaleFrame)
    if current and state.applied and state.original
        and math.abs(current - state.applied) < 0.00001
        and pcall(scaleFrame.SetScale, scaleFrame, state.original) then
        restored = true
    end
    if state.detached and state.owner then
        pcall(scaleFrame.ClearAllPoints, scaleFrame)
        pcall(scaleFrame.SetAllPoints, scaleFrame, state.owner)
    end
    return restored
end

local function FrameIsForbidden(frame)
    if not frame or type(frame.IsForbidden) ~= "function" then return false end
    local ok, forbidden = pcall(frame.IsForbidden, frame)
    return not ok or forbidden and true or false
end

local function DesiredHUDScale(metrics)
    if type(metrics) ~= "table" then return nil end
    local physicalHeight = math.max(1, tonumber(metrics.physicalHeight) or 1)
    local gameHeight = math.max(0, tonumber(metrics.gamePixelHeight) or 0)
    local gameWidth = math.max(0, tonumber(metrics.gamePixelWidth) or 0)
    local geometryScale = math.min(gameHeight / physicalHeight,
        gameWidth * 768 / (1100 * physicalHeight))
    return math.max(0.05, geometryScale
        * Number(Offhand.db and Offhand.db.hudScale, 0.70, 0.25, 1.25))
end

local function WorldTextCompensationRatio(metrics)
    if type(metrics) ~= "table" then return 1 end
    local physicalHeight = math.max(1, tonumber(metrics.physicalHeight) or 1)
    local gameHeight = math.max(0, tonumber(metrics.gamePixelHeight) or 0)
    local heightRatio = gameHeight / physicalHeight
    local db = Offhand.db
    if not db or db.worldTextCompensation == false then return 1 end
    -- Equal-height spans are the known unaffected Forever topology. Leave the
    -- native CVar exactly alone there, regardless of the optional HUD scale.
    if math.abs(heightRatio - 1) <= 0.01 then return 1 end
    return math.max(0.05, DesiredHUDScale(metrics)
        * Number(db.worldTextScale, 1, 0.50, 1.50))
end

function Viewport:RestoreNamePlateVisualScale()
    local restored = 0
    for scaleFrame, state in pairs(trackedNamePlateFrames) do
        if RestoreTrackedNamePlateFrame(scaleFrame, state) then restored = restored + 1 end
        trackedNamePlateFrames[scaleFrame] = nil
    end
    self.namePlateCompensationRatio = nil
    self.namePlateVisualFrameCount = 0
    return restored
end

function Viewport:RestoreNamePlateUnit(unitToken)
    if not unitToken then return false end
    for scaleFrame, state in pairs(trackedNamePlateFrames) do
        if state.unitToken == unitToken then
            RestoreTrackedNamePlateFrame(scaleFrame, state)
            trackedNamePlateFrames[scaleFrame] = nil
            return true
        end
    end
    return false
end

function Viewport:ApplyNamePlateFrame(namePlate, targetEffectiveScale)
    local scaleFrame = NamePlateScaleFrame(namePlate)
    if not scaleFrame then return false end
    local current = ReadFrameScale(scaleFrame)
    local parentEffectiveScale = ReadFrameEffectiveScale(namePlate)
    if not current or not parentEffectiveScale then return false end

    local state = trackedNamePlateFrames[scaleFrame]
    -- Blizzard or another addon can legitimately replace the local scale. If
    -- that happens, adopt the new value as the baseline instead of multiplying
    -- our previous correction again.
    if not state or not state.applied
        or math.abs(current - state.applied) >= 0.00001 then
        state = {
            original = current,
            owner = namePlate,
            unitToken = namePlate.unitToken or scaleFrame.unit,
        }
        trackedNamePlateFrames[scaleFrame] = state
    end
    -- Enemy, friendly, selected and distance-scaled nameplates can have
    -- different C++-owned base scales. A single multiplier therefore makes
    -- one class too large or too small. Normalize each UnitFrame against its
    -- own parent so its final effective scale matches Blizzard's HUD preview.
    local desired = state.original * targetEffectiveScale / parentEffectiveScale
    -- Friendly base frames can expose smaller current bounds than the native
    -- Size preset even though they share the same Blizzard setup options.
    -- Use the read-only native dimensions for the explicit UnitFrame bounds;
    -- never feed these values back through SetNamePlateSize.
    local width, height = ReadNamePlateDimensions()
    if not width or not height then
        local widthOK, fallbackWidth = pcall(namePlate.GetWidth, namePlate)
        local heightOK, fallbackHeight = pcall(namePlate.GetHeight, namePlate)
        if not widthOK or not heightOK or not ValidPositive(fallbackWidth)
            or not ValidPositive(fallbackHeight) then return false end
        width, height = fallbackWidth, fallbackHeight
    end
    -- SetAllPoints resolves the child's local width inversely to its scale,
    -- cancelling horizontal compensation while fixed-height regions grow.
    -- Give the child explicit native bounds before scaling so both axes use
    -- the same factor. RestoreTrackedNamePlateFrame returns Blizzard's anchor
    -- contract before the pooled frame can be reused by the options preview.
    local boundsOK = pcall(function()
        scaleFrame:ClearAllPoints()
        scaleFrame:SetPoint("CENTER", namePlate, "CENTER", 0, 0)
        scaleFrame:SetSize(width, height)
    end)
    if not boundsOK then return false end
    state.detached = true
    if math.abs(current - desired) >= 0.00001 then
        if not pcall(scaleFrame.SetScale, scaleFrame, desired) then return false end
    end
    state.applied = desired
    return true
end

function Viewport:ApplyNamePlateVisualScale(metrics)
    if not Offhand.db or not Offhand.db.enabled or not metrics or not metrics.isSpanned then
        self:RestoreNamePlateVisualScale()
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        if not self.namePlateVisualPending and type(Offhand.RunOrQueueCombat) == "function" then
            self.namePlateVisualPending = true
            Offhand:RunOrQueueCombat(function()
                Viewport.namePlateVisualPending = nil
                local live = Offhand.db and Offhand.db.enabled and Viewport:GetMetrics() or nil
                Viewport:ApplyNamePlateVisualScale(live)
            end)
        end
        return
    end
    self.namePlateVisualPending = nil
    if not C_NamePlate or type(C_NamePlate.GetNamePlates) ~= "function" then return end
    local ok, namePlates = pcall(C_NamePlate.GetNamePlates)
    if not ok or type(namePlates) ~= "table" then return end

    -- The C++ nameplate frame owns both its dimensions and its base scale.
    -- Changing either produces stretching or is overwritten by the client.
    -- Compensate only the Lua UnitFrame contents, using the same scale as the
    -- HUD preview so the selected Blizzard Size remains visually consistent.
    local targetEffectiveScale = DesiredHUDScale(metrics)
    if not targetEffectiveScale then return end
    local count = 0
    for _, namePlate in pairs(namePlates) do
        if self:ApplyNamePlateFrame(namePlate, targetEffectiveScale) then count = count + 1 end
    end
    self.namePlateCompensationRatio = targetEffectiveScale
    self.namePlateVisualFrameCount = count
end

function Viewport:ScheduleNamePlateVisualScale()
    if self.namePlateVisualScheduled then return end
    self.namePlateVisualScheduled = true
    local function apply()
        Viewport.namePlateVisualScheduled = nil
        local metrics = Offhand.db and Offhand.db.enabled and Viewport:GetMetrics() or nil
        Viewport:ApplyNamePlateVisualScale(metrics)
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, apply) else apply() end
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
    local topology, topologyStatus = self:GetCompanionTopology(pw, ph, sw, sh)
    if topology then
        local companionVersionStatus, companionVersion, expectedCompanionVersion = CompanionVersionStatus(topology)
        pw, ph = tonumber(topology.physicalWidth), tonumber(topology.physicalHeight)
        local ux, uy = sw / pw, sh / ph
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
            companionVersionStatus = companionVersionStatus,
            companionVersion = companionVersion,
            expectedCompanionVersion = expectedCompanionVersion,
        }
    elseif self:IsRecoveryTopologyStatus(topologyStatus) then
        return {
            screenWidth = sw, screenHeight = sh, physicalWidth = pw, physicalHeight = ph,
            deckWidth = 0, workspaceWidth = 0, workspaceHeight = 0,
            workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 0, workspaceTop = 0,
            gameWidth = sw, gameHeight = sh, gameLeft = 0, gameBottom = 0,
            gameRight = sw, gameTop = sh, gamePixelLeft = 0, gamePixelBottom = 0,
            gamePixelWidth = pw, gamePixelHeight = ph, hudScale = 1, bezel = 0,
            preset = preset, actualAR = pw / ph, arMode = "NATIVE", isSpanned = false,
            companionTopology = false, topologyStatus = topologyStatus,
        }
    end

    local ux, uy = sw / pw, sh / ph
    
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
    -- Friendly Retail plates can remain visible while their name CVar is off,
    -- producing a blank bar until the unit is selected. This is a visibility
    -- invariant, not span compensation: keep names enabled for the whole time
    -- Offhand is enabled, including a restored/unspanned window, and restore the
    -- player's exact preference only when Offhand itself is disabled or unloaded.
    ManageFriendlyPlayerNames(db)
    if not db.enabled or (metrics and not metrics.isSpanned) then
        if self.originalScale or self.originalWorldScale or db.originalUiScale
            or db.originalWorldTextScale or db.originalNameplateSize then
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
                if db.originalWorldTextScale then
                    local _, availableName = ReadWorldTextScale()
                    WriteNumericCVar(db.originalWorldTextScaleCVar or availableName
                        or "WorldTextScale", db.originalWorldTextScale)
                end
                if db.originalNameplateSize then
                    WriteNumericCVar("nameplateSize", db.originalNameplateSize)
                end
                if WorldFrame and WorldFrame.SetScale and self.originalWorldScale then
                    WorldFrame:SetScale(self.originalWorldScale)
                end
            end)
            self.originalScale = nil
            self.originalWorldScale = nil
            db.originalUiScale = nil
            db.originalUseUiScale = nil
            db.originalWorldTextScale = nil
            db.originalWorldTextScaleCVar = nil
            db.originalNameplateSize = nil
            self.scaling=false
        end
        self:RestoreNamePlateVisualScale()
        return
    end
    local m=metrics or self:GetMetrics()
    local desired=DesiredHUDScale(m)
    
    if not self.originalScale then
        self.originalScale = UIParent:GetScale()
    end
    if WorldFrame and WorldFrame.GetScale and not self.originalWorldScale then
        self.originalWorldScale = WorldFrame:GetScale()
    end
    local currentWorldTextScale, worldTextScaleCVar = ReadWorldTextScale()
    if currentWorldTextScale then
        if not db.originalWorldTextScale then
            db.originalWorldTextScale = currentWorldTextScale
        end
        if not db.originalWorldTextScaleCVar then
            db.originalWorldTextScaleCVar = worldTextScaleCVar
        end
    end
    -- Migrate the previous beta's discrete-preset workaround back to the
    -- player's exact setting. Per-frame visual scaling below provides
    -- continuous compensation without changing the Size selection or native
    -- stacking bounds.
    if db.originalNameplateSize then
        WriteNumericCVar("nameplateSize", db.originalNameplateSize)
        db.originalNameplateSize = nil
    end

    -- Keep WorldFrame native. Retail hides protected friendly nameplates from
    -- addon enumeration inside instances, so shrinking this shared root makes
    -- them smaller than accessible enemy plates. Forever 1.60 also proved that
    -- its engine-rendered damage/XP text ignores WorldFrame scale, so mutating
    -- the root there adds risk without correcting the reported text.
    local uiNeedsWrite = math.abs(UIParent:GetScale()-desired) >= 0.00001
    -- Damage numbers and other engine-owned world text are rendered against
    -- the complete spanned window rather than the bounded WorldFrame. Live
    -- comparison shows equal-height spans already render at the native size;
    -- only mixed-height layouts use the Mainhand visual baseline. Preserve the
    -- player's native value as the multiplier and apply explicit fine tuning.
    local worldTextRatio = WorldTextCompensationRatio(m)
    local desiredWorldTextScale = db.originalWorldTextScale
        and db.originalWorldTextScale * worldTextRatio or nil
    local worldTextNeedsWrite = currentWorldTextScale and desiredWorldTextScale
        and math.abs(currentWorldTextScale - desiredWorldTextScale) >= 0.00001
    if not uiNeedsWrite and not worldTextNeedsWrite then
        self:ApplyNamePlateVisualScale(m)
        return
    end
    self.scaling=true
    local ok,err=pcall(function() 
        -- Keep the native CVar separate: client clamping can otherwise cause
        -- every display notification to write it again.
        if uiNeedsWrite then UIParent:SetScale(desired) end
        if worldTextNeedsWrite then
            WriteNumericCVar(worldTextScaleCVar, desiredWorldTextScale)
        end
    end)
    self.scaling=false
    if not ok then error(err) end
    -- Parent effective scales are authoritative only after both roots have
    -- reached their new values; normalizing before this point uses stale
    -- enemy/friendly scales on the first application.
    self:ApplyNamePlateVisualScale(m)
end

function Viewport:IsDualActive()
    return Offhand.db and Offhand.db.enabled
end

-- Keep the raw Companion handoff separate from the applied metrics. When the
-- generated topology is valid but WoW still reports its old bordered-window
-- dimensions, GetMetrics deliberately enters safe single-screen recovery and
-- therefore cannot describe why the exact topology was rejected.
function Viewport:GetTopologyDiagnostics()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local pw, ph = GetPhysicalScreenSize()
    if not pw or pw <= 0 or not ph or ph <= 0 then pw, ph = sw, sh end
    local topology, status = self:GetCompanionTopology(pw, ph, sw, sh)
    local raw = _G.OffhandCompanionTopology
    local loaded = type(raw) == "table"
    return {
        status = status,
        loaded = loaded,
        schema = loaded and tonumber(raw.schema) or nil,
        generatedAt = loaded and raw.generatedAt or nil,
        companionVersion = loaded and raw.companionVersion or nil,
        expectedWidth = loaded and tonumber(raw.physicalWidth) or nil,
        expectedHeight = loaded and tonumber(raw.physicalHeight) or nil,
        liveWidth = tonumber(pw) or 0,
        liveHeight = tonumber(ph) or 0,
        canvasWidth = tonumber(sw) or 0,
        canvasHeight = tonumber(sh) or 0,
        accepted = topology ~= nil,
    }
end

local function DiagnosticCVar(name)
    local function read(getter)
        if type(getter) ~= "function" then return nil end
        local ok, value = pcall(getter, name)
        return ok and value ~= nil and tostring(value) or nil
    end
    return read(GetCVar) or read(C_CVar and C_CVar.GetCVar) or "unavailable"
end

local function DiagnosticCVarFallback(primary, fallback)
    local value = DiagnosticCVar(primary)
    if value == "unavailable" and fallback then
        value = DiagnosticCVar(fallback)
    end
    return value
end

-- Read-only renderer evidence for performance reports. The physical dimensions
-- describe the bounding surface Windows gives the one spanned WoW window; they
-- do not claim that every pixel receives the same 3D workload. In particular,
-- gxWindowedResolution can remain the saved pre-span window size after an
-- external SetWindowPos and must not be presented as a live backbuffer size.
function Viewport:GetPerformanceDiagnostics(metrics)
    local m = metrics or self:GetMetrics()
    local worldTextScale, worldTextScaleCVar = ReadWorldTextScale()
    local namePlateWidth, namePlateHeight = ReadNamePlateDimensions()
    local namePlateCount, namePlateForbiddenCount = 0, 0
    local namePlateSample
    if C_NamePlate and type(C_NamePlate.GetNamePlates) == "function" then
        local ok, namePlates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(namePlates) == "table" then
            for _, namePlate in pairs(namePlates) do
                namePlateCount = namePlateCount + 1
                local forbidden = FrameIsForbidden(namePlate)
                if forbidden then namePlateForbiddenCount = namePlateForbiddenCount + 1 end
                if not namePlateSample then
                    local unitFrame = namePlate and namePlate.UnitFrame
                    local state = unitFrame and trackedNamePlateFrames[unitFrame] or nil
                    namePlateSample = {
                        forbidden = forbidden,
                        localScale = ReadFrameScale(namePlate),
                        effectiveScale = ReadFrameEffectiveScale(namePlate),
                        originalScale = state and state.original or nil,
                        appliedScale = state and state.applied or nil,
                        unitLocalScale = ReadFrameScale(unitFrame),
                        unitEffectiveScale = ReadFrameEffectiveScale(unitFrame),
                    }
                end
            end
        end
    end
    local spanPixels = math.max(0, tonumber(m.physicalWidth) or 0)
        * math.max(0, tonumber(m.physicalHeight) or 0)
    local mainhandPixels = math.max(0, tonumber(m.gamePixelWidth) or 0)
        * math.max(0, tonumber(m.gamePixelHeight) or 0)
    local fps
    if GetFramerate then
        local ok, value = pcall(GetFramerate)
        if ok then fps = tonumber(value) end
    end
    return {
        fps = fps,
        spanPixels = spanPixels,
        mainhandPixels = mainhandPixels,
        boundsToMainhandRatio = mainhandPixels > 0 and spanPixels / mainhandPixels or 0,
        gxWindowedResolution = DiagnosticCVar("gxWindowedResolution"),
        renderScale = DiagnosticCVar("RenderScale"),
        resampleQuality = DiagnosticCVar("ResampleQuality"),
        gxApi = DiagnosticCVar("gxApi"),
        -- Retail exposes this as "vsync"; older branches have also used the
        -- gx-prefixed spelling. Keep one diagnostic field across both.
        gxVSync = DiagnosticCVarFallback("vsync", "gxVSync"),
        maxFPS = DiagnosticCVar("maxFPS"),
        maxFPSBk = DiagnosticCVar("maxFPSBk"),
        lowLatencyMode = DiagnosticCVar("LowLatencyMode"),
        msaaQuality = DiagnosticCVar("MSAAQuality"),
        msaaAlphaTest = DiagnosticCVar("MSAAAlphaTest"),
        antiAliasingMode = DiagnosticCVar("ffxAntiAliasingMode"),
        cmaa2Quality = DiagnosticCVar("CMAA2Quality"),
        textureFilteringMode = DiagnosticCVar("textureFilteringMode"),
        dynamicRenderScale = DiagnosticCVar("DynamicRenderScale"),
        resampleAlwaysSharpen = DiagnosticCVar("ResampleAlwaysSharpen"),
        resampleSharpness = DiagnosticCVar("ResampleSharpness"),
        worldTextScale = worldTextScale and tostring(worldTextScale) or "unavailable",
        worldTextScaleCVar = worldTextScaleCVar or "unavailable",
        originalWorldTextScale = Offhand.db and Offhand.db.originalWorldTextScale or nil,
        worldTextMethod = worldTextScale and "CVAR" or "UNMANAGED",
        worldFrameLocalScale = ReadFrameScale(WorldFrame),
        worldFrameEffectiveScale = ReadFrameEffectiveScale(WorldFrame),
        worldTextHeightRatio = math.max(0, tonumber(m.gamePixelHeight) or 0)
            / math.max(1, tonumber(m.physicalHeight) or 1),
        worldTextCompensationEnabled = Offhand.db
            and Offhand.db.worldTextCompensation ~= false or false,
        worldTextFineTune = Number(Offhand.db and Offhand.db.worldTextScale,
            1, 0.50, 1.50),
        worldTextCompensationRatio = WorldTextCompensationRatio(m),
        nameplateGlobalScale = DiagnosticCVar("nameplateGlobalScale"),
        nameplateSize = DiagnosticCVar("nameplateSize"),
        originalNameplateSize = Offhand.db and Offhand.db.originalNameplateSize or nil,
        nameplateWidth = namePlateWidth,
        nameplateHeight = namePlateHeight,
        nameplateCompensationRatio = self.namePlateCompensationRatio,
        nameplateVisualFrameCount = self.namePlateVisualFrameCount or 0,
        nameplateCount = namePlateCount,
        nameplateForbiddenCount = namePlateForbiddenCount,
        nameplateSample = namePlateSample,
        nameplateHorizontalScale = DiagnosticCVar("NamePlateHorizontalScale"),
        nameplateVerticalScale = DiagnosticCVar("NamePlateVerticalScale"),
        nameplateLargerScale = DiagnosticCVar("nameplateLargerScale"),
        nameplateSelectedScale = DiagnosticCVar("nameplateSelectedScale"),
        nameplateShowFriends = DiagnosticCVar("nameplateShowFriends"),
        nameplateShowOnlyNames = DiagnosticCVar("nameplateShowOnlyNames"),
        unitNameFriendlyPlayerName = DiagnosticCVar("UnitNameFriendlyPlayerName"),
        unitNameEnemyPlayerName = DiagnosticCVar("UnitNameEnemyPlayerName"),
    }
end

function Viewport:CaptureDiagnostics()
    local m = self:GetMetrics()
    local snapshot = { metrics = m, frames = {} }
    -- Only WorldFrame participates in the PASS/MISMATCH result. Historical
    -- HUD rectangles were saved here but never displayed or consumed.
    for _, name in ipairs({"WorldFrame"}) do
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

function Offhand:InitializeViewport()
    if not Viewport.namePlateEventFrame and CreateFrame then
        local eventFrame = CreateFrame("Frame")
        Viewport.namePlateEventFrame = eventFrame
        for _, event in ipairs({"NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
            "PLAYER_TARGET_CHANGED", "DISPLAY_SIZE_CHANGED", "CVAR_UPDATE"}) do
            pcall(eventFrame.RegisterEvent, eventFrame, event)
        end
        eventFrame:SetScript("OnEvent", function(_, event, value)
            if event == "NAME_PLATE_UNIT_REMOVED" then
                Viewport:RestoreNamePlateUnit(value)
                return
            end
            local cvar = type(value) == "string" and string.lower(value) or ""
            if event == "CVAR_UPDATE" and (cvar == "unitnamefriendlyplayername"
                or cvar == "nameplateshowfriends") then
                if not Viewport.friendlyNameVisibilityScheduled then
                    Viewport.friendlyNameVisibilityScheduled = true
                    local function reapply()
                        Viewport.friendlyNameVisibilityScheduled = nil
                        Viewport:ApplyGlobalScale()
                    end
                    if C_Timer and C_Timer.After then C_Timer.After(0, reapply) else reapply() end
                end
            end
            if event ~= "CVAR_UPDATE" or string.find(cvar, "nameplate", 1, true) then
                Viewport:ScheduleNamePlateVisualScale()
            end
        end)
    end
    Viewport:ScheduleNamePlateVisualScale()
end
function Offhand:UpdateViewport() Viewport:Apply() end
