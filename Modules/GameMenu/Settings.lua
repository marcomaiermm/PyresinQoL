local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("gameMenu", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local general = context.pages.main

    local cooldown = Register(general, "CooldownShortcut", "cooldownShortcut", Settings.VarType.Boolean,
        L.cooldownOption, true, module.UpdateCooldownButton)
    AddControl(general, Settings.CreateCheckboxInitializer(cooldown, nil, L.cooldownHelp))
end)
