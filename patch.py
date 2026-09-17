import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = r'Please run the Offhand Companion App located in your AddOns folder, or download it from GitHub below:\\n'
new_text = 'The Offhand Companion App is required to stretch the WoW window. Download it securely from GitHub below:\\n'

code = re.sub(pattern, new_text, code)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

