local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("tooltips", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local tooltips = context.pages.main

    local tooltipHealth = Register(tooltips, "TooltipHealth", "tooltipHealth", Settings.VarType.Boolean,
        L.tooltipHealth, true, module.UpdateTooltips)
    AddControl(tooltips, Settings.CreateCheckboxInitializer(tooltipHealth, nil, L.tooltipHealthHelp))
    local tooltipGuildRank = Register(tooltips, "TooltipGuildRank", "tooltipGuildRank", Settings.VarType.Boolean,
        L.tooltipGuildRank, true, module.UpdateTooltips)
    AddControl(tooltips, Settings.CreateCheckboxInitializer(tooltipGuildRank, nil, L.tooltipGuildRankHelp))
    local tooltipObjectCursor = Register(tooltips, "TooltipObjectCursor", "tooltipObjectCursor", Settings.VarType.Boolean,
        L.tooltipObjectCursor, true, module.UpdateTooltips)
    AddControl(tooltips, Settings.CreateCheckboxInitializer(tooltipObjectCursor, nil, L.tooltipObjectCursorHelp))
end)
