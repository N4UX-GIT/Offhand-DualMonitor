import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

old_guard = '''            -- Guard: Companion App check
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

new_guard = '''            -- Guard: Companion App check
            if Offhand.db and Offhand.db.enabled and not Offhand.db.suppressCompanionWarning then
                local w = GetScreenWidth() * UIParent:GetEffectiveScale()
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

