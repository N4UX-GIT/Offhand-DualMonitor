StaticPopupDialogs = {}
-- Test the actual shared settings/wizard control without a live game.
local frames = {}
function CreateFrame(kind)
    local f = {kind=kind, scripts={}}
    function f:SetSize(w,h) self.width,self.height=w,h end
    function f:SetWidth(w) self.width=w end
    function f:SetHeight(h) self.height=h end
    function f:GetHeight() return self.height end
    function f:SetWordWrap(wrap) self.wrap=wrap end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:SetPoint(...) self.point={...} end
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
local addon={db={gameBottomPixels=6}, applied=0,
    L={LABEL_BOTTOM_OFFSET_SHORT='Game bottom offset (pixels):',BTN_APPLY_SHORT='Apply'}}
function addon:ApplyFullLayout() self.applied=self.applied+1 end
assert(loadfile("UI/Controls.lua"))("Offhand",addon)
assert(loadfile("Core/TopologyDetection.lua"))("Offhand",addon)
assert(loadfile("UI/OptionsActions.lua"))("Offhand",addon)
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
local function tick(elapsed)
    for _,frame in ipairs(frames) do
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,elapsed) end
    end
end
tick(0.3)
local appliedBeforeBurst=addon.applied
local allocatedFrames=#frames
for _=1,1000 do
    buttons['+1 px'].scripts.OnClick()
    buttons['-1 px'].scripts.OnClick()
end
assert(addon.applied==appliedBeforeBurst and input.text=='6'
    and #frames==allocatedFrames,'bottom burst must update text without extra frames or layout')
tick(0.24)
assert(addon.applied==appliedBeforeBurst)
buttons['+1 px'].scripts.OnClick()
assert(input.text=='7' and addon.db.gameBottomPixels==7)
tick(0.24)
assert(addon.applied==appliedBeforeBurst,'bottom adjustment must restart the quiet period')
tick(0.02)
assert(addon.applied==appliedBeforeBurst+1)
tick(1)
assert(addon.applied==appliedBeforeBurst+1,'bottom controller must stop after applying')
input:SetText('0'); buttons.Apply.scripts.OnClick(); tick(0.3)
local noOpCount=addon.applied
buttons['-1 px'].scripts.OnClick()
buttons.Apply.scripts.OnClick()
tick(1)
assert(addon.applied==noOpCount,'clamped/unchanged bottom value must not request layout')
addon.db.gameBottomPixels=6; row:Refresh()
local before=addon.applied
for _,locale in ipairs({'enUS','deDE','esES','esMX','frFR','itIT','koKR','ptBR','ruRU','zhCN','zhTW'}) do
    GetLocale=function() return locale end
    addon.L={}
    assert(loadfile('Locales/'..locale..'.lua'))('Offhand',addon)
    frames={}
    local localizedRow=addon.Options:CreateBottomControl({})
    local localizedInput,applyButton,label
    for _,frame in ipairs(frames) do
        if frame.kind=='EditBox' then localizedInput=frame end
        if frame.kind=='Button' and frame.text==addon.L.BTN_APPLY_SHORT then applyButton=frame end
        if frame.kind=='FontString' then label=frame end
    end
    assert(applyButton and applyButton.width==94, locale..': Apply must use the dictionary and reserved width')
    assert(label.width==280 and label.wrap, locale..': label must wrap within its column')
    assert(localizedRow:GetHeight() >= -localizedInput.point[3] + applyButton:GetHeight(),
        locale..': row must contain wrapped label and actions')
    assert(addon.db.gameBottomPixels==6 and addon.applied==before, 'localization layout changed calibration')
end
-- A long measured label must push actions down instead of overlapping them.
addon.L.LABEL_BOTTOM_OFFSET_SHORT=string.rep('Long label ',20)
frames={}
local expanded=addon.Options:CreateBottomControl({})
assert(expanded:GetHeight()>row:GetHeight(), 'expanded label must grow the row')
print("PASS: bottom control preserves opening value, nudges, bounds and refresh")

