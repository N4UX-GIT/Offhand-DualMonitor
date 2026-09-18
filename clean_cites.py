import os
import re
import glob

locales_dir = r'D:\Tools\Code\Offhand\Locales'
lua_files = glob.glob(os.path.join(locales_dir, '*.lua'))

pattern = re.compile(r'\[cite: \d+\]')

for filepath in lua_files:
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    new_content = pattern.sub('', content)
    
    if content != new_content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Cleaned {filepath}")

