-- EllesmereUIBags bag provider (built into Offhand): the former EllesmereUI bag Escape adapter
-- of Core/BagPersistence.lua and its close button finder of Core/WorkspaceChrome.lua, moved
-- with unchanged behaviour. In the Forever bag Escape pass (provider order 70, after the
-- bridges' own RefreshBags) EUI_MainBagFrame and EUI_ReagentBagFrame leave EllesmereUI's
-- shared Escape proxy while they are open on the workspace and rejoin it on Mainhand, and
-- the native bags it parks are closed. The workspace close button handling finds the
-- backpack's header close button. The generic inventory toggles are kept open while
-- EUI_MainBagFrame is on the workspace. The rest of its bag persistence stays in the core
-- for now.
-- Registered on every client before EllesmereUI exists. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

-- escapeFrames: the roots whose default proxy registration Offhand removed.
local Ellesmere = {}

local function IsAddOnLoadedCompat(name)
    local checker = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not checker then return _G[name] ~= nil end
    local ok, loaded = pcall(checker, name)
    return ok and loaded == true
end

local function RefreshEllesmereBagEscape(services)
    if InCombatLockdown() then return end
    local vendor = IsAddOnLoadedCompat("EllesmereUIBags") and _G.EllesmereUI
    local namespace = vendor and vendor._ModuleNS and vendor._ModuleNS.EllesmereUIBags
    if not namespace or not namespace.BlizzardBagsParked or not vendor.RegisterEscapeClose
        or not vendor._ForgetEscapeClose or not _G.EllesmereUI_EscapeProxy then return end
    local frame = _G.EUI_MainBagFrame
    if not frame or frame ~= _G.EUI_Bags or not frame.RefreshInventory then return end
    Ellesmere.escapeFrames = Ellesmere.escapeFrames or {}
    local preserved = false
    for _, root in ipairs({frame, _G.EUI_ReagentBagFrame}) do
        local exclude = not services.IsPaused() and services.TrackEnabled() and services.IsSpanned()
            and not services.InputReserved()
            and services.CanOpenBagsFromAddon() and root:GetParent() == UIParent
            and (root:IsVisible() or (Ellesmere.escapeFrames[root] and not root:IsShown()))
            and not (root.IsForbidden and root:IsForbidden())
            and not (root.IsProtected and root:IsProtected())
            and services.IsFrameOnWorkspace(root)
        if exclude and not Ellesmere.escapeFrames[root] then
            -- The vendor proxy is shared with other windows. Remove only the
            -- default registration for this backpack while Offhand owns it.
            Ellesmere.escapeFrames[root] = true
            vendor._ForgetEscapeClose(root)
        elseif not exclude and Ellesmere.escapeFrames[root] then
            Ellesmere.escapeFrames[root] = nil
            vendor.RegisterEscapeClose(root)
            if root:IsShown() then _G.EllesmereUI_EscapeProxy:Show() end
        end
        if exclude then preserved = true end
    end
    if preserved then
        local combined = _G.ContainerFrameCombinedBags
        if combined then
            services.CloseParkedNativeBags(combined:GetParent(), NUM_CONTAINER_FRAMES or 13,
                NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4)
        end
    end
end

-- The backpack's close button is the header child anchored RIGHT to RIGHT.
local function FindEllesmereCloseButton(frame, buttons)
    local header = frame and frame.Header
    if not header or not header.GetChildren then return end
    local children = { header:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.GetObjectType and child:GetObjectType() == "Button"
            and child.GetPoint then
            local point, relativeTo, relativePoint = child:GetPoint(1)
            if point == "RIGHT" and relativePoint == "RIGHT" and relativeTo == header then
                buttons[#buttons + 1] = child
            end
        end
    end
end

API.RegisterBridge("EllesmereUIBags", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 70,
        RefreshEscape = RefreshEllesmereBagEscape,
        closeButtonRoots = { "EUI_MainBagFrame" },
        GetCloseButtons = function(frame)
            local buttons = {}
            FindEllesmereCloseButton(frame, buttons)
            return buttons
        end,
        GetToggleFrame = function() return _G.EUI_MainBagFrame end,
    },
})
