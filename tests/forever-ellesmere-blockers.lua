-- Exercise the production planner and importer without executing vendor source.
UIParent = {GetEffectiveScale = function() return 1 end,
    GetWidth = function() return 2000 end, GetHeight = function() return 1000 end}
InCombatLockdown = function() return false end
Enum = {EditModeSystem = {}, EditModeActionBarSystemIndices = {}}
local profile, snapshot, payload = {}, {}, nil
local registry = {}
local function element(key, left, width)
    registry[key] = {label = key .. " label", getFrame = function()
        return {GetEffectiveScale = function() return 1 end,
            GetRect = function() return left, 100, width or 100, 40 end}
    end}
end
element("MainBar", 500)
element("player", 550)
local context = {rect = {left = 1000, right = 2000, bottom = 0, top = 1000,
    width = 1000, height = 1000, screenWidth = 2000, screenHeight = 1000}, generated = {systems = {}}}
local addon = {isForever = true, db = {enabled = true}, Mainhand = {
    GetEllesmereLayoutSource = function() return context end}}
EllesmereUIDB = {unlockAnchors = {}}
local links = EllesmereUIDB.unlockAnchors
EllesmereUI = {_unlockRegisteredElements = registry,
    IsUnlockAnchored = function(key) return links[key] and links[key].target ~= nil end,
    GetActiveProfileData = function() return profile end,
    GetActiveProfileName = function() return "Fixture" end,
    GetProfileKeys = function() return {} end,
    SnapshotAllAddons = function()
        snapshot.addons = {EllesmereUIActionBars = {barPositions = {}}}
        return snapshot
    end,
    EncodePayload = function(value) payload = value; return "fixture" end,
    ImportProfileInteractive = function() return true end}
assert(loadfile("Core/ForeverEllesmereLayout.lua"))("Offhand", addon)
local transfer = addon.EllesmereLayout
local stores = {"specOverrides", "condOverrides",
    "specUnlockOverrides", "condUnlockOverrides", "specBmOverrides", "condBmOverrides",
    "specDmOverrides", "condDmOverrides", "unlockOverrideAnchors"}
for _, key in ipairs(stores) do profile[key], snapshot[key] = {}, {} end
profile.specUnlockOverrides = {layouts = {}}
snapshot.specUnlockOverrides = {layouts = {}}
profile.specOverrideGroups, profile.condOverrideGroups = {{id = 1, name = "Unused group"}}, {}
snapshot.specOverrideGroups, snapshot.condOverrideGroups = profile.specOverrideGroups, {}
local rows, _, state = transfer:Preview("fit")
assert(not state.block and rows[1].position, "empty vendor override stores must not block the preview")
assert(profile.specOverrideGroups[1].name == "Unused group", "group metadata alone is harmless and must be preserved")
assert(transfer:OpenImport({rows[1]}) and payload.data.overridesExcluded,
    "empty override stores must not block the isolated profile import")
snapshot.condOverrides = {{values = {hidden = false}}}
assert(not select(3, transfer:Preview("fit")).block, "the preview fixture still has no override values")
local lateOK, lateReason = transfer:OpenImport({rows[1]})
assert(not lateOK and lateReason == "ELLESMERE_HUD_OVERRIDES", "a changed import snapshot must invalidate an earlier allowed preview")
snapshot.condOverrides = {}
for _, key in ipairs(stores) do
    profile[key], snapshot[key] = {{values = {hidden = false}}}, {{values = {hidden = false}}}
    local _, _, blocked = transfer:Preview("fit")
    assert(blocked.block == "ELLESMERE_HUD_OVERRIDES", key .. " must remain protected")
    local ok, reason = transfer:OpenImport({rows[1]})
    assert(not ok and reason == "ELLESMERE_HUD_OVERRIDES", "recheck overrides at import time: " .. key)
    profile[key], snapshot[key] = {}, {}
end
local _, _, refreshed = transfer:Preview("fit")
assert(not refreshed.block, "removing the blocker must refresh the preview state")
element("parent", 400)
links.MainBar = {target = "parent"}
rows = transfer:Preview("fit")
assert(not rows[1].position and rows[1].reason == "ELLESMERE_HUD_FOLLOWS"
    and rows[1].reasonArgs[1] == "parent label", "identify an unmapped parent without detaching its child")
links.parent = {target = "MainBar"}
assert(transfer:Preview("fit")[1].reason == "ELLESMERE_HUD_ANCHOR_GRAPH", "report a circular link")
links.MainBar = {target = {}}
assert(transfer:Preview("fit")[1].reason == "ELLESMERE_HUD_ANCHOR_GRAPH", "report malformed links without formatting an invalid parent")
links.parent, links.MainBar = nil, nil
registry.MainBar.getFrame = function()
    return {GetEffectiveScale = function() return 1 end, GetRect = function() return nil end}
end
assert(transfer:Preview("fit")[1].reason == "ELLESMERE_HUD_BOUNDS", "missing bounds are not a linked-anchor failure")
element("MainBar", 500)
links.missing = {target = "MainBar"}
rows = transfer:Preview("fit")
assert(rows[1].reason == "ELLESMERE_HUD_CHILD_BOUNDS" and rows[1].reasonArgs[1] == "missing",
    "name the unmeasurable member of a linked group")
links.missing = nil
element("child", 490)
links.child = {target = "MainBar"}
rows = transfer:Preview("fit")
assert(rows[1].position and rows[1].linkedGroup, "a measurable linked group remains transferable")
element("child", 490, 2000)
assert(transfer:Preview("fit")[1].reason == "ELLESMERE_HUD_GROUP_TOO_LARGE", "explain oversized groups")
links.child = nil
links.player = {target = "MainBar"}
rows = transfer:Preview("fit")
assert(rows[3].followKey == "MainBar" and rows[3].reason == "ELLESMERE_HUD_MOVES_WITH"
    and rows[3].reasonArgs[1] == "MainBar label", "name the parent that will actually move")
assert(links.player.target == "MainBar", "preview must preserve the vendor's link graph")
print("PASS: empty and real EUI overrides, import rechecks and actionable linked-anchor blockers")
