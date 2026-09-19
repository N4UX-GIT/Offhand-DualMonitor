local _, Offhand = ...

local icon = CreateFrame("Button", "OffhandMinimapIcon", Minimap)
icon:SetSize(31, 31)
icon:SetFrameStrata("MEDIUM")
icon:SetFrameLevel(8)

local bg = icon:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("CENTER", 1, 1)

local texture = icon:CreateTexture(nil, "ARTWORK")
texture:SetTexture("Interface\\AddOns\\Offhand\\Media\\OffhandLogo64x64.blp")
texture:SetSize(20, 20)
texture:SetPoint("CENTER", 1, 1)

local border = icon:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT")

icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
icon:RegisterForDrag("LeftButton")
icon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local isDragging = false
icon:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    isDragging = true
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        local dx, dy = px - mx, py - my
        local angle = math.atan2(dy, dx)
        local radius = (Minimap:GetWidth() / 2) + 5
        self:ClearAllPoints()
        self:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        
        if Offhand.db then Offhand.db.minimapAngle = angle end
    end)
end)

icon:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    isDragging = false
    self:SetScript("OnUpdate", nil)
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    local angle = (Offhand.db and Offhand.db.minimapAngle) or 225
    local radius = (Minimap:GetWidth() / 2) + 5
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    Offhand:UpdateMinimapIcon()
end)

function Offhand:UpdateMinimapIcon()
    if Offhand.db and Offhand.db.showMinimapIcon == false then
        icon:Hide()
    else
        icon:Show()
    end
end

local menuFrame = CreateFrame("Frame", "OffhandMinimapMenu", UIParent, "UIDropDownMenuTemplate")

local function GatherOffScreenUI()
    if Offhand.GatherOffScreenUI then Offhand:GatherOffScreenUI() end
end

icon:SetScript("OnClick", function(self, button)
    if isDragging then return end
    if button == "LeftButton" then
        if Offhand.Options then Offhand.Options:Open() end
    elseif button == "RightButton" then
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
                rootDescription:CreateTitle("Offhand Workspace")
                rootDescription:CreateButton("Open Settings", function()
                    if Offhand.Options then Offhand.Options:Open() end
                end)
                rootDescription:CreateButton("Run Setup Wizard", function()
                    if Offhand.Wizard then Offhand.Wizard:Open() end
                end)
                rootDescription:CreateDivider()
                rootDescription:CreateButton("Gather Off-Screen UI", GatherOffScreenUI)
            end)
        else
            -- Fallback for older clients without MenuUtil
            local menuList = {
                { text = "Offhand Workspace", isTitle = true, notCheckable = true },
                { text = "Open Settings", notCheckable = true, func = function() if Offhand.Options then Offhand.Options:Open() end end },
                { text = "Run Setup Wizard", notCheckable = true, func = function() if Offhand.Wizard then Offhand.Wizard:Open() end end },
                { text = "", isTitle = true, notCheckable = true },
                { text = "Gather Off-Screen UI", notCheckable = true, func = GatherOffScreenUI }
            }
            EasyMenu(menuList, menuFrame, "cursor", 0, 0, "MENU")
        end
    end
end)

icon:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Offhand Workspace")
    GameTooltip:AddLine("Left-Click:|r Open Settings", 1, 1, 1)
    GameTooltip:AddLine("Right-Click:|r Open Menu", 1, 1, 1)
    GameTooltip:AddLine("Drag:|r Move Icon", 1, 1, 1)
    GameTooltip:Show()
end)
icon:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)


