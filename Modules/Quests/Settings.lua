local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("quests", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local quests = context.pages.main

    local questLevels = Register(quests, "QuestLevels", "questLevels", Settings.VarType.Boolean,
        L.questLevels, true, module.UpdateQuestLevels)
    AddControl(quests, Settings.CreateCheckboxInitializer(questLevels, nil, L.questLevelsHelp))
end)
