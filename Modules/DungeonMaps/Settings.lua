local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("dungeonMaps", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local page = context.pages.main
    local enabled = Register(page, "DungeonMapsEnabled", "dungeonMapsEnabled", Settings.VarType.Boolean,
        L.dungeonMapsEnabled, true, module.UpdateDungeonMaps)
    AddControl(page, Settings.CreateCheckboxInitializer(enabled, nil, L.dungeonMapsEnabledHelp))
end)
