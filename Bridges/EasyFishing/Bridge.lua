-- EasyFishing bridge (built into Offhand).
-- EasyFishing shows a "+1 Fishing (76)" popup on each Fishing skill-up,
-- anchored once to the top-centre of UIParent (Tackle.lua ShowSkillUp). With
-- Offhand spanning UIParent across monitors, that centre is the seam between
-- them, so the text is split in half. The popup is an unnamed frame EasyFishing
-- makes on the first skill-up, so on each skill-up message this file looks for
-- it among UIParent's children (by its size, strata, text and timer) and
-- re-anchors it to the top-centre of the game rectangle. EasyFishing never
-- moves it again, so the anchor sticks; later refreshes only follow the game
-- rectangle, and put EasyFishing's own anchor back when not spanned.
--
-- EasyFishing's named frames (EasyFishing.lua: session window, cast button,
-- line-out indicator, glow preview, settings window, debug console; Tackle.lua
-- BuildBadge: lure badge) default to spots measured from UIParent's centre, so
-- they hit the seam too. Any of them still at EasyFishing's own default spot is
-- moved to the same spot of the game rectangle. A frame the player dragged is
-- left alone, and so is the lure badge while it hangs off the cast button. The
-- cast button and lure badge are secure, so they are only moved out of combat.
-- Messages EasyFishing prints through Blizzard's own error and raid-warning
-- frames are not handled here.
-- Contributed by Kintrok (@DCtheGeek).

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or type(API.GetBridgeNamespace) ~= "function" then return end
local Shared = API.GetBridgeNamespace("Shared")
if type(Shared) ~= "table" or type(Shared.Available) ~= "function" or not Shared.Available("EasyFishing") then return end

-- frame name -> { point, relativePoint, x, y }: EasyFishing's own default anchor on UIParent.
local fitter = Shared.NewAnchorFitter({
    EasyFishingSessionWindow = { "CENTER", "CENTER", 330, 20 },   -- EasyFishing.lua CreateSessionWindow
    EasyFishingButton = { "CENTER", "CENTER", 0, -140 },          -- LayoutCastButton (secure)
    EasyFishingIndicator = { "CENTER", "CENTER", 0, -90 },        -- LayoutIndicator
    EasyFishingLureBadge = { "CENTER", "CENTER", 60, -140 },      -- Tackle.lua BuildBadge, when there is no cast button (secure)
    EasyFishingGlow = { "CENTER", "CENTER", 0, -60 },             -- Glow.Anchor preview; on a nameplate otherwise
    EasyFishingSettings = { "CENTER", "CENTER", 0, 0 },
    EasyFishingDebugConsole = { "CENTER", "CENTER", 0, 0 },
})
local bridge = {}

-- ---------------------------------------------------------------------
-- Skill-up popup
-- ---------------------------------------------------------------------

local DROP = 170                     -- EasyFishing's distance below the top
local WIDE, HIGH = 300, 40           -- EasyFishing's popup size

local popup
local placed = 0

-- The anchor is not checked: once moved it no longer matches.
local function isPopup(f)
    if type(f) ~= "table" or type(f.IsForbidden) ~= "function" or f:IsForbidden() then return false end
    if f:GetObjectType() ~= "Frame" or f:GetName() ~= nil then return false end
    if type(f.text) ~= "table" or type(f.text.SetText) ~= "function" then return false end
    if type(f.t) ~= "number" then return false end
    if f:GetFrameStrata() ~= "HIGH" then return false end
    local w, h = f:GetWidth(), f:GetHeight()
    if type(w) ~= "number" or type(h) ~= "number" then return false end
    if math.abs(w - WIDE) > 1 or math.abs(h - HIGH) > 1 then return false end
    return f:GetScript("OnUpdate") ~= nil
end

local function find()
    if popup then return popup end
    local ok, kids = pcall(function() return { UIParent:GetChildren() } end)
    if ok then
        for i = #kids, 1, -1 do   -- the popup is among the newest children
            local kid = kids[i]
            local good, yes = pcall(isPopup, kid)
            if good and yes then
                popup = kid
                return popup
            end
        end
    elseif type(EnumerateFrames) == "function" then
        -- too many children for one GetChildren() call; walk every frame instead
        pcall(function()
            local f = EnumerateFrames()
            while f do
                local good, yes = pcall(isPopup, f)
                if good and yes and f:GetParent() == UIParent then
                    popup = f
                    return
                end
                f = EnumerateFrames(f)
            end
        end)
        return popup
    end
    return nil
end

-- Spanned: the top-centre of the game rectangle. Not spanned: EasyFishing's own
-- anchor, but only when the popup still has the anchor this file gave it.
local function place()
    if not popup then return false end
    local point, relPoint, x, y
    local count = popup:GetNumPoints()
    local p, rel, rp, cx, cy = popup:GetPoint(1)
    local single = count == 1 and (rel == nil or rel == UIParent)
    if Shared.IsSpanned() then
        local l, _, r, t = Shared.GameRect()
        point, relPoint, x, y = "TOP", "BOTTOMLEFT", (l + r) / 2, t - DROP
    else
        if not (single and p == "TOP" and rp == "BOTTOMLEFT") then return false end
        point, relPoint, x, y = "TOP", "TOP", 0, -DROP
    end
    if single and p == point and rp == relPoint and Shared.Near(cx, x) and Shared.Near(cy, y) then return false end
    popup:ClearAllPoints()
    popup:SetPoint(point, UIParent, relPoint, x, y)
    placed = placed + 1
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_SKILL")
events:SetScript("OnEvent", function()
    -- EasyFishing's handler normally ran first and made the popup
    pcall(find)
    pcall(place)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            pcall(find)
            pcall(place)
        end)
    end
end)

function bridge:Refresh(reason)
    fitter:Refresh()
    -- Never search from here: the search walks every UIParent child and only a
    -- skill-up can create the popup.
    if popup then pcall(place) end
end

function bridge:GetDiagnostics()
    return Shared.Describe("EasyFishingAnchors", fitter) .. " EasyFishingPopup=" .. (popup and tostring(placed) or "-")
end

if Shared.Register("EasyFishing", bridge) then bridge:Refresh("load") end
