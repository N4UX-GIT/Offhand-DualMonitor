-- Forever taint boundaries: global Blizzard functions and secure panel-manager
-- state must remain native. These regressions caused secret-number failures in
-- CompactUnitFrame, TextStatusBar and CooldownViewer on the 16.0.1 beta client.

local addon = {
    isForever = true,
    modules = {},
    db = { enabled = true, persistentWorkspacePanels = true },
}

InCombatLockdown = function() return false end

local nativeCloseAllWindows = function() return "windows" end
local nativeCloseAllBags = function() return "bags" end
local nativeContainerCloseAllBags = function() return "container-bags" end
CloseAllWindows = nativeCloseAllWindows
CloseAllBags = nativeCloseAllBags
C_Container = { CloseAllBags = nativeContainerCloseAllBags }

local canvasChunk = assert(loadfile("Core/Canvas.lua"))
canvasChunk("Offhand", addon)

local panelMotionFile = assert(io.open("Core/PanelMotion.lua", "r"))
local panelMotionSource = panelMotionFile:read("*a")
panelMotionFile:close()
assert(panelMotionSource:find("PanelDragBarTemplate", 1, true)
        and panelMotionSource:find("RegisterStateDriver", 1, true),
    "experimental title motion must use Blizzard's template and secure combat visibility")
assert(not panelMotionSource:find(":SetScript(", 1, true)
        and not panelMotionSource:find(":StartMoving(", 1, true)
        and not panelMotionSource:find(":StopMovingOrSizing(", 1, true),
    "Offhand must not replace or reproduce the Blizzard template's native drag scripts")

assert(CloseAllWindows == nativeCloseAllWindows,
    "Forever must not replace Blizzard CloseAllWindows")
assert(CloseAllBags == nativeCloseAllBags,
    "Forever must not replace Blizzard CloseAllBags")
assert(C_Container.CloseAllBags == nativeContainerCloseAllBags,
    "Forever must not replace C_Container.CloseAllBags")
assert(_G.Offhand_OriginalCloseAllWindows == nil
        and _G.Offhand_OriginalCloseAllBags == nil
        and _G.Offhand_Original_C_Container_CloseAllBags == nil,
    "Forever must not publish replacement-function state")

local canvasFile = assert(io.open("Core/Canvas.lua", "r"))
local canvasSource = canvasFile:read("*a")
canvasFile:close()
assert(not canvasSource:find('frame:SetScript("OnHide", nil)', 1, true)
        and not canvasSource:find('frame:SetScript("OnShow", nil)', 1, true),
    "Forever persistence must not replace Blizzard panel scripts")

local seamFile = assert(io.open("Core/SeamRedirect.lua", "r"))
local seamSource = seamFile:read("*a")
seamFile:close()

assert(not seamSource:find('SetUIPanelAttribute, frame, "centerFrameSkipAnchoring"', 1, true),
    "Forever must not write EditModeManagerFrame panel attributes")
assert(not seamSource:find("UIPanelWindows.EditModeManagerFrame.centerFrameSkipAnchoring", 1, true),
    "Forever must not write EditModeManagerFrame panel metadata")
assert(seamSource:find("not self.anchorsHooked and not UsesForeverEditMode()", 1, true),
    "Forever must preserve native UpdateContainerFrameAnchors")
local bagProxySource = canvasSource:match(
    "local function GetForeverNativeBagSavedPosition(.-)%-%- Forever's map%-pin sharing path")
assert(bagProxySource and bagProxySource:find("EnableForeverNativeBagProxy", 1, true),
    "Forever native bags must use the isolated proxy adapter")
assert(bagProxySource:find('CreateFrame("Frame", nil, UIParent)', 1, true),
    "Forever native bag drag input must be owned by a UIParent sibling")
assert(not bagProxySource:find("HookScript", 1, true)
        and not bagProxySource:find("SetPassThroughButtons", 1, true)
        and not bagProxySource:find(":SetUserPlaced", 1, true),
    "Forever bag proxy must not hook native controls or mutate protected ownership state")
assert(bagProxySource:find('hooksecurefunc("CloseAllBags", ObserveClose)', 1, true)
        and bagProxySource:find('hooksecurefunc("ToggleAllBags", ObserveExplicitToggle)', 1, true)
        and bagProxySource:find('hooksecurefunc("ToggleGameMenu", function()', 1, true),
    "Forever bag persistence must distinguish deferred system and explicit closes through secure global observers")
assert(not bagProxySource:find("pcall(ToggleGameMenu)", 1, true),
    "deferred bag restoration must not re-enter ToggleGameMenu's protected SpellStopCasting path")
assert(bagProxySource:find("OpenForeverNativeBackpackThroughBlizzard", 1, true)
        and not bagProxySource:find("bag:Show()", 1, true),
    "Forever hidden-logical bag recovery must use Blizzard bag APIs without showing a native shell")
assert(bagProxySource:find("state.nativeInitialized and state.wasShown", 1, true)
        and bagProxySource:find("pcall(frame.Show, frame)", 1, true),
    "modal fallback must re-show only a previously initialized and visible native bag root")
assert(bagProxySource:find("IsOptionFrameOpen", 1, true)
        and bagProxySource:find("panelTransitionGrace", 1, true)
        and bagProxySource:find("InstallForeverOptionsOpeningObservers", 1, true)
        and bagProxySource:find("optionsOpeningObserved", 1, true),
    "Forever bag persistence must bridge Options discovery and system-panel close timing gaps")
assert(canvasSource:find("if not preservingPanel then ClearNativeBackpackOpenState() end", 1, true),
    "Settings opener rejection must not discard tracked bag intent during modal ownership")
assert(bagProxySource:find("IsForeverNativeBagPreservingPanelShown", 1, true)
        and not bagProxySource:find('EditModeManagerFrame:HookScript', 1, true),
    "Forever panel transitions must be observed without hooking the protected Edit Mode tree")
assert(seamSource:find("not self.anchorsHooked and not UsesForeverEditMode()", 1, true),
    "Forever must preserve native UpdateContainerFrameAnchors")

print("PASS: Forever global-function and secure panel-manager taint boundaries verified")
