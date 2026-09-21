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
local tocs = {"Offhand.toc", "Offhand_Mainline.toc", "Offhand_Vanilla.toc", "Offhand_Classic.toc", "Offhand_Forever.toc"}
for _, toc in ipairs(tocs) do
    local text = assert(io.open(toc, "rb")):read("*a")
    assert(text:match("## LoadSavedVariablesFirst:%s*1"), "Missing early SavedVariables load: " .. toc)
    assert(text:match("## X%-Offhand%-Manifest:%s*%S+"), "Missing manifest diagnostic marker: " .. toc)
end
local main = entries(tocs[1])
for i=2,#tocs do
    local flavor = entries(tocs[i])
    assert(#main==#flavor, "Client TOCs load different numbers of files: " .. tocs[i])
    for j,file in ipairs(main) do assert(file==flavor[j], "Client TOC load order mismatch: "..file) end
end
print("PASS: matching client load order and loadable Lua files across all TOCs")

