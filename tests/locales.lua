-- Load each dictionary independently: English fallback must not conceal omissions.
local locales = {"enUS","deDE","esES","esMX","frFR","itIT","koKR","ptBR","ruRU","zhCN","zhTW"}
local function dictionary(locale)
    GetLocale = function() return locale end
    local addon = {L={}}
    assert(loadfile("Locales/"..locale..".lua"))("Offhand",addon)
    return addon.L
end
local base = dictionary("enUS")
assert(base.FOREVER_PARTY_FRAME_RECOVERY_TEXT:find("Restore Window", 1, true)
        and base.FOREVER_PARTY_FRAME_RECOVERY_TEXT:find("/reload", 1, true),
    "Party Frame recovery must describe the reachable single-window workflow")
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
local french = dictionary("frFR")
for key, text in pairs(base) do
    if key:match("^ONBOARD_") or key:match("^WIZARD_RECOVERY_") then
        assert(french[key] ~= text, "French setup still uses English fallback for " .. key)
    end
end
-- Product names and mathematical controls are deliberately language-neutral.
-- Complete keys alone must never hide newer English fallback paragraphs.
local invariant = {BINDING_HEADER_OFFHAND=true, BTN_DISCORD=true, BTN_SEAM_MINUS=true,
    BTN_SEAM_PLUS=true, ELLESMERE_HUD_MAINHAND=true, SETUP_STAGE_ELLESMERE=true,
    WORKSPACE_ROUTE_MAINHAND=true, WORKSPACE_ROUTE_COLLECTIONS=true}
for _, locale in ipairs({"deDE", "frFR", "itIT", "esES", "esMX"}) do
    local values=dictionary(locale)
    for key,text in pairs(base) do
        assert(values[key] ~= text or invariant[key],
            locale .. ": untranslated English text in " .. key)
    end
end
print("PASS: all 11 locale dictionaries have complete keys and matching format arguments")

