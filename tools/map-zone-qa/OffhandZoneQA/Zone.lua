-- Optional Forever test driver. Arming is session-only. No native frame hooks.
local frame = CreateFrame("Frame")
local mode, previous
local generation = 0

local function number(value)
    if issecretvalue and issecretvalue(value) then return end
    if type(value) == "number" and value > -math.huge and value < math.huge then return value end
end

local function record(message)
    if type(OffhandZoneQALog) ~= "table" then OffhandZoneQALog = {} end
    table.insert(OffhandZoneQALog, date("%H:%M:%S") .. " " .. message)
    if #OffhandZoneQALog > 100 then table.remove(OffhandZoneQALog, 1) end
    print("Zone QA | " .. message)
end

local function owner()
    local compat = Offhand and Offhand.CanvasCompatibility
    return compat and compat.GetWorldMapExternalOwner() or (OpenMapAPI and "OpenMap" or "Blizzard")
end

local function snapshot(label)
    if InCombatLockdown() then record(label .. " | combat") return end
    local shown = WorldMapFrame and WorldMapFrame:IsVisible()
    local shownID = shown and number(WorldMapFrame:GetMapID())
    local api = OpenMapAPI
    local detail = ""
    if shown and api and api.GetView and api.MapAt then
        local u, v, zoom = api.GetView()
        if number(u) and number(v) and number(zoom) then
            detail = (" | stitched center=%s zoom=%.3f u=%.4f v=%.4f"):format(
                tostring(number(api.MapAt(u, v))), zoom, u, v)
        end
    end
    local bugs = "unavailable"
    if BugSack and BugSack.GetErrors and BugGrabber and BugGrabber.GetSessionId then
        local errors = BugSack:GetErrors(BugGrabber:GetSessionId())
        local occurrences = 0
        for _, entry in ipairs(errors) do occurrences = occurrences + (entry.counter or 1) end
        bugs = ("%d entries/%d occurrences"):format(#errors, occurrences)
    end
    record(("%s | %s player=%s displayed=%s%s | BugSack %s"):format(label, owner(),
        tostring(number(C_Map.GetBestMapForUnit("player"))), shown and tostring(shownID) or "closed", detail, bugs))
end

local function eligibleMap()
    local map, api, oh = WorldMapFrame, OpenMapAPI, Offhand
    if not (oh and oh.isForever and oh.db and oh.db.enabled and oh.db.persistentWorkspacePanels ~= false
        and oh.Canvas and oh.Viewport and owner() == "OpenMap") then return "owner or workspace disabled" end
    if C_AddOns.GetAddOnMetadata("OpenMap", "Version") ~= "v0.8.13" then return "untested OpenMap version" end
    if not (api and api.major == 1 and api.IsStitched and api.GetView and api.MapAt
        and api.WorldFromMap and api.ShowWorld) then return "OpenMap API unavailable" end
    if not map or not map:IsVisible() or map:IsMaximized() or not oh.Canvas.CanManagePanelsFromAddon()
        or IsInInstance() then return "outside windowed outdoor test" end
    local metrics = oh.Viewport:GetMetrics()
    if not metrics or not metrics.isSpanned or not oh.Canvas.IsFrameOnWorkspace(map)
        or not api.IsStitched() then return "outside stitched Offhand map" end
    return nil, api
end

local function playerWorld(api, current)
    local pos = C_Map.GetPlayerMapPosition(current, "player")
    if (issecretvalue and issecretvalue(pos)) or not pos then return end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    if not number(x) or not number(y) then return end
    local u, v = api.WorldFromMap(current, x, y)
    if number(u) and number(v) then return u, v end
end

local function trial(old, current)
    local reason, api = eligibleMap()
    if reason then return reason end
    local u, v = api.GetView()
    if not number(u) or not number(v) or number(api.MapAt(u, v)) ~= old then
        return "view already moved or browsing another zone"
    end
    u, v = playerWorld(api, current)
    if not u then return "stitched player position unavailable" end
    if api.ShowWorld(u, v) then return "requested recenter" end
    return "OpenMap declined recenter"
end

-- OpenMap 0.8.13 glides for 0.4 seconds. Sample after each glide, leaving
-- wheel zoom to settle and never writing the stitched or native zoom ourselves.
local followTimer, lastZoom, moves
local function follow()
    if InCombatLockdown() then return end
    local _, api = eligibleMap()
    if not api then return end
    if WorldMapFrame:IsMouseOver() and IsMouseButtonDown("LeftButton") then
        followTimer:Cancel()
        followTimer = nil
        record("follow paused for browsing | /ohzone follow to resume")
        return
    end
    local cu, cv, zoom = api.GetView()
    if not number(cu) or not number(cv) or not number(zoom) then return end
    local changedZoom = lastZoom and math.abs(zoom-lastZoom) > 0.00001
    lastZoom = zoom
    if changedZoom then return end
    local id = number(C_Map.GetBestMapForUnit("player"))
    if not id then return end
    local u, v = playerWorld(api, id)
    if not u then return end
    -- Do not keep restarting an animation at rest. Normalized distance is
    -- scaled by zoom so the tolerance is comparable at different zoom levels.
    local offset = math.max(math.abs(cu-u), math.abs(cv-v)) * zoom
    if offset > 0.0005 and api.ShowWorld(u, v) then
        moves = moves + 1
        if moves == 1 or moves % 10 == 0 then
            record(("follow sample %d | player=%d zoom=%.3f offset=%.5f"):format(moves,id,zoom,offset))
        end
    end
end

local function stop()
    if followTimer then followTimer:Cancel() end
    followTimer, lastZoom, moves = nil, nil, 0
    generation = generation + 1
    mode, previous = nil, nil
    frame:UnregisterAllEvents()
end

frame:SetScript("OnEvent", function(_, event, addon, operation)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        record(event .. " " .. tostring(addon) .. " " .. tostring(operation))
        return
    end
    generation = generation + 1
    local ticket = generation
    if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_REGEN_DISABLED" then
        previous = nil
        return
    end
    -- Later zone events supersede early or duplicate notifications. Start fresh
    -- after loading or combat, rather than pulling the player back to a stale view.
    local function sample(retry)
        if ticket ~= generation or InCombatLockdown() then return end
        local current = number(C_Map.GetBestMapForUnit("player"))
        if (not current or current == previous) and not retry then
            C_Timer.After(1, function() sample(true) end)
            return
        end
        if not current or current == previous then return end
        local old = previous
        previous = current
        snapshot(event)
        if old and mode == "trial" then record(trial(old, current)) end
        if old and mode == "native" then
            local map, oh = WorldMapFrame, Offhand
            if oh and oh.isForever and oh.db and oh.db.enabled and oh.db.persistentWorkspacePanels ~= false
                and oh.Viewport:GetMetrics().isSpanned and owner() == "Blizzard"
                and not OpenMapAPI and not IsInInstance() and oh.Canvas.CanManagePanelsFromAddon()
                and map and not map:IsForbidden() and map:IsVisible() and not map:IsMaximized()
                and oh.Canvas.IsFrameOnWorkspace(map) and number(map:GetMapID()) == old
                and C_Map.OpenWorldMap then
                mode = "watch"
                record("requesting native WORLD_MAP_OPEN for " .. current)
                C_Map.OpenWorldMap(current)
            end
        end
        C_Timer.After(1.5, function() if ticket == generation then snapshot("settled") end end)
    end
    C_Timer.After(0.5, function() sample(false) end)
end)

SLASH_OFFHANDZONEQA1 = "/ohzone"
SlashCmdList.OFFHANDZONEQA = function(command)
    if command == "status" then snapshot(mode or "idle") return end
    if command == "off" then stop() record("stopped") return end
    if command ~= "watch" and command ~= "trial" and command ~= "follow" and command ~= "native" then
        print("Zone QA | /ohzone watch, trial, follow, native, status, off")
        return
    end
    stop()
    if command == "follow" then
        if InCombatLockdown() then record("arm follow outside combat") return end
        local reason = eligibleMap()
        if reason then record(reason) return end
        followTimer = C_Timer.NewTicker(0.5, follow)
    end
    mode = command
    if not InCombatLockdown() then previous = number(C_Map.GetBestMapForUnit("player")) end
    for _, event in ipairs({"ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN"}) do frame:RegisterEvent(event) end
    snapshot(mode)
end
