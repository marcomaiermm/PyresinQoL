local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("unitFrames", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl

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
            end
            if unit == "target" then
                local threat = Register(unitPage, "TargetThreat", "targetThreat", Settings.VarType.Boolean,
                    L.targetThreat, true, module.UpdateTargetThreat)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(threat, nil, L.targetThreatHelp))
                local debuffs = Register(unitPage, "TargetDebuffs", "targetDebuffs", Settings.VarType.Boolean,
                    L.targetDebuffs, true, module.UpdateTargetDebuffs)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(debuffs, nil, L.targetDebuffsHelp))
                local ownTimers = Register(unitPage, "TargetDebuffsOnlyMine", "targetDebuffsOnlyMine", Settings.VarType.Boolean,
                    L.targetDebuffsOnlyMine, true, module.UpdateTargetDebuffs)
                AddControl(unitPage, Settings.CreateCheckboxInitializer(ownTimers, nil, L.targetDebuffsOnlyMineHelp))
            end
        end
    end)
end)
