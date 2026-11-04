local _,Offhand=...
local UI={}
Offhand.WorkspaceOptions=UI

function UI.Build(tabs,card,options)
    local L=Offhand.L
    local CreateFrame=Offhand.UIControls.CreateFrame
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
    local function Choice(parent,x,y,width,choices,get,set)
        local b
        local function Values() return type(choices)=="function" and choices() or choices end
        local function Update()
            local value=get();local label
            for _,entry in ipairs(Values()) do if entry.id==value then label=entry.label or entry.name end end
            b:SetText((label or string.format(L.WORKSPACE_MISSING_REGION,tostring(value))).."  >")
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

    local profiles=card(tabs.profiles,L.WORKSPACE_PROFILES_TITLE,258)
    Text(profiles,L.WORKSPACE_PROFILES_HELP,12,-34,628)
    local active=Text(profiles,"",12,-79,628)
    local selected
    local picker=Choice(profiles,12,-103,390,function()return Offhand.WorkspaceProfiles:List()end,
        function()return selected end,function(id)selected=id;return true end)
    local input=CreateFrame("EditBox",nil,profiles,"InputBoxTemplate")
    input:SetPoint("TOPLEFT",profiles,"TOPLEFT",18,-143);input:SetSize(380,26);input:SetAutoFocus(false)
    input:SetMaxLetters(96);input:SetScript("OnEscapePressed",function(self)self:ClearFocus()end)
    local create=Button(profiles,L.WORKSPACE_PROFILE_NEW,12,-185,122,function()
        local ok,err=Offhand.WorkspaceProfiles:Create(input:GetText())
        if ok then local _,id=Offhand.WorkspaceProfiles:List();selected=id end
        Report(ok,err);input:ClearFocus()
    end)
    Button(profiles,L.WORKSPACE_PROFILE_SAVE,140,-185,122,function()Report(Offhand.WorkspaceProfiles:Save())end)
    Button(profiles,L.PROFILES_BTN_LOAD or L.WORKSPACE_PROFILE_LOAD,268,-185,122,function()Report(Offhand.WorkspaceProfiles:Activate(selected))end)
    local rename=Button(profiles,L.WORKSPACE_PROFILE_RENAME,396,-185,122,function()Report(Offhand.WorkspaceProfiles:Rename(selected,input:GetText()))end)
    local delete=Button(profiles,L.WORKSPACE_PROFILE_DELETE,524,-185,122,function()
        local id=selected
        options:Confirm(L.WORKSPACE_PROFILE_DELETE_CONFIRM,function()Report(Offhand.WorkspaceProfiles:Delete(id))end)
    end)
    Text(profiles,L.WORKSPACE_PROFILE_NAME_HELP,18,-222,620)
    table.insert(refreshers,1,function()
        local list,current=Offhand.WorkspaceProfiles:List();local exists=false
        for _,entry in ipairs(list) do if entry.id==selected then exists=true end end
        if not exists then selected=current end
        local name=""
        for _,entry in ipairs(list) do if entry.id==current then name=entry.name end end
        active:SetText(string.format(L.WORKSPACE_PROFILE_ACTIVE,name))
        create:SetEnabled(current~=nil);rename:SetEnabled(selected~=nil)
        delete:SetEnabled(selected~=nil and selected~=current and selected~="default")
    end)

    local routing=card(tabs.workspace,L.WORKSPACE_ROUTING_TITLE,344)
    Text(routing,L.WORKSPACE_ROUTING_HELP,12,-34,628)
    local function Destinations()
        local values={{id="AUTO",label=L.WORKSPACE_ROUTE_AUTO},{id="MAINHAND",label=L.WORKSPACE_ROUTE_MAINHAND}}
        for index,r in ipairs(Regions()) do values[#values+1]={id=r.id,label=string.format(L.WORKSPACE_REGION_NUMBER,index)} end
        return values
    end
    for index,group in ipairs(Offhand.WorkspaceRouting:GetGroups()) do
        local id=group.id;local y=-95-(index-1)*36
        Text(routing,L[group.label],12,y-5,190)
        Choice(routing,208,y,274,Destinations,
            function()local routes=Offhand.db and Offhand.db.workspacePanelRoutes;return type(routes)=="table" and routes[id] or "AUTO" end,
            function(value)return Offhand.WorkspaceRouting:SetRule(id,value~="AUTO" and value or nil)end)
        Button(routing,L.WORKSPACE_ROUTE_RESET,492,y,154,function()
            options:Confirm(L.WORKSPACE_ROUTE_RESET_CONFIRM,function()Report(Offhand.WorkspaceRouting:ResetManual(id))end)
        end)
    end
    Text(routing,L.WORKSPACE_ROUTING_SCOPE,12,-315,628)

    local themeCard=card(tabs.themes,L.WORKSPACE_THEMES_TITLE,342)
    local themeHelp=Text(themeCard,L.WORKSPACE_THEMES_HELP,12,-34,628)
    local themeChoices={{id="INHERIT",label=L.WORKSPACE_THEME_INHERIT},
        {id="CLASSIC",label=L.THEME_CLASSIC},{id="BLIZZARD_SLATE",label=L.THEME_SLATE},
        {id="OBSIDIAN",label=L.THEME_OBSIDIAN},{id="PITCH_BLACK",label=L.THEME_PITCH_BLACK},
        {id="GNOMISH_TINKER",label=L.THEME_TINKER}}
    local regionRows={}
    local mediaChoices={{id="INHERIT",label=L.WORKSPACE_MEDIA_INHERIT},
        {id="THEME",label=L.WORKSPACE_MEDIA_THEME},{id="IMAGE",label=L.WORKSPACE_MEDIA_IMAGE}}
    local fitChoices={{id="INHERIT",label=L.WORKSPACE_MEDIA_FIT_INHERIT},
        {id="PACKAGE",label=L.USER_MEDIA_FIT_PACKAGE},{id="FILL",label=L.USER_MEDIA_FIT_FILL},
        {id="FIT",label=L.USER_MEDIA_FIT_FIT},{id="STRETCH",label=L.USER_MEDIA_FIT_STRETCH}}
    local function RegionSetting(i,key)
        local r=Regions()[i];local all=Offhand.db and Offhand.db.workspaceRegionThemes
        local settings=r and type(all)=="table" and all[r.id]
        return type(settings)=="table" and settings[key] or "INHERIT"
    end
    for index=1,2 do
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
        local media=Choice(themeCard,12,y-34,310,mediaChoices,
            function()return RegionSetting(i,"userMediaMode")end,
            function(value)
                local r=Regions()[i];if not r then return false,"WORKSPACE_CUSTOM_REQUIRED" end
                return Offhand.Themes:SetRegionMediaMode(r.id,value~="INHERIT" and value or nil)
            end)
        local fit=Choice(themeCard,332,y-34,314,fitChoices,
            function()return RegionSetting(i,"userMediaFitMode")end,
            function(value)
                local r=Regions()[i];if not r then return false,"WORKSPACE_CUSTOM_REQUIRED" end
                return Offhand.Themes:SetRegionMediaFit(r.id,value~="INHERIT" and value or nil)
            end)
        regionRows[i]={label=label,button=button,media=media,fit=fit}
    end
    refreshers[#refreshers+1]=function()
        local regions=Regions();themeHelp:SetText(#regions>0 and L.WORKSPACE_THEMES_HELP or L.WORKSPACE_CUSTOM_REQUIRED)
        for i,row in ipairs(regionRows) do
            row.label:SetText(string.format(L.WORKSPACE_REGION_NUMBER,i))
            row.label:SetAlpha(regions[i] and 1 or 0.45);row.button:SetEnabled(regions[i]~=nil)
            row.media:SetEnabled(regions[i]~=nil);row.fit:SetEnabled(regions[i]~=nil)
        end
    end
    Text(themeCard,L.WORKSPACE_MEDIA_HELP,12,-286,628)
    UI.refreshers=refreshers
    -- Resolve profile selection before its choice label is first rendered.
    local _,current=Offhand.WorkspaceProfiles:List();selected=current
    UI.controls={profiles=profiles,picker=picker,name=input,routing=routing,themes=themeCard,regions=regionRows}
    UI:Refresh()
    return UI.controls
end
function UI:Refresh()
    for _,refresh in ipairs(self.refreshers or {}) do refresh() end
end
