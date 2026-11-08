-- Plain Lua cannot create WoW secret values. Mark ordinary matching strings as
-- secret to verify that discovery rejects them rather than choosing a false menu.
-- Native secret-key enforcement and Gamepad focus still require live Forever QA.

local function object(parent, width, height)
    local frame = { parent = parent, width = width or 100, height = height or 40 }
    function frame:GetName() return "TestRadial" end
    function frame:GetParent() return self.parent end
    function frame:GetWidth() return self.width end
    function frame:GetHeight() return self.height end
    function frame:IsShown() return true end
    function frame:IsForbidden() return false end
    function frame:GetChildren() return unpack(self.children or {}) end
    function frame:GetRegions() return unpack(self.regions or {}) end
    function frame:GetNumPoints() return 1 end
    function frame:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
    function frame:ClearAllPoints() error("discovery must not move native frames") end
    function frame:SetPoint() error("discovery must not move native frames") end
    return frame
end

local function discover(options)
    UIParent = object(nil, 4000, 2560)
    local radial = object(UIParent, 600, 600)
    local title = object(radial)
    local option = object(radial)
    title.regions = {{ GetText = function() return options.title or "Main Menu" end }}
    -- Exercise text on a button as well as a FontString region.
    option.GetText = function() return options.option or "Game Menu" end
    radial.children = { title, option }

    local resource = object(UIParent)
    resource.regions = {
        { GetText = function() error("unreadable region") end },
        { GetText = function() return nil end },
        { GetText = function() return 42 end },
        { GetText = function() return "" end },
        { GetText = function() return "resource-secret" end },
    }
    if options.enumerated then
        UIParent.children = { resource }
        local frames = { resource, radial, title, option }
        EnumerateFrames = function(previous)
            if not previous then return frames[1] end
            for index, frame in ipairs(frames) do
                if frame == previous then return frames[index + 1] end
            end
        end
    else
        -- Traversal is reversed, so inspect the unrelated resource first.
        UIParent.children = { radial, resource }
        EnumerateFrames = nil
    end

    local checks = {}
    issecretvalue = options.noDetector and nil or function(value)
        if options.detectorError then error("secret inspection unavailable") end
        if value ~= nil then checks[value] = (checks[value] or 0) + 1 end
        return value == "resource-secret" or value == options.secret
    end
    if options.noDetector then issecretvalue = nil end
    FRAME_LABEL_MAIN_MENU = options.globalTitle
    RADIAL_LABEL_GAME_MENU = options.globalOption

    local addon = {
        isForever = true, db = { enabled = true },
        Mainhand = { GetRect = function()
            return { width = 4000, height = 2560, isSpanned = false }
        end },
        MainhandGeometry = {
            Number = function(value) return tonumber(value) end,
            IsPlayerCombatRestricted = function() return false end,
        },
        MainhandCompatibility = { IsNativeGamepadInterface = function() return true end },
    }
    assert(loadfile("Core/MainhandGamepad.lua"))("Offhand", addon)
    local moved, reason = addon.Mainhand:CenterForeverGamepadMainMenu()
    assert(not moved, "discovery must not change anchors outside a span")
    return reason, checks, addon.Mainhand:GetForeverGamepadMainMenuDiagnostics()
end

for _, enumerated in ipairs({ false, true }) do
    local reason, checks = discover({ enumerated = enumerated, secret = "Main Menu" })
    assert(reason == "not-found", "secret heading must not identify a radial")
    assert(checks["Main Menu"], "heading must pass through the secret check")

    reason, checks = discover({ enumerated = enumerated, secret = "Game Menu" })
    assert(reason == "not-found", "secret option must not identify a radial")
    assert(checks["Game Menu"], "button text must pass through the secret check")

    local status
    reason, checks, status = discover({ enumerated = enumerated })
    assert(reason == "inactive" and status == "located:TestRadial",
        "valid radial must remain discoverable after unreadable/secret resource text")
    assert(checks["resource-secret"], "resource text must be checked in both scan paths")

    reason = discover({ enumerated = enumerated, detectorError = true })
    assert(reason == "not-found", "failed secret inspection must skip the text")

    reason = discover({ enumerated = enumerated, noDetector = true })
    assert(reason == "inactive", "clients without secret APIs must retain discovery")

    reason = discover({ enumerated = enumerated, title = "Private heading",
        globalTitle = "Private heading", secret = "Private heading" })
    assert(reason == "not-found", "secret localized heading must not enter the label set")

    reason = discover({ enumerated = enumerated, option = "Private option",
        globalOption = "Private option", secret = "Private option" })
    assert(reason == "not-found", "secret localized option must not enter the label set")
end

print("Forever Gamepad menu secret-text tests passed")
