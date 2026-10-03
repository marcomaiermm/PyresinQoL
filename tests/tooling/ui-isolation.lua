-- Loaded before the representative flows, and again after each ordered pass.
local state = PyresinQoLUITestIsolation
local function AuraIDs()
    local ids = {}
    for _, button in ipairs(BuffFrame.auraFrames or {}) do
        local id = button.hasValidInfo and button.buttonInfo and button.buttonInfo.auraInstanceID
        if id and C_UnitAuras.GetAuraDataByAuraInstanceID("player", id) then ids[id] = true end
    end
    return ids
end
local function SameState(expected, actual, path)
    assert(type(expected) == type(actual), path .. ": type changed")
    if type(expected) ~= "table" then
        assert(expected == actual, path .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        return
    end
    for key, value in pairs(expected) do SameState(value, actual[key], path .. "." .. key) end
    for key in pairs(actual) do assert(expected[key] ~= nil, path .. "." .. key .. ": unexpected saved value") end
end
if not state then
    state = { database = CopyTable(PyresinQoLDB), handler = geterrorhandler(), passes = 0,
        layout = C_EditMode.GetLayouts().activeLayout, auras = AuraIDs() }
    PyresinQoLUITestIsolation = state
else
    test("representative flows restore state after pass " .. (state.passes + 1), function()
        SameState(state.database, PyresinQoLDB, "PyresinQoLDB")
        SameState(state.auras, AuraIDs(), "PlayerAuras")
        assertEquals(state.handler, geterrorhandler())
        assertEquals(state.layout, C_EditMode.GetLayouts().activeLayout)
        assertFalse(PyresinQoLSettingsFrame:IsShown())
        assertFalse(EditModeManagerFrame:IsShown())
        assertFalse(EditModeSystemSettingsDialog:IsShown())
        assertFalse(GameMenuFrame:IsShown())
        assertFalse(ColorPickerFrame:IsShown())
        assertFalse(Menu.GetManager():IsAnyMenuOpen())
        for _, name in ipairs({ "NAME", "DELETE", "SWITCH" }) do
            assertNil(StaticPopup_FindVisible("PYRESINQOL_PROFILE_" .. name))
        end
        state.passes = state.passes + 1
        print("ui-isolation-pass-" .. state.passes .. "-clean")
    end)
end
