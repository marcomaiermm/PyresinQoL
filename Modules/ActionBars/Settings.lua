local _, ns = ...
local L = ns.L
local actionBars = ns.ActionBars

local function RegisterConditionDialog()
    if StaticPopupDialogs.PYRESINQOL_ACTIONBAR_CONDITION then return end
    StaticPopupDialogs.PYRESINQOL_ACTIONBAR_CONDITION = {
        text = L.actionBarConditionDialog,
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(dialog, data)
            local input = dialog:GetEditBox()
            input:SetMaxLetters(1023)
            input:SetText(actionBars.Get(data.key))
            input:HighlightText()
            input:SetFocus()
        end,
        EditBoxOnTextChanged = function(input, data)
            local value = actionBars.ValidateCondition(input:GetText())
            input:GetParent():GetButton1():SetEnabled(value ~= nil and not InCombatLockdown())
        end,
        EditBoxOnEnterPressed = function(input)
            local button = input:GetParent():GetButton1()
            if button:IsEnabled() then button:Click() end
        end,
        EditBoxOnEscapePressed = function(input) input:GetParent():Hide() end,
        OnAccept = function(dialog, data)
            if InCombatLockdown() then return true end
            local value, errorKey = actionBars.ValidateCondition(dialog:GetEditBox():GetText())
            if not value then
                UIErrorsFrame:AddMessage(L[errorKey] or L.actionBarConditionInvalid, 1, 0.2, 0.2)
                return true
            end
            data.setting:SetValue(value)
        end,
    }
end

ns.RegisterModuleSettings("actionBars", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local main = context.pages.main
    local function Section(page, label)
        table.insert(page.initializers, CreateSettingsListSectionHeaderInitializer(label))
    end
    local function Checkbox(page, key, name, default, help)
        local setting = Register(page, key, key, Settings.VarType.Boolean, name, default, module.UpdateActionBars)
        AddControl(page, Settings.CreateCheckboxInitializer(setting, nil, help or L[key .. "Help"] or L.actionBarVisibilityHelp))
        return setting
    end
    local function Color(page, key, name, default)
        local setting = Register(page, key, key, Settings.VarType.String, name, default, module.UpdateActionBars)
        AddControl(page, Settings.CreateColorSwatchInitializer(setting))
        return setting
    end
    local function Slider(page, key, name, default, minimum, maximum, step, formatter)
        local setting = Register(page, key, key, Settings.VarType.Number, name, default, module.UpdateActionBars)
        local options = Settings.CreateSliderOptions(minimum, maximum, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter)
        AddControl(page, Settings.CreateSliderInitializer(setting, options, L[key .. "Help"] or L.actionBarVisibilityHelp))
        return setting
    end
    local function FontSize(value)
        return value == 0 and L.actionBarNative or ("%.0f px"):format(value)
    end

    Section(main, L.actionBarColors)
    Checkbox(main, "actionBarColorIcons", L.actionBarColorIcons, false)
    Checkbox(main, "actionBarColorHotkeys", L.actionBarColorHotkeys, false)
    Color(main, "actionBarRangeIconColor", L.actionBarRangeIconColor, actionBars.defaults.actionBarRangeIconColor)
    Color(main, "actionBarManaIconColor", L.actionBarManaIconColor, actionBars.defaults.actionBarManaIconColor)
    Color(main, "actionBarUnusableIconColor", L.actionBarUnusableIconColor, actionBars.defaults.actionBarUnusableIconColor)
    Color(main, "actionBarRangeHotkeyColor", L.actionBarRangeHotkeyColor, actionBars.defaults.actionBarRangeHotkeyColor)
    Color(main, "actionBarManaHotkeyColor", L.actionBarManaHotkeyColor, actionBars.defaults.actionBarManaHotkeyColor)
    Color(main, "actionBarUnusableHotkeyColor", L.actionBarUnusableHotkeyColor, actionBars.defaults.actionBarUnusableHotkeyColor)

    Section(main, L.actionBarFonts)
    Slider(main, "actionBarHotkeySize", L.actionBarHotkeySize, 0, 0, 24, 1, FontSize)
    Slider(main, "actionBarMacroSize", L.actionBarMacroSize, 0, 0, 24, 1, FontSize)
    Slider(main, "actionBarCountSize", L.actionBarCountSize, 0, 0, 24, 1, FontSize)
    Checkbox(main, "actionBarCompactHotkeys", L.actionBarCompactHotkeys, false)

    RegisterConditionDialog()
    actionBars.settings = {}
    for _, bar in ipairs(actionBars.bars) do
        local prefix = bar.prefix
        -- Keep settings registration for defaults and profile refresh; controls live in Edit Mode.
        for key, default in pairs(actionBars.defaults) do
            if key:sub(1, #prefix) == prefix then
                local valueType = type(default) == "boolean" and Settings.VarType.Boolean
                    or type(default) == "number" and Settings.VarType.Number or Settings.VarType.String
                actionBars.settings[key] = Register(main, key, key, valueType,
                    L["actionBar" .. key:sub(#prefix + 1)], default, module.UpdateActionBars)
            end
        end
    end

    Section(main, L.actionBarVisibility)
    local editMode = CreateSettingsButtonInitializer(L.actionBarVisibility, L.actionBarEditMode,
        function() if module.ConfigureActionBars then module.ConfigureActionBars() end end,
        L.actionBarEditModeHelp, true)
    editMode:AddSearchTags(L.actionBarEditModeHelp)
    editMode:AddModifyPredicate(function() return module.active and PyresinQoLDB.modules[module.id] end)
    table.insert(main.initializers, editMode)
end)
