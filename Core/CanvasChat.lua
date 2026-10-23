-- Blizzard chat dock ownership and detached-window presentation.
local _, Offhand = ...
local Chat = {}
Offhand.CanvasChat = Chat

function Chat.Install(Canvas)
    local function HasChattynator()
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            return C_AddOns.IsAddOnLoaded("Chattynator")
        elseif IsAddOnLoaded then
            return IsAddOnLoaded("Chattynator")
        end
        return false
    end

    local function IsSecondaryBlizzardChatFrame(frame, suppliedName)
        local name = suppliedName or (frame and frame.GetName and frame:GetName())
        local index = name and tonumber(name:match("^ChatFrame(%d+)$"))
        return index and index > 1 or false
    end

    -- Forever rebuilds its native multi-frame chat dock after Offhand's generic
    -- panel restoration can begin. Never let those generic paths show, resize or
    -- reanchor a secondary Blizzard chat frame from a stale workspace record.
    -- Only the tracked-chat path may continue after dock settlement has positively
    -- identified a detached window.
    function Canvas:ShouldRouteForeverSecondaryChatRestore(frame, suppliedName)
        if not Offhand.isForever or not frame
            or frame._OffhandApplyingTrackedChatPosition then return false end
        return IsSecondaryBlizzardChatFrame(frame, suppliedName)
    end

    local function IsForeverCombatLog(frame, suppliedName)
        local name = suppliedName or (frame and frame.GetName and frame:GetName())
        return Offhand.isForever and name == "ChatFrame2"
    end

    local function IsChatTabAttachedToDock(frame)
        local dock = GENERAL_CHAT_DOCK or GeneralDockManager
        local name = frame and frame.GetName and frame:GetName()
        local tab = name and _G[name .. "Tab"]
        if not dock or not tab or type(tab.GetParent) ~= "function" then return false end
        local ok, parent = pcall(tab.GetParent, tab)
        if not ok or not parent then return false end
        if parent == dock then return true end
        if type(parent.GetParent) ~= "function" then return false end
        local parentOK, grandparent = pcall(parent.GetParent, parent)
        return parentOK and grandparent == dock or false
    end

    local function GetBlizzardChatDockMembership(frame)
        local dock = GENERAL_CHAT_DOCK or GeneralDockManager
        if not dock or type(dock.DOCKED_CHAT_FRAMES) ~= "table" then return nil end
        for _, dockedFrame in pairs(dock.DOCKED_CHAT_FRAMES) do
            if dockedFrame == frame then return true end
        end
        -- During Forever's multi-frame dock rebuild the membership array can lag
        -- behind the visible native tab hierarchy. A tab already parented to the
        -- dock (or its scroll child) is positive ownership evidence and must win.
        if IsChatTabAttachedToDock(frame) then return true end
        return false
    end

    local function IsBlizzardChatFrameDocked(frame, suppliedName)
        if not IsSecondaryBlizzardChatFrame(frame, suppliedName) then return false end
        -- Forever can leave isDocked/isStaticDocked set after a chat tab has been
        -- pulled out of the primary dock.  The dock manager's membership table is
        -- the current topology and must win over those stale compatibility fields.
        local membership = GetBlizzardChatDockMembership(frame)
        if membership ~= nil then return membership end
        if FCF_IsDocked then
            local ok, docked = pcall(FCF_IsDocked, frame)
            if ok and docked then return true end
        end
        if frame.isDocked == true or frame.isDocked == 1
            or frame.isStaticDocked == true then return true end
        return false
    end

    local ClearTrackedChatState

    -- Forever rebuilds the chat dock over several frames during login, reload and
    -- Edit Mode transitions. A single absent DOCKED_CHAT_FRAMES entry is therefore
    -- not proof that a secondary chat window is detached. Require two separated
    -- observations before Offhand restores a floating window; a positive dock
    -- observation wins immediately and ambiguous transitions are left to Blizzard.
    local function QueueForeverChatDockSettlement(frame, purpose, callback)
        if not Offhand.isForever or not frame or type(callback) ~= "function"
            or not C_Timer or not C_Timer.After then return false end

        Canvas._foreverChatDockSettlements = Canvas._foreverChatDockSettlements
            or setmetatable({}, {__mode = "k"})
        local frameState = Canvas._foreverChatDockSettlements[frame]
        if not frameState then
            frameState = {}
            Canvas._foreverChatDockSettlements[frame] = frameState
        end
        if frameState[purpose] then return true end

        local state = { first = nil }
        frameState[purpose] = state
        C_Timer.After(0.25, function()
            if frameState[purpose] ~= state then return end
            state.first = GetBlizzardChatDockMembership(frame)
        end)
        C_Timer.After(1.00, function()
            if frameState[purpose] ~= state then return end
            frameState[purpose] = nil
            local second = GetBlizzardChatDockMembership(frame)
            if second == true then
                callback(true)
            elseif state.first == false and second == false then
                callback(false)
            else
                callback(nil)
            end
        end)
        return true
    end

    local function RefreshDetachedChatPresentation(frame, suppliedName)
        local name = suppliedName or (frame and frame.GetName and frame:GetName())
        if not IsSecondaryBlizzardChatFrame(frame, name) or HasChattynator()
            or IsForeverCombatLog(frame, name)
            or GetBlizzardChatDockMembership(frame) ~= false
            or frame._OffhandRefreshingChatPresentation then return false end

        -- Forever can remove a tab from DOCKED_CHAT_FRAMES without completing the
        -- visual part of its floating-window transition. Do not call
        -- FCF_UnDockFrame here: built-in windows such as Combat Log can be saved as
        -- hidden while docked, and running that transition before repairing the
        -- shown bit makes Blizzard hide them. Commit shown first, then the detached
        -- saved state, and normalize only the stale runtime isDocked flag.
        -- Do this even when the legacy flags are already nil: the reverted
        -- undock-based beta cleared them before a later native update hid custom
        -- windows, and those windows need the same non-destructive recovery.
        frame._OffhandRefreshingChatPresentation = true
        local id = frame.GetID and frame:GetID() or tonumber(name:match("(%d+)$"))
        if id and SetChatWindowShown then pcall(SetChatWindowShown, id, true) end
        if id and SetChatWindowDocked then pcall(SetChatWindowDocked, id, false) end
        frame.isDocked = nil
        local wasLocked = frame.isLocked
        if wasLocked ~= nil and FCF_SetLocked then
            pcall(FCF_SetLocked, frame, wasLocked)
        end

        -- A docked frame may have every CHAT_FRAME_TEXTURES entry faded to
        -- zero. Reapply the player's own saved background color and opacity through
        -- Blizzard's setters so its floating border/background becomes visible
        -- without Offhand inventing or persisting presentation values.
        if id and FCF_GetChatWindowInfo then
            local ok, _, _, r, g, b, alpha = pcall(FCF_GetChatWindowInfo, id)
            if ok and type(r) == "number" and type(g) == "number" and type(b) == "number"
                and FCF_SetWindowColor then
                pcall(FCF_SetWindowColor, frame, r, g, b, true)
            end
            if ok and type(alpha) == "number" and FCF_SetWindowAlpha then
                pcall(FCF_SetWindowAlpha, frame, alpha, true)
            end
        end
        -- A tracked detached window is expected to remain visible. Repair the
        -- shown bit damaged by the previous undock-based implementation and use
        -- Blizzard's normal visibility helper for both message frame and tab.
        local tab = _G[name .. "Tab"]
        if FCF_CheckShowChatFrame then
            pcall(FCF_CheckShowChatFrame, frame)
        else
            if frame.Show then pcall(frame.Show, frame) end
        end
        -- FCF_CheckShowChatFrame expects the scrolling message frame, not its tab.
        -- Forever can leave the tab hidden even after the saved shown bit is fixed.
        if tab and tab.Show then pcall(tab.Show, tab) end
        if FCF_FadeInChatFrame then pcall(FCF_FadeInChatFrame, frame) end
        frame._OffhandRefreshingChatPresentation = nil
        return true
    end

    -- Earlier Beta 21 recovery could mistake an inactive Combat Log for a lost
    -- detached window, show ChatFrame2 over General and persist docked=false. Never
    -- synthesize visibility for the built-in Combat Log. When Blizzard's settled
    -- dock positively owns it, return saved docking and visibility entirely to
    -- Blizzard and remove only Offhand's stale position record.
    function Canvas:ReconcileForeverCombatLogOwnership()
        if not Offhand.isForever or HasChattynator() or not Offhand.db
            or not Offhand.db.enabled then return false end
        local frame = _G.ChatFrame2
        if not frame then return false end

        local function reconcile(isDocked)
            if not Offhand.isForever or not Offhand.db or not Offhand.db.enabled
                or isDocked ~= true then return end

            local nativeDocked
            if FCF_GetChatWindowInfo then
                local values = {pcall(FCF_GetChatWindowInfo, 2)}
                if values[1] then nativeDocked = values[10] end
            end
            local compatibility = type(OffhandDB) == "table" and OffhandDB.compatibility
            local unsafeRecoveryRan = type(compatibility) == "table"
                and (tonumber(compatibility.detachedCombatLogRecoveryVersion) or 0) >= 1
            -- A native false value can also describe a genuinely detached Combat
            -- Log passing through Forever's startup dock. Repair it only when the
            -- removed unsafe migration records that it previously took ownership,
            -- and the tab hierarchy independently confirms the current native dock.
            if nativeDocked == false then
                if not unsafeRecoveryRan or not IsChatTabAttachedToDock(frame) then return end
                if SetChatWindowDocked then pcall(SetChatWindowDocked, 2, true) end
                compatibility.detachedCombatLogRecoveryVersion = nil
                compatibility.combatLogOwnershipRepairVersion = 1
            elseif nativeDocked ~= true then
                return
            end

            ClearTrackedChatState("ChatFrame2")

            local dock = GENERAL_CHAT_DOCK or GeneralDockManager
            local selected
            if dock and FCFDock_GetSelectedWindow then
                local ok, value = pcall(FCFDock_GetSelectedWindow, dock)
                if ok then selected = value end
            end
            if selected and selected ~= frame and frame.IsShown and frame:IsShown()
                and frame.Hide then
                pcall(frame.Hide, frame)
            end
        end

        -- Positive dock evidence is authoritative and can be handed back before
        -- the first rendered frame. Only an apparent absence needs settlement.
        if GetBlizzardChatDockMembership(frame) == true then
            reconcile(true)
            return true
        end
        return QueueForeverChatDockSettlement(frame, "combat-log-ownership", reconcile)
    end

    local function QueueDetachedChatPresentationRefresh(frame)
        if not frame or frame._OffhandChatAppearanceRefreshPending
            or frame._OffhandRefreshingChatPresentation or HasChattynator()
            or not Offhand.db or not Offhand.db.enabled then return end
        local name = frame.GetName and frame:GetName()
        if not IsSecondaryBlizzardChatFrame(frame, name)
            or IsForeverCombatLog(frame, name)
            or GetBlizzardChatDockMembership(frame) ~= false then return end
        local tracked = (Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name])
            or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name])
        if not tracked then return end

        local function refresh(finalPass)
            if not frame._OffhandRefreshingChatPresentation then
                RefreshDetachedChatPresentation(frame, name)
            end
            if finalPass then frame._OffhandChatAppearanceRefreshPending = nil end
        end
        frame._OffhandChatAppearanceRefreshPending = true
        if C_Timer and C_Timer.After then
            -- Forever's chat Settings flow performs another dock-oriented fade
            -- after the color/opacity setters return. The next-frame replay keeps
            -- ordinary picker changes responsive; the bounded settlement pass
            -- restores the final saved values after that later native fade.
            C_Timer.After(0, function() refresh(false) end)
            C_Timer.After(0.20, function() refresh(true) end)
        else
            refresh(true)
        end
    end

    -- Forever's Chat Settings panel can fade floating chat chrome without routing
    -- that work through FCF_SetWindowColor/FCF_SetWindowAlpha. Observe the panel
    -- from Offhand's own ticker instead of hooking the Blizzard panel into our call
    -- chain, then replay only the saved presentation of tracked detached windows.
    function Canvas:MonitorDetachedChatSettingsPresentation()
        if HasChattynator() or not Offhand.db or not Offhand.db.enabled then return end
        local settingsShown = ChatConfigFrame and ChatConfigFrame.IsShown
            and ChatConfigFrame:IsShown() or false
        local transitioned = settingsShown ~= self._detachedChatSettingsWasShown
        self._detachedChatSettingsWasShown = settingsShown
        if not transitioned and not settingsShown then return end

        for i = 2, (NUM_CHAT_WINDOWS or 10) do
            local frame = _G["ChatFrame" .. i]
            local name = frame and frame.GetName and frame:GetName()
            local tracked = name and ((Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name])
                or (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]))
            if tracked and GetBlizzardChatDockMembership(frame) == false then
                QueueDetachedChatPresentationRefresh(frame)
            end
        end
    end

    ClearTrackedChatState = function(name)
        if not name or not Offhand.db then return false end
        local cleared = false
        for _, key in ipairs({"savedWorkspacePositions", "savedMainPositions", "openWorkspacePanels"}) do
            local records = Offhand.db[key]
            if records and records[name] ~= nil then
                records[name] = nil
                cleared = true
            end
        end
        if Offhand.ForeverPersistence and Offhand.ForeverPersistence.ClearPosition then
            Offhand.ForeverPersistence:ClearPosition(name)
        end
        return cleared
    end

    local function RelinquishDockedChatPosition(frame, suppliedName)
        local name = suppliedName or (frame and frame.GetName and frame:GetName())
        if not name or not IsBlizzardChatFrameDocked(frame, name) then return false end
        ClearTrackedChatState(name)

        -- Chattynator reparents the native Combat Log (ChatFrame2), anchors it on
        -- two sides inside its custom holder, and hides Blizzard's chrome. Never
        -- resize or reanchor that borrowed native frame.
        if HasChattynator() then return true end

        local dock = GENERAL_CHAT_DOCK or GeneralDockManager
        local primary = dock and dock.primary or _G.ChatFrame1
        if primary and primary ~= frame and primary.GetWidth and primary.GetHeight
            and frame.SetSize then
            local width, height = primary:GetWidth(), primary:GetHeight()
            local currentWidth = frame.GetWidth and frame:GetWidth()
            local currentHeight = frame.GetHeight and frame:GetHeight()
            if width and width > 0 and height and height > 0
                and (not currentWidth or not currentHeight
                    or math.abs(currentWidth - width) > 0.001
                    or math.abs(currentHeight - height) > 0.001) then
                pcall(frame.SetSize, frame, width, height)
            end
        end
        if primary and primary ~= frame and primary.GetFont and FCF_SetChatWindowFontSize then
            local _, fontSize = primary:GetFont()
            if type(fontSize) == "number" and fontSize > 0 then
                pcall(FCF_SetChatWindowFontSize, nil, frame, fontSize)
            end
        end
        return true
    end

    -- Chattynator deliberately reuses Blizzard's primary edit box while anchoring
    -- it to an unnamed Chattynator window.  Reattaching that edit box to the hidden
    -- ChatFrame1 makes Enter focus a valid but invisible input field.
    local function ShouldManageBlizzardChatEditBox(frame)
        return frame == ChatFrame1 and not HasChattynator()
    end

    return {
        HasChattynator = HasChattynator,
        IsSecondaryBlizzardChatFrame = IsSecondaryBlizzardChatFrame,
        IsForeverCombatLog = IsForeverCombatLog,
        GetBlizzardChatDockMembership = GetBlizzardChatDockMembership,
        IsBlizzardChatFrameDocked = IsBlizzardChatFrameDocked,
        QueueForeverChatDockSettlement = QueueForeverChatDockSettlement,
        RefreshDetachedChatPresentation = RefreshDetachedChatPresentation,
        QueueDetachedChatPresentationRefresh = QueueDetachedChatPresentationRefresh,
        ClearTrackedChatState = ClearTrackedChatState,
        RelinquishDockedChatPosition = RelinquishDockedChatPosition,
        ShouldManageBlizzardChatEditBox = ShouldManageBlizzardChatEditBox,
    }
end

