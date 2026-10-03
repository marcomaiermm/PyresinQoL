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
    local main, visibility = context.pages.main, context.pages.visibility
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
    local function Opacity(value) return ("%.0f%%"):format(value * 100) end

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
    for _, bar in ipairs(actionBars.bars) do
        local prefix = bar.prefix
        Section(visibility, L[bar.label])
        Checkbox(visibility, prefix .. "Enabled", L.actionBarEnabled, false)
        Checkbox(visibility, prefix .. "HideCombat", L.actionBarHideCombat, false)
        Checkbox(visibility, prefix .. "HideOutOfCombat", L.actionBarHideOutOfCombat, false)
        Checkbox(visibility, prefix .. "HideStealth", L.actionBarHideStealth, false)
        Checkbox(visibility, prefix .. "HideNotStealth", L.actionBarHideNotStealth, false)
        Checkbox(visibility, prefix .. "HideForm", L.actionBarHideForm, false)
        Checkbox(visibility, prefix .. "HideNoForm", L.actionBarHideNoForm, false)
        Slider(visibility, prefix .. "AlphaNormal", L.actionBarAlphaNormal, 1, 0, 1, 0.01, Opacity)
        Slider(visibility, prefix .. "AlphaCombat", L.actionBarAlphaCombat, 1, 0, 1, 0.01, Opacity)
        Checkbox(visibility, prefix .. "Mouseover", L.actionBarMouseover, false, L.actionBarMouseoverHelp)

        local condition = Register(visibility, prefix .. "CustomCondition", prefix .. "CustomCondition",
            Settings.VarType.String, L.actionBarCustomCondition, "", module.UpdateActionBars)
        local button = CreateSettingsButtonInitializer(L.actionBarEditCondition, L.actionBarEditCondition,
            function() StaticPopup_Show("PYRESINQOL_ACTIONBAR_CONDITION", nil, nil, {
                key = prefix .. "CustomCondition", setting = condition,
            }) end, L.actionBarCustomConditionHelp, false)
        button:AddModifyPredicate(function()
            return module.active and PyresinQoLDB.modules[module.id]
        end)
        table.insert(visibility.initializers, button)
    end
end)
