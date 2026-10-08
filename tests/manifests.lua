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
    assert(text:match("## X%-Offhand%-Release:%s*beta%.20"), "Beta 20 addon release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Version:%s*2%.1%.2"), "Frozen Companion version marker changed: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Release:%s*beta%.20"), "Beta 20 Companion release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Protocol:%s*1"), "Companion protocol marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Min%-Version:%s*2%.1%.2%-beta%.19"), "Companion minimum version marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Addon%-Release:%s*beta%.20"), "Beta 20 addon release marker missing: " .. toc)
end
local genericText = assert(io.open("Offhand.toc", "rb")):read("*a")
local classicText = assert(io.open("Offhand_Classic.toc", "rb")):read("*a")
local wrathText = assert(io.open("Offhand_Wrath335a.toc", "rb")):read("*a")
assert(genericText:match("## Interface:%s*30300"),
    "generic manifest must lead with 30300 for the original single-value TOC parser")
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
print("PASS: matching client load order and loadable Lua files across all TOCs")

