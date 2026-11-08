local addon = {}
local loaded, mutations = false, 0
local secret = {}
issecretvalue = function(value) return value == secret end
C_AddOns = {IsAddOnLoaded = function(name) return loaded and name == "ZygorGuidesViewer" end}
local function Frame(name, alpha)
    return {
        GetName = function() return name end,
        IsShown = function() return true end,
        IsVisible = function() return false end,
        GetAlpha = function() return alpha end,
        GetEffectiveAlpha = function() return 0 end,
        GetEffectiveScale = function() return 0.7 end,
        GetFrameStrata = function() return "BACKGROUND" end,
        GetFrameLevel = function() return 0 end,
        GetLeft = function() return -500 end,
        GetBottom = function() return 120 end,
        GetRight = function() return secret end,
        GetTop = function() error("unavailable") end,
        SetPoint = function() mutations = mutations + 1 end,
        Show = function() mutations = mutations + 1 end,
        HookScript = function() mutations = mutations + 1 end,
    }
end
local guide = Frame("ZygorGuideDiagnosticFixture", 0.5)
local other = Frame("OtherAddon", 1)
UIParent = {GetChildren = function() return other, guide end}
WorldFrame = {GetChildren = function() return guide end}
assert(loadfile("Core/CanvasCompatibility.lua"))("Offhand", addon)
local reports = addon.CanvasCompatibility.GetGuideAddonDiagnostics()
assert(#reports == 2 and reports[1]:find("namedRoots=1", 1, true)
        and reports[2]:find("shown=1 visible=0 alpha=0.50 effectiveAlpha=0.00", 1, true)
        and reports[2]:find("strata=BACKGROUND level=0.00", 1, true)
        and reports[2]:find("bounds=-500.00/120.00/unavailable/unavailable", 1, true),
    "guide diagnostics must distinguish geometry, visibility, inherited alpha and unreadable values")
assert(mutations == 0, "diagnostics must not mutate third-party widgets")
UIParent.GetChildren = function() return other end
WorldFrame = nil
assert(addon.CanvasCompatibility.GetGuideAddonDiagnostics() == nil,
    "no observed guide must not produce an unsupported addon-absence diagnosis")
loaded = true
reports = addon.CanvasCompatibility.GetGuideAddonDiagnostics()
assert(#reports == 1 and reports[1]:find("knownAddonID=loaded", 1, true)
        and reports[1]:find("namedRoots=0", 1, true),
    "a loaded guide with no named direct roots must remain diagnostically distinct")
guide.GetName = function() return secret end
UIParent.GetChildren = function() return guide end
reports = addon.CanvasCompatibility.GetGuideAddonDiagnostics()
assert(#reports == 1, "secret frame names must not be compared or formatted")
local many = {}
for index = 1, 300 do many[index] = other end
UIParent.GetChildren = function() return unpack(many) end
reports = addon.CanvasCompatibility.GetGuideAddonDiagnostics()
assert(reports[1]:find("scanned=256 truncated=yes", 1, true), "guide root inspection must be bounded")
print("PASS: read-only guide diagnostics preserve secret values, scope and bounded discovery")
