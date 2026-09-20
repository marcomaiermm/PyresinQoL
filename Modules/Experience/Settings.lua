local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("experience", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local experience = context.pages.main

    local xpFormat = Register(experience, "XPTextFormat", "xpTextFormat", Settings.VarType.String,
        L.xpTextFormat, "both", module.UpdateExperience)
    AddControl(experience, Settings.CreateDropdownInitializer(xpFormat, function()
        local options = Settings.CreateControlTextContainer()
        options:Add("blizzard", L.xpBlizzard)
        options:Add("value", "X / X")
        options:Add("both", "X / X (N%)")
        options:Add("percent", "N%")
        return options:GetData()
    end))
    local xpAlways = Register(experience, "XPAlwaysShow", "xpAlwaysShow", Settings.VarType.Boolean,
        L.xpAlwaysShow, true, module.UpdateExperience)
    AddControl(experience, Settings.CreateCheckboxInitializer(xpAlways, nil, L.xpAlwaysHelp))
    local xpTooltip = Register(experience, "XPTooltip", "xpTooltip", Settings.VarType.Boolean,
        L.xpTooltip, true, module.UpdateExperience)
    AddControl(experience, Settings.CreateCheckboxInitializer(xpTooltip, nil, L.xpTooltipHelp))
    local xpQuests = Register(experience, "XPQuestRewards", "xpQuestRewards", Settings.VarType.Boolean,
        L.xpQuestRewards, true, module.UpdateExperience)
    AddControl(experience, Settings.CreateCheckboxInitializer(xpQuests, nil, L.xpQuestHelp))
end)
