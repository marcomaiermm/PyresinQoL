local _, ns = ...

function ns.CreateSettingsControls(category)
    local function Register(page, variable, key, valueType, name, default, callback)
        local setting = Settings.RegisterAddOnSetting(category, "PyresinQoL_" .. variable,
            key, PyresinQoLDB, valueType, name, default)
        setting:SetValueChangedCallback(function(...)
            if callback and page.module.active and PyresinQoLDB.modules[page.module.id] then callback(...) end
        end)
        table.insert(page.settings, { setting = setting, default = default })
        return setting
    end
    local function AddControl(page, initializer)
        if page.module then
            initializer:AddModifyPredicate(function()
                return page.module.active and PyresinQoLDB.modules[page.module.id]
            end)
        end
        function initializer:GetExtent() return 44 end
        local initialize = initializer.InitFrame
        function initializer:InitFrame(frame)
            initialize(self, frame)
            -- Keep a common control column and leave room for two-line translated labels.
            frame.Text:ClearAllPoints()
            frame.Text:SetPoint("LEFT", 8, 0)
            frame.Text:SetPoint("RIGHT", frame, "RIGHT", -320, 0)
            frame.Text:SetWordWrap(true)
            frame.Text:SetMaxLines(2)
            frame.Tooltip:ClearAllPoints()
            frame.Tooltip:SetPoint("TOPLEFT")
            frame.Tooltip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -316, 0)
            local control = frame.Checkbox or frame.SliderWithSteppers or frame.Control or frame.ColorSwatch
            control:ClearAllPoints()
            if frame.Control then
                control:SetPoint("CENTER", frame, "RIGHT", -166, 0)
                control.Dropdown:SetWidth(240)
            else
                control:SetPoint("LEFT", frame, "RIGHT", -304, 0)
                if frame.SliderWithSteppers then control:SetWidth(250) end
            end
        end
        table.insert(page.initializers, initializer)
    end
    local function Choices(firstValue, firstName, secondValue, secondName)
        return function()
            local options = Settings.CreateControlTextContainer()
            options:Add(firstValue, firstName)
            options:Add(secondValue, secondName)
            return options:GetData()
        end
    end

    return { Register = Register, AddControl = AddControl, Choices = Choices }
end
