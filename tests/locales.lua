-- Load each dictionary independently: English fallback must not conceal omissions.
local locales = {"enUS","deDE","esES","esMX","frFR","itIT","koKR","ptBR","ruRU","zhCN","zhTW"}
local function dictionary(locale)
    GetLocale = function() return locale end
    local addon = {L={}}
    assert(loadfile("Locales/"..locale..".lua"))("Offhand",addon)
    return addon.L
end
local base = dictionary("enUS")
local function placeholders(text)
    local result={}
    text=text:gsub("%%%%","")
    for token in text:gmatch("%%[%d%.]*[sdfix]") do result[#result+1]=token end
    return table.concat(result,"|")
end
for _,locale in ipairs(locales) do
    local values=dictionary(locale)
    for key,text in pairs(base) do
        assert(type(values[key])=="string" and values[key]~="",locale..": missing "..key)
        assert(placeholders(text)==placeholders(values[key]),locale..": format mismatch in "..key)
    end
end
print("PASS: all 11 locale dictionaries have complete keys and matching format arguments")

