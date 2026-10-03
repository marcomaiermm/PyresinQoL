local UI = PyresinQoLUITest
local health, originalHealth, current, maximum
local function HealthText()
    for _, region in ipairs({ GameTooltip.StatusBar:GetRegions() }) do
        if region:IsObjectType("FontString") and region:GetText() == "321 / 654" then return region end
    end
    error("Native tooltip is missing addon health text")
end
local function ShowPlayer()
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetUnit("player")
    GameTooltip:Show()
end

UI.Flow("tooltip health setting updates native text content and bar height", {
    function(_, sidebar, list)
        health = Settings.GetSetting("PyresinQoL_TooltipHealth")
        originalHealth = health:GetValue()
        health:SetValue(true)
        current, maximum = UnitHealth("player"), UnitHealthMax("player")
        A_Admin.SetPlayerHealth(321, 654)
        UI.PageButton(sidebar, "Tooltips"):Click()
        list:ScrollToElementByName(health:GetName())
        ShowPlayer()
    end,
    function(_, _, list)
        -- The pinned simulator does not show the unit-health StatusBar; verify its
        -- addon text and geometry separately from visible tooltip anchoring below.
        assertTrue(GameTooltip:IsVisible())
        assertEquals("321 / 654", HealthText():GetText())
        assertEquals(14, GameTooltip.StatusBar:GetHeight())
        UI.VisibleSetting(list, health).Checkbox:Click()
    end,
    function(_, _, list)
        for _, region in ipairs({ GameTooltip.StatusBar:GetRegions() }) do
            if region:IsObjectType("FontString") then assertTrue(region:GetText() ~= "321 / 654") end
        end
        assertTrue(GameTooltip.StatusBar:GetHeight() < 14)
        UI.VisibleSetting(list, health).Checkbox:Click()
        ShowPlayer()
    end,
    function() assertEquals("321 / 654", HealthText():GetText()); assertEquals(14, GameTooltip.StatusBar:GetHeight()) end,
}, function()
    GameTooltip:Hide()
    if health then health:SetValue(originalHealth) end
    if current then A_Admin.SetPlayerHealth(current, maximum) end
end)

local anchor, dropdown, originalAnchor
UI.Flow("tooltip anchor dropdown positions a visible native tooltip at the configured screen point", {
    function(_, sidebar, list)
        anchor = Settings.GetSetting("PyresinQoL_TooltipAnchor")
        originalAnchor = anchor:GetValue()
        UI.PageButton(sidebar, "Tooltips"):Click()
        list:ScrollToElementByName(anchor:GetName())
    end,
    function(_, _, list)
        dropdown = UI.VisibleSetting(list, anchor).Control.Dropdown
        UI.OpenMenu(dropdown)
    end,
    function() UI.SelectMenu(dropdown, "Fixed screen position") end,
    function()
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnit("player")
        GameTooltip:Show()
    end,
    function()
        assertTrue(GameTooltip:IsVisible())
        assertEquals("ANCHOR_NONE", GameTooltip:GetAnchorType())
        local point, relative, relativePoint, x, y = GameTooltip:GetPoint(1)
        assertEquals("BOTTOMRIGHT", point); assertEquals(UIParent, relative)
        assertEquals("BOTTOMRIGHT", relativePoint); assertEquals(-30, x); assertEquals(120, y)
        UI.AssertInside(GameTooltip, UIParent, "Fixed native tooltip")
    end,
}, function()
    GameTooltip:Hide()
    if anchor then anchor:SetValue(originalAnchor) end
end)
