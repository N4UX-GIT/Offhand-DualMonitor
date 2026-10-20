local function entries(path)
    local result={}
    for line in io.lines(path) do
        local file=line:match("^%s*(.-%.lua)%s*$")
        if file and not file:match("^#") then
            file=file:gsub("\\", "/")
            assert(loadfile(file), "Invalid or missing TOC file: "..file)
            result[#result+1]=file
        end
    end
    return result
end
local tocs = {"Offhand.toc", "Offhand_Mainline.toc", "Offhand_Vanilla.toc", "Offhand_Classic.toc", "Offhand_Forever.toc", "Offhand_Wrath335a.toc"}
for _, toc in ipairs(tocs) do
    local text = assert(io.open(toc, "rb")):read("*a")
    assert(text:match("## LoadSavedVariablesFirst:%s*1"), "Missing early SavedVariables load: " .. toc)
    assert(text:match("## X%-Offhand%-Manifest:%s*%S+"), "Missing manifest diagnostic marker: " .. toc)
    assert(text:match("## X%-Offhand%-Release:%s*beta%.21"), "Beta 21 addon release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Version:%s*2%.1%.2"), "Frozen Companion version marker changed: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Release:%s*beta%.20"), "Beta 20 Companion release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Protocol:%s*1"), "Companion protocol marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Min%-Version:%s*2%.1%.2%-beta%.19"), "Companion minimum version marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Addon%-Release:%s*beta%.21"), "Beta 21 addon release marker missing: " .. toc)
end
local genericText = assert(io.open("Offhand.toc", "rb")):read("*a")
local mainlineText = assert(io.open("Offhand_Mainline.toc", "rb")):read("*a")
local classicText = assert(io.open("Offhand_Classic.toc", "rb")):read("*a")
local wrathText = assert(io.open("Offhand_Wrath335a.toc", "rb")):read("*a")
assert(genericText:match("## Interface:%s*30300"),
    "generic manifest must lead with 30300 for the original single-value TOC parser")
assert(genericText:match("120105"),
    "generic manifest must support Retail 12.1.5 interface 120105")
assert(mainlineText:match("## Interface:%s*120105"),
    "Mainline manifest must lead with Retail 12.1.5 interface 120105")
assert(not genericText:match("121500") and not mainlineText:match("121500"),
    "12.1.5 must use interface 120105, not 121500")
assert(classicText:match("## Interface:%s*30300"),
    "Classic manifest must retain 30300 as its leading legacy package target")
assert(wrathText:match("## Interface:%s*30300%s*\r?\n"),
    "dedicated Wrath test manifest must target only interface 30300")
local main = entries(tocs[1])
for i=2,#tocs do
    local flavor = entries(tocs[i])
    assert(#main==#flavor, "Client TOCs load different numbers of files: " .. tocs[i])
    for j,file in ipairs(main) do assert(file==flavor[j], "Client TOC load order mismatch: "..file) end
end
local bindings = assert(io.open("Bindings.xml", "rb")):read("*a")
assert(bindings:match('<Binding name="OFFHAND_TOGGLE_SETTINGS" header="OFFHAND">'),
    "Offhand settings binding is missing")
assert(bindings:match('<Binding name="OFFHAND_TOGGLE_GAMEPAD_UI_FOCUS">'),
    "Forever Gamepad UI focus binding is missing")
assert(bindings:match('Offhand_ToggleGamepadUIFocus%(%s*%)'),
    "Forever Gamepad UI focus binding does not call its safe delegate")
local _, offhandHeaderCount = bindings:gsub('header="OFFHAND"', '')
assert(offhandHeaderCount == 1,
    "the OFFHAND binding header must be declared exactly once")
local initSource = assert(io.open("Core/Init.lua", "rb")):read("*a")
local optionsSource = assert(io.open("UI/Options.lua", "rb")):read("*a")
assert(initSource:find("HEADER_OFFHAND", 1, true)
        and initSource:find("BINDING_HEADER_OFFHAND", 1, true)
        and optionsSource:find("_G.HEADER_OFFHAND", 1, true),
    "Forever and standard binding-header globals must both be initialized")
assert(optionsSource:find("GAMEPAD_CATEGORY_ID", 1, true)
        and not optionsSource:find("settings.KEYBINDINGS_CATEGORY_ID,", 1, true),
    "the controller focus helper must open Gamepad settings, not keyboard bindings")
local packageSource = assert(io.open("package.ps1", "rb")):read("*a")
assert(packageSource:find('Join%-Path %$rootDir "Bindings%.xml"'),
    "release packaging must include the automatic Bindings.xml file")
print("PASS: matching client load order and loadable Lua files across all TOCs")

