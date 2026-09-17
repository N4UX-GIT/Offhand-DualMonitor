import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = r'\|cffd0d0d0Offhand is enabled, but your window is not spanned!\|r'
new_text = '|cffd0d0d0Offhand is enabled, but your window is not optimally spanned to your physical monitor setup and resolution.|r'

code = re.sub(pattern, new_text, code)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

