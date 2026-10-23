-- Panel placement measurement and Social/Communities anchor ownership.
local _, Offhand = ...
local Placement = {}
Offhand.CanvasPanelPlacement = Placement

function Placement.Install(Canvas, services)
    local WithWorkspace = services.WithWorkspace
    local IsForeverSocialPositionRoot = services.IsForeverSocialPositionRoot
    local IsUnsafeForPanelMutation = services.IsUnsafeForPanelMutation
    local NotePanelControllerActivity = services.NotePanelControllerActivity
    local RestoreWorkspacePosition = services.RestoreWorkspacePosition
    local IsPanelDragging = Offhand.CanvasFrameState.IsDragging
    local GetPanelPhysicalPlacement, PlacementMatchesPosition
    local socialMainhandSessionPositions = setmetatable({}, { __mode = "k" })
    local socialAnchorRepairState = setmetatable({}, { __mode = "k" })

    GetPanelPhysicalPlacement = function(frame)
        if not frame then return nil end
        local ok, placement = pcall(function()
            local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
            if not metrics or not metrics.isSpanned then return nil end
            local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            if frameScale <= 0 or parentScale <= 0 then return nil end
            local factor = frameScale / parentScale
            local width = ((frame.GetWidth and frame:GetWidth()) or 0) * factor
            local height = ((frame.GetHeight and frame:GetHeight()) or 0) * factor
            local left = frame.GetLeft and frame:GetLeft()
            local top = frame.GetTop and frame:GetTop()
            local centerX, centerY
            if frame.GetCenter then centerX, centerY = frame:GetCenter() end
            if left then left = left * factor end
            if top then top = top * factor end
            if centerX then centerX = centerX * factor end
            if centerY then centerY = centerY * factor end
            if not centerX and left and width > 0 then centerX = left + width / 2 end
            if not centerY and top and height > 0 then centerY = top - height / 2 end
            if not left and centerX and width > 0 then left = centerX - width / 2 end
            if not top and centerY and height > 0 then top = centerY + height / 2 end
            if not centerX or not centerY then return nil end
            return {
                x = left,
                y = top,
                onWorkspace = centerX >= metrics.workspaceLeft
                    and centerX <= metrics.workspaceRight
                    and centerY >= metrics.workspaceBottom
                    and centerY <= metrics.workspaceTop,
            }
        end)
        return ok and placement or nil
    end

    PlacementMatchesPosition = function(placement, position)
        return placement and position and position.x and position.y
            and math.abs(placement.x - position.x) < 0.5
            and math.abs(placement.y - position.y) < 0.5
    end

    local function RepairShownSocialPanel(frame, suppliedName)
        if not frame or not frame.IsShown or not frame:IsShown()
            or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return false end
        local name = (frame.GetName and frame:GetName()) or suppliedName
        if not name then return false end
        local positionOnlyRoot = IsForeverSocialPositionRoot(frame, name)
            or IsForeverSocialPositionRoot(frame, suppliedName)
        if not positionOnlyRoot and IsUnsafeForPanelMutation(frame, name) then return false end

        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.repairing then return false end

        local workspacePosition = Offhand.db.savedWorkspacePositions
            and (Offhand.db.savedWorkspacePositions[name]
                or (suppliedName and Offhand.db.savedWorkspacePositions[suppliedName]))
        local mainPosition = Offhand.db.savedMainPositions
            and (Offhand.db.savedMainPositions[name]
                or (suppliedName and Offhand.db.savedMainPositions[suppliedName]))
        local placement = GetPanelPhysicalPlacement(frame)
        state.repairing = true
        if workspacePosition or mainPosition then
            local savedPosition = workspacePosition or mainPosition
            if not PlacementMatchesPosition(placement, savedPosition) then
                NotePanelControllerActivity(name, "forever-social-community", "saved-repair")
                RestoreWorkspacePosition(frame)
            end
        else
            local sessionPosition = socialMainhandSessionPositions[frame]
            if sessionPosition then
                if not PlacementMatchesPosition(placement, sessionPosition) then
                    NotePanelControllerActivity(name, "forever-social-community", "session-repair")
                    Canvas:PlacePanelOnMainhand(frame, nil,
                        sessionPosition, false, true)
                end
            elseif placement and not placement.onWorkspace and placement.x and placement.y then
                -- Capture the panel's native Mainhand anchor before another member
                -- of Blizzard's shared UIPanel stack recalculates it.
                socialMainhandSessionPositions[frame] = {
                    x = placement.x,
                    y = placement.y,
                }
            elseif placement and placement.onWorkspace then
                -- An unsaved Friends frame has no intentional Offhand ownership.
                -- Restore the last native Mainhand anchor, or center it safely when
                -- this session first discovered the frame after displacement.
                NotePanelControllerActivity(name, "forever-social-community", "mainhand-rescue")
                Canvas:PlacePanelOnMainhand(frame, nil,
                    socialMainhandSessionPositions[frame], false, true)
                local restored = GetPanelPhysicalPlacement(frame)
                if restored and not restored.onWorkspace and restored.x and restored.y then
                    socialMainhandSessionPositions[frame] = {
                        x = restored.x,
                        y = restored.y,
                    }
                end
            end
        end
        state.repairing = nil
        return true
    end

    local function HookSocialPanelAnchorResets(frame, suppliedName)
        if not frame or not hooksecurefunc then return false end
        local state = socialAnchorRepairState[frame]
        if not state then
            state = {}
            socialAnchorRepairState[frame] = state
        end
        if state.hooked then return true end
        state.hooked = true
        hooksecurefunc(frame, "SetPoint", function()
            if state.repairing or IsPanelDragging(frame) or not Offhand.db
                or not Offhand.db.enabled or not frame.IsShown or not frame:IsShown() then return end
            state.generation = (state.generation or 0) + 1
            local generation = state.generation
            -- Root SetPoint hooks run after Blizzard's write but before the next
            -- render. Repair immediately so the native intermediate anchor is not
            -- visible, then retain one bounded next-frame pass for layout work that
            -- continues asynchronously.
            RepairShownSocialPanel(frame, suppliedName)
            local function RepairAfterNativeLayout()
                if generation ~= state.generation or state.repairing
                    or not frame.IsShown or not frame:IsShown() then return end
                RepairShownSocialPanel(frame, suppliedName)
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, RepairAfterNativeLayout)
            else
                RepairAfterNativeLayout()
            end
        end)
        return true
    end

    function Canvas:RepairShownSocialCommunityPanels()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        local repaired = setmetatable({}, { __mode = "k" })
        local names = {
            "FriendsFrame", "FriendsListFrame", "SocialFrame", "SocialUIFrame",
            "CommunitiesFrame",
        }
        for _, name in ipairs(names) do
            local frame = _G[name]
            if frame and not repaired[frame] and frame.IsShown and frame:IsShown() then
                repaired[frame] = true
                HookSocialPanelAnchorResets(frame, name)
                RepairShownSocialPanel(frame, name)
            end
        end
    end
    return GetPanelPhysicalPlacement, PlacementMatchesPosition, HookSocialPanelAnchorResets
end

