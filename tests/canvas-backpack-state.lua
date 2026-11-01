local addon = { isForever = true }

ContainerFrame1 = { name = "individual", shown = false }
ContainerFrameCombinedBags = { name = "combined", shown = false }
function ContainerFrame1:IsShown() return self.shown end
function ContainerFrameCombinedBags:IsShown() return self.shown end

assert(loadfile("Core/CanvasBackpackState.lua"))("Offhand", addon)
local state = assert(addon.CanvasBackpackState)

assert(state.IsForeverContainerName("ContainerFrame7")
        and not state.IsForeverContainerName("CharacterFrame"),
    "Forever native container detection changed during extraction")
addon.isForever = false
assert(not state.IsForeverContainerName("ContainerFrame1"),
    "non-Forever clients must not enter the Forever container adapter")
addon.isForever = true

assert(state.IsRoot("ContainerFrame1") and state.IsRoot("ContainerFrameCombinedBags")
        and not state.IsRoot("ContainerFrame2"),
    "native backpack root identity changed during extraction")
for _, name in ipairs({
    "ContainerFrame3", "ContainerFrameCombinedBags", "EUI_MainBagFrame",
    "Baganator_SingleViewBackpackViewFrame1", "Baganator_CategoryViewBackpackViewFrame1",
    "BaginatorMain", "BGR_Main", "BagnonInventory", "AdiBagsContainer",
    "BetterBagsBag", "ArkInventoryFrame", "CustomBagRestorer",
}) do
    assert(state.IsRestorableRootName(name), "restorable bag root lost: " .. name)
end
assert(not state.IsRestorableRootName("BaganatorChild")
        and not state.IsRestorableRootName(nil),
    "bag child or invalid names must not become reload roots")

local individualPosition = { x = 100, y = 500 }
local combinedPosition = { x = 200, y = 600 }
local db = {
    savedWorkspacePositions = {
        ContainerFrame1 = individualPosition,
        ContainerFrameCombinedBags = combinedPosition,
    },
    savedMainPositions = {
        ContainerFrame1 = { x = 10, y = 20 },
        ContainerFrameCombinedBags = { x = 30, y = 40 },
    },
    openWorkspacePanels = {
        ContainerFrame1 = true,
        ContainerFrameCombinedBags = true,
    },
}
assert(state.GetWorkspacePosition(db) == individualPosition
        and db.nativeBackpackWorkspacePosition == individualPosition,
    "the individual root must retain established fallback priority")
assert(state.IsTrackedOpen(db) and db.nativeBackpackWorkspaceOpen == true,
    "legacy root open state must populate the mode-independent marker")
assert(state.ClearOtherRoots(db, "ContainerFrameCombinedBags"),
    "clearing an open inactive root must report an open-state change")
assert(db.savedWorkspacePositions.ContainerFrame1 == nil
        and db.savedMainPositions.ContainerFrame1 == nil
        and db.openWorkspacePanels.ContainerFrame1 == nil
        and db.savedWorkspacePositions.ContainerFrameCombinedBags == combinedPosition,
    "backpack ownership transfer must clear only the inactive root")
assert(state.ClearOpenState(db)
        and db.nativeBackpackWorkspaceOpen == nil
        and db.openWorkspacePanels.ContainerFrameCombinedBags == nil,
    "mode-independent and root-specific open state must clear together")
assert(not state.ClearOpenState(db),
    "clearing an already empty open state must be idempotent")

ContainerFrame1.shown = true
ContainerFrameCombinedBags.shown = true
assert(state.GetShownRoot() == ContainerFrameCombinedBags,
    "the visible Combined Bags root must take precedence")
ContainerFrameCombinedBags.shown = false
assert(state.GetShownRoot() == ContainerFrame1,
    "the visible individual root must be discovered")

db.savedWorkspacePositions.ContainerFrameCombinedBags = combinedPosition
assert(state.GetPreferredRoot(db) == ContainerFrameCombinedBags,
    "saved Combined Bags ownership must determine the preferred root")
db.savedWorkspacePositions = {}
GetCVarBool = function(name) return name == "combinedBags" end
assert(state.GetPreferredRoot(db) == ContainerFrameCombinedBags,
    "the native combinedBags preference must select an unsaved root")

print("PASS: Canvas native backpack identity, ownership and open-state policy")
