local addon = {}

assert(loadfile("UI/Controls.lua"))("Offhand", addon)
local controls = assert(addon.UIControls)

local button = { enabled = false, locked = false }
function button:SetEnabled(enabled) self.enabled = enabled end
function button:LockHighlight() self.locked = true end
function button:UnlockHighlight() self.locked = false end
assert(controls.SetChoiceSelected(button, true)
        and button.enabled and button.selected and button.locked,
    "selected choices must remain enabled and visibly highlighted")
assert(controls.SetChoiceSelected(button, false)
        and button.enabled and not button.selected and not button.locked,
    "cleared choices must remain enabled and release their highlight")
assert(not controls.SetChoiceSelected(nil, true),
    "missing choice controls must fail closed")

local parent = {}
function parent:SetHeight(height) self.height = height end
local function Card(height)
    local card = { height = height }
    function card:ClearAllPoints() self.cleared = true end
    function card:SetPoint(...) self.point = { ... } end
    function card:GetHeight() return self.height end
    return card
end
local first, second, third = Card(100), Card(80), Card(60)
local height = controls.StackCards(parent, { first, second, third })
assert(height == 276 and parent.height == 276,
    "default card stacking must retain twelve-unit spacing")
assert(first.point[5] == 0 and second.point[5] == -112 and third.point[5] == -204,
    "cards must retain their established top-down offsets")
height = controls.StackCards(parent, { first, second }, 8)
assert(height == 196 and parent.height == 196 and second.point[5] == -108,
    "card stacking must support an explicit reusable spacing rule")
assert(controls.StackCards(nil, {}) == 0,
    "missing card parents must fail closed")

print("PASS: shared choice selection and card stacking presentation")

-- Paragraph sizing must not reuse a native height constrained by the last
-- message. It must also shrink again when a short message replaces a long one.
do
    local text = {height = 12, naturalHeight = 240}
    function text:SetHeight(height) self.height = height end
    function text:GetStringHeight()
        return self.height > 0 and math.min(self.height, self.naturalHeight) or self.naturalHeight
    end
    local height = controls.FitParagraphText(text, "Full instructions", 600)
    assert(height == 240 and text.height == 240,
        "previous clipped text height must not constrain the next measurement")
    text.naturalHeight = 18
    height = controls.FitParagraphText(text, "Short", 600)
    assert(height < 240 and text.height == height,
        "paragraphs must release old reserved height when their content shrinks")
    text.GetStringHeight = function() return 12 end
    height = controls.FitParagraphText(text, "First step\n\nSecond step\n\nThird step", 600)
    assert(height > 5 * 18,
        "stale native metrics must not discard paragraphs or blank lines")
end
print("PASS: paragraph sizing clears old constraints and retains complete messages")
