StaticPopupDialogs = {}
-- Test the actual shared settings/wizard control without a live game.
local frames = {}
function CreateFrame(kind)
    local f = {kind=kind, scripts={}}
    function f:SetSize() end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint() end
    function f:SetAutoFocus() end
    function f:SetNumeric() end
    function f:SetMaxLetters() end
    function f:SetText(text) self.text=text end
    function f:GetText() return self.text end
    function f:ClearFocus() end
    function f:SetScript(event, callback) self.scripts[event]=callback end
    function f:CreateFontString() return CreateFrame("FontString") end
    frames[#frames+1]=f
    return f
end
GetPhysicalScreenSize=function() return 4000,2560 end
local addon={db={gameBottomPixels=6}, applied=0}
function addon:ApplyFullLayout() self.applied=self.applied+1 end
assert(loadfile("UI/Options.lua"))("Offhand",addon)
local row=addon.Options:CreateBottomControl({})
local input,buttons=nil,{}
for _,f in ipairs(frames) do
    if f.kind=="EditBox" then input=f end
    if f.kind=="Button" then buttons[f.text]=f end
end
assert(input.text=="6" and addon.applied==0, "opening changed saved calibration")
buttons["+1 px"].scripts.OnClick()
assert(addon.db.gameBottomPixels==7)
buttons["-1 px"].scripts.OnClick()
assert(addon.db.gameBottomPixels==6)
input:SetText("99999"); buttons.Apply.scripts.OnClick()
assert(addon.db.gameBottomPixels==2559)
input:SetText("0"); buttons["-1 px"].scripts.OnClick()
assert(addon.db.gameBottomPixels==0)
input:SetText(""); input.scripts.OnEnterPressed(input)
assert(input.text=="0")
addon.db.gameBottomPixels=6; row.scripts.OnShow()
assert(input.text=="6")
print("PASS: bottom control preserves opening value, nudges, bounds and refresh")

