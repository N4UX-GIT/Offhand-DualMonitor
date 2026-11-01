-- Mainhand Edit Mode layout generation, persistence, diagnostics, and prompts.
local _, Offhand = ...
local Mainhand = assert(Offhand.Mainhand, "Offhand Mainhand geometry must load before Edit Mode")
local Geometry = assert(Offhand.MainhandGeometry, "Offhand Mainhand geometry must load before Edit Mode")
local Compatibility = assert(Offhand.MainhandCompatibility, "Offhand Mainhand compatibility must load before Edit Mode")
local NativeGamepadInterface = Compatibility.IsNativeGamepadInterface
local ControllerMode = Compatibility.IsControllerMode

local function ExternallyOwnedSystem(entry)
    return Offhand.HUDCompatibility and Offhand.HUDCompatibility.IsExternallyOwnedEditModeSystem
        and Offhand.HUDCompatibility.IsExternallyOwnedEditModeSystem(entry) or false
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
        -- Preset layoutIndex is a zero-based enum used for default anchors.
        -- activeLayout and SetActiveLayout use the one-based combined list.
        if index == active then
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
            return layout, index, index, true
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
        if groupEntry and not ExternallyOwnedSystem(entry) and type(info) == "table"
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

local function IsExtraAbilityRecovery(name)
    return name == "ExtraAbilityContainer" or name == "ExtraActionBarFrame" or name == "ZoneAbilityFrame"
end

local function RefineExtraAbilityRecovery(layout, rect, transformed, repairFrameName)
    if not IsExtraAbilityRecovery(repairFrameName) then return 0, 0 end
    local systems = Enum and Enum.EditModeSystem
    local extra = systems and (systems.ExtraAbilities or systems.ExtraAbility)
    if extra == nil then return 0, 0 end
    for index, entry in ipairs(layout.systems or {}) do
        if entry.system == extra then
            -- Explicit Repair HUD consent covers this one system's custom
            -- relationship too. Let Blizzard apply the serialized anchor.
            entry.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
                offsetX = (rect.left + rect.right) / 2,
                offsetY = rect.bottom + math.min(180, rect.height * 0.25) }
            entry.isInDefaultPosition = false
            return transformed[index] and 0 or 1, 1
        end
    end
    return 0, 0
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

local function ParentScale(frame)
    if not frame or not frame.GetEffectiveScale or not UIParent.GetEffectiveScale then return 1 end
    local ok, scale = pcall(frame.GetEffectiveScale, frame)
    local parent = UIParent:GetEffectiveScale()
    if ok and type(scale) == "number" and scale > 0 and parent and parent > 0 then return scale / parent end
    return 1
end

local function PlaceRetailStatus(entry, mainAnchor, mainFrame, rect)
    if not mainFrame or mainAnchor.relativeTo ~= "UIParent" then return false end
    local indices = Enum and Enum.EditModeStatusTrackingBarSystemIndices
    local secondaryIndex = indices and indices.StatusTrackingBar2
    local secondary = secondaryIndex ~= nil and entry.systemIndex == secondaryIndex
    if indices and indices.StatusTrackingBar1 ~= nil and entry.systemIndex ~= indices.StatusTrackingBar1
        and not secondary then return false end
    local target = secondary and _G.SecondaryStatusTrackingBarContainer or _G.MainStatusTrackingBarContainer
    if secondary and (not _G.SecondaryStatusTrackingBarContainer or not _G.MainStatusTrackingBarContainer) then return false end
    if not target then return false end
    local mw, mh = FrameSize(mainFrame, 570, 40)
    local ms, ts = ParentScale(mainFrame), ParentScale(target)
    local width, height = FrameSize(target, 571, 17)
    local _, primaryHeight = FrameSize(_G.MainStatusTrackingBarContainer, 571, 17)
    local primaryScale = ParentScale(_G.MainStatusTrackingBarContainer)
    local mx, my = PointFractions(mainAnchor.point)
    local screen = {left=0, bottom=0, right=UIParent:GetWidth(), top=UIParent:GetHeight()}
    local bx, by = PointBase(mainAnchor.relativePoint or mainAnchor.point, screen)
    local ax = bx + (tonumber(mainAnchor.offsetX) or 0) * ms
    local ay = by + (tonumber(mainAnchor.offsetY) or 0) * ms
    local center = ax + (0.5 - mx) * mw * ms
    local bottom = ay + (1 - my) * mh * ms + 3
        + (secondary and (primaryHeight * primaryScale + 4) or 0)
    local half = width * ts / 2
    -- Never shrink native frames to fit. Unsupported/oversized source sizes
    -- retain their existing serialized anchor for explicit user adjustment.
    if half * 2 > rect.width - 16 or bottom < rect.bottom or bottom + height * ts > rect.top then return false end
    center = math.max(rect.left + half + 8, math.min(rect.right - half - 8, center))
    local point = FramePoint(target, entry.anchorInfo and entry.anchorInfo.point)
    local px, py = PointFractions(point)
    entry.anchorInfo = {point=point, relativeTo="UIParent", relativePoint="BOTTOMLEFT",
        offsetX=(center + (px - 0.5) * width * ts) / ts,
        offsetY=(bottom + py * height * ts) / ts}
    entry.isInDefaultPosition = false
    return true
end

-- A custom Retail source layout can attach Action Bar 1 to the XP/reputation
-- bar while that bar keeps Blizzard's default anchor to StatusTrackingBarManager.
-- The manager sits at the bottom of the complete span, which has no physical
-- monitor behind it on mixed-height spans, so the whole chain stays unreachable
-- and every Repair HUD rebuild reproduces it. Move only those default status
-- entries to the bottom of Mainhand; systems the player attached to them follow.
local function RebaseDetachedRetailStatus(layout, rect, sourceDefaults)
    local systems = Enum and Enum.EditModeSystem
    local statusSystem = systems and systems.StatusTrackingBar
    if statusSystem == nil then return 0 end
    local indices = Enum.EditModeStatusTrackingBarSystemIndices
    local secondaryIndex = indices and indices.StatusTrackingBar2
    local primary = _G.MainStatusTrackingBarContainer
    local _, primaryHeight = FrameSize(primary, 571, 17)
    local primaryScale = ParentScale(primary)
    local offsetX = (rect.left + rect.right) / 2 - UIParent:GetWidth() / 2
    local refined = 0
    for index, entry in ipairs(layout.systems or {}) do
        local info = entry.anchorInfo
        if sourceDefaults[index] and entry.system == statusSystem and type(info) == "table"
            and info.relativeTo == "StatusTrackingBarManager" then
            local secondary = secondaryIndex ~= nil and entry.systemIndex == secondaryIndex
            local scale = ParentScale(secondary and _G.SecondaryStatusTrackingBarContainer or primary)
            local bottom = rect.bottom + 8 + (secondary and (primaryHeight * primaryScale + 4) or 0)
            entry.anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM",
                offsetX = offsetX / scale, offsetY = bottom / scale }
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
    if not mainAnchor then
        if Offhand.isRetail and not controllerLayout then
            refined = refined + RebaseDetachedRetailStatus(layout, rect, sourceDefaults)
        end
        return refined
    end

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
    if Offhand.isRetail then
        -- Retail's bags are a separate corner system. Use serialized main-bar
        -- geometry for default siblings, not stale live button or bag edges.
        hudLeft, hudRight = mainLeft, mainRight
    end
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
                -- Classic default bars move together with the native artwork
                -- root. Preserve the source XP-to-manager relationship instead
                -- of deriving a child offset from the action-bar/manager sizes.
                local nativeClassic = not Offhand.isRetail and not Offhand.isForever
                    and mainAnchor.relativeTo == "MainMenuBarArtFrame"
                -- Keyboard layouts align the complete XP/reputation bar
                -- with the main/bag bar, not merely Action Button 1.
                if Offhand.isRetail then
                    if PlaceRetailStatus(entry, mainAnchor, mainFrame, rect) then refined = refined + 1 end
                elseif not nativeClassic and PlaceFromMainAnchor(entry, mainAnchor, statusFrame,
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
    return controllerLayout and "Offhand - Gamepad" or "Offhand"
end

local function IsSharedLayoutName(name, controllerLayout)
    if type(name) ~= "string" then return false end
    local base, actual = string.lower(GeneratedLayoutBaseName(controllerLayout)), string.lower(name)
    return actual == base or (actual:sub(1, #base) == base
        and actual:sub(#base + 1):match("^ %(%d+%)$") ~= nil)
end

function Mainhand:IsCharacterEditModeLayoutAllowed(name)
    if type(name) ~= "string" then return true end
    local lower = string.lower(name)
    if lower:sub(1, #"offhand - mainhand - ") ~= "offhand - mainhand - " then return true end
    local player = UnitName and UnitName("player")
    if not player then return false end
    for _, controller in ipairs({false, true}) do
        local expected = string.lower("Offhand - Mainhand" .. (controller and " - Gamepad" or "") .. " - " .. player)
        if lower == expected or (lower:sub(1, #expected) == expected
            and lower:sub(#expected + 1):match("^ %(%d+%)$") ~= nil) then return true end
    end
    return false
end

local function SharedLayoutClient()
    return Offhand.isForever and "forever" or Offhand.isRetail and "retail"
        or tostring(WOW_PROJECT_ID or Offhand.tocVersion or "classic")
end

local function LayoutOwnershipSignature()
    local policy = Offhand.HUDCompatibility
    if not policy or not policy.IsAddonPresent then return "" end
    local owners = {}
    for _, name in ipairs({"EllesmereUIActionBars", "EllesmereUIMinimap", "EllesmereUIChat",
        "EllesmereUICooldownManager", "EllesmereUIQuestTracker", "EllesmereUIUnitFrames",
        "EllesmereUIRaidFrames", "Bartender4", "Dominos", "ElvUI", "Tukui", "Chattynator"}) do
        if policy.IsAddonPresent(name) then owners[#owners + 1] = name end
    end
    return table.concat(owners, ":")
end

local function SharedLayoutRecord(name, controllerLayout, geometrySignature)
    -- Old targeted repairs incorrectly registered character-named rows here.
    -- Metadata alone must never make another character's layout shareable.
    if not IsSharedLayoutName(name, controllerLayout) then return nil end
    local registry = type(OffhandDB) == "table" and OffhandDB.sharedMainhandLayouts
    local record = type(registry) == "table" and registry[name]
    if type(record) == "table" and record.version == 1
        and record.client == SharedLayoutClient()
        and record.ownershipSignature == LayoutOwnershipSignature()
        and (record.controllerLayout == true) == (controllerLayout == true)
        and record.geometrySignature == (geometrySignature or Mainhand:GetGeometrySignature()) then return record end
end

local function IsCurrentCharacterLayoutName(name, controllerLayout, geometrySignature)
    if type(name) ~= "string" then return false end
    if SharedLayoutRecord(name, controllerLayout, geometrySignature) then return true end
    -- Preserve existing character-specific layouts and their rollback tickets.
    local player = UnitName and UnitName("player") or nil
    local expected = string.lower("Offhand - Mainhand"
        .. (controllerLayout and " - Gamepad" or "") .. (player and (" - " .. player) or ""))
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
    -- Without the Gamepad enum, ControllerMode always returns false. Avoid
    -- copying every preset/system tree for a result the copies cannot change.
    if not (Enum and Enum.InputDeviceInterfaceType
        and Enum.InputDeviceInterfaceType.Gamepad ~= nil) then return false end
    EnsureEditModeLoaded()
    -- Periodic recovery needs only the input-style scalar, not full copies of
    -- every system/settings tree. The client adapter preserves Forever's stricter
    -- ownership boundary and reports nil where the existing fallback is needed.
    local controllerMode = Compatibility.ReadControllerPresetMode()
    if controllerMode ~= nil then return controllerMode end
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

-- Switch existing layouts, never regenerate or edit them during a window-mode
-- transition. The return ticket is character-scoped and survives /reload.
local selectingWindowLayout = false
function Mainhand:UpdateWindowModeLayout(metrics)
    if Offhand.isForever or Offhand.isLegacyWrath or _G.ConsolePort or NativeGamepadInterface()
        or type(OffhandCharDB) ~= "table" then return false, "unsupported" end
    local record = OffhandCharDB.mainhandLayout
    if type(record) ~= "table" or record.controllerLayout or record.activationPending
        or not IsCurrentCharacterLayoutName(record.generatedName, false, record.geometrySignature)
        or (record.ownerName and UnitName and record.ownerName ~= UnitName("player"))
        or (record.ownerGUID and UnitGUID and UnitGUID("player") and record.ownerGUID ~= UnitGUID("player")) then return false, "unmanaged" end
    if not metrics or type(metrics.isSpanned) ~= "boolean" then return true, "metrics" end
    if selectingWindowLayout or Geometry.IsPlayerCombatRestricted() then return true, "combat" end
    if Offhand.IsCinematicOrMovieActive and Offhand:IsCinematicOrMovieActive() then return true, "cinematic" end
    local manager = _G.EditModeManagerFrame
    if manager and manager.IsShown and manager:IsShown() then return true, "edit-mode" end
    local data, presets = EditModeData(), Presets()
    if not data or #presets == 0 or not C_EditMode or not C_EditMode.SetActiveLayout then return true, "api" end
    if ControllerMode(presets) then return false, "gamepad" end
    local active, activeID, _, activePreset = ResolveActiveLayout(data, presets)
    if not active then return true, "active" end
    local activeName = LayoutName(active)
    local windowed = not Offhand.db or not Offhand.db.enabled or not metrics.isSpanned
    local ticket = OffhandCharDB.mainhandWindowedLayout
    if type(ticket) ~= "table" or ticket.generatedName ~= record.generatedName then ticket = nil end
    local target, targetID, _, targetPreset
    if windowed then
        if activeName ~= record.generatedName or activePreset then
            if ticket and (activeName ~= ticket.windowedName or activePreset ~= ticket.windowedPreset) then
                OffhandCharDB.mainhandWindowedLayout = nil
            end
            return true, "windowed"
        end
        if OffhandCharDB.mainhandWindowedManualLayout == activeName then return true, "manual" end
        target, targetID, _, targetPreset = FindNamedLayout(data, presets, record.sourceName)
        if not target or targetID == activeID or targetPreset ~= (record.sourcePreset == true)
            or LayoutName(target):find("Offhand - Mainhand", 1, true) == 1 then return true, "source-missing" end
    else
        OffhandCharDB.mainhandWindowedManualLayout = nil
        if not ticket then return false, "spanned" end
        if activeName == record.generatedName and not activePreset then
            OffhandCharDB.mainhandWindowedLayout = nil
            return true, "spanned"
        end
        if activeName ~= ticket.windowedName or activePreset ~= ticket.windowedPreset then
            OffhandCharDB.mainhandWindowedLayout = nil
            return true, "manual"
        end
        if record.geometrySignature ~= self:GetGeometrySignature() then return true, "stale" end
        target, targetID, _, targetPreset = FindNamedLayout(data, presets, record.generatedName)
        if not target or targetPreset then return true, "generated-missing" end
    end
    selectingWindowLayout = true
    local ok, result = pcall(C_EditMode.SetActiveLayout, targetID)
    selectingWindowLayout = false
    local confirmed = EditModeData()
    if not ok or result == false or not confirmed or tonumber(confirmed.activeLayout) ~= targetID then
        return true, "select-failed"
    end
    if windowed then
        OffhandCharDB.mainhandWindowedLayout = {generatedName=record.generatedName,
            windowedName=LayoutName(target),windowedPreset=targetPreset == true}
    else
        OffhandCharDB.mainhandWindowedLayout = nil
    end
    OffhandCharDB.editModeLayoutName = LayoutName(target)
    return true, windowed and "restored" or "resumed"
end

function Mainhand:RememberWindowModeLayoutSelection(name)
    if type(OffhandCharDB) ~= "table" or type(name) ~= "string" then return end
    OffhandCharDB.mainhandWindowedLayout = nil
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    OffhandCharDB.mainhandWindowedManualLayout = metrics and not metrics.isSpanned and name or nil
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
        return string.format("Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Gamepad=%s | LastFailure=%s",
            tostring(active),
            status.configured and tostring(status.generatedName or "recorded") or "none",
            status.configured and (status.currentGeometry and "current" or "stale") or "none",
            needsAttention and "yes" or "no", tostring(reason or "unknown"),
            NativeGamepadInterface() and "yes" or "no", tostring(self.lastLayoutFailure or "none"))
    end
    return string.format(
        "Supported=%s | API=%s/%s | Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Repair=%s/%s | GamepadMenu=%s | GamepadPanels=%s | GamepadReticle=%s | GamepadBack=%s | LastFailure=%s",
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
        tostring(self:GetForeverGamepadMainMenuDiagnostics()),
        self:GetForeverGamepadDestinationPanelDiagnostics(), tostring(self:GetForeverGamepadReticleDiagnostics()),
        Offhand.WorkspaceBehavior and Offhand.WorkspaceBehavior.GetGamepadWorkspaceBackDiagnostics
            and Offhand.WorkspaceBehavior:GetGamepadWorkspaceBackDiagnostics() or "unavailable",
        tostring(self.lastLayoutFailure or "none"))
end

function Mainhand:CreateOrUpdateEditModeLayout(options)
    options = type(options) == "table" and options or nil
    local repairFrameName = options and options.repairFrameName or nil
    local repairSystems = options and options.repairSystems
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
    local playerName = UnitName and UnitName("player") or nil
    if modeRecord and modeRecord.ownerName and playerName and modeRecord.ownerName ~= playerName then
        modeRecord = nil
    end
    local playerGUID = UnitGUID and UnitGUID("player")
    if modeRecord and modeRecord.ownerGUID and playerGUID and modeRecord.ownerGUID ~= playerGUID then
        modeRecord = nil
    end
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
                sourceID = index
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
        local named, namedID, namedIndex, namedPreset =
            FindNamedLayout(data, presets, modeRecord.sourceName)
        if named and namedPreset then
            source, sourceID, sourceIndex, sourcePreset = named, namedID, namedIndex, true
        end
        for index, layout in ipairs(presets) do
            if not source and index == wanted then
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
    -- A fresh character may start on an account layout made for another span.
    -- Rebuild from its original source, never translate an already moved HUD.
    if not modeRecord then
        local registry = type(OffhandDB) == "table" and OffhandDB.sharedMainhandLayouts
        local prior = type(registry) == "table" and registry[LayoutName(source, "")]
        if type(prior) == "table" and prior.version == 1 and prior.client == SharedLayoutClient() then
            local original, originalID, originalIndex, originalPreset = FindNamedLayout(data, presets, prior.sourceName)
            if not original or original == source then return false, "source" end
            source, sourceID, sourceIndex, sourcePreset = original, originalID, originalIndex, originalPreset
        elseif string.lower(LayoutName(source, "")):find("offhand - mainhand - ", 1, true) == 1 then
            -- A legacy account row may have no provenance at all. Never use
            -- another incarnation/character's already-translated HUD as source.
            source, sourceID, sourceIndex, sourcePreset = presets[1], 1, 1, true
        end
    end
    local generatedName = matchingRecord and matchingRecord.generatedName or nil
    local generated, _, generatedIndex = FindNamedLayout(data, presets, generatedName)
    -- Explicit full setup can promote this character's already-positioned legacy
    -- layout. Preserve its actual anchors instead of rebuilding from Modern and
    -- losing the adjustments that made the individual layout accurate.
    local legacyLayout
    if Offhand.isRetail and not Offhand.isForever and generated and matchingRecord
        and matchingRecord.geometrySignature == self:GetGeometrySignature()
        and not IsSharedLayoutName(generatedName, controllerLayout)
        and not repairFrameName and not repairSystems then
        legacyLayout = generated
        generatedName, generated, generatedIndex = nil, nil, nil
        for index, candidate in ipairs(data.layouts) do
            if SharedLayoutRecord(LayoutName(candidate), controllerLayout) then
                generatedName, generated, generatedIndex = LayoutName(candidate), candidate, index
                break
            end
        end
    end
    -- SaveLayouts can succeed before a later activation step fails. Recover
    -- that exact Offhand-owned row on retry so an interrupted transaction does
    -- not create a suffixed duplicate or consume another custom-layout slot.
    if not generated and not matchingRecord and (not Offhand.isRetail or Offhand.isForever) then
        local player = UnitName and UnitName("player") or nil
        local expectedName = "Offhand - Mainhand" .. (controllerLayout and " - Gamepad" or "")
            .. (player and (" - " .. player) or "")
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
        if IsCurrentCharacterLayoutName(preferredName, false) and not SharedLayoutRecord(preferredName, false) then
            local preferred, _, preferredIndex = FindNamedLayout(data, presets, preferredName)
            if preferred and preferredIndex then
                generatedName = preferredName
                generated = preferred
                generatedIndex = preferredIndex
            end
        end
    end
    -- Setup is an explicit player action. Adopt an existing compatible account
    -- layout without rewriting it, preserving edits made by another character.
    -- A name alone is not proof of ownership or compatible monitor geometry.
    if not generated and not legacyLayout and not repairFrameName and not repairSystems then
        for index, candidate in ipairs(data.layouts) do
            local name = LayoutName(candidate, "")
            local shared = SharedLayoutRecord(name, controllerLayout)
            if shared then
                local targetID = (Offhand.isForever and 3 or #presets) + index
                local active = tonumber(data.activeLayout) == targetID
                if not active and type(C_EditMode.SetActiveLayout) == "function" then
                    local called, result = pcall(C_EditMode.SetActiveLayout, targetID)
                    local current = EditModeData()
                    active = called and result ~= false and current
                        and tonumber(current.activeLayout) == targetID or false
                end
                if not active and not Offhand.isForever then return false, "activate-api" end
                OffhandCharDB.mainhandLayout = {
                    version = 1, generatedName = name, generatedID = targetID,
                    sourceName = source == candidate and shared.sourceName or LayoutName(source),
                    sourceID = source == candidate and shared.sourceID or sourceID,
                    sourcePreset = source == candidate and shared.sourcePreset or sourcePreset == true,
                    geometrySignature = self:GetGeometrySignature(),
                    movedSystems = shared.movedSystems, controllerLayout = controllerLayout and true or nil,
                    ownerName = UnitName and UnitName("player") or nil,
                    ownerGUID = playerGUID,
                    activationPending = not active and true or nil,
                }
                OffhandCharDB.mainhandLayoutDeferred = nil
                OffhandCharDB.hudSetupReminder = nil
                OffhandCharDB.hudSetupReminderDeclined = nil
                OffhandCharDB.mainhandWindowedLayout = nil
                OffhandCharDB.mainhandWindowedManualLayout = nil
                if Offhand.isForever then
                    if active then
                        OffhandCharDB.foreverEditModeLayoutName = name
                        OffhandCharDB.foreverEditModeLayoutID = targetID
                        OffhandCharDB.foreverEditModeLegacyRecovery = nil
                        OffhandCharDB.foreverEditModeRecovery = nil
                    end
                    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
                        Offhand.ForeverPersistence:SaveProfileSnapshot(true)
                    end
                else
                    OffhandCharDB.editModeLayoutName = name
                end
                return true, name, shared.movedSystems or 0, active and "active" or "select"
            end
        end
    end
    if not generatedName then generatedName = UniqueLayoutName(data, controllerLayout) end

    local repairExtra = IsExtraAbilityRecovery(repairFrameName)
    local selective = type(repairSystems) == "table" and #repairSystems > 0
    -- Targeted recovery preserves the other systems in the existing generated
    -- layout, including edits made since it was first created.
    local selectiveSource = selective and ResolveActiveLayout(data, presets) or nil
    local layout = DeepCopy(legacyLayout or selectiveSource or (repairExtra and (generated or source) or source))
    local sourceDefaults = {}
    local externallyOwned = {}
    for index, entry in ipairs(layout.systems or {}) do
        sourceDefaults[index] = entry.isInDefaultPosition ~= false and not ExternallyOwnedSystem(entry)
        if ExternallyOwnedSystem(entry) then externallyOwned[index] = DeepCopy(entry) end
    end
    local editModeSystems = Enum and Enum.EditModeSystem
    local actionIndices = Enum and Enum.EditModeActionBarSystemIndices
    local foreverActionSystem = editModeSystems and editModeSystems.ActionBar
    local foreverClassBar = actionIndices and actionIndices.ClassBar
    local moved, transformed = 0, {}
    if legacyLayout then moved = matchingRecord.movedSystems or #(layout.systems or {}) end
    if not legacyLayout and not repairExtra and not selective then
        moved, transformed = TransformLayout(layout, rect, function(entry)
            -- Forever's empty MultiCast/Totem Edit Mode preview can call
            -- C_TooltipInfo.GetSpellByID(nil) after an addon-generated relocation.
            -- Leave this ambiguous ClassBar entry exactly where the source layout
            -- put it; stance, pet and possess have their own unambiguous indices.
            return ExternallyOwnedSystem(entry) or (Offhand.isForever and foreverActionSystem ~= nil and foreverClassBar ~= nil
                and entry.system == foreverActionSystem and entry.systemIndex == foreverClassBar)
        end)
        RefineStandardHUDLayout(layout, rect, sourceDefaults, controllerLayout)
    end
    local groupMoved, groupRepaired = 0, 0
    if not legacyLayout and not repairExtra and not selective then
        groupMoved, groupRepaired = RefineGroupHUDLayout(layout, rect, sourceDefaults,
            transformed, repairFrameName)
    end
    moved = moved + groupMoved
    local extraMoved, extraRepaired = RefineExtraAbilityRecovery(layout, rect, transformed, repairFrameName)
    moved = moved + extraMoved
    if selective then
        for _, request in ipairs(repairSystems) do
            local found
            for _, entry in ipairs(layout.systems or {}) do
                if entry.system == request.system
                    and (request.systemIndex == nil or entry.systemIndex == request.systemIndex) then
                    if ExternallyOwnedSystem(entry) then return false, "external" end
                    entry.anchorInfo = DeepCopy(request.anchorInfo)
                    entry.isInDefaultPosition = false
                    moved, found = moved + 1, true
                    break
                end
            end
            if not found then return false, "repair-system", LayoutName(source, "layout"), 0 end
        end
    end
    if repairExtra and extraRepaired == 0 then
        return false, "repair-system", LayoutName(source, "layout"), moved
    end
    if IsGroupRecoveryFrame(repairFrameName) and groupRepaired == 0 then
        return false, "repair-system", LayoutName(source, "layout"), moved
    end
    -- Refinement can inspect neighbouring native systems. Restore external
    -- entries byte-for-byte even if a requested repair traversed that group.
    for index, entry in pairs(externallyOwned) do layout.systems[index] = entry end
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
    -- Keep ownership metadata even if native activation fails after SaveLayouts.
    -- The next setup attempt can adopt this exact row without consuming a slot.
    if type(OffhandDB) ~= "table" then OffhandDB = {} end
    if type(OffhandDB.sharedMainhandLayouts) ~= "table" then OffhandDB.sharedMainhandLayouts = {} end
    if legacyLayout and generated then
        OffhandDB.sharedMainhandLayoutBackups = OffhandDB.sharedMainhandLayoutBackups or {}
        OffhandDB.sharedMainhandLayoutBackups[generatedName] = DeepCopy(generated)
    end
    if IsSharedLayoutName(generatedName, controllerLayout) then
        OffhandDB.sharedMainhandLayouts[generatedName] = {
            version = 1, client = SharedLayoutClient(), geometrySignature = self:GetGeometrySignature(),
            ownershipSignature = LayoutOwnershipSignature(),
            controllerLayout = controllerLayout and true or nil, movedSystems = moved,
            sourceName = LayoutName(source), sourceID = sourceID, sourcePreset = sourcePreset == true,
        }
    end
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
        protectedRepairSystems = groupRepaired + extraRepaired > 0 and groupRepaired + extraRepaired or nil,
        controllerLayout = controllerLayout and true or nil,
        ownerName = UnitName and UnitName("player") or nil,
        ownerGUID = playerGUID,
        activationPending = activationPending and true or nil,
    }
    OffhandCharDB.mainhandLayoutDeferred = nil
    OffhandCharDB.hudSetupReminder = nil
    OffhandCharDB.hudSetupReminderDeclined = nil
    OffhandCharDB.mainhandWindowedLayout = nil
    OffhandCharDB.mainhandWindowedManualLayout = nil
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
    if Offhand.HUD and Offhand.HUD.CompleteProtectedHUDLayoutRecovery then
        Offhand.HUD:CompleteProtectedHUDLayoutRecovery()
    end
    return true, generatedName, moved, activationPending and "select" or "active"
end

function Mainhand:GetLayoutStatus()
    local record = type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayout or nil
    local deferred = type(OffhandCharDB) == "table"
        and OffhandCharDB.mainhandLayoutDeferred == true or false
    local guid = UnitGUID and UnitGUID("player")
    if type(record) ~= "table" or not self:IsCharacterEditModeLayoutAllowed(record.generatedName)
        or (record.ownerName and UnitName and record.ownerName ~= UnitName("player"))
        or (record.ownerGUID and guid and record.ownerGUID ~= guid) then
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
    if not wanted then
        OffhandCharDB.hudSetupReminder = nil
        OffhandCharDB.hudSetupReminderDeclined = nil
    end
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

