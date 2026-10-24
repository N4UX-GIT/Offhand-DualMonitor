-- Anchor managed HUD frames inside the same rectangle used by WorldFrame.
local _, Offhand = ...
local HUD = {}
Offhand.SeamRedirect = HUD
Offhand.HUD = HUD
local aligning, pending = false, false
local hooks = {}
local desiredFrames = {}
local Compatibility = assert(
    Offhand.HUDCompatibility,
    "Offhand HUD compatibility must load before SeamRedirect"
)
local HasCustomActionBarAddon = Compatibility.HasCustomActionBarAddon
local HasCustomBagAddon = Compatibility.HasCustomBagAddon
local HasCustomMinimapAddon = Compatibility.HasCustomMinimapAddon
local HasEllesmerePartyFrames = Compatibility.HasEllesmerePartyFrames
local IsBlizzardEditModeOwnedFrame = Compatibility.IsBlizzardEditModeOwnedFrame
local HasBlizzardEditMode = Compatibility.HasBlizzardEditMode
local UsesNativeGamepadInterface = Compatibility.UsesNativeGamepadInterface
local UsesControllerInterface = Compatibility.UsesControllerInterface
local HasChattynator = Compatibility.HasChattynator
local UsesForeverEditMode = Compatibility.UsesForeverEditMode
local IsForeverEditModeFrame = Compatibility.IsForeverEditModeFrame
local RetailEditModeOwnsPrimaryChat = Compatibility.RetailEditModeOwnsPrimaryChat
local TransientPolicy = assert(
    Offhand.HUDTransientPolicy,
    "Offhand HUD transient policy must load before SeamRedirect"
)
local NormalizeMainhandTransientScale = TransientPolicy.NormalizeScale

local actionNames = {"MainMenuBar", "MainActionBar", "StatusTrackingBarManager", "MainMenuExpBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
    }

local Recovery = assert(
    Offhand.HUDRecovery,
    "Offhand HUD recovery must load before SeamRedirect"
).Install(HUD)
local GetEditModeLayouts = Recovery.GetEditModeLayouts
local EditModeLayoutNamesMatch = Recovery.EditModeLayoutNamesMatch
local GetActiveEditModeLayoutName = Recovery.GetActiveEditModeLayoutName
local GetEditModeCustomLayoutOffset = Recovery.GetEditModeCustomLayoutOffset
local RememberCharacterEditModeLayout = Recovery.RememberCharacterEditModeLayout
local HookCharacterEditModeSelection = Recovery.HookCharacterEditModeSelection
local PrepareForeverEditModeState = Recovery.PrepareForeverEditModeState

local function Remember(frame)
    desiredFrames[frame] = desiredFrames[frame] or {}
    return desiredFrames[frame]
end

-- Rewriting identical anchors dirties Blizzard layout again on the next frame.
local function Points(frame, ...)
    local desired = {...}
    Remember(frame).points = desired
    local same = frame:GetNumPoints() == #desired
    if same then
        for i, point in ipairs(desired) do
            local a, b, c, x, y = frame:GetPoint(i)
            if a ~= point[1] or b ~= point[2] or c ~= point[3]
                or math.abs((x or 0) - point[4]) > 0.001
                or math.abs((y or 0) - point[5]) > 0.001 then
                same = false; break
            end
        end
    end
    if same then return end
    frame:ClearAllPoints()
    for _, point in ipairs(desired) do frame:SetPoint(unpack(point)) end
end

local function ScreenPoint(frame, point, x, y)
    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
    Points(frame, {point, UIParent, "BOTTOMLEFT", x * factor, y * factor})
end

local function Anchor(frame, point, m, x, y, force)
    if not frame then return end
    if not force and frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if not force and frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    local px = point:find("LEFT") and m.gameLeft or point:find("RIGHT") and m.gameRight
        or (m.gameLeft + m.gameRight) / 2
    local py = point:find("TOP") and m.gameTop or point:find("BOTTOM") and m.gameBottom
        or (m.gameBottom + m.gameTop) / 2
    ScreenPoint(frame, point,
        px + (x or 0) * m.hudScale, py + (y or 0) * m.hudScale)
end

local function Prepare(frame, m)
    if not frame then return end
    frame:SetClampedToScreen(false)
end

local Transient = assert(
    Offhand.HUDTransientFrames,
    "Offhand HUD transient frames must load before SeamRedirect"
).Install(HUD, {
    Points = Points,
    Anchor = Anchor,
    Prepare = Prepare,
})
local PositionForeverGameMenu = Transient.PositionForeverGameMenu
local IsRetailChatSettlementActive = Transient.IsRetailChatSettlementActive

function HUD:RequestLayout()
    if aligning or pending or not Offhand.db or not Offhand.db.enabled then return end
    pending = true
    C_Timer.After(0.05, function()
        if not Offhand.db or not Offhand.db.enabled then pending = false; return end
        -- A HUD repair must not resize WorldFrame, the deck or docked modules.
        Offhand:RunOrQueueCombat(function()
            pending = false
            if Offhand.db and Offhand.db.enabled then HUD:AlignHUDFrames() end
        end)
    end)
end

function HUD:AlignChatFrame(m)
    if InCombatLockdown() or not Offhand.db.enabled or not ChatFrame1 or Offhand.db.dockChat == false then return end
    -- Chattynator owns the complete chat layout, including Blizzard's shared
    -- ChatFrame1EditBox.  Touching either its custom windows or that edit box
    -- can leave the visible input without mouse/focus handling.
    if HasChattynator() then return end
    local chat = ChatFrame1
    if IsRetailChatSettlementActive(chat) then return end
    if IsForeverEditModeFrame(chat, "ChatFrame1") then return end
    local chatName = (chat.GetName and chat:GetName()) or "ChatFrame1"
    local native = chat == ChatFrame1
    local retailManaged = native and RetailEditModeOwnsPrimaryChat(chat)
    local editModeActive = retailManaged and ((chat.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown()))
    if chat._OffhandDragging or MOVING_CHATFRAME == chat or editModeActive then return end
    if chat.Selection and chat.IsEditModeDragging and chat:IsEditModeDragging() then return end
    local nativeDefault = native and chat.IsInDefaultPosition and chat:IsInDefaultPosition()
    local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
        or (not native and Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
    -- Retail's primary chat frame is a Blizzard Edit Mode system. Offhand owns
    -- it only after an explicit workspace placement; otherwise Blizzard's
    -- active layout remains authoritative for both position and dimensions.
    if retailManaged and not isWs and Offhand.db.chatPosition ~= "DECK" then
        if Offhand.db.savedMainPositions then Offhand.db.savedMainPositions[chatName] = nil end
        return
    end
    Prepare(chat, m)
    if native then self:RepairChatDock() end
    if isWs then
        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
            Offhand.Canvas:RestoreWorkspacePosition(chat)
        elseif Offhand.Canvas and Offhand.Canvas.OnPanelDragStop and not (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName]) then
            Offhand.Canvas.OnPanelDragStop(chat)
        end
        if ChatFrame1EditBox then
            Points(ChatFrame1EditBox,
                {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
                {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
        end
        return
    end
    local mainPosition = native and Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[chatName]
    if mainPosition and Offhand.db.chatPosition ~= "DECK" then
        ScreenPoint(chat, mainPosition.point or "TOPLEFT", mainPosition.x, mainPosition.y)
        return
    end
    if not nativeDefault and chat.IsUserPlaced and chat:IsUserPlaced() and Offhand.db.chatPosition ~= "DECK" then return end
    if chat ~= ChatFrame1 and not hooks[chat] then
        hooks[chat] = true
        hooksecurefunc(chat, "SetPoint", function()
            local isWorkspace = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[chatName])
                or (Offhand.Canvas and Offhand.Canvas.IsFrameOnWorkspace and Offhand.Canvas.IsFrameOnWorkspace(chat))
            if not isWorkspace and not (chat.IsUserPlaced and chat:IsUserPlaced()) then
                HUD:RequestLayout()
            end
        end)
    end
    if Offhand.db.chatPosition == "DECK" and Offhand.canvas then
        pcall(function() chat:SetUserPlaced(false) end)
        ScreenPoint(chat, "BOTTOMLEFT",
            m.workspaceLeft + 24 * m.hudScale, m.workspaceBottom + 45 * m.hudScale)
        chat:SetSize(math.min(460, m.workspaceWidth / m.hudScale - 48), 220)
    else
        -- The native button strip sits outside the message frame's left edge.
        local inset = native and 48 or 24
        if native and chat.buttonFrame and chat.buttonFrame.GetWidth then
            inset = math.max(inset, chat.buttonFrame:GetWidth() + 17)
        end
        Anchor(chat, "BOTTOMLEFT", m, inset, 120, nativeDefault)
        local width = math.min(460, m.gameWidth / m.hudScale * 0.40)
        if not chat.GetWidth or not chat.GetHeight
            or math.abs(chat:GetWidth() - width) > 0.001 or math.abs(chat:GetHeight() - 220) > 0.001 then
            chat:SetSize(width, 220)
        end
    end
    if ChatFrame1EditBox then
        Points(ChatFrame1EditBox,
            {"TOPLEFT", chat, "BOTTOMLEFT", 0, 0},
            {"TOPRIGHT", chat, "BOTTOMRIGHT", 0, 0})
    end
end

function HUD:RepairChatDock()
    local dock = GENERAL_CHAT_DOCK or GeneralDockManager
    if not dock or dock.primary ~= ChatFrame1 then return end
    if dock.IsForbidden and dock:IsForbidden() then return end
    if dock.IsProtected and dock:IsProtected() then return end
    for _, key in ipairs({"savedWorkspacePositions", "savedMainPositions", "openWorkspacePanels"}) do
        if Offhand.db[key] then Offhand.db[key].GeneralDockManager = nil end
    end
    -- Tabs are dock children, not chat-frame children. Keep the native dock
    -- attached to chat, including after a former erroneous tab-parent drag.
    Points(dock,
        {"BOTTOMLEFT", ChatFrame1, "TOPLEFT", 0, 6},
        {"BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 6})
    if not self.chatDockRepaired or (dock.IsShown and not dock:IsShown()) then
        if dock.Show then dock:Show() end
        if dock.SetAlpha then dock:SetAlpha(1) end
        if FCFDock_UpdateTabs and dock.DOCKED_CHAT_FRAMES then
            FCFDock_UpdateTabs(dock, true)
        end
        self.chatDockRepaired = true
    end
end

function HUD:RepairChatButtons(chat)
    if not chat or chat ~= _G.ChatFrame1 or not FCF_SetButtonSide then return end
    -- Forever's Edit Mode owns ChatFrame1ButtonFrame. Replaying the saved side
    -- while that layout is settling can move the channel/menu buttons to the
    -- opposite edge after /reload or an Edit Mode save. Retail still needs the
    -- native helper after Offhand moves a deliberately workspace-owned chat.
    if Offhand.isForever then return end
    -- The channel/menu controls are children of ChatFrame1ButtonFrame. Force
    -- Blizzard's own layout function to reattach that frame after Offhand moves
    -- the message frame into the workspace.
    pcall(function()
        FCF_SetButtonSide(chat, chat.buttonSide or "left", true)
    end)
end

function HUD:AlignHUDFrames(m)
    if aligning or InCombatLockdown() or not Offhand.db.enabled then return end
    aligning = true
    local ok, err = pcall(function()
        m = m or Offhand.Viewport:GetMetrics()
        if Offhand.MainhandCompatibility and Offhand.MainhandCompatibility.UpdateClassicNativeBar then
            Offhand.MainhandCompatibility.UpdateClassicNativeBar(m)
        end
        if not HasBlizzardEditMode() and not HasCustomActionBarAddon() then
            local main = MainMenuBar or MainActionBar

            -- Detect if the action bar is currently centered in the bezel (default Edit Mode behavior for bottom)
            local isBezelCentered = false
            if main and main.GetCenter then
                local cx = main:GetCenter()
                local screenCenter = UIParent:GetWidth() / 2
                if cx and math.abs(cx - screenCenter) < 150 then
                    isBezelCentered = true
                end
            end

            -- If it's in the default Edit Mode position, or it's Classic Era, center it on the game viewport!
            if main and (isBezelCentered or not EditModeManagerFrame) then
                Prepare(main, m)
                Anchor(main, "BOTTOM", m, 0, 0)
            end

            -- For older clients (Classic Era) that don't have Edit Mode, we must manually stack the extra bars
            if not EditModeManagerFrame then
                if MainActionBar and MainActionBar ~= main and (not MainActionBar.IsInDefaultPosition or MainActionBar:IsInDefaultPosition()) then
                    Prepare(MainActionBar, m)
                    Points(MainActionBar, {"BOTTOMLEFT", main, "BOTTOMLEFT", 8, 4})
                end

                local xp = StatusTrackingBarManager or MainMenuExpBar
                Prepare(xp, m)
                if xp and main and (not xp.IsInDefaultPosition or xp:IsInDefaultPosition()) then
                    Points(xp, {"BOTTOM", main, "TOP", 0, -2})
                end

                -- Match Blizzard's compact default stack: the thin XP/reputation
                -- bar sits directly above the main bar, while stance/form buttons
                -- begin above action button 1 on the left. This is a one-pass
                -- legacy default adjustment, not a managed-frame hook: form bars
                -- retain native ownership after the initial layout.
                local stance = StanceBar or ShapeshiftBarFrame
                if stance and main
                    and (not stance.IsInDefaultPosition or stance:IsInDefaultPosition()) then
                    local point, relativeTo, relativePoint, x, y = stance:GetPoint(1)
                    if stance:GetNumPoints() ~= 1 or point ~= "BOTTOMLEFT"
                        or relativeTo ~= main or relativePoint ~= "TOPLEFT"
                        or math.abs((x or 0) - 0) > 0.001
                        or math.abs((y or 0) - 14) > 0.001 then
                        stance:ClearAllPoints()
                        stance:SetPoint("BOTTOMLEFT", main, "TOPLEFT", 0, 14)
                    end
                end

                local bottomLeft, bottomRight = MultiBarBottomLeft, MultiBarBottomRight
                Prepare(bottomLeft, m)
                Prepare(bottomRight, m)
                if bottomLeft and main and (not bottomLeft.IsInDefaultPosition or bottomLeft:IsInDefaultPosition()) then
                    Points(bottomLeft, {"BOTTOMLEFT", main, "TOPLEFT", 0, 8})
                end
                if bottomRight and main and (not bottomRight.IsInDefaultPosition or bottomRight:IsInDefaultPosition()) then
                    Points(bottomRight, {"BOTTOMLEFT", main, "TOPLEFT", 515, 8})
                end
            end

            -- Right side action bars (Safely dock to the game viewport right edge if they are at the bezel edge)
            local function IsRightBezelAnchored(frame)
                if not frame or not frame.GetCenter then return false end
                local cx = frame:GetCenter()
                local screenCenter = UIParent:GetWidth() / 2

                -- Check if the frame is sitting in the bezel (center of the entire span)
                if cx and math.abs(cx - screenCenter) < 150 then return true end

                -- Also check if it's sitting on the far physical right edge of the screen, BUT the game viewport is on the left
                if cx and m and cx > m.gameRight and cx > (UIParent:GetWidth() - 150) then return true end

                return false
            end

            if MultiBarRight and (IsRightBezelAnchored(MultiBarRight) or not EditModeManagerFrame) then
                Prepare(MultiBarRight, m)
                Anchor(MultiBarRight, "RIGHT", m, -4, 0)
            end

            if MultiBarLeft and (IsRightBezelAnchored(MultiBarLeft) or not EditModeManagerFrame) then
                Prepare(MultiBarLeft, m)
                Anchor(MultiBarLeft, "RIGHT", m, -48, 0)
            end
        end

        for _, item in ipairs({
            {"MinimapCluster", "TOPRIGHT", 0, 0},
            {"PlayerFrame", "TOPLEFT", 16, -16},
            {"TargetFrame", "TOPLEFT", 260, -16},
            {"PartyMemberFrame1", "TOPLEFT", 16, -160},
            {"CompactPartyFrame", "TOPLEFT", 16, -160},
            {"BuffFrame", "TOPRIGHT", -210, -16},
            {"BuffCluster", "TOPRIGHT", -210, -16},
            {"CastingBarFrame", "BOTTOM", 0, 165},
            {"PlayerCastingBarFrame", "BOTTOM", 0, 165},
        }) do
            local frame = _G[item[1]]
            if frame then
                if IsForeverEditModeFrame(frame, item[1]) then
                    -- Forever's saved Edit Mode layout owns these frames. Writing
                    -- their anchors here can taint later Edit Mode/party refreshes.
                elseif item[1] == "MinimapCluster" and HasCustomMinimapAddon() then
                    -- Yield completely to custom minimap addon (e.g. SexyMap, BasicMinimap, ElvUI)
                elseif frame._OffhandDragging then
                    -- Frame is actively being dragged by the player; do not interrupt!
                else
                    Prepare(frame, m)
                    local isWorkspace = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[item[1]]
                    if isWorkspace then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                    else
                        if item[1] == "MinimapCluster" then
                            pcall(function() frame:SetUserPlaced(false) end)
                            Anchor(frame, item[2], m, item[3], item[4], true)
                            if frame.IsShown and not frame:IsShown() and frame.Show then
                                frame:Show()
                            end
                            if frame.SetAlpha then frame:SetAlpha(1) end
                        elseif item[1] == "PartyMemberFrame1" or item[1] == "CompactPartyFrame" then
                            local mainPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[item[1]]
                            local isEditModeCustomized = frame.IsInDefaultPosition and not frame:IsInDefaultPosition()
                            if isEditModeCustomized then
                                -- Yield to Edit Mode
                            elseif mainPos and mainPos.x and mainPos.y then
                                local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                frame:ClearAllPoints()
                                frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", mainPos.x * factor, mainPos.y * factor)
                            elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                                Anchor(frame, item[2], m, item[3], item[4], false)
                            end
                        elseif not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                            Anchor(frame, item[2], m, item[3], item[4], false)
                        end
                    end
                end
            end
        end

        self:AlignChatFrame(m)
        if Offhand.db.seamRedirect then
            for _, item in ipairs({{"UIErrorsFrame", -60}, {"RaidWarningFrame", -100}}) do
                local frame = _G[item[1]]
                Prepare(frame, m)
                if frame then Anchor(frame, "TOP", m, 0, item[2]) end
            end
            self:PositionMainhandTransientFrames(m)
        end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

-- Replay the last committed layout for just the frame Blizzard changed. A timer
-- exposes the reset geometry for several rendered frames even when idle.
-- Cache only layout written by AlignHUDFrames; never replace Blizzard methods or
-- force visibility/action state. The guard prevents our setters from re-entering.
function HUD:RepairFrame(frame)
    if aligning or not Offhand.db or not Offhand.db.enabled then return end
    if IsForeverEditModeFrame(frame) then return end
    if frame.IsUserPlaced and frame:IsUserPlaced() then return end
    if HasCustomActionBarAddon() then return end

    if frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then
        -- Edit Mode marks preset layouts (like "Classic") as non-default.
        -- We must check if it's an action bar sitting in the bezel before yielding!
        local yieldToEditMode = true
        if frame == _G.MainMenuBar or frame == _G.MainActionBar then
            local cx = frame.GetCenter and frame:GetCenter()
            if cx and math.abs(cx - (UIParent:GetWidth() / 2)) < 150 then
                yieldToEditMode = false -- It's sitting in the bezel, let Offhand move it
            end
        elseif frame == _G.MultiBarRight or frame == _G.MultiBarLeft then
            local cx = frame.GetCenter and frame:GetCenter()
            local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
            if cx and (math.abs(cx - UIParent:GetWidth()) < 150 or (m and cx > m.gameRight and cx > (UIParent:GetWidth() - 150))) then
                yieldToEditMode = false -- It's on the far right bezel edge, let Offhand move it
            end
        end

        if yieldToEditMode then return end
    end
    local desired = desiredFrames[frame]
    if not desired then return end
    if InCombatLockdown() then self:RequestLayout(); return end
    aligning = true
    local ok, err = pcall(function()
        if desired.points then Points(frame, unpack(desired.points)) end
    end)
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end

function HUD:IsManagedFrame(frame)
    return desiredFrames[frame] ~= nil
end

-- Repair only the committed native chat anchor before the next rendered frame.
-- Do not run a full HUD layout (or resize chat) from a SetPoint callback.
function HUD:RepairChatAnchor(frame)
    if aligning or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
        or Offhand.db.dockChat == false or HasChattynator() then return end
    if IsRetailChatSettlementActive(frame) then return end
    if frame._OffhandDragging or frame._OffhandApplyingTrackedChatPosition
        or MOVING_CHATFRAME == frame then return end
    local retailManaged = RetailEditModeOwnsPrimaryChat(frame)
    local retailEditModeActive = retailManaged and ((frame and frame.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown
            and EditModeManagerFrame:IsShown()))
    if retailEditModeActive then return end
    if Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions.ChatFrame1 then
        -- Blizzard restores the primary chat anchor late during cold login on
        -- both legacy and Forever clients. The SetPoint hook runs inside that
        -- write, so reanchoring synchronously risks recursion. Reassert the
        -- explicit Offhand placement on the next frame and coalesce bursts of
        -- native layout writes into one repair.
        if self.chatWorkspaceRepairPending or not C_Timer or not C_Timer.After then return end
        self.chatWorkspaceRepairPending = true
        C_Timer.After(0, function()
            self.chatWorkspaceRepairPending = nil
            if aligning or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
                or Offhand.db.dockChat == false or HasChattynator()
                or IsRetailChatSettlementActive(frame)
                or frame._OffhandDragging or MOVING_CHATFRAME == frame
                or (RetailEditModeOwnsPrimaryChat(frame)
                    and ((frame and frame.isInEditMode == true)
                        or (EditModeManagerFrame and EditModeManagerFrame.IsShown
                            and EditModeManagerFrame:IsShown())))
                or not (Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions.ChatFrame1) then return end
            if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                aligning = true
                local ok, err = pcall(Offhand.Canvas.RestoreWorkspacePosition, Offhand.Canvas, frame)
                aligning = false
                if not ok then Offhand:Print("Chat workspace repair error: %s", tostring(err)) end
            end
        end)
        return
    end
    if retailManaged then return end
    if frame.Selection and frame.IsEditModeDragging and frame:IsEditModeDragging() then return end
    if frame.IsInDefaultPosition and not frame:IsInDefaultPosition() then return end
    local desired = desiredFrames[frame]
    if not desired or not desired.points then return end
    aligning = true
    local ok, err = pcall(Points, frame, unpack(desired.points))
    aligning = false
    if not ok then Offhand:Print("HUD layout error: %s", tostring(err)) end
end


function HUD:IsRetailEditModePrimaryChat(frame)
    return RetailEditModeOwnsPrimaryChat(frame)
end

function HUD:HookFrames()
    self:HookMainhandTransientFrames()
    if UsesForeverEditMode() then
        -- Seed the hidden frame as soon as it exists, then repair synchronously
        -- after every native toggle in case Blizzard rebuilt its stock anchor.
        PositionForeverGameMenu()
        if hooksecurefunc and ToggleGameMenu and not self.foreverGameMenuHooked then
            self.foreverGameMenuHooked = true
            hooksecurefunc("ToggleGameMenu", function()
                PositionForeverGameMenu()
            end)
        end
    end
    if not HasBlizzardEditMode() and not HasCustomActionBarAddon() then
        if not self.managerHooked and UIParent_ManageFramePositions then
            self.managerHooked = true
            hooksecurefunc("UIParent_ManageFramePositions", function()
                if InCombatLockdown() then return end
                for _, name in ipairs(actionNames) do
                    local frame = _G[name]
                    if frame then HUD:RepairFrame(frame) end
                end
                HUD:RequestLayout()
            end)
        end
        for _, name in ipairs(actionNames) do
            local frame = _G[name]
            if frame and not hooks[frame] then
                hooks[frame] = true
                hooksecurefunc(frame, "SetPoint", function() HUD:RepairFrame(frame) end)
            end
        end
    end
    for _, name in ipairs({"PlayerFrame", "TargetFrame", "PartyMemberFrame1", "CompactPartyFrame", "ChatFrame1",
        "BuffFrame", "UIErrorsFrame", "RaidWarningFrame"}) do
        local frame = _G[name]
        if frame and not IsForeverEditModeFrame(frame, name) and not hooks[frame] then
            hooks[frame] = true
            hooksecurefunc(frame, "SetPoint", function()
                if frame._OffhandDragging or MOVING_CHATFRAME == frame then return end
                if frame == ChatFrame1 then HUD:RepairChatAnchor(frame); return end
                local isWs = Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not isWs and not (frame.IsUserPlaced and frame:IsUserPlaced()) then
                    HUD:RequestLayout()
                end
            end)
        end
    end

    -- Center ordinary menus and settings panels on Mainhand. Edit Mode and its
    -- system dialogs stay entirely Blizzard-owned on every client.
    local menuFrameNames = {
        "GameMenuFrame", "SettingsPanel", "InterfaceOptionsFrame", "VideoOptionsFrame",
        "AddonList", "KeyBindingFrame", "HelpFrame",
        "BugSackFrame", "RedIsFriendFrame",
    }
    local function PrepareForeverEditModeManager()
        -- Forever's Edit Mode manager is part of a secure/secret-value path.
        -- Leave its panel metadata, attributes, scripts and anchors entirely native.
        return
    end

    local function PositionEditMode()
        -- Non-Forever Edit Mode positioning remains disabled. Repeatedly moving the
        -- manager or its dialogs from OnShow taints CompactUnitFrame on some clients.
    end

    local function CenterGameMenu()
        if UsesForeverEditMode() then return end
        PositionEditMode()
        for _, name in ipairs(menuFrameNames) do
            local frame = _G[name]
            if frame and frame:IsShown() and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                local m = Offhand.Viewport:GetMetrics()
                if Offhand.MenuPlacement then Offhand.MenuPlacement:Center(frame, m) end
            end
        end
    end

    local function HookMenuFrame(name)
        if UsesForeverEditMode() then return end
        local frame = _G[name]
        if frame and not hooks[frame] then
            hooks[frame] = true
            if SetUIPanelAttribute then
                pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
            end
            frame:HookScript("OnShow", function(self)
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
            end)
            if name == "AddonList" and UISpecialFrames then
                local found = false
                for _, sName in ipairs(UISpecialFrames) do
                    if sName == "AddonList" then found = true; break end
                end
                if not found then table.insert(UISpecialFrames, "AddonList") end
            end
        end
    end

    if not UsesForeverEditMode() and UIPanelWindows then
        for _, name in ipairs(menuFrameNames) do
            if UIPanelWindows[name] then
                UIPanelWindows[name].area = nil
                UIPanelWindows[name].centerFrameSkipAnchoring = true
            end
        end
    end

    for _, name in ipairs(menuFrameNames) do
        HookMenuFrame(name)
    end

    local function PatchEditModeUtil()
        -- Disabled: Overriding EditModeUtil causes taint in CompactUnitFrame (e.g. party/raid frames)
        -- We no longer attempt to patch GetBottomActionBarHeight.
    end

    local function CheckEditModeHooks()
        PatchEditModeUtil()
        if UsesForeverEditMode() then
            PrepareForeverEditModeManager()
            -- Do not attach addon script handlers to Forever's Edit Mode manager.
            -- Its layout and close/reset path remain Blizzard-owned after the
            -- one-time panel-manager preparation above.
            return
        end
        -- Non-Forever clients also own the manager, dialogs, and managed
        -- systems. Do not attach even a no-op OnShow hook: new Blizzard builds
        -- initialize the Damage Meter from the same secure Edit Mode traversal.
    end
    CheckEditModeHooks()

    -- Universal Void Rescue & Popup Redirection Engine
    -- Rescues frames anchoring into the unrendered black space above the 3D Game Viewport,
    -- and redirects popups that anchor to the bezel seam center.
    local function RedirectExternalPopups()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        -- Forever's native gamepad navigator owns the structure and focus of
        -- visible windows. The broad rescue pass must not enumerate and
        -- re-anchor those roots while SmartNavigation is rebuilding them.
        if UsesNativeGamepadInterface() then return end
        
        local m = Offhand.Viewport:GetMetrics()
        if not m or not m.isSpanned then return end
        local cx = (m.gameLeft + m.gameRight) / 2
        local cy = (m.gameBottom + m.gameTop) / 2
        local parentScale = UIParent:GetEffectiveScale() or 1

        local function CenterIsInside(left, top, width, height, areaLeft, areaBottom, areaRight, areaTop)
            if not left or not top or not width or not height
                or areaLeft == nil or areaBottom == nil or areaRight == nil or areaTop == nil then
                return false
            end
            local centerX = left + width / 2
            local centerY = top - height / 2
            return centerX >= areaLeft and centerX <= areaRight
                and centerY >= areaBottom and centerY <= areaTop
        end

        -- 1. Check UISpecialFrames (standard config panels)
        if UISpecialFrames then
            for _, name in ipairs(UISpecialFrames) do
                local frame = _G[name]
                if frame and type(frame) == "table" and frame.GetPoint
                    and not IsBlizzardEditModeOwnedFrame(frame, name)
                    and not hooks[frame] and frame.IsProtected and not frame:IsProtected() then
                    hooks[frame] = true
                    frame:HookScript("OnShow", function(self)
                        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                        local pt, rel = self:GetPoint(1)
                        if (rel == UIParent or rel == nil) and (pt == "CENTER") then
                            self:ClearAllPoints()
                            local factor = UIParent:GetEffectiveScale() / self:GetEffectiveScale()
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            self:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                        end
                    end)
                end
            end
        end

        -- 2. Void Rescue: Detect any frame on the game monitor side whose top extends into the black void above m.gameTop
        local voidTargets = {
        }
        for _, frame in ipairs(voidTargets) do
            if frame and type(frame) == "table" then
                pcall(function()
                    if frame.IsForbidden and frame:IsForbidden() then return end
                    if frame.IsProtected and frame:IsProtected() then return end
                    if not frame.IsShown or not frame:IsShown() then return end
                    local fScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (frame:GetTop() or 0) * scaleFactor
                    local left = (frame:GetLeft() or 0) * scaleFactor
                    local width = (frame.GetWidth and frame:GetWidth() or 0) * scaleFactor
                    local height = (frame.GetHeight and frame:GetHeight() or 0) * scaleFactor
                    local centerX = left + width / 2
                    local onGameSide = centerX >= m.gameLeft and centerX <= m.gameRight
                    local onWorkspace = CenterIsInside(left, top, width, height,
                        m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
                    if onGameSide and not onWorkspace and top > (m.gameTop + 2) then
                        frame:ClearAllPoints()
                        local invFactor = parentScale / fScale
                        local offsetX = cx - (UIParent:GetWidth() / 2)
                        local offsetY = cy - (UIParent:GetHeight() / 2)
                        frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                    end
                end)
            end
        end

        -- 3. Scan active children of UIParent for rogue centered popup frames or frames in the void
        for _, child in ipairs({UIParent:GetChildren()}) do
            if type(child) == "table" and child ~= WorldFrame and child ~= Offhand.canvas then
                pcall(function()
                    if child.IsForbidden and child:IsForbidden() then return end
                    if not child.IsShown or not child:IsShown() then return end
                    if child.IsProtected and child:IsProtected() then return end

                    local cName
                    if child.GetName then
                        local okName, name = pcall(child.GetName, child)
                        if okName then cName = name end
                    end
                    if cName == "OffhandCanvasFrame" or cName == "OffhandSeamGuideLine" then return end
                    if IsBlizzardEditModeOwnedFrame(child, cName)
                        or IsForeverEditModeFrame(child, cName) then return end
                    -- Native chat owns these linked frames. Moving a dock or tab
                    -- independently separates the headers from the message window.
                    if child == GeneralDockManager or child == GENERAL_CHAT_DOCK
                        or (cName and cName:match("^ChatFrame%d")) then return end

                    -- Void Rescue check for general children on the game side
                    local fScale = (child.GetEffectiveScale and child:GetEffectiveScale()) or parentScale
                    if fScale <= 0 then fScale = parentScale end
                    local scaleFactor = fScale / parentScale
                    local top = (child.GetTop and child:GetTop() or 0) * scaleFactor
                    local left = (child.GetLeft and child:GetLeft() or 0) * scaleFactor
                    local width = (child.GetWidth and child:GetWidth() or 0) * scaleFactor
                    local height = (child.GetHeight and child:GetHeight() or 0) * scaleFactor
                    local centerX = left + width / 2
                    local onGameSide = centerX >= m.gameLeft and centerX <= m.gameRight
                    local onWorkspace = CenterIsInside(left, top, width, height,
                        m.workspaceLeft, m.workspaceBottom, m.workspaceRight, m.workspaceTop)
                    if onGameSide and not onWorkspace and top > (m.gameTop + 2) then
                        if child.GetPoint and child.ClearAllPoints and child.SetPoint then
                            child:ClearAllPoints()
                            local invFactor = parentScale / fScale
                            local offsetX = cx - (UIParent:GetWidth() / 2)
                            local offsetY = cy - (UIParent:GetHeight() / 2)
                            child:SetPoint("CENTER", UIParent, "CENTER", offsetX * invFactor, offsetY * invFactor)
                        end
                    end

                    -- Seam centering check
                    if child.GetNumPoints and child:GetNumPoints() == 1 then
                        local pt, rel, relPt, x, y = child:GetPoint(1)
                        if (rel == UIParent or rel == nil) and pt == "CENTER" and relPt == "CENTER" then
                            if (x or 0) == 0 and (y or 0) == 0 then
                                if child.ClearAllPoints and child.SetPoint then
                                    child:ClearAllPoints()
                                    local factor = UIParent:GetEffectiveScale() / child:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    child:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    -- The general scanner is intentionally broad and slow. Blizzard Edit Mode
    -- recovery gets a separate cheap cadence so its entry prompt and native
    -- transactional dialogs become usable in well under a second on every
    -- supported client.
    if HasBlizzardEditMode() and C_Timer and C_Timer.NewTicker
        and not self.foreverEditModeRecoveryTicker then
        self.foreverEditModeRecoveryTicker = C_Timer.NewTicker(0.25, function()
            HUD:UpdateForeverEditModeControlsRecovery()
        end)
    end

    if C_Timer and C_Timer.NewTicker and not self.popupTicker then
        self.popupTicker = C_Timer.NewTicker(2, function()
            RedirectExternalPopups()
            HUD:HookMainhandTransientFrames()
            HUD:PositionMainhandTransientFrames()
            CheckEditModeHooks()
            HUD:UpdateForeverEditModeControlsRecovery()
            HUD:UpdateForeverPartyFrameRecovery()
        end)
    end

    local function AutoLoadEditModeLayout()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        if UsesControllerInterface() then return end
        if not C_EditMode or not C_EditMode.GetLayouts then return end
        
        local layoutData = C_EditMode.GetLayouts()
        if not layoutData or not layoutData.layouts then return end

        local forever = UsesForeverEditMode()
        if not forever and Offhand.Mainhand and Offhand.Mainhand.UpdateWindowModeLayout then
            local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
            local managed = Offhand.Mainhand:UpdateWindowModeLayout(metrics)
            -- Generated-layout transitions own both window modes. The legacy
            -- login selector must not reselect Mainhand after a window restore.
            if managed then return end
        end
        if forever then
            local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
                and Offhand.Viewport:GetMetrics() or nil
            PrepareForeverEditModeState(layoutData, metrics)
        end
        local activeName = not forever and GetActiveEditModeLayoutName() or nil
        local targetName = forever
            and (type(OffhandCharDB) == "table" and OffhandCharDB.foreverEditModeLayoutName or nil)
            or (type(OffhandCharDB) == "table" and OffhandCharDB.editModeLayoutName or nil)
        if not forever and (type(targetName) ~= "string" or not targetName:match("%S")) then
            -- Upgrade behavior: adopt the layout Blizzard already selected for
            -- this character. Do not replace it merely because a layout named
            -- "Offhand" also exists on the account.
            targetName = activeName
            RememberCharacterEditModeLayout()
        end

        local found = false
        local needsSetup = false
        for index, layout in ipairs(layoutData.layouts) do
            if targetName and EditModeLayoutNamesMatch(layout.layoutName, targetName) then
                found = true
                if forever then
                    -- A newly copied/renamed layout can still contain Blizzard's
                    -- full-canvas default for Action Bar 1. Selecting it would
                    -- appear to move the bar away from the Mainhand viewport.
                    -- Require the player to position the main bar once in Edit
                    -- Mode; this keeps all protected writes inside Blizzard UI.
                    needsSetup = true
                    local actionBarSystem = Enum and Enum.EditModeSystem and Enum.EditModeSystem.ActionBar
                    local mainBarIndex = Enum and Enum.EditModeActionBarSystemIndices and Enum.EditModeActionBarSystemIndices.MainBar
                    for _, systemInfo in ipairs(layout.systems or {}) do
                        if systemInfo.system == actionBarSystem and systemInfo.systemIndex == mainBarIndex then
                            needsSetup = systemInfo.isInDefaultPosition ~= false
                            break
                        end
                    end
                end
                if not needsSetup and not forever
                    and not EditModeLayoutNamesMatch(activeName, targetName)
                    and C_EditMode.SetActiveLayout then
                    -- GetLayouts().layouts contains only custom entries, while
                    -- SetActiveLayout consumes the global identifier after the
                    -- built-in preset rows. Passing the bare array index can
                    -- silently select Modern/Classic while appearing successful.
                    local targetID = GetEditModeCustomLayoutOffset(layoutData, activeName) + index
                    local ok, result = pcall(C_EditMode.SetActiveLayout, targetID)
                    local confirmed = GetEditModeLayouts()
                    if ok and result ~= false and confirmed
                        and tonumber(confirmed.activeLayout) == targetID then
                        Offhand:Print("Auto-loaded Edit Mode layout: " .. layout.layoutName)
                    end
                end
                break
            end
        end

        if not forever and not found and activeName and type(OffhandCharDB) == "table" then
            -- The remembered layout was renamed or deleted. The currently
            -- active Blizzard choice is the safest replacement; never select
            -- an unrelated layout that inherited the old numeric slot.
            OffhandCharDB.editModeLayoutName = activeName
        end

        local designatedActive = false
        if forever and targetName and found then
            local status = self:GetForeverEditModeLayoutStatus()
            designatedActive = status and status.activeMatches or false
        end
        local needsGuidance = forever
            and (not targetName or not found or (needsSetup and not designatedActive))
            or (Offhand.isRetail and not activeName)
        if needsGuidance and not self.editModeGuidanceShown then
            self.editModeGuidanceShown = true
            local messageKey = HasEllesmerePartyFrames()
                and "COMPAT_ELLESMERE_PARTY" or (UsesForeverEditMode() and "EDIT_MODE_LAYOUT_MISSING" or "EDIT_MODE_LAYOUT_MISSING_RETAIL")
            Offhand:Print((Offhand.L and Offhand.L[messageKey]) or (Offhand.L and Offhand.L["EDIT_MODE_LAYOUT_MISSING"]))
        end
    end

    local function UpdateUIPanelOffsets()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        if HasBlizzardEditMode() then
            -- Forever dispatches UIParent attribute changes through its secure
            -- panel manager and reads layout offsets from UIPanelLayoutFrame.
            -- Avoid this legacy attribute path entirely on that client.
            return
        end
        local m = Offhand.Viewport:GetMetrics()
        if m and m.isSpanned and UIParent.SetAttribute then
            -- Default blizzard panels to the Game World monitor, but add standard 16px left padding
            -- and preserve Blizzard's native -104px top padding (so they don't jam into the absolute corner)
            local left = (m.gameLeft or 0) + 16
            UIParent:SetAttribute("LEFT_OFFSET", left)
            
            local topDelta = (UIParent:GetHeight() or 0) - (m.gameTop or 0)
            UIParent:SetAttribute("TOP_OFFSET", -104 - (topDelta > 0 and topDelta or 0))
        end
    end

    UpdateUIPanelOffsets()
    HookCharacterEditModeSelection()
    if not Offhand.db or not Offhand.db.enabled then
        self.editModeLoadScheduled = nil
    elseif not self.editModeLoadScheduled then
        self.editModeLoadScheduled = true
        C_Timer.After(3, AutoLoadEditModeLayout)
    end

    if not UsesForeverEditMode() and not self.menuHooksInstalled then
        self.menuHooksInstalled = true
        if ToggleGameMenu then
            hooksecurefunc("ToggleGameMenu", function()
                CenterGameMenu()
                C_Timer.After(0, CenterGameMenu)
                C_Timer.After(0.05, CenterGameMenu)
            end)
        end
        if CreateFrame then
            local editModeLoader = CreateFrame("Frame")
            if editModeLoader and editModeLoader.RegisterEvent and editModeLoader.SetScript then
                editModeLoader:RegisterEvent("ADDON_LOADED")
                editModeLoader:SetScript("OnEvent", function(_, _, addonName)
                    if addonName == "Blizzard_EditMode" or addonName == "Blizzard_Settings" then
                        CheckEditModeHooks()
                        HookCharacterEditModeSelection()
                        for _, name in ipairs(menuFrameNames) do HookMenuFrame(name) end
                    end
                end)
            end
        end
        if ShowUIPanel then
            hooksecurefunc("ShowUIPanel", function(frame)
                if frame and not InCombatLockdown() and Offhand.db and Offhand.db.enabled then
                    local name = frame.GetName and frame:GetName()
                    if name then
                        if IsBlizzardEditModeOwnedFrame(frame, name)
                            or IsForeverEditModeFrame(frame, name) then return end
                        local isMenu = false
                        for _, n in ipairs(menuFrameNames) do
                            if n == name then isMenu = true; break end
                        end
                        
                        local info = UIPanelWindows and UIPanelWindows[name]
                        if isMenu or (info and info.area == "center") then
                            local function DoCenter()
                                if frame:IsShown() and not InCombatLockdown() then
                                    local m = Offhand.Viewport:GetMetrics()
                                    frame:ClearAllPoints()
                                    local cx = (m.gameLeft + m.gameRight) / 2
                                    local cy = (m.gameBottom + m.gameTop) / 2
                                    local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                                    local offsetX = cx - (UIParent:GetWidth() / 2)
                                    local offsetY = cy - (UIParent:GetHeight() / 2)
                                    frame:SetPoint("CENTER", UIParent, "CENTER", offsetX * factor, offsetY * factor)
                                end
                            end
                            DoCenter()
                            C_Timer.After(0, DoCenter)
                        end
                    end
                end
            end)
        end
        if UpdateUIPanelPositions then
            hooksecurefunc("UpdateUIPanelPositions", function()
                UpdateUIPanelOffsets()
            end)
        end
    end

    -- Keep bags on regular monitor unless user explicitly dragged them to workspace
    local isArrangingBags = false
    function HUD:LayoutBags()
        if Offhand.isForever or HasCustomBagAddon() or isArrangingBags
            or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        isArrangingBags = true

        local m = Offhand.Viewport and Offhand.Viewport:GetMetrics()
        if not m then
            isArrangingBags = false
            return
        end

        local deckMinX = m.workspaceLeft + 12
        local deckMaxX = m.workspaceRight - 12
        local deckMinY = m.workspaceBottom + 12
        local deckMaxY = math.max(deckMinY, m.workspaceTop - 30)

        local visibleBackpack = ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown()
            and ContainerFrameCombinedBags
            or (ContainerFrame1 and ContainerFrame1:IsShown() and ContainerFrame1 or nil)
        if visibleBackpack and Offhand.Canvas and Offhand.Canvas.PrepareNativeBackpackFrame then
            Offhand.Canvas:PrepareNativeBackpackFrame(visibleBackpack)
        end

        -- Determine if bags are stationed on the workspace
        local bpPos = Offhand.Canvas and Offhand.Canvas.GetNativeBackpackWorkspacePosition
            and Offhand.Canvas:GetNativeBackpackWorkspacePosition() or (Offhand.db.savedWorkspacePositions and (
            Offhand.db.savedWorkspacePositions["ContainerFrame1"] or 
            Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
        ))
        local bagsOnWorkspace = false
        if bpPos and bpPos.x and bpPos.y then
            bagsOnWorkspace = true
        end

        local bagSpacing = 4
        local defaultBagWidth = 192
        local defaultBagHeight = 250

        if bagsOnWorkspace and bpPos then
            -- Layout on workspace: dock unpositioned bags relative to the backpack on the workspace
            local expandRight = (bpPos.x + (defaultBagWidth + bagSpacing) * 3 <= deckMaxX)
            local currentX = bpPos.x
            local currentY = bpPos.y
            local stackBagCount = 0

            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame:IsShown() then
                    local name = frame:GetName()
                    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if pos and pos.x and pos.y then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                        if frame.SetAlpha then frame:SetAlpha(1) end
                    else
                        local w = frame:GetWidth() or defaultBagWidth
                        local h = frame:GetHeight() or defaultBagHeight
                        local targetX, targetY

                        targetX = currentX
                        targetY = currentY + (h + bagSpacing) * (stackBagCount + 1)
                        if targetY + h > deckMaxY then
                            if expandRight then
                                currentX = currentX + w + bagSpacing
                            else
                                currentX = currentX - w - bagSpacing
                            end
                            stackBagCount = 0
                            targetX = currentX
                            targetY = currentY + (h + bagSpacing) * (stackBagCount + 1)
                        end

                        targetX = math.max(deckMinX, math.min(targetX, deckMaxX - w))
                        targetY = math.max(deckMinY, math.min(targetY, deckMaxY - h))

                        if name and not string.match(name, "^ContainerFrame") then
                            frame:SetUserPlaced(true)
                        end
                        frame:ClearAllPoints()
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        -- Offset X by width so BOTTOMRIGHT anchor acts identically to old TOPLEFT
                        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", (targetX + w) * factor, (targetY - h) * factor)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        stackBagCount = stackBagCount + 1
                    end
                end
            end
            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
                if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                    Offhand.Canvas.RestoreWorkspacePosition(ContainerFrameCombinedBags)
                end
                if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
            end
        else
            -- Standard game view bag layout: Custom collision detection to wrap around action bars
            local right = m.gameRight - 16
            local bottom = m.gameBottom + 32
            
            local function DodgeFrame(f)
                if type(f) == "string" then f = _G[f] end
                if not f or not f.IsShown or not f:IsShown() then return end
                local factor = (f.GetEffectiveScale and f:GetEffectiveScale() or 1) / UIParent:GetEffectiveScale()
                local fl = (f:GetLeft() or 0) * factor
                local fr = (f:GetRight() or 0) * factor
                local ft = (f:GetTop() or 0) * factor
                local fb = (f:GetBottom() or 0) * factor
                if fr == 0 and fb == 0 then return end
                                
                -- If it's a vertical bar on the right edge, push bags left
                if fr >= m.gameRight - 200 and fb < m.gameBottom + 500 then
                    if (ft - fb) > (fr - fl) * 1.5 then
                        right = math.min(right, fl - 16)
                    end
                end
                
                -- If it's a horizontal bar in the bottom right quadrant, push bags up
                if fr >= m.gameRight - 400 and fb <= m.gameBottom + 200 then
                      if (fr - fl) > (ft - fb) * 1.5 then
                          bottom = math.max(bottom, ft + 16)
                      end
                  end
            end
            
                        DodgeFrame("MultiBarRight")
                        DodgeFrame("MultiBarLeft")
            DodgeFrame("MultiBar5")
            DodgeFrame("MultiBar6")
            DodgeFrame("MultiBar7")
            DodgeFrame("MicroButtonAndBagsBar")
            DodgeFrame("MicroMenuContainer")
            DodgeFrame("BagsBar")
            DodgeFrame("MainMenuBar")
            DodgeFrame("StanceBar")
            DodgeFrame("PetActionBar")
                        local curColRight = right
            local curColY = bottom
            local nextColRight = right
            
            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                local frame = _G["ContainerFrame" .. i]
                if frame and frame.IsShown and frame:IsShown() then
                    local name = frame.GetName and frame:GetName()
                    local pos = name and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                    if pos and pos.x and pos.y then
                        if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                            Offhand.Canvas.RestoreWorkspacePosition(frame)
                        end
                        if frame.SetAlpha then frame:SetAlpha(1) end
                    else
                        pcall(function() frame:SetUserPlaced(false) end)
                        frame:ClearAllPoints()
                        local rawW = frame:GetWidth() or defaultBagWidth
                        local rawH = frame:GetHeight() or defaultBagHeight
                        local factor = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
                        
                        -- Convert physical dimensions to UIParent scale for stacking
                        local uiW = rawW / factor
                        local uiH = rawH / factor
                        
                        -- If adding this bag pushes us above the top of the GAME view monitor (not the spanned void)
                        if curColY + uiH > m.gameTop - 32 then
                            curColRight = nextColRight - bagSpacing
                            curColY = bottom
                        end
                        
                        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", curColRight * factor, curColY * factor)
                        if frame.SetAlpha then frame:SetAlpha(1) end
                        
                        curColY = curColY + uiH + bagSpacing
                        nextColRight = math.min(nextColRight, curColRight - uiW)
                    end
                end
            end

            if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
                local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
                if pos and pos.x and pos.y then
                    if Offhand.Canvas and Offhand.Canvas.RestoreWorkspacePosition then
                        Offhand.Canvas.RestoreWorkspacePosition(ContainerFrameCombinedBags)
                    end
                    if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
                else
                    ContainerFrameCombinedBags:SetUserPlaced(false)
                    ContainerFrameCombinedBags:ClearAllPoints()
                    local factor = UIParent:GetEffectiveScale() / ContainerFrameCombinedBags:GetEffectiveScale()
                    ContainerFrameCombinedBags:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right * factor, bottom * factor)
                    if ContainerFrameCombinedBags.SetAlpha then ContainerFrameCombinedBags:SetAlpha(1) end
                end
            end
        end

        isArrangingBags = false
    end

    -- Legacy clients use the custom bag anchor pass to avoid anchor-family
    -- cycles. Forever keeps Blizzard's function identity to preserve taint safety.
    if _G.UpdateContainerFrameAnchors and not self.anchorsHooked and not UsesForeverEditMode() and not HasBlizzardEditMode() then
        self.anchorsHooked = true
        HUD.origUpdateContainerFrameAnchors = _G.UpdateContainerFrameAnchors
        _G.UpdateContainerFrameAnchors = function(...)
            if HasCustomBagAddon() or not Offhand.db or not Offhand.db.enabled then
                return HUD.origUpdateContainerFrameAnchors(...)
            end
            HUD:LayoutBags()
        end
    end

    -- Forever's native bag frames are protected item-action ancestors. Even an
    -- OnShow observer or a post-toggle layout hook can attribute later
    -- UseContainerItem calls to Offhand, so that client gets no native-bag
    -- hooks at all. Custom bag-addon roots are handled by their own adapters.
    if not Offhand.isForever then
    -- Pre-hook bag OnShow to suppress flicker by setting alpha 0 before positioning
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            frame:HookScript("OnShow", function(self)
                if HasCustomBagAddon() then return end
                if self:GetName() == "ContainerFrame1" and Offhand.Canvas
                    and Offhand.Canvas.PrepareNativeBackpackFrame then
                    Offhand.Canvas:PrepareNativeBackpackFrame(self)
                end
                local name = self:GetName()
                local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
                if not pos then
                    if self.SetAlpha then self:SetAlpha(0) end
                end
                HUD:LayoutBags()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if not HasCustomBagAddon() then
                            HUD:LayoutBags()
                        end
                    end)
                end
            end)
        end
    end
    if ContainerFrameCombinedBags and not hooks[ContainerFrameCombinedBags] then
        hooks[ContainerFrameCombinedBags] = true
        ContainerFrameCombinedBags:HookScript("OnShow", function(self)
            if HasCustomBagAddon() then return end
            if Offhand.Canvas and Offhand.Canvas.PrepareNativeBackpackFrame then
                Offhand.Canvas:PrepareNativeBackpackFrame(self)
            end
            local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ContainerFrameCombinedBags"]
            if not pos then
                if self.SetAlpha then self:SetAlpha(0) end
            end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end)
    end

    if not self.bagHooksInstalled then
        self.bagHooksInstalled = true
        local function TriggerBagLayout()
            if HasCustomBagAddon() then return end
            HUD:LayoutBags()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if not HasCustomBagAddon() then
                        HUD:LayoutBags()
                    end
                end)
            end
        end
        if ContainerFrame_GenerateFrame then
            hooksecurefunc("ContainerFrame_GenerateFrame", TriggerBagLayout)
        end
        if ToggleBag then
            hooksecurefunc("ToggleBag", TriggerBagLayout)
        end
        if ToggleAllBags then
            hooksecurefunc("ToggleAllBags", TriggerBagLayout)
        end
        if OpenAllBags then
            hooksecurefunc("OpenAllBags", TriggerBagLayout)
        end
        if OpenBag then
            hooksecurefunc("OpenBag", TriggerBagLayout)
        end
        if CloseBag then
            hooksecurefunc("CloseBag", TriggerBagLayout)
        end
        if CloseAllBags then
            hooksecurefunc("CloseAllBags", TriggerBagLayout)
        end
    end
    end
    for i = 1, 4 do
        local frame = _G["StaticPopup" .. i]
        if frame and not hooks[frame] then
            hooks[frame] = true
            local index = i
            frame:HookScript("OnShow", function(self)
                if InCombatLockdown() or not Offhand.db.enabled or not Offhand.db.seamRedirect then return end
                local m = Offhand.Viewport:GetMetrics()
                Prepare(self, m)
                NormalizeMainhandTransientScale(self)
                Anchor(self, "CENTER", m, 0, (index - 1) * 120)
                if C_Timer and C_Timer.After then
                    for _, delay in ipairs({0, 0.05, 0.2}) do
                        C_Timer.After(delay, function() HUD:PositionMainhandTransientFrames() end)
                    end
                end
            end)
        end
    end
end

function HUD:GatherLostFrames()
    return Offhand:GatherOffScreenUI()
end

function Offhand:InitializeSeamRedirect()
    HUD:HookFrames()
end
function Offhand:UpdateSeamRedirect()
    HUD:HookFrames()
    HUD:AlignHUDFrames()
end





