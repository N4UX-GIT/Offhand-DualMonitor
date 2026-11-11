local addon = { modules = {} }
assert(loadfile("Core/PopupBounds.lua"))("Offhand", addon)
local combat = false
InCombatLockdown = function() return combat end
local function frame(shown, level, alpha)
    return {
        IsShown = function() return shown end,
        GetFrameStrata = function() return "TOOLTIP" end,
        GetFrameLevel = function() return level end,
        GetEffectiveAlpha = function() return alpha end,
        Show = function() error("diagnostics showed a frame") end,
        SetAlpha = function() error("diagnostics changed alpha") end,
        SetFrameLevel = function() error("diagnostics changed layering") end,
    }
end
GameTooltip = frame(true, 10, 1)
GameTooltip.NineSlice = frame(false, 0, 0)
GameTooltip.NineSlice.GetCenterColor = function() return 0, 0, 0, 0 end
ItemRefTooltip = frame(true, 20, 1)
ItemRefTooltip.IsEmbedded = true
ItemRefTooltip.NineSlice = frame(false, 20, 1)
ShoppingTooltip1 = { IsForbidden = function() return true end,
    IsShown = function() error("forbidden tooltip inspected") end }
ShoppingTooltip2 = nil
UIParent={GetEffectiveScale=function()return 0.7 end,GetName=function()return 'UIParent' end}
SettingsTooltip=frame(true,30,1)
SettingsTooltip.GetParent=function()return UIParent end
SettingsTooltip.GetScale=function()return 1 end
SettingsTooltip.GetEffectiveScale=function()return 0.7 end
SettingsTooltip.IsIgnoringParentScale=function()return false end
SettingsTooltip.GetRegions=function()return {GetFont=function()return 'font-file',14,'OUTLINE' end,
    GetText=function()error('Tooltip text must not be read')end} end
local report = table.concat(addon.PopupBounds:GetTooltipPresentationDiagnostics(), "\n")
assert(report:find("GameTooltip=shown,alpha=1.00,strata=TOOLTIP,level=10", 1, true))
assert(report:find("backdrop=hidden,alpha=0.00,strata=TOOLTIP,level=0,scale=unknown,rect=unresolved;centerAlpha=0.00", 1, true))
assert(report:find("embedded=yes;backdrop=hidden", 1, true), "embedded backgrounds must remain untouched")
assert(report:find("ShoppingTooltip1=forbidden", 1, true))
assert(report:find("ShoppingTooltip2=absent", 1, true))
assert(report:find('SettingsTooltip=shown',1,true))
assert(report:find('localScale=1.000;parent=UIParent;parentScale=0.700;uiScale=0.700;ignoreParentScale=false;fontHeight=14.000',1,true))
SettingsTooltip.GetParent=function()return {IsForbidden=function()return true end,
    GetName=function()error('Forbidden parent inspected')end}end
assert(table.concat(addon.PopupBounds:GetTooltipPresentationDiagnostics()):find('parent=unknown;parentScale=unknown',1,true))
GameTooltip.GetFrameLevel = function() error("uninspectable frame") end
assert(table.concat(addon.PopupBounds:GetTooltipPresentationDiagnostics()):find("GameTooltip=unavailable", 1, true))
combat = true
GameTooltip.IsShown = function() error("combat tooltip inspected") end
assert(table.concat(addon.PopupBounds:GetTooltipPresentationDiagnostics()) == "deferred:combat")
combat = false
GameTooltip.IsShown = function() return true end
GameTooltip.GetFrameLevel = function() return 10 end
local scripts, timers, printed = {}, {}, {}
GameTooltip.HookScript = function(_, event, callback) scripts[event] = callback end
C_Timer = { After = function(delay, callback) timers[#timers + 1] = {delay, callback} end }
addon.Print = function(_, format, report) printed[#printed + 1] = string.format(format, report) end
addon.PopupBounds:ObserveTooltip(GameTooltip)
scripts.OnShow(GameTooltip)
assert(#timers == 0 and #printed == 0, "ordinary tooltip hover must not collect or print diagnostics")
assert(addon.PopupBounds:ArmTooltipPresentationCapture())
scripts.OnShow(GameTooltip)
assert(#printed == 0 and #timers == 2 and timers[2][1] == 0,
    "hover capture must wait for the native show turn to settle")
timers[2][2]()
assert(#printed == 5 and printed[1]:find("Hovered tooltip presentation: GameTooltip=shown", 1, true))
scripts.OnShow(GameTooltip)
assert(#timers == 2 and #printed == 5, "one-shot capture must not log every future hover")
assert(addon.PopupBounds:ArmTooltipPresentationCapture())
timers[3][2]() -- expire the new 30-second capture
scripts.OnShow(GameTooltip)
assert(#timers == 3 and #printed == 5, "expired captures must leave ordinary hover untouched")
combat = true
assert(not addon.PopupBounds:ArmTooltipPresentationCapture(), "capture must not arm during combat")
combat=false
local settingsScripts={}
SettingsTooltip.HookScript=function(_,event,callback)
    local previous=settingsScripts[event]
    settingsScripts[event]=function(...)if previous then previous(...)end;callback(...)end
end
addon.PopupBounds:ObserveTooltip(SettingsTooltip)
assert(addon.PopupBounds:ArmTooltipPresentationCapture())
settingsScripts.OnShow(SettingsTooltip)
timers[#timers][2]()
assert(#printed==10,'Settings hover did not participate in opt-in capture')
print("PASS: tooltip backdrop evidence is read-only, opt-in, guarded and deferred in combat")
