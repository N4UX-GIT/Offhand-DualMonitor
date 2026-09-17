import re

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'r', encoding='utf-8') as f:
    code = f.read()

target = '''    autoWizardBtn:SetScript("OnClick", function()
        if Offhand.Wizard and Offhand.Wizard.Open then
            Offhand.Wizard.openedFromOptions = true
            configFrame:Hide()
            Offhand.Wizard:Open()
        end
    end)'''

button_code = '''
    local compAppBtn = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
    compAppBtn:SetSize(155, 22)
    compAppBtn:SetPoint("RIGHT", autoWizardBtn, "LEFT", -10, 0)
    compAppBtn:SetText("Get Companion App")
    compAppBtn:SetScript("OnClick", function()
        StaticPopup_Show("OFFHAND_DOWNLOAD_LINK")
    end)
'''

code = code.replace(target, target + '\n' + button_code)

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'w', encoding='utf-8') as f:
    f.write(code)

