local _, ns = ...

-- Whether an option's parent (see FlightTimer/Options.lua) leaves it enabled, with get reading a saved value.
function ns.IsOptionEnabled(option, get)
    local value = get(option.parent)
    if option.parentValue then return value == option.parentValue end
    return value ~= false and value ~= "off"
end

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
        -- Blizzard looks for the parent in its own panel's open layout, never this window's list, and fails
        -- when that is our canvas category. It found no parent there before either: keep that look.
        function initializer:IsParentInitializerInLayout() return false end
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
