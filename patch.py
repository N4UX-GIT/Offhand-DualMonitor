import re

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'r', encoding='utf-8') as f:
    code = f.read()

new_card_code = '''    local card1_5 = CreateCard(tab1, "Companion App Download (Recommended)", 86)
    
    local compDesc = card1_5:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    compDesc:SetPoint("TOPLEFT", 16, -26)
    compDesc:SetPoint("TOPRIGHT", -16, -26)
    compDesc:SetJustifyH("LEFT")
    compDesc:SetText("Required to automate a pixel-perfect, borderless span across multiple monitors.")
    
    local compEdit = CreateFrame("EditBox", nil, card1_5, "InputBoxTemplate")
    compEdit:SetSize(350, 20)
    compEdit:SetPoint("TOPLEFT", 22, -52)
    compEdit:SetAutoFocus(false)
    compEdit:SetText("https://github.com/N4UX/Offhand/releases")
    compEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    compEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    compEdit:SetScript("OnTextChanged", function(self, userChanged) if userChanged then self:SetText("https://github.com/N4UX/Offhand/releases") self:HighlightText() end end)
'''

# Insert after card1_4 definition
code = code.replace('    Options:StackCards(tab1, {card1_1, card1_2, card1_3, card2_3, card1_4})', 
                    new_card_code + '\n    Options:StackCards(tab1, {card1_1, card1_5, card1_2, card1_3, card2_3, card1_4})')

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'w', encoding='utf-8') as f:
    f.write(code)

