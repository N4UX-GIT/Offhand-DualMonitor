import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = r'StaticPopupDialogs\["OFFHAND_COMPANION_WARNING"\] = \{.*?\}'
new_table = '''StaticPopupDialogs["OFFHAND_COMPANION_WARNING"] = {
    text = [[|cffd0d0d0Offhand is enabled, but your window is not spanned!|r

For a seamless, borderless experience, the Offhand Companion App is highly recommended. Download it securely from GitHub below:

(Alternatively, if you are using Eyefinity/Surround or stretching manually, click Ignore).]],
    button1 = "OK",
    button2 = "Ignore",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        self.editBox:SetText("https://github.com/N4UX/Offhand/releases")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    OnAccept = function() end,
    OnCancel = function(self)
        Offhand.db.suppressCompanionWarning = true
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

# Now update the guard logic to check the suppress flag
old_guard = '''            -- Guard: Companion App check
            if Offhand.db and Offhand.db.enabled then
                local w, h = GetScreenWidth(), GetScreenHeight()
                local physW = w
                if GetPhysicalScreenSize then
                    pcall(function() physW = select(1, GetPhysicalScreenSize()) end)
                end
                -- If the game width is less than or equal to a single monitor's physical width, it is not spanned.
                if w and physW and w <= (physW + 50) then
                    StaticPopup_Show("OFFHAND_COMPANION_WARNING")
                end
            end'''

new_guard = '''            -- Guard: Companion App check
            if Offhand.db and Offhand.db.enabled and not Offhand.db.suppressCompanionWarning then
                local w, h = GetScreenWidth(), GetScreenHeight()
                local physW = w
                if GetPhysicalScreenSize then
                    pcall(function() physW = select(1, GetPhysicalScreenSize()) end)
                end
                if w and physW and w <= (physW + 50) then
                    StaticPopup_Show("OFFHAND_COMPANION_WARNING")
                end
            end'''

code = code.replace(old_guard, new_guard)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

