-- WoW 3.3.5a compatibility must supply only the missing runtime primitives
-- and must leave later clients' native implementations untouched.

local interfaceVersion = 30300
GetBuildInfo = function() return "3.3.5", "12340", "Jan 1 2010", interfaceVersion end

local driver
CreateFrame = function()
    driver = { shown = true, scripts = {} }
    function driver:SetScript(name, callback) self.scripts[name] = callback end
    function driver:Show() self.shown = true end
    function driver:Hide() self.shown = false end
    return driver
end

UIParent = {
    GetEffectiveScale = function() return 0.75 end,
}
GetScreenWidth = function() return 2560 end
GetScreenHeight = function() return 1440 end
GetCVar = function(name)
    if name == "gxWindowedResolution" then return "4480x1440" end
end

C_Timer = nil
GetPhysicalScreenSize = nil

local addon = {}
assert(loadfile("Core/LegacyWrathCompat.lua"))("Offhand", addon)
assert(addon.legacyWrathInterface == 30300,
    "3.3.5a must be identified as the legacy Wrath interface")
assert(C_Timer and C_Timer.After and C_Timer.NewTimer and C_Timer.NewTicker,
    "legacy Wrath must receive the timer subset used by Offhand")
local width, height = GetPhysicalScreenSize()
assert(width == 4480 and height == 1440,
    "legacy physical bounds must prefer the manually spanned window CVar")
assert(addon.legacyTimerShim and addon.legacyPhysicalSizeSource == "gxWindowedResolution",
    "legacy diagnostics must identify the compatibility services in use")

local afterCalls, timerCalls, tickerCalls = 0, 0, 0
C_Timer.After(0, function() afterCalls = afterCalls + 1 end)
local cancelled = C_Timer.NewTimer(0, function() timerCalls = timerCalls + 1 end)
cancelled:Cancel()
local ticker = C_Timer.NewTicker(0.1, function() tickerCalls = tickerCalls + 1 end, 2)
assert(driver.shown and driver.scripts.OnUpdate,
    "scheduling a legacy timer must activate the shared update driver")
driver.scripts.OnUpdate(driver, 0.1)
driver.scripts.OnUpdate(driver, 0.1)
assert(afterCalls == 1 and timerCalls == 0 and tickerCalls == 2,
    "legacy timers must execute, repeat, and cancel with C_Timer semantics")
assert(ticker:IsCancelled() and not driver.shown,
    "completed legacy timers must leave the shared driver idle")

local nativeTimer = {}
local nativePhysical = function() return 1, 2 end
C_Timer = nativeTimer
GetPhysicalScreenSize = nativePhysical
interfaceVersion = 30405
local modernAddon = {}
assert(loadfile("Core/LegacyWrathCompat.lua"))("Offhand", modernAddon)
assert(modernAddon.legacyWrathInterface == nil and C_Timer == nativeTimer
        and GetPhysicalScreenSize == nativePhysical,
    "later clients must retain their native timer and display APIs")

local init = assert(io.open("Core/Init.lua", "r")):read("*a")
assert(init:find("Offhand.isLegacyWrath", 1, true)
        and init:find("local hasProjectIdentity", 1, true),
    "client detection must not compare absent project constants as equal nils")

print("PASS: WoW 3.3.5a compatibility primitives and modern-client isolation")
