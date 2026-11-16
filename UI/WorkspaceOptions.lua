local _,Offhand=...
local UI={}
Offhand.WorkspaceOptions=UI

function UI.Build(tabs,card,options)
    local L=Offhand.L
    local Controls=Offhand.UIControls
    local CreateFrame=Controls.CreateFrame
    local refreshers={}
    local function Text(parent,value,x,y,width)
        local f=parent:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall")
        f:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);f:SetWidth(width);f:SetJustifyH("LEFT")
        if f.SetWordWrap then f:SetWordWrap(true) end
        f:SetText(value);return f
    end
    local function Button(parent,label,x,y,width,action)
        local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT",parent,"TOPLEFT",x,y);b:SetSize(width,26);b:SetText(label)
        b:SetScript("OnClick",action);return b
    end
    local function Report(ok,err)
        if not ok and err and Offhand.Print then Offhand:Print(L[err] or err) end
        UI:Refresh()
    end
    local function Choice(parent,x,y,width,choices,get,set,missingLabel)
        local b
        local function Values() return type(choices)=="function" and choices() or choices end
        local function Update()
            local value=get();local label
            for _,entry in ipairs(Values()) do if entry.id==value then label=entry.label or entry.name end end
            b:SetText((label or missingLabel or string.format(L.WORKSPACE_MISSING_REGION,tostring(value))).."  >")
            if Offhand.SetTooltip then Offhand:SetTooltip(b,L.WORKSPACE_NEXT_CHOICE,L.WORKSPACE_NEXT_CHOICE_HELP) end
        end
        b=Button(parent,"",x,y,width,function()
            local values=Values();local current=get();local index=0
            if #values==0 then Report(false,"WORKSPACE_PROFILE_INVALID");return end
            for i,entry in ipairs(values) do if entry.id==current then index=i end end
            local value=values[index%#values+1].id
            Report(set(value));Update()
        end)
        refreshers[#refreshers+1]=Update;return b
    end
    local function Regions()
        local m=Offhand.Viewport and Offhand.Viewport:GetMetrics()
        return m and m.workspaceRegions or {}
    end

    local profiles=card(tabs.profiles,L.WORKSPACE_PROFILES_TITLE,140,
        L.WORKSPACE_PROFILES_HELP,L.WORKSPACE_PRESETS_WORKFLOW)
    local profileHelp=Text(profiles,L.WORKSPACE_PROFILES_HELP,12,-34,628)
    local activeTop=46+Controls.FitCompactParagraph(profileHelp,L.WORKSPACE_PROFILES_HELP,628)
    local active=Text(profiles,"",12,-activeTop,628)
    local profileBody=CreateFrame("Frame",nil,profiles)
    local collapsedHeight=activeTop+68
    profileBody:SetPoint("TOPLEFT",profiles,"TOPLEFT",0,-collapsedHeight)
    local workflow=Text(profileBody,L.WORKSPACE_PRESETS_WORKFLOW,12,0,628)
    local controlsTop=Controls.FitCompactParagraph(workflow,L.WORKSPACE_PRESETS_WORKFLOW,628)+12
    local nameHelp=Text(profileBody,L.WORKSPACE_PROFILE_NAME_HELP,18,-controlsTop-119,620)
    local bodyHeight=controlsTop+133+Controls.FitCompactParagraph(nameHelp,L.WORKSPACE_PROFILE_NAME_HELP,620)
    profileBody:SetSize(662,bodyHeight)
    local expanded=false
    local disclosure
    local input
    disclosure=Button(profiles,L.ADVANCED_SHOW,12,-activeTop-28,310,function()
        expanded=not expanded
        disclosure:SetText(expanded and L.ADVANCED_HIDE or L.ADVANCED_SHOW)
        if expanded then
            profileBody:Show()
        else
            input:ClearFocus()
            profileBody:Hide()
        end
        profiles:SetHeight(collapsedHeight+(expanded and bodyHeight or 0))
        if profiles.onSizingChanged then profiles.onSizingChanged(expanded) end
    end)
    profileBody:Hide()
    profiles:SetHeight(collapsedHeight)
    local selected
    local picker=Choice(profileBody,12,-controlsTop,390,function()return Offhand.WorkspaceProfiles:List()end,
        function()return selected end,function(id)selected=id;return true end)
    input=CreateFrame("EditBox",nil,profileBody,"InputBoxTemplate")
    input:SetPoint("TOPLEFT",profileBody,"TOPLEFT",18,-controlsTop-40);input:SetSize(380,26);input:SetAutoFocus(false)
    input:SetMaxLetters(96);input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local create=Button(profileBody,L.WORKSPACE_PROFILE_NEW,12,-controlsTop-82,122,function()
        local ok,err=Offhand.WorkspaceProfiles:Create(input:GetText())
        if ok then local _,id=Offhand.WorkspaceProfiles:List();selected=id end
        Report(ok,err);input:ClearFocus()
    end)
    local save=Button(profileBody,L.WORKSPACE_PROFILE_SAVE,140,-controlsTop-82,122,function()Report(Offhand.WorkspaceProfiles:Save())end)
    local load=Button(profileBody,L.PROFILES_BTN_LOAD or L.WORKSPACE_PROFILE_LOAD,268,-controlsTop-82,122,function()Report(Offhand.WorkspaceProfiles:Activate(selected))end)
    local rename=Button(profileBody,L.WORKSPACE_PROFILE_RENAME,396,-controlsTop-82,122,function()Report(Offhand.WorkspaceProfiles:Rename(selected,input:GetText()))end)
    local delete=Button(profileBody,L.WORKSPACE_PROFILE_DELETE,524,-controlsTop-82,122,function()
        local id=selected
        options:Confirm(L.WORKSPACE_PROFILE_DELETE_CONFIRM,function()Report(Offhand.WorkspaceProfiles:Delete(id))end)
    end)
    table.insert(refreshers,1,function()
        local list,current=Offhand.WorkspaceProfiles:List();local exists=false
        for _,entry in ipairs(list) do if entry.id==selected then exists=true end end
        if not exists then selected=current end
        local name=""
        for _,entry in ipairs(list) do if entry.id==current then name=entry.name end end
        active:SetText(string.format(L.WORKSPACE_PROFILE_ACTIVE,name))
        create:SetEnabled(current~=nil);save:SetEnabled(current~=nil)
        load:SetEnabled(selected~=nil and selected~=current);rename:SetEnabled(selected~=nil)
        delete:SetEnabled(selected~=nil and selected~=current and selected~="default")
    end)

    local routing=card(tabs.panels,L.WORKSPACE_ROUTING_TITLE,144,
        L.WORKSPACE_ROUTING_HELP,L.WORKSPACE_ROUTING_SCOPE)
    local routingHelp=Text(routing,L.WORKSPACE_ROUTING_HELP,12,-34,628)
    local routeBody=CreateFrame("Frame",nil,routing)
    local function Destinations()
        local values={{id="AUTO",label=L.WORKSPACE_ROUTE_AUTO},{id="MAINHAND",label=L.WORKSPACE_ROUTE_MAINHAND}}
        for index,r in ipairs(Regions()) do values[#values+1]={id=r.id,label=string.format(L.WORKSPACE_REGION_NUMBER,index)} end
        return values
    end
    local groups=Offhand.WorkspaceRouting:GetGroups()
    local panels,panelLabels={},{}
    for _,group in ipairs(groups) do
        local label=L[group.label]
        panels[#panels+1]={id=group.id,label=label}
        panelLabels[group.id]=label
    end
    local panel=panels[1] and panels[1].id
    local function Destination()
        local routes=Offhand.db and Offhand.db.workspacePanelRoutes
        return type(routes)=="table" and routes[panel] or "AUTO"
    end
    local legacyMenu
    local function Dropdown(x,width,values,get,set)
        local button=Button(routeBody,"",x,0,width,function(self)
            local entries=values()
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self,function(_,root)
                    for _,entry in ipairs(entries) do
                        root:CreateRadio(entry.label,function(id) return get()==id end,set,entry.id)
                    end
                end)
            elseif UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and ToggleDropDownMenu then
                legacyMenu=legacyMenu or CreateFrame("Frame","OffhandPanelRoutingMenu",routeBody,"UIDropDownMenuTemplate")
                UIDropDownMenu_Initialize(legacyMenu,function()
                    for _,entry in ipairs(entries) do
                        local id=entry.id
                        UIDropDownMenu_AddButton({text=entry.label,checked=get()==id,func=function() set(id) end},1)
                    end
                end,"MENU")
                ToggleDropDownMenu(1,nil,legacyMenu,"cursor",0,0)
            end
        end)
        local arrow=button:CreateTexture(nil,"ARTWORK")
        arrow:SetSize(16,16)
        arrow:SetPoint("RIGHT",button,"RIGHT",-5,0)
        arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        local text=button:GetFontString()
        if text then text:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-23,2) end
        return button
    end
    routeBody:SetScript("OnHide",function()
        if legacyMenu and CloseDropDownMenus
            and (UIDROPDOWNMENU_OPEN_MENU==legacyMenu or UIDROPDOWNMENU_OPEN_MENU==legacyMenu:GetName()) then
            CloseDropDownMenus()
        end
    end)
    local panelTitle=Text(routeBody,L.WORKSPACE_ROUTE_PANEL_TYPE,12,0,196)
    local destinationTitle=Text(routeBody,L.WORKSPACE_ROUTE_DESTINATION,218,0,260)
    local panelChoice=Dropdown(12,196,function() return panels end,function() return panel end,function(id)
        panel=id
        UI:Refresh()
    end)
    local destinationChoice=Dropdown(218,260,Destinations,Destination,function(value)
        Report(Offhand.WorkspaceRouting:SetRule(panel,value~="AUTO" and value or nil))
    end)
    local resetRoute=Button(routeBody,L.WORKSPACE_ROUTE_RESET,488,0,158,function()
        local id=panel
        options:Confirm(panelLabels[id].."\n\n"..L.WORKSPACE_ROUTE_RESET_CONFIRM,function()
            Report(Offhand.WorkspaceRouting:ResetManual(id))
        end)
    end)
    local routingHeight
    refreshers[#refreshers+1]=function()
        local metrics=Offhand.Viewport and Offhand.Viewport:GetMetrics()
        local available=panel and metrics and metrics.isSpanned and #(metrics.workspaceRegions or {})>0
        local description=L[available and "WORKSPACE_ROUTING_HELP" or "WORKSPACE_CUSTOM_REQUIRED"]
        routingHelp:SetText(description)
        local height=34+Controls.FitCompactParagraph(routingHelp,description,628)+14
        if available then
            local label=panelLabels[panel]
            local destination=Destination()
            local targetLabel
            for _,entry in ipairs(Destinations()) do
                if entry.id==destination then targetLabel=entry.label;break end
            end
            targetLabel=targetLabel or string.format(L.WORKSPACE_MISSING_REGION,tostring(destination))
            panelChoice:SetText(label)
            destinationChoice:SetText(targetLabel)
            local rowTop=math.max(Controls.FitCompactParagraph(panelTitle,L.WORKSPACE_ROUTE_PANEL_TYPE,196),
                Controls.FitCompactParagraph(destinationTitle,L.WORKSPACE_ROUTE_DESTINATION,260))+5
            local rowHeight=26
            for _,button in ipairs({panelChoice,destinationChoice,resetRoute}) do
                rowHeight=math.max(rowHeight,Controls.MeasureWrappedText(button:GetFontString(),button:GetText(),button:GetWidth()-28,14)+8)
            end
            panelChoice:SetPoint("TOPLEFT",routeBody,"TOPLEFT",12,-rowTop)
            destinationChoice:SetPoint("TOPLEFT",routeBody,"TOPLEFT",218,-rowTop)
            resetRoute:SetPoint("TOPLEFT",routeBody,"TOPLEFT",488,-rowTop)
            panelChoice:SetHeight(rowHeight);destinationChoice:SetHeight(rowHeight);resetRoute:SetHeight(rowHeight)
            local bodyHeight=rowTop+rowHeight
            routeBody:SetPoint("TOPLEFT",routing,"TOPLEFT",0,-height)
            routeBody:SetSize(662,bodyHeight)
            routeBody:Show()
            height=height+bodyHeight+14
        else
            routeBody:Hide()
        end
        if height~=routingHeight then
            routingHeight=height
            routing:SetHeight(height)
            if routing.onSizingChanged then routing.onSizingChanged() end
        end
    end

    local sizing
    if Offhand.WorkspaceScaleControls then
        sizing=card(tabs.panels,L.REGION_SCALE_TITLE,140,L.REGION_SCALE_DETAILS)
        local control=Offhand.WorkspaceScaleControls:BuildAdvanced(sizing,628,true)
        control:SetPoint("TOPLEFT",sizing,"TOPLEFT",12,-34)
        sizing:SetHeight(control:GetHeight()+46)
        control.onResize=function(height,reveal)
            sizing:SetHeight(height+46)
            if sizing.onSizingChanged then sizing.onSizingChanged(reveal) end
        end
        refreshers[#refreshers+1]=function()control:Refresh()end
        control:Refresh()
    end

    local themeCard=card(tabs.appearance,L.WORKSPACE_THEMES_TITLE,342,
        L.WORKSPACE_THEMES_HELP,L.WORKSPACE_MEDIA_HELP)
    local themeHelp=Text(themeCard,L.WORKSPACE_THEMES_HELP,12,-34,628)
    local themeFooter=Text(themeCard,L.WORKSPACE_MEDIA_HELP,12,-286,628)
    local themeChoices={{id="INHERIT",label=L.WORKSPACE_THEME_INHERIT},
        {id="CLASSIC",label=L.THEME_CLASSIC},{id="BLIZZARD_SLATE",label=L.THEME_SLATE},
        {id="OBSIDIAN",label=L.THEME_OBSIDIAN},{id="PITCH_BLACK",label=L.THEME_PITCH_BLACK},
        {id="GNOMISH_TINKER",label=L.THEME_TINKER}}
    local regionRows={}
    local function MediaChoices()
        local choices={{id="INHERIT",label=L.WORKSPACE_MEDIA_INHERIT},
            {id="THEME",label=L.WORKSPACE_MEDIA_THEME},{id="IMAGE",label=L.WORKSPACE_MEDIA_IMAGE}}
        local assets=Offhand.UserMedia and Offhand.UserMedia:GetAssets() or {}
        if #assets>1 or assets[1] and assets[1].id~="shared" then
            for _,asset in ipairs(assets) do choices[#choices+1]={id="ASSET:"..asset.id,label=asset.name} end
        end
        return choices
    end
    local fitChoices={{id="INHERIT",label=L.WORKSPACE_MEDIA_FIT_INHERIT},
        {id="PACKAGE",label=L.USER_MEDIA_FIT_PACKAGE},{id="FILL",label=L.USER_MEDIA_FIT_FILL},
        {id="FIT",label=L.USER_MEDIA_FIT_FIT},{id="STRETCH",label=L.USER_MEDIA_FIT_STRETCH}}
    local function RegionSetting(i,key)
        local r=Regions()[i];local all=Offhand.db and Offhand.db.workspaceRegionThemes
        local settings=r and type(all)=="table" and all[r.id]
        return type(settings)=="table" and settings[key] or "INHERIT"
    end
    local maxRegions=Offhand.WorkspaceRegions and Offhand.WorkspaceRegions.MAX_WORKSPACES or 2
    for index=1,maxRegions do
        local i=index;local y=-90-(i-1)*104;local label=Text(themeCard,"",12,y-5,190)
        local button=Choice(themeCard,208,y,438,themeChoices,
            function()
                local r=Regions()[i];local all=Offhand.db and Offhand.db.workspaceRegionThemes
                local settings=r and type(all)=="table" and all[r.id]
                return type(settings)=="table" and settings.theme or "INHERIT"
            end,
            function(value)
                local r=Regions()[i];if not r then return false,"WORKSPACE_CUSTOM_REQUIRED" end
                return Offhand.Themes:SetRegionTheme(r.id,value~="INHERIT" and value or nil)
            end)
        local media=Choice(themeCard,12,y-34,310,MediaChoices,
            function()
                local mode=RegionSetting(i,"userMediaMode");local asset=RegionSetting(i,"userMediaAssetID")
                if mode=="IMAGE" and asset~="INHERIT" then
                    return type(asset)=="string" and "ASSET:"..asset or "INVALID_ASSET"
                end
                return mode
            end,
            function(value)
                local r=Regions()[i];if not r then return false,"WORKSPACE_CUSTOM_REQUIRED" end
                local assetID=value:match("^ASSET:(.+)$")
                local ok,err=Offhand.Themes:SetRegionMediaMode(r.id,assetID and "IMAGE" or value~="INHERIT" and value or nil)
                if not ok then return ok,err end
                return Offhand.Themes:SetRegionMediaAsset(r.id,assetID)
            end,L.WORKSPACE_MEDIA_MISSING)
        local fit=Choice(themeCard,332,y-34,314,fitChoices,
            function()return RegionSetting(i,"userMediaFitMode")end,
            function(value)
                local r=Regions()[i];if not r then return false,"WORKSPACE_CUSTOM_REQUIRED" end
                return Offhand.Themes:SetRegionMediaFit(r.id,value~="INHERIT" and value or nil)
            end)
        regionRows[i]={label=label,button=button,media=media,fit=fit}
    end
    local themeHeight
    refreshers[#refreshers+1]=function()
        local regions = Regions()
        local count = math.min(#regions, #regionRows)
        local help = count > 0 and L.WORKSPACE_THEMES_HELP or L.WORKSPACE_CUSTOM_REQUIRED
        themeHelp:SetText(help)
        local helpBottom = 34 + Controls.FitCompactParagraph(themeHelp, help, 628)
        local firstRowTop = math.max(90, helpBottom + 10)
        for i, row in ipairs(regionRows) do
            local visible = i <= count
            row.button:SetEnabled(visible)
            row.media:SetEnabled(visible)
            row.fit:SetEnabled(visible)
            if visible then
                local y = -(firstRowTop + (i - 1) * 104)
                row.label:SetText(string.format(L.WORKSPACE_REGION_NUMBER, i))
                row.label:SetPoint("TOPLEFT", themeCard, "TOPLEFT", 12, y - 5)
                row.button:SetPoint("TOPLEFT", themeCard, "TOPLEFT", 208, y)
                row.media:SetPoint("TOPLEFT", themeCard, "TOPLEFT", 12, y - 34)
                row.fit:SetPoint("TOPLEFT", themeCard, "TOPLEFT", 332, y - 34)
                row.label:Show()
                row.button:Show()
                row.media:Show()
                row.fit:Show()
            else
                row.label:Hide()
                row.button:Hide()
                row.media:Hide()
                row.fit:Hide()
            end
        end
        local bottom = helpBottom
        if count > 0 then
            local footerTop = firstRowTop + count * 104 - 12
            themeFooter:SetPoint("TOPLEFT", themeCard, "TOPLEFT", 12, -footerTop)
            themeFooter:Show()
            bottom = footerTop + Controls.FitCompactParagraph(themeFooter, L.WORKSPACE_MEDIA_HELP, 628)
        else
            themeFooter:Hide()
        end
        local height = bottom + 14
        if height ~= themeHeight then
            themeHeight = height
            themeCard:SetHeight(height)
            if themeCard.onSizingChanged then themeCard.onSizingChanged() end
        end
    end
    UI.refreshers=refreshers
    -- Resolve profile selection before its choice label is first rendered.
    local _,current=Offhand.WorkspaceProfiles:List();selected=current
    UI.controls={sizing=sizing,profiles=profiles,picker=picker,name=input,routing=routing,themes=themeCard,regions=regionRows}
    UI:Refresh()
    return UI.controls
end
function UI:Refresh()
    for _,refresh in ipairs(self.refreshers or {}) do refresh() end
end
