--[[
    Offhand: Multi-Monitor Setup Addon
    Core/Mainhand.lua: Safe frame gathering and Mainhand event coordination
--]]

local _, Offhand = ...

local Mainhand = assert(Offhand.Mainhand, "Offhand Mainhand geometry must load before Mainhand")
local Geometry = assert(
    Offhand.MainhandGeometry,
    "Offhand Mainhand geometry must load before Mainhand"
)
local IsPlayerCombatRestricted = Geometry.IsPlayerCombatRestricted
local CurrentRect = Geometry.GetCurrentRect

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
