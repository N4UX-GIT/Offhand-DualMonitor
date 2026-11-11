-- Shared by calibration and settings. Preview is addon-owned; Apply is explicit.
local _,Offhand=...
local UI={instances=setmetatable({}, {__mode="k"})}
Offhand.WorkspaceScaleControls=UI
function UI:RefreshThemes()
    for box in pairs(self.instances) do box.controls.slider:UpdateTheme() end
end

function UI:Build(parent,width,hideHeading)
    local C,L=Offhand.UIControls,Offhand.L
    local box=C.CreateFrame("Frame",nil,parent)
    box:SetWidth(width)
    local scale=Offhand.WorkspaceScale
    local selected,context,pending,includeChat
    local function Metrics() return Offhand.Viewport and Offhand.Viewport:GetMetrics() end
    local function Text(text,font)
        local f=box:CreateFontString(nil,"ARTWORK",font or "GameFontHighlightSmall")
        f:SetJustifyH("LEFT");f:SetWidth(width);f:SetWordWrap(true);f:SetText(text);return f
    end
    local title=not hideHeading and Text(L.REGION_SCALE_TITLE,"GameFontNormal")
    local help=title and Text(L.REGION_SCALE_HELP)
    local status=Text("")
    local function Button(label,fn)
        local b=C.CreateFrame("Button",nil,box,"UIPanelButtonTemplate")
        b:SetText(label);b:SetScript("OnClick",fn);return b
    end
    local picker=Button("",function()
        local m=Metrics();local list=scale:Destinations(m);local at=0
        for i,r in ipairs(list) do if r.id==selected then at=i end end
        if #list>0 then selected=list[at%#list+1].id;context=nil;box:Refresh() end
    end)
    local slider=C.CreateNativeSlider(box,L.REGION_SCALE_TITLE,scale.MIN,scale.MAX,.01,
        function()
            if pending=="AUTO" then
                local m=Metrics();local game=m and m.workspaceScaleGame
                local work=m and m.workspaceScaleDisplays and m.workspaceScaleDisplays[selected]
                if game and work and game.percent and work.percent then
                    return math.max(scale.MIN,math.min(scale.MAX,work.percent/game.percent))
                end
                return 1
            end
            return pending or 1
        end,
        function(v)pending=v;box:Refresh(true)end,"%.0f%%",L.REGION_SCALE_TITLE,L.REGION_SCALE_HELP)
    slider.applyLayout=function()box:Refresh(true)end
    local auto=Button(L.REGION_SCALE_AUTO,function()pending="AUTO";box:Refresh(true)end)
    local reset=Button(L.REGION_SCALE_RESET,function()pending=1;includeChat=false;box:Refresh(true)end)
    local chat=C.CreateNativeCheckbox(box,L.REGION_SCALE_CHAT,
        function()return includeChat==true end,function(v)includeChat=v;box:Refresh(true)end,
        L.REGION_SCALE_TITLE,L.REGION_SCALE_SCOPE)
    -- The standard checkbox commits layout immediately. This control only
    -- edits an addon-owned draft until Apply, including clicks on its label.
    chat:SetScript("OnClick",function(self)includeChat=self:GetChecked()==true;box:Refresh(true)end)
    chat.labelButton:SetScript("OnClick",function()
        if chat.IsEnabled and not chat:IsEnabled() then return end
        includeChat=not includeChat;box:Refresh(true)
    end)
    chat.Text:SetWidth(width-32)
    chat.Text:SetWordWrap(true)
    local sampleAnchor=C.CreateFrame("Frame",nil,box)
    sampleAnchor:SetSize(1,1)
    local sample=C.CreateFrame("Frame",nil,sampleAnchor)
    sample:SetSize(math.min(280,width/2),28)
    sample:SetPoint("TOPLEFT",sampleAnchor,"TOPLEFT",0,0)
    local sampleText=sample:CreateFontString(nil,"ARTWORK","GameFontNormal")
    sampleText:SetPoint("LEFT",sample,"LEFT",0,0);sampleText:SetText(L.REGION_SCALE_SAMPLE)
    local mini=C.CreateFrame("Frame",nil,box);mini:SetSize(116,52)
    local textures={}
    local apply=Button(L.REGION_SCALE_APPLY,function()
        local m=Metrics()
        if scale:SetSetting(m,selected,pending,includeChat) then
            context=nil;box:Refresh()
            if Offhand.WorkspaceOptions then Offhand.WorkspaceOptions:Refresh() end
        end
    end)
    local cancel=Button(L.REGION_SCALE_CANCEL,function()box:DiscardPreview()end)
    function box:DiscardPreview()
        if slider.editBox and slider.editBox.ClearFocus then slider.editBox:ClearFocus() end
        context=nil
        self:Refresh()
    end
    function box:Refresh(keepDraft)
        if self.notifyingResize then return end
        local m=Metrics();local list=scale:Destinations(m);local current
        for i,r in ipairs(list) do if r.id==selected then current=i end end
        if not current then selected=list[1] and list[1].id;current=1 end
        local key=scale:Keys(m,selected)
        -- Refreshing layout/profile state is read-only and discards stale drafts.
        local stored,storedChat=scale:GetSetting(m,selected)
        local nextContext=tostring(Offhand.db)..":"..tostring(key)..":"..tostring(selected)..":"..tostring(stored)..":"..tostring(storedChat)
        if context~=nextContext or not keepDraft and not self.dirty then
            pending,includeChat=scale:GetSetting(m,selected);self.dirty=false;context=nextContext
        end
        if keepDraft then self.dirty=true end
        local destination = L.REGION_SCALE_UNAVAILABLE
        if list[1] then
            destination = m.workspaceRegions and string.format(L.WORKSPACE_REGION_NUMBER,current) or L.TAB_WORKSPACE
            if #list>1 then destination=destination.."  >" end
        end
        picker:SetText(destination)
        picker:SetEnabled(#list>1)
        slider:UpdateText()
        local multiplier=slider:GetValue() or 1
        sample:SetScale(multiplier)
        chat:SetChecked(includeChat==true)
        local enabled=#list>0
        local changed=pending~=stored or includeChat~=storedChat
        apply:SetEnabled(enabled and changed);cancel:SetEnabled(enabled and changed)
        auto:SetEnabled(enabled);reset:SetEnabled(enabled)
        C.SetCheckboxEnabled(chat,enabled)
        if slider.editBox then slider.editBox:EnableMouse(enabled) end
        if slider.btnPlus then slider.btnPlus:SetEnabled(enabled) end
        if slider.btnMinus then slider.btnMinus:SetEnabled(enabled) end
        if slider.EnableMouse then slider:EnableMouse(enabled) end
        self:SetAlpha(enabled and 1 or .65)
        local message
        if not enabled then message=L.REGION_SCALE_UNAVAILABLE
        elseif not changed then message=string.format(L.REGION_SCALE_SAVED,multiplier*100)
        elseif pending=="AUTO" then
            local game=m.workspaceScaleGame;local work=m.workspaceScaleDisplays and m.workspaceScaleDisplays[selected]
            message=game and work and game.percent and work.percent
                and string.format(L.REGION_SCALE_DETECTED,multiplier*100,work.percent,game.percent)
                or L.REGION_SCALE_AUTO_UNAVAILABLE
        else message=string.format(L.REGION_SCALE_MANUAL,multiplier*100) end
        status:SetText(message)
        local y=0
        local function Paragraph(f)
            f:ClearAllPoints();f:SetPoint("TOPLEFT",box,"TOPLEFT",0,-y)
            y=y+C.FitParagraphText(f,f:GetText(),width)+10
        end
        local function Row(buttons)
            local w=(width-(#buttons-1)*8)/#buttons;local h=28
            for _,b in ipairs(buttons) do
                h=math.max(h,C.MeasureWrappedText(b:GetFontString(),b:GetText(),w-16,14)+8)
            end
            for i,b in ipairs(buttons) do
                b:ClearAllPoints();b:SetPoint("TOPLEFT",box,"TOPLEFT",(i-1)*(w+8),-y);b:SetSize(w,h)
            end
            y=y+h+12
        end
        if title then Paragraph(title);Paragraph(help) end
        Row({picker})
        slider:ClearAllPoints();slider:SetPoint("TOPLEFT",box,"TOPLEFT",0,-y-20);slider:SetWidth(math.max(140,width-330))
        y=y+64
        Row({auto,reset});Paragraph(status)
        chat:ClearAllPoints();chat:SetPoint("TOPLEFT",box,"TOPLEFT",0,-y)
        y=y+math.max(30,C.MeasureWrappedText(chat.Text,L.REGION_SCALE_CHAT,width-30,14)+8)
        sampleAnchor:ClearAllPoints();sampleAnchor:SetPoint("TOPLEFT",box,"TOPLEFT",0,-y-12)
        mini:ClearAllPoints();mini:SetPoint("TOPRIGHT",box,"TOPRIGHT",0,-y)
        local rects={{id="game",x=m and m.gameLeft,y=m and m.gameBottom,
            width=m and m.gameWidth,height=m and m.gameHeight}}
        for _,r in ipairs(list) do rects[#rects+1]=r end
        for i,r in ipairs(rects) do
            local texture=textures[i]
            if not texture then texture=mini:CreateTexture(nil,"ARTWORK");textures[i]=texture end
            texture:Hide()
            if m and m.screenWidth and m.screenHeight and m.screenWidth>0 and m.screenHeight>0 and r.x and r.y and r.width and r.height then
                texture:ClearAllPoints();texture:SetPoint("BOTTOMLEFT",mini,"BOTTOMLEFT",r.x/m.screenWidth*116,r.y/m.screenHeight*52)
                texture:SetSize(math.max(1,r.width/m.screenWidth*116-1),math.max(1,r.height/m.screenHeight*52-1))
                local chosen=r.id==selected
                if texture.SetColorTexture then texture:SetColorTexture(chosen and 1 or .25,chosen and .75 or .3,.2,1)
                else texture:SetTexture(chosen and 1 or .25,chosen and .75 or .3,.2,1) end
                texture:Show()
            end
        end
        for i=#rects+1,#textures do textures[i]:Hide() end
        y=y+66;Row({apply,cancel})
        -- Native frame height can round through UI scale. Use the measured
        -- content height and avoid reentering via a parent layout callback.
        if self.contentHeight~=y then
            self.contentHeight=y
            self:SetHeight(y)
            if self.onResize then
                self.notifyingResize=true
                self.onResize(y)
                self.notifyingResize=nil
            end
        end
    end
    box.controls={picker=picker,slider=slider,auto=auto,reset=reset,chat=chat,apply=apply,cancel=cancel,sample=sample}
    self.instances[box]=true
    box:Refresh()
    return box
end

function UI:BuildAdvanced(parent,width,hideHeading)
    local C,L=Offhand.UIControls,Offhand.L
    local pane=C.CreateFrame("Frame",nil,parent)
    pane:SetWidth(width)
    local top=0
    if not hideHeading then
        local title=pane:CreateFontString(nil,"ARTWORK","GameFontNormal")
        title:SetPoint("TOPLEFT",pane,"TOPLEFT",0,0)
        title:SetText(L.REGION_SCALE_TITLE)
        local helpButton=C.CreateHelpButton(pane,L.REGION_SCALE_TITLE,L.REGION_SCALE_DETAILS)
        helpButton:SetPoint("TOPRIGHT",pane,"TOPRIGHT",0,3)
        top=30
    end
    local intro=pane:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-top)
    intro:SetJustifyH("LEFT")
    if intro.SetWordWrap then intro:SetWordWrap(true) end
    intro:SetText(L.REGION_SCALE_HELP)
    top=top+C.FitCompactParagraph(intro,L.REGION_SCALE_HELP,width)+10

    local disclosure=C.CreateFrame("Button",nil,pane,"UIPanelButtonTemplate")
    disclosure:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-top)
    disclosure:SetSize(math.min(310,width),26)
    disclosure:SetText(L.ADVANCED_SHOW)
    local bodyTop=top+38
    local control=self:Build(pane,width,true)
    control:SetPoint("TOPLEFT",pane,"TOPLEFT",0,-bodyTop)
    control:Hide()
    local expanded=false
    local function Resize(reveal)
        local height=bodyTop+(expanded and control:GetHeight() or 0)
        if pane.contentHeight==height then return end
        pane.contentHeight=height
        pane:SetHeight(height)
        if pane.onResize then pane.onResize(height,reveal) end
    end
    control.onResize=function() Resize() end
    disclosure:SetScript("OnClick",function()
        if not expanded then control:Refresh() end
        expanded=not expanded
        disclosure:SetText(expanded and L.ADVANCED_HIDE or L.ADVANCED_SHOW)
        if expanded then
            control:Show()
        else
            control:Hide()
            control:DiscardPreview()
        end
        Resize(expanded)
    end)
    function pane:Refresh() control:Refresh() end
    Resize()
    return pane
end
