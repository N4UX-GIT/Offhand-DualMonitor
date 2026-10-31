local addon = {}

assert(loadfile("Core/HUDTransientPolicy.lua"))("Offhand", addon)
local policy = assert(addon.HUDTransientPolicy)
local specs = policy.GetSpecs()

local byName = {}
for _, spec in ipairs(specs) do byName[spec.name] = spec end
assert(byName.LFGListApplicationDialog.specialPopup and byName.LFGListInviteDialog.specialPopup,
    "premade-group dialogs must use the external native-stack placement policy")
assert(byName.GroupLootContainer and byName.GroupLootContainer.secure
        and byName.GroupLootContainer.groupLootRows
        and byName.PetBattleFrame and byName.PetBattleFrame.petBattleBounds,
    "reviewed secure transient roots changed during extraction")
assert(byName.CombatText.normalizeScale and byName.TimerTracker.bounds
        and byName.LFGDungeonReadyPopup.hookEvent,
    "transient scale, bounds, or event policy changed during extraction")

local ordinary = {
    ClearAllPoints = function() end,
    SetPoint = function() end,
}
TransientTestFrame = ordinary
assert(policy.Resolve({ name = "TransientTestFrame" }) == ordinary,
    "global transient resolution changed during extraction")
HouseEditorFrame = { ModeBar = ordinary }
assert(policy.Resolve(byName["HouseEditorFrame.ModeBar"]) == ordinary,
    "nested transient resolution changed during extraction")
assert(policy.Resolve(nil) == nil, "invalid transient specifications must fail closed")

assert(policy.CanPosition(ordinary), "ordinary mutable transient frame was rejected")
local forbidden = {
    ClearAllPoints = ordinary.ClearAllPoints,
    SetPoint = ordinary.SetPoint,
    IsForbidden = function() return true end,
}
assert(not policy.CanPosition(forbidden), "forbidden transient frame must be rejected")
local protected = {
    ClearAllPoints = ordinary.ClearAllPoints,
    SetPoint = ordinary.SetPoint,
    IsProtected = function() return true end,
}
assert(not policy.CanPosition(protected)
        and policy.CanPosition(protected, { secure = true }),
    "protected transient frames require an explicitly reviewed secure specification")

local scaled = { ignoring = true }
function scaled:IsIgnoringParentScale() return self.ignoring end
function scaled:SetIgnoreParentScale(value) self.ignoring = value end
assert(policy.NormalizeScale(scaled) and scaled.ignoring == false,
    "owned transient scale must rejoin the UIParent scale hierarchy")
assert(not policy.NormalizeScale(scaled),
    "an already normalized transient scale must remain unchanged")
scaled.IsIgnoringParentScale = function() error("restricted") end
assert(not policy.NormalizeScale(scaled),
    "restricted scale inspection must fail closed")

print("PASS: transient HUD registry, resolution, protection and scale policy")
