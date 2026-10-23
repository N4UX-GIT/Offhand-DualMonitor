--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Mainhand.lua: Mainhand geometry, safe frame gathering, and Edit Mode layout generation
--]]

local _, Offhand = ...

local Mainhand = assert(Offhand.Mainhand, "Offhand Mainhand geometry must load before Mainhand")
local Geometry = assert(
    Offhand.MainhandGeometry,
    "Offhand Mainhand geometry must load before Mainhand"
)
local Number = Geometry.Number
local IsPlayerCombatRestricted = Geometry.IsPlayerCombatRestricted
local CurrentRect = Geometry.GetCurrentRect
local gamepadMainMenuController
local gamepadMainMenuFrame
local gamepadMainMenuState = setmetatable({}, { __mode = "k" })
local gamepadMainMenuStatus = "unavailable"
local gamepadReticleStatus = "unavailable"
local gamepadDestinationPanelState = setmetatable({}, { __mode = "k" })
local gamepadDestinationPanelStatus = {}
local gamepadDestinationDragHandles = setmetatable({}, { __mode = "k" })
local GAMEPAD_INTERFACE_SETTLE_SECONDS = 1.0
local GAMEPAD_ACTIVE_PANEL_INTERVAL = 0.05
local GAMEPAD_INACTIVE_PANEL_INTERVAL = 0.20

local editModeNames = {
    MainMenuBar = true, MainActionBar = true, StatusTrackingBarManager = true,
    MainMenuExpBar = true, MultiBarBottomLeft = true, MultiBarBottomRight = true,
    MultiBarLeft = true, MultiBarRight = true, StanceBar = true,
    PetActionBar = true, PossessActionBar = true, MinimapCluster = true,
    PlayerFrame = true, TargetFrame = true, FocusFrame = true, PetFrame = true,
    BossTargetFrameContainer = true, PartyFrame = true,
    PartyMemberFrame1 = true, CompactPartyFrame = true,
    CompactRaidFrameContainer = true, BuffFrame = true, BuffCluster = true,
    CastingBarFrame = true, PlayerCastingBarFrame = true,
    ExtraAbilityContainer = true, ExtraActionBarFrame = true, ZoneAbilityFrame = true,
    EncounterBar = true, UIWidgetPowerBarContainerFrame = true, LossOfControlFrame = true,
    MainMenuBarVehicleLeaveButton = true, VehicleExitButton = true,
    TotemFrame = true, MultiCastActionBarFrame = true, PersonalResourceDisplayFrame = true,
    DurabilityFrame = true, DamageMeter = true,
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
    if not frame or frame == UIParent or frame == WorldFrame or Geometry.IsAnchor(frame)
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

local function TransformLayout(layout, rect, skipEntry)
    local screen = { left = 0, bottom = 0, right = UIParent:GetWidth(), top = UIParent:GetHeight() }
    local moved, transformed = 0, {}
    for index, entry in ipairs(layout.systems or {}) do
        local info = entry.anchorInfo
        if not (skipEntry and skipEntry(entry))
            and type(info) == "table" and (info.relativeTo == nil or info.relativeTo == "UIParent")
            and type(info.offsetX) == "number" and type(info.offsetY) == "number" then
            local relativePoint = info.relativePoint or info.point or "CENTER"
            local sx, sy = PointBase(relativePoint, screen)
            local gx, gy = PointBase(relativePoint, rect)
            info.offsetX = info.offsetX + gx - sx
            info.offsetY = info.offsetY + gy - sy
            entry.isInDefaultPosition = false
            moved = moved + 1
            transformed[index] = true
        end
    end
    return moved, transformed
end

local function FirstEnumValue(values, names)
    if type(values) ~= "table" then return nil end
    for _, name in ipairs(names) do
        if values[name] ~= nil then return values[name] end
    end
end

local function IsGroupRecoveryFrame(name)
    return name == "PartyFrame" or name == "PartyMemberFrame1"
        or name == "CompactPartyFrame" or name == "CompactRaidFrameContainer"
end

local function GroupRecoveryKind(name)
    if name == "CompactRaidFrameContainer" then return "raid" end
    if IsGroupRecoveryFrame(name) then return "party" end
end

-- Party and raid entries on Forever can be relative to another Edit Mode
-- system rather than UIParent. The generic translation deliberately skips
-- those relationships, which can leave the preview in a mixed-height span's
-- physical void. Rebase only a default non-UIParent group entry, or an entry
-- covered by the player's explicit Repair HUD action. Blizzard remains the
-- owner and applies the serialized anchor during its layout transaction.
local function RefineGroupHUDLayout(layout, rect, sourceDefaults, transformed, repairFrameName)
    local systems = Enum and Enum.EditModeSystem
    local indices = Enum and Enum.EditModeUnitFrameSystemIndices
    local unitSystem = systems and systems.UnitFrame
    if unitSystem == nil or type(indices) ~= "table" then return 0, 0 end

    local partyIndex = FirstEnumValue(indices, { "Party", "PartyFrame", "PartyFrames" })
    local raidIndex = FirstEnumValue(indices, { "Raid", "RaidFrame", "RaidFrames" })
    if partyIndex == nil and raidIndex == nil then return 0, 0 end

    local targetKind = GroupRecoveryKind(repairFrameName)
    local moved, repaired = 0, 0
    for index, entry in ipairs(layout.systems or {}) do
        local partyEntry = entry.system == unitSystem and partyIndex ~= nil
            and entry.systemIndex == partyIndex
        local raidEntry = entry.system == unitSystem and raidIndex ~= nil
            and entry.systemIndex == raidIndex
        local groupEntry = partyEntry or raidEntry
        local repairEntry = targetKind == "party" and partyEntry
            or targetKind == "raid" and raidEntry
        local info = groupEntry and entry.anchorInfo or nil
        local systemRelative = type(info) == "table"
            and info.relativeTo ~= nil and info.relativeTo ~= "UIParent"
        if groupEntry and type(info) == "table"
            and (repairEntry or (sourceDefaults[index] and systemRelative)) then
            info.point = "TOPLEFT"
            info.relativeTo = "UIParent"
            info.relativePoint = "BOTTOMLEFT"
            info.offsetX = rect.left + 24
            info.offsetY = rect.top - math.min(180, rect.height * 0.15)
            entry.isInDefaultPosition = false
            if repairEntry then repaired = repaired + 1 end
            if not transformed[index] then moved = moved + 1 end
        end
    end
    return moved, repaired
end

local function PointFractions(point)
    point = type(point) == "string" and point or "CENTER"
    local x = point:find("LEFT", 1, true) and 0
        or point:find("RIGHT", 1, true) and 1 or 0.5
    local y = point:find("BOTTOM", 1, true) and 0
        or point:find("TOP", 1, true) and 1 or 0.5
    return x, y
end

local function FrameSize(frame, fallbackWidth, fallbackHeight)
    local width, height
    if frame and frame.GetWidth then
        local ok, value = pcall(frame.GetWidth, frame)
        if ok and type(value) == "number" and value > 0 then width = value end
    end
    if frame and frame.GetHeight then
        local ok, value = pcall(frame.GetHeight, frame)
        if ok and type(value) == "number" and value > 0 then height = value end
    end
    return width or fallbackWidth, height or fallbackHeight
end

local function FramePoint(frame, fallback)
    if frame and frame.GetPoint then
        local ok, point = pcall(frame.GetPoint, frame, 1)
        if ok and type(point) == "string" then return point end
    end
    return type(fallback) == "string" and fallback or "CENTER"
end

local function FrameEdge(frame, method)
    if frame and type(frame[method]) == "function" then
        local ok, value = pcall(frame[method], frame)
        if ok and type(value) == "number" then return value end
    end
end

local function PlaceFromMainAnchor(entry, mainAnchor, targetFrame,
    fallbackWidth, fallbackHeight, left, bottom)
    if type(entry) ~= "table" or type(mainAnchor) ~= "table"
        or type(mainAnchor.offsetX) ~= "number"
        or type(mainAnchor.offsetY) ~= "number" then return false end
    local current = entry.anchorInfo
    local targetPoint = FramePoint(targetFrame, current and current.point)
    local width, height = FrameSize(targetFrame, fallbackWidth, fallbackHeight)
    local px, py = PointFractions(targetPoint)
    local info = DeepCopy(mainAnchor)
    -- Keep Action Bar 1's proven UIParent reference point, but retain the target
    -- frame's own attachment point. Forever's systems use different fixed self
    -- points; treating every entry like Action Bar 1 moves wide bars into the
    -- Offhand canvas.
    info.point = targetPoint
    info.offsetX = mainAnchor.offsetX + left + (width * px)
    info.offsetY = mainAnchor.offsetY + bottom + (height * py)
    entry.anchorInfo = info
    entry.isInDefaultPosition = false
    return true
end

-- Refine only HUD systems that were still in their source layout's default
-- position. Explicitly customized source entries remain untouched. Enum lookup
-- keeps this capability-based across Forever and Retail without assuming that
-- numeric system identifiers are identical between client versions.
local function RefineGamepadStatusBars(layout, rect, sourceDefaults)
    local systems = Enum and Enum.EditModeSystem
    local statusSystem = systems and systems.StatusTrackingBar
    if statusSystem == nil then return 0 end
    local statusIndices = Enum.EditModeStatusTrackingBarSystemIndices
    local secondary = statusIndices and statusIndices.StatusTrackingBar2
    local _, primaryHeight = FrameSize(_G.MainStatusTrackingBarContainer, 400, 14)
    local screen = { left = 0, bottom = 0,
        right = UIParent:GetWidth(), top = UIParent:GetHeight() }
    local sx, sy = PointBase("BOTTOM", screen)
    local gx, gy = PointBase("BOTTOM", rect)
    local refined = 0
    for index, entry in ipairs(layout.systems or {}) do
        if sourceDefaults[index] and entry.system == statusSystem then
            local isSecondary = secondary ~= nil and entry.systemIndex == secondary
            entry.anchorInfo = {
                point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM",
                offsetX = gx - sx,
                offsetY = gy - sy + 12 + (isSecondary and (primaryHeight + 4) or 0),
            }
            entry.isInDefaultPosition = false
            refined = refined + 1
        end
    end
    return refined
end

local function RefineStandardHUDLayout(layout, rect, sourceDefaults, controllerLayout)
    -- The native Gamepad preset has GamepadMainActionBar instead of keyboard
    -- ActionBar MainBar. Its manager-relative status bars must be handled
    -- before any keyboard-action-bar prerequisites or early returns.
    local refined = controllerLayout and RefineGamepadStatusBars(layout, rect, sourceDefaults) or 0
    local systems = Enum and Enum.EditModeSystem
    local indices = Enum and Enum.EditModeActionBarSystemIndices
    if type(systems) ~= "table" or type(indices) ~= "table" then return refined end
    local actionSystem = systems.ActionBar
    local statusSystem = systems.StatusTrackingBar
    local extraSystem = systems.ExtraAbilities or systems.ExtraAbility
    local vehicleSystem = systems.VehicleLeaveButton or systems.VehicleExitButton
    local encounterSystem = systems.EncounterBar
    local lossOfControlSystem = systems.LossOfControl or systems.LossOfControlFrame
    local minimapSystem = systems.Minimap
    local buffSystem = FirstEnumValue(systems,
        { "BuffFrame", "BuffsAndDebuffs", "AuraFrame" })
    local damageMeterSystem = FirstEnumValue(systems,
        { "DamageMeter", "DamageMeterFrame" })
    local mainIndex = indices.MainBar
    -- ClassBar is not a safe stance fallback on Forever: it can identify the
    -- empty MultiCast/Totem preview, whose native tooltip rejects a nil spell.
    local stanceIndex = indices.StanceBar or indices.Stance
    local petIndex = indices.PetActionBar or indices.PetBar
    local possessIndex = indices.PossessActionBar or indices.PossessBar
    if actionSystem == nil or mainIndex == nil then return refined end

    local mainAnchor, lossOfControlAnchor
    for index, entry in ipairs(layout.systems or {}) do
        if sourceDefaults[index] and entry.system == actionSystem
            and entry.systemIndex == mainIndex and type(entry.anchorInfo) == "table" then
            mainAnchor = entry.anchorInfo
        elseif sourceDefaults[index] and lossOfControlSystem ~= nil
            and entry.system == lossOfControlSystem and type(entry.anchorInfo) == "table" then
            lossOfControlAnchor = entry.anchorInfo
        end
    end
    if not mainAnchor then return refined end

    local mainFrame = _G.MainActionBar or _G.MainMenuBar
    local mainWidth, mainHeight = FrameSize(mainFrame, 1390, 50)
    local mainPX, mainPY = PointFractions(FramePoint(mainFrame, mainAnchor.point))
    local mainLeft = -(mainWidth * mainPX)
    local mainBottom = -(mainHeight * mainPY)
    local mainRight, mainTop = mainLeft + mainWidth, mainBottom + mainHeight
    local mainScreenLeft = FrameEdge(mainFrame, "GetLeft")
    local mainReferenceX = mainScreenLeft and (mainScreenLeft + mainWidth * mainPX) or nil
    local actionLeft = FrameEdge(_G.ActionButton1, "GetLeft") or mainScreenLeft
    local bagRight
    for _, name in ipairs({
        "MainMenuBarBackpackButton", "BagsBar", "MicroButtonAndBagsBar", "MainMenuBar",
    }) do
        bagRight = FrameEdge(_G[name], "GetRight")
        if bagRight then break end
    end
    local hudLeft = mainReferenceX and actionLeft and (actionLeft - mainReferenceX) or mainLeft
    local hudRight = mainReferenceX and bagRight and (bagRight - mainReferenceX) or mainRight
    local statusFrame = _G.StatusTrackingBarManager or _G.MainMenuExpBar
    local statusWidth, statusHeight = FrameSize(statusFrame, mainWidth, 14)
    local stanceFrame = _G.StanceBar or _G.ShapeshiftBarFrame
    local _, stanceHeight = FrameSize(stanceFrame, 252, 36)
    local petFrame = _G.PetActionBar or _G.PetActionBarFrame
    local vehicleFrame = _G.MainMenuBarVehicleLeaveButton or _G.VehicleExitButton
    local extraFrame = _G.ExtraAbilityContainer or _G.ExtraAbilityBar
    local possessFrame = _G.PossessActionBar or _G.PossessBarFrame
    local lossOfControlFrame = _G.LossOfControlFrame
    local encounterFrame = _G.EncounterBar or _G.UIWidgetPowerBarContainerFrame
    local stanceBottom = mainTop + statusHeight + 8

    for index, entry in ipairs(layout.systems or {}) do
        if sourceDefaults[index] then
            if not controllerLayout and statusSystem ~= nil and entry.system == statusSystem then
                -- Keyboard layouts align the complete XP/reputation bar
                -- with the main/bag bar, not merely Action Button 1.
                if PlaceFromMainAnchor(entry, mainAnchor, statusFrame,
                    mainWidth, 14, hudRight - statusWidth, mainTop + 3) then
                    refined = refined + 1
                end
            elseif stanceIndex ~= nil and entry.system == actionSystem
                and entry.systemIndex == stanceIndex then
                if PlaceFromMainAnchor(entry, mainAnchor, stanceFrame,
                    252, 36, hudLeft, stanceBottom) then
                    refined = refined + 1
                end
            elseif petIndex ~= nil and entry.system == actionSystem
                and entry.systemIndex == petIndex then
                if PlaceFromMainAnchor(entry, mainAnchor, petFrame,
                    400, 36, hudLeft, stanceBottom) then
                    refined = refined + 1
                end
            elseif extraSystem ~= nil and entry.system == extraSystem then
                local extraWidth = FrameSize(extraFrame, 256, 80)
                if PlaceFromMainAnchor(entry, mainAnchor, extraFrame,
                    256, 80, (mainLeft + mainRight - extraWidth) / 2,
                    mainTop + statusHeight + 18) then
                    refined = refined + 1
                end
            elseif vehicleSystem ~= nil and entry.system == vehicleSystem then
                if PlaceFromMainAnchor(entry, mainAnchor, vehicleFrame,
                    52, 52, hudLeft, stanceBottom + stanceHeight + 8) then
                    refined = refined + 1
                end
            elseif possessIndex ~= nil and entry.system == actionSystem
                and entry.systemIndex == possessIndex then
                if PlaceFromMainAnchor(entry, mainAnchor, possessFrame,
                    400, 36, hudLeft, mainTop + statusHeight + 8) then
                    refined = refined + 1
                end
            elseif encounterSystem ~= nil and entry.system == encounterSystem
                and lossOfControlAnchor then
                local locWidth, locHeight = FrameSize(lossOfControlFrame, 300, 90)
                local locPX, locPY = PointFractions(FramePoint(lossOfControlFrame,
                    lossOfControlAnchor.point))
                local locLeft, locBottom = -(locWidth * locPX), -(locHeight * locPY)
                local encounterWidth = FrameSize(encounterFrame, 280, 40)
                if PlaceFromMainAnchor(entry, lossOfControlAnchor, encounterFrame,
                    280, 40, locLeft + (locWidth - encounterWidth) / 2,
                    locBottom + locHeight + 8) then
                    refined = refined + 1
                end
            elseif not controllerLayout
                and ((buffSystem ~= nil and entry.system == buffSystem)
                    or (damageMeterSystem ~= nil and entry.system == damageMeterSystem))
                and type(entry.anchorInfo) == "table"
                and type(entry.anchorInfo.offsetY) == "number" then
                -- Keyboard presets otherwise leave these two tall top-edge
                -- systems pressed against Mainhand's upper boundary. Keep the
                -- native relationship (BuffFrame is commonly Minimap-relative)
                -- and add only a vertical inset. Gamepad has its own compact
                -- arrangement and must retain the native preset spacing.
                entry.anchorInfo.offsetY = entry.anchorInfo.offsetY - 96
                entry.isInDefaultPosition = false
                refined = refined + 1
            elseif minimapSystem ~= nil and entry.system == minimapSystem
                and type(entry.anchorInfo) == "table"
                and entry.anchorInfo.relativeTo == "UIParent"
                and type(entry.anchorInfo.offsetY) == "number" then
                -- The Forever Gamepad preset pins the Minimap flush to the top
                -- of Mainhand after translation. BuffFrame is system-relative
                -- to MinimapCluster, so one inset lowers both without breaking
                -- their native relationship or rewriting a customized source.
                entry.anchorInfo.offsetY = entry.anchorInfo.offsetY - 64
                entry.isInDefaultPosition = false
                refined = refined + 1
            end
        end
    end
    return refined
end

local function GeneratedLayoutBaseName(controllerLayout)
    local player = UnitName and UnitName("player") or nil
    return "Offhand - Mainhand"
        .. (controllerLayout and " - Gamepad" or "")
        .. (player and (" - " .. player) or "")
end

local function IsCurrentCharacterLayoutName(name, controllerLayout)
    if type(name) ~= "string" then return false end
    local expected = string.lower(GeneratedLayoutBaseName(controllerLayout))
    local actual = string.lower(name)
    if actual == expected then return true end
    -- UniqueLayoutName appends only a numeric collision suffix. Accept those
    -- current-character variants, but never another character's layout.
    local suffix = actual:sub(#expected + 1)
    return actual:sub(1, #expected) == expected
        and suffix:match("^ %(%d+%)$") ~= nil
end

local function UniqueLayoutName(data, controllerLayout)
    local base = GeneratedLayoutBaseName(controllerLayout)
    local names = {}
    for _, layout in ipairs(data.layouts) do names[string.lower(LayoutName(layout, ""))] = true end
    if not names[string.lower(base)] then return base end
    for number = 2, 99 do
        local candidate = base .. " (" .. number .. ")"
        if not names[string.lower(candidate)] then return candidate end
    end
    return base .. " - " .. tostring(time and time() or Geometry.GetRevision())
end

local function NativeGamepadInterface()
    if type(Offhand.IsGamepadUIEnabled) == "function" then
        return Offhand:IsGamepadUIEnabled()
    end
    local gamepad = Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad
    local getStyle = C_InputInterfaceStyle and C_InputInterfaceStyle.GetCurrentStyle
    if gamepad == nil or type(getStyle) ~= "function" then return false end
    local ok, current = pcall(getStyle)
    return ok and current == gamepad
end

-- Forever's native radial Main Menu is not part of Edit Mode. It is also a
-- gamepad input surface, so Offhand must not install scripts, hooks, fields, or
-- handlers anywhere in its Blizzard-owned tree. Locate its visual container
-- from Blizzard's localized labels, then let one addon-owned observer adjust
-- only that container's root anchor outside combat. Protected roots use a
-- direct UIParent anchor instead of depending on an addon-owned frame.
local gamepadMainMenuGlobalNames = {
    "GamepadMainMenuFrame", "GamepadMenuFrame", "GamepadRadialMenuFrame",
    "GamepadMenuRadialFrame", "MainMenuRadialFrame", "GamepadRadialFrame",
}

local function GamepadMainMenuTextSets()
    local titles = {}
    local options = {}
    local function Add(set, value)
        if type(value) == "string" and value ~= "" then set[value] = true end
    end
    Add(titles, _G.FRAME_LABEL_MAIN_MENU)
    Add(titles, "Main Menu")
    for _, key in ipairs({
        "RADIAL_LABEL_GAME_MENU", "RADIAL_LABEL_QUEST_MAPS",
        "RADIAL_LABEL_PROFESSIONS", "RADIAL_LABEL_SPELLBOOK",
        "RADIAL_LABEL_TARGET_EMOTES",
    }) do
        Add(options, _G[key])
    end
    Add(options, "Game Menu")
    Add(options, "Quest & Maps")
    Add(options, "Professions")
    Add(options, "Spellbook")
    Add(options, "Emotes")
    return titles, options
end

local function FrameParent(frame)
    if not frame or type(frame.GetParent) ~= "function" then return nil end
    local ok, parent = pcall(frame.GetParent, frame)
    return ok and parent or nil
end

local function FrameDimensions(frame)
    if not frame or type(frame.GetWidth) ~= "function"
        or type(frame.GetHeight) ~= "function" then return nil end
    local okW, width = pcall(frame.GetWidth, frame)
    local okH, height = pcall(frame.GetHeight, frame)
    if not okW or not okH then return nil end
    return Number(width), Number(height)
end

local function IsEligibleGamepadMenuContainer(frame)
    if not frame or frame == UIParent or type(frame.ClearAllPoints) ~= "function"
        or type(frame.SetPoint) ~= "function" then return false end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return false end
    end
    local width, height = FrameDimensions(frame)
    local rect = Mainhand:GetRect()
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or rect.width
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or rect.height
    return width and height and width >= 280 and height >= 280
        and width <= parentWidth * 1.05
        and height <= parentHeight * 1.05
end

local function IsProtectedGamepadMenuContainer(frame)
    if not frame or type(frame.IsProtected) ~= "function" then return false end
    local ok, protected = pcall(frame.IsProtected, frame)
    return ok and protected and true or false
end

local function FindEligibleAncestor(frame)
    local depth = 0
    while frame and frame ~= UIParent and depth < 12 do
        if IsEligibleGamepadMenuContainer(frame) then return frame end
        frame = FrameParent(frame)
        depth = depth + 1
    end
end

local function LowestCommonAncestor(first, second)
    local ancestors = {}
    local depth = 0
    while first and depth < 16 do
        ancestors[first] = true
        first = FrameParent(first)
        depth = depth + 1
    end
    depth = 0
    while second and depth < 16 do
        if ancestors[second] then return second end
        second = FrameParent(second)
        depth = depth + 1
    end
end

local function FindLabeledGamepadMainMenu(includeHidden)
    local titles, options = GamepadMainMenuTextSets()
    local titleOwners, optionOwners = {}, {}
    local seen, visited = {}, 0

    local function IsVisible(frame)
        if includeHidden then return true end
        if not frame or frame == UIParent or type(frame.IsShown) ~= "function" then
            return true
        end
        local ok, shown = pcall(frame.IsShown, frame)
        return ok and shown and true or false
    end

    local function InspectText(owner, object)
        if not object or type(object.GetText) ~= "function" then return end
        local ok, value = pcall(object.GetText, object)
        if not ok or type(value) ~= "string" then return end
        if titles[value] then titleOwners[#titleOwners + 1] = owner end
        if options[value] then optionOwners[#optionOwners + 1] = owner end
    end

    local function Walk(frame, depth)
        if not frame or seen[frame] or depth > 14 or visited >= 5000
            or not IsVisible(frame) then return end
        seen[frame] = true
        visited = visited + 1
        InspectText(frame, frame)
        if type(frame.GetRegions) == "function" then
            local regions = { pcall(frame.GetRegions, frame) }
            if regions[1] then
                for index = 2, #regions do InspectText(frame, regions[index]) end
            end
        end
        if type(frame.GetChildren) == "function" then
            local children = { pcall(frame.GetChildren, frame) }
            if children[1] then
                -- Load-on-demand Gamepad overlays are normally among the most
                -- recently created UIParent children. Search in reverse order
                -- so the bounded scan reaches the visible radial before older
                -- action bars, unit frames, and addon trees consume the budget.
                for index = #children, 2, -1 do Walk(children[index], depth + 1) end
            end
        end
    end

    local function CandidateFromLabels()
        for _, titleOwner in ipairs(titleOwners) do
            for _, optionOwner in ipairs(optionOwners) do
                local candidate = FindEligibleAncestor(LowestCommonAncestor(titleOwner, optionOwner))
                    or FindEligibleAncestor(optionOwner)
                    or FindEligibleAncestor(titleOwner)
                if candidate then return candidate end
            end
        end
    end

    Walk(UIParent, 0)
    local candidate = CandidateFromLabels()
    if candidate then return candidate end

    -- Some Forever builds do not expose the radial through UIParent's direct
    -- child traversal even though its frames are globally enumerable. This
    -- fallback inspects visible frames only and does not recurse into their
    -- trees, keeping the late-overlay discovery bounded.
    if type(EnumerateFrames) == "function" then
        local current
        for _ = 1, 15000 do
            local ok, nextFrame = pcall(EnumerateFrames, current)
            if not ok or not nextFrame then break end
            current = nextFrame
            if not seen[current] and IsVisible(current) then
                seen[current] = true
                InspectText(current, current)
                if type(current.GetRegions) == "function" then
                    local regions = { pcall(current.GetRegions, current) }
                    if regions[1] then
                        for index = 2, #regions do
                            InspectText(current, regions[index])
                        end
                    end
                end
            end
        end
        return CandidateFromLabels()
    end
end

local function FindGamepadMainMenuFrame(includeHidden)
    if gamepadMainMenuFrame then return gamepadMainMenuFrame end
    for _, name in ipairs(gamepadMainMenuGlobalNames) do
        local candidate = _G[name]
        if IsEligibleGamepadMenuContainer(candidate) then
            gamepadMainMenuFrame = candidate
            gamepadMainMenuStatus = "located:" .. name
            return candidate
        end
    end
    local candidate = FindLabeledGamepadMainMenu(includeHidden)
    if candidate then
        gamepadMainMenuFrame = candidate
        local name = candidate.GetName and candidate:GetName()
        gamepadMainMenuStatus = "located:" .. (name or "anonymous")
        return candidate
    end
    gamepadMainMenuStatus = "not-found"
end

local function CaptureGamepadMainMenuPoints(frame)
    local state = gamepadMainMenuState[frame]
    if state then return state end
    state = { points = {} }
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local ok, count = pcall(frame.GetNumPoints, frame)
        if ok then
            for index = 1, count do
                local point = { pcall(frame.GetPoint, frame, index) }
                if point[1] then
                    state.points[#state.points + 1] = {
                        point[2], point[3], point[4], point[5] or 0, point[6] or 0,
                    }
                end
            end
        end
    end
    gamepadMainMenuState[frame] = state
    return state
end

local function RestoreGamepadMainMenu(frame, state)
    if not state or not state.applied or IsPlayerCombatRestricted() then return false end
    if #state.points == 0 then return false end
    local applied = state.applied
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local okCount, count = pcall(frame.GetNumPoints, frame)
        local okPoint, point, relativeTo, relativePoint, x, y =
            pcall(frame.GetPoint, frame, 1)
        local ownsAnchor = okCount and count == 1 and okPoint
            and point == "CENTER" and relativeTo == applied.relativeTo
            and relativePoint == "CENTER"
            and math.abs((x or 0) - applied.x) < 0.01
            and math.abs((y or 0) - applied.y) < 0.01
        if not ownsAnchor then
            state.applied = nil
            gamepadMainMenuStatus = "ownership-changed"
            return false
        end
    end
    local ok = pcall(function()
        frame:ClearAllPoints()
        for _, point in ipairs(state.points) do
            frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
    end)
    if not ok then
        gamepadMainMenuStatus = "restore-blocked"
        return false
    end
    state.applied = nil
    gamepadMainMenuStatus = "native"
    return true
end

function Mainhand:CenterForeverGamepadMainMenu()
    if not Offhand.isForever or _G.ConsolePort then return false, "unsupported" end
    local frame = FindGamepadMainMenuFrame()
    if not frame then return false, "not-found" end
    local state = CaptureGamepadMainMenuPoints(frame)
    if #state.points == 0 then
        gamepadMainMenuStatus = "unanchored"
        return false, "unanchored"
    end
    local rect = self:GetRect()
    local active = Offhand.db and Offhand.db.enabled and rect.isSpanned
        and NativeGamepadInterface()
    if not active then
        RestoreGamepadMainMenu(frame, state)
        return false, "inactive"
    end
    if IsPlayerCombatRestricted() then return false, "combat" end
    if not IsEligibleGamepadMenuContainer(frame) then return false, "restricted" end
    local relativeTo, x, y
    if IsProtectedGamepadMenuContainer(frame) then
        local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
        local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
        local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
        local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not Number(frameScale) or not Number(parentScale)
            or frameScale <= 0 or parentScale <= 0 then return false, "scale" end
        relativeTo = UIParent
        x = (rect.left + rect.right - parentWidth) / 2
        y = (rect.bottom + rect.top - parentHeight) / 2
        x = x / (frameScale / parentScale)
        y = y / (frameScale / parentScale)
    else
        relativeTo = self:CreateAnchor()
        x, y = 0, 0
        if not relativeTo then return false, "anchor" end
    end
    local correct = false
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local okCount, count = pcall(frame.GetNumPoints, frame)
        local okPoint, point, currentRelativeTo, relativePoint, currentX, currentY =
            pcall(frame.GetPoint, frame, 1)
        correct = okCount and count == 1 and okPoint and point == "CENTER"
            and currentRelativeTo == relativeTo and relativePoint == "CENTER"
            and math.abs((currentX or 0) - x) < 0.01
            and math.abs((currentY or 0) - y) < 0.01
    end
    if not correct then
        local ok = pcall(function()
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", relativeTo, "CENTER", x, y)
        end)
        if not ok then
            gamepadMainMenuStatus = "move-blocked"
            return false, "restricted"
        end
    end
    state.applied = { relativeTo = relativeTo, x = x, y = y }
    local name = frame.GetName and frame:GetName()
    gamepadMainMenuStatus = "centered:" .. (name or "anonymous")
    return true
end

function Mainhand:GetForeverGamepadMainMenuDiagnostics()
    return gamepadMainMenuStatus
end

-- Native Gamepad navigation opens these destinations at fixed UIParent
-- anchors and does not expose them through Edit Mode. Keep their native input,
-- focus, visibility, and close behavior intact. The adapter only translates a
-- shown root to the physical Mainhand center from an addon-owned observer.
-- Protected roots are denied except for the explicit position-only allowlist
-- below. Their drag surface remains an addon-owned UIParent sibling and only
-- commits the same permitted root-anchor operation after a hardware gesture.
-- LootFrame is intentionally absent: Blizzard owns it as an Edit Mode system
-- and its FocusGamepad path must remain completely untouched.
local gamepadDestinationPanelNames = {
    "CharacterFrame",
    "WorldMapFrame",
    "FlightMapFrame",
    "PlayerSpellsFrame",
    "ProfessionsBookFrame",
    "ProfessionsFrame",
    "ChannelFrame",
    "QuestFrame",
    "GossipFrame",
    "MerchantFrame",
    "ContainerFrameCombinedBags",
    "ContainerFrame1",
    "LegacySystemFrame",
    "FriendsFrame",
    "CommunitiesFrame",
    "PVEFrame",
    "CollectionsJournal",
    "EncounterJournal",
    "MacroFrame",
    "CalendarFrame",
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "AudioOptionsFrame",
    "AddonList",
    "HelpFrame",
}

-- FriendsFrame is the ordinary root, but Forever builds have also exposed the
-- same shown Social surface through one of these compatibility names. Resolve
-- only the first shown candidate so Offhand never reanchors both a wrapper and
-- its child in the same pass.
local gamepadDestinationPanelAliases = {
    FriendsFrame = { "SocialUIFrame", "FriendsListFrame", "SocialFrame" },
}

-- These Gamepad destinations have protected roots, but Forever does not
-- provide an Edit Mode system or a public placement API for either window.
-- Moving only the root anchor out of combat is the smallest useful exception:
-- do not add scripts or children and do not make the frame itself movable.
local protectedGamepadDestinationPositionNames = {
    PlayerSpellsFrame = true,
    FlightMapFrame = true,
    ProfessionsBookFrame = true,
    ProfessionsFrame = true,
    ChannelFrame = true,
    QuestFrame = true,
    GossipFrame = true,
    LegacySystemFrame = true,
    FriendsFrame = true,
    SocialUIFrame = true,
    CommunitiesFrame = true,
    CollectionsJournal = true,
}

local function IsNativeBagDestinationName(name)
    return name == "ContainerFrameCombinedBags" or name == "ContainerFrame1"
end

local function ResolveGamepadDestinationPanel(name)
    local primary = _G[name]
    if primary and primary.IsShown and primary:IsShown() then return primary end
    local aliases = gamepadDestinationPanelAliases[name]
    if aliases then
        for _, alias in ipairs(aliases) do
            local candidate = _G[alias]
            if candidate and candidate.IsShown and candidate:IsShown() then
                return candidate
            end
        end
    end
    return primary
end

local function IsProtectedGamepadDestinationPositionName(name)
    return name and protectedGamepadDestinationPositionNames[name] == true
end

local function IsUsableGamepadDestinationPanel(frame, suppliedName)
    if not frame or frame == UIParent or type(frame.ClearAllPoints) ~= "function"
        or type(frame.SetPoint) ~= "function" then return false, "invalid" end
    if type(frame.IsForbidden) == "function" then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return false, "forbidden" end
    end
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        if not ok or protected then
            local name = suppliedName or (frame.GetName and frame:GetName())
            if not ok or not IsProtectedGamepadDestinationPositionName(name) then
                return false, "protected"
            end
            return true, "protected-position"
        end
    end
    return true
end

local function CanDragGamepadDestinationPanel(frame, suppliedName)
    if not frame then return false end
    local name = suppliedName or (frame.GetName and frame:GetName())
    if type(frame.IsProtected) == "function" then
        local ok, protected = pcall(frame.IsProtected, frame)
        if not ok then return false end
        if protected then
            return IsProtectedGamepadDestinationPositionName(name)
        end
    end
    return true
end

local function CaptureDestinationPanelPoints(frame)
    local state = gamepadDestinationPanelState[frame]
    if state then return state end
    state = { points = {} }
    if type(frame.IsClampedToScreen) == "function" then
        local ok, clamped = pcall(frame.IsClampedToScreen, frame)
        if ok then
            state.clampedKnown = true
            state.clamped = clamped and true or false
        end
    end
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local ok, count = pcall(frame.GetNumPoints, frame)
        if ok then
            for index = 1, count do
                local point = { pcall(frame.GetPoint, frame, index) }
                if point[1] then
                    state.points[#state.points + 1] = {
                        point[2], point[3], point[4], point[5] or 0, point[6] or 0,
                    }
                end
            end
        end
    end
    gamepadDestinationPanelState[frame] = state
    return state
end

local function RestoreDestinationPanel(frame, state, name)
    if not state or not state.applied or IsPlayerCombatRestricted() then return false end
    local usable, reason = IsUsableGamepadDestinationPanel(frame, name)
    if not usable or #state.points == 0 then return false, reason or "unanchored" end
    local ownsAnchor = false
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local okCount, count = pcall(frame.GetNumPoints, frame)
        local okPoint, point, relativeTo, relativePoint, x, y = pcall(frame.GetPoint, frame, 1)
        ownsAnchor = okCount and count == 1 and okPoint and point == "CENTER"
            and relativeTo == UIParent and relativePoint == "CENTER"
            and math.abs((x or 0) - state.applied.x) < 0.01
            and math.abs((y or 0) - state.applied.y) < 0.01
    end
    if not ownsAnchor then
        state.applied = nil
        return false, "ownership-changed"
    end
    local ok = pcall(function()
        frame:ClearAllPoints()
        for _, point in ipairs(state.points) do
            frame:SetPoint(point[1], point[2], point[3], point[4], point[5])
        end
        if not IsProtectedGamepadDestinationPositionName(name)
            and state.clampedKnown and frame.SetClampedToScreen then
            frame:SetClampedToScreen(state.clamped)
        end
    end)
    if not ok then return false, "restore-blocked" end
    state.applied = nil
    return true, "native"
end

local function DestinationPanelCenter()
    local rect = Mainhand:GetRect()
    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    return rect, (rect.left + rect.right - parentWidth) / 2,
        (rect.bottom + rect.top - parentHeight) / 2
end

local function DestinationPanelOffset(name, state)
    local offsets = type(OffhandCharDB) == "table"
        and OffhandCharDB.foreverGamepadPanelOffsets or nil
    local saved = offsets and offsets[name] or nil
    local x = saved and Number(saved.x) or nil
    local y = saved and Number(saved.y) or nil
    if x and y then return x, y end
    local transient = state and state.offset or nil
    return transient and Number(transient.x) or 0,
        transient and Number(transient.y) or 0
end

local function SaveDestinationPanelOffset(name, state, x, y)
    x, y = Number(x) or 0, Number(y) or 0
    state.offset = { x = x, y = y }
    if type(OffhandCharDB) ~= "table" then return end
    OffhandCharDB.foreverGamepadPanelOffsets =
        OffhandCharDB.foreverGamepadPanelOffsets or {}
    OffhandCharDB.foreverGamepadPanelOffsets[name] = { x = x, y = y }
end

local function CenterDestinationPanel(frame, suppliedName)
    local usable, reason = IsUsableGamepadDestinationPanel(frame, suppliedName)
    if not usable then return false, reason end
    local state = CaptureDestinationPanelPoints(frame)
    if #state.points == 0 then return false, "unanchored" end
    local rect, x, y = DestinationPanelCenter()
    if not rect.isSpanned then return false, "span" end
    local name = suppliedName or (frame.GetName and frame:GetName())
    local offsetX, offsetY = DestinationPanelOffset(name, state)
    x, y = x + offsetX, y + offsetY
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local parentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not Number(frameScale) or not Number(parentScale)
        or frameScale <= 0 or parentScale <= 0 then return false, "scale" end
    x = x / (frameScale / parentScale)
    y = y / (frameScale / parentScale)

    local correct = false
    if type(frame.GetNumPoints) == "function" and type(frame.GetPoint) == "function" then
        local okCount, count = pcall(frame.GetNumPoints, frame)
        local okPoint, point, relativeTo, relativePoint, currentX, currentY =
            pcall(frame.GetPoint, frame, 1)
        correct = okCount and count == 1 and okPoint and point == "CENTER"
            and relativeTo == UIParent and relativePoint == "CENTER"
            and math.abs((currentX or 0) - x) < 0.01
            and math.abs((currentY or 0) - y) < 0.01
    end
    if not correct then
        local ok = pcall(function()
            if not IsProtectedGamepadDestinationPositionName(name)
                and frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
        end)
        if not ok then return false, "move-blocked" end
    end
    state.applied = { x = x, y = y }
    return true, "centered"
end

-- Native Gamepad panels do not expose mouse movement and adding a grip to
-- their frame trees can contaminate Blizzard's protected focus transaction.
-- Each visible root receives its own independent UIParent sibling. Gamepad can
-- leave several destinations open at once, so one shared grip would strand all
-- but the first frame. A grip moves only itself during the gesture, then applies
-- the completed delta through the same root-only adapter used for centering.
local function EnsureDestinationPanelDragHandle(target, suppliedName)
    if not target or not CreateFrame or not UIParent then return nil end
    local existing = gamepadDestinationDragHandles[target]
    if existing then return existing end
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local targetName = target.GetName and target:GetName() or "Panel"
    local safeName = type(targetName) == "string"
        and targetName:gsub("[^%w_]", "") or "Panel"
    local globalName = targetName == "CharacterFrame"
        and "OffhandForeverGamepadPanelMover"
        or "OffhandForeverGamepadPanelMover_" .. safeName
    local handle = CreateFrame("Frame", globalName,
        UIParent, template)
    if not handle then return nil end
    gamepadDestinationDragHandles[target] = handle
    handle._OffhandTarget = target
    handle._OffhandPanelName = suppliedName
    if handle.SetSize then handle:SetSize(128, 20) end
    if handle.SetFrameStrata then handle:SetFrameStrata("TOOLTIP") end
    if handle.SetFrameLevel then handle:SetFrameLevel(9000) end
    if handle.SetMovable then handle:SetMovable(true) end
    if handle.SetClampedToScreen then handle:SetClampedToScreen(true) end
    if handle.EnableMouse then handle:EnableMouse(true) end
    if handle.RegisterForDrag then handle:RegisterForDrag("LeftButton") end
    if handle.SetBackdrop then
        handle:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        handle:SetBackdropColor(0.02, 0.02, 0.02, 0.88)
        handle:SetBackdropBorderColor(1, 0.74, 0.04, 0.95)
    end
    if handle.CreateFontString then
        local label = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if label then
            label:SetPoint("CENTER")
            label:SetText((Offhand.L and Offhand.L["GROUP_LOOT_MOVER_DRAG"])
                or "Drag to move")
        end
    end
    if handle.SetScript then
        handle:SetScript("OnDragStart", function(self)
            if IsPlayerCombatRestricted() or not self._OffhandTarget then return end
            local x, y
            if self.GetCenter then x, y = self:GetCenter() end
            if not Number(x) or not Number(y) then return end
            self._OffhandDragStartX, self._OffhandDragStartY = x, y
            self._OffhandDragging = true
            if self.StartMoving then self:StartMoving() end
        end)
        handle:SetScript("OnDragStop", function(self)
            if self.StopMovingOrSizing then self:StopMovingOrSizing() end
            local target = self._OffhandTarget
            local startX, startY = self._OffhandDragStartX, self._OffhandDragStartY
            self._OffhandDragging = nil
            self._OffhandDragStartX, self._OffhandDragStartY = nil, nil
            if IsPlayerCombatRestricted() or not target or not startX or not startY then return end
            local name = self._OffhandPanelName
                or (target.GetName and target:GetName())
            local usable = IsUsableGamepadDestinationPanel(target, name)
            local x, y
            if self.GetCenter then x, y = self:GetCenter() end
            if not usable or not Number(x) or not Number(y) then return end
            local state = gamepadDestinationPanelState[target]
            if not name or not state then return end
            local oldX, oldY = DestinationPanelOffset(name, state)
            SaveDestinationPanelOffset(name, state,
                oldX + x - startX, oldY + y - startY)
            CenterDestinationPanel(target, name)
        end)
    end
    if handle.Hide then handle:Hide() end
    return handle
end

local function GamepadDestinationDragHandlesEnabled()
    return not Offhand.db or Offhand.db.showGamepadPanelDragHandles ~= false
end

local function UpdateDestinationPanelDragHandle(target, active, suppliedName)
    local enabled = GamepadDestinationDragHandlesEnabled()
    local handle = target and gamepadDestinationDragHandles[target] or nil
    if not active and not handle then return end
    if not enabled then
        if handle and handle._OffhandDragging then
            if handle.StopMovingOrSizing then handle:StopMovingOrSizing() end
            handle._OffhandDragging = nil
            handle._OffhandDragStartX, handle._OffhandDragStartY = nil, nil
        end
        if handle and handle.Hide then handle:Hide() end
        return
    end
    handle = handle or (target and EnsureDestinationPanelDragHandle(target, suppliedName) or nil)
    if not handle then return end
    if suppliedName then handle._OffhandPanelName = suppliedName end
    if handle._OffhandDragging then return end
    if not active or not target or IsPlayerCombatRestricted() then
        if handle.Hide then handle:Hide() end
        return
    end
    local ok, handleX, handleY = pcall(function()
        local frameScale = (target.GetEffectiveScale and target:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        if not Number(frameScale) or not Number(parentScale) or parentScale <= 0 then
            return nil
        end
        local factor = frameScale / parentScale
        local left = target.GetLeft and target:GetLeft() or nil
        local top = target.GetTop and target:GetTop() or nil
        local width = target.GetWidth and target:GetWidth() or nil
        if Number(left) and Number(top) and Number(width) then
            return (left + width / 2) * factor, top * factor + 4
        end
        -- Some protected Forever Social roots do not expose edge coordinates
        -- while focused. Their center and height remain sufficient to place an
        -- addon-owned sibling above the visible root without entering its tree.
        local centerX, centerY
        if target.GetCenter then centerX, centerY = target:GetCenter() end
        local height = target.GetHeight and target:GetHeight() or nil
        if Number(centerX) and Number(centerY) and Number(height) then
            return centerX * factor, (centerY + height / 2) * factor + 4
        end
    end)
    if not ok or not Number(handleX) or not Number(handleY) then
        if handle.Hide then handle:Hide() end
        return
    end
    if handle.ClearAllPoints and handle.SetPoint then
        handle:ClearAllPoints()
        handle:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", handleX, handleY)
    end
    if handle.Show then handle:Show() end
end

local function HideDestinationPanelDragHandles()
    for _, handle in pairs(gamepadDestinationDragHandles) do
        if handle._OffhandDragging then
            if handle.StopMovingOrSizing then handle:StopMovingOrSizing() end
            handle._OffhandDragging = nil
            handle._OffhandDragStartX, handle._OffhandDragStartY = nil, nil
        end
        if handle.Hide then handle:Hide() end
    end
end

function Mainhand:AreForeverGamepadDragHandlesShown()
    return GamepadDestinationDragHandlesEnabled()
end

function Mainhand:SetForeverGamepadDragHandlesShown(shown)
    if not Offhand.isForever or not Offhand.db then return false end
    Offhand.db.showGamepadPanelDragHandles = shown == true
    if not shown then
        for target in pairs(gamepadDestinationDragHandles) do
            UpdateDestinationPanelDragHandle(target, false)
        end
    else
        self:CenterForeverGamepadDestinationPanels()
    end
    return true
end

function Mainhand:CenterForeverGamepadDestinationPanels()
    if not Offhand.isForever then return 0 end
    -- InputDeviceInterfaceStyle is Forever's actual Gamepad UI setting, not a
    -- last-input hint. A saved Gamepad HUD may remain selected while the player
    -- explicitly returns to keyboard UI, but it must never keep Offhand's
    -- Gamepad-only panel anchors or drag handles active in that mode.
    local active = not _G.ConsolePort and Offhand.db and Offhand.db.enabled
        and NativeGamepadInterface()
        and self:GetRect().isSpanned
    local inCombat = IsPlayerCombatRestricted()
    local moved = 0
    local activeHandles = {}
    for _, name in ipairs(gamepadDestinationPanelNames) do
        local frame = ResolveGamepadDestinationPanel(name)
        local state = frame and gamepadDestinationPanelState[frame] or nil
        local replacementBag = IsNativeBagDestinationName(name)
            and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
        if frame and replacementBag then
            local restored, reason = RestoreDestinationPanel(frame, state, name)
            gamepadDestinationPanelStatus[name] = restored and "replacement-owned"
                or (state and state.applied and (reason or "restore-deferred")
                    or "replacement-owned")
            UpdateDestinationPanelDragHandle(frame, false, name)
        elseif frame and not active then
            local shown = frame.IsShown and frame:IsShown() or false
            local _, protectionReason = IsUsableGamepadDestinationPanel(frame, name)
            if shown and protectionReason == "protected-position"
                and state and state.applied then
                -- Do not rewrite a visible protected panel while Forever is
                -- rebuilding focus and bindings for keyboard UI. Leave its
                -- native lifecycle in control, then restore the captured
                -- anchor after the panel is hidden.
                gamepadDestinationPanelStatus[name] = "native-visible"
            else
                local restored, reason = RestoreDestinationPanel(frame, state, name)
                gamepadDestinationPanelStatus[name] = restored and "native"
                    or (state and state.applied and (reason or "restore-deferred") or "inactive")
            end
        elseif frame and active and not inCombat then
            local shown = frame.IsShown and frame:IsShown() or false
            if shown then
                local centered, reason = CenterDestinationPanel(frame, name)
                gamepadDestinationPanelStatus[name] = reason or "unknown"
                if centered then moved = moved + 1 end
                if centered and GamepadDestinationDragHandlesEnabled()
                    and CanDragGamepadDestinationPanel(frame, name) then
                    UpdateDestinationPanelDragHandle(frame, true, name)
                    activeHandles[frame] = true
                end
            elseif state and state.applied then
                gamepadDestinationPanelStatus[name] = "centered-hidden"
            else
                gamepadDestinationPanelStatus[name] = "hidden"
            end
        elseif frame and inCombat then
            gamepadDestinationPanelStatus[name] = "combat"
        end
    end
    for frame, handle in pairs(gamepadDestinationDragHandles) do
        if not activeHandles[frame] and not handle._OffhandDragging and handle.Hide then
            handle:Hide()
        end
    end
    return moved
end

function Mainhand:GetForeverGamepadDestinationPanelDiagnostics()
    local entries = {}
    for _, name in ipairs(gamepadDestinationPanelNames) do
        if gamepadDestinationPanelStatus[name] then
            entries[#entries + 1] = name .. ":" .. gamepadDestinationPanelStatus[name]
        end
    end
    return #entries > 0 and table.concat(entries, ",") or "none"
end

local function ReticleResult(moved, status)
    gamepadReticleStatus = status or "inactive"
    return moved, status
end

function Mainhand:CenterForeverGamepadReticle()
    if not Offhand.isForever then return ReticleResult(false, "client") end
    local frame = _G.GamepadReticle
    if not frame then return ReticleResult(false, "unavailable") end
    if IsPlayerCombatRestricted() then return ReticleResult(false, "combat") end
    local active = not _G.ConsolePort and Offhand.db and Offhand.db.enabled
        and NativeGamepadInterface() and self:GetRect().isSpanned
    if not active then
        return ReticleResult(RestoreDestinationPanel(frame, gamepadDestinationPanelState[frame], "GamepadReticle"))
    end
    if not frame.IsShown or not frame:IsShown() then return ReticleResult(false, "hidden") end
    -- The native reticle's Recenter uses UIParent's horizontal center and a
    -- full-canvas cursor height. Reuse only the root geometry adapter, without
    -- adding it to movable/persistent destinations or changing targeting APIs.
    return ReticleResult(CenterDestinationPanel(frame, "GamepadReticle"))
end

function Mainhand:GetShownForeverGamepadWorkspacePanels()
    local panels, seen = {}, {}
    local canvas = Offhand.Canvas
    if not canvas or type(canvas.IsFrameOnWorkspace) ~= "function" then return panels end
    for _, name in ipairs(gamepadDestinationPanelNames) do
        local frame = ResolveGamepadDestinationPanel(name)
        if frame and not seen[frame] and frame.IsShown and frame:IsShown() then
            seen[frame] = true
            local ok, onWorkspace = pcall(canvas.IsFrameOnWorkspace, frame)
            if ok and onWorkspace then panels[#panels + 1] = frame end
        end
    end
    return panels
end

function Mainhand:EnableForeverGamepadMainMenuAdapter()
    if not Offhand.isForever or not CreateFrame or not UIParent then return false end
    if gamepadMainMenuController then return true end
    gamepadMainMenuController = CreateFrame("Frame",
        "OffhandForeverGamepadMainMenuController", UIParent)
    if not gamepadMainMenuController or not gamepadMainMenuController.SetScript then return false end
    -- Discover a load-on-demand radial while it is still hidden. Positioning
    -- waits until the interface style has remained stable so Offhand never
    -- writes protected anchors inside Forever's Gamepad enable/disable stack.
    FindGamepadMainMenuFrame(true)
    if gamepadMainMenuController.RegisterEvent then
        gamepadMainMenuController:RegisterEvent("ADDON_LOADED")
        gamepadMainMenuController:SetScript("OnEvent", function(_, _, addonName)
            if gamepadMainMenuFrame or type(addonName) ~= "string"
                or not addonName:find("Gamepad", 1, true) then return end
            FindGamepadMainMenuFrame(true)
        end)
    end
    local stableGamepadMode = NativeGamepadInterface()
    local interfaceSettleElapsed = 0
    local radialElapsed = 0
    local panelElapsed = 0
    gamepadMainMenuController:SetScript("OnUpdate", function(_, elapsed)
        local currentGamepadMode = NativeGamepadInterface()
        if currentGamepadMode ~= stableGamepadMode then
            stableGamepadMode = currentGamepadMode
            interfaceSettleElapsed = 0
            radialElapsed = 0
            panelElapsed = 0
            HideDestinationPanelDragHandles()
            if not currentGamepadMode and Offhand.WorkspaceBehavior
                and Offhand.WorkspaceBehavior.RefreshGamepadWorkspaceBack then
                Offhand.WorkspaceBehavior:RefreshGamepadWorkspaceBack()
            end
            gamepadMainMenuStatus = "interface-settling"
            return
        end
        interfaceSettleElapsed = interfaceSettleElapsed + (elapsed or 0)
        if interfaceSettleElapsed < GAMEPAD_INTERFACE_SETTLE_SECONDS then
            HideDestinationPanelDragHandles()
            return
        end
        radialElapsed = radialElapsed + (elapsed or 0)
        panelElapsed = panelElapsed + (elapsed or 0)
        local radialInterval = gamepadMainMenuFrame and 0.2 or 1
        if radialElapsed >= radialInterval then
            radialElapsed = 0
            Mainhand:CenterForeverGamepadMainMenu()
        end
        -- A 20 Hz observer is visually prompt without continuously touching
        -- protected roots during Forever's render and focus transactions.
        local panelInterval = stableGamepadMode and GAMEPAD_ACTIVE_PANEL_INTERVAL
            or GAMEPAD_INACTIVE_PANEL_INTERVAL
        if panelElapsed >= panelInterval then
            panelElapsed = 0
            Mainhand:CenterForeverGamepadDestinationPanels()
            Mainhand:CenterForeverGamepadReticle()
            if Offhand.WorkspaceBehavior and Offhand.WorkspaceBehavior.RefreshGamepadWorkspaceBack then
                Offhand.WorkspaceBehavior:RefreshGamepadWorkspaceBack()
            end
        end
    end)
    return true
end

local function ControllerMode(presets)
    if _G.ConsolePort or NativeGamepadInterface() then return true end
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

function Mainhand:RestoreForeverGamepadPreset()
    -- Forever's Gamepad preset feeds Blizzard's protected Edit Mode and compact
    -- unit-frame refresh paths. Even an out-of-combat manager refresh can taint
    -- secret values later. Keep this compatibility stub so older callers fail
    -- closed without touching the preset table or EditModeManagerFrame.
    return false, "gamepad"
end

function Mainhand:IsNativeGamepadInterface()
    return NativeGamepadInterface()
end

function Mainhand:IsControllerLayout()
    if _G.ConsolePort or NativeGamepadInterface() then return true end
    EnsureEditModeLoaded()
    return ControllerMode(Presets())
end

function Mainhand:CanCreateControllerLayout()
    if _G.ConsolePort or not Offhand.isForever or not NativeGamepadInterface() then
        return false
    end
    EnsureEditModeLoaded()
    return C_EditMode ~= nil
        and type(C_EditMode.GetLayouts) == "function"
        and type(C_EditMode.SaveLayouts) == "function"
        and (type(C_EditMode.OnLayoutAdded) == "function"
            or type(C_EditMode.SetActiveLayout) == "function")
        and #Presets() > 0
end

-- Profiles completed before generated Mainhand layouts were introduced can be
-- fully spanned while Blizzard's protected HUD still uses the complete
-- UIParent. The ordinary wizard no longer reopens for those users, so expose a
-- narrow migration check that can offer the same player-initiated transaction.
-- Forever has its own protected-layout recovery flow and is excluded here.
function Mainhand:NeedsEditModeLayoutAttention()
    if Offhand.isForever then return false, "forever" end
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return false, "disabled" end
    local rect = self:GetRect()
    if not rect.isSpanned then return false, "span" end
    if type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayoutDeferred then
        return false, "deferred"
    end
    if type(Offhand.HasBlizzardEditMode) ~= "function"
        or not Offhand:HasBlizzardEditMode() then return false, "unsupported" end

    EnsureEditModeLoaded()
    if not C_EditMode or type(C_EditMode.GetLayouts) ~= "function"
        or type(C_EditMode.SaveLayouts) ~= "function" then
        return false, "api"
    end
    local data = EditModeData()
    if not data then return false, "unavailable" end
    local presets = Presets()
    if #presets == 0 then return false, "presets" end
    if ControllerMode(presets) then return false, "gamepad" end

    local status = self:GetLayoutStatus()
    if not status.configured then return true, "missing" end
    if not status.currentGeometry then return true, "stale" end
    return false, "ready"
end

function Mainhand:GetEditModeDiagnostics(compact)
    local needsAttention, reason = self:NeedsEditModeLayoutAttention()
    local status = self:GetLayoutStatus()
    local data = EditModeData()
    local active = data and data.activeLayout or "unavailable"
    if compact then
        return string.format("Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Gamepad=%s",
            tostring(active),
            status.configured and tostring(status.generatedName or "recorded") or "none",
            status.configured and (status.currentGeometry and "current" or "stale") or "none",
            needsAttention and "yes" or "no", tostring(reason or "unknown"),
            NativeGamepadInterface() and "yes" or "no")
    end
    return string.format(
        "Supported=%s | API=%s/%s | Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Repair=%s/%s | GamepadMenu=%s | GamepadPanels=%s | GamepadReticle=%s | GamepadBack=%s",
        type(Offhand.HasBlizzardEditMode) == "function"
            and Offhand:HasBlizzardEditMode() and "yes" or "no",
        C_EditMode and type(C_EditMode.GetLayouts) == "function" and "read" or "none",
        C_EditMode and type(C_EditMode.SaveLayouts) == "function" and "write" or "none",
        tostring(active),
        status.configured and tostring(status.generatedName or "recorded") or "none",
        status.configured and (status.currentGeometry and "current" or "stale") or "none",
        needsAttention and "yes" or "no", tostring(reason or "unknown"),
        tostring(status.protectedRepairCandidate or "none"),
        tostring(status.protectedRepairSystems or 0),
        tostring(gamepadMainMenuStatus),
        self:GetForeverGamepadDestinationPanelDiagnostics(), tostring(gamepadReticleStatus),
        Offhand.WorkspaceBehavior and Offhand.WorkspaceBehavior.GetGamepadWorkspaceBackDiagnostics
            and Offhand.WorkspaceBehavior:GetGamepadWorkspaceBackDiagnostics() or "unavailable")
end

function Mainhand:CreateOrUpdateEditModeLayout(options)
    options = type(options) == "table" and options or nil
    local repairFrameName = options and options.repairFrameName or nil
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return false, "disabled" end
    local rect = self:GetRect()
    if not rect.isSpanned then return false, "span" end
    -- ConsolePort remains the external owner of its protected controller HUD.
    -- Forever's native Gamepad interface can use a custom Edit Mode layout on
    -- current beta builds, but the built-in preset itself remains read-only.
    if _G.ConsolePort then return false, "gamepad" end
    local nativeGamepadLayout = Offhand.isForever and NativeGamepadInterface()
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
    local controllerLayout = ControllerMode(presets)
    if controllerLayout and not nativeGamepadLayout then return false, "gamepad" end
    if type(OffhandCharDB) ~= "table" then return false, "state" end

    local record = OffhandCharDB.mainhandLayout
    local modeRecord = type(record) == "table"
        and (record.controllerLayout == true) == controllerLayout and record or nil
    local matchingRecord = modeRecord
        and IsCurrentCharacterLayoutName(modeRecord.generatedName, controllerLayout)
        and modeRecord or nil
    local source, sourceID, sourceIndex, sourcePreset
    if nativeGamepadLayout then
        -- Old beta builds could leave a controller record pointing at Classic
        -- after rejecting custom-layout activation. Always rebuild a Gamepad
        -- layout from the live Gamepad preset, never from that stale record or
        -- from an already translated custom layout.
        local gamepadStyle = Enum and Enum.InputDeviceInterfaceType
            and Enum.InputDeviceInterfaceType.Gamepad
        for index, candidate in ipairs(presets) do
            local name = LayoutName(candidate, "")
            if (gamepadStyle ~= nil and candidate.interfaceStyle == gamepadStyle)
                or string.lower(name):find("gamepad", 1, true) then
                source = candidate
                sourceID = tonumber(candidate.layoutIndex) or index
                sourceIndex = index
                sourcePreset = true
                break
            end
        end
        if not source then
            local activeSource, activeID, activeIndex, activePreset =
                ResolveActiveLayout(data, presets)
            if activePreset then
                source, sourceID, sourceIndex, sourcePreset =
                    activeSource, activeID, activeIndex, true
            end
        end
    elseif modeRecord and modeRecord.sourcePreset and tonumber(modeRecord.sourceID) then
        -- Source provenance is safe to reuse even when an older account-global
        -- fallback attached another character's generated target to this DB.
        -- This rebuilds the current character from Modern/Classic rather than
        -- copying the other character's custom layout.
        local wanted = tonumber(modeRecord.sourceID)
        for index, layout in ipairs(presets) do
            if tonumber(layout.layoutIndex) == wanted or index == wanted then
                source, sourceID, sourceIndex, sourcePreset = layout, wanted, index, true
                break
            end
        end
    elseif modeRecord and type(modeRecord.sourceName) == "string" then
        source, sourceID, sourceIndex, sourcePreset =
            FindNamedLayout(data, presets, modeRecord.sourceName)
    end
    if not source then source, sourceID, sourceIndex, sourcePreset = ResolveActiveLayout(data, presets) end
    if not source then return false, "source" end
    local generatedName = matchingRecord and matchingRecord.generatedName or nil
    local generated, _, generatedIndex = FindNamedLayout(data, presets, generatedName)
    -- SaveLayouts can succeed before a later activation step fails. Recover
    -- that exact Offhand-owned row on retry so an interrupted transaction does
    -- not create a suffixed duplicate or consume another custom-layout slot.
    if not generated and not matchingRecord then
        local expectedName = GeneratedLayoutBaseName(controllerLayout)
        local orphan, _, orphanIndex = FindNamedLayout(data, presets, expectedName)
        if orphan and orphanIndex then
            generatedName = expectedName
            generated = orphan
            generatedIndex = orphanIndex
        end
    end
    -- Forever already persisted the selected protected-frame layout before the
    -- generated-layout provenance record was introduced. Reuse that exact
    -- Offhand-owned layout when the newer record is absent or stale. Without
    -- this bridge, a character at Blizzard's custom-layout cap is told to make
    -- a sixth layout even though its existing Mainhand layout is available.
    if not generated and Offhand.isForever and not controllerLayout
        and not (type(record) == "table" and record.controllerLayout == true) then
        local preferredName = OffhandCharDB.foreverEditModeLayoutName
        if IsCurrentCharacterLayoutName(preferredName, false) then
            local preferred, _, preferredIndex = FindNamedLayout(data, presets, preferredName)
            if preferred and preferredIndex then
                generatedName = preferredName
                generated = preferred
                generatedIndex = preferredIndex
            end
        end
    end
    if not generatedName then generatedName = UniqueLayoutName(data, controllerLayout) end

    local layout = DeepCopy(source)
    local sourceDefaults = {}
    for index, entry in ipairs(layout.systems or {}) do
        sourceDefaults[index] = entry.isInDefaultPosition ~= false
    end
    local editModeSystems = Enum and Enum.EditModeSystem
    local actionIndices = Enum and Enum.EditModeActionBarSystemIndices
    local foreverActionSystem = editModeSystems and editModeSystems.ActionBar
    local foreverClassBar = actionIndices and actionIndices.ClassBar
    local moved, transformed = TransformLayout(layout, rect, function(entry)
        -- Forever's empty MultiCast/Totem Edit Mode preview can call
        -- C_TooltipInfo.GetSpellByID(nil) after an addon-generated relocation.
        -- Leave this ambiguous ClassBar entry exactly where the source layout
        -- put it; stance, pet and possess have their own unambiguous indices.
        return Offhand.isForever and foreverActionSystem ~= nil and foreverClassBar ~= nil
            and entry.system == foreverActionSystem and entry.systemIndex == foreverClassBar
    end)
    RefineStandardHUDLayout(layout, rect, sourceDefaults, controllerLayout)
    local groupMoved, groupRepaired = RefineGroupHUDLayout(layout, rect, sourceDefaults,
        transformed, repairFrameName)
    moved = moved + groupMoved
    if IsGroupRecoveryFrame(repairFrameName) and groupRepaired == 0 then
        return false, "repair-system", LayoutName(source, "layout"), moved
    end
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
    local function IsTargetActive()
        local current = EditModeData()
        return current and tonumber(current.activeLayout) == targetID or false
    end
    local active = IsTargetActive()
    -- Match Blizzard's native MakeNewLayout transaction: save the custom
    -- payload once, then register and activate a newly added layout. Calling
    -- SetActiveLayout first and submitting SaveLayouts a second time can make
    -- Forever restore the prior active ID from its internal layout manager.
    -- GetLayouts().layouts contains only custom rows, but OnLayoutAdded follows
    -- the manager's combined index space after its three preset rows.
    if not active and not generated and type(C_EditMode.OnLayoutAdded) == "function" then
        called, result = pcall(C_EditMode.OnLayoutAdded, targetID, true, false)
        active = called and result ~= false and IsTargetActive()
    end
    if not active and type(C_EditMode.SetActiveLayout) == "function" then
        called, result = pcall(C_EditMode.SetActiveLayout, targetID)
        active = called and result ~= false and IsTargetActive()
    end
    -- Forever currently accepts the saved custom payload but can decline both
    -- addon-driven activation paths without raising a Lua error. The generated
    -- layout remains valid; Blizzard Edit Mode must own the final selection.
    -- Other clients continue to treat failed activation as an API failure.
    local activationPending = not active
    if activationPending and not Offhand.isForever then return false, "activate-api" end

    OffhandCharDB.mainhandLayout = {
        version = 1,
        sourceName = LayoutName(source, sourcePreset and ("Preset " .. tostring(sourceID)) or "Layout"),
        sourceID = sourceID,
        sourcePreset = sourcePreset and true or false,
        generatedName = generatedName,
        generatedID = targetID,
        geometrySignature = self:GetGeometrySignature(),
        movedSystems = moved,
        protectedRepairCandidate = repairFrameName,
        protectedRepairSystems = groupRepaired > 0 and groupRepaired or nil,
        controllerLayout = controllerLayout and true or nil,
        ownerName = UnitName and UnitName("player") or nil,
        activationPending = activationPending and true or nil,
    }
    OffhandCharDB.mainhandLayoutDeferred = nil
    if Offhand.isForever then
        if active then
            OffhandCharDB.foreverEditModeLayoutName = generatedName
            OffhandCharDB.foreverEditModeLayoutID = targetID
            OffhandCharDB.foreverEditModeLegacyRecovery = nil
            OffhandCharDB.foreverEditModeRecovery = nil
        end
        if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
            Offhand.ForeverPersistence:SaveProfileSnapshot(true)
        end
    else
        -- Retail and Anniversary restore the active layout per character by
        -- stable name during login. Without updating that preference here, a
        -- successful Repair HUD is immediately undone on /reload when the old
        -- remembered layout is auto-selected again.
        OffhandCharDB.editModeLayoutName = generatedName
    end
    return true, generatedName, moved, activationPending and "select" or "active"
end

function Mainhand:GetLayoutStatus()
    local record = type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayout or nil
    local deferred = type(OffhandCharDB) == "table"
        and OffhandCharDB.mainhandLayoutDeferred == true or false
    if type(record) ~= "table" then
        return { configured = false, deferred = deferred }
    end
    return {
        configured = true,
        deferred = deferred,
        sourceName = record.sourceName,
        generatedName = record.generatedName,
        generatedID = record.generatedID,
        movedSystems = record.movedSystems,
        protectedRepairCandidate = record.protectedRepairCandidate,
        protectedRepairSystems = record.protectedRepairSystems,
        controllerLayout = record.controllerLayout == true,
        activationPending = record.activationPending == true,
        presetApplied = record.presetApplied == true,
        currentGeometry = record.geometrySignature == self:GetGeometrySignature(),
    }
end

function Mainhand:SetEditModeLayoutDeferred(deferred)
    if type(OffhandCharDB) ~= "table" then return false end
    local wanted = deferred and true or false
    if (OffhandCharDB.mainhandLayoutDeferred == true) == wanted then return true end
    OffhandCharDB.mainhandLayoutDeferred = wanted and true or nil
    if Offhand.isForever and Offhand.ForeverPersistence
        and Offhand.ForeverPersistence.SaveProfileSnapshot then
        Offhand.ForeverPersistence:SaveProfileSnapshot(true)
    end
    return true
end

function Mainhand:PromptReload()
    if not StaticPopupDialogs or not Offhand.ShowPopup then return false end
    local dialog = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD or {
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD = dialog
    if NativeGamepadInterface() then
        -- Forever blocks addon calls to Reload while its Gamepad interface owns
        -- the input stack, even from an addon-owned hardware-click button. Do
        -- not attempt the protected call. The player can safely type /reload.
        dialog.text = Offhand.L["MAINHAND_LAYOUT_RELOAD_MANUAL"]
        dialog.button1 = OKAY or "OK"
        dialog.button2 = nil
        dialog.OnAccept = nil
    else
    local record = type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayout or nil
    dialog.text = NativeGamepadInterface() and type(record) == "table"
        and record.presetApplied == true
        and Offhand.L["MAINHAND_GAMEPAD_PRESET_RELOAD_TEXT"]
        or Offhand.L["MAINHAND_LAYOUT_RELOAD_TEXT"]
        dialog.button1 = RELOADUI or "Reload UI"
        dialog.button2 = LATER or "Later"
        dialog.OnAccept = function()
            if ReloadUI then ReloadUI() end
        end
    end
    Offhand:ShowPopup("OFFHAND_MAINHAND_LAYOUT_RELOAD")
    return true
end

function Mainhand:PromptManualLayoutSelection(layoutName)
    if not StaticPopupDialogs or not Offhand.ShowPopup then return false end
    local dialog = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_SELECT or {
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_SELECT = dialog
    dialog.text = Offhand.L["MAINHAND_LAYOUT_SELECT_MANUAL"]
    dialog.button1 = OKAY or "OK"
    dialog.button2 = nil
    dialog.OnAccept = nil
    Offhand:ShowPopup("OFFHAND_MAINHAND_LAYOUT_SELECT", tostring(layoutName or "Offhand"))
    return true
end

local events = CreateFrame and CreateFrame("Frame") or nil
if events then
    for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "DISPLAY_SIZE_CHANGED",
        "UI_SCALE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, arg1)
        Mainhand:Update(event)
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            Mainhand:EnableForeverGamepadMainMenuAdapter()
        end
        if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
            C_Timer.After(0, function() Mainhand:Update("settled") end)
        end
    end)
end
