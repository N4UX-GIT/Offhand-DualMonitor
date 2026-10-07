--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Mainhand.lua: Mainhand geometry, safe frame gathering, and Edit Mode layout generation
--]]

local _, Offhand = ...

local Mainhand = {}
Offhand.Mainhand = Mainhand
Offhand.API = Offhand.API or {}

local anchor
local geometrySignature
local geometryRevision = 0
local geometryCallbacks = {}
local updatePending = false

local function Number(value)
    value = tonumber(value)
    if not value or value ~= value then return nil end
    return value
end

local function IsPlayerCombatRestricted()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat then
        local ok, active = pcall(UnitAffectingCombat, "player")
        if ok and active then return true end
    end
    return false
end

local function ValidMetrics(metrics)
    return type(metrics) == "table"
        and Number(metrics.gameLeft) and Number(metrics.gameBottom)
        and Number(metrics.gameRight) and Number(metrics.gameTop)
        and metrics.gameRight > metrics.gameLeft
        and metrics.gameTop > metrics.gameBottom
end

local function CurrentRect()
    local width = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local height = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and Offhand.Viewport:GetMetrics() or nil
    local active = Offhand.db and Offhand.db.enabled and metrics and metrics.isSpanned
        and ValidMetrics(metrics) or false
    if active then
        return {
            left = metrics.gameLeft, bottom = metrics.gameBottom,
            right = metrics.gameRight, top = metrics.gameTop,
            width = metrics.gameRight - metrics.gameLeft,
            height = metrics.gameTop - metrics.gameBottom,
            screenWidth = width, screenHeight = height,
            isSpanned = true,
        }
    end
    return {
        left = 0, bottom = 0, right = width, top = height,
        width = width, height = height,
        screenWidth = width, screenHeight = height,
        isSpanned = false,
    }
end

local function Signature(rect)
    return string.format("%.1f:%.1f:%.1f:%.1f:%.1f:%.1f:%s",
        rect.left, rect.bottom, rect.right, rect.top,
        UIParent:GetWidth(), UIParent:GetHeight(), rect.isSpanned and "1" or "0")
end

local function CopyRect(rect)
    local copy = {}
    for key, value in pairs(rect or {}) do copy[key] = value end
    return copy
end

function Mainhand:CreateAnchor()
    if anchor or not CreateFrame or not UIParent then return anchor end
    anchor = CreateFrame("Frame", "OffhandMainhandFrame", UIParent)
    anchor:SetFrameStrata("BACKGROUND")
    anchor:SetFrameLevel(0)
    if anchor.EnableMouse then anchor:EnableMouse(false) end
    anchor:SetAllPoints(UIParent)
    Offhand.mainhandFrame = anchor
    return anchor
end

local function NotifyGeometry(rect, reason)
    for owner, callback in pairs(geometryCallbacks) do
        local ok, keep = pcall(callback, CopyRect(rect), reason or "update", geometryRevision)
        if not ok or keep == false then geometryCallbacks[owner] = nil end
    end
end

function Mainhand:Update(reason)
    local region = self:CreateAnchor()
    if not region then return false end
    local rect = CurrentRect()
    local signature = Signature(rect)
    if signature == geometrySignature then return false end

    if InCombatLockdown and InCombatLockdown() then
        if not updatePending then
            updatePending = true
            local apply = function()
                updatePending = false
                Mainhand:Update("combat-ended")
            end
            if Offhand.RunOrQueueCombat then Offhand:RunOrQueueCombat(apply) end
        end
        return false
    end
    updatePending = false

    region:ClearAllPoints()
    region:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom)
    region:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", rect.right, rect.top)
    geometrySignature = signature
    geometryRevision = geometryRevision + 1
    self.rect = rect
    NotifyGeometry(rect, reason)
    return true
end

function Mainhand:GetRect()
    if not self.rect then self:Update("read") end
    return CopyRect(self.rect or CurrentRect())
end

function Mainhand:GetGeometrySignature()
    local rect = self:GetRect()
    return Signature(rect)
end

function Mainhand:GetGeometryRevision()
    return geometryRevision
end

function Offhand.API.GetMainhandFrame()
    return Mainhand:CreateAnchor()
end

function Offhand.API.GetMainhandRect()
    return Mainhand:GetRect()
end

function Offhand.API.GetGeometryRevision()
    return Mainhand:GetGeometryRevision()
end

function Offhand.API.RegisterGeometryCallback(owner, callback)
    if owner == nil or type(callback) ~= "function" then return false end
    geometryCallbacks[owner] = callback
    return true
end

function Offhand.API.UnregisterGeometryCallback(owner)
    geometryCallbacks[owner] = nil
end

-- Anchor an explicitly cooperating, unprotected frame to Mainhand. Offhand
-- never discovers or registers third-party frames automatically.
function Offhand.API.AnchorToMainhand(frame, point, relativePoint, x, y)
    if not frame or not frame.ClearAllPoints or not frame.SetPoint then return false, "frame" end
    if frame.IsForbidden and frame:IsForbidden() then return false, "forbidden" end
    if frame.IsProtected and frame:IsProtected() then return false, "protected" end
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    local region = Mainhand:CreateAnchor()
    if not region then return false, "unavailable" end
    point = point or "CENTER"
    relativePoint = relativePoint or point
    frame:ClearAllPoints()
    frame:SetPoint(point, region, relativePoint, x or 0, y or 0)
    return true
end

local editModeNames = {
    MainMenuBar = true, MainActionBar = true, StatusTrackingBarManager = true,
    MainMenuExpBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true,
    MultiBarLeft = true, MultiBarRight = true, StanceBar = true,
    PetActionBar = true, PossessActionBar = true, MinimapCluster = true,
    PlayerFrame = true, TargetFrame = true, FocusFrame = true, PartyFrame = true,
    PartyMemberFrame1 = true, CompactPartyFrame = true,
    CompactRaidFrameContainer = true, BuffFrame = true, BuffCluster = true,
    CastingBarFrame = true, PlayerCastingBarFrame = true,
    EssentialCooldownViewer = true, UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true, BottomManagedFrameContainer = true,
}

local function IsEditModeOwned(frame, name)
    if frame and frame.isManagedFrame == true then return true end
    return type(name) == "string" and (editModeNames[name]
        or name:match("^EditMode")
        or name:match("CooldownViewer")
        or name:match("ManagedFrameContainer")
        or name:match("^PartyMemberFrame")
        or name:match("^CompactPartyFrame")
        or name:match("^CompactRaidFrame")) or false
end

local function SafeGatherCandidate(frame)
    if not frame or frame == UIParent or frame == WorldFrame or frame == anchor
        or frame == Offhand.canvas then return false end
    if frame.IsForbidden and frame:IsForbidden() then return false end
    if frame.IsProtected and frame:IsProtected() then return false end
    if not frame.IsShown or not frame:IsShown() then return false end
    if not frame.IsMovable or not frame:IsMovable() then return false end
    if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return false end
    local name = frame.GetName and frame:GetName() or nil
    if IsEditModeOwned(frame, name) then return false end
    return true
end

local function Clamp(value, low, high)
    if high < low then return (low + high) / 2 end
    return math.max(low, math.min(value, high))
end

function Mainhand:GatherSafeUI()
    if IsPlayerCombatRestricted() then return false, "combat", 0, 0 end
    if Offhand.Canvas and Offhand.Canvas.GatherSafeUIToMainhand then
        return Offhand.Canvas:GatherSafeUIToMainhand()
    end
    -- Canvas consumes live viewport metrics. The fallback must do the same:
    -- the anchor rectangle may still contain its pre-topology value just after
    -- /reload even though Companion geometry is already active.
    local rect = CurrentRect()
    if not rect.isSpanned then return false, "span", 0, 0 end
    local parentScale = UIParent:GetEffectiveScale() or 1
    local candidates = {}
    for name in pairs(UIPanelWindows or {}) do
        if _G[name] then candidates[_G[name]] = true end
    end
    if UIParent.GetChildren then
        for _, child in ipairs({ UIParent:GetChildren() }) do candidates[child] = true end
    end

    local moved, skipped = 0, 0
    for frame in pairs(candidates) do
        local eligible = false
        local ok = pcall(function() eligible = SafeGatherCandidate(frame) end)
        if not ok or not eligible then
            skipped = skipped + 1
        else
            local placed = pcall(function()
                local scale = frame:GetEffectiveScale()
                local left, right = frame:GetLeft(), frame:GetRight()
                local bottom, top = frame:GetBottom(), frame:GetTop()
                if not scale or scale <= 0 or not left or not right or not bottom or not top then return end
                local factor = scale / parentScale
                left, right = left * factor, right * factor
                bottom, top = bottom * factor, top * factor
                if left >= rect.left and right <= rect.right
                    and bottom >= rect.bottom and top <= rect.top then return end
                local width, height = right - left, top - bottom
                local cx = Clamp((left + right) / 2,
                    rect.left + width / 2 + 8, rect.right - width / 2 - 8)
                local cy = Clamp((bottom + top) / 2,
                    rect.bottom + height / 2 + 8, rect.top - height / 2 - 8)
                frame:ClearAllPoints()
                frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / factor, cy / factor)
                moved = moved + 1
            end)
            if not placed then skipped = skipped + 1 end
        end
    end
    return true, nil, moved, skipped
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[DeepCopy(key, seen)] = DeepCopy(item, seen) end
    return copy
end

local function EditModeData()
    if not C_EditMode or type(C_EditMode.GetLayouts) ~= "function" then return nil end
    local ok, data = pcall(C_EditMode.GetLayouts)
    if not ok or type(data) ~= "table" or type(data.layouts) ~= "table" then return nil end
    return data
end

local function Presets()
    local manager = _G.EditModePresetLayoutManager
    if not manager or type(manager.GetCopyOfPresetLayouts) ~= "function" then return {} end
    local ok, layouts = pcall(manager.GetCopyOfPresetLayouts, manager)
    return ok and type(layouts) == "table" and layouts or {}
end

local function LayoutName(layout, fallback)
    local name = type(layout) == "table" and layout.layoutName or nil
    return type(name) == "string" and name:match("%S") and name or fallback
end

local function ResolveActiveLayout(data, presets)
    local active = tonumber(data and data.activeLayout)
    if not active then return nil end
    local offset = Offhand.isForever and 3 or #presets
    local customIndex = active - offset
    if customIndex >= 1 and data.layouts[customIndex] then
        return data.layouts[customIndex], active, customIndex, false
    end
    for index, layout in ipairs(presets) do
        if tonumber(layout.layoutIndex) == active or index == active then
            return layout, active, index, true
        end
    end
    if Offhand.isForever and active > 3 and data.layouts[active - 3] then
        return data.layouts[active - 3], active, active - 3, false
    end
    if not Offhand.isForever and data.layouts[active] then
        return data.layouts[active], active, active, false
    end
end

local function FindNamedLayout(data, presets, wanted)
    if type(wanted) ~= "string" then return nil end
    local lower = string.lower(wanted)
    local offset = Offhand.isForever and 3 or #presets
    for index, layout in ipairs(data.layouts) do
        if string.lower(LayoutName(layout, "")) == lower then
            return layout, offset + index, index, false
        end
    end
    for index, layout in ipairs(presets) do
        if string.lower(LayoutName(layout, "")) == lower then
            return layout, tonumber(layout.layoutIndex) or index, index, true
        end
    end
end

local function PointBase(point, rect)
    point = type(point) == "string" and point or "CENTER"
    local x = point:find("LEFT", 1, true) and rect.left
        or point:find("RIGHT", 1, true) and rect.right
        or (rect.left + rect.right) / 2
    local y = point:find("BOTTOM", 1, true) and rect.bottom
        or point:find("TOP", 1, true) and rect.top
        or (rect.bottom + rect.top) / 2
    return x, y
end

local function TransformLayout(layout, rect)
    local screen = { left = 0, bottom = 0, right = UIParent:GetWidth(), top = UIParent:GetHeight() }
    local moved = 0
    for _, entry in ipairs(layout.systems or {}) do
        local info = entry.anchorInfo
        if type(info) == "table" and (info.relativeTo == nil or info.relativeTo == "UIParent")
            and type(info.offsetX) == "number" and type(info.offsetY) == "number" then
            local relativePoint = info.relativePoint or info.point or "CENTER"
            local sx, sy = PointBase(relativePoint, screen)
            local gx, gy = PointBase(relativePoint, rect)
            info.offsetX = info.offsetX + gx - sx
            info.offsetY = info.offsetY + gy - sy
            entry.isInDefaultPosition = false
            moved = moved + 1
        end
    end
    return moved
end

local function UniqueLayoutName(data)
    local player = UnitName and UnitName("player") or nil
    local base = "Offhand - Mainhand" .. (player and (" - " .. player) or "")
    local names = {}
    for _, layout in ipairs(data.layouts) do names[string.lower(LayoutName(layout, ""))] = true end
    if not names[string.lower(base)] then return base end
    for number = 2, 99 do
        local candidate = base .. " (" .. number .. ")"
        if not names[string.lower(candidate)] then return candidate end
    end
    return base .. " - " .. tostring(time and time() or geometryRevision)
end

local function ControllerMode(presets)
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    return gamepad ~= nil and type(presets[1]) == "table"
        and presets[1].interfaceStyle == gamepad
end

local function EnsureEditModeLoaded()
    if C_EditMode and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.SaveLayouts) == "function" then return end
    local load = C_AddOns and C_AddOns.LoadAddOn or _G.LoadAddOn
    if type(load) == "function" then pcall(load, "Blizzard_EditMode") end
end

function Mainhand:CreateOrUpdateEditModeLayout()
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return false, "disabled" end
    local rect = self:GetRect()
    if not rect.isSpanned then return false, "span" end
    EnsureEditModeLoaded()
    if not C_EditMode or type(C_EditMode.GetLayouts) ~= "function" then
        return false, "read-api"
    end
    if type(C_EditMode.SaveLayouts) ~= "function" then return false, "save-api" end
    local manager = _G.EditModeManagerFrame
    if manager and ((manager.IsShown and manager:IsShown()) or manager.editModeActive) then
        return false, "open"
    end

    local data = EditModeData()
    if not data then return false, "unavailable" end
    local presets = Presets()
    if #presets == 0 then return false, "presets" end
    if ControllerMode(presets) then return false, "gamepad" end
    if type(OffhandCharDB) ~= "table" then return false, "state" end

    local record = OffhandCharDB.mainhandLayout
    local source, sourceID, sourceIndex, sourcePreset
    if type(record) == "table" and record.sourcePreset and tonumber(record.sourceID) then
        local wanted = tonumber(record.sourceID)
        for index, layout in ipairs(presets) do
            if tonumber(layout.layoutIndex) == wanted or index == wanted then
                source, sourceID, sourceIndex, sourcePreset = layout, wanted, index, true
                break
            end
        end
    elseif type(record) == "table" and type(record.sourceName) == "string" then
        source, sourceID, sourceIndex, sourcePreset = FindNamedLayout(data, presets, record.sourceName)
    end
    if not source then
        source, sourceID, sourceIndex, sourcePreset = ResolveActiveLayout(data, presets)
    end
    if not source then return false, "source" end

    local generatedName = type(record) == "table" and record.generatedName or nil
    local generated, _, generatedIndex = FindNamedLayout(data, presets, generatedName)
    if not generatedName then generatedName = UniqueLayoutName(data) end

    local layout = DeepCopy(source)
    local moved = TransformLayout(layout, rect)
    if moved == 0 then return false, "already", LayoutName(source, "layout"), 0 end
    layout.layoutName = generatedName
    layout.layoutIndex = nil
    if Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account ~= nil then
        layout.layoutType = Enum.EditModeLayoutType.Account
    end

    local targetIndex = generated and generatedIndex or (#data.layouts + 1)
    if not generated then
        local maximum = Constants and Constants.EditModeConsts
            and Constants.EditModeConsts.EditModeMaxLayoutsPerType
        if type(maximum) == "number" and #data.layouts >= maximum then return false, "maximum" end
    end
    local writeData = DeepCopy(data)
    writeData.layouts[targetIndex] = layout

    local called, result = pcall(C_EditMode.SaveLayouts, writeData)
    if not called or result == false then return false, "save" end
    local targetID = (Offhand.isForever and 3 or #presets) + targetIndex
    local active = tonumber(writeData.activeLayout) == targetID
    if not active and type(C_EditMode.SetActiveLayout) == "function" then
        called, result = pcall(C_EditMode.SetActiveLayout, targetID)
        active = called and result ~= false
    end
    -- Some Edit Mode branches expose the layout-added transaction instead of
    -- SetActiveLayout to addon code. It is also Blizzard's native path after a
    -- newly imported layout has been saved. Pass the custom-array index here,
    -- not Forever's global layout identifier.
    if not active and not generated and type(C_EditMode.OnLayoutAdded) == "function" then
        called, result = pcall(C_EditMode.OnLayoutAdded, targetIndex, true, true)
        active = called and result ~= false
    end
    if not active then
        local confirmed = EditModeData()
        active = confirmed and tonumber(confirmed.activeLayout) == targetID or false
    end
    if not active then return false, "activate-api" end

    OffhandCharDB.mainhandLayout = {
        version = 1,
        sourceName = LayoutName(source, sourcePreset and ("Preset " .. tostring(sourceID)) or "Layout"),
        sourceID = sourceID,
        sourcePreset = sourcePreset and true or false,
        generatedName = generatedName,
        generatedID = targetID,
        geometrySignature = self:GetGeometrySignature(),
        movedSystems = moved,
    }
    if Offhand.isForever then
        OffhandCharDB.foreverEditModeLayoutName = generatedName
        OffhandCharDB.foreverEditModeLayoutID = targetID
        OffhandCharDB.foreverEditModeLegacyRecovery = nil
        OffhandCharDB.foreverEditModeRecovery = nil
        if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
            Offhand.ForeverPersistence:SaveProfileSnapshot(true)
        end
    end
    return true, generatedName, moved
end

function Mainhand:GetLayoutStatus()
    local record = type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayout or nil
    if type(record) ~= "table" then return { configured = false } end
    return {
        configured = true,
        sourceName = record.sourceName,
        generatedName = record.generatedName,
        generatedID = record.generatedID,
        movedSystems = record.movedSystems,
        currentGeometry = record.geometrySignature == self:GetGeometrySignature(),
    }
end

function Mainhand:PromptReload()
    if not StaticPopupDialogs or not StaticPopup_Show then return false end
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD =
        StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD or {
            button1 = RELOADUI or "Reload UI",
            button2 = LATER or "Later",
            OnAccept = function() ReloadUI() end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD.text =
        Offhand.L["MAINHAND_LAYOUT_RELOAD_TEXT"]
    StaticPopup_Show("OFFHAND_MAINHAND_LAYOUT_RELOAD")
    return true
end

local events = CreateFrame and CreateFrame("Frame") or nil
if events then
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "DISPLAY_SIZE_CHANGED",
        "UI_SCALE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event)
        Mainhand:Update(event)
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
            C_Timer.After(0, function() Mainhand:Update("settled") end)
        end
    end)
end
