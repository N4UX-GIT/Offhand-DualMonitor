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
    BuffFrame = true, DebuffFrame = true, ExternalDefensivesFrame = true,
    BuffCluster = true, CastingBarFrame = true, PlayerCastingBarFrame = true,
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
    if Compatibility.IsAddonPresent("EllesmereUIBags")
        and not (Offhand.isForever and Compatibility.UsesNativeGamepadInterface()) then return true end
    if _G.Baganator or _G.Baginator or _G.Bagnon or _G.AdiBags
        or _G.ArkInventory or _G.BetterBags or _G.Inventorian
        or _G.ElvUI or _G.Tukui then return true end
    -- Combined mode can exist without an individual backpack root. Either
    -- native root is sufficient; explicit replacement owners above still win.
    return not (_G.ContainerFrame1 or _G.ContainerFrameCombinedBags)
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

function Compatibility.IsExternallyOwnedHUDFrame(frame, name)
    if Offhand.ForeverPlusWarnings and Offhand.ForeverPlusWarnings:IsOwnedFrame(frame) then return true end
    name = name or (frame and frame.GetName and frame:GetName())
    -- Replacement minimaps detach the visible canvas from MinimapCluster.
    -- Treat that canvas as HUD even when it overhangs Mainhand or sits at the
    -- seam. Cropped Ellesmere maps can also use an anonymous UIParent root.
    if name == "Minimap" or (frame and frame == _G.Minimap) then return true end
    if frame and frame ~= UIParent and Compatibility.HasCustomMinimapAddon() then
        local ok, owned = pcall(function()
            local current = _G.Minimap
            for _ = 1, 4 do
                if not current or current == UIParent or current == WorldFrame then return false end
                if current == frame then return true end
                if current.IsForbidden and current:IsForbidden() then return false end
                current = current.GetParent and current:GetParent()
            end
            return false
        end)
        if ok and owned then return true end
    end
    -- These public roots are positioned by Ellesmere's player aura-bar module
    -- and its unlock anchors. The generic popup pass must not compete with it.
    return name == "EllesmereUIPlayerAuraBars_Buffs"
        or name == "EllesmereUIPlayerAuraBars_Debuffs"
end

local positionedAddonPopupRoots = {
    BetterBagsBagBackpack = true, BetterBagsBagBank = true,
    BetterBagsBagBackpackAnchor = true, BetterBagsBagBankAnchor = true,
    -- Next persists its own panel placement and deliberately clears the native
    -- user-placed flag after dragging. It has no Classic anchor roots.
    BetterBagsNextBackpack = true, BetterBagsNextBank = true,
    BetterBagsNextVendor = true, BetterBagsNextGuildBank = true,
    RXPFrame = true, RXPItemFrame = true,
    -- This one-unit presentation anchor belongs to ProcDoc, including while
    -- Offhand's optional Mainhand centering is off. Popup recovery must not
    -- supply an offset that the centering adapter would then apply again.
    ProcDocAlertFrame = true,
    -- Questie owns TrackerLocation and its Ctrl-drag/lock behavior. Its reset
    -- anchor deliberately uses screen center and need not be IsUserPlaced.
    Questie_BaseFrame = true,
}

local linkedChatPopupRoots = {
    -- Social and Quick Join are two states of the same native button. The
    -- alert and text-to-speech controls follow the chat button strip. The
    -- button's immediate anchor varies by client; preserve the linked roots.
    ChatAlertFrame = true,
    TextToSpeechButtonFrame = true,
    QuickJoinToastButton = true,
}

local function IsOrdinaryPopupValue(value)
    if type(issecretvalue) ~= "function" then return true end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
end

-- Only automatic popup redirection yields here. Explicit workspace movement
-- and each vendor's own position persistence keep their existing policies.
function Compatibility.ShouldPreservePopupPosition(frame, name)
    if not frame then return false end
    if not IsOrdinaryPopupValue(name) then return true end
    if name == nil and type(frame.GetName) == "function" then
        local ok, value = pcall(frame.GetName, frame)
        if not ok then return true end
        name = value
    end
    if not IsOrdinaryPopupValue(name) then return true end
    if type(name) == "string" and positionedAddonPopupRoots[name] then return true end
    if type(name) == "string" and linkedChatPopupRoots[name] then return true end
    -- Details owns each numbered meter through its instance/LibWindow store.
    -- Its drag completion clears IsUserPlaced; configuration dialogs are separate.
    if type(name) == "string" and name:match("^DetailsBaseFrame%d+$") then return true end
    -- RestedXP V2 exposes an AceGUI widget; its actual UIParent child is
    -- anonymous. Consult the public widget on each pass for load-order changes.
    local guide = _G.RXPV2GuideWindow
    if type(guide) == "table" and rawget(guide, "frame") == frame then return true end
    if type(frame.IsUserPlaced) == "function" then
        local ok, placed = pcall(frame.IsUserPlaced, frame)
        if not ok or not IsOrdinaryPopupValue(placed) or placed ~= false then return true end
    end
    return false
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
