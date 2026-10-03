local UI = PyresinQoLUITest
local fps, latency, originalFPS, originalLatency
local function Caption(text)
    for _, region in ipairs({ PyresinQoLPerformance:GetRegions() }) do
        if region:IsObjectType("FontString") and region:GetText() == text then return region end
    end
    error("Missing performance caption: " .. text)
end

UI.Flow("performance checkboxes resize live rows and preserve the remaining metric", {
    function(_, sidebar, list)
        fps = Settings.GetSetting("PyresinQoL_ShowFPS")
        latency = Settings.GetSetting("PyresinQoL_ShowLatency")
        originalFPS, originalLatency = fps:GetValue(), latency:GetValue()
        fps:SetValue(true); latency:SetValue(true)
        UI.PageButton(sidebar, "FPS & Latency"):Click()
        list:ScrollToElementByName(fps:GetName())
    end,
    function(_, _, list)
        assertTrue(Caption("FPS:"):IsVisible()); assertTrue(Caption("MS:"):IsVisible())
        assertEquals(35, PyresinQoLPerformance:GetHeight())
        UI.VisibleSetting(list, fps).Checkbox:Click()
    end,
    function(_, _, list)
        assertFalse(Caption("FPS:"):IsVisible()); assertTrue(Caption("MS:"):IsVisible())
        assertEquals(15, PyresinQoLPerformance:GetHeight())
        UI.AssertInside(Caption("MS:"), PyresinQoLPerformance, "Remaining latency row")
        UI.VisibleSetting(list, latency).Checkbox:Click()
    end,
    function(_, _, list)
        assertFalse(PyresinQoLPerformance:IsVisible())
        UI.VisibleSetting(list, fps).Checkbox:Click()
    end,
    function()
        assertTrue(PyresinQoLPerformance:IsVisible())
        UI.AssertInside(PyresinQoLPerformance, UIParent, "Performance display")
        assertTrue(Caption("FPS:"):IsVisible()); assertFalse(Caption("MS:"):IsVisible())
        assertEquals(15, PyresinQoLPerformance:GetHeight())
    end,
}, function()
    if fps then fps:SetValue(originalFPS); latency:SetValue(originalLatency) end
end)
