local ns = PyresinQoL

-- A page per bar, under the Resource Bars entry.
ns.RegisterModuleSettings("resourceBar", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl

    for _, bar in ipairs(module.resourceBars) do
        -- No page for a class without the bar.
        local page = context.pages[bar.id]
        local built = {} -- key -> { setting, initializer }, for the children greyed out with their parent
        for _, option in ipairs(page and bar.playerOptions or {}) do
            if option.section then
                table.insert(page.initializers, CreateSettingsListSectionHeaderInitializer(option.section))
            end
            local valueType = (option.choices or option.color) and Settings.VarType.String
                or option.min and Settings.VarType.Number or Settings.VarType.Boolean
            local setting = Register(page, option.key:gsub("^%l", string.upper), option.key, valueType, option.label,
                option.default, module.UpdateResourceBars)
            option.setting = setting -- the Edit Mode dialog writes through it
            local initializer
            if option.choices then
                initializer = Settings.CreateDropdownInitializer(setting, function()
                    local container = Settings.CreateControlTextContainer()
                    for _, choice in ipairs(option.choices) do container:Add(choice[1], choice[2]) end
                    return container:GetData()
                end)
            elseif option.color then
                initializer = Settings.CreateColorSwatchInitializer(setting)
            elseif option.min then
                local slider = Settings.CreateSliderOptions(option.min, option.max, 1)
                slider:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
                    function(value) return module.FormatResourceBarOption(option, value) end)
                initializer = Settings.CreateSliderInitializer(setting, slider)
            else
                initializer = Settings.CreateCheckboxInitializer(setting, nil, option.tooltip)
            end
            local parent = built[option.parent]
            if parent then
                initializer:SetParentInitializer(parent.initializer, function()
                    return ns.IsOptionEnabled(option, function() return parent.setting:GetValue() end)
                end)
            end
            AddControl(page, initializer)
            built[option.key] = { setting = setting, initializer = initializer }
        end
    end
end)
