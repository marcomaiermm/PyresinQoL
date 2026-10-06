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
        initializer:AddSearchTags(initializer:GetName(), initializer:GetTooltip())
        if page.module then
            initializer:AddModifyPredicate(function()
                return page.module.active and PyresinQoLDB.modules[page.module.id]
            end)
        end
        function initializer:GetExtent() return 44 end
        local initialize = initializer.InitFrame
        function initializer:InitFrame(frame)
            initialize(self, frame)
            -- Keep native columns, with enough height for two translated lines.
            frame.Text:SetWordWrap(true)
            frame.Text:SetMaxLines(2)
            frame.Text:SetHeight(44)
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
