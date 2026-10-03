local UI = PyresinQoLUITest
local always, format, dropdown, originalAlways, originalFormat
local function Bars()
    local result = {}
    for _, container in ipairs(StatusTrackingBarManager.barContainers) do
        result[#result + 1] = container.bars[StatusTrackingBarInfo.BarsEnum.Experience]
    end
    assertEquals(2, #result)
    return result
end

UI.Flow("experience checkbox and format dropdown update both native text layers", {
    function(_, sidebar, list)
        always = Settings.GetSetting("PyresinQoL_XPAlwaysShow")
        format = Settings.GetSetting("PyresinQoL_XPTextFormat")
        originalAlways, originalFormat = always:GetValue(), format:GetValue()
        always:SetValue(true); format:SetValue("both")
        UI.PageButton(sidebar, "Experience Bar"):Click()
        list:ScrollToElementByName(always:GetName())
    end,
    function(_, _, list)
        for _, bar in ipairs(Bars()) do
            local current, maximum = bar:GetLevelData()
            assertTrue(maximum > 0)
            local expected = FormatLargeNumber(current) .. " / " .. FormatLargeNumber(maximum)
                .. (" (%.1f%%)"):format(current / maximum * 100)
            assertEquals(expected, bar.OverlayFrame.Text:GetText())
            assertTrue(bar.OverlayFrame.Text:IsShown())
        end
        UI.VisibleSetting(list, always).Checkbox:Click()
    end,
    function(_, _, list)
        for _, bar in ipairs(Bars()) do assertFalse(bar.OverlayFrame.Text:IsShown()) end
        UI.VisibleSetting(list, always).Checkbox:Click()
        list:ScrollToElementByName(format:GetName())
    end,
    function(_, _, list)
        dropdown = UI.VisibleSetting(list, format).Control.Dropdown
        UI.OpenMenu(dropdown)
    end,
    function() UI.SelectMenu(dropdown, "N%") end,
    function()
        for _, bar in ipairs(Bars()) do
            assertTrue(bar.OverlayFrame.Text:IsShown())
            local current, maximum = bar:GetLevelData()
            assertEquals(("%.1f%%"):format(current / maximum * 100), bar.OverlayFrame.Text:GetText())
        end
    end,
}, function()
    if always then always:SetValue(originalAlways); format:SetValue(originalFormat) end
end)
