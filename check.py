import sys
with open(r'D:\Tools\Code\Offhand\Core\Canvas.lua', 'r', encoding='utf-8') as f:
    lua = f.read()
idx = lua.find('CloseAllWindows = function')
print(lua[idx:idx+1500])
