-- Explicit missing-only recovery. Never infer that a dormant HUD is broken.
local _, Offhand = ...
local Recovery = {}
Offhand.Recovery = Recovery

function Recovery.Inspect(frame, metrics)
    local ok, status = pcall(function()
        if not frame then return "absent" end
        if frame == UIParent or frame == WorldFrame or frame == Offhand.canvas then return "unsupported" end
        if frame.IsForbidden and frame:IsForbidden() then return "forbidden" end
        if frame.IsObjectType and frame:IsObjectType("GameTooltip") then return "unsupported" end
        if not frame.IsShown or not frame:IsShown() then return "hidden" end
        if frame.IsVisible and not frame:IsVisible() then return "parent-hidden" end
        if frame.GetEffectiveAlpha and frame:GetEffectiveAlpha() <= 0 then return "unavailable" end
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        local left, bottom = frame:GetLeft(), frame:GetBottom()
        local width, height = frame:GetWidth(), frame:GetHeight()
        if not left or not bottom or not width or not height or width <= 0 or height <= 0 then return "missing" end
        left, bottom, width, height = left * scale, bottom * scale, width * scale, height * scale
        local function Overlap(l, b, r, t)
            return l and b and r and t and left < r and left + width > l
                and bottom < t and bottom + height > b
        end
        -- Any visible portion counts. This action must leave a partially clipped
        -- window in place too, rather than treating it as a layout-reset request.
        return (Overlap(metrics.gameLeft, metrics.gameBottom, metrics.gameRight, metrics.gameTop)
            or Overlap(metrics.workspaceLeft, metrics.workspaceBottom, metrics.workspaceRight, metrics.workspaceTop))
            and "visible" or "missing"
    end)
    return ok and status or "unavailable"
end

function Recovery:Run()
    if InCombatLockdown() then return false, "combat" end
    if not Offhand.db or not Offhand.db.enabled then return false, "disabled" end
    local metrics = Offhand.Viewport and Offhand.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned then return false, "span" end
    local manager = _G.EditModeManagerFrame
    if manager and ((manager.IsShown and manager:IsShown()) or manager.editModeActive) then
        return false, "open"
    end
    local canvas = Offhand.Canvas
    if not canvas or not canvas.GatherSafeUIToMainhand then return false, "unavailable" end
    local ok, why, moved, skipped = canvas:GatherSafeUIToMainhand(true)
    if not ok then return false, why end
    local requests = {}
    local compatibility = Offhand.HUDCompatibility
    local mainhand = Offhand.Mainhand
    local systems = Enum and Enum.EditModeSystem
    local units = Enum and Enum.EditModeUnitFrameSystemIndices
    local actions = Enum and Enum.EditModeActionBarSystemIndices
    -- Native controller and replacement HUDs retain ownership of their systems.
    if systems and mainhand and mainhand.CreateOrUpdateEditModeLayout
        and not _G.ConsolePort and not _G.ElvUI and not _G.Tukui
        and not (mainhand.IsControllerLayout and mainhand:IsControllerLayout())
        and not (_G.MoveAny or _G.MoveAnything) then
        local function Add(name, system, index, needsIndex, x, y, expected)
            if system == nil or (needsIndex and index == nil) then return end
            local state = Recovery.Inspect(_G[name], metrics)
            if state ~= "missing" and not (state == "hidden" and expected) then return end
            local sized, width, frameHeight, factor = pcall(function()
                local frame = _G[name]
                local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                return frame:GetWidth() * scale, frame:GetHeight() * scale, scale
            end)
            if not sized or width <= 0 or frameHeight <= 0 or factor <= 0
                or width + 24 > metrics.gameRight - metrics.gameLeft
                or frameHeight + 24 > metrics.gameTop - metrics.gameBottom then return end
            x = math.max(metrics.gameLeft + width / 2 + 12, math.min(metrics.gameRight - width / 2 - 12, x))
            y = math.max(metrics.gameBottom + 12, math.min(metrics.gameTop - frameHeight - 12, y))
            requests[#requests + 1] = {system=system, systemIndex=index,
                anchorInfo={point="BOTTOM", relativeTo="UIParent", relativePoint="BOTTOMLEFT",
                    offsetX=x/factor, offsetY=y/factor}}
        end
        local center = (metrics.gameLeft + metrics.gameRight) / 2
        local height = metrics.gameTop - metrics.gameBottom
        local extraAvailable = false
        if C_ActionBar and type(C_ActionBar.HasExtraActionBar) == "function" then
            local read, value = pcall(C_ActionBar.HasExtraActionBar)
            extraAvailable = read and value == true
        end
        Add("ExtraAbilityContainer", systems.ExtraAbilities or systems.ExtraAbility, nil, false,
            center, metrics.gameBottom + math.min(180, height * .25), extraAvailable)
        Add("MinimapCluster", systems.Minimap, nil, false,
            metrics.gameRight - 160, metrics.gameTop - 300)
        Add("ObjectiveTrackerFrame", systems.ObjectiveTracker, nil, false,
            metrics.gameRight - 180, metrics.gameBottom + 80)
        Add("PlayerFrame", systems.UnitFrame, units and units.Player, true,
            metrics.gameLeft + 180, metrics.gameTop - 180)
        if not (compatibility and compatibility.HasEllesmerePartyFrames and compatibility.HasEllesmerePartyFrames()) then
            Add("PartyFrame", systems.UnitFrame, units and units.Party, true,
                metrics.gameLeft + 180, metrics.gameTop - 500)
            Add("CompactRaidFrameContainer", systems.UnitFrame, units and units.Raid, true,
                metrics.gameLeft + 300, metrics.gameBottom + 160)
        end
        if not (compatibility and compatibility.HasCustomActionBarAddon and compatibility.HasCustomActionBarAddon()) then
            Add("MainActionBar", systems.ActionBar, actions and actions.MainBar, true,
                center, metrics.gameBottom + 32)
        end
    end
    if #requests > 0 then
        local saved, value, count, activation = mainhand:CreateOrUpdateEditModeLayout({repairSystems=requests})
        if not saved then return false, value, moved, skipped end
        return true, nil, moved, skipped, count, activation, value
    end
    return true, nil, moved, skipped, 0
end
