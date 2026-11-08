-- Fresh Config state plus the actual entry handler, not an already-enabled mock.
-- Synthetic client identities and UI/timers only; no native-client acceptance.
StaticPopupDialogs, SlashCmdList = {}, {}
local entryEvent, queue, cvars = nil, {}, {}
local version, build, interface = "1.60.1", "70790", 16001
GetBuildInfo = function() return version, build, "synthetic", interface end
InCombatLockdown = function() return false end
CreateFrame = function(_, name)
    return {
        RegisterEvent = function() end,
        SetScript = function(_, script, callback)
            if name == "OffhandEventFrame" and script == "OnEvent" then entryEvent = callback end
        end,
    }
end
UIParent = { GetEffectiveScale = function() return 1 end }
GetScreenWidth = function() return 1920 end
GetPhysicalScreenSize = function() return 1920, 1080 end
RegisterCVar = function(name, default) if cvars[name] == nil then cvars[name] = default or "" end end
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value) cvars[name] = tostring(value) end
UnitName = function() return "Tester" end
UnitFullName = function() return "Tester", "Realm" end
GetNormalizedRealmName = function() return "Realm" end
C_Timer = { After = function(_, callback) queue[#queue + 1] = callback end }

local function NewAddon(account, character)
    OffhandDB, OffhandCharDB = account, character
    queue = {}
    local addon = {}
    assert(loadfile("Core/Init.lua"))("Offhand", addon)
    assert(loadfile("Core/ClientRuntime.lua"))("Offhand", addon)
    assert(loadfile("Core/Config.lua"))("Offhand", addon)
    addon:InitializeConfig()
    addon.opened = 0
    addon.Onboarding = { Open = function() addon.opened = addon.opened + 1 end }
    addon.IsBlizzardInputReserved = function() return addon.reserved == true end
    addon.HideCompanionNotices = function() end
    addon.HideResolvedSpanPrompts = function() end
    addon.RefreshCompanionNoticeState = function() return false end
    addon.RefreshMainhandLayoutAttention = function() end
    addon.ApplyFullLayout = function() end
    addon.Viewport = { GetMetrics = function() return { isSpanned = false } end }
    addon.Canvas = {}
    return addon
end
local function Flush(limit)
    local count = 0
    while #queue > 0 and (not limit or count < limit) do
        count = count + 1
        assert(count < 20, "entry guidance polled indefinitely")
        table.remove(queue, 1)()
    end
end
local function Enter(addon, first, limit)
    if first then addon._hasEnteredWorld = nil end
    entryEvent(nil, "PLAYER_ENTERING_WORLD")
    Flush(limit)
end

local addon = NewAddon()
assert(addon.isForever and addon.db.enabled == false and not addon:IsSetupComplete())
Enter(addon, true)
assert(addon.opened == 1, "fresh disabled Forever profiles must receive the preparation guide")
assert(addon.db.enabled == false and not addon:IsSetupComplete(),
    "showing preparation must not activate a guessed viewport or finish setup")
Enter(addon, false)
assert(addon.opened == 1, "zone transitions must not repeatedly reopen setup")

addon:SetOnboardingSetupMethod("COMPANION")
addon:SetOnboardingResumeStep(4)
addon = NewAddon() -- Simulate missing normal SavedVariables with session CVars retained.
assert(addon:GetOnboardingResumeStep() == 4 and addon.db.enabled == false)
Enter(addon, true)
assert(addon.opened == 1, "placement Reload UI must resume before calibration enables Offhand")

addon:SetEnabled(false)
addon = NewAddon()
assert(addon:GetOnboardingResumeStep() == 4,
    "disabling must preserve setup progress for an explicit return")
Enter(addon, true)
assert(addon.opened == 0, "explicit disable must suppress even a saved setup resume across reload")
addon:SetAutomaticSetupSuppressed(false) -- The explicit guide/wizard entry points do this.
addon = NewAddon()
Enter(addon, true)
assert(addon.opened == 1 and addon.db.enabled == false,
    "explicitly returning to setup must survive reload without enabling the viewport")

addon:MarkWelcomeDismissed()
addon:SetOnboardingResumeStep(nil)
addon = NewAddon()
Enter(addon, true)
assert(addon.opened == 1, "acknowledging preparation must not strand uncalibrated disabled users")
addon:MarkSetupComplete()
addon = NewAddon()
Enter(addon, true)
assert(addon.opened == 0, "completed disabled accounts must stay quiet")
addon:SetEnabled(true)
Enter(addon, true)
assert(addon.opened == 0, "completed enabled accounts must stay quiet")

cvars = {}
addon = NewAddon()
addon.reserved = true
Enter(addon, true, 2)
assert(addon.opened == 0 and #queue == 1,
    "first-launch guidance must defer while Blizzard owns cinematic input")
addon.reserved = false
Flush()
assert(addon.opened == 1 and addon.db.enabled == false,
    "deferred fresh guidance must open after cinematic input is released")

-- Shared path: ordinary SavedVariables must carry the opt-out on other clients.
for _, client in ipairs({{"12.1.7", "synthetic", 121700}, {"1.15.9", "synthetic", 11509}}) do
    version, build, interface = unpack(client)
    cvars = {}
    addon = NewAddon()
    Enter(addon, true)
    assert(addon.opened == 1 and addon.db.enabled == false, "shared fresh setup must open without activation")
    addon:SetEnabled(false)
    local savedAccount, savedCharacter = OffhandDB, OffhandCharDB
    addon = NewAddon(savedAccount, savedCharacter)
    Enter(addon, true)
    assert(addon.opened == 0, "ordinary SavedVariables must preserve explicit setup suppression")
    addon:SetEnabled(true)
    Enter(addon, true)
    assert(addon.opened == 1, "explicit enable must allow incomplete setup guidance again")
end
version, build, interface = "1.60.1", "70790", 16001
cvars = {}
addon = NewAddon()
addon:SetEnabled(false)
assert(addon.ForeverPersistence:SaveProfileSnapshot(true))
cvars.offhandForeverDisplayFlags = nil
addon = NewAddon({foreverPersistenceRevision = 0})
Enter(addon, true)
assert(addon.foreverPersistenceDiagnostics.source == "session-fallback"
        and addon.db.automaticSetupSuppressed == true and addon.opened == 0,
    "complete Forever snapshot recovery must preserve the explicit setup opt-out")
print("PASS: fresh launch, inactive viewport, placement resume, explicit disable, persistence and cinematic deferral")
