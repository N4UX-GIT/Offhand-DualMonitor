--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Zygor/Bridge.lua: read-only Zygor Guides frame probe for the
    debug diagnostics

    This is the former guide addon probe of Core/CanvasCompatibility.lua, moved
    behind the bridge contract; its output is unchanged. GetDebugDiagnostics()
    returns the label "Guide frame" and the report lines, so /offhand diag debug
    prints each as "Guide frame diagnostics: <line>." It creates nothing and
    hooks nothing. Registered on every client, like the probe it replaces.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function" then return end

local function IsAddonLoaded(addonName)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    elseif IsAddOnLoaded then
        local ok, loaded = pcall(IsAddOnLoaded, addonName)
        if ok and loaded then return true end
    end
    return false
end

-- Support-only inspection. Never move, show, hook or read guide contents from
-- third-party frames. A missing named root is not proof that an addon is absent.
local function GetGuideAddonDiagnostics()
    local loaded = IsAddonLoaded("ZygorGuidesViewer")
        or IsAddonLoaded("ZygorGuidesViewerClassic")
    local namespace = type(_G.ZygorGuidesViewer) == "table"
    local reports, seen, scanned, truncated = {}, {}, 0, false
    local function Public(value)
        if type(issecretvalue) == "function" then
            local ok, secret = pcall(issecretvalue, value)
            if not ok or secret then return nil end
        end
        return value
    end
    local function Read(frame, method)
        local ok, value = pcall(function()
            local getter = frame and frame[method]
            if type(getter) == "function" then return getter(frame) end
        end)
        if ok then return Public(value) end
    end
    local function Value(value)
        if type(value) == "boolean" then return value and "1" or "0" end
        if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
            return string.format("%.2f", value)
        end
        return "unavailable"
    end
    for _, parent in pairs({UIParent, WorldFrame}) do
        if parent and type(parent.GetChildren) == "function" then
            local ok, children = pcall(function() return {parent:GetChildren()} end)
            if ok then
                if #children > 256 then truncated = true end
                for index = 1, math.min(#children, 256) do
                    local frame = children[index]
                    scanned = scanned + 1
                    local name = Read(frame, "GetName")
                    if type(name) == "string" and name:lower():find("zygor", 1, true) and not seen[frame] then
                        seen[frame] = true
                        if #reports < 8 then
                            local strata = Read(frame, "GetFrameStrata")
                            reports[#reports + 1] = string.format(
                                "%s parent=%s shown=%s visible=%s alpha=%s effectiveAlpha=%s strata=%s level=%s scale=%s bounds=%s/%s/%s/%s",
                                name:sub(1, 96), parent == UIParent and "UIParent" or "WorldFrame",
                                Value(Read(frame, "IsShown")), Value(Read(frame, "IsVisible")),
                                Value(Read(frame, "GetAlpha")), Value(Read(frame, "GetEffectiveAlpha")),
                                type(strata) == "string" and strata:sub(1, 32) or "unavailable",
                                Value(Read(frame, "GetFrameLevel")),
                                Value(Read(frame, "GetEffectiveScale")), Value(Read(frame, "GetLeft")),
                                Value(Read(frame, "GetBottom")), Value(Read(frame, "GetRight")), Value(Read(frame, "GetTop")))
                        else truncated = true end
                    end
                end
            end
        end
    end
    if not loaded and not namespace and #reports == 0 then return nil end
    table.insert(reports, 1, string.format("Zygor probes: knownAddonID=%s namespace=%s namedRoots=%d scanned=%d truncated=%s",
        loaded and "loaded" or "not-observed", namespace and "present" or "not-observed",
        #reports, scanned, truncated and "yes" or "no"))
    return reports
end

local bridge = { contract = API.BRIDGE_CONTRACT }

-- Debug diagnostics only: nothing when no guide was observed.
function bridge:GetDebugDiagnostics()
    local reports = GetGuideAddonDiagnostics()
    if reports then return "Guide frame", reports end
end

API.RegisterBridge("Zygor", bridge)
