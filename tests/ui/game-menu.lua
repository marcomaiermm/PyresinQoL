local UI = PyresinQoLUITest
local setting, originalSetting, shortcut, nativeHeight
local function Shortcut()
    for _, frame in ipairs({ UIParent:GetChildren() }) do
        if frame:IsObjectType("Button") and frame:GetText() == "Cooldown Settings" then return frame end
    end
    error("Missing cooldown shortcut")
end

UI.Flow("game-menu checkbox reserves exactly one shortcut row and restores native layout", {
    function(_, sidebar, list)
        setting = Settings.GetSetting("PyresinQoL_CooldownShortcut")
        originalSetting = setting:GetValue()
        setting:SetValue(true)
        UI.PageButton(sidebar, "Game Menu"):Click()
        list:ScrollToElementByName(setting:GetName())
    end,
    function(_, _, list) UI.VisibleSetting(list, setting).Checkbox:Click() end,
    function() ShowUIPanel(GameMenuFrame) end,
    function(canvas)
        nativeHeight = GameMenuFrame:GetHeight()
        shortcut = Shortcut()
        assertFalse(shortcut:IsShown())
        HideUIPanel(GameMenuFrame)
        canvas:Show()
    end,
    function(_, _, list) UI.VisibleSetting(list, setting).Checkbox:Click() end,
    function() ShowUIPanel(GameMenuFrame) end,
    function()
        assertTrue(shortcut:IsVisible())
        assertEquals(UIParent, shortcut:GetParent())
        assertEquals(nativeHeight + shortcut:GetHeight() + (GameMenuFrame.spacing or 0), GameMenuFrame:GetHeight())
        UI.AssertInside(shortcut, GameMenuFrame, "Cooldown shortcut")
        HideUIPanel(GameMenuFrame)
    end,
    function()
        assertFalse(GameMenuFrame:IsShown())
        assertFalse(shortcut:IsShown())
        assertEquals(nativeHeight, GameMenuFrame:GetHeight())
    end,
}, function()
    HideUIPanel(GameMenuFrame)
    HideUIPanel(CooldownViewerSettings)
    if setting then setting:SetValue(originalSetting) end
end)
