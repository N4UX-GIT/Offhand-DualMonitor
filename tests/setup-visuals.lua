-- Diagram geometry only: never infers native monitor discovery or HUD placement.
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
