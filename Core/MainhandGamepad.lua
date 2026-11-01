-- Forever native Gamepad presentation adapters and their owned state.
local _, Offhand = ...
local Mainhand = assert(Offhand.Mainhand, "Offhand Mainhand geometry must load before Gamepad adapters")
local Geometry = assert(Offhand.MainhandGeometry, "Offhand Mainhand geometry must load before Gamepad adapters")
local Compatibility = assert(Offhand.MainhandCompatibility, "Offhand Mainhand compatibility must load before Gamepad adapters")
local Number = Geometry.Number
local IsPlayerCombatRestricted = Geometry.IsPlayerCombatRestricted
local NativeGamepadInterface = Compatibility.IsNativeGamepadInterface

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

function Mainhand:GetForeverGamepadReticleDiagnostics()
    return gamepadReticleStatus
end

