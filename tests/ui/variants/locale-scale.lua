-- Dedicated lane: addon deDE was selected before its Lua loaded; pinned native
-- Blizzard strings remain enUS. Never run the English scenario matrix here.
local UI = PyresinQoLUITest
local originalStore, originalEnabled, originalRawEnabled, selector, popup
local longName = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"

test("German addon locale and nondefault UI scale were initialized before scenarios", function()
    assertEquals("deDE", GetLocale())
    assertEquals("enUS", PyresinQoLUITestNativeLocale)
    assertAlmostEquals(1.25, UIParent:GetScale())
    assertEquals("Zauberleiste anpassen", Settings.GetSetting("PyresinQoL_CastBarCustomization"):GetName())
end)

UI.Flow("German settings at enlarged scale retain layout and controls across reopen", {
    function(canvas, sidebar, list)
        originalStore = CopyTable(PyresinQoLDB.profileStore)
        originalEnabled = Settings.GetSetting("PyresinQoL_CastBarCustomization"):GetValue()
        originalRawEnabled = PyresinQoLDB.castBarCustomization
        UI.AssertInside(canvas, UIParent, "Deutsches Einstellungsfenster")
        UI.AssertInside(sidebar, canvas, "Deutsche Navigation")
        UI.PageButton(sidebar, "Spielerrahmen"):Click()
        list:ScrollToElementByName("Zauberleiste anpassen")
    end,
    function(_, _, list)
        local row = UI.VisibleSetting(list, Settings.GetSetting("PyresinQoL_CastBarCustomization"))
        assertEquals("Zauberleiste anpassen", row.Text:GetText())
        UI.AssertInside(row.Text, row, "Deutsche Einstellungsbeschriftung")
        UI.Click(row.Checkbox, list.ScrollBox, "Zauberleiste anpassen")
    end,
    function(canvas)
        assertTrue(PyresinQoLDB.castBarCustomization)
        UI.Click(canvas.ClosePanelButton, UIParent, "Fenster schließen")
    end,
    function(canvas) assertFalse(canvas:IsShown()); SlashCmdList.PQOL() end,
    function(canvas, sidebar, list)
        UI.AssertInside(canvas, UIParent, "Wieder geöffnetes Fenster")
        assertTrue(UI.VisibleSetting(list, Settings.GetSetting("PyresinQoL_CastBarCustomization")).Checkbox:GetChecked())
        UI.PageButton(sidebar, "Profiles"):Click()
    end,
    function(_, _, list)
        assertFalse(list.Header.DefaultsButton:IsShown())
        UI.Click(UI.Button(list, "Erstellen"), list, "Profil erstellen")
    end,
    function()
        popup = assert(StaticPopup_FindVisible("PYRESINQOL_PROFILE_NAME"))
        assertContains(popup:GetTextFontString():GetText(), "Neues Addon-Profil")
        UI.AssertInside(popup, UIParent, "Deutscher Profildialog")
        popup:GetEditBox():SetText(longName)
        UI.Click(popup:GetButton1(), popup, "Langen Profilnamen übernehmen")
    end,
    function(_, _, list)
        assertEquals(longName, PyresinQoLDB.profileStore.active)
        selector = assert(UI.Find(list, function(f)
            return f:IsVisible() and f.SetupMenu and f:GetText() == longName
        end))
        UI.AssertInside(selector, list, "Profilwahl mit langem Namen")
        UI.AssertInside(selector.Text, selector, "Langer Profilname")
        UI.OpenMenu(selector)
    end,
    function()
        UI.AssertInside(UI.MenuItem(selector, longName), UIParent, "Langer Profilname im Menü")
        selector:CloseMenu()
    end,
}, function()
    if selector then selector:CloseMenu() end
    StaticPopup_Hide("PYRESINQOL_PROFILE_NAME")
    if originalStore then PyresinQoLDB.profileStore = originalStore; EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged") end
    if originalEnabled ~= nil then Settings.GetSetting("PyresinQoL_CastBarCustomization"):SetValue(originalEnabled) end
    PyresinQoLDB.castBarCustomization = originalRawEnabled
end)

UI.Flow("German settings search finds localized labels and help at enlarged scale", {
    function(canvas, sidebar, list)
        UI.PageButton(sidebar, "Spielerrahmen"):Click()
        UI.AssertInside(canvas.SearchBox, canvas, "Deutsches Suchfeld")
        canvas.SearchBox:SetText("FuNkElN")
        list:ScrollToElementByName("Questgegenstände funkeln lassen")
    end,
    function(canvas, _, list)
        local row = UI.VisibleSetting(list, Settings.GetSetting("PyresinQoL_QuestItemSparkles"))
        assertEquals("Questgegenstände funkeln lassen", row.Text:GetText())
        UI.AssertInside(row.Text, row, "Deutscher Suchtreffer")
        assertFalse(list.Header.DefaultsButton:IsShown())
        canvas.SearchBox:SetText("spielneustart")
        list:ScrollToElementByName("Questgegenstände funkeln lassen")
    end,
    function(canvas, _, list)
        assertTrue(UI.VisibleSetting(list, Settings.GetSetting("PyresinQoL_QuestItemSparkles")).Checkbox:IsEnabled())
        UI.Click(canvas.SearchBox.clearButton, canvas, "Suche leeren")
    end,
    function(canvas, _, list)
        assertEquals("Spielerrahmen", list.Header.Title:GetText())
        canvas.SearchBox:SetText("bedrohung")
        list:ScrollToElementByName(Settings.GetSetting("PyresinQoL_NameplateThreat"):GetName())
    end,
    function(_, _, list)
        assertTrue(UI.VisibleSetting(list, Settings.GetSetting("PyresinQoL_NameplateThreat")).Checkbox:IsEnabled())
    end,
})

local sparkleSetting, originalSparkles
UI.Flow("German quest-sparkle checkbox and post-close restart dialog fit at enlarged scale", {
    function(_, sidebar, list)
        sparkleSetting = Settings.GetSetting("PyresinQoL_QuestItemSparkles")
        originalSparkles = sparkleSetting:GetValue()
        sparkleSetting:SetValue(true)
        UI.PageButton(sidebar, "Quests"):Click()
        list:ScrollToElementByName(sparkleSetting:GetName())
    end,
    function(_, _, list)
        local row = UI.VisibleSetting(list, sparkleSetting)
        assertEquals("Questgegenstände funkeln lassen", row.Text:GetText())
        UI.AssertInside(row.Text, row, "Deutsche Funkeln-Beschriftung")
        UI.Click(row.Checkbox, list.ScrollBox, "Funkeln ausschalten")
    end,
    function(_, _, list)
        assertFalse(PyresinQoLDB.questItemSparkles)
        assertNil(StaticPopup_FindVisible("PYRESINQOL_QUEST_SPARKLES_RESTART"))
        UI.Click(list.Header.DefaultsButton, list.Header, "Quest-Standardwerte")
    end,
    function(canvas, _, list)
        assertFalse(PyresinQoLDB.questItemSparkles)
        assertFalse(UI.VisibleSetting(list, sparkleSetting).Checkbox:GetChecked())
        UI.Click(canvas.ClosePanelButton, UIParent, "Quest-Einstellungen schließen")
    end,
    function(canvas)
        assertFalse(canvas:IsShown())
        local popup = assert(StaticPopup_FindVisible("PYRESINQOL_QUEST_SPARKLES_RESTART"))
        -- The pinned popup formatter corrupts UTF-8 umlauts; validate the source
        -- translation and the rendered ASCII instruction separately (SIM-010).
        assertContains(StaticPopupDialogs.PYRESINQOL_QUEST_SPARKLES_RESTART.text, "vollständig neu")
        assertContains(popup:GetTextFontString():GetText(), "Starte das Spiel")
        assertContains(popup:GetTextFontString():GetText(), "/reload")
        UI.AssertInside(popup, UIParent, "Deutscher Neustart-Dialog")
        UI.AssertInside(popup:GetTextFontString(), popup, "Deutscher Neustart-Hinweis")
        UI.Click(popup:GetButton1(), popup, "Neustart-Hinweis bestätigen")
    end,
}, function()
    if sparkleSetting then sparkleSetting:SetValue(originalSparkles) end
    PyresinQoLSettingsFrame:Hide()
    StaticPopup_Hide("PYRESINQOL_QUEST_SPARKLES_RESTART")
end)

local enable, panel, original
UI.Flow("German cast-bar labels and scrolled controls fit at enlarged scale", {
    function(_, sidebar, list)
        original = PyresinQoLDB.castBarCustomization
        UI.PageButton(sidebar, "Spielerrahmen"):Click()
        list:ScrollToElementByName("Im Bearbeitungsmodus konfigurieren")
    end,
    function(_, _, list)
        UI.Click(UI.Button(list, "Im Bearbeitungsmodus konfigurieren"), list.ScrollBox, "Deutscher Editor-Aufruf")
    end,
    function()
        local row
        enable, row = UI.Checkbox(EditModeSystemSettingsDialog, "Zauberleiste anpassen")
        panel = row:GetParent()
        if not enable:GetChecked() then UI.Click(enable, panel, "Zauberleiste aktivieren") end
        UI.Click(UI.Button(panel, "Aussehen"), panel, "Aussehen-Reiter")
    end,
    function()
        UI.AssertInside(EditModeSystemSettingsDialog, UIParent, "Skalierter deutscher Zauberleistendialog")
        local scroll = assert(UI.Find(panel, function(f) return f:IsObjectType("ScrollFrame") end))
        scroll.ScrollBar:SetValue(math.max(0, scroll:GetScrollChild():GetHeight() - scroll:GetHeight()))
    end,
    function()
        UI.AssertInside(UI.Button(panel, "Zauberleisten-Anpassungen zurücksetzen"), panel, "Langer Zurücksetzen-Button")
        UI.Click(UI.Button(panel, "Details"), panel, "Details-Reiter")
    end,
    function()
        UI.AssertInside(EditModeSystemSettingsDialog, UIParent, "Deutscher Detailsdialog")
        local checkbox, row = UI.Checkbox(panel, "Zaubername anzeigen")
        UI.AssertInside(row.Label, row, "Deutsche Optionsbeschriftung")
        assertTrue(checkbox:IsEnabled())
    end,
}, function()
    if enable and enable:GetChecked() ~= (original == true) then enable:Click() end
    PyresinQoLDB.castBarCustomization = original
    HideUIPanel(EditModeManagerFrame)
end)
