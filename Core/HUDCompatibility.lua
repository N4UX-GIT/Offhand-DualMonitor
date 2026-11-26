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

-- Replacement HUD owners come from the bridges' ownership roles.
local function HasRole(role)
    return Offhand.Bridges and Offhand.Bridges:HasRole(role) or false
end

function Compatibility.HasCustomActionBarAddon()
    if HasRole("hud.actionBars") then return true end
    local main = _G.MainMenuBar or _G.MainActionBar
    return not main
end

function Compatibility.HasCustomStatusBarAddon()
    return HasRole("hud.statusBars")
end

local function GetBagSmithParkingParent(frame)
    -- BagSmith can leave the native bag binding enabled. Its replacement
    -- parks the native backpack under a hidden, anonymous UIParent child.
    if not frame or not frame.GetParent or (frame.IsForbidden and frame:IsForbidden()) then return end
    local parent = frame:GetParent()
    if parent and parent ~= UIParent and parent ~= _G.ContainerFrameContainer
        and not (parent.IsForbidden and parent:IsForbidden())
        and parent.GetName and parent:GetName() == nil and parent.GetParent
        and parent:GetParent() == UIParent and parent.IsShown and not parent:IsShown() then
        return parent
    end
end

function Compatibility.GetBagSmithParkingParent()
    if Offhand.isForever and Compatibility.IsAddonPresent("BagSmith") then
        return GetBagSmithParkingParent(_G.ContainerFrame1)
            or GetBagSmithParkingParent(_G.ContainerFrameCombinedBags)
    end
end

function Compatibility.HasMoveMyBags()
    return Compatibility.IsAddonPresent("MoveMyBags")
end

function Compatibility.HasCustomBagAddon()
    if Compatibility.IsAddonPresent("EllesmereUIBags")
        and not (Offhand.isForever and Compatibility.UsesNativeGamepadInterface()) then return true end
    if Compatibility.HasMoveMyBags() then return true end
    if _G.Baganator or _G.Baginator or _G.Bagnon or _G.AdiBags
        or _G.ArkInventory or _G.BetterBags or _G.Inventorian
        or _G.ElvUI or _G.Tukui then return true end
    if Compatibility.IsAddonPresent("BetterBags") or Compatibility.IsAddonPresent("Bagnaros") then return true end
    if Offhand.Bridges and Offhand.Bridges.HasCustomBag and Offhand.Bridges:HasCustomBag() then return true end
    if Compatibility.GetBagSmithParkingParent() then return true end
    -- Combined mode can exist without an individual backpack root. Either
    -- native root is sufficient; explicit replacement owners above still win.
    return not (_G.ContainerFrame1 or _G.ContainerFrameCombinedBags)
end

function Compatibility.HasCustomMinimapAddon()
    if HasRole("hud.minimap") then return true end
    local minimap = _G.MinimapCluster
    if not minimap then return true end
    return minimap.IsUserPlaced and minimap:IsUserPlaced() or false
end

function Compatibility.HasCustomPartyFrames()
    return HasRole("hud.partyFrames")
end

function Compatibility.IsBlizzardEditModeOwnedFrame(frame, name)
    name = name or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    -- Blizzard's Group Finder Edit Mode system owns the Queue Status anchor.
    return name and (name == "QueueStatusButton" or name:match("^EditMode") ~= nil
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

function Compatibility.HasCustomChatAddon()
    return HasRole("hud.chat")
end

-- DaylightUI lends these native panels back for some views. Check the
-- current parent on every placement, including delayed repairs after a span.
function Offhand.IsDaylightParkedPanel(frame)
    if not frame then return false end
    if Offhand.Bridges and Offhand.Bridges.IsParkedNativePanel
        and Offhand.Bridges:IsParkedNativePanel(frame) then
        return true
    end
    if not Offhand.isForever or
        (frame ~= _G.PlayerSpellsFrame and frame ~= _G.ClassTrainerFrame) then return false end
    local win = _G.DaylightUI and _G.DaylightUI.Win
    local followers = win and win.Followers
    if not followers or not frame.GetParent or (frame.IsForbidden and frame:IsForbidden()) then return false end
    local parent = frame:GetParent()
    return parent ~= nil and (parent == followers.aside or parent == followers.hidden or parent == followers.veil)
end

function Compatibility.IsExternallyOwnedHUDFrame(frame, name)
    if Offhand.IsDaylightParkedPanel(frame) then return true end
    if Offhand.Bridges and Offhand.Bridges.IsExternallyOwnedFrame
        and Offhand.Bridges:IsExternallyOwnedFrame(frame, name) then return true end
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
    -- Vendor HUD roots the bridges name (rule externalHUD) are positioned by
    -- their own addon and its unlock anchors. The generic popup pass must not
    -- compete with it.
    local bridges = Offhand.Bridges
    return bridges ~= nil and bridges:MatchFrame("externalHUD", frame, name)
end

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

-- An addon window whose actual UIParent child is anonymous, reached through a
-- named widget (rule recoverableGuide): returns the frame and the widget's name.
function Compatibility.GetPreservedAnonymousRoot()
    local bridges = Offhand.Bridges
    if bridges then return bridges:GetRuleWidget("recoverableGuide") end
end

-- Only automatic popup redirection yields here. Explicit workspace movement
-- and each vendor's own position persistence keep their existing policies.
function Compatibility.ShouldPreservePopupPosition(frame, name, allowUserPlaced)
    if not frame then return false end
    -- This full-screen parent derives its rectangle from both UIParent corners.
    -- Moving it like a popup leaves Blizzard's separate bags without a rectangle.
    if frame == _G.ContainerFrameContainer then return true end
    if not IsOrdinaryPopupValue(name) then return true end
    if name == nil and type(frame.GetName) == "function" then
        local ok, value = pcall(frame.GetName, frame)
        if not ok then return true end
        name = value
    end
    if not IsOrdinaryPopupValue(name) then return true end
    local addonEscape = Offhand.CanvasAddonEscape
    if addonEscape and addonEscape:IsVendorGameplayFrame(frame, name) then return true end
    -- Addon windows whose vendor saves or derives the position itself, even
    -- when it looks like a newly opened popup or leaves IsUserPlaced false
    -- (rule preservePopup, named by the bridges).
    local bridges = Offhand.Bridges
    if bridges and bridges:MatchFrame("preservePopup", frame, name) then return true end
    if type(name) == "string" and linkedChatPopupRoots[name] then return true end
    if allowUserPlaced then return false end
    local learned = Offhand.LearnedAddonWindows
    if learned and learned:OwnsPosition(frame, name) then return true end
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
        return HasRole("hud.cooldownViewer")
    elseif system == systems.ObjectiveTracker then
        return HasRole("hud.objectiveTracker")
    elseif system == systems.UnitFrame then
        local indices = Enum.EditModeUnitFrameSystemIndices or {}
        if (indices.Party ~= nil and entry.systemIndex == indices.Party)
            or (indices.Raid ~= nil and entry.systemIndex == indices.Raid) then
            return Compatibility.HasCustomPartyFrames() or HasRole("hud.groupFrames")
        end
        return HasRole("hud.unitFrames")
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
Offhand.HasCustomPartyFrames = Compatibility.HasCustomPartyFrames
