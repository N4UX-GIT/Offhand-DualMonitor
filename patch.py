import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = r'StaticPopupDialogs\["OFFHAND_COMPANION_WARNING"\] = \{.*?\}'
new_table = '''StaticPopupDialogs["OFFHAND_COMPANION_WARNING"] = {
    text = [[|cffd0d0d0Offhand is enabled, but your window is not spanned!|r

For a seamless, borderless experience, the Offhand Companion App is highly recommended. Download it securely from GitHub below:

(Alternatively, put WoW in Windowed mode and manually drag the edges across your monitors to dismiss this warning).]],
    button1 = "OK",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        self.editBox:SetText("https://github.com/N4UX/Offhand/releases")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}'''

code = re.sub(pattern, new_table, code, flags=re.DOTALL)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)
