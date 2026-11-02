-- Characterize existing adapters for the proposed 640-pixel workspace.
-- This does not enable partial planning or certify readability/protected UI.
local addon = { isRetail = true }
assert(loadfile("Core/CanvasPersistence.lua"))("Offhand", addon)
local persistence = addon.CanvasPersistence
local combat = false
InCombatLockdown = function() return combat end
local cases = 0
for _, canvasRatio in ipairs({1, 0.5}) do
    for _, side in ipairs({0, 3440}) do
        for _, ancestorRatio in ipairs({1, 1.25}) do
            local parentScale = 0.8
            UIParent = { GetEffectiveScale = function() return parentScale end }
            local metrics = { isSpanned = true,
                workspaceLeft = side * canvasRatio, workspaceBottom = 0,
                workspaceRight = (side + 640) * canvasRatio,
                workspaceTop = 1440 * canvasRatio }
            local frame = { scale = 1, width = 1060, height = 700, writes = 0 }
            function frame:GetScale() return self.scale end
            function frame:SetScale(value) self.scale = value; self.writes = self.writes + 1 end
            function frame:GetEffectiveScale() return self.scale * ancestorRatio * parentScale end
            function frame:GetWidth() return self.width end
            function frame:GetHeight() return self.height end
            PlayerSpellsFrame = frame
            for _, width in ipairs({1060, 2120}) do
                frame.width = width -- representative spellbook and talent fixture sizes
                persistence.FitPlayerSpellsToWorkspace(frame, metrics, true)
                local effectiveWidth = width * frame:GetEffectiveScale() / parentScale
                local effectiveHeight = frame.height * frame:GetEffectiveScale() / parentScale
                assert(effectiveWidth <= 640 * canvasRatio - 24 + 0.000001)
                assert(effectiveHeight <= 1440 * canvasRatio - 24 + 0.000001)
                assert(frame.scale > 0 and frame.scale < 1)
                cases = cases + 1
            end
            persistence.FitPlayerSpellsToWorkspace(frame, metrics, false)
            assert(frame.scale == 1, "leaving workspace restores original adapter-owned scale")
            combat = true
            local writes = frame.writes
            persistence.FitPlayerSpellsToWorkspace(frame, metrics, true)
            assert(frame.writes == writes, "narrow fit must defer scale writes in combat")
            combat = false
            persistence.FitPlayerSpellsToWorkspace(frame, metrics, true)
            frame:SetScale(0.75)
            persistence.FitPlayerSpellsToWorkspace(frame, metrics, false)
            assert(frame.scale == 0.75, "release must preserve a later external scale owner")
        end
    end
end
print("PASS: " .. cases .. " narrow PlayerSpells fits with scale ownership and combat deferral")

-- Existing generic persistence clamps position without resizing the frame.
-- An oversized frame cannot be made contained by this helper alone.
local metrics = { workspaceLeft = 0, workspaceRight = 640,
    workspaceBottom = 0, workspaceTop = 1440 }
local x, y = persistence.ClampWorkspacePoint(metrics, 100, 1000, 900, 1600, false)
assert(x == 12 and x + 900 > metrics.workspaceRight)
assert(y - 1600 >= metrics.workspaceBottom and y > metrics.workspaceTop)
print("CHARACTERIZED GAP: generic position clamp does not contain oversized panels")
