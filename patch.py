import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

old_guard = '''            -- Guard: Companion App check
            if Offhand.db and Offhand.db.enabled then
                local w, h = GetScreenWidth(), GetScreenHeight()
                if w and h and (w / h) < 2.1 then
                    StaticPopup_Show("OFFHAND_COMPANION_WARNING")
                end
            end'''

new_guard = '''            -- Guard: Companion App check
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

code = code.replace(old_guard, new_guard)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

