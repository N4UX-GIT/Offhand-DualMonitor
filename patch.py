import re

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'r', encoding='utf-8') as f:
    code = f.read()

pattern = r'For a seamless, borderless experience, the Offhand Companion App is highly recommended\. Download it securely from GitHub below:\\n\\n\(Alternatively, if you are attempting to stretch the window manually, ensure you drag it fully across both monitors\. Click Ignore to permanently dismiss this warning\)\.'
new_text = 'For a seamless, borderless experience—and to avoid the tedious process of manually stretching the window edges every time you launch the game—the Offhand Companion App is highly recommended. Download it securely from GitHub below:\\n\\n(Alternatively, if you prefer to stretch the window manually across both monitors, click Ignore to permanently dismiss this warning).'

code = re.sub(pattern, new_text, code)

with open(r'D:\Tools\Code\Offhand\Core\Init.lua', 'w', encoding='utf-8') as f:
    f.write(code)

