local _, ns = ...

ns.RegisterModuleSettings("flightTimer", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local main = context.pages.main

    local built = {} -- key -> { setting, initializer }, for the children greyed out with their parent
    for _, option in ipairs(module.flightTimerOptions) do
        local valueType = option.choices and Settings.VarType.String
            or option.min and Settings.VarType.Number or Settings.VarType.Boolean
        local setting = Register(main, option.key:gsub("^%l", string.upper), option.key, valueType, option.label,
            option.default, module.UpdateFlightTimerStyle)
        option.setting = setting -- the Edit Mode dialog writes through it
        local initializer
        if option.choices then
            initializer = Settings.CreateDropdownInitializer(setting, function()
                local container = Settings.CreateControlTextContainer()
                for _, choice in ipairs(option.choices) do container:Add(choice[1], choice[2]) end
                return container:GetData()
            end)
        elseif option.min then
            local slider = Settings.CreateSliderOptions(option.min, option.max, option.step or 1)
            slider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return module.FormatFlightTimerOption(option, value) end)
            initializer = Settings.CreateSliderInitializer(setting, slider)
            if option.scaled then
                -- A new scale changes the width's text alone.
                local initialize = initializer.InitFrame
                function initializer:InitFrame(frame)
                    initialize(self, frame)
                    frame.cbrHandles:SetOnValueChangedCallback("PyresinQoL_FlightTimerScale", function()
                        frame.SliderWithSteppers:FormatValue(setting:GetValue())
                    end)
                end
            end
        else
            initializer = Settings.CreateCheckboxInitializer(setting)
        end
        local parent = built[option.parent]
        if parent then
            initializer:SetParentInitializer(parent.initializer, function()
                return module.FlightTimerOptionEnabled(option, function() return parent.setting:GetValue() end)
            end)
        end
        AddControl(main, initializer)
        built[option.key] = { setting = setting, initializer = initializer }
    end
end)
