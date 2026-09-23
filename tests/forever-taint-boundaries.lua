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

local seamFile = assert(io.open("Core/SeamRedirect.lua", "r"))
local seamSource = seamFile:read("*a")
seamFile:close()

assert(not seamSource:find('SetUIPanelAttribute, frame, "centerFrameSkipAnchoring"', 1, true),
    "Forever must not write EditModeManagerFrame panel attributes")
assert(not seamSource:find("UIPanelWindows.EditModeManagerFrame.centerFrameSkipAnchoring", 1, true),
    "Forever must not write EditModeManagerFrame panel metadata")
assert(seamSource:find("not self.anchorsHooked and not UsesForeverEditMode()", 1, true),
    "Forever must preserve native UpdateContainerFrameAnchors")

print("PASS: Forever global-function and secure panel-manager taint boundaries verified")
