--[[
    Offhand: Multi-Monitor Setup Addon
    Bridges/Questie/Options.lua: built-in bridge for Questie's standalone
    settings window

    This is the former Questie part of the addon options window fitting in
    Core/PopupBounds.lua, moved behind the bridge contract; its behaviour is
    unchanged. The generic fitting helpers stay in core and are read through
    Offhand.API.GetOptionsWindowHelpers(); the options metrics through
    Offhand.API.GetOptionsMetrics().

    It registers its own id, QuestieOptions, on the Forever client only (the
    core code ran there only), before Questie exists and whether or not the
    default-anchor Questie bridge beside it is active: InitializePopupWindows()
    installs the QuestieOptionsEngine.ShowFrame hook when the popup bounds
    handling initializes and again on Questie's ADDON_LOADED, and
    RefreshAddonOptions(getMetrics) runs with every popup layout pass and after
    combat.
--]]

local ADDON_NAME, shared = ...
local Offhand = type(shared) == "table" and (shared.Offhand or (shared.API and shared)) or _G.Offhand
local API = type(Offhand) == "table" and Offhand.API
if type(API) ~= "table" or API.BRIDGE_CONTRACT ~= 1 or type(API.RegisterBridge) ~= "function"
    or type(API.IsForeverClient) ~= "function" or type(API.GetOptionsMetrics) ~= "function"
    or type(API.GetOptionsWindowHelpers) ~= "function" then return end
if not API.IsForeverClient() then return end
local helpers = API.GetOptionsWindowHelpers()
if type(helpers) ~= "table" then return end

local CanLayoutAddonOptions, SetWindowPoint = helpers.CanLayoutAddonOptions, helpers.SetWindowPoint
local OwnsOptionsPoint, FitAddonOptions = helpers.OwnsOptionsPoint, helpers.FitAddonOptions
local GetOptionsMetrics = API.GetOptionsMetrics

local addonOptions = setmetatable({}, { __mode = "k" })

local function RefreshQuestieOptions(frame, metrics)
    if not CanLayoutAddonOptions(frame) then return end
    local state = addonOptions[frame]
    if not state then
        if not metrics or not frame:IsShown() or frame:GetParent() ~= UIParent then return end
        state = {}
        addonOptions[frame] = state
    end
    local height = frame:GetHeight()
    if not metrics or frame:GetParent() ~= UIParent then
        if height == state.height then
            local target = math.max(1, math.floor(UIParent:GetHeight() * 0.7))
            if height ~= target then frame:SetHeight(target) end
        end
        if OwnsOptionsPoint(frame, state) then SetWindowPoint(frame, state.original) end
        addonOptions[frame] = nil
        return
    end
    if not frame:IsShown() or frame.isMoving then return end

    -- Questie keeps its lazily created frame, so resize on layout changes too.
    local target = math.max(1, math.floor((metrics.gameTop - metrics.gameBottom)
        * UIParent:GetEffectiveScale() / frame:GetEffectiveScale() * 0.7))
    if height ~= target then frame:SetHeight(target) end
    state.height = frame:GetHeight()
    FitAddonOptions(frame, state, metrics)
end

local bridge = { contract = API.BRIDGE_CONTRACT }

-- getMetrics() returns the options metrics of this layout pass (nil while
-- Offhand is off or not spanned).
function bridge:RefreshAddonOptions(getMetrics)
    local questie = _G.QuestieStandaloneSettings
    if not questie then return end
    RefreshQuestieOptions(questie, getMetrics())
end

function bridge:InitializePopupWindows()
    if not hooksecurefunc or not CreateFrame then return end
    local questieHooked
    local function installHooks()
        local loader = _G.QuestieLoader
        local engine = loader and loader._modules and loader._modules.QuestieOptionsEngine
        if not questieHooked and engine and type(engine.ShowFrame) == "function" then
            questieHooked = true
            hooksecurefunc(engine, "ShowFrame", function()
                RefreshQuestieOptions(_G.QuestieStandaloneSettings, GetOptionsMetrics())
            end)
        end
    end
    local observer = CreateFrame("Frame")
    observer:RegisterEvent("ADDON_LOADED")
    observer:SetScript("OnEvent", function(_, _, name)
        if name == "Questie" then installHooks() end
    end)
    installHooks()
end

API.RegisterBridge("QuestieOptions", bridge)
