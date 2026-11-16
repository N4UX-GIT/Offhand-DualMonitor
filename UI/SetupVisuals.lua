-- Addon-owned setup artwork. No native frames, world input or recurring work.
local _, Offhand = ...
local Controls, L = Offhand.UIControls, Offhand.L
local Visuals = {}
Offhand.SetupVisuals = Visuals
local function Surface(parent)
    local f = Controls.CreateFrame("Frame", nil, parent, not Offhand.isLegacyWrath and "BackdropTemplate" or nil)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
    f:SetBackdropColor(.094,.102,.137,1)
    f:SetBackdropBorderColor(.34,.38,.45,1)
    f:EnableMouse(false)
    return f
end
local function Text(parent, width, font)
    local text = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlightSmall")
    text:SetWidth(width)
    text:SetWordWrap(true)
    text:SetJustifyH("CENTER")
    return text
end

function Visuals:CreateProgress(parent, width)
    local rail = Surface(parent)
    rail:SetSize(width, 30)
    rail.cells = {}
    for i = 1, 6 do
        local cell = Surface(rail)
        cell.text = Text(cell, 0)
        cell.text:SetWordWrap(false)
        if cell.text.SetNonSpaceWrap then cell.text:SetNonSpaceWrap(false) end
        if cell.text.SetMaxLines then cell.text:SetMaxLines(1) end
        if cell.text.SetShadowOffset then cell.text:SetShadowOffset(0,0) end
        if cell.text.SetShadowColor then cell.text:SetShadowColor(0,0,0,0) end
        cell.text:SetPoint("CENTER", cell, "CENTER", 0, 0)
        cell:Hide()
        rail.cells[i] = cell
    end
    function rail:Update(current, labels)
        local count, gap, padding = #labels, 5, 12
        local available = self:GetWidth() - (count - 1) * gap - count * padding
        local widths, total = {}, 0
        for i, label in ipairs(labels) do
            local text = self.cells[i].text
            if text.SetTextScale then text:SetTextScale(1) end
            text:SetWidth(0)
            text:SetText(label)
            widths[i] = Controls.MeasureSingleLine(text, label)
            total = total + widths[i]
        end
        local scale = math.min(1, available / math.max(1, total))
        local extra = (available - total * scale) / count
        local left = 0
        for i, cell in ipairs(self.cells) do
            if i <= count then
                cell.state = i < current and "complete" or i == current and "current" or "locked"
                local textWidth = widths[i] * scale + extra
                if cell.text.SetTextScale then cell.text:SetTextScale(scale) end
                cell.text:SetWidth(textWidth)
                cell:ClearAllPoints()
                cell:SetPoint("TOPLEFT", self, "TOPLEFT", left, 0)
                cell:SetSize(textWidth + padding, 30)
                left = left + textWidth + padding + gap
                cell:Show()
                if i == current then
                    cell:SetBackdropColor(.12, .115, .09, 1)
                    cell:SetBackdropBorderColor(.58, .48, .22, 1)
                    cell.text:SetTextColor(1, .94, .77, 1)
                elseif i < current then
                    cell:SetBackdropColor(.055, .14, .12, 1)
                    cell:SetBackdropBorderColor(.15, .58, .4, 1)
                    cell.text:SetTextColor(.55, .91, .73, 1)
                else
                    cell:SetBackdropColor(.07, .08, .11, 1)
                    cell:SetBackdropBorderColor(.17, .19, .24, 1)
                    cell.text:SetTextColor(.58, .61, .66, 1)
                end
            else cell:Hide() end
        end
    end
    return rail
end

local function Number(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then return value end
end

local readyCue

function Visuals:ShowWorkspaceReady(metrics)
    if not metrics or not metrics.isSpanned then return end
    if not readyCue then
        readyCue = Controls.CreateFrame("Frame", nil, UIParent)
        readyCue:SetAllPoints(UIParent)
        readyCue:SetFrameStrata("HIGH")
        readyCue:EnableMouse(false)
        readyCue.regions = {}
        readyCue:SetScript("OnUpdate", function(self, elapsed)
            self.elapsed = self.elapsed + elapsed
            if self.elapsed >= 6 or Offhand._displayGeometryTransitionActive or not (Offhand.db and Offhand.db.enabled)
                or (Offhand.IsBlizzardInputReserved and Offhand:IsBlizzardInputReserved()) then
                self:Hide()
                return
            end
            self:SetAlpha(math.min(1, self.elapsed / .25, 6 - self.elapsed))
        end)
    end
    for _, frame in pairs(readyCue.regions) do frame:Hide() end
    local regions = metrics.workspaceRegions or {{
        x = metrics.workspaceLeft, y = metrics.workspaceBottom,
        width = metrics.workspaceWidth, height = metrics.workspaceHeight,
    }}
    local text = L.WORKSPACE_READY_TITLE .. "\n" .. L.WORKSPACE_READY_HINT
    local shown = false
    for i, region in ipairs(regions) do
        local x, y, width, height = Number(region.x), Number(region.y), Number(region.width), Number(region.height)
        if x and y and width and height and width > 0 and height > 0 then
            local frame = readyCue.regions[i]
            if not frame then
                frame = Surface(readyCue)
                frame:SetBackdropColor(1, .75, .15, .07)
                frame:SetBackdropBorderColor(1, .79, .30, .75)
                frame.label = Text(frame, 1, "GameFontHighlightLarge")
                frame.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
                frame.label:SetTextColor(1, .92, .68, 1)
                readyCue.regions[i] = frame
            end
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            frame:SetSize(width, height)
            frame.label:SetText(text)
            local textHeight = Controls.FitCompactParagraph(frame.label, text, math.max(1, math.min(width - 24, 420)))
            if textHeight <= height - 12 then frame.label:Show() else frame.label:Hide() end
            frame:Show()
            shown = true
        end
    end
    if shown then
        readyCue.elapsed = 0
        readyCue:SetAlpha(0)
        readyCue:Show()
    else
        readyCue:Hide()
    end
end

-- One coordinate space, including negative origins and the physical void.
function Visuals:Plan(metrics, width, height)
    local m = metrics or {}
    local function Rect(prefix)
        local x, y = Number(m[prefix .. "Left"]), Number(m[prefix .. "Bottom"])
        local right, top = Number(m[prefix .. "Right"]), Number(m[prefix .. "Top"])
        if x and y and right and top and right > x and top > y then return {x=x,y=y,w=right-x,h=top-y} end
    end
    local game, work
    if m.isSpanned and not Offhand._displayGeometryTransitionActive
        and (m.topologyStatus ~= "MISMATCH" or m.manualCanvas) then
        game, work = Rect("game"), Rect("workspace")
    end
    local example = not game or not work
    if not example and math.min(game.x+game.w,work.x+work.w)>math.max(game.x,work.x)
        and math.min(game.y+game.h,work.y+work.h)>math.max(game.y,work.y) then example=true end
    if example then game,work={x=700,y=0,w=1600,h=900},{x=0,y=0,w=700,h=1200} end
    local left, bottom = math.min(game.x,work.x), math.min(game.y,work.y)
    local right, top = math.max(game.x+game.w,work.x+work.w), math.max(game.y+game.h,work.y+work.h)
    local factor = math.min(width/(right-left), height/(top-bottom))
    local dx,dy=(width-(right-left)*factor)/2,(height-(top-bottom)*factor)/2
    local function Fit(r)
        return {x=dx+(r.x-left)*factor,y=dy+(r.y-bottom)*factor,w=r.w*factor,h=r.h*factor}
    end
    return {game=Fit(game),workspace=Fit(work),example=example}
end

function Visuals:CreateIllustration(parent, width)
    local art = Surface(parent)
    art:SetSize(width, 150)
    art.caption = Text(art, width - 24)
    art.caption:SetPoint("TOP", art, "TOP", 0, -10)
    art.legend = Text(art, width - 24)
    art.legend:SetPoint("BOTTOM", art, "BOTTOM", 0, 10)
    art.boxes, art.bars = {}, {}
    for i = 1, 4 do
        local box = Surface(art)
        box.label = Text(box, 200)
        box.label:SetPoint("TOP", box, "TOP", 0, -8)
        box.chrome = Text(box, 20)
        box.chrome:SetPoint("TOPRIGHT",box,"TOPRIGHT",-4,-3)
        box.chrome:SetText("")
        if box.chrome.SetDrawLayer then box.chrome:SetDrawLayer("OVERLAY") end
        box:Hide()
        art.boxes[i] = box
    end
    for i = 1, 7 do art.bars[i] = Surface(art);art.bars[i]:Hide() end
    art.placement = Visuals:CreateProgress(art, width - 24)
    art.placement:SetPoint("CENTER", art, "CENTER", 0, -2)
    art.placement:Hide()
    art:Hide()
    function art:Update(kind, metrics, phase)
        self.kind = kind
        for _, f in ipairs(self.boxes) do f:Hide();f.chrome:SetText("") end
        for _, f in ipairs(self.bars) do f:Hide() end
        self.placement:Hide()
        local caption = L["SETUP_VISUAL_" .. kind]
        self.caption:SetText(caption)
        local captionHeight = Controls.MeasureWrappedText(self.caption, caption, self:GetWidth()-24)
        self.caption:SetHeight(captionHeight)
        self.legend:SetText("")
        self:SetHeight(130 + captionHeight)
        local baseY = 30
        local function Box(i,x,y,w,h,r,g,b)
            local box=self.boxes[i]
            box:ClearAllPoints();box:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT",x,y)
            box:SetSize(math.max(1,w),math.max(1,h))
            box:SetBackdropColor(.055,.065,.085,1);box:SetBackdropBorderColor(r,g,b,1)
            box.label:ClearAllPoints();box.label:SetPoint("TOP",box,"TOP",0,-8)
            box.label:SetText("");box:Show()
            return box
        end
        local function Bar(i,parent,x,y,w,h,r,g,b)
            local bar=self.bars[i]
            bar:ClearAllPoints();bar:SetPoint("BOTTOMLEFT",parent,"BOTTOMLEFT",x,y)
            bar:SetSize(math.max(1,w),math.max(1,h))
            bar:SetBackdropColor(r,g,b,1);bar:SetBackdropBorderColor(r,g,b,1);bar:Show()
        end
        if kind == "RELOAD" then
            self.placement:Update(phase or 2,{L.SETUP_STAGE_PLACE,L.ONBOARD_RELOAD_UI,L.ONBOARD_CONFIRM_PLACEMENT})
            self.placement:Show()
            self:SetHeight(math.max(self:GetHeight(),captionHeight+self.placement:GetHeight()+54))
        elseif kind == "WINDOW" then
            local cell=(self:GetWidth()-48)/2
            local before=Box(1,12,baseY,cell,78,.3,.33,.38)
            local after=Box(2,24+cell,baseY,cell,78,.45,.55,.65)
            before.label:SetWidth(cell-16);before.label:SetText(L.ONBOARD_MODE_BEFORE)
            after.label:SetWidth(cell-16);after.label:SetText(L.ONBOARD_MODE_AFTER)
            before.label:ClearAllPoints();before.label:SetPoint("TOP",before,"TOP",0,-12)
            after.label:ClearAllPoints();after.label:SetPoint("TOP",after,"TOP",0,-24)
            Bar(1,after,2,60,cell-4,16,.22,.29,.37)
            after.chrome:SetText("x")
            -- Decorative window contents, visually distinct from action controls.
            for i=2,4 do Bar(i,before,12,14+(i-2)*10,cell-24,2,.24,.29,.35) end
            for i=5,7 do Bar(i,after,12,14+(i-5)*10,cell-24,2,.24,.29,.35) end
        elseif kind == "SCALE" then
            local sample=Box(1,12,baseY,self:GetWidth()-24,78,.4,.45,.55)
            sample.label:SetWidth(self:GetWidth()-56)
            sample.label:SetText(L.SETUP_VISUAL_SAMPLE)
            if sample.label.SetFontObject then sample.label:SetFontObject("GameFontHighlight") end
            sample.label:ClearAllPoints();sample.label:SetPoint("CENTER",sample,"CENTER",0,0)
            -- This inherits the actual UI scale, just like the controls being adjusted.
            self.legend:SetText(L.WIZARD_LABEL_UI_SCALE .. " " .. string.format("%.0f%%", ((Offhand.db and Offhand.db.hudScale) or .70)*100))
        elseif kind == "HUD" then
            local half=(self:GetWidth()-36)/2
            local plan=Visuals:Plan(metrics,half,60)
            self.plan=plan
            for side=1,2 do
                local dx=12+(side-1)*(half+12)
                local g,w=plan.game,plan.workspace
                local main=Box((side-1)*2+1,dx+g.x,baseY+g.y,g.w,g.h,1,.741,.04)
                Box((side-1)*2+2,dx+w.x,baseY+w.y,w.w,w.h,.15,.66,.77)
                main.label:SetWidth(math.max(1,g.w-4))
                main.label:SetText(g.w>=100 and (side==1 and L.SETUP_VISUAL_EXAMPLE or L.SETUP_STAGE_HUD) or "")
                if side==1 then Bar(1,self,dx+(half-80)/2,baseY+4,80,6,.85,.18,.15)
                else Bar(2,main,g.w*.2,4,g.w*.6,6,1,.741,.04) end
            end
            self.legend:SetText(L.SETUP_VISUAL_EXAMPLE .. "  >  " .. L.SETUP_VISUAL_HUD)
        else
            local plan=Visuals:Plan(metrics,self:GetWidth()-24,90)
            self.plan=plan
            local g,w=plan.game,plan.workspace
            local main=Box(1,g.x+12,g.y+baseY,g.w,g.h,1,.741,.04)
            local off=Box(2,w.x+12,w.y+baseY,w.w,w.h,.15,.66,.77)
            for i=1,3 do Bar(i,main,g.w*.25+(i-1)*g.w*.17,5,g.w*.14,6,1,.741,.04) end
            Bar(4,off,4,4,math.max(1,w.w-8),math.max(1,w.h*.45),.09,.29,.35)
            if kind == "SEAM" then
                local vertical=math.abs(g.x-(w.x+w.w))<2 or math.abs(w.x-(g.x+g.w))<2
                if vertical then
                    local x=g.x>w.x and g.x or w.x
                    local low,high=math.max(g.y,w.y),math.min(g.y+g.h,w.y+w.h)
                    if high>low then Bar(5,self,x+11,low+baseY,2,high-low,1,.18,.15) end
                elseif math.abs(g.y-(w.y+w.h))<2 or math.abs(w.y-(g.y+g.h))<2 then
                    local y=g.y>w.y and g.y or w.y
                    local low,high=math.max(g.x,w.x),math.min(g.x+g.w,w.x+w.w)
                    if high>low then Bar(5,self,low+12,y+baseY-1,high-low,2,1,.18,.15) end
                end
            end
            self.legend:SetText((plan.example and L.SETUP_VISUAL_EXAMPLE or L.SETUP_VISUAL_CONFIGURED)
                .. "  |cffffbd0a" .. L.IDENTIFY_MAINHAND .. "|r  |cff26a8c4" .. L.IDENTIFY_OFFHAND .. "|r")
        end
        local legendHeight=Controls.MeasureWrappedText(self.legend,self.legend:GetText(),self:GetWidth()-24)
        self.legend:SetHeight(legendHeight)
        -- Reserve translated legends below the artwork instead of drawing over it.
        if legendHeight>15 then
            local extra=legendHeight-15
            for _,box in ipairs(self.boxes) do
                if box:IsShown() then
                    local _,_,_,x,y=box:GetPoint(1)
                    box:ClearAllPoints();box:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT",x,y+extra)
                end
            end
            if self.bars[5]:IsShown() then
                local bar=self.bars[5]
                local _,_,_,x,y=bar:GetPoint(1)
                bar:ClearAllPoints();bar:SetPoint("BOTTOMLEFT",self,"BOTTOMLEFT",x,y+extra)
            end
            self:SetHeight(self:GetHeight()+extra)
        end
    end
    return art
end
