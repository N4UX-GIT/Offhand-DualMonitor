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
    assert(text:match("## X%-Offhand%-Release:%s*beta%.22"), "Beta 22 addon release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Version:%s*2%.1%.2"), "Frozen Companion version marker changed: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Release:%s*beta%.20"), "Beta 20 Companion release marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Protocol:%s*1"), "Companion protocol marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Companion%-Min%-Version:%s*2%.1%.2%-beta%.19"), "Companion minimum version marker missing: " .. toc)
    assert(text:match("## X%-Offhand%-Addon%-Release:%s*beta%.22"), "Beta 22 addon release marker missing: " .. toc)
end
local genericText = assert(io.open("Offhand.toc", "rb")):read("*a")
local mainlineText = assert(io.open("Offhand_Mainline.toc", "rb")):read("*a")
local classicText = assert(io.open("Offhand_Classic.toc", "rb")):read("*a")
local wrathText = assert(io.open("Offhand_Wrath335a.toc", "rb")):read("*a")
assert(genericText:match("## Interface:%s*30300"),
    "generic manifest must lead with 30300 for the original single-value TOC parser")
assert(genericText:match("120105"),
    "generic manifest must support Retail 12.1.5 interface 120105")
assert(genericText:match("120107"),
    "generic manifest must support Retail 12.1.7 interface 120107")
assert(mainlineText:match("## Interface:%s*120107"),
    "Mainline manifest must lead with Retail 12.1.7 interface 120107")
assert(mainlineText:match("120105"),
    "Mainline manifest must retain Retail 12.1.5 interface 120105")
assert(not genericText:match("121500") and not mainlineText:match("121500"),
    "12.1.5 must use interface 120105, not 121500")
assert(classicText:match("## Interface:%s*30300"),
    "Classic manifest must retain 30300 as its leading legacy package target")
assert(wrathText:match("## Interface:%s*30300%s*\r?\n"),
    "dedicated Wrath test manifest must target only interface 30300")
local main = entries(tocs[1])
local initIndex
local viewportIndex
local topologyDetectionIndex
local clientRuntimeIndex
local mainhandGeometryIndex
local mainhandCompatibilityIndex
local mainhandGamepadIndex
local mainhandEditModeIndex
local mainhandIndex
local hudCompatibilityIndex
local hudTransientPolicyIndex
local hudRecoveryIndex
local hudTransientFramesIndex
local seamRedirectIndex
local compatibilityIndex
local frameStateIndex
local panelRegistryIndex
local canvasPersistenceIndex
local canvasBackpackStateIndex
local canvasForeverBagsIndex
local canvasForeverMapIndex
local canvasChatIndex
local canvasProfessionsIndex
local canvasPanelMotionIndex
local canvasMapPresentationIndex
local canvasIndex
local controlsIndex
local optionsActionsIndex
local optionsIndex
for index, file in ipairs(main) do
    if file == "Core/Init.lua" then initIndex = index end
    if file == "Core/Viewport.lua" then viewportIndex = index end
    if file == "Core/TopologyDetection.lua" then topologyDetectionIndex = index end
    if file == "Core/ClientRuntime.lua" then clientRuntimeIndex = index end
    if file == "Core/MainhandGeometry.lua" then mainhandGeometryIndex = index end
    if file == "Core/MainhandCompatibility.lua" then mainhandCompatibilityIndex = index end
    if file == "Core/MainhandGamepad.lua" then mainhandGamepadIndex = index end
    if file == "Core/MainhandEditMode.lua" then mainhandEditModeIndex = index end
    if file == "Core/Mainhand.lua" then mainhandIndex = index end
    if file == "Core/HUDCompatibility.lua" then hudCompatibilityIndex = index end
    if file == "Core/HUDTransientPolicy.lua" then hudTransientPolicyIndex = index end
    if file == "Core/HUDRecovery.lua" then hudRecoveryIndex = index end
    if file == "Core/HUDTransientFrames.lua" then hudTransientFramesIndex = index end
    if file == "Core/SeamRedirect.lua" then seamRedirectIndex = index end
    if file == "Core/CanvasCompatibility.lua" then compatibilityIndex = index end
    if file == "Core/CanvasFrameState.lua" then frameStateIndex = index end
    if file == "Core/CanvasPanelRegistry.lua" then panelRegistryIndex = index end
    if file == "Core/CanvasPersistence.lua" then canvasPersistenceIndex = index end
    if file == "Core/CanvasBackpackState.lua" then canvasBackpackStateIndex = index end
    if file == "Core/CanvasForeverBags.lua" then canvasForeverBagsIndex = index end
    if file == "Core/CanvasForeverMap.lua" then canvasForeverMapIndex = index end
    if file == "Core/CanvasChat.lua" then canvasChatIndex = index end
    if file == "Core/CanvasProfessions.lua" then canvasProfessionsIndex = index end
    if file == "Core/CanvasPanelMotion.lua" then canvasPanelMotionIndex = index end
    if file == "Core/CanvasMapPresentation.lua" then canvasMapPresentationIndex = index end
    if file == "Core/Canvas.lua" then canvasIndex = index end
    if file == "UI/Controls.lua" then controlsIndex = index end
    if file == "UI/OptionsActions.lua" then optionsActionsIndex = index end
    if file == "UI/Options.lua" then optionsIndex = index end
end
assert(initIndex and clientRuntimeIndex and initIndex + 1 == clientRuntimeIndex,
    "client runtime capabilities must load immediately after Init")
assert(viewportIndex and topologyDetectionIndex and optionsIndex
        and viewportIndex + 1 == topologyDetectionIndex
        and topologyDetectionIndex < optionsIndex,
    "topology detection must load after Viewport and before settings")
assert(mainhandGeometryIndex and mainhandCompatibilityIndex and mainhandGamepadIndex
        and mainhandEditModeIndex and mainhandIndex
        and mainhandGeometryIndex + 1 == mainhandCompatibilityIndex
        and mainhandCompatibilityIndex + 1 == mainhandGamepadIndex
        and mainhandGamepadIndex + 1 == mainhandEditModeIndex
        and mainhandEditModeIndex + 1 == mainhandIndex,
    "Mainhand support services must load together immediately before Mainhand")
assert(hudCompatibilityIndex and hudTransientPolicyIndex and hudRecoveryIndex
        and hudTransientFramesIndex and seamRedirectIndex
        and hudCompatibilityIndex + 1 == hudTransientPolicyIndex
        and hudTransientPolicyIndex + 1 == hudRecoveryIndex
        and hudRecoveryIndex + 1 == hudTransientFramesIndex
        and hudTransientFramesIndex + 1 == seamRedirectIndex,
    "HUD support services must load together immediately before SeamRedirect")
assert(compatibilityIndex and frameStateIndex and panelRegistryIndex and canvasPersistenceIndex
        and canvasBackpackStateIndex and canvasForeverBagsIndex and canvasForeverMapIndex
        and canvasChatIndex and canvasProfessionsIndex and canvasPanelMotionIndex
        and canvasMapPresentationIndex and canvasIndex
        and compatibilityIndex + 1 == frameStateIndex
        and frameStateIndex + 1 == panelRegistryIndex
        and panelRegistryIndex + 1 == canvasPersistenceIndex
        and canvasPersistenceIndex + 1 == canvasBackpackStateIndex
        and canvasBackpackStateIndex + 1 == canvasForeverBagsIndex
        and canvasForeverBagsIndex + 1 == canvasForeverMapIndex
        and canvasForeverMapIndex + 1 == canvasChatIndex
        and canvasChatIndex + 1 == canvasProfessionsIndex
        and canvasProfessionsIndex + 1 == canvasPanelMotionIndex
        and canvasPanelMotionIndex + 1 == canvasMapPresentationIndex
        and canvasMapPresentationIndex + 1 == canvasIndex,
    "Canvas support services must load together immediately before Canvas")
assert(controlsIndex and optionsActionsIndex and optionsIndex
        and controlsIndex + 1 == optionsActionsIndex
        and optionsActionsIndex + 1 == optionsIndex,
    "shared controls and settings actions must load immediately before Options")
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
local optionsActionsSource = assert(io.open("UI/OptionsActions.lua", "rb")):read("*a")
assert(optionsActionsSource:find("AssignGamepadFocusBinding", 1, true)
        and not optionsSource:find("settings.OpenToCategory(gamepadCategoryID)", 1, true),
    "the controller focus helper must provide native binding capture instead of the unrelated settings page")
local packageSource = assert(io.open("package.ps1", "rb")):read("*a")
assert(packageSource:find('Join%-Path %$rootDir "Bindings%.xml"'),
    "release packaging must include the automatic Bindings.xml file")
print("PASS: matching client load order and loadable Lua files across all TOCs")

