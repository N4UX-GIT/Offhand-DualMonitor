-- Action buttons retain readable text and differ from filled step markers.
local addon={db={}}
assert(loadfile("UI/Controls.lua"))("Offhand",addon)
local text={SetTextColor=function(s,...) s.color={...} end,SetPoint=function() end}
local button={enabled=true,GetFontString=function() return text end,
 SetBackdrop=function() end,SetBackdropColor=function(s,...) s.bg={...} end,
 SetBackdropBorderColor=function(s,...) s.border={...} end,
 IsEnabled=function(s) return s.enabled end,
 SetNormalFontObject=function(s,v) s.font=v end,SetHighlightFontObject=function() end,
 SetDisabledFontObject=function() end,
 CreateFontString=function() return {SetPoint=function() end,SetText=function() end,
 SetTextColor=function() end,Show=function() end,Hide=function() end} end}
local c=addon.UIControls
assert(c.SetRecommendedButton(button,true))
local idle=button.bg[1]
assert(idle<.1 and text.color[1]>.9 and button.font=="GameFontHighlight")
button.uiHover=true;c.StyleSurface(button,"button")
assert(button.bg[1]>idle and text.color[1]>.9,"hover must highlight without reducing text contrast")
button.uiHover=nil;c.StyleSurface(button,"button")
assert(button.bg[1]==idle)
button.enabled=0
assert(not c.SetRecommendedButton(button,true),"disabled action cannot become recommended")
assert(text.color[1]<.6)
print("PASS: action contrast, standard font, hover, leave and legacy disabled state")
