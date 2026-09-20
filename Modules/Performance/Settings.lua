local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("performance", function(module, context)
    local Register, AddControl, Choices = context.controls.Register, context.controls.AddControl, context.controls.Choices
    local misc = context.pages.main

    local fps = Register(misc, "ShowFPS", "showFPS", Settings.VarType.Boolean, L.showFPS, true, module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateCheckboxInitializer(fps, nil, L.moveHelp))
    local latency = Register(misc, "ShowLatency", "showLatency", Settings.VarType.Boolean, L.showLatency, true, module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateCheckboxInitializer(latency, nil, L.moveHelp))
    local layout = Register(misc, "PerformanceLayout", "performanceLayout", Settings.VarType.String, L.layout, "column", module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateDropdownInitializer(layout, Choices("column", L.column, "row", L.row)))
    local padding = Settings.CreateSliderOptions(0, 40, 1)
    padding:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return ("%.0f px"):format(value) end)
    local rowPadding = Register(misc, "PerformanceRowPadding", "performanceRowPadding", Settings.VarType.Number, L.rowPadding, 14, module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateSliderInitializer(rowPadding, padding))
    local columnPadding = Register(misc, "PerformanceColumnPadding", "performanceColumnPadding", Settings.VarType.Number, L.columnPadding, 5, module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateSliderInitializer(columnPadding, padding))
    local order = Register(misc, "PerformanceOrder", "performanceOrder", Settings.VarType.String, L.order, "fps", module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateDropdownInitializer(order, Choices("fps", L.fpsFirst, "latency", L.latencyFirst)))
    local color = Register(misc, "PerformanceColor", "performanceColor", Settings.VarType.String, L.color, "FFFFFFFF", module.UpdatePerformanceLayout)
    AddControl(misc, Settings.CreateColorSwatchInitializer(color))
end)
