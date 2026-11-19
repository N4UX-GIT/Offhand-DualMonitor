-- Addon-owned diagrams and workspace cue. Native monitor discovery is separate.
local addon={UIControls={},L={}}
assert(loadfile("UI/SetupVisuals.lua"))("Offhand",addon)
local visuals=addon.SetupVisuals
local cases={
    {isSpanned=true,gameLeft=1440,gameRight=4000,gameBottom=0,gameTop=1440,
        workspaceLeft=0,workspaceRight=1440,workspaceBottom=0,workspaceTop=2560},
    {isSpanned=true,gameLeft=-2560,gameRight=0,gameBottom=-1440,gameTop=0,
        workspaceLeft=-2560,workspaceRight=-640,workspaceBottom=0,workspaceTop=1080},
    {isSpanned=true,gameLeft=0,gameRight=3440,gameBottom=0,gameTop=1440,
        workspaceLeft=760,workspaceRight=2680,workspaceBottom=1440,workspaceTop=2520},
    {isSpanned=true,gameLeft=0,gameRight=1920,gameBottom=1080,gameTop=2160,
        workspaceLeft=400,workspaceRight=1480,workspaceBottom=0,workspaceTop=1080},
}
for _,metrics in ipairs(cases) do
    local p=visuals:Plan(metrics,560,90)
    assert(not p.example)
    for _,r in ipairs({p.game,p.workspace}) do
        assert(r.x>=-.001 and r.y>=-.001 and r.w>0 and r.h>0)
        assert(r.x+r.w<=560.001 and r.y+r.h<=90.001,"diagram exceeded its bounded canvas")
    end
    local expected=(metrics.gameRight-metrics.gameLeft)/(metrics.gameTop-metrics.gameBottom)
    assert(math.abs(p.game.w/p.game.h-expected)<.0001,"diagram distorted monitor proportions")
    assert(math.min(p.game.x+p.game.w,p.workspace.x+p.workspace.w)<=math.max(p.game.x,p.workspace.x)+.001
        or math.min(p.game.y+p.game.h,p.workspace.y+p.workspace.h)<=math.max(p.game.y,p.workspace.y)+.001,
        "diagram filled the physical void or overlapped the displays")
end
for _,m in ipairs({{}, {isSpanned=false}, {isSpanned=true,topologyStatus="MISMATCH"},
    {isSpanned=true,gameLeft=0/0},
    {isSpanned=true,gameLeft=0,gameRight=10,gameBottom=0,gameTop=10,
        workspaceLeft=5,workspaceRight=15,workspaceBottom=0,workspaceTop=10}}) do
    assert(visuals:Plan(m,560,90).example,"unverified geometry claimed configured regions")
end
addon._displayGeometryTransitionActive=true
assert(visuals:Plan(cases[1],560,90).example)
addon._displayGeometryTransitionActive=nil
local secret={}
issecretvalue=function(v) return v==secret end
local m=cases[1];local old=m.gameLeft;m.gameLeft=secret
assert(visuals:Plan(m,560,90).example);m.gameLeft=old
print("PASS: setup diagrams preserve offsets, stacked layouts, aspect, voids and honest fallback labels")

local frames = {}
local function Region()
    return {
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
        SetPoint = function(self, _, _, _, x, y) self.x, self.y = x, y end,
        SetWidth = function() end,
        SetWordWrap = function() end,
        SetJustifyH = function() end,
        SetTextColor = function() end,
        SetText = function(self, text) self.text = text end,
    }
end
addon.UIControls.CreateFrame = function(_, _, parent)
    local frame = Region()
    frame.parent = parent
    frame.SetAllPoints = function() end
    frame.SetFrameStrata = function() end
    frame.SetScript = function(self, event, callback) self[event] = callback end
    frame.EnableMouse = function(self, enabled) self.mouse = enabled end
    frame.SetBackdrop = function() end
    frame.SetBackdropColor = function() end
    frame.SetBackdropBorderColor = function() end
    frame.SetAlpha = function(self, alpha) self.alpha = alpha end
    frame.ClearAllPoints = function() end
    frame.SetSize = function(self, width, height) self.width, self.height = width, height end
    frame.CreateFontString = Region
    frames[#frames + 1] = frame
    return frame
end
addon.UIControls.FitCompactParagraph = function() return 32 end
addon.db = {enabled = true}
addon.L.WORKSPACE_READY_TITLE = "Ready"
addon.L.WORKSPACE_READY_HINT = "Drag here"
UIParent = {}
visuals:ShowWorkspaceReady({isSpanned = true, workspaceRegions = {
    {x = 2560, y = 0, width = 640, height = 1440},
    {x = 0, y = 1440, width = 1280, height = 720},
}})
local cue, right, above = frames[1], frames[2], frames[3]
assert(cue.shown and cue.alpha == 0 and cue.mouse == false)
assert(right.parent == cue and right.shown and right.mouse == false and right.x == 2560 and right.width == 640)
assert(above.parent == cue and above.shown and above.mouse == false and above.y == 1440 and above.height == 720)
assert(above.label.shown and above.label.text == "Ready\nDrag here")
cue:OnUpdate(0.25)
assert(cue.alpha == 1)
cue:OnUpdate(5.25)
assert(cue.alpha == 0.5)
cue:OnUpdate(0.5)
assert(not cue.shown, "the one-time cue must expire without requiring a click")
visuals:ShowWorkspaceReady({isSpanned = true, workspaceLeft = 1920, workspaceBottom = 0,
    workspaceWidth = 1080, workspaceHeight = 1920})
assert(cue.shown and cue.alpha == 0 and right.x == 1920 and not above.shown,
    "the single-workspace cue must reuse its frame and clear unused regions")
addon._displayGeometryTransitionActive = true
cue:OnUpdate(0.1)
assert(not cue.shown, "stale geometry must end the workspace cue")
print("PASS: workspace cue follows configured rectangles, passes clicks through and fades out")
