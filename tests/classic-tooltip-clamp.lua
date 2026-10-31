local combat, writes, clamped = false, 0, true
InCombatLockdown = function() return combat end
UIParent = { GetEffectiveScale = function() return 0.5 end,
    GetWidth = function() return 1000 end, GetHeight = function() return 800 end }
local metrics = { isSpanned = true, hudScale = 1,
    workspaceLeft = 0, workspaceRight = 400, workspaceBottom = 0, workspaceTop = 800 }
local addon = { modules = {}, db = { enabled = true, seamRedirect = true },
    Viewport = { GetMetrics = function() return metrics end } }
assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
local ownerX = 10
local function frame(left, right, top, bottom)
    return {
        GetLeft = function() return left end, GetRight = function() return right end,
        GetTop = function() return top end, GetBottom = function() return bottom end,
        GetEffectiveScale = function() return 1 end, IsShown = function() return true end,
        IsObjectType = function() return false end,
        ClearAllPoints = function() error("native tooltip anchor changed") end,
        SetPoint = function() error("native tooltip anchor changed") end,
        SetOwner = function() error("native tooltip owner changed") end,
        SetScale = function() error("native tooltip scale changed") end,
    }
end
local owner = frame(0, 0, 300, 280)
owner.GetLeft = function() return ownerX end
owner.GetRight = function() return ownerX + 10 end
local tooltip = frame(190, 270, 200, 160)
local insets = { 0, 0, 25, 0 }
tooltip.GetOwner = function() return owner end
tooltip.GetClampRectInsets = function() return unpack(insets) end
tooltip.SetClampRectInsets = function(_, ...) assert(not combat); insets = {...}; writes = writes + 1 end
tooltip.IsClampedToScreen = function() return clamped end
tooltip.SetClampedToScreen = function(_, value) assert(not combat); clamped = value end
GameTooltip = tooltip
local scripts = {}
tooltip.HookScript = function(_, event, callback) scripts[event] = callback end
local shown, ownerCalls = false, 0
tooltip.IsShown = function() return shown end
tooltip.SetOwner = function(_, nativeOwner)
    assert(nativeOwner == owner)
    ownerCalls = ownerCalls + 1
end
hooksecurefunc = function(target, method, callback)
    assert(target == tooltip and method == "SetOwner")
    local original = target[method]
    target[method] = function(...) original(...); callback(...) end
end
addon.PopupBounds:ObserveTooltip(tooltip)
tooltip:SetOwner(owner, "ANCHOR_RIGHT")
assert(ownerCalls == 1 and insets[2] == 306,
    "workspace bounds must be prepared during native ownership assignment before the tooltip is shown")
local preparedWrites = writes
local nativeLeft = tooltip.GetLeft
tooltip.GetLeft = function()
    assert(shown, "preparation must not inspect a hidden tooltip's stale geometry")
    return nativeLeft()
end
scripts.OnSizeChanged(tooltip)
assert(writes == preparedWrites, "hidden item-data sizing must retain the prepared clamp without churn")
shown = true
scripts.OnShow(tooltip)
assert(writes == preparedWrites, "first show must not visibly change an already prepared clamp policy")
assert(insets[1] == -6 and insets[2] == 306 and insets[3] == 25 and insets[4] == -6,
    "native clamp policy must reserve the Mainhand width with the correct signs and effective scale")
local before = writes
scripts.OnSizeChanged(tooltip)
assert(writes == before, "unchanged native clamp policy must not churn")
scripts.OnHide(tooltip)
assert(insets[1] == 0 and insets[2] == 0 and insets[3] == 25 and insets[4] == 0 and clamped,
    "native tooltip clamp defaults must restore on hide")
metrics.workspaceLeft, metrics.workspaceRight, ownerX = 600, 1000, 350
assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip))
assert(insets[1] == -306 and insets[2] == 6, "right-side workspace must reserve the left Mainhand")
ownerX = 10
assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and insets[1] == 0 and insets[2] == 0,
    "Mainhand-owned tooltips must lose the workspace-only clamp")
before = writes
combat = true
assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and writes == before)
combat = false
ownerX = 350
metrics.isSpanned = false
assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and writes == before)
metrics.isSpanned = true
addon.db.enabled = false
assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and writes == before)
addon.db.enabled = true
tooltip.IsEmbedded = true
assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and writes == before)
tooltip.IsEmbedded = nil
tooltip.GetRight = function() return 500 end -- oversized, never shrink native content
assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and writes == before)
tooltip.GetRight = function() return 270 end
assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip))
insets = { 1, 2, 3, 4 }
scripts.OnHide(tooltip)
assert(insets[1] == 1 and insets[4] == 4, "restoration must not overwrite a newer native/custom clamp")
insets, clamped = { 0, 0, 25, 0 }, false
assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and clamped,
    "native clamping may be enabled temporarily without changing scale or anchors")
local queue = {}
addon.RunOrQueueCombat = function(_, callback) queue[#queue + 1] = callback end
combat = true
addon.PopupBounds:RestoreClassicTooltipClamp(tooltip)
addon.PopupBounds:RestoreClassicTooltipClamp(tooltip)
assert(#queue == 1, "combat restoration must be deferred and deduplicated")
combat, ownerX = false, 10
queue[1]()
assert(not clamped and insets[1] == 0 and insets[2] == 0,
    "post-combat restoration must re-evaluate the current owner and restore native clamping policy")
ownerX = 350
tooltip.IsObjectType = function(_, kind) return kind == "GameTooltip" end
local comparison = frame(280, 330, 200, 160)
comparison.GetOwner = function() return tooltip end
local comparisonInsets = { 0, 0, 25, 0 }
comparison.GetClampRectInsets = function() return unpack(comparisonInsets) end
comparison.SetClampRectInsets = function(_, ...) comparisonInsets = {...} end
comparison.IsClampedToScreen = function() return true end
comparison.SetClampedToScreen = function() error("comparison clamping was already enabled") end
assert(addon.PopupBounds:UpdateClassicTooltipClamp(comparison) and comparisonInsets[1] == -306,
    "comparison cards must resolve the primary tooltip's workspace owner without rewriting their anchor graph")
addon.PopupBounds:RestoreClassicTooltipClamp(comparison)
assert(comparisonInsets[1] == 0 and comparisonInsets[2] == 0)
print("PASS: Classic workspace clamp uses native engine bounds without owner, anchor or scale writes")

-- World/cursor tooltips use Mainhand bounds on Retail and Forever, including
-- the horizontal seam in a vertically stacked layout. Native anchors stay intact.
metrics.gameLeft, metrics.gameRight, metrics.gameBottom, metrics.gameTop = 0, 1000, 0, 400
metrics.workspaceLeft, metrics.workspaceRight = 0, 1000
metrics.workspaceBottom, metrics.workspaceTop = 400, 800
tooltip.GetOwner = function() return UIParent end
for _, client in ipairs({"isRetail", "isForever"}) do
    addon[client] = true
    insets, clamped = {0,0,25,0}, false
    assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip))
    assert(insets[1] == -6 and insets[2] == 6 and insets[3] == 206
            and insets[4] == -6 and clamped,
        "stacked world tooltips must stay on Mainhand using effective-scale clamp insets")
    ShoppingTooltip1 = comparison
    assert(addon.PopupBounds:ArrangeTooltipComparisons(tooltip) and comparisonInsets[3] == 206,
        "completed world-tooltip comparisons must share Mainhand bounds without rewriting their anchor graph")
    addon.PopupBounds:RestoreClassicTooltipClamp(comparison)
    ShoppingTooltip1 = nil
    local unchanged = writes
    addon.PopupBounds:UpdateClassicTooltipClamp(tooltip)
    assert(writes == unchanged, "unchanged world-tooltip bounds must not churn")
    combat = true
    addon.PopupBounds:UpdateClassicTooltipClamp(tooltip)
    assert(writes == unchanged, "world-tooltip clamp must defer during combat")
    combat = false
    addon.db.enabled = false
    assert(addon.PopupBounds:UpdateClassicTooltipClamp(tooltip) and not clamped
            and insets[3] == 25, "disabling must restore original world-tooltip clamping")
    addon.db.enabled = true
    TipTac = {}
    assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip), "external tooltip ownership must yield")
    TipTac = nil
    tooltip.IsProtected = function() return true end
    assert(not addon.PopupBounds:UpdateClassicTooltipClamp(tooltip), "protected tooltip must remain native")
    tooltip.IsProtected = nil
    addon[client] = nil
end
print("PASS: Retail and Forever world-tooltip clamp preserves native anchors, combat and external ownership")
