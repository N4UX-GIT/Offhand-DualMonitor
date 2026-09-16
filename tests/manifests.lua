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
local main,era=entries("Offhand.toc"),entries("Offhand_Vanilla.toc")
assert(#main==#era, "Client TOCs load different numbers of files")
for i,file in ipairs(main) do assert(file==era[i], "Client TOC load order mismatch: "..file) end
print("PASS: matching client load order and loadable Lua files")
