--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/PanelMotion.lua: narrowly scoped title-gesture support for panels

    This module is an original Offhand implementation built around Blizzard's
    public PanelDragBarTemplate. It does not contain or depend on third-party
    frame-movement addon code.
--]]

local _, Offhand = ...

local PanelMotion = {
    records = setmetatable({}, { __mode = "k" }),
}
Offhand.PanelMotion = PanelMotion

local function IsInCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsUsableFrame(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
end

local function SetGripShown(grip, shown)
    if not grip then return end
    if grip.EnableMouse then grip:EnableMouse(shown == true) end
    if shown then
        if grip.Show then grip:Show() end
    elseif grip.Hide then
        grip:Hide()
    end
end

local function ConfigureCombatVisibility(grip)
    if not RegisterStateDriver then return false end
    local ok = pcall(RegisterStateDriver, grip, "visibility", "[combat] hide; show")
    return ok == true
end

function PanelMotion:GetStatus(frame)
    local record = self.records[frame]
    if not record then return "not_attached" end
    return record.status or (record.active and "active" or "inactive")
end

function PanelMotion:GetDiagnostics()
    local entries = {}
    for frame, record in pairs(self.records) do
        local name = frame and frame.GetName and frame:GetName() or "unnamed"
        local protected = frame and frame.IsProtected and frame:IsProtected() and "1" or "0"
        entries[#entries + 1] = string.format("%s:%s/protected=%s",
            tostring(name), tostring(record.status or "unknown"), protected)
    end
    table.sort(entries)
    return string.format("Attached=%d | Frames=%s", #entries,
        #entries > 0 and table.concat(entries, ",") or "none")
end

function PanelMotion:SetTitleGripActive(frame, active)
    local record = self.records[frame]
    if not record then return false, "not_attached" end
    if IsInCombat() then
        record.status = "combat_deferred"
        return false, record.status
    end

    if active == true then
        if not record.combatVisibility then
            record.combatVisibility = ConfigureCombatVisibility(record.grip)
        end
        if not record.combatVisibility then
            record.active = false
            record.status = "combat_guard_unavailable"
            SetGripShown(record.grip, false)
            return false, record.status
        end
    elseif record.combatVisibility and UnregisterStateDriver then
        pcall(UnregisterStateDriver, record.grip, "visibility")
        record.combatVisibility = false
    end

    record.active = active == true
    record.status = record.active and "active" or "inactive"
    SetGripShown(record.grip, record.active)
    return true, record.status
end

function PanelMotion:AttachGuardedTitleGrip(frame, options)
    options = options or {}
    if not IsUsableFrame(frame) then return nil, "invalid_frame" end
    if IsInCombat() then return nil, "combat_deferred" end

    local existing = self.records[frame]
    if existing then
        existing.options = options
        self:SetTitleGripActive(frame, true)
        return existing.grip, existing.status
    end

    if type(CreateFrame) ~= "function" then return nil, "template_unavailable" end

    local created, grip = pcall(CreateFrame, "Frame", nil, frame, "PanelDragBarTemplate")
    if not created or not grip then return nil, "template_unavailable" end

    local anchor = options.anchorFrame
    if not IsUsableFrame(anchor) then anchor = frame end
    local leftInset = tonumber(options.leftInset) or 10
    local rightInset = tonumber(options.rightInset) or 36
    local height = tonumber(options.height) or 32

    grip:ClearAllPoints()
    grip:SetPoint("TOPLEFT", anchor, "TOPLEFT", leftInset, 0)
    grip:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -rightInset, 0)
    grip:SetHeight(height)

    if grip.SetFrameLevel then
        local panelLevel = frame.GetFrameLevel and frame:GetFrameLevel() or 1
        local anchorLevel = anchor.GetFrameLevel and anchor:GetFrameLevel() or panelLevel
        grip:SetFrameLevel(math.max(panelLevel, anchorLevel) + 1)
    end

    local combatVisibility = ConfigureCombatVisibility(grip)
    if not combatVisibility then
        SetGripShown(grip, false)
        return nil, "combat_guard_unavailable"
    end

    -- Establish the secure combat guard before changing the Blizzard panel's
    -- movable state. A missing template/driver therefore leaves the target
    -- untouched instead of producing a half-configured movable frame.
    local movableOK = pcall(frame.SetMovable, frame, true)
    if not movableOK or (frame.IsMovable and not frame:IsMovable()) then
        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, grip, "visibility")
        end
        SetGripShown(grip, false)
        return nil, "frame_not_movable"
    end
    if options.allowOffscreen ~= false and frame.SetClampedToScreen then
        pcall(frame.SetClampedToScreen, frame, false)
    end

    local record = {
        active = true,
        combatVisibility = combatVisibility,
        grip = grip,
        options = options,
        status = "active",
    }
    self.records[frame] = record

    -- Preserve the Blizzard template's native drag scripts. Offhand observes
    -- the gesture only to record the resulting placement.
    if grip.HookScript then
        grip:HookScript("OnDragStart", function()
            local current = PanelMotion.records[frame]
            if not current or not current.active or IsInCombat() then return end
            local callback = current.options and current.options.onBegin
            if callback then callback(frame, grip) end
        end)
        grip:HookScript("OnDragStop", function()
            local current = PanelMotion.records[frame]
            if not current or not current.active then return end
            local callback = current.options and current.options.onFinish
            if callback then callback(frame, grip) end
        end)
    end

    SetGripShown(grip, true)
    return grip, record.status
end
