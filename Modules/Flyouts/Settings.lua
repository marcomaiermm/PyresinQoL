local _, ns = ...

ns.RegisterModuleSettings("flyouts", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local main = context.pages.main

    for _, option in ipairs(module.flyoutOptions) do
        local valueType = option.choices and Settings.VarType.String or Settings.VarType.Number
        local setting = Register(main, option.key:gsub("^%l", string.upper), option.key, valueType, option.label,
            option.default, module.UpdateFlyouts)
        option.setting = setting -- the Edit Mode dialog writes through it
        local initializer
        if option.choices then
            initializer = Settings.CreateDropdownInitializer(setting, function()
                local container = Settings.CreateControlTextContainer()
                for _, choice in ipairs(option.choices) do container:Add(choice[1], choice[2]) end
                return container:GetData()
            end)
        else
            local slider = Settings.CreateSliderOptions(option.min, option.max, option.step or 1)
            slider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                function(value) return module.FormatFlyoutOption(option, value) end)
            initializer = Settings.CreateSliderInitializer(setting, slider)
        end
        AddControl(main, initializer)
    end
end)
