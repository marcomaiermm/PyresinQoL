local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("unitFrames", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl

    local function AuraSlider(page, key, name, default, minimum, maximum, callback, pixels)
        local setting = Register(page, key, key, Settings.VarType.Number, name, default, callback)
        local options = Settings.CreateSliderOptions(minimum, maximum, 1)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
            return (pixels and "%.0f px" or "%.0f"):format(value)
        end)
        AddControl(page, Settings.CreateSliderInitializer(setting, options, L.auraApplyHelp))
    end
    local function AuraDropdown(page, key, name, default, values, callback)
        local setting = Register(page, key, key, Settings.VarType.String, name, default, callback)
        AddControl(page, Settings.CreateDropdownInitializer(setting, function()
            local options = Settings.CreateControlTextContainer()
            for _, choice in ipairs(values) do options:Add(choice[1], choice[2]) end
            return options:GetData()
        end, L.auraApplyHelp))
    end

    local auras = context.pages.auras
    for _, prefix in ipairs({ "buff", "debuff" }) do
        table.insert(auras.initializers, CreateSettingsListSectionHeaderInitializer(L[prefix .. "Auras"]))
        for _, option in ipairs({ { "Layout", L.auraLayout, false }, { "OwnRow", L.auraOwnRow, false },
            { "Swipe", L.auraSwipe, false }, { "CooldownNumbers", L.auraCooldownNumbers, false } }) do
            local key = prefix .. option[1]
            local setting = Register(auras, key, key, Settings.VarType.Boolean,
                option[2], option[3], module.UpdatePlayerAuras)
            AddControl(auras, Settings.CreateCheckboxInitializer(setting, nil,
                option[1] == "Layout" and L.auraLayoutHelp or L.auraApplyHelp))
        end
        for _, option in ipairs({
            { "Own", L.auraOwn, "mixed", { { "mixed", L.auraMixed }, { "first", L.auraOwnFirst }, { "last", L.auraOwnLast } } },
            { "Sort", L.auraSort, "index", { { "index", L.auraIndex }, { "name", L.auraName }, { "time", L.auraTime } } },
            { "SortDirection", L.auraSortDirection, "ascending", { { "ascending", L.auraAscending }, { "descending", L.auraDescending } } },
            { "Direction", L.auraDirection, "LEFT", { { "LEFT", L.auraLeft }, { "RIGHT", L.auraRight } } },
            { "Growth", L.auraGrowth, "DOWN", { { "DOWN", L.auraDown }, { "UP", L.auraUp } } },
            { "TimerPosition", L.auraTimerPosition, "native", { { "native", L.auraNative }, { "below", L.auraBelow },
                { "inside", L.auraInside }, { "above", L.auraAbove }, { "hidden", L.hidden } } },
        }) do
            AuraDropdown(auras, prefix .. option[1], option[2], option[3], option[4], module.UpdatePlayerAuras)
        end
        for _, option in ipairs({
            { "Size", L.auraSize, 30, 16, 64, true },
            { "Wrap", L.auraWrap, 8, 1, 32 }, { "Rows", L.auraRows, 4, 1, 8 },
            { "GapX", L.auraGapX, 5, 0, 40, true }, { "GapY", L.auraGapY, 14, 0, 40, true },
            { "TimerSize", L.auraTimerSize, 12, 8, 24, true }, { "TimerGap", L.auraTimerGap, 0, 0, 16, true },
        }) do
            AuraSlider(auras, prefix .. option[1], option[2], option[3], option[4], option[5],
                module.UpdatePlayerAuras, option[6])
        end
    end

    table.insert(context.pages.statusText.initializers, CreateSettingsListSectionHeaderInitializer(L.hideStatusText))
    for _, unit in ipairs({ "pet", "target", "targettarget", "focus" }) do
        local key = unit .. "HideStatusText"
        local setting = Register(context.pages.statusText, key, key, Settings.VarType.Boolean,
            L[key], false, module.UpdateStatusText)
        AddControl(context.pages.statusText, Settings.CreateCheckboxInitializer(setting, nil, L.hideStatusTextHelp))
    end

    -- Register these controls alongside Blizzard's settings.
    SettingsRegistrar:AddRegistrant(function()
        local nameplates = context.pages.nameplates
        local nameplateThreat = Register(nameplates, "NameplateThreat", "nameplateThreat", Settings.VarType.Boolean,
            L.nameplateThreat, true, module.UpdateNameplateThreat)
        AddControl(nameplates, Settings.CreateCheckboxInitializer(nameplateThreat, nil, L.nameplateThreatHelp))
        local position = Register(nameplates, "NameplateThreatPosition", "nameplateThreatPosition", Settings.VarType.String,
            L.nameplateThreatPosition, "RIGHT", module.UpdateNameplateThreat)
        local function PositionOptions()
            local options = Settings.CreateControlTextContainer()
            for _, point in ipairs({ "RIGHT", "LEFT", "TOP", "BOTTOM" }) do options:Add(point, L[point]) end
            return options:GetData()
        end
        AddControl(nameplates, Settings.CreateDropdownInitializer(position, PositionOptions, L.nameplateThreatPositionHelp))
        local function IsModuleEnabled() return module.active and PyresinQoLDB.modules.unitFrames end
        local nativeCategory = Settings.GetCategory(Settings.NAMEPLATE_OPTIONS_CATEGORY_ID)
        local checkbox = Settings.CreateCheckbox(nativeCategory, nameplateThreat, L.nameplateThreatHelp)
        checkbox:AddModifyPredicate(IsModuleEnabled)
        local dropdown = Settings.CreateDropdown(nativeCategory, position, PositionOptions, L.nameplateThreatPositionHelp)
        dropdown:AddModifyPredicate(IsModuleEnabled)

        local comboPoints = Register(nameplates, "NameplateComboPoints", "nameplateComboPoints", Settings.VarType.Boolean,
            L.nameplateComboPoints, true, module.UpdateNameplateComboPoints)
        AddControl(nameplates, Settings.CreateCheckboxInitializer(comboPoints, nil, L.nameplateComboPointsHelp))
        local comboCheckbox = Settings.CreateCheckbox(nativeCategory, comboPoints, L.nameplateComboPointsHelp)
        comboCheckbox:AddModifyPredicate(IsModuleEnabled)

        for _, unit in ipairs({ "player", "target" }) do
            local unitPage = context.pages[unit]
            local classColor = Register(unitPage, unit .. "ClassColor", unit .. "ClassColor", Settings.VarType.Boolean,
                L.playerClassColor, false, module.UpdatePlayerFrame)
            AddControl(unitPage, Settings.CreateCheckboxInitializer(classColor, nil, L[unit .. "ClassColorHelp"]))
            for _, resource in ipairs({ "HP", "Mana" }) do
                local position = Register(unitPage, unit .. resource .. "Position", unit .. resource .. "Position",
                    Settings.VarType.String, L["player" .. resource .. "Position"], "CENTER", module.UpdatePlayerFrame)
                AddControl(unitPage, Settings.CreateDropdownInitializer(position, function()
                    local options = Settings.CreateControlTextContainer()
                    for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
                        options:Add(point, L[point])
                    end
                    return options:GetData()
                end, L.playerTextPositionHelp))
            end
            if unit == "player" then
                local mana = Register(unitPage, "DruidMana", "druidMana", Settings.VarType.Boolean,
                    L.druidMana, true, module.UpdateDruidMana)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(mana, nil, L.druidManaHelp))
                local cast = ns.CastBar
                table.insert(unitPage.initializers, CreateSettingsListSectionHeaderInitializer(L.castBarCustom))
                local enabled = Register(unitPage, "CastBarCustomization", "castBarCustomization",
                    Settings.VarType.Boolean, L.castBarEnable, false, function(_, value) cast.SetEnabled(value) end)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(enabled, nil, L.castBarEnableHelp))
                for _, action in ipairs({
                    { L.castBarConfigure, cast.Configure, L.castBarConfigureHelp },
                    { L.castBarReset, cast.Reset, L.castBarResetHelp },
                }) do
                    local button = CreateSettingsButtonInitializer(action[1], action[1], action[2], action[3], true)
                    button:AddSearchTags(action[3])
                    button:AddModifyPredicate(function()
                        return module.active and PyresinQoLDB.modules.unitFrames
                    end)
                    table.insert(unitPage.initializers, button)
                end
                unitPage.onReset = cast.Reset
            end
            if unit == "target" then
                local threat = Register(unitPage, "TargetThreat", "targetThreat", Settings.VarType.String,
                    L.targetThreat, "auto", module.UpdateTargetThreat)
                AddControl(unitPage, Settings.CreateDropdownInitializer(threat, function()
                    local options = Settings.CreateControlTextContainer()
                    for _, mode in ipairs({ "off", "auto", "combat", "always" }) do
                        options:Add(mode, L["targetThreat_" .. mode])
                    end
                    return options:GetData()
                end, L.targetThreatHelp))
                local debuffs = Register(unitPage, "TargetDebuffs", "targetDebuffs", Settings.VarType.Boolean,
                    L.targetDebuffs, true, module.UpdateTargetDebuffs)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(debuffs, nil, L.targetDebuffsHelp))
                local ownTimers = Register(unitPage, "TargetDebuffsOnlyMine", "targetDebuffsOnlyMine", Settings.VarType.Boolean,
                    L.targetDebuffsOnlyMine, true, module.UpdateTargetDebuffs)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(ownTimers, nil, L.targetDebuffsOnlyMineHelp))
                table.insert(unitPage.initializers, CreateSettingsListSectionHeaderInitializer(L.targetAuraLayout))
                local largeOwn = Register(unitPage, "TargetAuraLargeOwn", "targetAuraLargeOwn", Settings.VarType.Boolean,
                    L.targetAuraLargeOwn, true, module.UpdateTargetDebuffs)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(largeOwn, nil, L.targetAuraLayoutHelp))
                for _, option in ipairs({
                    { "targetAuraSize", L.auraSize, 17, 8, 64 },
                    { "targetAuraOwnSize", L.targetAuraOwnSize, 21, 8, 64 },
                    { "targetAuraRowWidth", L.targetAuraRowWidth, 122, 32, 512 },
                    { "targetAuraToTRowWidth", L.targetAuraToTRowWidth, 101, 32, 512 },
                    { "targetAuraGapX", L.auraGapX, 3, 0, 16 }, { "targetAuraGapY", L.auraGapY, 3, 0, 16 },
                }) do
                    AuraSlider(unitPage, option[1], option[2], option[3], option[4], option[5], module.UpdateTargetDebuffs, true)
                end
            end
        end
    end)
end)
