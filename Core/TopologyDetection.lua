-- Display topology recommendations shared by settings, onboarding, and setup.
local _, Offhand = ...
local Detection = {}
Offhand.TopologyDetection = Detection

function Detection.Detect()
    local physW, physH
    if GetPhysicalScreenSize then
        pcall(function() physW, physH = GetPhysicalScreenSize() end)
    end

    if not physW or physW <= 0 then
        local resStr = (GetCVar and (GetCVar("gxWindowedResolution") or GetCVar("gxFullscreenResolution"))) or "0x0"
        local w, h = strsplit("x", resStr)
        physW = tonumber(w) or (GetScreenWidth and GetScreenWidth()) or 1920
        physH = tonumber(h) or (GetScreenHeight and GetScreenHeight()) or 1080
    end

    local ar = physW / math.max(physH, 1)

    local function Near(v, target, tol)
        return math.abs(v - target) <= (tol or 100)
    end

    local info = {
        physWidth = physW,
        physHeight = physH,
        aspectRatio = ar,
        isSpanned = false,
        recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT",
        recommendedDeckRatio = 0.36,
        recommendedPosition = "RIGHT",
        recommendedAR = "16_9",
        description = "Single Display",
    }

    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if metrics and metrics.companionTopology then
        -- Accepted Companion bounds are authoritative when the physical API
        -- still reports a single display. Use the full span for wizard sizes
        -- and saved workspace percentages, including stacked arrangements.
        physW, physH = metrics.physicalWidth or physW, metrics.physicalHeight or physH
        info.physWidth, info.physHeight = physW, physH
        info.aspectRatio = physW / math.max(physH, 1)
        local gameAR = metrics.gamePixelWidth / math.max(metrics.gamePixelHeight, 1)
        local stacked = metrics.workspaceTop <= metrics.gameBottom + 2
            or metrics.gameTop <= metrics.workspaceBottom + 2
        local workspacePortrait = metrics.workspacePixelHeight > metrics.workspacePixelWidth
        local gameLandscape = metrics.gamePixelWidth >= metrics.gamePixelHeight
        info.isSpanned = true
        info.exactTopology = true
        info.companionVersionStatus = metrics.companionVersionStatus
        info.companionVersion = metrics.companionVersion
        info.expectedCompanionVersion = metrics.expectedCompanionVersion
        info.gamePixelWidth = metrics.gamePixelWidth
        info.gamePixelHeight = metrics.gamePixelHeight
        info.workspacePixelWidth = metrics.workspacePixelWidth
        info.workspacePixelHeight = metrics.workspacePixelHeight
        info.recommendedPreset = stacked and "STACKED_VERTICAL"
            or (workspacePortrait and gameLandscape and "PORTRAIT_LEFT_LANDSCAPE_RIGHT")
            or "LANDSCAPE_DUAL"
        if stacked then
            info.recommendedPosition = metrics.gameBottom >= metrics.workspaceTop - 2 and "TOP" or "BOTTOM"
            info.recommendedDeckRatio = metrics.workspacePixelHeight / physH
        else
            info.recommendedPosition = metrics.gameLeft < metrics.workspaceLeft and "LEFT" or "RIGHT"
            info.recommendedDeckRatio = metrics.workspacePixelWidth / physW
        end
        info.recommendedAR = gameAR >= 2.9 and "32_9" or gameAR >= 2.1 and "21_9" or "16_9"
        info.description = string.format("Companion: game %dx%d + workspace %dx%d (%s)",
            metrics.gamePixelWidth, metrics.gamePixelHeight,
            metrics.workspacePixelWidth, metrics.workspacePixelHeight,
            metrics.topologyMode == "SPLIT_ULTRAWIDE" and "single-display split" or (stacked and "stacked" or "side-by-side"))
        return info
    end

    -- A loaded exact topology that does not match the current WoW surface is a
    -- recovery/readiness state, not permission to guess from the old window's
    -- aspect ratio. For example, a decorated 3840x2160 window can temporarily
    -- report 3818x2104 while the Companion is spanning it. That single
    -- landscape surface otherwise satisfies the broad mixed-monitor heuristic
    -- below and makes the wizard save a false portrait + landscape layout.
    if metrics and metrics.topologyStatus == "MISMATCH"
        and not metrics.manualCanvas then
        info.topologyStatus = metrics.topologyStatus
        info.description = "Companion topology does not match the current WoW window"
        return info
    end

    -- ------------------------------------------------------------------------
    -- 1. Specific High-Confidence Multi-Monitor Topologies
    -- ------------------------------------------------------------------------
    if Near(physW, 5360) and Near(physH, 1440) then
        -- 3440x1440 Ultrawide + 1920x1080 Landscape (5360x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.358 -- 1920 / 5360 = ~35.8% (or 3440 / 5360 = 64.2% if primary left)
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (3440p) + 1080p Landscape")

    elseif Near(physW, 6000) and Near(physH, 1440) then
        -- 3440x1440 Ultrawide + 2560x1440 Landscape (6000x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.427 -- 2560 / 6000 = ~42.7%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (3440p) + 1440p Landscape")

    elseif Near(physW, 4480) and Near(physH, 1080) then
        -- 2560x1080 Ultrawide + 1920x1080 Landscape (4480x1080)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.429 -- 1920 / 4480 = ~42.9%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "21_9"
        info.description = string.format("Ultrawide 21:9 (2560p) + 1080p Landscape")

    elseif Near(physW, 4480) and Near(physH, 1440) then
        -- 2560x1440 Landscape + 1920x1080 Landscape (4480x1440)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.429 -- 1920 / 4480 = ~42.9%
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("1440p Gaming + 1080p Landscape")

    elseif Near(physW, 6400) and Near(physH, 2160) then
        -- 3840x2160 (4K) + 2560x1440 (1440p) = 6400x2160
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.400 -- 2560 / 6400
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("4K Gaming + 1440p Landscape")

    elseif Near(physW, 7680) and Near(physH, 2160) then
        -- Dual 4K (3840 + 3840 = 7680x2160)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 4K Landscape (7680x2160)")

    elseif Near(physW, 5120) and Near(physH, 1440) then
        -- Dual 1440p (2560 + 2560 = 5120x1440) or Super-Ultrawide 32:9
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 1440p Landscape")

    elseif Near(physW, 3840) and Near(physH, 1080) then
        -- Dual 1080p (1920 + 1920 = 3840x1080)
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual 1080p Landscape")

    elseif Near(physW, 4880) and Near(physH, 2560) then
        -- Portrait 1440p (1440x2560) + Ultrawide 3440x1440p (4880x2560)
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.295 -- 1440 / 4880
        info.recommendedAR = "21_9"
        info.description = string.format("Portrait 1440p + Ultrawide 21:9")

    elseif Near(physW, 4520) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Ultrawide 3440x1440p (4520x1920)
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.239 -- 1080 / 4520
        info.recommendedAR = "21_9"
        info.description = string.format("Portrait 1080p + Ultrawide 21:9")

    elseif Near(physW, 4000) and Near(physH, 2560) then
        -- Portrait 1440p (1440x2560) + Landscape 1440p (2560x1440) = 4000x2560
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.360 -- 1440 / 4000
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1440p) + Landscape (1440p)")

    elseif Near(physW, 3640) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Landscape 1440p (2560x1440) = 3640x1920
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.297 -- 1080 / 3640
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1080p) + Landscape (1440p)")

    elseif Near(physW, 3000) and Near(physH, 1920) then
        -- Portrait 1080p (1080x1920) + Landscape 1080p (1920x1080) = 3000x1920
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.360 -- 1080 / 3000
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait (1080p) + Landscape (1080p)")

    -- ------------------------------------------------------------------------
    -- 2. Fallback Heuristics by Aspect Ratio & Geometry
    -- ------------------------------------------------------------------------
    elseif physH >= 1800 and physW >= 2800 and ar < 2.6 then
        -- General Mixed Portrait + Landscape
        info.isSpanned = true
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedPosition = "RIGHT"
        info.recommendedDeckRatio = 0.36
        info.recommendedAR = "16_9"
        info.description = string.format("Mixed Portrait + Landscape")

    elseif ar >= 3.0 then
        -- Generic dual landscape side-by-side
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = 0.50
        info.recommendedPosition = "LEFT"
        info.recommendedAR = "16_9"
        info.description = string.format("Dual Landscape Side-by-Side")

    elseif ar >= 2.0 then
        -- A single 21:9-class ultrawide can reserve the width left over after
        -- preserving a 16:9 Mainhand region. Physical monitor ownership is not
        -- visible to Lua, so onboarding requires explicit manual confirmation.
        info.isSpanned = true
        info.recommendedPreset = "LANDSCAPE_DUAL"
        info.recommendedDeckRatio = math.max(0.15, math.min(0.50, 1 - ((16 / 9) / ar)))
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("Single-Display Ultrawide Split")

    else
        info.isSpanned = false
        info.recommendedPreset = "PORTRAIT_LEFT_LANDSCAPE_RIGHT"
        info.recommendedDeckRatio = 0.36
        info.recommendedPosition = "RIGHT"
        info.recommendedAR = "16_9"
        info.description = string.format("Single Display")
    end

    return info
end

