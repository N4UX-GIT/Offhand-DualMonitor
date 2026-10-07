--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/LegacyWrathCompat.lua: minimal compatibility services for WoW 3.3.5a

    This file is loaded first on every client, but changes global behavior only
    on the original Wrath 3.3.x interface family. Modern clients retain their
    native timer and display APIs.
--]]

local _, Offhand = ...

local interfaceVersion = GetBuildInfo and select(4, GetBuildInfo()) or 0
local isLegacyWrath = interfaceVersion >= 30000 and interfaceVersion < 30400

Offhand.legacyWrathInterface = isLegacyWrath and interfaceVersion or nil

if not isLegacyWrath then return end

-- C_Timer was added after the original Wrath client. Supply only the small
-- After/NewTimer/NewTicker surface used by Offhand, driven by one OnUpdate
-- frame. Timer callbacks remain asynchronous even when the delay is zero.
if not C_Timer then
    Offhand.legacyTimerShim = true
    local pending = {}
    local driver = CreateFrame("Frame")

    local function CancelTimer(timer)
        timer.cancelled = true
    end

    local function IsTimerCancelled(timer)
        return timer.cancelled == true
    end

    local function Schedule(delay, callback, interval, iterations)
        if type(callback) ~= "function" then return nil end

        local timer = {
            callback = callback,
            cancelled = false,
            remaining = math.max(0, tonumber(delay) or 0),
            interval = interval,
            iterations = iterations,
            fired = 0,
            Cancel = CancelTimer,
            IsCancelled = IsTimerCancelled,
        }
        pending[#pending + 1] = timer
        driver:Show()
        return timer
    end

    driver:SetScript("OnUpdate", function(_, elapsed)
        for index = #pending, 1, -1 do
            local timer = pending[index]
            if timer.cancelled then
                table.remove(pending, index)
            else
                timer.remaining = timer.remaining - elapsed
                if timer.remaining <= 0 then
                    timer.fired = timer.fired + 1
                    local repeats = timer.interval ~= nil
                        and (timer.iterations == nil or timer.fired < timer.iterations)
                    if repeats and not timer.cancelled then
                        timer.remaining = math.max(0.001, timer.interval + timer.remaining)
                    else
                        table.remove(pending, index)
                        timer.cancelled = true
                    end
                    timer.callback(timer)
                end
            end
        end
        if #pending == 0 then driver:Hide() end
    end)
    driver:Hide()

    C_Timer = {}
    function C_Timer.After(delay, callback)
        Schedule(delay, callback)
    end
    function C_Timer.NewTimer(delay, callback)
        return Schedule(delay, callback)
    end
    function C_Timer.NewTicker(interval, callback, iterations)
        interval = math.max(0.001, tonumber(interval) or 0.001)
        return Schedule(interval, callback, interval, tonumber(iterations))
    end
end

-- GetPhysicalScreenSize is also newer than 3.3.5a. Prefer the render-size
-- CVars because they preserve a manually spanned custom window. Fall back to
-- UIParent's physical scale when the client does not expose a parseable CVar.
if not GetPhysicalScreenSize then
    local function ParseResolution(value)
        local width, height = tostring(value or ""):match("(%d+)%s*[xX]%s*(%d+)")
        width, height = tonumber(width), tonumber(height)
        if width and height and width > 0 and height > 0 then return width, height end
    end

    function GetPhysicalScreenSize()
        if GetCVar then
            local width, height = ParseResolution(GetCVar("gxWindowedResolution"))
            if width then
                Offhand.legacyPhysicalSizeSource = "gxWindowedResolution"
                return width, height
            end
            width, height = ParseResolution(GetCVar("gxResolution"))
            if width then
                Offhand.legacyPhysicalSizeSource = "gxResolution"
                return width, height
            end
        end

        local scale = UIParent and UIParent.GetEffectiveScale
            and UIParent:GetEffectiveScale() or 1
        local width = GetScreenWidth and GetScreenWidth() or 0
        local height = GetScreenHeight and GetScreenHeight() or 0
        Offhand.legacyPhysicalSizeSource = "ui-scale-fallback"
        return math.floor(width * scale + 0.5), math.floor(height * scale + 0.5)
    end
end
