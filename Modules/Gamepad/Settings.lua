local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("gamepad", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local page = context.pages.main

    local function Checkbox(key, default)
        local setting = Register(page, key:sub(1, 1):upper() .. key:sub(2), key, Settings.VarType.Boolean, L[key], default, module.UpdateGamepad)
        AddControl(page, Settings.CreateCheckboxInitializer(setting, nil, L[key .. "Help"]))
    end
    Checkbox("gamepadLootTooltips", true)

    local range = Settings.CreateSliderOptions(20, 40, 1)
    range:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return ("%.0f"):format(value) end)
    local setting = Register(page, "GamepadInteractRange", "gamepadInteractRange", Settings.VarType.Number, L.gamepadInteractRange, 30, module.UpdateGamepad)
    AddControl(page, Settings.CreateSliderInitializer(setting, range, L.gamepadInteractRangeHelp))

    Checkbox("gamepadSwapAB", false)
    Checkbox("gamepadSwapXY", false)
    Checkbox("gamepadSwitchLabels", false)
end)
