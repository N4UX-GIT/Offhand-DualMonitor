-- Baganator owns its backpack visibility and layout. Track only its root backpack
-- windows, never the BGR item/button pools or bank/settings windows.
local _, Offhand = ...
local Bags = { paused = true, frames = {}, generation = 0 }
Offhand.BagPersistence = Bags

local function Enabled()
    local db = Offhand.db
    return db and db.enabled and db.persistentWorkspacePanels ~= false
        and db.restoreWorkspaceOnReload ~= false
end

function Bags:Discover()
    for name, frame in pairs(_G) do
        if type(name) == "string" and (name:match("^Baganator_SingleViewBackpackViewFrame")
            or name:match("^Baganator_CategoryViewBackpackViewFrame"))
            and type(frame) == "table" and frame.GetName and frame.HookScript
            and not self.frames[name] then
            self.frames[name] = frame
            local function Changed()
                -- Teardown hides windows synchronously; a deferred sample cannot
                -- erase the last visible state while the UI is being destroyed.
                C_Timer.After(0, function() Bags:Capture() end)
            end
            frame:HookScript("OnShow", function() Bags:Capture() end)
            frame:HookScript("OnHide", Changed)
        end
    end
end

function Bags:Capture()
    if self.paused or not Offhand.db then return end
    local snapshot = {}
    if Enabled() then
        for name, frame in pairs(self.frames) do
            if not (frame.IsForbidden and frame:IsForbidden()) and frame:IsVisible()
                and Offhand.Canvas.IsFrameOnWorkspace(frame) then
                local factor = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
                local x, y = frame:GetLeft(), frame:GetBottom()
                if x and y then snapshot[name] = { x = x * factor, y = y * factor } end
            end
        end
    end
    Offhand.db.baganatorWorkspacePanels = snapshot
end

function Bags:Resume()
    self.generation = self.generation + 1
    local generation = self.generation
    self.paused = true
    local attempts, toggled = 0, false
    local function Restore()
        if generation ~= Bags.generation then return end
        if not Enabled() then Bags.paused = false; Bags:Capture(); return end
        if InCombatLockdown() then
            Bags.waitingForCombat = true
            return
        end
        Bags.waitingForCombat = false
        Bags:Discover()
        local saved = Offhand.db.baganatorWorkspacePanels or {}
        local _, position = next(saved)
        if position and type(position) == "table" and position.x and position.y then
            local visible
            for _, frame in pairs(Bags.frames) do
                if frame:IsVisible() then visible = frame; break end
            end
            if not visible and next(Bags.frames) and ToggleAllBags and not toggled then
                toggled = true
                ToggleAllBags()
                for _, frame in pairs(Bags.frames) do
                    if frame:IsVisible() then visible = frame; break end
                end
            end
            if visible then
                Offhand.db.savedWorkspacePositions = Offhand.db.savedWorkspacePositions or {}
                Offhand.db.savedWorkspacePositions[visible:GetName()] = position
                Offhand.Canvas:RestoreWorkspacePosition(visible)
            else
                attempts = attempts + 1
                if attempts < 20 then C_Timer.After(0.25, Restore); return end
            end
        end
        Bags.paused = false
        Bags:Capture()
    end
    C_Timer.After(0.5, Restore)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "PLAYER_REGEN_ENABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
        Bags.paused = true
        Bags.generation = Bags.generation + 1
    elseif event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_REGEN_ENABLED" and Bags.waitingForCombat) then
        Bags:Resume()
    elseif event == "PLAYER_LOGIN" then
        Bags:Discover()
        if not Bags.ticker then
            local ticks = 0
            Bags.ticker = C_Timer.NewTicker(0.2, function()
                ticks = ticks + 1
                if not Bags.paused then
                    if ticks % 5 == 0 then Bags:Discover() end
                    Bags:Capture()
                end
            end)
        end
    end
end)
