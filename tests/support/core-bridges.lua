--[[
    Loads the real bridge registry and built-in bridge files into a suite's own
    addon table. Usage, from the repository root:

        local CoreBridges = dofile("tests/support/core-bridges.lua")
        local Bridges = CoreBridges.Load(addon, { "Bridges/<Addon>/Bridge.lua" })

    CoreBridges.Load(addon, files) runs Core/Bridges.lua as Offhand would
      (loadfile(path)("Offhand", addon)) unless addon.Bridges already exists, so
      a suite that loaded the registry itself keeps its registrations. It then
      runs every path of files (optional, in order) the same way and returns
      addon.Bridges. A suite whose assertions depend on an addon's data or
      bridge gains this one call and keeps every assertion. Bridge files that
      need the shared helper list "Bridges/Shared/DefaultAnchors.lua" first.
--]]

local CoreBridges = {}

function CoreBridges.Load(addon, files)
    assert(type(addon) == "table", "CoreBridges.Load needs the suite's addon table")
    if addon.Bridges == nil then assert(loadfile("Core/Bridges.lua"))("Offhand", addon) end
    for _, path in ipairs(files or {}) do
        assert(loadfile(path), path .. " must parse")("Offhand", addon)
    end
    return addon.Bridges
end

return CoreBridges
