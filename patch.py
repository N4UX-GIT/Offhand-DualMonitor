import re

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Fix card1_1 layout
code = code.replace('local card1_1 = CreateCard(tab1, "Display Mode & Dual Monitor Orientation", 0, 104)', 'local card1_1 = CreateCard(tab1, "Display Mode & Dual Monitor Orientation", 0, 130)')
code = code.replace('minimapCheck:SetPoint("TOPLEFT", 240, -26)', 'minimapCheck:SetPoint("TOPLEFT", 12, -96)')
code = code.replace('laserCheck:SetPoint("TOPLEFT", 420, -26)', 'laserCheck:SetPoint("TOPLEFT", 240, -96)')

code = code.replace('local card1_2 = CreateCard(tab1, "3D Game Viewport Geometry & Bezel Seam", -124, 108)', 'local card1_2 = CreateCard(tab1, "3D Game Viewport Geometry & Bezel Seam", -150, 108)')
code = code.replace('local card1_3 = CreateCard(tab1, "Screen Bottom Offset & Global UI Scale", -252, 120)', 'local card1_3 = CreateCard(tab1, "Screen Bottom Offset & Global UI Scale", -278, 120)')
code = code.replace('local card1_4 = CreateCard(tab1, "OBS Streamer Capture Setup", -386, 110)', 'local card1_4 = CreateCard(tab1, "OBS Streamer Capture Setup", -418, 110)')

# 2. Fix card2_2 layout (Gather Off-Screen UI button)
code = code.replace('local card2_2 = CreateCard(tab2, "Workspace Window Management & Persistence", -164, 260)', 'local card2_2 = CreateCard(tab2, "Workspace Window Management & Persistence", -164, 296)')
code = code.replace('gatherBtn:SetPoint("TOPRIGHT", -16, -26)', 'gatherBtn:SetPoint("TOPLEFT", 10, -256)')

code = code.replace('local card2_3 = CreateCard(tab2, "Bezel Compensation & Window Spanning", -436, 104)', 'local card2_3 = CreateCard(tab2, "Bezel Compensation & Window Spanning", -476, 104)')

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'w', encoding='utf-8') as f:
    f.write(code)

