local UI = PyresinQoLUITest
local levels, originalLevels, row
local info = { questID = 80002, questLevel = 80, title = "A native UI quest", frequency = 0 }

UI.Flow("quest-level checkbox controls decoration when native gossip rows are reused", {
    function(_, sidebar, list)
        levels = Settings.GetSetting("PyresinQoL_QuestLevels")
        originalLevels = levels:GetValue()
        levels:SetValue(true)
        UI.PageButton(sidebar, "Quests"):Click()
        list:ScrollToElementByName(levels:GetName())
        -- The pinned simulator cannot open GossipFrame's UIThemeContainerFrame.
        -- Use its real pooled-row template and Setup method with public quest data.
        row = CreateFrame("Button", nil, UIParent, "GossipTitleAvailableQuestButtonTemplate")
        row:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 40)
        row:Setup(info)
    end,
    function(_, _, list)
        assertTrue(row.PyresinQuestLevel:IsVisible())
        assertTrue(row.PyresinQuestLevel:GetText():find("[80]", 1, true) ~= nil)
        UI.VisibleSetting(list, levels).Checkbox:Click()
    end,
    function(_, _, list)
        row:Setup(info)
        assertFalse(row.PyresinQuestLevel:IsShown())
        assertNil(row.PyresinQuestTitleLayout)
        UI.VisibleSetting(list, levels).Checkbox:Click()
    end,
    function()
        row:Setup(info)
        assertTrue(row.PyresinQuestLevel:IsVisible())
        assertNotNil(row.PyresinQuestTitleLayout)
        assertFalse(row:GetText():find("[80]", 1, true) ~= nil)
        UI.AssertInside(row.PyresinQuestLevel, row, "Quest level prefix")
    end,
}, function()
    if row then row:Hide() end
    if levels then levels:SetValue(originalLevels) end
end)
