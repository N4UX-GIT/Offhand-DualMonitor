-- Exercise the real entry dispatcher, Config and release dialog with mock UI.
StaticPopupDialogs, SlashCmdList = {}, {}
local frames, timers, cvars = {}, {}, {}
local combat, gamepad, cinematic = false, false, false
local metadata = {}
for line in io.lines("Offhand.toc") do
    local key, value = line:match("^## ([^:]+):%s*(.-)%s*$")
    if key then metadata[key] = value end
end

GetBuildInfo = function() return "1.60.1", "70888", "synthetic", 16001 end
GetAddOnMetadata = function(_, key) return metadata[key] end
InCombatLockdown = function() return combat end
RegisterCVar = function(key, default) if cvars[key] == nil then cvars[key] = default end end
GetCVar = function(key) return cvars[key] end
SetCVar = function(key, value) cvars[key] = tostring(value) end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
GetScreenWidth = function() return 1920 end
strtrim = function(s) return s:match("^%s*(.-)%s*$") end
strsplit = function(_, s) return s:match("^(%S+)%s*(.*)$") end

local function Widget(_, name, parent)
    local f = { shown = true, scripts = {}, children = {}, scale = 1 }
    function f:RegisterEvent() end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:CreateFontString() return Widget() end
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetScale(scale) self.scale = scale end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = {...} end
    function f:SetText(text) self.text = text end
    function f:SetTextColor() end
    function f:SetFrameStrata() end
    function f:SetClampedToScreen() end
    function f:EnableMouse() end
    function f:SetJustifyH() end
    function f:SetJustifyV() end
    function f:SetAutoFocus() end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:ClearFocus() self.focus = false end
    function f:SetFocus() self.focus = true end
    function f:HighlightText() self.highlight = true end
    if name then frames[name] = f end
    if parent then parent.children[#parent.children + 1] = f end
    return f
end
CreateFrame = Widget
UIParent = Widget()
UIParent:SetSize(1920, 1080)

local metrics = { isSpanned = true, gameLeft = 1200, gameRight = 1920,
    gameBottom = 0, gameTop = 900, gameWidth = 720, gameHeight = 900 }
local function Load(account)
    frames, timers = {}, {}
    OffhandDB, OffhandCharDB = account, {}
    local addon = {}
    for _, path in ipairs({"Core/Init", "Core/ClientRuntime", "Core/Config", "Core/Viewport",
        "Locales/enUS", "UI/Controls", "UI/WhatsNew"}) do
        assert(loadfile(path .. ".lua"))("Offhand", addon)
    end
    addon:InitializeConfig()
    addon.guideOpened = 0
    addon.Onboarding = { Open = function() addon.guideOpened = addon.guideOpened + 1 end }
    addon.ApplyFullLayout = function() end
    addon.IsBlizzardInputReserved = function() return cinematic end
    addon.IsGamepadUIEnabled = function() return gamepad end
    addon.Viewport.GetMetrics = function() return metrics end
    return addon
end

local function Event(name)
    local eventFrame = assert(frames.OffhandEventFrame)
    eventFrame.scripts.OnEvent(eventFrame, name)
end

local function Flush()
    local count = 0
    while #timers > 0 do
        count = count + 1
        assert(count < 20, "unexpected entry loop")
        table.remove(timers, 1)()
    end
end

local function Login()
    Event("PLAYER_LOGIN")
    Event("PLAYER_ENTERING_WORLD")
    Flush()
end

local addon = Load()
local firstRelease = addon.fullVersion
assert(not frames.OffhandWhatsNewFrame, "login dialog must be created lazily")
OffhandCompanionTopology = { companionVersion = "2.1.7-beta.9" }
Login()
local dialog = assert(frames.OffhandWhatsNewFrame)
assert(dialog:IsShown() and addon.guideOpened == 0 and OffhandDB.lastSeenRelease == nil)
assert(dialog.title.text:find(firstRelease, 1, true) and dialog.point[4] == 1560)
assert(not dialog.body.text:find(addon.L.WHATS_NEW_FALLBACK, 1, true),
    "publish concise in-game highlights for the version in the TOC")
assert(dialog.body.text:find("2.1.7-beta.9", 1, true) and dialog.storeButton.uiPrimary,
    "an earlier Companion beta should offer the confirmed Store update")
assert(not dialog.link:IsShown() and not dialog.link.focus, "login must not take keyboard focus")
dialog.storeButton.scripts.OnClick()
assert(dialog.link.text == addon.companionStoreUrl and dialog.link.focus and dialog.link.highlight)
dialog.children[3].scripts.OnClick() -- Release notes link.
assert(dialog.link.text:sub(-#firstRelease) == firstRelease, "full notes must match the loaded release")
assert(dialog:GetHeight() - 44 > 52 + dialog.body:GetHeight(), "footer overlaps release notes")

cinematic = true
Event("PLAYER_CONTROL_LOST")
assert(not dialog:IsShown() and not dialog.link.focus and OffhandDB.lastSeenRelease == nil)
cinematic = false
Event("PLAYER_CONTROL_GAINED")
Flush()
assert(dialog:IsShown() and not dialog.link:IsShown(), "interrupted notice must return unread")
dialog.children[1].scripts.OnClick() -- Title-bar close button.
Flush()
assert(addon.guideOpened == 1 and OffhandDB.lastSeenRelease == firstRelease,
    "dismissal should resume the normal startup guide and save the account-wide release")
Event("PLAYER_ENTERING_WORLD")
Flush()
assert(not dialog:IsShown() and addon.guideOpened == 1)

addon = Load(OffhandDB)
addon:MarkSetupComplete()
OffhandCompanionTopology = { companionVersion = "2.2.0" }
Login()
assert(not frames.OffhandWhatsNewFrame, "reload/character swap must not repeat the notice")
gamepad = true
SlashCmdList.OFFHAND("whatsnew")
dialog = assert(frames.OffhandWhatsNewFrame)
assert(dialog:IsShown() and not dialog.storeButton.uiPrimary, "newer Companion must not get an update prompt")
dialog.storeButton.scripts.OnClick()
assert(dialog.link.text == addon.companionStoreUrl and not dialog.link.focus,
    "controller mode should not force keyboard focus")
addon.WhatsNew:Dismiss()
gamepad = false

local account = OffhandDB
metadata["X-Offhand-Release"] = ""
metadata["X-Offhand-Addon-Release"] = ""
addon = Load(account)
OffhandCompanionTopology = nil
combat = true
Login()
assert(not frames.OffhandWhatsNewFrame and OffhandDB.lastSeenRelease == firstRelease)
combat = false
Event("PLAYER_REGEN_ENABLED")
Flush()
dialog = assert(frames.OffhandWhatsNewFrame)
assert(dialog:IsShown() and dialog.body.text:find(addon.L.WHATS_NEW_FALLBACK, 1, true)
    and dialog.storeButton.uiPrimary and not dialog.body.text:find("last used", 1, true),
    "a new stable release should show a link and avoid guessing an absent Companion version")
addon.WhatsNew:Dismiss()
Flush()
assert(account.lastSeenRelease == addon.fullVersion)

metadata["X-Offhand-Release"] = firstRelease:match("-(.+)$")
addon = Load(account)
Login()
assert(not frames.OffhandWhatsNewFrame, "rolling back to a beta must not replace newer acknowledgement")
assert(addon.ForeverPersistence:SaveProfileSnapshot(true))
addon = Load({ foreverPersistenceRevision = 0 })
assert(OffhandDB.lastSeenRelease == account.lastSeenRelease and not addon.WhatsNew:HasUnseenRelease(),
    "the account-wide acknowledgement must survive the Forever fallback")
cvars = {}
addon = Load()
addon:SetOnboardingResumeStep(4)
Login()
assert(addon.guideOpened == 1 and not frames.OffhandWhatsNewFrame and OffhandDB.lastSeenRelease == nil,
    "a saved setup handoff should take priority without consuming the release")
print("PASS: release login, acknowledgement, replay, Store handoff and deferrals")
