local UI = PyresinQoLUITest
local setting, original
local dialog = "PYRESINQOL_QUEST_SPARKLES_RESTART"
local names = { "outlineModeShowLootEffectWhenDisabled", "graphicsOutlineMode", "OutlineEngineMode",
    "raidGraphicsOutlineMode", "RAIDOutlineEngineMode" }
local originalCVars = {}
local function CheckCVars(enabled)
    for index, name in ipairs(names) do
        assertEquals(index == 1 and (enabled and "1" or "0") or (enabled and "0" or "2"), C_CVar.GetCVar(name))
    end
end

UI.Flow("quest sparkles: opt-in, canceled reminder and restart dialog only after closing settings", {
    function(_, sidebar, list)
        setting = assert(Settings.GetSetting("PyresinQoL_QuestItemSparkles"))
        original = setting:GetValue()
        assertFalse(original)
        for _, name in ipairs(names) do originalCVars[name] = C_CVar.GetCVar(name) end
        setting:SetValue(true)
        UI.PageButton(sidebar, "Quests"):Click()
        list:ScrollToElementByName(setting:GetName())
    end,
    function(_, _, list)
        CheckCVars(true)
        assertTrue(UI.VisibleSetting(list, setting).Checkbox:GetChecked())
        assertNil(StaticPopup_FindVisible(dialog))
        UI.Click(UI.VisibleSetting(list, setting).Checkbox, list.ScrollBox, "Disable quest sparkles")
    end,
    function(_, _, list)
        assertFalse(PyresinQoLDB.questItemSparkles)
        CheckCVars(false)
        assertFalse(UI.VisibleSetting(list, setting).Checkbox:GetChecked())
        assertNil(StaticPopup_FindVisible(dialog), "Do not interrupt the open settings menu")
        UI.Click(UI.VisibleSetting(list, setting).Checkbox, list.ScrollBox, "Enable quest sparkles")
    end,
    function(canvas)
        CheckCVars(true)
        UI.Click(canvas.ClosePanelButton, UIParent, "Close after re-enabling")
    end,
    function()
        assertNil(StaticPopup_FindVisible(dialog), "Re-enabling cancels the restart reminder")
        SlashCmdList.PQOL()
    end,
    function(_, _, list)
        UI.Click(list.Header.DefaultsButton, list.Header, "Restore opt-in quest defaults")
    end,
    function(canvas, _, list)
        assertFalse(PyresinQoLDB.questItemSparkles)
        assertFalse(UI.VisibleSetting(list, setting).Checkbox:GetChecked())
        CheckCVars(false)
        assertNil(StaticPopup_FindVisible(dialog))
        UI.Click(canvas.ClosePanelButton, UIParent, "Close after disabling sparkles")
    end,
    function(canvas)
        assertFalse(canvas:IsShown())
        local popup = assert(StaticPopup_FindVisible(dialog), "Missing restart dialog after closing settings")
        assertContains(popup:GetTextFontString():GetText(), "Fully restart the game")
        assertContains(popup:GetTextFontString():GetText(), "/reload")
        UI.AssertInside(popup, UIParent, "Sparkles restart dialog")
        UI.AssertInside(popup:GetTextFontString(), popup, "Sparkles restart text")
        UI.Click(popup:GetButton1(), popup, "Acknowledge restart reminder")
        setting:NotifyUpdate()
        SlashCmdList.PQOL()
    end,
    function(canvas)
        UI.Click(canvas.ClosePanelButton, UIParent, "Close already-disabled settings")
    end,
    function()
        assertNil(StaticPopup_FindVisible(dialog), "A completed reset must not prompt again")
    end,
}, function()
    if setting then setting:SetValue(original) end
    PyresinQoLSettingsFrame:Hide()
    StaticPopup_Hide(dialog)
    for name, value in pairs(originalCVars) do C_CVar.SetCVar(name, value) end
end)
