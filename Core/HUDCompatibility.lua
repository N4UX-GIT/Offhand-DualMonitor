--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/HUDCompatibility.lua: HUD ownership and client capability policy
--]]

local _, Offhand = ...

local Compatibility = {}
Offhand.HUDCompatibility = Compatibility

local foreverEditModeFrameNames = {
    MainMenuBar = true, MainActionBar = true, StatusTrackingBarManager = true, MainMenuExpBar = true,
    MultiBarBottomLeft = true, MultiBarBottomRight = true, MultiBarLeft = true, MultiBarRight = true,
    StanceBar = true, PetActionBar = true, PossessActionBar = true,
    MinimapCluster = true, PlayerFrame = true, TargetFrame = true, FocusFrame = true, PetFrame = true,
    BossTargetFrameContainer = true,
    PartyFrame = true, PartyMemberFrame1 = true, CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    BuffFrame = true, BuffCluster = true, CastingBarFrame = true, PlayerCastingBarFrame = true,
    ExtraAbilityContainer = true, ExtraActionBarFrame = true, ZoneAbilityFrame = true,
    EncounterBar = true, UIWidgetPowerBarContainerFrame = true, LossOfControlFrame = true,
    MainMenuBarVehicleLeaveButton = true, VehicleExitButton = true,
    TotemFrame = true, MultiCastActionBarFrame = true, PersonalResourceDisplayFrame = true,
    DurabilityFrame = true, DamageMeter = true,
    UIErrorsFrame = true, RaidWarningFrame = true,
    EssentialCooldownViewer = true, UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true, BottomManagedFrameContainer = true,
}

function Compatibility.IsAddonPresent(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded(name) then return true end
    elseif IsAddOnLoaded then
        if IsAddOnLoaded(name) then return true end
    end
    if _G and _G[name] ~= nil then return true end
    return false
end

function Compatibility.HasCustomActionBarAddon()
    if _G.Bartender4 or _G.Dominos or _G.ElvUI or _G.Tukui or _G.ConsolePort then return true end
    if Compatibility.IsAddonPresent("EllesmereUIActionBars") then return true end
    local main = _G.MainMenuBar or _G.MainActionBar
    return not main
end

function Compatibility.HasCustomStatusBarAddon()
    if _G.Bartender4 or _G.Dominos or _G.ElvUI or _G.Tukui or _G.ConsolePort then return true end
    if not Compatibility.IsAddonPresent("EllesmereUIActionBars") then return false end
    -- DataBars is a separate information-panel module, not the native XP/Rep
    -- replacement. ActionBars owns that replacement unless the player opts back
    -- into Blizzard's bars. Read its cross-addon accessor without changing state.
    local lite = _G.EllesmereUI and _G.EllesmereUI.Lite
    if lite and type(lite.GetAddon) == "function" then
        local ok, addon = pcall(lite.GetAddon, "EllesmereUIActionBars", true)
        local profile = ok and addon and addon.db and addon.db.profile
        if profile and profile.useBlizzardDataBars == true then return false end
    end
    return true
end

function Compatibility.HasCustomBagAddon()
    if Compatibility.IsAddonPresent("EllesmereUIBags") then return true end
    if _G.Baganator or _G.Baginator or _G.Bagnon or _G.AdiBags
        or _G.ArkInventory or _G.BetterBags or _G.Inventorian
        or _G.ElvUI or _G.Tukui then return true end
    return not _G.ContainerFrame1
end

function Compatibility.HasCustomMinimapAddon()
    if _G.SexyMap or _G.Carbonite or _G.ElvUI then return true end
    if Compatibility.IsAddonPresent("EllesmereUIMinimap") then return true end
    local minimap = _G.MinimapCluster
    if not minimap then return true end
    return minimap.IsUserPlaced and minimap:IsUserPlaced() or false
end

function Compatibility.HasEllesmerePartyFrames()
    return Compatibility.IsAddonPresent("EllesmereUIRaidFrames")
end

function Compatibility.IsBlizzardEditModeOwnedFrame(frame, name)
    name = name or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    return name and (name:match("^EditMode") ~= nil
        or name:match("^DamageMeter") ~= nil) or false
end

function Compatibility.HasBlizzardEditMode()
    if type(Offhand.HasBlizzardEditMode) == "function" then
        return Offhand:HasBlizzardEditMode()
    end
    return Offhand.isRetail or Offhand.isForever
        or C_EditMode ~= nil or EditModeManagerFrame ~= nil
end

function Compatibility.UsesNativeGamepadInterface()
    local mainhand = Offhand.Mainhand
    return mainhand and type(mainhand.IsNativeGamepadInterface) == "function"
        and mainhand:IsNativeGamepadInterface() or false
end

function Compatibility.UsesControllerInterface()
    local mainhand = Offhand.Mainhand
    return mainhand and type(mainhand.IsControllerLayout) == "function"
        and mainhand:IsControllerLayout() or false
end

function Compatibility.HasChattynator()
    return Compatibility.IsAddonPresent("Chattynator")
end

function Compatibility.HasCustomChatAddon()
    return Compatibility.HasChattynator() or Compatibility.IsAddonPresent("EllesmereUIChat")
end

-- Serialized HUD generation must respect the same owners as runtime movement.
-- Profile bundles such as Naowh use their actual installed frame providers.
function Compatibility.IsExternallyOwnedEditModeSystem(entry)
    local systems = Enum and Enum.EditModeSystem
    if not systems or type(entry) ~= "table" then return false end
    local system = entry.system
    if system == nil then return false end
    if system == systems.ActionBar then
        return Compatibility.HasCustomActionBarAddon()
    elseif system == systems.StatusTrackingBar then
        return Compatibility.HasCustomStatusBarAddon()
    elseif system == systems.Minimap then
        return Compatibility.HasCustomMinimapAddon()
    elseif system == systems.ChatFrame then
        return Compatibility.HasCustomChatAddon()
    elseif system == systems.CooldownViewer then
        return Compatibility.IsAddonPresent("EllesmereUICooldownManager")
    elseif system == systems.ObjectiveTracker then
        return Compatibility.IsAddonPresent("EllesmereUIQuestTracker")
    elseif system == systems.UnitFrame then
        local indices = Enum.EditModeUnitFrameSystemIndices or {}
        if (indices.Party ~= nil and entry.systemIndex == indices.Party)
            or (indices.Raid ~= nil and entry.systemIndex == indices.Raid) then
            return Compatibility.HasEllesmerePartyFrames() or _G.ElvUI ~= nil
        end
        return Compatibility.IsAddonPresent("EllesmereUIUnitFrames") or _G.ElvUI ~= nil
    end
    return false
end

function Compatibility.UsesForeverEditMode()
    if Offhand.isForever ~= nil then return Offhand.isForever end
    local version = tonumber(Offhand.tocVersion)
    return version and version >= 16000 and version < 17000 or false
end

function Compatibility.IsForeverEditModeFrame(frame, name)
    if not Compatibility.HasBlizzardEditMode() then return false end
    name = name or (frame and frame.GetName and frame:GetName())
    if Compatibility.IsBlizzardEditModeOwnedFrame(frame, name) then return true end
    if name == "ChatFrame1" and Compatibility.UsesForeverEditMode() and frame
        and type(frame.OnEditModeEnter) == "function"
        and type(frame.OnEditModeExit) == "function" then
        return true
    end
    return name and (foreverEditModeFrameNames[name]
        or name:match("^EditMode")
        or name:match("CooldownViewer")
        or name:match("ManagedFrameContainer")
        or name:match("^PartyMemberFrame")
        or name:match("^CompactPartyFrame")
        or name:match("^CompactRaidFrame")) or false
end

function Compatibility.RetailEditModeOwnsPrimaryChat(frame)
    return not Compatibility.UsesForeverEditMode()
        and frame and frame == _G.ChatFrame1
        and frame.isStaticDocked == true
        and type(frame.OnEditModeEnter) == "function"
        and type(frame.OnEditModeExit) == "function"
end

Offhand.HasCustomActionBarAddon = Compatibility.HasCustomActionBarAddon
Offhand.HasCustomBagAddon = Compatibility.HasCustomBagAddon
Offhand.HasCustomMinimapAddon = Compatibility.HasCustomMinimapAddon
Offhand.HasEllesmerePartyFrames = Compatibility.HasEllesmerePartyFrames
