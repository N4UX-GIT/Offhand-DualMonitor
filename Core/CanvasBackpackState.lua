--[[
    Offhand: Multi-Monitor Workspace Addon
    Core/CanvasBackpackState.lua: Native backpack root and profile state policy
--]]

local _, Offhand = ...

local BackpackState = {}
Offhand.CanvasBackpackState = BackpackState

BackpackState.RootNames = {
    "ContainerFrame1",
    "ContainerFrameCombinedBags",
}

function BackpackState.IsForeverContainerName(name)
    return Offhand.isForever and type(name) == "string"
        and name:match("^ContainerFrame") ~= nil
end

function BackpackState.IsRoot(name)
    return name == "ContainerFrame1" or name == "ContainerFrameCombinedBags"
end

function BackpackState.IsRestorableRootName(name)
    if type(name) ~= "string" then return false end
    return name:match("^ContainerFrame%d+$") ~= nil
        or name == "ContainerFrameCombinedBags"
        or name == "EUI_MainBagFrame"
        or name:match("^Baganator_SingleViewBackpackViewFrame") ~= nil
        or name:match("^Baganator_CategoryViewBackpackViewFrame") ~= nil
        or name:match("^Baginator") ~= nil
        or name:match("^BGR") ~= nil
        or name:match("^Bagnon") ~= nil
        or name:match("^AdiBags") ~= nil
        or name:match("^BetterBags") ~= nil
        or name:match("^ArkInventory") ~= nil
        or name == "CustomBagRestorer"
end

function BackpackState.ClearOtherRoots(db, keepName)
    if type(db) ~= "table" then return false end
    local changedOpenState = false
    for _, rootName in ipairs(BackpackState.RootNames) do
        if rootName ~= keepName then
            if type(db.savedWorkspacePositions) == "table" then
                db.savedWorkspacePositions[rootName] = nil
            end
            if type(db.savedMainPositions) == "table" then
                db.savedMainPositions[rootName] = nil
            end
            if type(db.openWorkspacePanels) == "table" and db.openWorkspacePanels[rootName] then
                db.openWorkspacePanels[rootName] = nil
                changedOpenState = true
            end
        end
    end
    return changedOpenState
end

function BackpackState.GetWorkspacePosition(db)
    if type(db) ~= "table" then return nil end
    local position = db.nativeBackpackWorkspacePosition
    if type(position) == "table" and position.x and position.y then
        return position
    end
    local saved = db.savedWorkspacePositions
    if type(saved) ~= "table" then return nil end
    for _, rootName in ipairs(BackpackState.RootNames) do
        position = saved[rootName]
        if type(position) == "table" and position.x and position.y then
            db.nativeBackpackWorkspacePosition = position
            return position
        end
    end
    return nil
end

function BackpackState.IsTrackedOpen(db)
    if type(db) ~= "table" then return false end
    if db.nativeBackpackWorkspaceOpen == true then return true end
    local openPanels = db.openWorkspacePanels
    if type(openPanels) ~= "table" then return false end
    for _, rootName in ipairs(BackpackState.RootNames) do
        if openPanels[rootName] then
            db.nativeBackpackWorkspaceOpen = true
            return true
        end
    end
    return false
end

function BackpackState.ClearOpenState(db)
    if type(db) ~= "table" then return false end
    local changed = db.nativeBackpackWorkspaceOpen ~= nil
    db.nativeBackpackWorkspaceOpen = nil
    db.openWorkspacePanels = db.openWorkspacePanels or {}
    for _, rootName in ipairs(BackpackState.RootNames) do
        if db.openWorkspacePanels[rootName] ~= nil then changed = true end
        db.openWorkspacePanels[rootName] = nil
    end
    return changed
end

function BackpackState.GetShownRoot()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.IsShown and combined:IsShown() then return combined end
    local individual = _G.ContainerFrame1
    if individual and individual.IsShown and individual:IsShown() then return individual end
    return nil
end

function BackpackState.GetPreferredRoot(db)
    local saved = type(db) == "table" and db.savedWorkspacePositions or nil
    if saved and saved.ContainerFrameCombinedBags then return _G.ContainerFrameCombinedBags end
    if saved and saved.ContainerFrame1 then return _G.ContainerFrame1 end
    local prefersCombined = GetCVarBool and GetCVarBool("combinedBags")
    return prefersCombined and _G.ContainerFrameCombinedBags or _G.ContainerFrame1
end

