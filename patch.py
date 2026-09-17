import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern_onshow = r'OnShow = function\(self\).*?self\.editBox:SetText\(.*?self\.editBox:HighlightText\(\).*?self\.editBox:SetFocus\(\).*?end,'

new_onshow = '''OnShow = function(self)
        local eb = self.EditBox or _G[self:GetName().."EditBox"]
        if eb then
            eb:SetText("https://github.com/N4UX/Offhand/releases")
            eb:HighlightText()
            eb:SetFocus()
        end
    end,'''

code = re.sub(pattern_onshow, new_onshow, code, flags=re.DOTALL)

pattern_text = r'text = \[\[.*?\]\],'
new_text = '''text = [[|cffd0d0d0Offhand is enabled, but your window is not spanned!|r

For a seamless, borderless experience, the Offhand Companion App is highly recommended. Download it securely from GitHub below:

(Alternatively, if you are attempting to stretch the window manually, ensure you drag it fully across both monitors. Click Ignore to permanently dismiss this warning).]],'''

code = re.sub(pattern_text, new_text, code, flags=re.DOTALL)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

