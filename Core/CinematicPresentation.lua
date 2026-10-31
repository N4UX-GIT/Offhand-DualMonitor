-- Retail playback presentation only. Blizzard owns input, playback, text and visibility.
local _, Offhand = ...
if not Offhand.isRetail then return end

local Presentation = {}
Offhand.CinematicPresentation = Presentation
local states = setmetatable({}, {__mode="k"})
local widths = setmetatable({}, {__mode="k"})
local heights = setmetatable({}, {__mode="k"})
local hooks = setmetatable({}, {__mode="k"})
local applying, generation, combatPending, letterboxHooked = false, 0, false, false

local function Mutable(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

local function Shown(frame)
    return Mutable(frame) and frame.IsShown and frame:IsShown()
end

local function Points(frame)
    local result = {}
    for i = 1, frame:GetNumPoints() do result[i] = {frame:GetPoint(i)} end
    return result
end

local function Same(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        for j = 1, 5 do
            local x, y = a[i][j], b[i][j]
            if type(x)=="number" and type(y)=="number" then
                if math.abs(x-y)>0.001 then return false end
            elseif x ~= y then return false end
        end
    end
    return true
end

local function Write(frame, points)
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
end

local function Bounds(frame, left, bottom, right, top, remember)
    if not Mutable(frame) or not frame.GetNumPoints or not frame.GetPoint
        or not frame.GetEffectiveScale or not frame.ClearAllPoints or not frame.SetPoint then return end
    local scale = frame:GetEffectiveScale()
    if not scale or scale <= 0 then return end
    local factor = UIParent:GetEffectiveScale()/scale
    local desired = {
        {"BOTTOMLEFT", UIParent, "BOTTOMLEFT", left*factor, bottom*factor},
        {"TOPRIGHT", UIParent, "BOTTOMLEFT", right*factor, top*factor},
    }
    local current = Points(frame)
    if remember then
        local state = states[frame]
        if not state or not Same(current, state.applied) then
            state = {original=current}; states[frame]=state
        end
        state.applied=desired
    end
    if not Same(current, desired) then Write(frame, desired) end
end

local function Restore(frame)
    local state = states[frame]
    if not state or not Mutable(frame) then return end
    states[frame]=nil
    if Same(Points(frame), state.applied) then Write(frame, state.original) end
end

local function LimitWidth(region, m)
    if not Mutable(region) or not region.GetWidth or not region.SetWidth
        or not region.GetEffectiveScale then return end
    local scale = region:GetEffectiveScale()
    if not scale or scale <= 0 then return end
    local current = region:GetWidth()
    local state = widths[region]
    if not state or math.abs(current-state.applied)>0.001 then
        state={original=current}; widths[region]=state
    end
    local available=(m.gameRight-m.gameLeft)*UIParent:GetEffectiveScale()/scale-48
    if available <= 0 then return end
    state.applied=math.min(state.original, available)
    if math.abs(current-state.applied)>0.001 then
        region:SetWidth(state.applied)
        if region.ScaleTextToFit then region:ScaleTextToFit() end
    end
end

local function RestoreWidths()
    for region, state in pairs(widths) do
        if Mutable(region) then
            if math.abs(region:GetWidth()-state.applied)<0.001 then
                region:SetWidth(state.original)
                if region.ScaleTextToFit then region:ScaleTextToFit() end
            end
            widths[region]=nil
        end
    end
end

local function RestoreHeights()
    for region, state in pairs(heights) do
        if Mutable(region) then
            if math.abs(region:GetHeight()-state.applied)<0.001 then region:SetHeight(state.original) end
            heights[region]=nil
        end
    end
end

function Presentation:Apply(m)
    if applying then return end
    if InCombatLockdown and InCombatLockdown() then
        if not combatPending and Offhand.RunOrQueueCombat then
            combatPending=true
            Offhand:RunOrQueueCombat(function() combatPending=false; Presentation:Apply() end)
        end
        return
    end
    m=m or (Offhand.Viewport and Offhand.Viewport:GetMetrics())
    local active=Offhand.db and Offhand.db.enabled and m and m.isSpanned
    local cinematic, movie = _G.CinematicFrame, _G.MovieFrame
    local playing=active and (Shown(cinematic) or Shown(movie))
    applying=true
    for _, name in ipairs({"CinematicFrame", "MovieFrame", "SubtitlesFrame"}) do
        local frame=_G[name]
        if playing and Shown(frame) then
            Bounds(frame, m.gameLeft, m.gameBottom, m.gameRight, m.gameTop, true)
        elseif frame then Restore(frame) end
    end
    if playing and Shown(_G.SubtitlesFrame) then
        for _, region in ipairs(SubtitlesFrame.Subtitles or {}) do LimitWidth(region, m) end
        LimitWidth(SubtitlesFrame.SubtitleBackground, m)
    else RestoreWidths() end

    local legacyBars=false
    if playing and Shown(cinematic) and not Shown(movie) then
        -- Blizzard's native updater uses full-window physical aspect ratio.
        -- Fit its requested camera ratio within the physical Mainhand rectangle.
        local ratios=Enum and Enum.CameraModeAspectRatio
        local mode=cinematic.forcedAspectRatio
        local ratio
        local legacy=ratios and mode~=nil and mode==ratios.LegacyLetterbox
        if ratios and (legacy or mode==ratios.HighDefinition_16_X_9) then ratio=16/9
        elseif ratios and mode==ratios.Cinemascope_2_Dot_4_X_1 then ratio=2.4 end
        local left,bottom,right,top=m.gameLeft,m.gameBottom,m.gameRight,m.gameTop
        local width,height=right-left,top-bottom
        if ratio and width>0 and height>0 then
            if width/height>ratio and not legacy then
                local inset=(width-height*ratio)/2; left=left+inset; right=right-inset
            else
                local inset=math.max(0,(height-width/ratio)/2); bottom=bottom+inset; top=top-inset
            end
        end
        Bounds(_G.WorldFrame,left,bottom,right,top,false)
        if legacy then
            legacyBars=true
            for _, bar in ipairs({cinematic.UpperBlackBar or _G.UpperBlackBar,
                cinematic.LowerBlackBar or _G.LowerBlackBar}) do
                if Mutable(bar) and bar.SetHeight and bar.GetHeight and bar.GetEffectiveScale then
                    local factor=UIParent:GetEffectiveScale()/bar:GetEffectiveScale()
                    -- Native legacy bars have a 40-unit minimum.
                    local current=bar:GetHeight()
                    local state=heights[bar]
                    if not state or math.abs(current-state.applied)>0.001 then
                        state={original=current}; heights[bar]=state
                    end
                    state.applied=math.max((bottom-m.gameBottom)*factor,40)
                    if math.abs(current-state.applied)>0.001 then bar:SetHeight(state.applied) end
                end
            end
        end
    end
    if not legacyBars then RestoreHeights() end
    applying=false
end

function Presentation:Schedule()
    generation=generation+1
    local ticket=generation
    self:Apply()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({0,0.1,0.5}) do
            C_Timer.After(delay,function() if ticket==generation then Presentation:Apply() end end)
        end
    end
end

function Presentation:Attach()
    if hooksecurefunc and not letterboxHooked
        and type(_G.CinematicFrame_UpdateLettboxForAspectRatio)=="function" then
        letterboxHooked=true
        hooksecurefunc("CinematicFrame_UpdateLettboxForAspectRatio",function() Presentation:Apply() end)
    end
    for _, name in ipairs({"CinematicFrame","MovieFrame","SubtitlesFrame"}) do
        local frame=_G[name]
        if Mutable(frame) and frame.HookScript and not hooks[frame] then
            hooks[frame]=true
            frame:HookScript("OnShow",function() Presentation:Schedule() end)
            frame:HookScript("OnHide",function() Presentation:Schedule() end)
            if name=="SubtitlesFrame" and hooksecurefunc and type(frame.AddSubtitle)=="function" then
                hooksecurefunc(frame,"AddSubtitle",function() Presentation:Apply() end)
            end
        end
    end
end

local controller=CreateFrame("Frame")
for _, event in ipairs({"CINEMATIC_START","CINEMATIC_STOP","PLAY_MOVIE","STOP_MOVIE",
    "DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED","PLAYER_ENTERING_WORLD","ADDON_LOADED"}) do
    controller:RegisterEvent(event)
end
controller:SetScript("OnEvent",function(_,event,addon)
    if event=="ADDON_LOADED" and addon~="Blizzard_Subtitles" then return end
    Presentation:Attach()
    Presentation:Schedule()
end)
Presentation:Attach()
