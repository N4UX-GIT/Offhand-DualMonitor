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

local mainhandFile = assert(io.open("Core/Mainhand.lua", "r"))
local mainhandSource = mainhandFile:read("*a")
mainhandFile:close()
assert(not mainhandSource:find("presetLayoutInfo", 1, true)
        and not mainhandSource:find("UpdateLayoutInfo", 1, true),
    "Forever must not mutate or refresh Blizzard's Gamepad preset manager")
assert(mainhandSource:find("GAMEPAD_INTERFACE_SETTLE_SECONDS", 1, true)
        and mainhandSource:find("GAMEPAD_ACTIVE_PANEL_INTERVAL", 1, true)
        and mainhandSource:find('"native-visible"', 1, true),
    "Forever Gamepad transitions must settle before protected anchor work resumes")
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
local bagProxyEntry = canvasSource:match(
    "function Canvas:EnableForeverNativeBagProxy%(%)"
        .. "(.-)%-%- Forever's map%-pin sharing path")
assert(bagProxyEntry and bagProxyEntry:find("OpenForeverNativeBackpackThroughBlizzard", 1, true)
        and bagProxyEntry:find("InstallForeverNativeBagCloseObservers", 1, true)
        and bagProxyEntry:find("InstallForeverOptionsOpeningObservers", 1, true)
        and not bagProxyEntry:find("pcall(frame.Show, frame)", 1, true),
    "Forever bag proxy must restore tracked state through Blizzard APIs without showing a native shell")
assert(seamSource:find("not self.anchorsHooked and not UsesForeverEditMode()", 1, true),
    "Forever must preserve native UpdateContainerFrameAnchors")

print("PASS: Forever global-function and secure panel-manager taint boundaries verified")
