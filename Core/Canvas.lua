--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/Canvas.lua: Unsegmented free-space secondary monitor workspace with universal window dragging
--]]

local _, Offhand = ...

local Canvas = {}
Offhand.Canvas = Canvas

local rootCanvas

-- Accept metrics from older modules/tests while all live Viewport metrics now
-- expose an explicit workspace rectangle.
local function WithWorkspace(metrics)
    if not metrics or metrics.workspaceLeft ~= nil then return metrics end
    local position = Offhand.db and Offhand.db.primaryPosition or "RIGHT"
    if position == "TOP" then
        metrics.workspaceLeft, metrics.workspaceBottom = 0, 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.screenWidth, metrics.deckWidth
    elseif position == "BOTTOM" then
        metrics.workspaceLeft, metrics.workspaceBottom = 0, metrics.gameTop + (metrics.bezel or 0)
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.screenWidth, metrics.deckWidth
    elseif position == "LEFT" then
        metrics.workspaceLeft, metrics.workspaceBottom = metrics.gameRight + (metrics.bezel or 0), 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.deckWidth, metrics.screenHeight
    else
        metrics.workspaceLeft, metrics.workspaceBottom = 0, 0
        metrics.workspaceWidth, metrics.workspaceHeight = metrics.deckWidth, metrics.screenHeight
    end
    metrics.workspaceRight = metrics.workspaceLeft + metrics.workspaceWidth
    metrics.workspaceTop = metrics.workspaceBottom + metrics.workspaceHeight
    return metrics
end

function Canvas:CreateFrames()
    if rootCanvas then return end

    -- Root Canvas (covers the secondary monitor as an open, unsegmented free workspace)
    rootCanvas = CreateFrame("Frame", "OffhandCanvasFrame", UIParent, "BackdropTemplate")
        rootCanvas:SetFrameStrata("BACKGROUND")
    rootCanvas:SetFrameLevel(1)

    -- Dedicated solid background texture for guaranteed vibrant color visibility
    if not rootCanvas.bgTexture and rootCanvas.CreateTexture then
        rootCanvas.bgTexture = rootCanvas:CreateTexture(nil, "BACKGROUND", nil, -8)
        if rootCanvas.bgTexture.SetAllPoints then
            rootCanvas.bgTexture:SetAllPoints(rootCanvas)
        end
    end

    Offhand.canvas = rootCanvas
end

function Canvas:UpdateLayout()
    if not rootCanvas then self:CreateFrames() end

    local metrics = WithWorkspace(Offhand.Viewport:GetMetrics())

    if not metrics.isSpanned or not Offhand.db.enabled then
        rootCanvas:Hide()
        return
    end

    rootCanvas:Show()
    rootCanvas:ClearAllPoints()
    rootCanvas:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", metrics.workspaceLeft, metrics.workspaceBottom)
    rootCanvas:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", metrics.workspaceRight, metrics.workspaceTop)

    -- Apply clean, dark backdrop theme to the workspace
    if Offhand.Themes and Offhand.Themes.ApplyCanvasTheme then
        Offhand.Themes:ApplyCanvasTheme(rootCanvas)
    end

    -- Enable free dragging for standard Blizzard frames so the player can move them anywhere on the workspace
    self:EnableFreeDragging()
    self:UpdateMapMovementBehavior()
end

local function HasLeatrixMaps()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Maps")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Maps")
    end
    return false
end

local function HasLeatrixPlus()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Leatrix_Plus")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Leatrix_Plus")
    end
    return false
end

local DemodalizePanel, RemodalizePanel, OnPanelDragStop, RestoreWorkspacePosition, IsFrameOnWorkspace
local EvictWorkspacePanelSlot
local nonMovableSystemPanels

-- Forever exposes Edit Mode through a load-on-demand addon.  The absence of
-- EditModeManagerFrame during early login therefore does not mean these frames
-- are safe for addons to move or make draggable.
local foreverEditModeFrameNames = {
    EditModeManagerFrame = true,
    EditModeSystemSettingsDialog = true,
    EditModeUnsavedChangesDialog = true,
    EditModeDialog = true,
    MainMenuBar = true,
    MainActionBar = true,
    StatusTrackingBarManager = true,
    MainMenuExpBar = true,
    MultiBarBottomLeft = true,
    MultiBarBottomRight = true,
    MultiBarLeft = true,
    MultiBarRight = true,
    StanceBar = true,
    PetActionBar = true,
    PossessActionBar = true,
    MinimapCluster = true,
    PlayerFrame = true,
    TargetFrame = true,
    FocusFrame = true,
    PartyFrame = true,
    PartyMemberFrame1 = true,
    CompactPartyFrame = true,
    CompactRaidFrameContainer = true,
    BuffFrame = true,
    BuffCluster = true,
    CastingBarFrame = true,
    PlayerCastingBarFrame = true,
    UIErrorsFrame = true,
    RaidWarningFrame = true,
    EssentialCooldownViewer = true,
    UtilityCooldownViewer = true,
    BuffIconCooldownViewer = true,
    BottomManagedFrameContainer = true,
}

local function IsForeverEditModeFrame(frame, suppliedName)
    if not Offhand.isForever then return false end
    local name = suppliedName or (frame and frame.GetName and frame:GetName())
    if frame and frame.isManagedFrame == true then return true end
    if not name then return false end
    return foreverEditModeFrameNames[name]
        or name:match("^EditMode") ~= nil
        or name:match("CooldownViewer") ~= nil
        or name:match("ManagedFrameContainer") ~= nil
        or name:match("^PartyMemberFrame") ~= nil
        or name:match("^CompactPartyFrame") ~= nil
        or name:match("^CompactRaidFrame") ~= nil
end

local function IsUnsafeForDirectMutation(frame)
    if not frame then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then return true end
    return false
end

-- Forever marks several ordinary, load-on-demand UIPanels as protected even
-- while they are only usable out of combat.  They may still be repositioned
-- from a hardware drag while out of combat. Keep the exception restricted to
-- Blizzard's UIPanel registry; secure HUD/Edit Mode frames are not registered
-- here and remain covered by the stricter guard above.
local function IsUnsafeForPanelMutation(frame, name)
    if not frame then return true end
    if frame.IsForbidden and frame:IsForbidden() then return true end
    if frame.IsProtected and frame:IsProtected() then
        name = name or (frame.GetName and frame:GetName())
        return not (name and UIPanelWindows and UIPanelWindows[name])
    end
    return false
end

local function RegisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    for _, n in ipairs(UISpecialFrames) do
        if n == name then return end
    end
    table.insert(UISpecialFrames, name)
end

local function UnregisterSpecialFrame(name)
    if not name or not UISpecialFrames then return end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == name then
            table.remove(UISpecialFrames, i)
        end
    end
end

local function HasChattynator()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Chattynator")
    elseif IsAddOnLoaded then
        return IsAddOnLoaded("Chattynator")
    end
    return false
end

-- Chattynator deliberately reuses Blizzard's primary edit box while anchoring
-- it to an unnamed Chattynator window.  Reattaching that edit box to the hidden
-- ChatFrame1 makes Enter focus a valid but invisible input field.
local function ShouldManageBlizzardChatEditBox(frame)
    return frame == ChatFrame1 and not HasChattynator()
end

local function IsRetailEditModePrimaryChat(frame)
    return Offhand.HUD and Offhand.HUD.IsRetailEditModePrimaryChat
        and Offhand.HUD:IsRetailEditModePrimaryChat(frame) or false
end

local function IsRetailChatEditModeActive(frame)
    return IsRetailEditModePrimaryChat(frame) and ((frame and frame.isInEditMode == true)
        or (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown()))
end

local function SaveOpenWorkspacePanels()
    if Offhand.ForeverPersistence and Offhand.ForeverPersistence.SaveOpenPanels then
        Offhand.ForeverPersistence:SaveOpenPanels(Offhand.db and Offhand.db.openWorkspacePanels)
    end
end

function Canvas:SetWorkspacePanelOpen(frameOrName, isOpen)
    if not Offhand.db then return false end
    local name = type(frameOrName) == "string" and frameOrName
        or (frameOrName and frameOrName.GetName and frameOrName:GetName())
    if not name then return false end
    Offhand.db.openWorkspacePanels = Offhand.db.openWorkspacePanels or {}
    local hasWorkspacePosition = Offhand.db.savedWorkspacePositions
        and Offhand.db.savedWorkspacePositions[name]
    if isOpen and hasWorkspacePosition then
        Offhand.db.openWorkspacePanels[name] = true
    else
        Offhand.db.openWorkspacePanels[name] = nil
    end
    SaveOpenWorkspacePanels()
    return Offhand.db.openWorkspacePanels[name] == true
end

function Canvas:UpdateMapMovementBehavior()
    local map = WorldMapFrame
    if not map then return end
    if HasLeatrixMaps() then return end

    if Offhand.db and Offhand.db.enabled and Offhand.db.preventMapCloseOnMove then
        pcall(function() map:UnregisterEvent("PLAYER_STARTED_MOVING") end)
    else
        pcall(function() map:RegisterEvent("PLAYER_STARTED_MOVING") end)
    end
end

function Canvas:UpdatePersistenceBehavior()
    if not Offhand.db then return end
    -- Forever's UI panel manager participates in secure Edit Mode and secret-value
    -- flows. Removing Blizzard frames from its global registries taints later panel
    -- opens, so native Escape behavior wins over persistent-open panels here.
    if Offhand.isForever then return end
    local shouldPersist = (Offhand.db.persistentWorkspacePanels ~= false)
    if WorldMapFrame then
        local isWs = (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]) or IsFrameOnWorkspace(WorldMapFrame)
        if isWs and shouldPersist then
            UnregisterSpecialFrame("WorldMapFrame")
        else
            RegisterSpecialFrame("WorldMapFrame")
        end
    end
    if Offhand.db.savedWorkspacePositions then
        for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
            local frame = _G[name]
            if frame then
                if shouldPersist then
                    UnregisterSpecialFrame(name)
                else
                    RegisterSpecialFrame(name)
                end
            end
        end
    end
end

-- Global Bag Closure Hook for Escape Persistence

-- The Combined Backpack close button uses CloseAllBags too. Distinguish that
-- explicit user action from Escape/CloseAllWindows cleanup so a workspace bag
-- can still be closed from its own X button.
local explicitCombinedBagClose = false

local function HandleCustomCloseAllBags(originalFunc, ...)
    if explicitCombinedBagClose then return originalFunc(...) end
    if InCombatLockdown() then return originalFunc(...) end
    if not Offhand.db or not Offhand.db.enabled or Offhand.db.persistentWorkspacePanels == false then
        return originalFunc(...)
    end
    
    local closedAny = false
    local framesToCheck = {}
    local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
    if not hasCustomBags then
        for i = 1, NUM_CONTAINER_FRAMES or 13 do
            table.insert(framesToCheck, _G["ContainerFrame"..i])
        end
        if _G.ContainerFrameCombinedBags then
            table.insert(framesToCheck, _G.ContainerFrameCombinedBags)
        end
    end
    
    for _, f in ipairs(framesToCheck) do
        if f and f.IsShown and f:IsShown() then
            local name = f.GetName and f:GetName()
            if name then
                local isWs = (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]) or IsFrameOnWorkspace(f)
                if not isWs then
                    if f.Hide then f:Hide() end
                    closedAny = true
                end
            end
        end
    end
    
    if closedAny then return true else return false end
end

if not Offhand.isForever and C_Container and C_Container.CloseAllBags and not _G.Offhand_Original_C_Container_CloseAllBags then
    _G.Offhand_Original_C_Container_CloseAllBags = C_Container.CloseAllBags
    C_Container.CloseAllBags = function(...)
        return HandleCustomCloseAllBags(_G.Offhand_Original_C_Container_CloseAllBags, ...)
    end
end


if not Offhand.isForever and CloseAllWindows and not _G.Offhand_OriginalCloseAllWindows then
    _G.Offhand_OriginalCloseAllWindows = CloseAllWindows
    CloseAllWindows = function(ignoreCenter)
        local activeWorkspaceFrames = {}
        local closedBags = false
        
        local function TrackFrame(f)
            if not f or not f.IsShown or not f:IsShown() then return end
            for _, existing in ipairs(activeWorkspaceFrames) do
                if existing == f then return end
            end
            if IsFrameOnWorkspace(f) then
                table.insert(activeWorkspaceFrames, f)
            end
        end

        local restoredSpecialFrames = {}
        local restoredUIPanels = {}
        
        if not ignoreCenter and not InCombatLockdown() and Offhand.db and Offhand.db.enabled and Offhand.db.persistentWorkspacePanels ~= false then
            -- 1. Track standard bags ONLY if no custom bag addon is controlling them
            local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
            if not hasCustomBags then
                local standardBags = {}
                for i = 1, NUM_CONTAINER_FRAMES or 13 do table.insert(standardBags, _G["ContainerFrame"..i]) end
                if _G.ContainerFrameCombinedBags then table.insert(standardBags, _G.ContainerFrameCombinedBags) end
                
                for _, f in ipairs(standardBags) do
                    if f and f.IsShown and f:IsShown() then
                        if IsFrameOnWorkspace(f) or (Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[f:GetName() or ""]) then
                            TrackFrame(f)
                        else
                            if f.Hide then f:Hide() end
                            closedBags = true
                        end
                    end
                end
            end
            
            -- 2. Track known saved workspace panels
            if Offhand.db.savedWorkspacePositions then
                for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
                    TrackFrame(_G[name])
                end
            end
            
            -- 3. Track ALL UISpecialFrames
            if UISpecialFrames then
                for _, name in ipairs(UISpecialFrames) do
                    TrackFrame(_G[name])
                end
            end
            
            -- 4. Track ALL UIPanelWindows
            if UIPanelWindows then
                for name, _ in pairs(UIPanelWindows) do
                    TrackFrame(_G[name])
                end
            end
            
            -- 5. Strip them out of the Blizzard engine so Hide() is never called!
            for _, f in ipairs(activeWorkspaceFrames) do
                local name = f.GetName and f:GetName()
                if name then
                    -- Temporarily remove from UISpecialFrames
                    if UISpecialFrames then
                        for i = #UISpecialFrames, 1, -1 do
                            if UISpecialFrames[i] == name then
                                table.insert(restoredSpecialFrames, name)
                                table.remove(UISpecialFrames, i)
                            end
                        end
                    end
                    -- Temporarily remove from UIPanelWindows
                    if UIPanelWindows and UIPanelWindows[name] and UIPanelWindows[name].area then
                        restoredUIPanels[name] = UIPanelWindows[name].area
                        UIPanelWindows[name].area = nil
                    end
                end
            end
            
            if #activeWorkspaceFrames > 0 then
                ignoreCenter = true -- Bypass native C_Container.CloseAllBags()
            end
        end
        
        -- Pre-scan ALL UI panels to see their EXACT state before CloseAllWindows runs
        local statesBefore = {}
        if not InCombatLockdown() then
            if UISpecialFrames then
                for _, name in ipairs(UISpecialFrames) do
                    local f = _G[name]
                    if f and f.IsShown and f:IsShown() then statesBefore[name] = true end
                end
            end
            if UIPanelWindows then
                for name, _ in pairs(UIPanelWindows) do
                    local f = _G[name]
                    if f and f.IsShown and f:IsShown() then statesBefore[name] = true end
                end
            end
            local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
            if not hasCustomBags then
                for i = 1, NUM_CONTAINER_FRAMES or 13 do
                    local f = _G["ContainerFrame"..i]
                    if f and f.IsShown and f:IsShown() then statesBefore[f:GetName()] = true end
                end
            end
        end
        
        local closedAny = _G.Offhand_OriginalCloseAllWindows(ignoreCenter)
        
        -- Post-scan: Did anything on the main screen actually close?
        if not InCombatLockdown() and closedAny then
            local legitimateClose = false
            local function CheckLegitimateClose(name)
                local f = _G[name]
                if f and statesBefore[name] and not f:IsShown() then
                    local isWs = false
                    for _, w in ipairs(activeWorkspaceFrames) do
                        if w == f then isWs = true; break end
                    end
                    -- A legitimate close is a frame not on the workspace that was physically visible to the user
                    if not isWs and f.GetEffectiveAlpha and f:GetEffectiveAlpha() > 0.05 then
                        local left, bottom, width, height = f:GetRect()
                        if left and bottom and width and height and width > 1 and height > 1 then
                            local scale = f:GetEffectiveScale() or 1
                            local fLeft, fBottom = left * scale, bottom * scale
                            local fRight, fTop = fLeft + (width * scale), fBottom + (height * scale)
                            
                            local pWidth = (UIParent:GetWidth() or 0) * (UIParent:GetEffectiveScale() or 1)
                            local pHeight = (UIParent:GetHeight() or 0) * (UIParent:GetEffectiveScale() or 1)
                            
                            -- Simple bounding box collision with the total UIParent bounds
                            if fLeft < pWidth and fRight > 0 and fBottom < pHeight and fTop > 0 then
                                legitimateClose = true
                            end
                        end
                    end
                end
            end
            
            if UISpecialFrames then
                for _, name in ipairs(UISpecialFrames) do CheckLegitimateClose(name) end
            end
            if UIPanelWindows and not legitimateClose then
                for name, _ in pairs(UIPanelWindows) do CheckLegitimateClose(name) end
            end
            if not legitimateClose and not hasCustomBags then
                for i = 1, NUM_CONTAINER_FRAMES or 13 do CheckLegitimateClose("ContainerFrame"..i) end
            end
            
            -- If the ONLY things that closed were our activeWorkspaceFrames, then we SPOOF the return value to false!
            -- This perfectly guarantees ToggleGameMenu will open the Game Menu on the first Escape.
            if not legitimateClose and #activeWorkspaceFrames > 0 then
                closedAny = false
            end
        end
        
        if not InCombatLockdown() then
            -- Put everything back!
            if UISpecialFrames then
                for _, name in ipairs(restoredSpecialFrames) do
                    table.insert(UISpecialFrames, name)
                end
            end
            if UIPanelWindows then
                for name, area in pairs(restoredUIPanels) do
                    UIPanelWindows[name].area = area
                end
            end
            
            -- Failsafe (in case something bypassed the tables and closed anyway)
            for _, f in ipairs(activeWorkspaceFrames) do
                if f.Show and not f:IsShown() then
                    f:Show()
                end
            end
        end
        
        return closedAny or closedBags
    end
end

if not Offhand.isForever and CloseAllBags and not _G.Offhand_OriginalCloseAllBags then
    _G.Offhand_OriginalCloseAllBags = CloseAllBags
    CloseAllBags = function(...)
        return HandleCustomCloseAllBags(_G.Offhand_OriginalCloseAllBags, ...)
    end
end

-- A load-on-demand UIPanel can register while the same hardware action that
-- loaded its Blizzard addon is still opening it. Calling ShowUIPanel from that
-- registration stack (or its immediate zero-delay continuation) can re-enter
-- the native panel loader and is a credible cause of reported Forever Beta
-- crashes when opening Professions. Give Blizzard time to finish first. If the
-- native K/micro-button path already showed the panel, only restore its saved
-- workspace anchor. Otherwise perform the requested reload restoration after
-- the frame is fully initialized.
function Canvas:QueuePersistentPanelRestore(frame, name)
    if not frame or not name or not C_Timer or not C_Timer.After then return false end
    if frame._OffhandPersistentRestoreQueued then return true end

    frame._OffhandPersistentRestoreQueued = true
    C_Timer.After(0.75, function()
        frame._OffhandPersistentRestoreQueued = nil
        local db = Offhand.db
        local shouldRestore = db and db.enabled
            and db.persistentWorkspacePanels ~= false
            and db.restoreWorkspaceOnReload ~= false
            and db.openWorkspacePanels and db.openWorkspacePanels[name]
            and db.savedWorkspacePositions and db.savedWorkspacePositions[name]
        if not shouldRestore then return end
        if InCombatLockdown() then
            if Offhand.RunOrQueueCombat then
                Offhand:RunOrQueueCombat(function()
                    Canvas:QueuePersistentPanelRestore(frame, name)
                end)
            end
            return
        end

        if frame.IsShown and frame:IsShown() then
            RestoreWorkspacePosition(frame)
            return
        end

        if ShowUIPanel and UIPanelWindows and UIPanelWindows[name] then
            pcall(ShowUIPanel, frame)
        elseif frame.Show then
            pcall(frame.Show, frame)
        end

        -- OnShow normally restores the position. Retain a final deferred pass
        -- for panels whose native layout writes its anchor after OnShow.
        C_Timer.After(0, function()
            if frame.IsShown and frame:IsShown() then
                RestoreWorkspacePosition(frame)
            end
        end)
    end)
    return true
end

function Canvas:RestorePersistentFrames()
    if not Offhand.db or not Offhand.db.enabled or Offhand.db.persistentWorkspacePanels == false then return end
    if Offhand.db.restoreWorkspaceOnReload == false then return end
    if not Offhand.db.savedWorkspacePositions then return end
    if InCombatLockdown() then
        if Offhand.RunOrQueueCombat and not self.persistentRestorePending then
            self.persistentRestorePending = true
            Offhand:RunOrQueueCombat(function()
                Canvas.persistentRestorePending = false
                Canvas:RestorePersistentFrames()
            end)
        end
        return
    end
    
    local hasBag = false
    local openPanels = Offhand.db.openWorkspacePanels or {}
    
    for name, _ in pairs(openPanels) do
        if name:match("^ContainerFrame") or name:match("^Baganator") or name:match("^Baginator") or name:match("^BGR") or name:match("^Bagnon") or name:match("^AdiBags") or name:match("^BetterBags") or name:match("^ArkInventory") or name == "CustomBagRestorer" then
            hasBag = true
            break
        end
    end
    
    for name, _ in pairs(Offhand.db.savedWorkspacePositions) do
        local frame = _G[name]
        if frame then
            if frame:IsShown() then
                RestoreWorkspacePosition(frame)
            elseif openPanels[name] then
                if name == "WorldMapFrame" then
                    if ToggleWorldMap then
                        ToggleWorldMap()
                    else
                        frame:Show()
                    end
                elseif name:match("^ContainerFrame") or name:match("Baganator") or name:match("Baginator") or name:match("BGR") or name:match("Bagnon") or name:match("AdiBags") or name:match("BetterBags") or name:match("ArkInventory") then
                    hasBag = true
                elseif name:match("^ChatFrame") then
                    frame:Show()
                    RestoreWorkspacePosition(frame)
                else
                    -- Generic UIPanels (Character, Quest, Guild, etc.)
                    Canvas:QueuePersistentPanelRestore(frame, name)
                end
            end
        end
    end
    
    -- Baganator has its own root-frame snapshot/restore path. The generic
    -- prefix scan can see its still-shown child buttons while the bag is hidden.
    if hasBag and not (Baganator and Offhand.BagPersistence) then
        C_Timer.After(1.5, function()
            -- Combined Backpack mode may never create ContainerFrame1 during
            -- startup, which makes the general compatibility heuristic report
            -- a false custom-bag positive. An explicit saved native root wins.
            local hasNativeCombinedSnapshot = openPanels.ContainerFrameCombinedBags
                and Offhand.db.savedWorkspacePositions.ContainerFrameCombinedBags
                and _G.ContainerFrameCombinedBags
            local hasCustomBagAddon = not hasNativeCombinedSnapshot
                and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
            local isAlreadyOpen = false

            if hasCustomBagAddon then
                if IsBagOpen then isAlreadyOpen = IsBagOpen(0) end
                -- Custom bags can route OpenAllBags to a toggle, so inspect
                -- their actual root frames before invoking it.
                for k, v in pairs(_G) do
                    if type(k) == "string" and type(v) == "table" and type(rawget(v, 0)) == "userdata" then
                        if k:match("^Baganator") or k:match("^Baginator") or k:match("^BGR") or k:match("^Bagnon") or k:match("^AdiBags") or k:match("^BetterBags") or k:match("^ArkInventory") or k:match("^ElvUI_ContainerFrame") then
                            local ok, isShown = pcall(function() return v:IsShown() end)
                            if ok and isShown then
                                isAlreadyOpen = true
                                break
                            end
                        end
                    end
                end
            else
                -- IsBagOpen() reports logical container state and can remain
                -- true while Forever's Combined Backpack root is hidden.
                -- Native restoration therefore trusts rendered frame state.
                local combined = _G.ContainerFrameCombinedBags
                isAlreadyOpen = combined and combined.IsShown and combined:IsShown() or false
                if not isAlreadyOpen then
                    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                        local frame = _G["ContainerFrame" .. i]
                        if frame and frame.IsShown and frame:IsShown() then
                            isAlreadyOpen = true
                            break
                        end
                    end
                end
            end

            if not isAlreadyOpen then
                if not hasCustomBagAddon and OpenAllBags then
                    OpenAllBags()
                elseif ToggleAllBags then
                    -- Some custom bags ignore OpenAllBags and expose only the
                    -- native toggle route.
                    ToggleAllBags()
                end
            end
        end)
    end

    -- Blizzard and Edit Mode can finish their initial layout after the first
    -- restore pass. Reapply only already-visible saved workspace frames so chat
    -- dimensions and panel-slot detachment win the final startup race.
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if Offhand.db and Offhand.db.enabled then
                Canvas:RepairShownWorkspacePanels()
            end
        end)
    end
end

function Canvas:ConfigureWorldMap()
    local map = WorldMapFrame
    if InCombatLockdown() or not map or HasLeatrixMaps() or not Offhand.db or not Offhand.db.enabled then return end

    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m or not m.isSpanned then return end

    -- Enable proper parent scaling so the map scales consistently with UIParent
    if map.SetIgnoreParentScale then
        pcall(function() map:SetIgnoreParentScale(false) end)
    end

    -- Ensure windowed mini world map in Classic Era. Forever owns protected
    -- map state and must not be minimized or have its CVar changed by Offhand.
    if not Offhand.isForever then
        pcall(function()
            if type(GetCVar("miniWorldMap")) == "string" and GetCVar("miniWorldMap") ~= "1" then
                SetCVar("miniWorldMap", "1")
            end
            if map.IsMaximized and map:IsMaximized() and map.Minimize then
                map:Minimize()
            end
        end)
    end

    if not map._OffhandWindowedHook and hooksecurefunc then
        map._OffhandWindowedHook = true
        local function ScheduleWindowed()
            if map._OffhandWindowedPending or not C_Timer then return end
            map._OffhandWindowedPending = true
            C_Timer.After(0, function()
                map._OffhandWindowedPending = nil
                local function ApplyWindowed()
                    if not Offhand.db or not Offhand.db.enabled or HasLeatrixMaps() then return end
                    if map.IsShown and map:IsShown() then
                        Canvas:ConfigureWorldMap()
                        RestoreWorkspacePosition(map)
                    end
                end
                if InCombatLockdown() then
                    if Offhand.RunOrQueueCombat then Offhand:RunOrQueueCombat(ApplyWindowed) end
                else ApplyWindowed() end
            end)
        end
        if map.Maximize then hooksecurefunc(map, "Maximize", ScheduleWindowed) end
        if map.HookScript then map:HookScript("OnShow", ScheduleWindowed) end
    end

    -- Hook Blizzard's built-in title button drag handlers
    if WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
        WorldMapTitleButton._OffhandHooked = true
        WorldMapTitleButton:RegisterForDrag("LeftButton")
        WorldMapTitleButton:HookScript("OnDragStart", function(self)
            if InCombatLockdown() or not Offhand.db.enabled then return end
            map._OffhandDragging = true
        end)
        WorldMapTitleButton:HookScript("OnDragStop", function(self)
            OnPanelDragStop(map)
        end)
    end
    if WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
        Canvas._titleButtonHooked = true
        hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
            OnPanelDragStop(map)
        end)
    end

    -- Interactive Ctrl + MouseWheel scaling
    local function OnMapMouseWheel(self, delta)
        if InCombatLockdown() or not IsControlKeyDown() then return end
        if not Offhand.db or not Offhand.db.enabled then return end
        local current = map:GetScale() or 1.0
        local newScale
        if delta > 0 then
            newScale = math.min(3.00, current + 0.05)
        else
            newScale = math.max(0.40, current - 0.05)
        end
        newScale = math.floor(newScale * 100 + 0.5) / 100

        if IsFrameOnWorkspace(map) then
            Offhand.db.workspaceMapScale = newScale
            Canvas:ConfigureWorldMap()
            OnPanelDragStop(map)
        else
            Offhand.db.mainMapScale = newScale
            map:SetScale(newScale)
            OnPanelDragStop(map)
        end

        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(string.format("World Map Scale: %d%%", math.floor(newScale * 100 + 0.5)), 1.0, 0.82, 0.0, 1.0, 1.2)
        end
    end

    if not map._OffhandWheelHooked then
        map._OffhandWheelHooked = true
        if map.EnableMouseWheel then map:EnableMouseWheel(true) end
        if map.HookScript then map:HookScript("OnMouseWheel", OnMapMouseWheel) end
    end
    if WorldMapTitleButton and not WorldMapTitleButton._OffhandWheelHooked then
        WorldMapTitleButton._OffhandWheelHooked = true
        if WorldMapTitleButton.EnableMouseWheel then WorldMapTitleButton:EnableMouseWheel(true) end
        if WorldMapTitleButton.HookScript then WorldMapTitleButton:HookScript("OnMouseWheel", OnMapMouseWheel) end
    end

    -- If map is on the workspace, apply preferred or auto-fit scale
    local pos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]
    local isWorkspaceMap = pos or (not (Offhand.db.savedMainPositions and Offhand.db.savedMainPositions.WorldMapFrame) and IsFrameOnWorkspace(map))
    if isWorkspaceMap then
        if PlayerMovementFrameFader and PlayerMovementFrameFader.RemoveFrame then
            pcall(function() PlayerMovementFrameFader.RemoveFrame(map) end)
        end
        local userScale = Offhand.db.workspaceMapScale
        local fitScale
        if userScale and userScale ~= "AUTO" and tonumber(userScale) and tonumber(userScale) > 0 then
            fitScale = tonumber(userScale)
        else
            local baseWidth = map:GetWidth() or 610
            if baseWidth <= 0 then baseWidth = 610 end
            local availableWidth = m.workspaceWidth - 24
            fitScale = math.max(0.50, math.min(3.00, availableWidth / baseWidth))
        end
        map:SetScale(fitScale)
        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame("WorldMapFrame")
            EvictWorkspacePanelSlot(map)
        end
    else
        if PlayerMovementFrameFader and PlayerMovementFrameFader.AddDeferredFrame then
            pcall(function()
                PlayerMovementFrameFader.AddDeferredFrame(
                    map, .5, 1.0, 0.5,
                    function() return not map:IsMaximized() end)
            end)
        end
        local userMainScale = Offhand.db.mainMapScale
        if userMainScale and tonumber(userMainScale) and tonumber(userMainScale) > 0 then
            map:SetScale(tonumber(userMainScale))
        else
            map:SetScale(1.0)
        end
        RegisterSpecialFrame("WorldMapFrame")
    end

    local availableWidth, availableHeight = m.gameWidth-24, m.gameHeight-24
    if isWorkspaceMap then
        availableWidth, availableHeight = m.workspaceWidth-24, m.workspaceHeight-24
    end
    local width, height = map:GetWidth(), map:GetHeight()
    if width and height and width > 0 and height > 0 and availableWidth > 0 and availableHeight > 0 then
        local inherited = map:GetEffectiveScale() / map:GetScale() / UIParent:GetEffectiveScale()
        local scale = math.min(map:GetScale(), availableWidth/width/inherited, availableHeight/height/inherited)
        if scale > 0 and scale < math.huge then map:SetScale(scale) end
    end

    if not map._OffhandPersistenceHooked and map.HookScript then
        map._OffhandPersistenceHooked = true
        map:HookScript("OnShow", function(self)
            local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["WorldMapFrame"]) or IsFrameOnWorkspace(self)
            if isWs and (Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) then
                UnregisterSpecialFrame("WorldMapFrame")
                if not self._OffhandEvictingPanelSlot and C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        local saved = Offhand.db and Offhand.db.savedWorkspacePositions
                            and Offhand.db.savedWorkspacePositions["WorldMapFrame"]
                        if saved and self.IsShown and self:IsShown() then
                            RestoreWorkspacePosition(self)
                            Canvas:RepairShownWorkspacePanels(self)
                        end
                    end)
                end
            else
                RegisterSpecialFrame("WorldMapFrame")
            end
        end)
        map:HookScript("OnHide", function(self)
            if self._OffhandEvictingPanelSlot or not C_Timer or not C_Timer.After then return end
            C_Timer.After(0, function()
                Canvas:RepairShownWorkspacePanels(self)
            end)
        end)
    end
end

IsFrameOnWorkspace = function(frame)
    if not frame then return false end
    local x = frame:GetLeft()
    local y = frame.GetBottom and frame:GetBottom()
    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m then return false end
    if not x then
        local numPoints = frame.GetNumPoints and frame:GetNumPoints() or 0
        for i = 1, numPoints do
            local _, relTo, _, px = frame:GetPoint(i)
            if px then x = px; break end
        end
    end
    if not x or not y then return false end
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local scaleFactor = frameScale / parentScale
    local width = (frame:GetWidth() or 0) * scaleFactor
    local height = (frame:GetHeight() or 0) * scaleFactor
    if width <= 0 then width = 192 * scaleFactor end
    if height <= 0 then height = 192 * scaleFactor end
    local centerX = (x * scaleFactor) + (width / 2)
    local centerY = (y * scaleFactor) + (height / 2)
    return centerX >= m.workspaceLeft and centerX <= m.workspaceRight
        and centerY >= m.workspaceBottom and centerY <= m.workspaceTop
end

local originalAreas = {}

-- A workspace panel can still occupy one of Blizzard's active UIPanel slots
-- even after it has been removed from UISpecialFrames. Escape closes that slot
-- independently. Detach only the already-saved workspace panel; do not alter
-- UIPanelWindows or any secure layout attributes (especially on Forever).
EvictWorkspacePanelSlot = function(frame)
    if not frame or not GetUIPanel or not HideUIPanel or frame._OffhandEvictingPanelSlot then return false end
    local occupiesSlot = GetUIPanel("left") == frame or GetUIPanel("center") == frame
        or GetUIPanel("right") == frame or GetUIPanel("doublewide") == frame
    if not occupiesSlot then return false end

    -- Keep Blizzard's scripts installed. Replacing even an unchanged protected
    -- World Map handler taints later quest-pin acquisition on Forever. The
    -- re-entrancy flag makes Offhand's secure post-hooks ignore this deliberate
    -- hide/show cycle while Blizzard vacates the UIPanel slot normally.
    frame._OffhandEvictingPanelSlot = true
    pcall(function() HideUIPanel(frame, 1) end)
    if frame.Show then frame:Show() end
    frame._OffhandEvictingPanelSlot = nil
    return true
end


DemodalizePanel = function(frame)
      if not frame then return end
      local name = frame:GetName()
      if not name then return end

      -- Removing the workspace map from Blizzard's movement fader prevents the
      -- intended always-open map from becoming subdued while the player runs.
      -- This public fader registration is independent of the protected map
      -- scripts and UIPanel metadata that must remain untouched on Forever.
      if frame == WorldMapFrame and PlayerMovementFrameFader
          and PlayerMovementFrameFader.RemoveFrame then
          pcall(function() PlayerMovementFrameFader.RemoveFrame(WorldMapFrame) end)
      end

      -- Do not mutate Forever's Blizzard-owned panel registry or panel-layout
      -- attributes. Those feed protected UI execution paths.
      if Offhand.isForever then return end

      if UIPanelWindows and UIPanelWindows[name] then
          if name == "CharacterFrame" then
              if not originalAreas[name] then
                  originalAreas[name] = { isAreaNil = true, val = UIPanelWindows[name].area }
              end
              UIPanelWindows[name].area = nil
          else
              if not originalAreas[name] then
                  originalAreas[name] = { isAreaNil = false, val = UIPanelWindows[name] }
              end
              UIPanelWindows[name] = nil
          end
      end
    if SetUIPanelAttribute then
        pcall(function() SetUIPanelAttribute(frame, "area", nil) end)
    end
    local isWs = (Offhand.db and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]) or IsFrameOnWorkspace(frame)
    if isWs and (Offhand.db and Offhand.db.persistentWorkspacePanels ~= false) then
        UnregisterSpecialFrame(name)
    else
        RegisterSpecialFrame(name)
    end
end

RemodalizePanel = function(frame)
      if not frame then return end
      local name = frame:GetName()
      if not name then return end

      if frame == WorldMapFrame and PlayerMovementFrameFader and PlayerMovementFrameFader.AddDeferredFrame then
          pcall(function()
              PlayerMovementFrameFader.AddDeferredFrame(
                  WorldMapFrame, .5, 1.0, 0.5,
                  function() return not WorldMapFrame:IsMaximized() end)
          end)
      end

      if Offhand.isForever then return end

      UnregisterSpecialFrame(name)
      if originalAreas[name] then
          if UIPanelWindows then
              if originalAreas[name].isAreaNil then
                  if UIPanelWindows[name] then UIPanelWindows[name].area = originalAreas[name].val end
              else
                  UIPanelWindows[name] = originalAreas[name].val
              end
          end
          if SetUIPanelAttribute then
              local area = originalAreas[name].isAreaNil and originalAreas[name].val or (originalAreas[name].val and originalAreas[name].val.area)
              pcall(function() SetUIPanelAttribute(frame, "area", area) end)
          end
      end
  end

OnPanelDragStop = function(frame)
    if not frame then return end
    if InCombatLockdown() then frame._OffhandDragging = false; return end
    local dragName = frame.GetName and frame:GetName()
    if IsForeverEditModeFrame(frame, dragName) or IsUnsafeForPanelMutation(frame, dragName) then
        frame._OffhandDragging = false
        return
    end
    if dragName and dragName:match("^ChatFrame%d+$") then frame._OffhandDragging = true end
    if frame.StopMovingOrSizing then
        pcall(function() frame:StopMovingOrSizing() end)
    end
    local name = frame.GetName and frame:GetName()
    local wasShown = not frame.IsShown or frame:IsShown()

    -- Capture the hardware drag result before changing Blizzard's user-placed
    -- state. Some clients immediately restore the native anchor when
    -- SetUserPlaced(false) runs, which previously made a valid workspace drop
    -- look like a Mainhand-centered drop on every monitor orientation.
    local dragFrameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local dragParentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local dragScaleFactor = dragFrameScale / dragParentScale
    local dragLeftRaw = frame.GetLeft and frame:GetLeft() or 0
    local dragTopRaw = frame.GetTop and frame:GetTop() or 0
    local dragLeftInParent = dragLeftRaw * dragScaleFactor
    local dragTopInParent = dragTopRaw * dragScaleFactor
    local droppedOnWorkspace = IsFrameOnWorkspace(frame)

    if name and string.match(name, "^ChatFrame") then
        
    elseif not Offhand.isForever then
        -- Forever should retain Blizzard's user-placed state. Clearing it can
        -- synchronously return the frame to its native center anchor.
        pcall(function() frame:SetUserPlaced(false) end)
    end

    if not Offhand.db or not Offhand.db.enabled then
        frame._OffhandDragging = false
        return
    end
    local name = frame:GetName()
    if not name then
        frame._OffhandDragging = false
        return
    end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}

    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m then
        frame._OffhandDragging = false
        return
    end

    local onDeck = droppedOnWorkspace

    if IsRetailEditModePrimaryChat(frame) and not onDeck then
        -- Mainhand ChatFrame1 belongs to Retail Edit Mode. Remove legacy
        -- Offhand coordinates without writing another anchor over Blizzard's.
        Offhand.db.savedWorkspacePositions[name] = nil
        Offhand.db.savedMainPositions[name] = nil
        Canvas:SetWorkspacePanelOpen(name, false)
        if Offhand.ForeverPersistence then Offhand.ForeverPersistence:ClearPosition(name) end
        frame._OffhandDragging = false
        return
    end

    if onDeck then
        if frame == WorldMapFrame then
            Offhand.db.savedMainPositions.WorldMapFrame = nil
            Canvas:ConfigureWorldMap()
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local scaleFactor = frameScale / parentScale
        local xInParent = dragLeftInParent
        local yInParent = dragTopInParent
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Clamp strictly within the workspace boundaries so panels never bleed across the seam
        local inset = string.match(name, "^ChatFrame") and 48 or 12
        local minX = m.workspaceLeft + inset
        local maxX = math.max(minX, m.workspaceRight - frameWidth - 12)
        local clampedX = math.max(minX, math.min(xInParent, maxX))

        local screenHeight = m.workspaceHeight or m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = m.workspaceBottom + frameHeight + 12
        local maxY = math.max(minY, m.workspaceTop - 12)
        local clampedY = math.max(minY, math.min(yInParent, maxY))

        Offhand.db.savedWorkspacePositions[name] = {
            x = clampedX, y = clampedY,
            canvasWidth = m.workspaceWidth, canvasHeight = screenHeight,
            canvasLeft = m.workspaceLeft, canvasBottom = m.workspaceBottom,
        }
        if Offhand.db.savedMainPositions then
            Offhand.db.savedMainPositions[name] = nil
        end

        local rawW, rawH = frame:GetWidth(), frame:GetHeight()
        if Offhand.ForeverPersistence then
            Offhand.ForeverPersistence:SaveWorkspacePosition(
                name, Offhand.db.savedWorkspacePositions[name], rawW, rawH
            )
        end
        frame:ClearAllPoints()
        local factor = parentScale / frameScale
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
        
        if wasShown and (Offhand.db.independentWorkspacePanels or frame == WorldMapFrame) then
            -- Escape closes active UIPanel slots even when UISpecialFrames no
            -- longer contains this workspace panel.
            EvictWorkspacePanelSlot(frame)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
            frame:Show()
            DemodalizePanel(frame)
        end

        if wasShown and string.match(name, "^ContainerFrame") then
            if name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" then
                if Offhand.db.savedWorkspacePositions then
                    for i = 2, 13 do
                        Offhand.db.savedWorkspacePositions["ContainerFrame" .. i] = nil
                        local bf = _G["ContainerFrame" .. i]
                        if bf then pcall(function() bf:SetUserPlaced(false) end) end
                    end
                end
            end
            if not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                if Offhand.HUD and Offhand.HUD.LayoutBags then
                    Offhand.HUD:LayoutBags()
                end
            end
        elseif string.match(name, "^ChatFrame") then
            if ChatFrame1EditBox and ShouldManageBlizzardChatEditBox(frame) then
                if ChatFrame1EditBox.ClearAllPoints and ChatFrame1EditBox.SetPoint then
                    ChatFrame1EditBox:ClearAllPoints()
                    ChatFrame1EditBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                    ChatFrame1EditBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
                end
            end
            if FCF_SavePositionAndDimensions then
                pcall(function() FCF_SavePositionAndDimensions(frame) end)
            end
            if frame == ChatFrame1 and Offhand.HUD and Offhand.HUD.RepairChatButtons then
                Offhand.HUD:RepairChatButtons(frame)
            end
        end

        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
        if wasShown then Canvas:SetWorkspacePanelOpen(name, true) end
    else
        Offhand.db.savedWorkspacePositions[name] = nil
        Canvas:SetWorkspacePanelOpen(name, false)
        if Offhand.ForeverPersistence then
            Offhand.ForeverPersistence:ClearPosition(name)
        end
        if frame == WorldMapFrame then
            frame:SetScale(1.0)
            DemodalizePanel(frame)
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local scaleFactor = frameScale / parentScale
        -- World Map resets to scale 1 on Mainhand; retain its pre-reset anchor
        -- units to preserve the established map drag behavior.
        local xInParent = frame == WorldMapFrame and dragLeftRaw or dragLeftInParent
        local yInParent = frame == WorldMapFrame and dragTopRaw or dragTopInParent
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Clamp strictly inside the Game Viewport so panels never enter the black space above m.gameTop
        local minX = m.gameLeft + 12
        local maxX = math.max(minX, m.gameRight - frameWidth - 12)
        local clampedX = math.max(minX, math.min(xInParent, maxX))

        local minY = m.gameBottom + frameHeight + 12
        local maxY = math.max(minY, m.gameTop - 12)
        local clampedY = math.max(minY, math.min(yInParent, maxY))
        local factor = parentScale / frameScale

        if frame == WorldMapFrame then
            Offhand.db.savedMainPositions[name] = { x = clampedX, y = clampedY }
            RegisterSpecialFrame(name)
            local w, h = frame:GetWidth(), frame:GetHeight()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                    elseif string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "CompactRaidFrameContainer" then
            if EditModeManagerFrame then
                -- Retail Edit Mode manages these. Do not taint!
                Offhand.db.savedWorkspacePositions[name] = nil
                Offhand.db.savedMainPositions[name] = nil
            else
                Offhand.db.savedMainPositions[name] = { x = clampedX, y = clampedY }
                local w, h = frame:GetWidth(), frame:GetHeight()
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                            end
        
        elseif string.match(name, "^ContainerFrame") then
            pcall(function() frame:SetUserPlaced(false) end)
            if name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" then
                if Offhand.db.savedWorkspacePositions then
                    for i = 2, 13 do
                        Offhand.db.savedWorkspacePositions["ContainerFrame" .. i] = nil
                        local bf = _G["ContainerFrame" .. i]
                        if bf then pcall(function() bf:SetUserPlaced(false) end) end
                    end
                end
            end
            if not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                if Offhand.HUD and Offhand.HUD.LayoutBags then
                    Offhand.HUD:LayoutBags()
                end
            end
        elseif name == "MinimapCluster" then
            pcall(function() frame:SetUserPlaced(false) end)
            if Offhand.HUD and Offhand.HUD.AlignHUDFrames then
                Offhand.HUD:AlignHUDFrames()
            end
        elseif string.match(name, "^ChatFrame") then
            
            Offhand.db.savedMainPositions[name] = { point = "TOPLEFT", x = clampedX, y = clampedY }
            local w, h = frame:GetWidth(), frame:GetHeight()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                        if FCF_SavePositionAndDimensions then
                pcall(function() FCF_SavePositionAndDimensions(frame) end)
            end
            
            if frame == ChatFrame1 and Offhand.HUD and Offhand.HUD.RepairChatButtons then
                Offhand.HUD:RepairChatButtons(frame)
            end
        else
            Offhand.db.savedMainPositions[name] = {
                point = "TOPLEFT", x = clampedX, y = clampedY,
            }
            RemodalizePanel(frame)
            RegisterSpecialFrame(name)
            if UpdateUIPanelPositions and not Offhand.isForever then
                pcall(UpdateUIPanelPositions, frame)
            end
            local w, h = frame:GetWidth(), frame:GetHeight()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
                    end
    end

    frame._OffhandDragging = false
end

-- A missing saved display leaves no workspace rectangle. Close only panels
-- that were visible on that workspace so they do not get clamped into a pile
-- on Mainhand. Their saved geometry and open-state snapshot are intentionally
-- retained; reconnecting and reloading restores them. Panels opened manually
-- after recovery remain usable with Blizzard's native single-screen anchors.
local function IsSingleScreenRecovery(metrics)
    if Offhand.Viewport and Offhand.Viewport.IsSingleScreenRecovery then
        return Offhand.Viewport:IsSingleScreenRecovery(metrics)
    end
    return metrics and not metrics.isSpanned
        and (metrics.topologyStatus == "MISMATCH"
            or (Offhand.isForever and metrics.topologyStatus == "ABSENT")) or false
end

function Canvas:PrepareSingleScreenRecovery(metrics)
    if not IsSingleScreenRecovery(metrics) or not Offhand.db
        or not Offhand.db.savedWorkspacePositions then return end
    for name in pairs(Offhand.db.savedWorkspacePositions) do
        if not tostring(name):match("^ChatFrame%d+$") and not IsForeverEditModeFrame(_G[name], name) then
            local frame = _G[name]
            if frame and frame.IsShown and frame:IsShown() and frame.Hide then
                pcall(frame.Hide, frame)
            end
        end
    end
end

function Canvas:PlaceForSingleScreenRecovery(frame, metrics)
    if not frame or not Offhand.db or not Offhand.db.savedWorkspacePositions then return false end
    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics())
    if not IsSingleScreenRecovery(metrics) then return false end
    local name = frame.GetName and frame:GetName()
    if not name or not Offhand.db.savedWorkspacePositions[name]
        or IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return false end

    -- Blizzard Edit Mode's Modern fallback already places chat correctly and
    -- may also restore its preferred size. Do not override it with panel logic.
    if tostring(name):match("^ChatFrame%d+$") then return false end

    if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end
    if frame.ClearAllPoints and frame.SetPoint then
        pcall(function()
            frame:ClearAllPoints()
            if name == "CharacterFrame" then
                frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 24, -80)
            elseif name == "ContainerFrameCombinedBags" or tostring(name):match("^ContainerFrame%d+$")
                or tostring(name):match("Baganator") or tostring(name):match("Baginator")
                or tostring(name):match("Bagnon") or tostring(name):match("BetterBags") then
                frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -32, 140)
            else
                frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        end)
    end
    return true
end

-- Forever's Edit Mode can move and resize non-secure utility frames without
-- dispatching their normal drag callbacks. Mirror explicit Combined Backpack
-- and chat saves without touching protected Edit Mode anchors or handlers.
function Canvas:CaptureForeverFramePosition(frame)
    if not Offhand.isForever or InCombatLockdown() or not frame or not Offhand.db
        or not Offhand.db.enabled or not Offhand.ForeverPersistence then return false end
    local name = frame.GetName and frame:GetName()
    if name ~= "ContainerFrameCombinedBags" and not (name and name:match("^ChatFrame%d+$")) then return false end
    if IsUnsafeForDirectMutation(frame) or not frame.IsShown or not frame:IsShown() then return false end

    local ok, onWorkspace, x, y, width, height = pcall(function()
        local isWorkspace = IsFrameOnWorkspace(frame)
        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local factor = frameScale / parentScale
        local left = frame:GetLeft()
        local top = frame:GetTop()
        if not left or not top then return isWorkspace end
        return isWorkspace, left * factor, top * factor, frame:GetWidth(), frame:GetHeight()
    end)
    if not ok then return false end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    if onWorkspace and x and y then
        local metrics = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
        local position = {
            x = x, y = y, width = width, height = height,
            canvasWidth = metrics and metrics.workspaceWidth or nil,
            canvasHeight = metrics and metrics.workspaceHeight or nil,
            canvasLeft = metrics and metrics.workspaceLeft or nil,
            canvasBottom = metrics and metrics.workspaceBottom or nil,
        }
        Offhand.db.savedWorkspacePositions[name] = position
        Offhand.ForeverPersistence:SaveWorkspacePosition(name, position, width, height)
        return true
    elseif Offhand.db.savedWorkspacePositions[name] then
        Offhand.db.savedWorkspacePositions[name] = nil
        Offhand.ForeverPersistence:ClearPosition(name)
        return true
    end
    return false
end

-- Blizzard UIPanels anchor against the full UIParent. In an Offhand topology
-- that native origin may be the workspace, so an unsaved Spellbook,
-- Professions or Collections panel can open on the wrong monitor. Mainhand
-- placements use physical UIParent coordinates and are clamped on every
-- restore so display changes cannot strand a panel off screen.
function Canvas:PlacePanelOnMainhand(frame, metrics, position, preserveContained)
    if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
        or not Offhand.db.enabled then return false end
    local name = frame.GetName and frame:GetName()
    if not name or (nonMovableSystemPanels and nonMovableSystemPanels[name])
        or IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return false end

    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and WithWorkspace(Offhand.Viewport:GetMetrics()))
    if not metrics or not metrics.isSpanned then return false end

    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
    if parentScale <= 0 or frameScale <= 0 then return false end
    local scaleFactor = frameScale / parentScale
    local width = ((frame.GetWidth and frame:GetWidth()) or 0) * scaleFactor
    local height = ((frame.GetHeight and frame:GetHeight()) or 0) * scaleFactor
    if width <= 0 then width = 192 * scaleFactor end
    if height <= 0 then height = 192 * scaleFactor end

    local inset = 12
    local minX = metrics.gameLeft + inset
    local maxX = math.max(minX, metrics.gameRight - width - inset)
    local minY = metrics.gameBottom + height + inset
    local maxY = math.max(minY, metrics.gameTop - inset)

    if preserveContained and not position then
        local left = frame.GetLeft and frame:GetLeft()
        local top = frame.GetTop and frame:GetTop()
        if left and top then
            left, top = left * scaleFactor, top * scaleFactor
            if left >= minX and left + width <= metrics.gameRight - inset
                and top <= maxY and top - height >= metrics.gameBottom + inset then
                return false
            end
        end
    end

    local targetX = position and tonumber(position.x)
    local targetY = position and tonumber(position.y)
    if not targetX then
        targetX = metrics.gameLeft + (metrics.gameRight - metrics.gameLeft - width) / 2
    end
    if not targetY then
        targetY = metrics.gameBottom + (metrics.gameTop - metrics.gameBottom + height) / 2
    end
    local clampedX = math.max(minX, math.min(targetX, maxX))
    local clampedY = math.max(minY, math.min(targetY, maxY))
    local pointFactor = parentScale / frameScale

    local ok = pcall(function()
        if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            clampedX * pointFactor, clampedY * pointFactor)
    end)
    if ok then RegisterSpecialFrame(name) end
    return ok
end

RestoreWorkspacePosition = function(selfOrFrame, maybeFrame)
    local frame = (selfOrFrame == Canvas and maybeFrame) or maybeFrame or selfOrFrame
    if InCombatLockdown() or not frame or type(frame) ~= "table" or not frame.GetName then return end
    if not Offhand.db or not Offhand.db.enabled then return end
    local name = frame:GetName()
    if not name then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end
    if IsRetailChatEditModeActive(frame) then return end

    local m = Offhand.Viewport and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not m then return end
    if not m.isSpanned then
        Canvas:PlaceForSingleScreenRecovery(frame, m)
        return
    end

    local wPos = Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    if type(wPos) == "table" and wPos.x and wPos.y then
        if Offhand.db.independentWorkspacePanels or frame == WorldMapFrame then
            DemodalizePanel(frame)
            EvictWorkspacePanelSlot(frame)
        end
        if frame == WorldMapFrame then
            Canvas:ConfigureWorldMap()
            EvictWorkspacePanelSlot(frame)
        end
        if string.match(name, "^ChatFrame") and wPos.width and wPos.height and frame.SetSize then
            pcall(function() frame:SetSize(wPos.width, wPos.height) end)
        end

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local frameWidth = (frame:GetWidth() or 0) * (frame.GetScale and frame:GetScale() or 1)
        local frameHeight = (frame:GetHeight() or 0) * (frame.GetScale and frame:GetScale() or 1)
        if frameWidth <= 0 then frameWidth = 192 end
        if frameHeight <= 0 then frameHeight = 192 end

        -- Sanitize/clamp in case DB had bad coordinates (like y = -4.2 or x = 493.6)
        local inset = string.match(name, "^ChatFrame") and 48 or 12
        local minX = m.workspaceLeft + inset
        local maxX = math.max(minX, m.workspaceRight - frameWidth - 12)
        local targetX = wPos.x
        local savedCanvasWidth = tonumber(wPos.canvasWidth)
        local savedCanvasLeft = tonumber(wPos.canvasLeft) or 0
        if savedCanvasWidth and savedCanvasWidth > 0 and m.workspaceWidth > 0 then
            targetX = m.workspaceLeft + (targetX - savedCanvasLeft) * m.workspaceWidth / savedCanvasWidth
        end
        local clampedX = math.max(minX, math.min(targetX, maxX))

        local screenHeight = m.workspaceHeight or m.screenHeight or (UIParent.GetHeight and UIParent:GetHeight()) or 1080
        local minY = m.workspaceBottom + frameHeight + 12
        local maxY = math.max(minY, m.workspaceTop - 12)
        local savedCanvasHeight = tonumber(wPos.canvasHeight)
        local savedCanvasBottom = tonumber(wPos.canvasBottom) or 0
        local targetY = wPos.y
        if savedCanvasHeight and savedCanvasHeight > 0 and screenHeight > 0 then
            targetY = m.workspaceBottom + (targetY - savedCanvasBottom) * screenHeight / savedCanvasHeight
        end
        local clampedY = math.max(minY, math.min(targetY, maxY))

        local factor = parentScale / frameScale
        if frame.SetClampedToScreen then
            pcall(function() frame:SetClampedToScreen(false) end)
        end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", clampedX * factor, clampedY * factor)
        if string.match(name, "^ChatFrame") and ChatFrame1EditBox
            and ShouldManageBlizzardChatEditBox(frame) then
            if ChatFrame1EditBox.ClearAllPoints and ChatFrame1EditBox.SetPoint then
                ChatFrame1EditBox:ClearAllPoints()
                ChatFrame1EditBox:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, 0)
                ChatFrame1EditBox:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            end
            
            if Offhand.HUD and Offhand.HUD.RepairChatButtons then
                Offhand.HUD:RepairChatButtons(frame)
            end
        end
        if Offhand.db.persistentWorkspacePanels ~= false then
            UnregisterSpecialFrame(name)
        end
        return
    end

    local mPos = Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]
    if type(mPos) == "table" and mPos.x and mPos.y then
        if frame == WorldMapFrame then Canvas:ConfigureWorldMap() end
        RemodalizePanel(frame)
        Canvas:PlacePanelOnMainhand(frame, m, mPos, false)
        return
    end

    -- If frame is WorldMapFrame and on the main gaming screen:
    if frame == WorldMapFrame then
        Canvas:ConfigureWorldMap()
          RemodalizePanel(frame)
          RegisterSpecialFrame("WorldMapFrame")

        local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
        local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
        local factor = parentScale / frameScale

        local width = frame:GetWidth() / factor
        local height = frame:GetHeight() / factor
        local minX, maxX = m.gameLeft+12, math.max(m.gameLeft+12, m.gameRight-width-12)
        local minY, maxY = m.gameBottom+height+12, m.gameTop-12
        local x = math.max(minX, math.min((mPos and mPos.x) or minX, maxX))
        local y = math.min(maxY, math.max(minY, (mPos and mPos.y) or maxY))
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x*factor, y*factor)
    end
end

function Canvas:CaptureRetailEditModeChatPlacement()
    local frame = _G.ChatFrame1
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
        or not IsRetailEditModePrimaryChat(frame) then return end

    Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
    Offhand.db.savedMainPositions = Offhand.db.savedMainPositions or {}
    if IsFrameOnWorkspace(frame) then
        OnPanelDragStop(frame)
    else
        Offhand.db.savedWorkspacePositions.ChatFrame1 = nil
        Offhand.db.savedMainPositions.ChatFrame1 = nil
        self:SetWorkspacePanelOpen("ChatFrame1", false)
        if Offhand.ForeverPersistence then Offhand.ForeverPersistence:ClearPosition("ChatFrame1") end
    end
end

function Canvas:RepairShownWorkspacePanels(exceptFrame)
    if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled
        or not Offhand.db.savedWorkspacePositions then return end
    for name in pairs(Offhand.db.savedWorkspacePositions) do
        local frame = _G[name]
        if frame and frame ~= exceptFrame and frame.IsShown and frame:IsShown()
            and not IsForeverEditModeFrame(frame, name) and not IsUnsafeForPanelMutation(frame, name) then
            RestoreWorkspacePosition(frame)
        end
    end
end

-- ============================================================================
-- Universal Panel Dragger (Allows moving panels to the secondary monitor)
-- ============================================================================
nonMovableSystemPanels = {
    GameMenuFrame = true,
    SettingsPanel = true,
    InterfaceOptionsFrame = true,
    VideoOptionsFrame = true,
    AudioOptionsFrame = true,
}

-- A normal Blizzard panel can be reachable by its left edge while its close
-- button and most of its title bar sit in the mixed-height monitor void. Keep
-- the complete window inside whichever visible monitor currently contains the
-- greatest portion of it. Saved user placements are restored separately and
-- therefore always take precedence over this default-position rescue.
function Canvas:RescuePanelFromVoid(frame, metrics)
    if not frame or (InCombatLockdown and InCombatLockdown()) or not Offhand.db
        or not Offhand.db.enabled then return false end
    local name = frame.GetName and frame:GetName()
    if not name or nonMovableSystemPanels[name] or IsForeverEditModeFrame(frame, name)
        or IsUnsafeForPanelMutation(frame, name) then return false end
    if not UIPanelWindows or not UIPanelWindows[name] then return false end
    if frame.IsShown and not frame:IsShown() then return false end

    metrics = metrics or (Offhand.Viewport and Offhand.Viewport.GetMetrics
        and WithWorkspace(Offhand.Viewport:GetMetrics()))
    if not metrics or not metrics.isSpanned or metrics.workspaceLeft == nil then return false end

    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or parentScale
    if parentScale <= 0 or frameScale <= 0 then return false end
    local scaleFactor = frameScale / parentScale
    local left = frame.GetLeft and frame:GetLeft()
    local top = frame.GetTop and frame:GetTop()
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    if not left or not top or not width or not height or width <= 0 or height <= 0 then return false end

    left, top = left * scaleFactor, top * scaleFactor
    width, height = width * scaleFactor, height * scaleFactor
    local right, bottom = left + width, top - height
    local inset = 12
    local areas = {
        {
            left = metrics.workspaceLeft, right = metrics.workspaceRight,
            bottom = metrics.workspaceBottom, top = metrics.workspaceTop,
        },
        {
            left = metrics.gameLeft, right = metrics.gameRight,
            bottom = metrics.gameBottom, top = metrics.gameTop,
        },
    }

    local function IsContained(area)
        return left >= area.left + inset and right <= area.right - inset
            and bottom >= area.bottom + inset and top <= area.top - inset
    end
    if IsContained(areas[1]) or IsContained(areas[2]) then return false end

    local function Overlap(area)
        local overlapWidth = math.max(0, math.min(right, area.right) - math.max(left, area.left))
        local overlapHeight = math.max(0, math.min(top, area.top) - math.max(bottom, area.bottom))
        return overlapWidth * overlapHeight
    end
    local target = Overlap(areas[1]) >= Overlap(areas[2]) and areas[1] or areas[2]
    local availableWidth = math.max(0, target.right - target.left - inset * 2)
    local availableHeight = math.max(0, target.top - target.bottom - inset * 2)
    local targetLeft = width <= availableWidth
        and math.max(target.left + inset, math.min(left, target.right - width - inset))
        or target.left + inset
    local targetTop = height <= availableHeight
        and math.max(target.bottom + height + inset, math.min(top, target.top - inset))
        or target.top - inset
    local pointFactor = parentScale / frameScale
    local ok = pcall(function()
        if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
            targetLeft * pointFactor, targetTop * pointFactor)
    end)
    return ok
end

local function RestoreSavedPositionAfterShow(frame)
    if not frame or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics and Offhand.Viewport:GetMetrics()
    if metrics and not metrics.isSpanned then
        Canvas:PlaceForSingleScreenRecovery(frame, metrics)
        if C_Timer and C_Timer.After then
            frame._OffhandRecoveryGeneration = (frame._OffhandRecoveryGeneration or 0) + 1
            local generation = frame._OffhandRecoveryGeneration
            C_Timer.After(0, function()
                if frame._OffhandRecoveryGeneration ~= generation then return end
                if frame.IsShown and not frame:IsShown() then return end
                Canvas:PlaceForSingleScreenRecovery(frame)
            end)
        end
        return
    end
    local name = frame.GetName and frame:GetName()
    local workspacePosition = name and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name]
    local mainPosition = name and Offhand.db.savedMainPositions and Offhand.db.savedMainPositions[name]
    if not workspacePosition and not mainPosition then
        local isNativePanel = name and UIPanelWindows and UIPanelWindows[name]
            and not nonMovableSystemPanels[name]
        if isNativePanel then
            Canvas:PlacePanelOnMainhand(frame, metrics, nil, true)
        else
            Canvas:RescuePanelFromVoid(frame, metrics)
        end
        if C_Timer and C_Timer.After then
            frame._OffhandRescueGeneration = (frame._OffhandRescueGeneration or 0) + 1
            local generation = frame._OffhandRescueGeneration
            C_Timer.After(0, function()
                if frame._OffhandRescueGeneration ~= generation then return end
                if frame.IsShown and not frame:IsShown() then return end
                if isNativePanel then
                    Canvas:PlacePanelOnMainhand(frame, nil, nil, true)
                else
                    Canvas:RescuePanelFromVoid(frame)
                end
            end)
        end
        return
    end

    -- Apply once after Blizzard's show/layout stack has finished. UIPanel and
    -- container managers can set their native anchor after OnShow, which made
    -- the final position depend on panel opening order after a cold launch.
    RestoreWorkspacePosition(frame)
    if C_Timer and C_Timer.After then
        frame._OffhandRestoreGeneration = (frame._OffhandRestoreGeneration or 0) + 1
        local generation = frame._OffhandRestoreGeneration
        C_Timer.After(0, function()
            if frame._OffhandRestoreGeneration ~= generation then return end
            if frame.IsShown and not frame:IsShown() then return end
            RestoreWorkspacePosition(frame)
        end)
    end
end

local function HookContainerTitlePersistence(frame, name)
    if not frame or not name or not string.match(name, "^ContainerFrame") then return end
    local titleContainer = frame.TitleContainer
    if not titleContainer or not titleContainer.HookScript or titleContainer._OffhandPersistenceHooked then return end

    titleContainer._OffhandPersistenceHooked = true
    titleContainer:HookScript("OnDragStart", function()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
        frame._OffhandDragging = true
    end)
    titleContainer:HookScript("OnDragStop", function()
        if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then
            frame._OffhandDragging = false
            return
        end
        OnPanelDragStop(frame)
    end)
end

local function HookCombinedBagCloseButton(frame, name)
    if not frame or name ~= "ContainerFrameCombinedBags" then return end
    local closeButton = frame.CloseButton or _G[name .. "CloseButton"]
    if not closeButton or not closeButton.HookScript or closeButton._OffhandExplicitCloseHooked then return end

    closeButton._OffhandExplicitCloseHooked = true
    closeButton:HookScript("PreClick", function()
        explicitCombinedBagClose = true
        Canvas:SetWorkspacePanelOpen(frame, false)
        -- Do not leave the bypass armed if Blizzard aborts the click before
        -- PostClick. The native close runs synchronously between these scripts.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                explicitCombinedBagClose = false
            end)
        end
    end)
    closeButton:HookScript("PostClick", function()
        explicitCombinedBagClose = false
    end)
end

local function HookPanelCloseButton(frame, name)
    if not frame or not name or name == "ContainerFrameCombinedBags" then return end
    local closeButton = frame.CloseButton or _G[name .. "CloseButton"]
    if not closeButton or not closeButton.HookScript or closeButton._OffhandOpenStateHooked then return end
    closeButton._OffhandOpenStateHooked = true
    closeButton:HookScript("PreClick", function()
        Canvas:SetWorkspacePanelOpen(frame, false)
    end)
end

local function MakePanelDraggable(frame)
    if not frame or frame._OffhandMovable then return end
    local name = frame.GetName and frame:GetName()
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end

    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end

    if name and string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end

    local movableOK = pcall(function()
        frame:SetMovable(true)
        frame:SetClampedToScreen(false)
    end)
    if not movableOK or (frame.IsMovable and not frame:IsMovable()) then return end

    local function HookPanelDragSurface(surface)
        if not surface or surface._OffhandPanelDragTarget == frame
            or (surface.IsForbidden and surface:IsForbidden()) then return false end

        local hooked = pcall(function()
            surface:EnableMouse(true)
            surface:RegisterForDrag("LeftButton")
            surface:HookScript("OnDragStart", function()
                if InCombatLockdown() or not Offhand.db.enabled then return end
                local started = pcall(function() frame:StartMoving() end)
                frame._OffhandDragging = started and true or false
            end)
            surface:HookScript("OnDragStop", function()
                OnPanelDragStop(frame)
            end)
        end)
        if not hooked then return false end
        surface._OffhandPanelDragTarget = frame
        return true
    end

    -- Modern Blizzard panel templates place TitleContainer at frame level 510.
    -- Use that native title region directly: a child overlay at the parent's
    -- ordinary frame level sits underneath it and never receives drag input.
    -- Fall back to an elevated overlay only for older panels without a title
    -- container.
    -- MinimapCluster uses MinimapZoneTextButton as its natural drag handle and must not have an overlaid handle
    -- Unit frames (PartyMemberFrame, CompactPartyFrame) and FocusedRosterFrame must NOT have an overlaid handle
    -- to prevent blocking unit targeting, healing, right-click context menus, and roster row selection
    local isUnitFrame = name and (string.match(name, "^PartyMemberFrame") or string.match(name, "^CompactPartyFrame") or name == "PlayerFrame" or name == "TargetFrame")
    if frame ~= MinimapCluster and not isUnitFrame  then
        local titleContainer = frame.TitleContainer or (name and _G[name .. "TitleContainer"])
        if titleContainer and HookPanelDragSurface(titleContainer) then
            frame._OffhandHandle = titleContainer
        elseif not frame._OffhandHandle and CreateFrame then
            local handle
            handle = CreateFrame("Frame", nil, frame)
            handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
            handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, 0)
            handle:SetHeight(32)
            local lvl = (frame.GetFrameLevel and frame:GetFrameLevel()) or 1
            if handle.SetFrameLevel then handle:SetFrameLevel(math.max(lvl + 25, 520)) end
            HookPanelDragSurface(handle)
            frame._OffhandHandle = handle
        end
    end

    local frameIsProtected = frame.IsProtected and frame:IsProtected()
    if not frameIsProtected then
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")

        frame:HookScript("OnDragStart", function(self)
            if InCombatLockdown() or not Offhand.db.enabled then return end
            frame._OffhandDragging = true
            frame:StartMoving()
        end)

        frame:HookScript("OnDragStop", function(self)
            OnPanelDragStop(frame)
        end)
    end

    -- Modern/Forever combined bags are dragged by their native TitleContainer,
    -- which may not exist yet when the parent frame is first discovered.
    HookContainerTitlePersistence(frame, name)
    HookCombinedBagCloseButton(frame, name)
    HookPanelCloseButton(frame, name)

    pcall(function()
        frame:HookScript("OnShow", function(self)
            HookContainerTitlePersistence(frame, name)
            HookCombinedBagCloseButton(frame, name)
            HookPanelCloseButton(frame, name)
            RestoreSavedPositionAfterShow(frame)
            if Offhand.db and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name] then
                Canvas:SetWorkspacePanelOpen(frame, true)
            end
        end)
    end)

    if frame == MinimapCluster then
        local function HookMinimapDragHandle(handleFrame)
            if handleFrame and not handleFrame._OffhandHooked then
                handleFrame._OffhandHooked = true
                handleFrame:EnableMouse(true)
                handleFrame:RegisterForDrag("LeftButton")
                handleFrame:HookScript("OnDragStart", function(self)
                    if InCombatLockdown() or not Offhand.db.enabled then return end
                    frame:SetMovable(true)
                    frame._OffhandDragging = true
                    frame:StartMoving()
                end)
                handleFrame:HookScript("OnDragStop", function(self)
                    OnPanelDragStop(frame)
                end)
            end
        end

        HookMinimapDragHandle(MinimapZoneTextButton)
        HookMinimapDragHandle(_G["MinimapBorderTop"])
        HookMinimapDragHandle(MinimapCluster)
    end

    if frame == WorldMapFrame then
        if WorldMapTitleButton and not WorldMapTitleButton._OffhandHooked then
            WorldMapTitleButton._OffhandHooked = true
            WorldMapTitleButton:RegisterForDrag("LeftButton")
            WorldMapTitleButton:HookScript("OnDragStart", function(self)
                if InCombatLockdown() or not Offhand.db.enabled then return end
                frame._OffhandDragging = true
            end)
            WorldMapTitleButton:HookScript("OnDragStop", function(self)
                OnPanelDragStop(frame)
            end)
        end
        if WorldMapTitleButton_OnDragStop and not Canvas._titleButtonHooked then
            Canvas._titleButtonHooked = true
            hooksecurefunc("WorldMapTitleButton_OnDragStop", function()
                OnPanelDragStop(frame)
            end)
        end
    end

    frame._OffhandMovable = true
end

Canvas.RestoreWorkspacePosition = RestoreWorkspacePosition
Canvas.MakePanelDraggable = MakePanelDraggable
Canvas.HookCombinedBagCloseButton = HookCombinedBagCloseButton
Canvas.IsFrameOnWorkspace = IsFrameOnWorkspace
Canvas.OnPanelDragStop = OnPanelDragStop

local foreverSystemPanelNames = {
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "AudioOptionsFrame",
}

-- System settings must always open on Mainhand.  Generic void rescue is a
-- fallback and can miss a panel whose geometry is not final on its first show.
function Canvas:PlaceSystemPanelOnMainhand(frame)
    if not Offhand.isForever or not frame or IsUnsafeForDirectMutation(frame)
        or (InCombatLockdown and InCombatLockdown()) then return false end
    local metrics = Offhand.Viewport and Offhand.Viewport.GetMetrics
        and WithWorkspace(Offhand.Viewport:GetMetrics())
    if not metrics or not metrics.isSpanned then return false end

    local frameScale = (frame.GetEffectiveScale and frame:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if frameScale <= 0 or parentScale <= 0 then return false end
    local factor = frameScale / parentScale
    local x = ((metrics.gameLeft + metrics.gameRight) / 2 - UIParent:GetWidth() / 2) / factor
    local y = ((metrics.gameBottom + metrics.gameTop) / 2 - UIParent:GetHeight() / 2) / factor
    local ok = pcall(function()
        if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
    end)
    return ok
end

-- Opening Blizzard Settings closes native bags as part of its panel cleanup.
-- A workspace backpack marked open is independent workspace content, so reopen
-- only that tracked bag after Settings finishes its transition.
function Canvas:RestoreTrackedWorkspaceBag()
    if not Offhand.isForever or (InCombatLockdown and InCombatLockdown())
        or not Offhand.db or not Offhand.db.enabled
        or Offhand.db.persistentWorkspacePanels == false then return false end
    local bag = _G.ContainerFrameCombinedBags
    local name = bag and bag.GetName and bag:GetName()
    local saved = name and Offhand.db.savedWorkspacePositions
        and Offhand.db.savedWorkspacePositions[name]
    local trackedOpen = name and Offhand.db.openWorkspacePanels
        and Offhand.db.openWorkspacePanels[name]
    if not bag or not saved or not trackedOpen then return false end

    Canvas._restoringWorkspaceBagFromEscape = true
    if not (bag.IsShown and bag:IsShown()) then
        if OpenAllBags then
            pcall(OpenAllBags)
        elseif ToggleAllBags then
            pcall(ToggleAllBags)
        end
        -- CloseSpecialWindows can hide the combined parent without changing
        -- Blizzard's logical bag-open state.  OpenAllBags then returns early,
        -- so reveal that already-open parent directly as the final fallback.
        if not (bag.IsShown and bag:IsShown()) and bag.Show then
            pcall(bag.Show, bag)
        end
    end
    local restored = bag.IsShown and bag:IsShown()
    if restored then
        RestoreSavedPositionAfterShow(bag)
        Canvas:SetWorkspacePanelOpen(name, true)
    end
    Canvas._restoringWorkspaceBagFromEscape = false
    return restored and true or false
end

-- Settings can run its native bag cleanup after the panel's OnShow callbacks.
-- Keep this short-lived marker separate from normal bag persistence so B and
-- the backpack close button remain explicit closers once the transition ends.
function Canvas:RestoreWorkspaceBagClosedDuringSystemPanelOpen()
    if not Canvas._systemPanelOpeningToken or not C_Timer or not C_Timer.After then
        return false
    end
    C_Timer.After(0, function() Canvas:RestoreTrackedWorkspaceBag() end)
    C_Timer.After(0.10, function() Canvas:RestoreTrackedWorkspaceBag() end)
    return true
end

function Canvas:HookMainhandSystemPanels()
    if not Offhand.isForever then return end
    for _, name in ipairs(foreverSystemPanelNames) do
        local panel = _G[name]
        if panel and panel.HookScript and not panel._OffhandMainhandHooked then
            panel._OffhandMainhandHooked = true
            panel:HookScript("OnShow", function(self)
                local openingToken = {}
                Canvas._systemPanelOpeningToken = openingToken
                local function SettleSystemPanel()
                    if self.IsShown and not self:IsShown() then return end
                    Canvas:PlaceSystemPanelOnMainhand(self)
                    Canvas:RestoreTrackedWorkspaceBag()
                end
                SettleSystemPanel()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, SettleSystemPanel)
                    C_Timer.After(0.50, function()
                        if Canvas._systemPanelOpeningToken == openingToken then
                            Canvas._systemPanelOpeningToken = nil
                        end
                    end)
                end
            end)
        end
        if panel and panel.IsShown and panel:IsShown() then
            Canvas:PlaceSystemPanelOnMainhand(panel)
        end
    end
end

function Canvas:TryMakeFrameDraggable(frame)
    if not frame or frame._OffhandMovable or not frame.GetName then return end
    local name = frame:GetName()
    if not name then return end
    if nonMovableSystemPanels[name] then return end
    if IsForeverEditModeFrame(frame, name) or IsUnsafeForPanelMutation(frame, name) then return end
    if name == "MinimapCluster" and Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon() then
        return
    end
    if string.match(name, "^ContainerFrame") and Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon() then
        return
    end
    local isPanel = UIPanelWindows and UIPanelWindows[name]
    if isPanel or frame.TitleContainer or frame.TitleText or _G[name .. "TitleText"] then
        MakePanelDraggable(frame)
        if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
            DemodalizePanel(frame)
        end
    end
end

-- Load-on-demand Blizzard features register their panels independently and do
-- not share a stable exhaustive name list across clients. Discover the native
-- UIPanel registry after each addon load instead of requiring one Offhand entry
-- for every spell book, profession, collection, guild or future panel.
function Canvas:DiscoverUIPanels()
    if not UIPanelWindows or not Offhand.db or not Offhand.db.enabled then return end
    for name in pairs(UIPanelWindows) do
        local frame = _G[name]
        if frame then
            self:TryMakeFrameDraggable(frame)
            if frame.IsShown and frame:IsShown() then
                RestoreSavedPositionAfterShow(frame)
            end
        end
    end
end

function Canvas:EnableFreeDragging()
    if not Offhand.db or not Offhand.db.enabled then return end
    if InCombatLockdown() then
        if not self.dragSetupPending then
            self.dragSetupPending = true
            Offhand:RunOrQueueCombat(function()
                Canvas.dragSetupPending = false
                Canvas:EnableFreeDragging()
            end)
        end
        return
    end

    self:HookMainhandSystemPanels()

    -- RegisterUIPanel is the common path used by load-on-demand Blizzard
    -- features (including PlayerSpellsFrame). Hook the registration itself so
    -- a panel cannot be missed because its addon initialized after Offhand's
    -- ADDON_LOADED callback. Never show the frame from the registration turn:
    -- the same K/micro-button action may still be inside Blizzard's native
    -- loader. The settlement queue preserves reload persistence without that
    -- re-entrant panel open.
    if hooksecurefunc and RegisterUIPanel and not self.registerUIPanelHooked then
        self.registerUIPanelHooked = true
        hooksecurefunc("RegisterUIPanel", function(frame)
            local function AttachRegisteredPanel()
                Canvas:TryMakeFrameDraggable(frame)
                local name = frame and frame.GetName and frame:GetName()
                local shouldRestore = name and Offhand.db and Offhand.db.openWorkspacePanels
                    and Offhand.db.openWorkspacePanels[name]
                    and Offhand.db.savedWorkspacePositions
                    and Offhand.db.savedWorkspacePositions[name]
                if shouldRestore and frame.IsShown and not frame:IsShown() then
                    Canvas:QueuePersistentPanelRestore(frame, name)
                end
                if frame and frame.IsShown and frame:IsShown() then
                    RestoreSavedPositionAfterShow(frame)
                end
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0, AttachRegisteredPanel)
            else
                AttachRegisteredPanel()
            end
        end)
    end

    local hasCustomBags = Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()
    local hasCustomMinimap = Offhand.HasCustomMinimapAddon and Offhand.HasCustomMinimapAddon()

    if hooksecurefunc and not Canvas._explicitPanelToggleHooks then
        Canvas._explicitPanelToggleHooks = true
        local function SyncExplicitToggle(frame)
            if not frame or not C_Timer or not C_Timer.After then return end
            C_Timer.After(0, function()
                local name = frame.GetName and frame:GetName()
                if not name or not Offhand.db or not Offhand.db.savedWorkspacePositions
                    or not Offhand.db.savedWorkspacePositions[name] then return end
                local shown = frame.IsShown and frame:IsShown()
                Canvas:SetWorkspacePanelOpen(name, shown)
                if shown then RestoreSavedPositionAfterShow(frame) end
            end)
        end
        local function SyncNativeBags()
            SyncExplicitToggle(_G.ContainerFrameCombinedBags)
            for i = 1, (NUM_CONTAINER_FRAMES or 13) do
                SyncExplicitToggle(_G["ContainerFrame" .. i])
            end
        end
        if ToggleAllBags then hooksecurefunc("ToggleAllBags", SyncNativeBags) end
        if ToggleBag then hooksecurefunc("ToggleBag", SyncNativeBags) end
        if ToggleWorldMap then
            hooksecurefunc("ToggleWorldMap", function() SyncExplicitToggle(_G.WorldMapFrame) end)
        end
        if ToggleCharacter then
            hooksecurefunc("ToggleCharacter", function() SyncExplicitToggle(_G.CharacterFrame) end)
        end
    end

    -- Forever's Escape path calls CloseAllBags followed by ToggleGameMenu
    -- directly; it does not pass through CloseAllWindows. Pair those native
    -- calls within one event turn so B and the backpack X remain explicit
    -- closers while Escape restores a workspace backpack after opening or
    -- closing the Game Menu. Each hook has a retryable late-load guard.
    if hooksecurefunc and CloseAllBags and not Canvas._closeAllBagsEscapeHooked then
        Canvas._closeAllBagsEscapeHooked = true
        hooksecurefunc("CloseAllBags", function()
            if Canvas._restoringWorkspaceBagFromEscape or not C_Timer or not C_Timer.After
                or InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
            local bag = _G.ContainerFrameCombinedBags
            local name = bag and bag.GetName and bag:GetName()
            local saved = name and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name]
            local wasTrackedOpen = name and Offhand.db.openWorkspacePanels
                and Offhand.db.openWorkspacePanels[name]
            if not bag or not saved or not wasTrackedOpen
                or (bag.IsShown and bag:IsShown()) then return end

            -- Forever Settings may close bags after its OnShow handler. Restore
            -- from this post-hook while the bounded opening marker is active.
            if Canvas:RestoreWorkspaceBagClosedDuringSystemPanelOpen() then
                Canvas._workspaceBagAwaitingGameMenuToggle = nil
                return
            end

            local token = {}
            Canvas._workspaceBagAwaitingGameMenuToggle = {
                bag = bag, name = name, token = token,
                menuWasShown = GameMenuFrame and GameMenuFrame.IsShown
                    and GameMenuFrame:IsShown() or false,
            }
            C_Timer.After(0, function()
                local pending = Canvas._workspaceBagAwaitingGameMenuToggle
                if pending and pending.token == token then
                    Canvas._workspaceBagAwaitingGameMenuToggle = nil
                end
            end)
        end)
    end

    if hooksecurefunc and ToggleGameMenu and not Canvas._toggleGameMenuEscapeHooked then
        Canvas._toggleGameMenuEscapeHooked = true
        hooksecurefunc("ToggleGameMenu", function()
            local pending = Canvas._workspaceBagAwaitingGameMenuToggle
            if not pending or not C_Timer or not C_Timer.After then return end
            Canvas._workspaceBagAwaitingGameMenuToggle = nil
            C_Timer.After(0, function()
                local bag, name = pending.bag, pending.name
                local menuShouldBeShown = not pending.menuWasShown
                Canvas._restoringWorkspaceBagFromEscape = true
                if ToggleAllBags then
                    pcall(ToggleAllBags)
                elseif OpenAllBags then
                    pcall(OpenAllBags)
                elseif bag and bag.Show then
                    pcall(function() bag:Show() end)
                end
                if bag and bag.IsShown and bag:IsShown() then
                    RestoreSavedPositionAfterShow(bag)
                    Canvas:SetWorkspacePanelOpen(name, true)
                end
                -- ToggleGameMenu's post-hook runs before Forever finishes the
                -- menu transition, so derive the desired result from the stable
                -- state captured before Escape closed the bags.
                local menuIsShown = GameMenuFrame and GameMenuFrame.IsShown
                    and GameMenuFrame:IsShown() or false
                if menuShouldBeShown ~= menuIsShown then
                    -- A second ToggleGameMenu closes the backpack again on
                    -- Forever. Direct Show/Hide was verified to preserve the
                    -- bag while keeping the Escape-derived end state.
                    if menuShouldBeShown and GameMenuFrame and GameMenuFrame.Show then
                        pcall(function() GameMenuFrame:Show() end)
                    elseif GameMenuFrame and GameMenuFrame.Hide then
                        pcall(function() GameMenuFrame:Hide() end)
                    end
                end
                C_Timer.After(0, function()
                    Canvas._restoringWorkspaceBagFromEscape = false
                end)
            end)
        end)
    end

    -- List of standard frames that players love dragging to their secondary workspace
    local frameNames = {
        "WorldMapFrame",
        "CharacterFrame",
        "QuestLogFrame",
        "SpellBookFrame",
        "TalentFrame",
        "PlayerTalentFrame",
        "FriendsFrame",
        "TradeFrame",
        "MerchantFrame",
        "MailFrame",
        "OpenMailFrame",
        "BankFrame",
        "PVEFrame",
        "InspectFrame",
        "MacroFrame",
        "ClassTrainerFrame",
        "TradeSkillFrame",
        "CraftFrame",
    }
    
    -- In Classic Era (no Edit Mode), we allow dragging unit frames.
    -- In modern WoW, Edit Mode natively handles moving these frames to the offhand monitor.
    if not Offhand.isForever and not EditModeManagerFrame then
        table.insert(frameNames, "PartyMemberFrame1")
        table.insert(frameNames, "CompactPartyFrame")
        table.insert(frameNames, "CompactRaidFrameContainer")
    end

    if not Offhand.isForever and not hasCustomMinimap then
        table.insert(frameNames, "MinimapCluster")
    end

    if not hasCustomBags then
        for i = 1, 13 do
            table.insert(frameNames, "ContainerFrame" .. i)
        end
        table.insert(frameNames, "ContainerFrameCombinedBags")
    end

    for _, name in ipairs(frameNames) do
        local frame = _G[name]
        if frame and not IsUnsafeForPanelMutation(frame, name) and not IsForeverEditModeFrame(frame, name) then
            MakePanelDraggable(frame)
            if Offhand.db and Offhand.db.independentWorkspacePanels and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions[name] then
                DemodalizePanel(frame)
            end
        end
    end

    self:DiscoverUIPanels()

    if not hasCustomBags and ContainerFrame_GenerateFrame and not Canvas._bagGenHooked then
        Canvas._bagGenHooked = true
        hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
            if frame and not IsUnsafeForDirectMutation(frame)
                and not (Offhand.HasCustomBagAddon and Offhand.HasCustomBagAddon()) then
                MakePanelDraggable(frame)
            end
        end)
    end

    if not Offhand.isForever and not hasCustomMinimap and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["MinimapCluster"] and MinimapCluster then
        RestoreWorkspacePosition(MinimapCluster)
    end
    if not Offhand.isForever and Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["PartyMemberFrame1"] and _G.PartyMemberFrame1 then
        RestoreWorkspacePosition(_G.PartyMemberFrame1)
    end
    

    -- Hook Chat Frames and Tabs for workspace dragging and persistence
    local function RegisterChatFrame(chatFrame)
        if not chatFrame or chatFrame._OffhandChatHooked then return end
        chatFrame._OffhandChatHooked = true
        if chatFrame.SetClampedToScreen then
            pcall(function() chatFrame:SetClampedToScreen(false) end)
        end

        if chatFrame.HookScript then
            chatFrame:HookScript("OnDragStart", function(self) self._OffhandDragging = true end)
            chatFrame:HookScript("OnDragStop", function(self)
                self._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                OnPanelDragStop(self)
            end)
        end

        local chatName = chatFrame.GetName and chatFrame:GetName()
        local chatTab = chatName and _G[chatName .. "Tab"]
        if chatTab and not chatTab._OffhandTabHooked and chatTab.HookScript then
            chatTab._OffhandTabHooked = true

            -- Observe Blizzard's native chat-tab drag without changing its lock,
            -- docking, drag registration or movable state. Forcing StartMoving on
            -- Forever's locked static ChatFrame1 raises "Frame is not movable".
            chatTab:HookScript("OnDragStart", function()
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                chatFrame._OffhandDragging = true
            end)

            chatTab:HookScript("OnDragStop", function(self)
                chatFrame._OffhandDragging = false
                if InCombatLockdown() or not Offhand.db or not Offhand.db.enabled then return end
                -- Docked tabs belong to GeneralDockManager (or its scroll child),
                -- not the message frame. Persist the associated chat window.
                OnPanelDragStop(chatFrame)
            end)
        end
    end

    if FCF_StopDragging and not Canvas._fcfHooked then
        Canvas._fcfHooked = true
        hooksecurefunc("FCF_StopDragging", function(chatFrame)
            if chatFrame and Offhand.db and Offhand.db.enabled then
                if chatFrame.SetClampedToScreen then
                    pcall(function() chatFrame:SetClampedToScreen(false) end)
                end
                OnPanelDragStop(chatFrame)
                if FCF_SavePositionAndDimensions then
                    pcall(function() FCF_SavePositionAndDimensions(chatFrame) end)
                end
            end
        end)
    end

    if EditModeManagerFrame and EditModeManagerFrame.HookScript
        and not EditModeManagerFrame._OffhandRetailChatExitHooked then
        EditModeManagerFrame._OffhandRetailChatExitHooked = true
        EditModeManagerFrame:HookScript("OnHide", function()
            local capture = function() Canvas:CaptureRetailEditModeChatPlacement() end
            if C_Timer and C_Timer.After then C_Timer.After(0, capture) else capture() end
        end)
    end

    if FCF_SavePositionAndDimensions and not Canvas._fcfSaveHooked then
        Canvas._fcfSaveHooked = true
        hooksecurefunc("FCF_SavePositionAndDimensions", function(chatFrame)
            local name = chatFrame and chatFrame.GetName and chatFrame:GetName()
            if name and Offhand.db and Offhand.db.enabled
                and Offhand.db.savedWorkspacePositions
                and Offhand.db.savedWorkspacePositions[name] then
                Canvas:CaptureForeverFramePosition(chatFrame)
            end
        end)
    end

    if FCF_OpenNewWindow and not Canvas._fcfNewHooked then
        Canvas._fcfNewHooked = true
        hooksecurefunc("FCF_OpenNewWindow", function(...)
            for i = 1, (NUM_CHAT_WINDOWS or 10) do
                local cf = _G["ChatFrame" .. i]
                if cf then RegisterChatFrame(cf) end
            end
        end)
    end

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf then
            RegisterChatFrame(cf)
            if Offhand.db.savedWorkspacePositions and Offhand.db.savedWorkspacePositions["ChatFrame" .. i] then
                RestoreWorkspacePosition(cf)
            end
        end
    end

    self:ConfigureWorldMap()
    self:UpdatePersistenceBehavior()
end

function Offhand:InitializeCanvas()
    Canvas:CreateFrames()

    -- Re-check draggable frames when Blizzard on-demand addons load
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function()
        Canvas:EnableFreeDragging()
        Canvas:UpdateMapMovementBehavior()
        Canvas:UpdatePersistenceBehavior()
        Canvas:ConfigureWorldMap()
        -- Other ADDON_LOADED handlers may create/register their panel later in
        -- the same event dispatch. Rescan once that initialization settles.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                Canvas:EnableFreeDragging()
                Canvas:RestorePersistentFrames()
            end)
        end
    end)
    Canvas:UpdateMapMovementBehavior()
    Canvas:UpdatePersistenceBehavior()
    Canvas:ConfigureWorldMap()

    if Offhand.isForever and C_Timer and C_Timer.NewTicker and not Canvas.foreverPositionTicker then
        Canvas.foreverPositionTicker = C_Timer.NewTicker(0.5, function()
            if Offhand._displayGeometryTransitionActive then return end
            local editModeShown = EditModeManagerFrame and EditModeManagerFrame.IsShown
                and EditModeManagerFrame:IsShown()
            if editModeShown then
                Canvas._foreverEditModeWasShown = true
            elseif Canvas._foreverEditModeWasShown then
                Canvas._foreverEditModeWasShown = false
                -- Blizzard can display the saved chat width in Edit Mode while
                -- applying a stale runtime width. Trust Offhand's last explicit
                -- FCF save and restore it after protected Edit Mode closes.
                Canvas:RepairShownWorkspacePanels()
                return
            else
                return
            end
            Canvas:CaptureForeverFramePosition(_G.ContainerFrameCombinedBags)
        end)
    end

        if not Offhand.isForever and not Canvas.showUIPanelHooked and ShowUIPanel then
        Canvas.showUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(frame)
            if IsForeverEditModeFrame(frame) or IsUnsafeForDirectMutation(frame) then return end
            if frame and UIPanelWindows and UIPanelWindows[frame:GetName()] and not UIPanelWindows[frame:GetName()].area then
                if not frame:IsShown() then frame:Show() end
            end
            Canvas:TryMakeFrameDraggable(frame)
            RestoreSavedPositionAfterShow(frame)
        end)
    end
    if not Offhand.isForever and not Canvas.hideUIPanelHooked and HideUIPanel then
        Canvas.hideUIPanelHooked = true
        hooksecurefunc("HideUIPanel", function(frame)
            if IsForeverEditModeFrame(frame) or IsUnsafeForDirectMutation(frame) then return end
            if frame and UIPanelWindows and UIPanelWindows[frame:GetName()] and not UIPanelWindows[frame:GetName()].area then
                if frame:IsShown() then frame:Hide() end
            end
        end)
    end

end

function Offhand:UpdateCanvas()
    Canvas:UpdateLayout()
end




