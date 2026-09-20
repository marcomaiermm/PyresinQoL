local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("unitFrames", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local unitFrames = context.pages.main
    local category = context.category

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

        local statusModes = { "NUMERIC", "PERCENT", "BOTH", "NONE" }
        local function GetStatusText()
            if GetCVar("statusText") == "0" then return 4 end
            local current = GetCVar("statusTextDisplay")
            for value, mode in ipairs(statusModes) do
                if mode == current then return value end
            end
            return 4
        end
        local function SetStatusText(value)
            if not unitFrames.module.active or not PyresinQoLDB.modules.unitFrames then return end
            -- Native proxy callbacks run the restricted formatter in the caller's context.
            -- Change CVars only; Blizzard refreshes its bars through engine CVAR_UPDATE events.
            -- Toggle visibility so changing between two visible formats also refreshes immediately.
            SetCVar("statusText", "0")
            SetCVar("statusTextDisplay", statusModes[value])
            if value ~= 4 then SetCVar("statusText", "1") end
        end
        local statusText = Settings.RegisterProxySetting(category, "PyresinQoL_StatusText",
            Settings.VarType.Number, STATUSTEXT_LABEL, 4, GetStatusText, SetStatusText)
        AddControl(unitFrames, Settings.CreateDropdownInitializer(statusText, function()
            local options = Settings.CreateControlTextContainer()
            options:Add(4, NONE)
            options:Add(2, STATUS_TEXT_PERCENT)
            options:Add(3, STATUS_TEXT_BOTH)
            options:Add(1, STATUS_TEXT_VALUE)
            return options:GetData()
        end, L.unitStatusTextHelp))
        table.insert(unitFrames.settings, { setting = statusText, default = statusText:GetDefaultValue() })
        local oldFormats = { value = 1, percent = 2, both = 3, none = 4 }
        local previous = oldFormats[PyresinQoLDB.playerHPFormat] or oldFormats[PyresinQoLDB.playerManaFormat]
        if unitFrames.module.active then
            if previous then statusText:SetValue(previous, true) end
            PyresinQoLDB.playerHPFormat, PyresinQoLDB.playerManaFormat = nil, nil
        end

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
