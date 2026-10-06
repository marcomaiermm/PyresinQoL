local _, ns = ...
local L = ns.L

ns.RegisterModuleSettings("quests", function(module, context)
    local Register, AddControl = context.controls.Register, context.controls.AddControl
    local quests = context.pages.main

    local questLevels = Register(quests, "QuestLevels", "questLevels", Settings.VarType.Boolean,
        L.questLevels, true, module.UpdateQuestLevels)
    AddControl(quests, Settings.CreateCheckboxInitializer(questLevels, nil, L.questLevelsHelp))

    local sparkles = Register(quests, "QuestItemSparkles", "questItemSparkles", Settings.VarType.Boolean,
        L.questItemSparkles, false, module.UpdateQuestSparkles)
    AddControl(quests, Settings.CreateCheckboxInitializer(sparkles, nil, L.questItemSparklesHelp))

    StaticPopupDialogs.PYRESINQOL_QUEST_SPARKLES_RESTART = {
        text = L.questItemSparklesRestart, button1 = OKAY,
        timeout = 0, whileDead = true, hideOnEscape = true,
    }
    function module.MaybePromptQuestSparklesRestart()
        if not module.questSparklesRestartPending or context.canvas:IsShown() then return end
        module.questSparklesRestartPending = nil
        if sparkles:GetValue() ~= true then StaticPopup_Show("PYRESINQOL_QUEST_SPARKLES_RESTART") end
    end
    context.canvas:HookScript("OnHide", module.MaybePromptQuestSparklesRestart)
end)
