-- Both menu APIs must route unconfigured users through window preparation.
local frames = {}
local function Frame()
    return setmetatable({scripts = {}}, {__index = function(self, key)
        if key == "SetScript" then return function(_, event, callback) self.scripts[event] = callback end end
        if key == "CreateTexture" then return Frame end
        return function() end
    end})
end
CreateFrame = function(_, name)
    local frame = Frame()
    if name then frames[name] = frame end
    return frame
end
UIParent, Minimap = {}, {}
local complete, guides, wizards, options = false, 0, 0, 0
local addon = {
    L = setmetatable({}, {__index = function(_, key) return key end}),
    IsSetupComplete = function() return complete end,
    Onboarding = {Open = function() guides = guides + 1 end},
    Wizard = {Open = function() wizards = wizards + 1 end},
    Options = {Open = function() options = options + 1 end},
}
assert(loadfile("UI/Minimap.lua"))("Offhand", addon)
local icon, selectedAction = frames.OffhandMinimapIcon, nil
MenuUtil = {CreateContextMenu = function(_, build)
    build(nil, {
        CreateTitle = function() end,
        CreateDivider = function() end,
        CreateButton = function(_, label, action)
            if label == addon.L.MINIMAP_MENU_WIZARD then selectedAction = action end
        end,
    })
end}
EasyMenu = function(items)
    for _, item in ipairs(items) do
        if item.text == addon.L.MINIMAP_MENU_WIZARD then selectedAction = item.func end
    end
end
for _, modern in ipairs({true, false}) do
    if not modern then MenuUtil = nil end
    complete, selectedAction = false, nil
    icon.scripts.OnClick(icon, "RightButton")
    assert(selectedAction, "setup action must exist in both menu implementations")
    local beforeGuides, beforeWizards = guides, wizards
    selectedAction()
    assert(guides == beforeGuides + 1 and wizards == beforeWizards,
        "incomplete setup must open preparation before calibration")
    complete = true
    selectedAction()
    assert(wizards == beforeWizards + 1 and guides == beforeGuides + 1,
        "completed setup must retain direct calibration access")
end
icon.scripts.OnClick(icon, "LeftButton")
assert(options == 1, "left click must retain settings access")
print("PASS: modern and legacy minimap setup entries prepare new users before calibration")
