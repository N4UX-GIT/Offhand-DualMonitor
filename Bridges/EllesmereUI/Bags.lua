-- EllesmereUIBags bag provider (built into Offhand): the former EllesmereUI bag Escape adapter
-- and persistent-root branches of Core/BagPersistence.lua and its close button finder of
-- Core/WorkspaceChrome.lua, moved with unchanged behaviour. In the Forever bag Escape pass
-- (provider order 70, after the bridges' own RefreshBags) EUI_MainBagFrame and
-- EUI_ReagentBagFrame leave EllesmereUI's shared Escape proxy while they are open on the
-- workspace and rejoin it on Mainhand, and the native bags it parks are closed. The workspace
-- close button handling finds the backpack's header close button. The generic inventory
-- toggles are kept open while EUI_MainBagFrame is on the workspace.
-- Persistent root: EUI_MainBagFrame is the first root the bag persistence engine tries. On
-- Forever EllesmereUI restores that root itself (its saved open state wins, the reagent bag's
-- open state rides along, and Escape, Talents and reload reopen it through EllesmereUI's own
-- show and refresh handlers), it gets no scripts, and it claims the shared bag toggle. A false
-- EllesmereUIDB.bagsVisible is the player's own close.
-- Registered on every client before EllesmereUI exists. See README.md.

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local ROOT = "EUI_MainBagFrame"

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

local function IsForeverEllesmereBag(name)
    return API.IsForeverClient() and name == ROOT
end

local function EllesmereExplicitlyClosed(name)
    return name == ROOT
        and type(EllesmereUIDB) == "table"
        and EllesmereUIDB.bagsVisible == false
end

local function CanShowEllesmereBag(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
        and not frame:IsShown()
        and not (UIParent.IsVisible and not UIParent:IsVisible())
end

local function ShowEllesmereBag(frame)
    if not CanShowEllesmereBag(frame) or type(frame.RefreshInventory) ~= "function" then return end
    frame:Show()
    if frame:IsVisible() then frame:RefreshInventory() end
end

-- Opens the saved root while EllesmereUI and another provider both replaced
-- the shared bag toggle; nil otherwise, so the engine's generic opener runs.
local function ShowSavedRoot(name, frame, services)
    if not (IsForeverEllesmereBag(name) and services.HasSharedToggleConflict()) then return nil end
    -- EllesmereUI 9.7.8 exposes its scale setup in the module namespace.
    -- Use that capability for an already-initialized bag and let its own
    -- show and refresh handlers rebuild it. Neither shared toggle is safe
    -- to call when both providers registered one.
    local eui = _G.EllesmereUI
    local module = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUIBags
    local internals = module and module._bagsInternals
    local applyScale = type(internals) == "table" and rawget(internals, "ApplyBagScale")
    local bagsDB = eui and eui._bagsDB
    local profile = bagsDB and bagsDB.profile
    if profile and type(applyScale) == "function"
        and CanShowEllesmereBag(frame) and pcall(applyScale) then
        ShowEllesmereBag(frame)
        if frame:IsVisible() and profile.detachReagentBag then
            ShowEllesmereBag(_G.EUI_ReagentBagFrame)
        end
        return frame:IsVisible() and true or false
    end
    return false
end

local function CapturePosition(position, frame, services)
    local reagent = _G.EUI_ReagentBagFrame
    position.reagentOpen = reagent and not (reagent.IsForbidden and reagent:IsForbidden())
        and reagent:IsVisible()
        and services.IsFrameOnWorkspace(reagent) or nil
end

local function CanRestoreEllesmereWorkspaceBag(frame, services)
    return frame == _G.EUI_MainBagFrame and CanShowEllesmereBag(frame)
        and type(EllesmereUIDB) == "table" and EllesmereUIDB.bagsVisible == true
        and services.IsFrameOnWorkspace(frame)
        and not services.IsPreservingPanelShown()
end

-- Restore only the initialized root that was open before the panel transition.
local function RestoreEllesmereWorkspaceBag(frame, position, services)
    ShowEllesmereBag(frame)
    if not frame:IsVisible() then return false end
    local reagent = _G.EUI_ReagentBagFrame
    if position.reagentOpen and CanShowEllesmereBag(reagent)
        and services.IsFrameOnWorkspace(reagent) then
        ShowEllesmereBag(reagent)
    end
    return true
end

-- "wait" while the frame exists before EllesmereUI installs its bag opener
-- and loads the native position on its startup timer.
local function ResumeEllesmereBag(name, frame, services)
    if services.IsPreservingPanelShown() or not (frame and frame.GetNumPoints and frame:GetNumPoints() > 0) then
        return "wait"
    end
    if services.IsSpanned() and not frame:IsShown()
        and EllesmereUIDB and EllesmereUIDB.bagsVisible == true then
        local bagsDB = _G.EllesmereUI and _G.EllesmereUI._bagsDB
        local profile = bagsDB and bagsDB.profile
        if profile and profile.enhancedBags ~= false then services.OpenSavedRoot(name) end
    end
    return nil
end

API.RegisterBridge("EllesmereUIBags", {
    contract = API.BRIDGE_CONTRACT,
    bagProvider = {
        order = 70,
        RefreshEscape = RefreshEllesmereBagEscape,
        closeButtonRoots = { ROOT },
        GetCloseButtons = function(frame)
            local buttons = {}
            FindEllesmereCloseButton(frame, buttons)
            return buttons
        end,
        GetToggleFrame = function() return _G.EUI_MainBagFrame end,
        IsRoot = function(name) return name == ROOT end,
        -- A stable root name, so discovery never needs a global-table walk.
        Discover = function(register)
            if _G.EUI_MainBagFrame then return register(ROOT, _G.EUI_MainBagFrame) end
            return false
        end,
        -- On Forever the root is observed outside its frame tree.
        hookScripts = function() return not API.IsForeverClient() end,
        GetManagedRoot = function() return API.IsForeverClient() and ROOT or nil end,
        ClaimsSharedToggle = function() return API.IsForeverClient() and _G.EUI_MainBagFrame and true or false end,
        ExplicitlyClosed = EllesmereExplicitlyClosed,
        Show = ShowSavedRoot,
        CapturePosition = CapturePosition,
        CanRestore = CanRestoreEllesmereWorkspaceBag,
        Restore = RestoreEllesmereWorkspaceBag,
        Resume = ResumeEllesmereBag,
        GetRootDiagnostics = function()
            return "EUIOpen=" .. (type(EllesmereUIDB) == "table"
                and tostring(EllesmereUIDB.bagsVisible) or "unavailable")
        end,
    },
})
