local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("tooltips", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local page = context.pages.main

    local function Section(label)
        table.insert(page.initializers, CreateSettingsListSectionHeaderInitializer(label))
    end
    local function Setting(key, valueType, default)
        return Register(page, key:sub(1, 1):upper() .. key:sub(2), key, valueType, L[key], default, module.UpdateTooltips)
    end
    local function Checkbox(key, default)
        AddControl(page, Settings.CreateCheckboxInitializer(Setting(key, Settings.VarType.Boolean, default), nil, L[key .. "Help"]))
    end
    local function Dropdown(key, default, values)
        AddControl(page, Settings.CreateDropdownInitializer(Setting(key, Settings.VarType.String, default), function()
            local options = Settings.CreateControlTextContainer()
            for _, entry in ipairs(values) do options:Add(entry[1], entry[2]) end
            return options:GetData()
        end, L[key .. "Help"]))
    end
    local function Slider(key, default, minimum, maximum, step, format)
        local options = Settings.CreateSliderOptions(minimum, maximum, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
        AddControl(page, Settings.CreateSliderInitializer(Setting(key, Settings.VarType.Number, default), options, L[key .. "Help"]))
    end
    local function Offset(value) return ("%.0f px"):format(value) end
    local function Opacity(value) return ("%.0f%%"):format(value * 100) end

    Section(L.tooltipPositionSection)
    Dropdown("tooltipAnchor", "default", {
        { "default", L.tooltipAnchorDefault }, { "cursor", L.tooltipAnchorCursor }, { "fixed", L.tooltipAnchorFixed },
    })
    local points = {}
    for _, point in ipairs({ "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }) do
        points[#points + 1] = { point, L[point] }
    end
    Dropdown("tooltipAnchorPoint", "BOTTOMRIGHT", points)
    Slider("tooltipAnchorX", -30, -2500, 2500, 1, Offset)
    Slider("tooltipAnchorY", 120, -2500, 2500, 1, Offset)
    Dropdown("tooltipCursorAnchor", "ANCHOR_CURSOR_RIGHT", {
        { "ANCHOR_CURSOR_RIGHT", L.tooltipCursorRight }, { "ANCHOR_CURSOR_LEFT", L.tooltipCursorLeft },
        { "ANCHOR_CURSOR", L.tooltipCursorAbove },
    })
    Slider("tooltipCursorX", 16, -2500, 2500, 1, Offset)
    Slider("tooltipCursorY", 8, -2500, 2500, 1, Offset)
    Checkbox("tooltipAnchorCombat", false)
    Checkbox("tooltipObjectCursor", true)

    Section(L.tooltipSpellSection)
    Checkbox("tooltipAnchorSpells", true)
    Checkbox("tooltipSpellID", true)
    Checkbox("tooltipSpellIconID", false)

    Section(L.tooltipItemSection)
    Checkbox("tooltipItemQualityBorder", true)
    Checkbox("tooltipItemQualityBackground", false)
    Checkbox("tooltipItemStack", false)
    Checkbox("tooltipItemID", false)
    Checkbox("tooltipItemIconID", false)

    Section(L.tooltipUnitSection)
    Checkbox("tooltipHealth", true)
    Checkbox("tooltipGuildRank", true)
    Checkbox("tooltipTarget", true)
    Checkbox("tooltipUnitClassBorder", true)
    Checkbox("tooltipUnitReactionBorder", true)
    Checkbox("tooltipUnitClassBackground", false)
    Checkbox("tooltipUnitReactionBackground", false)

    Section(L.tooltipBackgroundSection)
    Checkbox("tooltipCustomBackground", false)
    AddControl(page, Settings.CreateColorSwatchInitializer(Setting("tooltipBackgroundColor", Settings.VarType.String, "FF000000")))
    Slider("tooltipBackgroundOpacity", 0.9, 0, 1, 0.01, Opacity)

    Section(L.tooltipBorderSection)
    Checkbox("tooltipCustomBorder", false)
    AddControl(page, Settings.CreateColorSwatchInitializer(Setting("tooltipBorderColor", Settings.VarType.String, "FFB2B2B2")))
    Slider("tooltipBorderOpacity", 1, 0, 1, 0.01, Opacity)
end)
