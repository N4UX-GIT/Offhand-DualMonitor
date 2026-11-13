-- Mainhand Edit Mode layout generation, persistence, diagnostics, and prompts.
local _, Offhand = ...
local Mainhand = assert(Offhand.Mainhand, "Offhand Mainhand geometry must load before Edit Mode")
local Geometry = assert(Offhand.MainhandGeometry, "Offhand Mainhand geometry must load before Edit Mode")
local Compatibility = assert(Offhand.MainhandCompatibility, "Offhand Mainhand compatibility must load before Edit Mode")
local NativeGamepadInterface = Compatibility.IsNativeGamepadInterface
local ControllerMode = Compatibility.IsControllerMode
local fallbackBase = "Offhand HUD - Blizzard"

local function IsEllesmereFallbackName(name)
    return name == fallbackBase or name:match("^Offhand HUD %- Blizzard %(%d+%)$") ~= nil
end

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

local function SameLayoutData(first, second)
    if first == second then return true end
    if type(first) ~= "table" or type(second) ~= "table" then return false end
    for key, value in pairs(first) do
        if not SameLayoutData(value, second[key]) then return false end
    end
    for key in pairs(second) do
        if first[key] == nil then return false end
    end
    return true
end

local function PublicLayoutNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return false end
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function MatchesSavedAnchor(actual, expected)
    if type(actual) ~= "table" or type(expected) ~= "table" then return false end
    for key, value in pairs(expected) do
        local saved = actual[key]
        if key == "offsetX" or key == "offsetY" then
            if not PublicLayoutNumber(saved) or not PublicLayoutNumber(value) then return false end
            -- Blizzard persists offsets to one decimal place across a restart.
            -- Accept the generated value or its serialized representation.
            if math.abs(saved - value) > 0.01 then
                local persisted = tonumber(("%.1f"):format(value))
                if not persisted or math.abs(saved - persisted) > 0.001 then return false end
            end
        elseif not SameLayoutData(saved, value) then return false end
    end
    for key in pairs(actual) do
        if expected[key] == nil then return false end
    end
    return true
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

local function FindGamepadPreset(presets)
    local style = Enum and Enum.InputDeviceInterfaceType and Enum.InputDeviceInterfaceType.Gamepad
    for index, candidate in ipairs(presets) do
        local name = type(candidate.layoutName) == "string" and candidate.layoutName or ""
        if (style ~= nil and candidate.interfaceStyle == style) or name:lower():find("gamepad", 1, true) then
            return candidate, index
        end
    end
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
        if entry.isInDefaultPosition ~= false and not (skipEntry and skipEntry(entry)) then
            for _, key in ipairs({"anchorInfo", "anchorInfo2"}) do
                local info = entry[key]
                if type(info) == "table" and (info.relativeTo == nil or info.relativeTo == "UIParent")
                    and type(info.offsetX) == "number" and type(info.offsetY) == "number" then
                    local relativePoint = info.relativePoint or info.point or "CENTER"
                    local sx, sy = PointBase(relativePoint, screen)
                    local gx, gy = PointBase(relativePoint, rect)
                    info.offsetX = info.offsetX + gx - sx
                    info.offsetY = info.offsetY + gy - sy
                    transformed[index] = true
                end
            end
            if transformed[index] then
                entry.isInDefaultPosition = false
                moved = moved + 1
            end
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

local function IsEncounterRecovery(name)
    return name == "EncounterBar" or name == "UIWidgetPowerBarContainerFrame"
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

local function RefineEncounterRecovery(layout, rect, repairFrameName)
    if not IsEncounterRecovery(repairFrameName) then return 0 end
    local system = Enum and Enum.EditModeSystem and Enum.EditModeSystem.EncounterBar
    if system == nil then return 0 end
    for _, entry in ipairs(layout.systems or {}) do
        if entry.system == system and not ExternallyOwnedSystem(entry) then
            -- A custom/system-relative anchor survives ordinary generation.
            -- Explicit Repair HUD consent covers this system only. Blizzard
            -- applies the saved anchor; never reanchor its protected live root.
            -- EditModeSystemMixin divides serialized offsets by GetScale()
            -- when applying them. Keep saved offsets in UIParent units.
            entry.anchorInfo = {
                point = "CENTER", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
                offsetX = (rect.left + rect.right) / 2,
                offsetY = rect.bottom + rect.height * 0.6,
            }
            entry.anchorInfo2 = nil
            entry.isInDefaultPosition = false
            return 1
        end
    end
    return 0
end

local function PlaceRetailStatus(entry, mainAnchor, mainFrame, rect)
    if mainAnchor and (not mainFrame or mainAnchor.relativeTo ~= "UIParent") then return false end
    local indices = Enum and Enum.EditModeStatusTrackingBarSystemIndices
    local secondaryIndex = indices and indices.StatusTrackingBar2
    local secondary = secondaryIndex ~= nil and entry.systemIndex == secondaryIndex
    if indices and indices.StatusTrackingBar1 ~= nil and entry.systemIndex ~= indices.StatusTrackingBar1
        and not secondary then return false end
    local target = secondary and _G.SecondaryStatusTrackingBarContainer or _G.MainStatusTrackingBarContainer
    if secondary and (not _G.SecondaryStatusTrackingBarContainer or not _G.MainStatusTrackingBarContainer) then return false end
    if not target then return false end
    local ts = ParentScale(target)
    local width, height = FrameSize(target, 571, 17)
    local _, primaryHeight = FrameSize(_G.MainStatusTrackingBarContainer, 571, 17)
    local primaryScale = ParentScale(_G.MainStatusTrackingBarContainer)
    local center, bottom = (rect.left + rect.right) / 2, rect.bottom + 8
    if mainAnchor then
        local mw, mh = FrameSize(mainFrame, 570, 40)
        local ms = ParentScale(mainFrame)
        local mx, my = PointFractions(mainAnchor.point)
        local screen = {left=0, bottom=0, right=UIParent:GetWidth(), top=UIParent:GetHeight()}
        local bx, by = PointBase(mainAnchor.relativePoint or mainAnchor.point, screen)
        local ax = bx + (tonumber(mainAnchor.offsetX) or 0) * ms
        local ay = by + (tonumber(mainAnchor.offsetY) or 0) * ms
        center = ax + (0.5 - mx) * mw * ms
        bottom = ay + (1 - my) * mh * ms + 3
    end
    if secondary then bottom = bottom + primaryHeight * primaryScale + 4 end
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
    if mainAnchor then return true end
    return true, {center = center, bottom = bottom, width = width * ts, height = height * ts}
end

local function StackRetailStatusChainBars(main, bars, actions, rect, status, transformed)
    local mainFrame = _G.MainActionBar
    if not mainFrame or main.anchorInfo2 then return 0 end
    local anchor = main.anchorInfo
    local mainWidth, mainHeight = FrameSize(mainFrame, nil, nil)
    if not mainWidth or not mainHeight then return 0 end
    local scale = ParentScale(mainFrame)
    local px, py = PointFractions(anchor.point)
    local rx, ry = PointFractions(anchor.relativePoint or anchor.point)
    local x = status.center + (rx - 0.5) * status.width + (tonumber(anchor.offsetX) or 0)
        + (0.5 - px) * mainWidth * scale
    local top = status.bottom + ry * status.height + (tonumber(anchor.offsetY) or 0)
        + (1 - py) * mainHeight * scale

    -- Blizzard stacks default bottom bars independently of a custom main bar.
    -- Link only default rows so they follow the recovered chain.
    local moved, relativeTo = 0, "MainActionBar"
    for _, row in ipairs({
        {index = actions.Bar2, frame = _G.MultiBarBottomLeft, name = "MultiBarBottomLeft"},
        {index = actions.Bar3, frame = _G.MultiBarBottomRight, name = "MultiBarBottomRight"},
    }) do
        local bar = bars[row.index]
        if not bar or not row.frame then break end
        local barWidth, barHeight = FrameSize(row.frame, nil, nil)
        if not barWidth or not barHeight then break end
        local barScale = ParentScale(row.frame)
        local halfWidth = barWidth * barScale / 2
        local nextTop = top + 4 + barHeight * barScale
        if top + 4 < rect.bottom or nextTop > rect.top or x - halfWidth < rect.left
            or x + halfWidth > rect.right then break end

        local desired = {point = "BOTTOM", relativeTo = relativeTo,
            relativePoint = "TOP", offsetX = 0, offsetY = 4}
        if not MatchesSavedAnchor(bar.entry.anchorInfo, desired) or bar.entry.isInDefaultPosition ~= false then
            if not bar.canMove then break end
            bar.entry.anchorInfo, bar.entry.isInDefaultPosition = desired, false
            if not transformed[bar.index] then moved = moved + 1 end
        end
        top, relativeTo = nextTop, row.name
    end
    return moved
end

local function RetailStatusBounds(entry, rootIndex, statuses)
    local anchor = entry and entry.anchorInfo
    if not anchor or entry.anchorInfo2 or anchor.relativeTo ~= "UIParent"
        or not PublicLayoutNumber(anchor.offsetX) or not PublicLayoutNumber(anchor.offsetY) then return end
    local frame = rootIndex == statuses.StatusTrackingBar1 and _G.MainStatusTrackingBarContainer
        or rootIndex == statuses.StatusTrackingBar2 and _G.SecondaryStatusTrackingBarContainer
    local width, height = FrameSize(frame, nil, nil)
    if not width or not height then return end
    local scale = ParentScale(frame)
    width, height = width * scale, height * scale
    local screen = {left = 0, bottom = 0, right = UIParent:GetWidth(), top = UIParent:GetHeight()}
    local x, y = PointBase(anchor.relativePoint or anchor.point, screen)
    local px, py = PointFractions(anchor.point)
    return {center = x + anchor.offsetX * scale + (0.5 - px) * width,
        bottom = y + anchor.offsetY * scale - py * height, width = width, height = height}
end

-- A custom Action Bar 1 can follow a default status container into the void
-- below Mainhand. Move the serialized status roots and preserve the link.
local function RebaseRetailStatusChain(layout, rect, sourceDefaults, transformed, priorSource)
    local systems = Enum and Enum.EditModeSystem
    local actions = Enum and Enum.EditModeActionBarSystemIndices
    local statuses = Enum and Enum.EditModeStatusTrackingBarSystemIndices
    if not systems or not actions or not statuses or not systems.ActionBar
        or not systems.StatusTrackingBar or not actions.MainBar then return 0 end

    local priorRows = {}
    if priorSource then
        -- Beta 32 translated default rows into Mainhand before serializing
        -- them as custom. Compare with that placement to detect player edits.
        local projected = DeepCopy(priorSource)
        TransformLayout(projected, rect, ExternallyOwnedSystem)
        for index, entry in ipairs(priorSource.systems or {}) do
            if entry.system == systems.ActionBar and entry.systemIndex ~= nil
                and (entry.systemIndex == actions.Bar2 or entry.systemIndex == actions.Bar3)
                and entry.isInDefaultPosition ~= false and not entry.anchorInfo2 then
                priorRows[entry.systemIndex] = projected.systems[index]
            end
        end
    end

    local main, rootIndex
    local defaultStatus, savedStatus, defaultBars = {}, {}, {}
    for index, entry in ipairs(layout.systems or {}) do
        local anchor = entry.anchorInfo
        if type(anchor) == "table" then
            if entry.system == systems.ActionBar then
                if entry.systemIndex == actions.MainBar and not sourceDefaults[index]
                    and not ExternallyOwnedSystem(entry) then
                    main = entry
                    if anchor.relativeTo == "MainStatusTrackingBarContainer" then
                        rootIndex = statuses.StatusTrackingBar1
                    elseif anchor.relativeTo == "SecondaryStatusTrackingBarContainer" then
                        rootIndex = statuses.StatusTrackingBar2
                    end
                elseif not entry.anchorInfo2 and not ExternallyOwnedSystem(entry)
                    and entry.systemIndex ~= nil and (entry.systemIndex == actions.Bar2 or entry.systemIndex == actions.Bar3) then
                    local prior = priorRows[entry.systemIndex]
                    if prior then
                        local canMove = (entry.isInDefaultPosition == false) == (prior.isInDefaultPosition == false)
                            and MatchesSavedAnchor(anchor, prior.anchorInfo)
                        defaultBars[entry.systemIndex] = {entry = entry, index = index, canMove = canMove}
                    elseif not priorSource and sourceDefaults[index] then
                        defaultBars[entry.systemIndex] = {entry = entry, index = index, canMove = true}
                    end
                end
            elseif entry.system == systems.StatusTrackingBar and not entry.anchorInfo2
                and not ExternallyOwnedSystem(entry) and entry.systemIndex ~= nil then
                savedStatus[entry.systemIndex] = entry
                if sourceDefaults[index] and anchor.relativeTo == "StatusTrackingBarManager" then
                    defaultStatus[entry.systemIndex] = entry
                end
            end
        end
    end

    if priorSource then
        local status = RetailStatusBounds(rootIndex and savedStatus[rootIndex], rootIndex, statuses)
        if not status then return 0 end
        return StackRetailStatusChainBars(main, defaultBars, actions, rect, status, transformed)
    end
    local root = rootIndex and defaultStatus[rootIndex]
    if not root then return 0 end
    local placed, status = PlaceRetailStatus(root, nil, nil, rect)
    if not placed then return 0 end
    local companionIndex = rootIndex == statuses.StatusTrackingBar1
        and statuses.StatusTrackingBar2 or statuses.StatusTrackingBar1
    local companion = defaultStatus[companionIndex]
    local moved = companion and companion ~= root and PlaceRetailStatus(companion, nil, nil, rect) and 2 or 1
    return moved + StackRetailStatusChainBars(main, defaultBars, actions, rect, status, transformed)
end

local function MainAnchorOrigin(layout, mainAnchor)
    local screen = {left=0, bottom=0, right=UIParent:GetWidth(), top=UIParent:GetHeight()}
    local relative = screen
    if mainAnchor.relativeTo ~= nil and mainAnchor.relativeTo ~= "UIParent" then
        -- Forever's default main bar follows MicroMenuContainer. Resolve that
        -- one known serialized relationship, never its stale live screen edges.
        if mainAnchor.relativeTo ~= "MicroMenuContainer" then return end
        local menuSystem = Enum.EditModeSystem.MicroMenu
        local menuAnchor
        for _, entry in ipairs(layout.systems or {}) do
            if menuSystem ~= nil and entry.system == menuSystem then menuAnchor = entry.anchorInfo; break end
        end
        if type(menuAnchor) ~= "table" or (menuAnchor.relativeTo ~= nil and menuAnchor.relativeTo ~= "UIParent")
            or type(menuAnchor.offsetX) ~= "number" or type(menuAnchor.offsetY) ~= "number" then return end
        local menuFrame = _G.MicroMenuContainer
        local width, height = FrameSize(menuFrame, 0, 0)
        if width <= 0 or height <= 0 then return end
        local scale = ParentScale(menuFrame)
        width, height = width * scale, height * scale
        local x, y = PointBase(menuAnchor.relativePoint or menuAnchor.point, screen)
        local px, py = PointFractions(menuAnchor.point)
        local left, bottom = x + menuAnchor.offsetX - px*width, y + menuAnchor.offsetY - py*height
        relative = {left=left, bottom=bottom, right=left+width, top=bottom+height}
    end
    if type(mainAnchor.offsetX) ~= "number" or type(mainAnchor.offsetY) ~= "number" then return end
    local bx, by = PointBase(mainAnchor.relativePoint or mainAnchor.point, relative)
    return bx + mainAnchor.offsetX, by + mainAnchor.offsetY
end

local function ForeverStatusFrame(entry)
    local indices = Enum and Enum.EditModeStatusTrackingBarSystemIndices
    if indices and indices.StatusTrackingBar1 ~= nil and entry.systemIndex == indices.StatusTrackingBar1 then
        return _G.MainStatusTrackingBarContainer
    end
    if indices and indices.StatusTrackingBar2 ~= nil and entry.systemIndex == indices.StatusTrackingBar2 then
        return _G.SecondaryStatusTrackingBarContainer
    end
end

local function PlaceForeverStatus(entry, layout, rect, sourceDefaults, mainAnchor, mainFrame, attachToMain)
    local target = ForeverStatusFrame(entry)
    if not target then return false end
    local ax, ay = MainAnchorOrigin(layout, mainAnchor)
    if not ax then return false end
    local mainWidth, mainHeight = FrameSize(mainFrame, 570, 40)
    local mx, my = PointFractions(mainAnchor.point)
    local mainScale = ParentScale(mainFrame)
    local mainTop = ay + (1 - my) * mainHeight * mainScale
    local gap = 3
    local indices = Enum.EditModeStatusTrackingBarSystemIndices
    if entry.systemIndex == indices.StatusTrackingBar2 then
        for index, primary in ipairs(layout.systems or {}) do
            if sourceDefaults[index] and primary.system == entry.system
                and primary.systemIndex == indices.StatusTrackingBar1 then
                local _, height = FrameSize(_G.MainStatusTrackingBarContainer, 571, 14)
                gap = gap + height * ParentScale(_G.MainStatusTrackingBarContainer) + 4
                break
            end
        end
    end
    local width, height = FrameSize(target, 571, 14)
    local scale = ParentScale(target)
    width, height = width * scale, height * scale
    local bottom = mainTop + gap
    if width > rect.width - 16 or bottom < rect.bottom or bottom + height > rect.top then return false end
    if attachToMain then
        -- The fitter can move MicroMenuContainer and the native main bar with it.
        -- Keep the vertical spacing in Blizzard's saved anchor chain.
        local center = ax + (0.5 - mx) * mainWidth * mainScale
        local x = math.max(rect.left + width / 2 + 8, math.min(rect.right - width / 2 - 8, center))
        entry.anchorInfo = {point = "BOTTOM", relativeTo = "MainActionBar", relativePoint = "TOP",
            offsetX = x - center, offsetY = gap}
    else
        entry.anchorInfo = {point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
            offsetX = (rect.left + rect.right) / 2, offsetY = bottom}
    end
    entry.anchorInfo2, entry.isInDefaultPosition = nil, false
    return true
end

local function CenterForeverStatus(layout, rect, placements)
    if not next(placements) then return end
    local systems, actions = Enum.EditModeSystem, Enum.EditModeActionBarSystemIndices
    local main = _G.MainActionBar
    for _, entry in ipairs(layout.systems or {}) do
        local anchor = entry.anchorInfo
        if entry.system == systems.ActionBar and entry.systemIndex == actions.MainBar
            and anchor and anchor.relativeTo == "MicroMenuContainer"
            and not entry.anchorInfo2 and not ExternallyOwnedSystem(entry) then
            local x = MainAnchorOrigin(layout, anchor)
            if not x then return end
            local width = FrameSize(main, 570, 40)
            local px = PointFractions(anchor.point)
            local center = x + (0.5 - px) * width * ParentScale(main)
            -- Fit can move the menu and action bar as a group. Center only
            -- the status anchors we generated, retaining their vertical chain.
            for _, statusAnchor in ipairs(placements) do
                statusAnchor.offsetX = (rect.left + rect.right) / 2 - center
            end
            return
        end
    end
end

local function RefineForeverSecondaryBars(layout, rect, sourceDefaults, mainAnchor, mainFrame, statusHeight, attachToMain)
    local indices = Enum and Enum.EditModeActionBarSystemIndices
    local actionSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
    if not Offhand.isForever or not indices or not actionSystem then return 0 end
    -- Serialize distinct rows above the main bar and its status containers.
    local ax, ay = MainAnchorOrigin(layout, mainAnchor)
    if not ax then return 0 end
    local mw, mh = FrameSize(mainFrame, 570, 40)
    local ms = ParentScale(mainFrame)
    local mx, my = PointFractions(mainAnchor.point)
    local mainLeft = ax - mx * mw * ms
    local center = mainLeft + mw * ms / 2
    local mainTop = ay + (1 - my) * mh * ms
    local bottom = mainTop + statusHeight + 8
    local refined, firstRowRight, firstRowBottom = 0
    for _, spec in ipairs({
        {systemIndex=indices.Bar2, frame=_G.MultiBarBottomLeft},
        {systemIndex=indices.Bar3, frame=_G.MultiBarBottomRight},
    }) do
        for index, entry in ipairs(layout.systems or {}) do
            if spec.systemIndex ~= nil and sourceDefaults[index]
                and entry.system == actionSystem and entry.systemIndex == spec.systemIndex then
                local width, height = FrameSize(spec.frame, 454, 35)
                local scale = ParentScale(spec.frame)
                width, height = width * scale, height * scale
                if width <= rect.width - 24 then
                    local x = math.max(rect.left + width/2 + 12,
                        math.min(rect.right - width/2 - 12, center))
                    local y = bottom
                    local anchor = entry.anchorInfo
                    local stockOffset = anchor and anchor.bottomBarOffsetX
                    if type(stockOffset) == "number" then
                        local left = mainLeft + stockOffset
                        if left >= rect.left + 12 and left + width <= rect.right - 12 then
                            x = left + width / 2
                            -- Forever places Bar 3 alongside Bar 2 when the
                            -- preset excludes it from the bottom stack height.
                            if anchor.bottomBarExcludeFromStackIncrement and firstRowRight
                                and left >= firstRowRight + 4 then y = firstRowBottom end
                        end
                    end
                    if y + height <= rect.top - 12 then
                        -- ApplySystemAnchor divides serialized offsets by the bar's
                        -- local scale. Store offsets in UIParent units once.
                        if attachToMain then
                            entry.anchorInfo = {point="BOTTOM", relativeTo="MainActionBar", relativePoint="TOP",
                                offsetX=x - center, offsetY=y - mainTop}
                        else
                            entry.anchorInfo = {point="BOTTOM", relativeTo="UIParent", relativePoint="BOTTOMLEFT",
                                offsetX=x, offsetY=y}
                        end
                        entry.anchorInfo2 = nil
                        entry.isInDefaultPosition = false
                        firstRowRight, firstRowBottom = x + width / 2, y
                        bottom = math.max(bottom, y + height + 8)
                        refined = refined + 1
                    end
                end
                break
            end
        end
    end
    return refined, refined > 0 and (bottom - ay) or nil
end

local function RefineForeverRightBars(layout, rect, sourceDefaults, targetSizes)
    local indices = Enum and Enum.EditModeActionBarSystemIndices
    local system = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
    if not Offhand.isForever or not indices or system == nil then return 0 end
    local stockX, stockY = _G.RIGHT_ACTION_BAR_DEFAULT_OFFSET_X, _G.RIGHT_ACTION_BAR_DEFAULT_OFFSET_Y
    local padding = tonumber(_G.RIGHT_ACTION_BAR_DEFAULT_PADDING_X) or 0
    local right, refined = rect.right + (tonumber(stockX) or -12), 0
    local gap = type(stockX) == "number" and math.max(0, 5 - padding) or 8
    local screen = {left = 0, bottom = 0, right = UIParent:GetWidth(), top = UIParent:GetHeight()}
    for _, spec in ipairs({
        {index = indices.RightBar1, frame = _G.MultiBarRight},
        {index = indices.RightBar2, frame = _G.MultiBarLeft},
    }) do
        for index, entry in ipairs(layout.systems or {}) do
            if spec.index ~= nil and sourceDefaults[index] and entry.system == system
                and entry.systemIndex == spec.index and type(entry.anchorInfo) == "table" then
                local width, height = FrameSize(spec.frame, 40, 480)
                local scale = ParentScale(spec.frame)
                width, height = width * scale, height * scale
                local size = targetSizes and targetSizes[spec.index]
                if size then width, height = size.width, size.height end
                if right - width >= rect.left + 12 and height <= rect.height - 24 then
                    local _, y = PointBase(entry.anchorInfo.relativePoint or entry.anchorInfo.point, screen)
                    y = y + (tonumber(entry.anchorInfo.offsetY) or 0)
                    if type(stockY) == "number" then y = (rect.bottom + rect.top) / 2 + stockY end
                    y = math.max(rect.bottom + height / 2 + 12, math.min(y, rect.top - height / 2 - 12))
                    entry.anchorInfo = {point = "RIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT",
                        offsetX = right, offsetY = y}
                    entry.anchorInfo2, entry.isInDefaultPosition = nil, false
                    right, refined = right - width - gap, refined + 1
                end
                break
            end
        end
    end
    return refined
end

local function RefineStandardHUDLayout(layout, rect, sourceDefaults, controllerLayout, foreverStatus)
    -- The native Gamepad preset has GamepadMainActionBar instead of keyboard
    -- ActionBar MainBar. Its manager-relative status bars must be handled
    -- before any keyboard-action-bar prerequisites or early returns.
    if controllerLayout then return RefineGamepadStatusBars(layout, rect, sourceDefaults) end
    local refined = RefineForeverRightBars(layout, rect, sourceDefaults)
    local systems = Enum and Enum.EditModeSystem
    local indices = Enum and Enum.EditModeActionBarSystemIndices
    if type(systems) ~= "table" or type(indices) ~= "table" then return refined end
    local actionSystem = systems.ActionBar
    local statusSystem = systems.StatusTrackingBar
    local statusIndices = Enum.EditModeStatusTrackingBarSystemIndices
    local foreverContainers = Offhand.isForever and _G.MainStatusTrackingBarContainer
        and statusIndices and statusIndices.StatusTrackingBar1 ~= nil
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

    local nativeForeverStatus = false
    if foreverContainers then
        for index, entry in ipairs(layout.systems or {}) do
            if sourceDefaults[index] and entry.system == statusSystem and ForeverStatusFrame(entry) then
                nativeForeverStatus = true
                break
            end
        end
    end
    local mainAnchor, lossOfControlAnchor, attachToMain
    for index, entry in ipairs(layout.systems or {}) do
        if (sourceDefaults[index] or nativeForeverStatus) and entry.system == actionSystem
            and entry.systemIndex == mainIndex and type(entry.anchorInfo) == "table" then
            mainAnchor = entry.anchorInfo
            attachToMain = nativeForeverStatus and _G.MainActionBar and not ExternallyOwnedSystem(entry)
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
    if Offhand.isRetail then
        -- Retail's bags are a separate corner system. Use serialized main-bar
        -- geometry for default siblings, not stale live button or bag edges.
        hudLeft, hudRight = mainLeft, mainRight
    end
    local statusFrame = _G.StatusTrackingBarManager or _G.MainMenuExpBar
    local statusWidth, statusHeight = FrameSize(statusFrame, mainWidth, 14)
    if foreverContainers then
        statusHeight = 0
        for index, entry in ipairs(layout.systems or {}) do
            local target = entry.system == statusSystem and sourceDefaults[index] and ForeverStatusFrame(entry)
            if target then
                local _, height = FrameSize(target, 571, 14)
                statusHeight = statusHeight + height * ParentScale(target) + 4
            end
        end
    end
    local stanceFrame = _G.StanceBar or _G.ShapeshiftBarFrame
    local _, stanceHeight = FrameSize(stanceFrame, 252, 36)
    local petFrame = _G.PetActionBar or _G.PetActionBarFrame
    local vehicleFrame = _G.MainMenuBarVehicleLeaveButton or _G.VehicleExitButton
    local extraFrame = _G.ExtraAbilityContainer or _G.ExtraAbilityBar
    local possessFrame = _G.PossessActionBar or _G.PossessBarFrame
    local lossOfControlFrame = _G.LossOfControlFrame
    local encounterFrame = _G.EncounterBar or _G.UIWidgetPowerBarContainerFrame
    local stanceBottom = mainTop + statusHeight + 8
    local secondaryLift = 0
    local secondaryRefined, nextRow = RefineForeverSecondaryBars(
        layout, rect, sourceDefaults, mainAnchor, mainFrame, statusHeight, attachToMain)
    refined = refined + secondaryRefined
    if nextRow then
        secondaryLift = math.max(0, nextRow - stanceBottom)
        stanceBottom = stanceBottom + secondaryLift
    end

    for index, entry in ipairs(layout.systems or {}) do
        if sourceDefaults[index] then
            if statusSystem ~= nil and entry.system == statusSystem then
                -- Classic default bars move together with the native artwork
                -- root. Preserve the source XP-to-manager relationship instead
                -- of deriving a child offset from the action-bar/manager sizes.
                local nativeClassic = not Offhand.isRetail and not Offhand.isForever
                    and mainAnchor.relativeTo == "MainMenuBarArtFrame"
                -- Keyboard layouts align the complete XP/reputation bar
                -- with the main/bag bar, not merely Action Button 1.
                if Offhand.isRetail then
                    if PlaceRetailStatus(entry, mainAnchor, mainFrame, rect) then refined = refined + 1 end
                elseif foreverContainers then
                    if PlaceForeverStatus(entry, layout, rect, sourceDefaults, mainAnchor, mainFrame, attachToMain) then
                        refined = refined + 1
                        if attachToMain then foreverStatus[#foreverStatus + 1] = entry.anchorInfo end
                    end
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
                    mainTop + statusHeight + 18 + secondaryLift) then
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
                    400, 36, hudLeft, mainTop + statusHeight + 8 + secondaryLift) then
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
            elseif not Offhand.isForever
                and ((buffSystem ~= nil and entry.system == buffSystem)
                    or (damageMeterSystem ~= nil and entry.system == damageMeterSystem))
                and type(entry.anchorInfo) == "table"
                and type(entry.anchorInfo.offsetY) == "number" then
                -- Retain the existing inset on other clients. Forever's
                -- translated preset keeps these systems at its stock edges.
                entry.anchorInfo.offsetY = entry.anchorInfo.offsetY - 96
                entry.isInDefaultPosition = false
                refined = refined + 1
            elseif not Offhand.isForever and minimapSystem ~= nil and entry.system == minimapSystem
                and type(entry.anchorInfo) == "table"
                and entry.anchorInfo.relativeTo == "UIParent"
                and type(entry.anchorInfo.offsetY) == "number" then
                -- BuffFrame is often system-relative
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

local function RepairGeneratedForeverStatus(layout, source, rect, foreverStatus)
    local systems = Enum and Enum.EditModeSystem
    local actions = Enum and Enum.EditModeActionBarSystemIndices
    local indices = Enum and Enum.EditModeStatusTrackingBarSystemIndices
    local main = _G.MainActionBar
    if not main or not systems or not systems.StatusTrackingBar or not actions or actions.MainBar == nil
        or not indices or indices.StatusTrackingBar1 == nil then return 0 end

    local mainAnchor
    for _, entry in ipairs(layout.systems or {}) do
        if entry.system == systems.ActionBar and entry.systemIndex == actions.MainBar
            and not entry.anchorInfo2 and not ExternallyOwnedSystem(entry) then mainAnchor = entry.anchorInfo; break end
    end
    if type(mainAnchor) ~= "table" then return 0 end
    local x, y = MainAnchorOrigin(layout, mainAnchor)
    if not x then return 0 end
    local width, height = FrameSize(main, 570, 40)
    local scale = ParentScale(main)
    width, height = width * scale, height * scale
    local pointX, pointY = PointFractions(mainAnchor.point)
    local left, bottom = x - pointX * width, y - pointY * height

    -- Reproduce the absolute anchors Beta 32 generated before fitting the
    -- main bar. A default source alone cannot identify a saved player edit.
    local projected = DeepCopy(source)
    TransformLayout(projected, rect, ExternallyOwnedSystem)
    local sourceDefaults, priorStatus, priorMain = {}, {}, nil
    for index, entry in ipairs(source.systems or {}) do
        if entry.system == systems.ActionBar and entry.systemIndex == actions.MainBar and not entry.anchorInfo2 then
            priorMain = projected.systems[index].anchorInfo
        elseif entry.system == systems.StatusTrackingBar and entry.systemIndex ~= nil
            and entry.isInDefaultPosition ~= false and not ExternallyOwnedSystem(entry) then
            sourceDefaults[index] = true
        end
    end
    if type(priorMain) ~= "table" then return 0 end
    for index, entry in ipairs(projected.systems or {}) do
        if sourceDefaults[index] and PlaceForeverStatus(entry, projected, rect, sourceDefaults, priorMain, main, false) then
            priorStatus[entry.systemIndex] = entry.anchorInfo
        end
    end

    local candidates, overlap = {}, false
    for index, entry in ipairs(layout.systems or {}) do
        local target = entry.system == systems.StatusTrackingBar and ForeverStatusFrame(entry)
        local anchor = entry.anchorInfo
        if target and entry.isInDefaultPosition == false and not entry.anchorInfo2 and not ExternallyOwnedSystem(entry)
            and MatchesSavedAnchor(anchor, priorStatus[entry.systemIndex]) then
            local w, h = FrameSize(target, 571, 14)
            local statusScale = ParentScale(target)
            local halfWidth = w * statusScale / 2
            candidates[entry.systemIndex] = index
            overlap = overlap or (anchor.offsetY < bottom + height - 0.01
                and anchor.offsetY + h * statusScale > bottom + 0.01
                and anchor.offsetX - halfWidth < left + width - 0.01
                and anchor.offsetX + halfWidth > left + 0.01)
        end
    end
    local xp = candidates[indices.StatusTrackingBar1]
    if not overlap or not xp then return 0 end
    local defaults = {[xp] = true}
    if not PlaceForeverStatus(layout.systems[xp], layout, rect, defaults, mainAnchor, main, true) then return 0 end
    foreverStatus[#foreverStatus + 1] = layout.systems[xp].anchorInfo
    local secondary = candidates[indices.StatusTrackingBar2]
    if secondary and PlaceForeverStatus(layout.systems[secondary], layout, rect, defaults, mainAnchor, main, true) then
        foreverStatus[#foreverStatus + 1] = layout.systems[secondary].anchorInfo
        return 2
    end
    return 1
end

-- Fit only the generated copy. Resolve serialized dependencies instead of using
-- the live positions of a different active layout or detaching snapped children.
local function FitNativeHUDLayout(layout, rect, sourceDefaults)
    local manager = _G.EditModeManagerFrame
    if (not Offhand.isForever and not Offhand.isRetail) or not manager
        or type(manager.GetRegisteredSystemFrame) ~= "function" then return 0, 0, "unavailable" end
    local screen = {left = 0, bottom = 0, right = UIParent:GetWidth(), top = UIParent:GetHeight()}
    local uiScale = UIParent:GetEffectiveScale()
    if not PublicLayoutNumber(uiScale) or uiScale <= 0 or not PublicLayoutNumber(screen.right) or screen.right <= 0
        or not PublicLayoutNumber(screen.top) or screen.top <= 0 then return 0, 0, "unavailable" end
    local records, names = {}, {}
    local systems, actions = Enum and Enum.EditModeSystem, Enum and Enum.EditModeActionBarSystemIndices
    for index, entry in ipairs(layout.systems or {}) do
        local record = {entry = entry, index = index, blocked = ExternallyOwnedSystem(entry)}
        records[index] = record
        if Offhand.isForever and systems and actions and actions.ClassBar ~= nil
            and entry.system == systems.ActionBar and entry.systemIndex == actions.ClassBar then record.blocked = true end
        local ok, frame = pcall(manager.GetRegisteredSystemFrame, manager, entry.system, entry.systemIndex)
        if ok and frame and not (frame.IsForbidden and frame:IsForbidden()) then
            local read, width, height, scale, name = pcall(function()
                return frame:GetWidth(), frame:GetHeight(), frame:GetEffectiveScale(), frame:GetName()
            end)
            if read and PublicLayoutNumber(width) and PublicLayoutNumber(height) and PublicLayoutNumber(scale)
                and width > 0 and height > 0 and scale > 0 then
                record.width, record.height = width * scale / uiScale, height * scale / uiScale
            end
            if read and type(name) == "string" and not (issecretvalue and issecretvalue(name)) then
                record.name = name
                if names[name] ~= nil then
                    if names[name] then names[name].blocked = true end
                    names[name], record.blocked = false, true
                else names[name] = record end
            end
        end
    end
    local function Resolve(record, visiting)
        if record.bounds then return record.bounds end
        if not record.width or visiting[record] then return end
        visiting[record] = true
        local function Anchor(info)
            if type(info) ~= "table" or not PublicLayoutNumber(info.offsetX) or not PublicLayoutNumber(info.offsetY) then return end
            for _, key in ipairs({"point", "relativePoint", "relativeTo"}) do
                local value = info[key]
                if value ~= nil and ((issecretvalue and issecretvalue(value)) or type(value) ~= "string") then return end
            end
            local relative, parent = screen, nil
            if info.relativeTo ~= nil and info.relativeTo ~= "UIParent" then
                parent = names[info.relativeTo]
                relative = parent and Resolve(parent, visiting)
                if not relative then return end
            end
            local x, y = PointBase(info.relativePoint or info.point, relative)
            return {x = x + info.offsetX, y = y + info.offsetY, parent = parent,
                px = select(1, PointFractions(info.point)), py = select(2, PointFractions(info.point))}
        end
        local first, second = Anchor(record.entry.anchorInfo), nil
        if record.entry.anchorInfo2 then second = Anchor(record.entry.anchorInfo2) end
        visiting[record] = nil
        if not first or (record.entry.anchorInfo2 and not second) or (second and second.parent ~= first.parent) then return end
        local width, height = record.width, record.height
        if second then
            if second.px ~= first.px then width = (second.x - first.x) / (second.px - first.px) end
            if second.py ~= first.py then height = (second.y - first.y) / (second.py - first.py) end
        end
        if not PublicLayoutNumber(width) or not PublicLayoutNumber(height) or width <= 0 or height <= 0 then return end
        local left, bottom = first.x - first.px * width, first.y - first.py * height
        record.root = first.parent and first.parent.root or record
        record.bounds = {left = left, bottom = bottom, right = left + width, top = bottom + height}
        return record.bounds
    end
    local groups, skipped = {}, 0
    for _, record in ipairs(records) do
        local bounds = Resolve(record, {})
        if bounds then
            local group = groups[record.root]
            if not group then group = {left = bounds.left, bottom = bounds.bottom, right = bounds.right, top = bounds.top, records = {}}; groups[record.root] = group end
            group.records[#group.records + 1] = record
            group.blocked = group.blocked or record.blocked
            group.left, group.bottom = math.min(group.left, bounds.left), math.min(group.bottom, bounds.bottom)
            group.right, group.top = math.max(group.right, bounds.right), math.max(group.top, bounds.top)
        elseif not record.blocked then skipped = skipped + 1 end
    end
    -- An unresolved snapped child must not be moved indirectly with its parent.
    for _, record in ipairs(records) do
        if not record.bounds then
            for _, key in ipairs({"anchorInfo", "anchorInfo2"}) do
                local info = record.entry[key]
                local relative = type(info) == "table" and info.relativeTo
                local parent = type(relative) == "string" and not (issecretvalue and issecretvalue(relative)) and names[relative]
                local group = parent and parent.root and groups[parent.root]
                if group then group.blocked = true end
            end
        end
    end
    local fitted = 0
    for root, group in pairs(groups) do
        if not group.blocked then
            local width, height = group.right - group.left, group.top - group.bottom
            local first, second = root.entry.anchorInfo, root.entry.anchorInfo2
            -- A standalone stretched system (for example XP) can fit by moving
            -- its two anchors. Never resize bars or a snapped group by guessing.
            local stretchX, stretchY = false, false
            if #group.records == 1 and second then
                local ax, ay = PointFractions(first.point)
                local bx, by = PointFractions(second.point)
                stretchX, stretchY = width > rect.width + 0.01 and ax ~= bx, height > rect.height + 0.01 and ay ~= by
                if stretchX then width = rect.width end
                if stretchY then height = rect.height end
            end
            if width <= rect.width + 0.01 and height <= rect.height + 0.01 then
                local desiredLeft, desiredBottom = group.left, group.bottom
                if not (sourceDefaults and sourceDefaults[root.index]) then
                    -- Keep in-Mainhand edits exactly. Project outlying custom
                    -- groups proportionally before clamping, so several bars
                    -- do not all collapse onto the same screen edge.
                    -- Persisted native anchors and physical-to-UI conversion
                    -- differ by tiny rounding errors at a display boundary.
                    -- Use the same epsilon as the eventual write threshold.
                    if group.left < rect.left - 0.01 or group.right > rect.right + 0.01 then
                        desiredLeft = rect.left + group.left / screen.right * rect.width
                    end
                    if group.bottom < rect.bottom - 0.01 or group.top > rect.top + 0.01 then
                        desiredBottom = rect.bottom + group.bottom / screen.top * rect.height
                    end
                end
                local left = math.max(rect.left, math.min(desiredLeft, rect.right - width))
                local bottom = math.max(rect.bottom, math.min(desiredBottom, rect.top - height))
                local dx, dy = left - group.left, bottom - group.bottom
                if math.abs(dx) > 0.01 or math.abs(dy) > 0.01 or stretchX or stretchY then
                    for _, info in ipairs({first, second}) do
                        local sx, sy = PointBase(info.relativePoint or info.point, screen)
                        local px, py = PointFractions(info.point)
                        info.offsetX = stretchX and (left + px * width - sx) or (info.offsetX + dx)
                        info.offsetY = stretchY and (bottom + py * height - sy) or (info.offsetY + dy)
                    end
                    root.entry.isInDefaultPosition = false
                    fitted = fitted + 1
                end
            else skipped = skipped + #group.records end
        elseif group.left < rect.left - 0.01 or group.right > rect.right + 0.01
            or group.bottom < rect.bottom - 0.01 or group.top > rect.top + 0.01 then
            for _, record in ipairs(group.records) do if not record.blocked then skipped = skipped + 1 end end
        end
    end
    return fitted, skipped, skipped > 0 and "partial" or "complete"
end

local function GeneratedLayoutBaseName(controllerLayout)
    return controllerLayout and "Offhand - Gamepad" or "Offhand"
end

local function LayoutNameMatches(name, base)
    if type(name) ~= "string" or type(base) ~= "string" then return false end
    local actual = name:lower()
    base = base:lower()
    return actual == base or (actual:sub(1, #base) == base
        and actual:sub(#base + 1):match("^ %(%d+%)$") ~= nil)
end

local function IsSharedLayoutName(name, controllerLayout)
    return LayoutNameMatches(name, GeneratedLayoutBaseName(controllerLayout))
end

local function CharacterLayoutBaseName(player, controllerLayout)
    return player and ((controllerLayout and "Offhand Pad - " or "Offhand Main - ") .. player)
end

local function LegacyCharacterLayoutName(player, controllerLayout)
    return "Offhand - Mainhand" .. (controllerLayout and " - Gamepad" or "") .. (player and (" - " .. player) or "")
end

local function IsCharacterLayoutName(name)
    if type(name) ~= "string" then return false end
    local lower = name:lower()
    return lower:match("^offhand %- mainhand %- ")
        or lower:match("^offhand main %- ") or lower:match("^offhand pad %- ")
end

local function IsNamedForPlayer(name, player, controllerLayout)
    return LayoutNameMatches(name, CharacterLayoutBaseName(player, controllerLayout))
        or LayoutNameMatches(name, LegacyCharacterLayoutName(player, controllerLayout))
end

function Mainhand:IsCharacterEditModeLayoutAllowed(name)
    if not IsCharacterLayoutName(name) then return true end
    local player = UnitName and UnitName("player")
    return player and (IsNamedForPlayer(name, player, false) or IsNamedForPlayer(name, player, true)) or false
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
    -- Old signatures already represent replacement status bars by default.
    -- Mark the case where Action Bars is loaded but Blizzard owns XP/Rep.
    if policy.IsAddonPresent("EllesmereUIActionBars") and policy.HasCustomStatusBarAddon
        and not policy.HasCustomStatusBarAddon() then owners[#owners + 1] = "native-status" end
    return table.concat(owners, ":")
end

local function OnlyEllesmereGainedOwnership(previous, current)
    if type(previous) ~= "string" or previous == current then return false end
    local before, after = {}, {}
    for owner in previous:gmatch("[^:]+") do before[owner] = true end
    for owner in current:gmatch("[^:]+") do after[owner] = true end
    local hadNativeStatus = not before.EllesmereUIActionBars or before["native-status"]
    local hasNativeStatus = not after.EllesmereUIActionBars or after["native-status"]
    if hasNativeStatus and not hadNativeStatus then return false end
    for owner in pairs(before) do
        if owner ~= "native-status" and not after[owner] then return false end
    end
    for owner in pairs(after) do
        if owner ~= "native-status" and not before[owner] and not owner:match("^EllesmereUI") then return false end
    end
    return true
end

local function RegisteredSharedLayout(name, controllerLayout)
    -- Old targeted repairs incorrectly registered character-named rows here.
    -- Metadata alone must never make another character's layout shareable.
    if not IsSharedLayoutName(name, controllerLayout) then return nil end
    local registry = type(OffhandDB) == "table" and OffhandDB.sharedMainhandLayouts
    local record = type(registry) == "table" and registry[name]
    if type(record) == "table" and record.version == 1
        and record.client == SharedLayoutClient()
        and (record.controllerLayout == true) == (controllerLayout == true) then return record end
end

local function SharedLayoutRecord(name, controllerLayout, geometrySignature)
    local record = RegisteredSharedLayout(name, controllerLayout)
    if record and record.ownershipSignature == LayoutOwnershipSignature()
        and record.geometrySignature == (geometrySignature or Mainhand:GetGeometrySignature()) then return record end
end

local function IsCurrentCharacterLayoutName(name, controllerLayout, geometrySignature)
    if type(name) ~= "string" then return false end
    if SharedLayoutRecord(name, controllerLayout, geometrySignature) then return true end
    local player = UnitName and UnitName("player") or nil
    return IsNamedForPlayer(name, player, controllerLayout)
end

local function UniqueLayoutName(data, base)
    local names = {}
    for _, layout in ipairs(data.layouts) do names[string.lower(LayoutName(layout, ""))] = true end
    if not names[string.lower(base)] then return base end
    for number = 2, 99 do
        local candidate = base .. " (" .. number .. ")"
        if not names[string.lower(candidate)] then return candidate end
    end
    return base .. " - " .. tostring(time and time() or Geometry.GetRevision())
end

local function ForeverCharacterLayoutType()
    local types = Enum and Enum.EditModeLayoutType
    return Offhand.isForever and types and types.Character or nil
end

local function LayoutModeKey(controllerLayout)
    return controllerLayout and "gamepad" or "standard"
end

local function CharacterModeRecord(controllerLayout)
    local character = type(OffhandCharDB) == "table" and OffhandCharDB
    if not character then return end
    local records = character.mainhandLayoutsByMode
    local record = ForeverCharacterLayoutType() and type(records) == "table"
        and records[LayoutModeKey(controllerLayout)] or character.mainhandLayout
    if type(record) == "table" and (record.controllerLayout == true) == controllerLayout then return record end
end

local function LayoutInsertIndex(layouts, layoutType, precedingType, maximum)
    local lastOfType, lastPreceding, count = nil, 0, 0
    for index, row in ipairs(layouts) do
        if row.layoutType == layoutType then
            lastOfType, count = index, count + 1
        elseif precedingType ~= nil and row.layoutType == precedingType then
            lastPreceding = index
        end
    end
    if type(maximum) ~= "number" or count < maximum then return (lastOfType or lastPreceding) + 1 end
end

local function InsertNativeLayout(data, index, id, layout)
    table.insert(data.layouts, index, layout)
    local active = tonumber(data.activeLayout)
    if active and active >= id then data.activeLayout = active + 1 end
end

local function RememberCharacterLayout(controllerLayout, record)
    local records = OffhandCharDB.mainhandLayoutsByMode
    if type(records) ~= "table" then records = {}; OffhandCharDB.mainhandLayoutsByMode = records end
    records[LayoutModeKey(controllerLayout)] = record
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
    local fit = string.format(" | NativeFit=%s/%s/%s | Source=%s", tostring(status.fitStatus or "not-recorded"),
        tostring(status.fitMoved or 0), tostring(status.fitSkipped or 0), tostring(status.sourceName or "unknown"))
    if compact then
        return string.format("Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Gamepad=%s | LastFailure=%s",
            tostring(active),
            status.configured and tostring(status.generatedName or "recorded") or "none",
            status.configured and (status.currentGeometry and "current" or "stale") or "none",
            needsAttention and "yes" or "no", tostring(reason or "unknown"),
            NativeGamepadInterface() and "yes" or "no", tostring(self.lastLayoutFailure or "none")) .. fit
    end
    return string.format(
        "Supported=%s | API=%s/%s | Active=%s | Generated=%s | Geometry=%s | Attention=%s/%s | Repair=%s/%s | GamepadMenu=%s | GamepadPanels=%s | GamepadReticle=%s | GamepadBack=%s | LastFailure=%s | GamepadLoot=%s",
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
        tostring(self.lastLayoutFailure or "none"),
        self:GetForeverGamepadLootDiagnostics()) .. fit
end

function Mainhand:CreateOrUpdateEditModeLayout(options)
    options = type(options) == "table" and options or nil
    local repairFrameName = options and options.repairFrameName or nil
    local repairSystems = options and options.repairSystems
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return false, "disabled" end
    if Offhand._displayGeometryTransitionActive then return false, "span" end
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
    local modeRecord = CharacterModeRecord(controllerLayout)
    local characterType = ForeverCharacterLayoutType()
    local playerName = UnitName and UnitName("player") or nil
    if characterType and not playerName then return false, "state" end
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
    local activeSource, activeSourceID, activeSourceIndex, activeSourcePreset = ResolveActiveLayout(data, presets)
    local activeName = activeSource and LayoutName(activeSource, "")
    local explicitSource = not nativeGamepadLayout and not repairFrameName and not repairSystems and activeSource
        and not (IsCharacterLayoutName(activeName) or IsSharedLayoutName(activeName, false)
            or IsSharedLayoutName(activeName, true) or IsEllesmereFallbackName(activeName))
    if nativeGamepadLayout then
        -- Old beta builds could leave a controller record pointing at Classic
        -- after rejecting custom-layout activation. Always rebuild a Gamepad
        -- layout from the live Gamepad preset, never from that stale record or
        -- from an already translated custom layout.
        source, sourceID = FindGamepadPreset(presets)
        if source then sourceIndex, sourcePreset = sourceID, true end
        if not source then
            local activeSource, activeID, activeIndex, activePreset =
                ResolveActiveLayout(data, presets)
            if activePreset then
                source, sourceID, sourceIndex, sourcePreset =
                    activeSource, activeID, activeIndex, true
            end
        end
    elseif explicitSource then
        -- A deliberate Create after selecting Modern or another user layout
        -- must use that choice, not silently revive the previous source.
        source, sourceID, sourceIndex, sourcePreset = activeSource, activeSourceID, activeSourceIndex, activeSourcePreset
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
    local sourceFromActive = not source
    if sourceFromActive then source, sourceID, sourceIndex, sourcePreset = ResolveActiveLayout(data, presets) end
    if not source then return false, "source" end
    -- A fresh character may start on an account layout made for another span.
    -- Rebuild from its original source, never translate an already moved HUD.
    if not modeRecord or (characterType and sourceFromActive) then
        local registry = type(OffhandDB) == "table" and OffhandDB.sharedMainhandLayouts
        local prior = type(registry) == "table" and registry[LayoutName(source, "")]
        if type(prior) == "table" and prior.version == 1 and prior.client == SharedLayoutClient() then
            local original, originalID, originalIndex, originalPreset = FindNamedLayout(data, presets, prior.sourceName)
            if not original or original == source then return false, "source" end
            source, sourceID, sourceIndex, sourcePreset = original, originalID, originalIndex, originalPreset
        elseif IsCharacterLayoutName(LayoutName(source))
            or IsEllesmereFallbackName(LayoutName(source, "")) then
            -- A legacy account row may have no provenance at all. Never use
            -- another incarnation/character's already-translated HUD as source.
            source, sourceID, sourceIndex, sourcePreset = presets[1], 1, 1, true
        end
    end
    local generatedName = matchingRecord and matchingRecord.generatedName or nil
    local generated, _, generatedIndex = FindNamedLayout(data, presets, generatedName)
    local legacyLayout, previousAccountLayout
    if characterType and (not generated or generated.layoutType ~= characterType) then
        if generated and matchingRecord.geometrySignature == self:GetGeometrySignature() then
            previousAccountLayout = generated
            if not repairFrameName and not repairSystems
                and SharedLayoutRecord(generatedName, controllerLayout) then
                legacyLayout = generated
            end
        end
        generatedName, generated, generatedIndex = nil, nil, nil
    end
    -- Explicit full setup can promote this character's already-positioned legacy
    -- layout. Preserve its actual anchors instead of rebuilding from Modern and
    -- losing the adjustments that made the individual layout accurate.
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
    if not characterType and not generated and not matchingRecord and (not Offhand.isRetail or Offhand.isForever) then
        local player = UnitName and UnitName("player") or nil
        local expectedName = LegacyCharacterLayoutName(player, controllerLayout)
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
    if not characterType and not generated and Offhand.isForever and not controllerLayout
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
    if not characterType and not generated and not legacyLayout and not repairFrameName and not repairSystems then
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
    if not generatedName then
        local base = characterType and CharacterLayoutBaseName(playerName, controllerLayout)
            or GeneratedLayoutBaseName(controllerLayout)
        generatedName = UniqueLayoutName(data, base)
    end

    local repairExtra = IsExtraAbilityRecovery(repairFrameName)
    local repairEncounter = IsEncounterRecovery(repairFrameName)
    local targeted = repairExtra or repairEncounter
    local selective = type(repairSystems) == "table" and #repairSystems > 0
    -- Targeted recovery preserves the other systems in the existing generated
    -- layout, including edits made since it was first created.
    local selectiveSource = selective and ResolveActiveLayout(data, presets) or nil
    local encounterSource = repairEncounter and ResolveActiveLayout(data, presets) or nil
    local preserveGenerated = (Offhand.isForever or Offhand.isRetail) and manager
        and type(manager.GetRegisteredSystemFrame) == "function"
        and not controllerLayout and not targeted and not selective and not explicitSource and generated and matchingRecord
        and matchingRecord.geometrySignature == self:GetGeometrySignature()
        and generated == activeSource
    local layout = DeepCopy(legacyLayout or selectiveSource or encounterSource or (preserveGenerated and generated)
        or (targeted and (generated or previousAccountLayout or source) or source))
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
    local moved, transformed, foreverStatus = 0, {}, {}
    if legacyLayout then moved = matchingRecord.movedSystems or #(layout.systems or {}) end
    if preserveGenerated then moved = matchingRecord.movedSystems or #(layout.systems or {}) end
    if preserveGenerated and not repairFrameName then
        if Offhand.isForever then
            moved = moved + RepairGeneratedForeverStatus(layout, source, rect, foreverStatus)
        elseif Offhand.isRetail then
            moved = moved + RebaseRetailStatusChain(layout, rect, sourceDefaults, transformed, source)
        end
    end
    if not legacyLayout and not preserveGenerated and not targeted and not selective then
        moved, transformed = TransformLayout(layout, rect, function(entry)
            -- Forever's empty MultiCast/Totem Edit Mode preview can call
            -- C_TooltipInfo.GetSpellByID(nil) after an addon-generated relocation.
            -- Leave this ambiguous ClassBar entry exactly where the source layout
            -- put it; stance, pet and possess have their own unambiguous indices.
            return ExternallyOwnedSystem(entry) or (Offhand.isForever and foreverActionSystem ~= nil and foreverClassBar ~= nil
                and entry.system == foreverActionSystem and entry.systemIndex == foreverClassBar)
        end)
        RefineStandardHUDLayout(layout, rect, sourceDefaults, controllerLayout, foreverStatus)
        if Offhand.isRetail and not controllerLayout then
            moved = moved + RebaseRetailStatusChain(layout, rect, sourceDefaults, transformed)
        end
    end
    local groupMoved, groupRepaired = 0, 0
    if not legacyLayout and not preserveGenerated and not targeted and not selective then
        groupMoved, groupRepaired = RefineGroupHUDLayout(layout, rect, sourceDefaults,
            transformed, repairFrameName)
    end
    moved = moved + groupMoved
    local extraMoved, extraRepaired = RefineExtraAbilityRecovery(layout, rect, transformed, repairFrameName)
    moved = moved + extraMoved
    local encounterRepaired = RefineEncounterRecovery(layout, rect, repairFrameName)
    moved = moved + encounterRepaired
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
    if repairEncounter and encounterRepaired == 0 then
        return false, "repair-system", LayoutName(source, "layout"), moved
    end
    if IsGroupRecoveryFrame(repairFrameName) and groupRepaired == 0 then
        return false, "repair-system", LayoutName(source, "layout"), moved
    end
    -- Refinement can inspect neighbouring native systems. Restore external
    -- entries byte-for-byte even if a requested repair traversed that group.
    for index, entry in pairs(externallyOwned) do layout.systems[index] = entry end
    local fitMoved, fitSkipped, fitStatus = 0, 0, "not-requested"
    if not targeted and not selective and not controllerLayout then
        fitMoved, fitSkipped, fitStatus = FitNativeHUDLayout(layout, rect, sourceDefaults)
        moved = moved + fitMoved
    end
    CenterForeverStatus(layout, rect, foreverStatus)
    -- A reported preview can outlive a layout that already contains the same
    -- repair. Saving that active layout again cannot justify another reload.
    if repairFrameName and generated and generated == activeSource
        and generated.interfaceStyle == layout.interfaceStyle
        and SameLayoutData(generated.systems, layout.systems) then
        return false, "repair-system", generatedName, 0
    end
    if moved == 0 and not characterType then return false, "already", LayoutName(source, "layout"), 0 end

    layout.layoutName = generatedName
    layout.layoutIndex = nil
    local layoutTypes = Enum and Enum.EditModeLayoutType
    local targetType = characterType or (layoutTypes and layoutTypes.Account)
    local typedSlots = targetType ~= nil and layoutTypes.Character ~= nil
    if targetType ~= nil then layout.layoutType = targetType end

    local targetIndex = generatedIndex
    if not generated then
        local maximum = Constants and Constants.EditModeConsts
            and Constants.EditModeConsts.EditModeMaxLayoutsPerType
        if typedSlots then
            local precedingType = characterType and layoutTypes.Account or nil
            targetIndex = LayoutInsertIndex(data.layouts, targetType, precedingType, maximum)
            if not targetIndex then return false, "maximum" end
        else
            if type(maximum) == "number" and #data.layouts >= maximum then return false, "maximum" end
            targetIndex = #data.layouts + 1
        end
    end

    local generatedRecord = {
        version = 1,
        sourceName = LayoutName(source, sourcePreset and ("Preset " .. tostring(sourceID)) or "Layout"),
        sourceID = sourceID,
        sourcePreset = sourcePreset and true or false,
        generatedName = generatedName,
        geometrySignature = self:GetGeometrySignature(),
        movedSystems = moved,
        fitMoved = fitMoved, fitSkipped = fitSkipped, fitStatus = fitStatus,
        protectedRepairCandidate = repairFrameName,
        protectedRepairSystems = groupRepaired + extraRepaired > 0 and groupRepaired + extraRepaired or nil,
        controllerLayout = controllerLayout and true or nil,
        ownerName = playerName,
        ownerGUID = playerGUID,
        ownershipSignature = characterType and LayoutOwnershipSignature() or nil,
    }
    local targetID = (Offhand.isForever and 3 or #presets) + targetIndex
    local called, result
    if not (characterType and generated and SameLayoutData(generated.systems, layout.systems)
        and generated.interfaceStyle == layout.interfaceStyle) then
        if generated then
            -- Snapshot before the native write, including saves that error or
            -- whose updated row only becomes readable on a later UI turn.
            if type(OffhandCharDB.mainhandLayoutBackups) ~= "table" then OffhandCharDB.mainhandLayoutBackups = {} end
            local backupKey = generatedName
            local prior = OffhandCharDB.mainhandLayoutBackups[backupKey]
            local priorOwner = type(prior) == "table" and type(prior.record) == "table" and prior.record.ownerGUID
            if prior and playerGUID and priorOwner ~= playerGUID then backupKey = backupKey .. "@" .. playerGUID end
            if not OffhandCharDB.mainhandLayoutBackups[backupKey] then
                OffhandCharDB.mainhandLayoutBackups[backupKey] = {layout = DeepCopy(generated), record = DeepCopy(matchingRecord)}
            end
        end
        local writeData = DeepCopy(data)
        if generated then
            writeData.layouts[targetIndex] = layout
        elseif typedSlots then
            InsertNativeLayout(writeData, targetIndex, targetID, layout)
        else
            writeData.layouts[targetIndex] = layout
        end
        called, result = pcall(C_EditMode.SaveLayouts, writeData)
        if not called or result == false then return false, "save" end
    end
    if characterType then
        local current = EditModeData()
        local saved, id
        if current then saved, id = FindNamedLayout(current, presets, generatedName) end
        if not saved or saved.layoutType ~= characterType then
            -- The native save was accepted but the row may arrive later.
            -- Remember the requested name for the next attempt without
            -- claiming it as the active layout.
            RememberCharacterLayout(controllerLayout, generatedRecord)
            return false, "save"
        end
        targetID = id
    end
    local function IsTargetActive()
        local current = EditModeData()
        return current and tonumber(current.activeLayout) == targetID or false
    end
    -- An account row inserted at the active character layout's former index
    -- can appear active in GetLayouts before Blizzard has applied its systems.
    local insertedAtPreviousActiveIndex = not generated and tonumber(data.activeLayout) == targetID
    local active = not insertedAtPreviousActiveIndex and IsTargetActive()
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

    generatedRecord.generatedID = targetID
    generatedRecord.activationPending = activationPending and true or nil
    OffhandCharDB.mainhandLayout = generatedRecord
    if characterType then RememberCharacterLayout(controllerLayout, generatedRecord) end
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
        if active and Offhand.HideForeverLayoutRecoveryPrompt then
            Offhand:HideForeverLayoutRecoveryPrompt("fallback")
            Offhand:HideForeverLayoutRecoveryPrompt("restore")
            if Offhand.HUD then Offhand.HUD.foreverRecoveryPromptShown = nil end
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

function Mainhand:GetLayoutStatus(geometrySignature, layoutRecord)
    local record = layoutRecord or (type(OffhandCharDB) == "table" and OffhandCharDB.mainhandLayout)
    local deferred = type(OffhandCharDB) == "table"
        and OffhandCharDB.mainhandLayoutDeferred == true or false
    local guid = UnitGUID and UnitGUID("player")
    if type(record) ~= "table" or not self:IsCharacterEditModeLayoutAllowed(record.generatedName)
        or (record.ownerName and UnitName and record.ownerName ~= UnitName("player"))
        or (record.ownerGUID and guid and record.ownerGUID ~= guid) then
        return { configured = false, deferred = deferred }
    end
    local shared = RegisteredSharedLayout(record.generatedName, record.controllerLayout)
    local ownership = record.ownershipSignature or (shared and shared.ownershipSignature)
    local currentOwnership = LayoutOwnershipSignature()
    return {
        configured = true,
        deferred = deferred,
        sourceName = record.sourceName,
        generatedName = record.generatedName,
        generatedID = record.generatedID,
        movedSystems = record.movedSystems,
        fitMoved = record.fitMoved, fitSkipped = record.fitSkipped, fitStatus = record.fitStatus,
        protectedRepairCandidate = record.protectedRepairCandidate,
        protectedRepairSystems = record.protectedRepairSystems,
        controllerLayout = record.controllerLayout == true,
        activationPending = record.activationPending == true,
        presetApplied = record.presetApplied == true,
        currentGeometry = record.geometrySignature == (geometrySignature or self:GetGeometrySignature()),
        currentOwnership = ownership == nil or ownership == currentOwnership,
        ellesmereGainedOwnership = OnlyEllesmereGainedOwnership(ownership, currentOwnership),
    }
end

local function EllesmereTransferLayout(source, generated, rect, controller, targetSizes)
    if not source or not generated then return end
    local projected = DeepCopy(source)
    local defaults = {}
    for index, entry in ipairs(projected.systems or {}) do
        defaults[index] = entry.isInDefaultPosition ~= false
    end
    TransformLayout(projected, rect, function(entry)
        local systems, indices = Enum.EditModeSystem, Enum.EditModeActionBarSystemIndices
        return systems and indices and indices.ClassBar ~= nil
            and entry.system == systems.ActionBar and entry.systemIndex == indices.ClassBar
    end)
    local foreverStatus = {}
    RefineStandardHUDLayout(projected, rect, defaults, controller, foreverStatus)
    CenterForeverStatus(projected, rect, foreverStatus)
    local nativeProjection = DeepCopy(projected)
    if not controller then RefineForeverRightBars(projected, rect, defaults, targetSizes) end
    local result, defaultRows = DeepCopy(generated), {}
    for rowIndex, entry in ipairs(result.systems or {}) do
        for index, original in ipairs(source.systems or {}) do
            if original.system == entry.system and original.systemIndex == entry.systemIndex
                and defaults[index]
                and ((controller and entry.isInDefaultPosition == true)
                    or SameLayoutData(entry, original) or SameLayoutData(entry, nativeProjection.systems[index])) then
                result.systems[rowIndex] = DeepCopy(projected.systems[index])
                defaultRows[result.systems[rowIndex]] = true
                break
            end
        end
    end
    return result, defaultRows
end

-- Read-only source selection for the EllesmereUI transfer. A generated row
-- can still contain the native anchor for a system owned by another addon.
function Mainhand:GetEllesmereLayoutSource(geometryOnly, targetSizes)
    local rect = Geometry.GetCurrentRect()
    if not Offhand.isForever or not rect.isSpanned then return nil end
    local controller = NativeGamepadInterface() == true
    if geometryOnly then return {rect = rect, controller = controller} end
    local data, presets = EditModeData(), Presets()
    if not data then return nil end
    local active, activeID = ResolveActiveLayout(data, presets)
    local geometry = Geometry.Signature(rect)
    local status = self:GetLayoutStatus(geometry, CharacterModeRecord(controller))
    local characterType = ForeverCharacterLayoutType()
    local source, generated, ellesmereReview
    if status.configured and status.controllerLayout == controller then
        source = FindNamedLayout(data, presets, status.sourceName)
        if status.currentGeometry then
            local saved = FindNamedLayout(data, presets, status.generatedName)
            -- This takeover only removes work from Blizzard. The active
            -- character row still has the anchors the preview can copy.
            ellesmereReview = status.ellesmereGainedOwnership and saved and saved == active
                and characterType and saved.layoutType == characterType
            if status.currentOwnership or ellesmereReview then
                generated = saved
            end
        end
    end
    local name = LayoutName(active, "")
    if not source and not generated then
        local character = type(OffhandCharDB) == "table" and OffhandCharDB
        local setup = character and character.characterSetup
        local record = RegisteredSharedLayout(name, controller)
        if record then
            source = FindNamedLayout(data, presets, record.sourceName)
            if SharedLayoutRecord(name, controller, geometry) then generated = active end
        elseif character and IsSharedLayoutName(name, controller) and character.foreverEditModeLayoutName == name
            and tonumber(character.foreverEditModeLayoutID) == activeID
            and type(setup) == "table" and setup.geometrySignature == geometry
            and (setup.gamepad == true) == controller then
            -- Older Forever recovery recorded the active layout identity
            -- separately from the generated-layout ticket. Treat its anchors
            -- as already projected when setup confirms this exact span.
            generated = active
        elseif not controller and not (IsSharedLayoutName(name, false) or IsSharedLayoutName(name, true)
            or IsEllesmereFallbackName(name) or IsCharacterLayoutName(name)) then
            source = active
        end
    end
    if controller and not source and not generated then source = FindGamepadPreset(presets) end
    if not (source or generated) then return nil end
    local context = {source = source, generated = generated, generatedActive = generated ~= nil and generated == active,
        rect = rect, controller = controller, ellesmereReview = ellesmereReview}
    context.transferLayout, context.transferDefaults = EllesmereTransferLayout(source, generated, rect, controller, targetSizes)
    if generated and characterType then context.characterOwned = generated.layoutType == characterType end
    return context
end

-- A fallback is a separate, inactive native layout. Leave the active layout,
-- shared Mainhand registry and character recovery ticket with their current owners.
function Mainhand:SaveEllesmereFallback(context, rows)
    if not Offhand.isForever or InCombatLockdown() or not context.generated then return false, "unavailable" end
    local data, presets = EditModeData(), Presets()
    if not data or type(C_EditMode.SaveLayouts) ~= "function" then return false, "save-api" end
    local source = FindNamedLayout(data, presets, context.generated.layoutName)
    if not source then return false, "source" end

    local layout = DeepCopy(source)
    local changed = false
    for _, entry in ipairs(layout.systems or {}) do
        for _, row in ipairs(rows) do
            if row.anchor and row.system == entry.system and row.systemIndex == entry.systemIndex
                and not entry.anchorInfo2 then
                entry.anchorInfo = DeepCopy(row.anchor)
                entry.isInDefaultPosition = false
                changed = true
                break
            end
        end
    end
    if not changed then return false, "already" end

    for _, existing in ipairs(data.layouts) do
        local name = LayoutName(existing, "")
        if IsEllesmereFallbackName(name) and existing.interfaceStyle == layout.interfaceStyle
            and SameLayoutData(existing.systems, layout.systems) then return true, name end
    end

    local maximum = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
    local accountType = Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account
    local index = #data.layouts + 1
    if accountType and ForeverCharacterLayoutType() then
        index = LayoutInsertIndex(data.layouts, accountType, nil, maximum)
        if not index then return false, "maximum" end
    elseif type(maximum) == "number" and #data.layouts >= maximum then
        return false, "maximum"
    end

    local name, suffix = fallbackBase, 1
    while FindNamedLayout(data, presets, name) do
        suffix = suffix + 1
        name = string.format("%s (%d)", fallbackBase, suffix)
    end
    layout.layoutName, layout.layoutIndex = name, nil
    if accountType then layout.layoutType = accountType end
    local save = DeepCopy(data)
    InsertNativeLayout(save, index, 3 + index, layout)
    local called, result = pcall(C_EditMode.SaveLayouts, save)
    if not called or result == false then return false, "save" end
    local current = EditModeData()
    if not current or not FindNamedLayout(current, presets, name) then return false, "save" end
    return true, name
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

function Mainhand:PromptReload(reviewHUD)
    if not StaticPopupDialogs or not Offhand.ShowPopup then return false end
    local dialog = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD or {
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_RELOAD = dialog
    dialog.offhandAcceptBeforeHide = true
    if NativeGamepadInterface() or (InCombatLockdown and InCombatLockdown())
        or not Offhand:GetReloadUIFunction() then
        -- Preserve the created layout while combat, controller ownership or a
        -- missing reload API requires the player to use the native chat command.
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
            if NativeGamepadInterface() or (InCombatLockdown and InCombatLockdown()) then
                Mainhand:PromptReload(reviewHUD)
                return
            end
            local reload = Offhand:GetReloadUIFunction()
            if reload then reload() else Mainhand:PromptReload(reviewHUD) end
        end
    end
    if reviewHUD then dialog.text = dialog.text .. "\n\n" .. Offhand.L["SETUP_REVIEW_HUD"] end
    Offhand:ShowPopup("OFFHAND_MAINHAND_LAYOUT_RELOAD")
    return true
end

function Mainhand:PromptManualLayoutSelection(layoutName, resumeWizard)
    if not StaticPopupDialogs or not Offhand.ShowPopup then return false end
    local dialog = StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_SELECT or {
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.OFFHAND_MAINHAND_LAYOUT_SELECT = dialog
    dialog.text = Offhand.L[resumeWizard and "ELLESMERE_HUD_WIZARD_SELECT_MANUAL" or "MAINHAND_LAYOUT_SELECT_MANUAL"]
    dialog.button1 = OKAY or "OK"
    dialog.button2 = nil
    dialog.OnAccept = nil
    Offhand:ShowPopup("OFFHAND_MAINHAND_LAYOUT_SELECT", tostring(layoutName or "Offhand"))
    return true
end

-- Read-only discovery for character onboarding. Reuse must never fall through
-- to layout generation, legacy promotion, transformation or SaveLayouts.
local function CharacterSetupLayoutContext(mainhand)
    if InCombatLockdown and InCombatLockdown() then return nil, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return nil, "disabled" end
    if not mainhand:GetRect().isSpanned then return nil, "span" end
    if _G.ConsolePort then return nil, "gamepad" end
    if Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved() then return nil, "input" end
    local manager = _G.EditModeManagerFrame
    if manager and ((manager.IsShown and manager:IsShown()) or manager.editModeActive) then return nil, "open" end
    EnsureEditModeLoaded()
    local data, presets = EditModeData(), Presets()
    if not data or #presets == 0 then return nil, "unavailable" end
    local controller = ControllerMode(presets) and true or false
    if controller and not (Offhand.isForever and NativeGamepadInterface()) then return nil, "gamepad" end
    if type(OffhandCharDB) ~= "table" then return nil, "state" end
    local record = CharacterModeRecord(controller)
    local status = record and mainhand:GetLayoutStatus(nil, record)
    local candidate, candidateIndex, shared, ownRecord, ellesmereReview, needsRefresh
    if status and status.configured and status.currentGeometry then
        local found, id, index, preset = FindNamedLayout(data, presets, record.generatedName)
        if found and not preset then
            local characterType = ForeverCharacterLayoutType()
            ellesmereReview = status.ellesmereGainedOwnership and characterType and found.layoutType == characterType
                and tonumber(data.activeLayout) == id
            needsRefresh = not status.currentOwnership and not ellesmereReview
            if ellesmereReview or (status.currentOwnership
                and IsCurrentCharacterLayoutName(record.generatedName, controller, record.geometrySignature)) then
                candidate, candidateIndex, ownRecord = found, index, record
            end
        end
    end
    if not candidate then
        for index, row in ipairs(data.layouts) do
            local metadata = SharedLayoutRecord(LayoutName(row, ""), controller)
            if metadata then candidate, candidateIndex, shared = row, index, metadata; break end
        end
    end
    if not candidate then return nil, needsRefresh and "ownership" or "missing" end
    local id = (Offhand.isForever and 3 or #presets) + candidateIndex
    return {
        data = data, presets = presets, candidate = candidate, id = id,
        controller = controller, ownRecord = ownRecord, shared = shared,
        ellesmereReview = ellesmereReview,
        active = tonumber(data.activeLayout) == id,
    }
end

function Mainhand:GetCharacterSetupLayoutStatus()
    local context, reason = CharacterSetupLayoutContext(self)
    if not context then return {ready = false, available = false, reason = reason} end
    return {
        ready = context.ownRecord ~= nil and context.active and not context.ellesmereReview,
        available = true, name = LayoutName(context.candidate), ellesmereReview = context.ellesmereReview,
    }
end

function Mainhand:UseExistingEditModeLayout(expectedName)
    local context, reason = CharacterSetupLayoutContext(self)
    if not context then return false, reason end
    local name = LayoutName(context.candidate)
    if expectedName and expectedName ~= name then return false, "missing" end
    if context.ellesmereReview and not expectedName then return false, "review" end
    -- Capture rollback provenance before SetActiveLayout can change live data.
    local source, sourceID, _, preset = ResolveActiveLayout(context.data, context.presets)
    local active = context.active
    if not active then
        if not C_EditMode or type(C_EditMode.SetActiveLayout) ~= "function" then return false, "activate-api" end
        local called, result = pcall(C_EditMode.SetActiveLayout, context.id)
        local current = EditModeData()
        if not called or result == false or not current
            or tonumber(current.activeLayout) ~= context.id then return false, "activate-api" end
    end
    local record = context.ownRecord and DeepCopy(context.ownRecord)
    if not record then
        local registry = type(OffhandDB) == "table" and OffhandDB.sharedMainhandLayouts
        local prior = source and type(registry) == "table" and registry[LayoutName(source)]
        if source ~= context.candidate and type(prior) == "table" and prior.version == 1
            and prior.client == SharedLayoutClient() then
            local original, id, _, isPreset = FindNamedLayout(context.data, context.presets, prior.sourceName)
            if original and original ~= source then source, sourceID, preset = original, id, isPreset
            else source, sourceID, preset = context.presets[1], 1, true end
        end
        if source and not self:IsCharacterEditModeLayoutAllowed(LayoutName(source)) then
            source, sourceID, preset = context.presets[1], 1, true
        end
        local shared = context.shared
        record = {
            version = 1, generatedName = name, generatedID = context.id,
            sourceName = source == context.candidate and shared.sourceName or LayoutName(source),
            sourceID = source == context.candidate and shared.sourceID or sourceID,
            sourcePreset = source == context.candidate and shared.sourcePreset or preset == true,
            geometrySignature = self:GetGeometrySignature(), movedSystems = shared.movedSystems,
            controllerLayout = context.controller and true or nil,
            ownerName = UnitName and UnitName("player") or nil,
            ownerGUID = UnitGUID and UnitGUID("player") or nil,
            ownershipSignature = shared.ownershipSignature,
        }
    end
    record.generatedID, record.activationPending = context.id, nil
    if context.ellesmereReview then record.ownershipSignature = LayoutOwnershipSignature() end
    OffhandCharDB.mainhandLayout = record
    local characterType = ForeverCharacterLayoutType()
    if characterType and context.ownRecord and context.candidate.layoutType == characterType then
        RememberCharacterLayout(context.controller, record)
    end
    OffhandCharDB.mainhandLayoutDeferred = nil
    OffhandCharDB.hudSetupReminder, OffhandCharDB.hudSetupReminderDeclined = nil, nil
    OffhandCharDB.mainhandWindowedLayout, OffhandCharDB.mainhandWindowedManualLayout = nil, nil
    if Offhand.isForever then
        OffhandCharDB.foreverEditModeLayoutName, OffhandCharDB.foreverEditModeLayoutID = name, context.id
        OffhandCharDB.foreverEditModeLegacyRecovery, OffhandCharDB.foreverEditModeRecovery = nil, nil
        if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveProfileSnapshot then
            Offhand.ForeverPersistence:SaveProfileSnapshot(true)
        end
    else
        OffhandCharDB.editModeLayoutName = name
    end
    return true, name, record.movedSystems or 0, not active
end

