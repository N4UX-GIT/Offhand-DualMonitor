local addon = { HUDCompatibility = {} }
local hud = {}
assert(loadfile("Core/HUDRecovery.lua"))("Offhand", addon)
addon.HUDRecovery.Install(hud)
local combat = false
InCombatLockdown = function() return combat end
UIParent = { GetEffectiveScale = function() return 0.5 end }
local metrics = {
    gameLeft = 1000, gameBottom = 0, gameRight = 2000, gameTop = 800,
    workspaceLeft = 0, workspaceBottom = 0, workspaceRight = 1000, workspaceTop = 1200,
}
local function root(left, bottom, width, height)
    return {
        IsShown = function() return true end,
        IsVisible = function() return true end,
        GetEffectiveAlpha = function() return 1 end,
        GetEffectiveScale = function() return 1 end,
        GetLeft = function() return left end,
        GetBottom = function() return bottom end,
        GetWidth = function() return width end,
        GetHeight = function() return height end,
        Show = function() error("diagnostics changed visibility") end,
        Hide = function() error("diagnostics changed visibility") end,
        SetPoint = function() error("diagnostics changed geometry") end,
    }
end
ProfessionsFrame = root(550, 450, 100, 100) -- scaled into the physical void above Mainhand
LFGListApplicationDialog = root(850, 150, 150, 150)
LFGListInviteDialog = root(850, 320, 150, 150)
ExtraActionBarFrame = root(600, 40, 100, 100)
ExtraActionButton1 = root(600, 40, 100, 100)
ExtraActionButton1.IsVisible = function() return false end
OverrideActionBar = root(0, 0, 1, 1)
OverrideActionBar.IsShown = function() return false end
ObjectiveTrackerFrame = root(450, 100, 100, 100) -- overlaps both visible displays
ZoneAbilityFrame = { IsForbidden = function() return true end,
    IsShown = function() error("forbidden frame inspected") end }
WatchFrame = root(nil, nil, 1, 1)
local report = table.concat(hud:GetInteractionVisibilityDiagnostics(metrics), "\n")
assert(report:find("ProfessionsFrame=shown,alpha=1.00,rect=1100/900/200/200,overlap=outside", 1, true))
assert(report:find("ProfessionsBookFrame=absent", 1, true))
assert(report:find("ExtraActionBarFrame=shown,alpha=1.00,rect=1200/80/200/200,overlap=mainhand", 1, true))
assert(report:find("ExtraActionButton1=shown,parent-hidden", 1, true))
assert(report:find("OverrideActionBar=hidden", 1, true))
assert(report:find("ObjectiveTrackerFrame=shown,alpha=1.00,rect=900/200/200/200,overlap=both", 1, true))
assert(report:find("ZoneAbilityFrame=forbidden", 1, true))
assert(report:find("WatchFrame=shown,alpha=1.00,bounds=unresolved", 1, true))
assert(not report:find("RetailExtra", 1, true), "Retail probes ran on another client")
addon.isRetail = true
local groupReport = table.concat(hud:GetInteractionVisibilityDiagnostics(metrics), "\n")
assert(groupReport:find("LFGListApplicationDialog=shown",1,true)
    and groupReport:find("LFGListInviteDialog=shown",1,true),
    "full diagnostics must include the reported Premade Groups dialogs")
Enum = { EditModeSystem = { ExtraAbilities = 7 } }
local available = true
C_ActionBar = { HasExtraActionBar = function() return available end }
ExtraAbilityContainer = root(600, 40, 100, 100)
ExtraAbilityContainer.IsShown = function() return false end
ExtraAbilityContainer.GetName = function() return "ExtraAbilityContainer" end
ExtraAbilityContainer.GetParent = function() return UIParent end
UIParent.GetName = function() return "UIParent" end
ExtraAbilityContainer.GetNumPoints = function() return 1 end
ExtraAbilityContainer.GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end
ExtraActionBarFrame.GetParent = function() return ExtraAbilityContainer end
ExtraActionButton1.icon = { GetEffectiveAlpha = function() return 0 end }
EditModeManagerFrame = { GetActiveLayoutInfo = function() return {
    systems = { { system = 7, isInDefaultPosition = false, anchorInfo = {
        point = "CENTER", relativeTo = "OtherSystem", relativePoint = "TOP", offsetX = 5, offsetY = 20,
    } } },
} end }
report = table.concat(hud:GetInteractionVisibilityDiagnostics(metrics), "\n")
assert(report:find("RetailExtraAction=available", 1, true))
assert(report:find("ExtraAbilityContainer=hidden", 1, true))
assert(report:find("ExtraAbilityContainer.ownership=parent:UIParent,points:1,anchor:CENTER/UIParent/CENTER/0.0/0.0", 1, true))
assert(report:find("ExtraActionBarFrame.ownership=parent:ExtraAbilityContainer", 1, true))
assert(report:find("iconAlpha:0.00", 1, true))
assert(report:find("RetailExtraAbilitiesLayout=default:false,anchor:CENTER/OtherSystem/TOP/5/20", 1, true))
C_ActionBar.HasVehicleActionBar = function() return false end
C_ActionBar.HasOverrideActionBar = function() return true end
OverrideActionBar.GetNumPoints = function() return 1 end
OverrideActionBar.GetPoint = function() return "BOTTOM", UIParent, "BOTTOM", 0, 0 end
OverrideActionBar.GetParent = function() return UIParent end
OverrideActionBar.IsProtected = function() return true end
report = table.concat(hud:GetInteractionVisibilityDiagnostics(metrics), "\n")
assert(report:find("RetailVehicleAction=inactive",1,true)
    and report:find("RetailOverrideAction=available",1,true)
    and report:find("RetailTemporaryAction=unsupported",1,true))
assert(report:find("OverrideActionBar=hidden",1,true)
    and report:find("OverrideActionBar.ownership=parent:UIParent,points:1,anchor:BOTTOM/UIParent/BOTTOM/0.0/0.0,protected:true,managed:false",1,true),
    "inactive protected controls must expose read-only native anchor evidence without force-showing")
C_ActionBar.HasOverrideActionBar = function() error('unavailable native capability') end
assert(table.concat(hud:GetInteractionVisibilityDiagnostics(metrics)):find("RetailOverrideAction=unavailable",1,true))
available = false
assert(table.concat(hud:GetInteractionVisibilityDiagnostics(metrics)):find("RetailExtraAction=inactive", 1, true))
C_ActionBar.HasExtraActionBar = function() error("API unavailable") end
ExtraAbilityContainer.IsForbidden = function() return true end
ExtraAbilityContainer.GetParent = function() error("forbidden parent inspected") end
report = table.concat(hud:GetInteractionVisibilityDiagnostics(metrics), "\n")
assert(report:find("RetailExtraAction=unavailable", 1, true))
assert(report:find("ExtraAbilityContainer.ownership=forbidden", 1, true))
Enum.EditModeSystem = {}
assert(table.concat(hud:GetInteractionVisibilityDiagnostics(metrics)):find("RetailExtraAbilitiesLayout=unavailable", 1, true))
combat = true
C_ActionBar.HasExtraActionBar = function() error("combat native action inspected") end
ExtraActionBarFrame.IsShown = function() error("combat frame inspected") end
assert(table.concat(hud:GetInteractionVisibilityDiagnostics(metrics)) == "deferred:combat")
print("PASS: missing interaction-frame diagnostics distinguish absent, hidden and off-screen without mutations")
