local ns = {}
assert(loadfile("Modules/ActionBars/Config.lua"))("PyresinQoL", ns)
local config = ns.ActionBars

for _, case in ipairs({
    { name = "empty", value = "  ", expected = "" },
    { name = "unconditional", value = " hide ", expected = "hide" },
    { name = "branches", value = "[combat] hide; [] show", expected = "[combat] hide; [] show" },
    { name = "alternative conditions", value = "[combat] [stealth] hide; show", expected = "[combat][stealth] hide; show" },
    { name = "invalid result", value = "[combat] hide; [stealth] maybe", error = "actionBarConditionResult" },
    { name = "missing bracket", value = "[combat hide", error = "actionBarConditionBranch" },
    { name = "nested bracket", value = "[[combat]] hide", error = "actionBarConditionBranch" },
    { name = "empty branch", value = "hide;;show", error = "actionBarConditionBranch" },
    { name = "trailing branch", value = "hide;", error = "actionBarConditionBranch" },
    { name = "control character", value = "hide\n", error = "actionBarConditionControl" },
    { name = "markup", value = "|cFFFFFFFFhide", error = "actionBarConditionControl" },
    { name = "oversized", value = string.rep("x", 1024), error = "actionBarConditionLength" },
    { name = "non-string", value = false, error = "actionBarConditionType" },
}) do
    local actual, errorKey = config.ValidateCondition(case.value)
    assert(actual == case.expected and errorKey == case.error, case.name)
end

for _, case in ipairs({
    { name = "valid alpha", key = "actionBarMainAlphaNormal", value = .37, expected = .37 },
    { name = "negative alpha", key = "actionBarMainAlphaNormal", value = -.1, expected = 1 },
    { name = "alpha overflow", key = "actionBarMainAlphaNormal", value = 1.1, expected = 1 },
    { name = "NaN alpha", key = "actionBarMainAlphaNormal", value = 0/0, expected = 1 },
    { name = "font boundary", key = "actionBarHotkeySize", value = 24, expected = 24 },
    { name = "fractional font", key = "actionBarHotkeySize", value = 12.5, expected = 0 },
    { name = "font overflow", key = "actionBarHotkeySize", value = 25, expected = 0 },
    { name = "boolean", key = "actionBarMainEnabled", value = true, expected = true },
    { name = "non-boolean", key = "actionBarMainEnabled", value = 1, expected = false },
    { name = "valid color", key = "actionBarRangeIconColor", value = "FF123456", expected = "FF123456" },
    { name = "invalid color", key = "actionBarRangeIconColor", value = "red", expected = "FFFF3333" },
    { name = "invalid saved macro", key = "actionBarMainCustomCondition", value = "[combat] hide; [stealth] maybe", expected = "" },
}) do
    PyresinQoLDB = { [case.key] = case.value }
    assert(config.Get(case.key) == case.expected, case.name)
    assert(rawequal(PyresinQoLDB[case.key], case.value) or case.value ~= case.value,
        case.name .. ": fallback must preserve the saved value")
end
print("PASS: action-bar condition grammar and saved-value validation tables")
