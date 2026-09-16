import re

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace(r'configFrame.enableCheck = enableCheck\n    local minimapCheck', 'configFrame.enableCheck = enableCheck\\n    local minimapCheck')

with open(r'D:\Tools\Code\Offhand\UI\Options.lua', 'w', encoding='utf-8') as f:
    f.write(code)
