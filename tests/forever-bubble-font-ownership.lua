-- Legacy repair must not become a recurring writer of an externally owned font.
local function scenario(height, external)
 local font={height=height,writes=0}
 ChatBubbleFont={GetFont=function() return "Fonts/FRIZQT__.TTF",font.height,"OUTLINE" end,
  SetFont=function(_,_,value) font.height=value;font.writes=font.writes+1;return true end}
 EllesmereUI=external and {GetActiveProfileData=function() return {chatBubbles={enabled=true}} end} or nil
 local addon={isForever=true,modules={},db={enabled=true,originalChatBubbleFontHeight=13},
  Viewport={GetWorldTextScaleControl=function() return "WorldTextScale_v2" end,
   GetMetrics=function() return {isSpanned=false} end}}
 assert(loadfile("Core/ChatBubbles.lua"))("Offhand",addon)
 local bubbles=addon.modules.ChatBubbles
 return font,bubbles
end
local font,bubbles=scenario(21,false)
bubbles:ApplyLayout();bubbles:ApplyLayout()
assert(font.height==21 and font.writes==0,"custom native font must not be normalized by the legacy repair")
font,bubbles=scenario(3.25,false)
bubbles:ApplyLayout()
assert(font.height==13 and font.writes==1,"recover the legacy undersized startup font once")
font.height=7
bubbles:ApplyLayout();bubbles:ApplyLayout()
assert(font.height==7 and font.writes==1,"a later font owner must retain even a small intentional size")
font,bubbles=scenario(7,true)
bubbles:ApplyLayout()
assert(font.height==7 and font.writes==0,"explicit Ellesmere ownership must win before legacy recovery")
EllesmereUI=nil
bubbles:ApplyLayout()
assert(font.height==7 and font.writes==0,"changing vendor ownership must not replay startup repair")
font,bubbles=scenario(13,false)
bubbles:ApplyLayout();font.height=24;bubbles:ApplyLayout()
assert(font.height==24 and font.writes==0,"a font owner arriving after startup must retain its size")
print("PASS: Forever legacy bubble-font recovery runs once and yields external font ownership")
