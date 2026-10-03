local UI = PyresinQoLUITest

local color, savedColor, originalColor, originalDesaturation
UI.Flow("player class-color checkbox changes and restores the native health bar", {
    function(_, sidebar, list)
        color = Settings.GetSetting("PyresinQoL_playerClassColor")
        savedColor = color:GetValue()
        color:SetValue(false)
        originalColor = { PlayerFrame.healthbar:GetStatusBarColor() }
        originalDesaturation = PlayerFrame.healthbar:GetStatusBarTexture():GetDesaturation()
        UI.PageButton(sidebar, "Player Frame"):Click()
        list:ScrollToElementByName(color:GetName())
    end,
    function(_, _, list) UI.VisibleSetting(list, color).Checkbox:Click() end,
    function(_, _, list)
        local _, class = UnitClass("player")
        local expected = RAID_CLASS_COLORS[class]
        local r, g, b = PlayerFrame.healthbar:GetStatusBarColor()
        assertTrue(math.abs(expected.r - r) < 0.00001)
        assertTrue(math.abs(expected.g - g) < 0.00001)
        assertTrue(math.abs(expected.b - b) < 0.00001)
        assertEquals(1, PlayerFrame.healthbar:GetStatusBarTexture():GetDesaturation())
        UI.VisibleSetting(list, color).Checkbox:Click()
    end,
    function()
        local r, g, b = PlayerFrame.healthbar:GetStatusBarColor()
        assertEquals(originalColor[1], r); assertEquals(originalColor[2], g); assertEquals(originalColor[3], b)
        assertEquals(originalDesaturation, PlayerFrame.healthbar:GetStatusBarTexture():GetDesaturation())
    end,
}, function() if color then color:SetValue(savedColor) end end)

local hidden, savedHidden, originalAlpha, previousTarget, previousHealth, previousMaximum
UI.Flow("target status-text checkbox hides and restores native text", {
    function(_, sidebar, list)
        hidden = Settings.GetSetting("PyresinQoL_targetHideStatusText")
        savedHidden = hidden:GetValue()
        hidden:SetValue(false)
        if UnitExists("target") then
            previousTarget = { UnitName("target"), UnitLevel("target"), select(3, UnitClass("target")), UnitCanAttack("player", "target") }
            previousHealth, previousMaximum = UnitHealth("target"), UnitHealthMax("target")
        end
        A_Admin.SetTarget("Status text UI enemy", 80, 1, true)
        A_Admin.SetTargetHealth(100, 100)
        A_Admin.FireEvent("PLAYER_TARGET_CHANGED")
        originalAlpha = TargetFrame.healthbar.TextString:GetAlpha()
        UI.PageButton(sidebar, "Status Text"):Click()
        list:ScrollToElementByName(hidden:GetName())
    end,
    function(_, _, list) UI.VisibleSetting(list, hidden).Checkbox:Click() end,
    function(_, _, list)
        assertTrue(TargetFrame:IsVisible())
        assertEquals(0, TargetFrame.healthbar.TextString:GetAlpha())
        assertEquals(0, TargetFrame.manabar.TextString:GetAlpha())
        UI.VisibleSetting(list, hidden).Checkbox:Click()
    end,
    function() assertEquals(originalAlpha, TargetFrame.healthbar.TextString:GetAlpha()) end,
}, function()
    if hidden then hidden:SetValue(savedHidden) end
    if previousTarget then
        A_Admin.SetTarget(unpack(previousTarget))
        A_Admin.SetTargetHealth(previousHealth, previousMaximum)
    else A_Admin.ClearTarget() end
    A_Admin.FireEvent("PLAYER_TARGET_CHANGED")
end)
