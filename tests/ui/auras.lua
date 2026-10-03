local UI = PyresinQoLUITest
local layout, originalLayout, wrap, gap, originalWidth, originalHeight, originalWrap, originalGap
local function SeededAura(id)
    for _, button in ipairs(BuffFrame.auraFrames or {}) do
        if button.hasValidInfo and button.buttonInfo and button.buttonInfo.auraInstanceID then
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID("player", button.buttonInfo.auraInstanceID)
            if aura and aura.spellId == (id or 990001) then return button end
        end
    end
    error("Seeded buff did not reach native BuffFrame")
end

UI.Flow("buff layout checkbox applies and restores a real native aura button", {
    function(_, sidebar, list)
        layout = Settings.GetSetting("PyresinQoL_buffLayout")
        originalLayout = layout:GetValue()
        layout:SetValue(false)
        wrap, gap = Settings.GetSetting("PyresinQoL_buffWrap"), Settings.GetSetting("PyresinQoL_buffGapY")
        originalWrap, originalGap = wrap:GetValue(), gap:GetValue()
        UI.PageButton(sidebar, "Buffs & Debuffs"):Click()
        list:ScrollToElementByName(layout:GetName())
        A_Admin.AddBuff(990001, "UI layout test", 135987, 60, 1)
        A_Admin.AddBuff(990002, "UI second row", 135987, 60, 1)
    end,
    function(_, _, list)
        local button = SeededAura()
        assertTrue(button:IsVisible())
        originalWidth, originalHeight = button:GetSize()
        UI.VisibleSetting(list, layout).Checkbox:Click()
    end,
    function(_, _, list)
        local button = SeededAura()
        assertEquals(30, button.Icon:GetWidth())
        assertEquals(BuffFrame.AuraContainer, select(2, button:GetPoint(1)))
        UI.AssertInside(button.Icon, button, "Buff icon")
        list:ScrollToElementByName(wrap:GetName())
    end,
    function(_, _, list)
        UI.VisibleSetting(list, wrap).SliderWithSteppers.Slider:SetValue(1)
        list:ScrollToElementByName(gap:GetName())
    end,
    function(_, _, list) UI.VisibleSetting(list, gap).SliderWithSteppers.Slider:SetValue(0) end,
    function(_, _, list)
        local first, second = SeededAura(), SeededAura(990002)
        local _, timerBottom = UI.PhysicalRect(first.Duration)
        local _, _, _, secondTop = UI.PhysicalRect(second.Icon)
        assert(timerBottom >= secondTop - 1,
            ("Aura timer overlaps the next icon: timer bottom %.1f, icon top %.1f"):format(timerBottom, secondTop))
        list:ScrollToElementByName(layout:GetName())
    end,
    function(_, _, list) UI.VisibleSetting(list, layout).Checkbox:Click() end,
    function()
        local button = SeededAura()
        assertEquals(originalWidth, button:GetWidth())
        assertEquals(originalHeight, button:GetHeight())
    end,
}, function()
    if wrap then wrap:SetValue(originalWrap); gap:SetValue(originalGap) end
    if layout then layout:SetValue(originalLayout) end
    A_Admin.RemoveBuff(990001)
    A_Admin.RemoveBuff(990002)
end)

local saved, settings, sortMenu, reused = {}, {}, nil, {}
local function AuraCooldown(button)
    return UI.Find(button, function(f) return f:IsObjectType("Cooldown") end)
end
local function AssertNextSlot(first, second)
    local firstX = UI.PhysicalRect(first)
    local secondX = UI.PhysicalRect(second)
    assert(firstX > secondX, "Ascending remaining time must fill native right-to-left slots")
    local _, _, _, x1, y1 = first:GetPoint(1)
    local _, _, _, x2, y2 = second:GetPoint(1)
    assertAlmostEquals(35, math.abs(x2 - x1))
    assertAlmostEquals(y1, y2)
end

UI.Flow("buff removal compacts sorted slots and reused buttons clear old duration swipes", {
    function(_, sidebar, list)
        saved, settings, reused = {}, {}, {}
        for _, key in ipairs({ "buffLayout", "buffSwipe", "buffSort" }) do
            settings[key] = assert(Settings.GetSetting("PyresinQoL_" .. key))
            saved[key] = settings[key]:GetValue()
        end
        UI.PageButton(sidebar, "Buffs & Debuffs"):Click()
        list:ScrollToElementByName(settings.buffLayout:GetName())
        A_Admin.AddBuff(990011, "UI long aura", 135987, 90, 1)
        A_Admin.AddBuff(990012, "UI short aura", 135987, 30, 2)
        A_Admin.AddBuff(990013, "UI medium aura", 135987, 60, 1)
    end,
    function(_, _, list)
        UI.VisibleSetting(list, settings.buffLayout).Checkbox:Click()
        list:ScrollToElementByName(settings.buffSwipe:GetName())
    end,
    function(_, _, list)
        UI.VisibleSetting(list, settings.buffSwipe).Checkbox:Click()
        list:ScrollToElementByName(settings.buffSort:GetName())
    end,
    function(_, _, list)
        sortMenu = UI.VisibleSetting(list, settings.buffSort).Control.Dropdown
        UI.OpenMenu(sortMenu)
    end,
    function() UI.SelectMenu(sortMenu, "Remaining duration") end,
    function()
        local short, medium, long = SeededAura(990012), SeededAura(990013), SeededAura(990011)
        AssertNextSlot(short, medium); AssertNextSlot(medium, long)
        for _, button in ipairs({ short, medium, long }) do
            reused[button] = true
            local cooldown = assert(AuraCooldown(button))
            assertTrue(cooldown:IsVisible())
            assertTrue(button.Duration:IsVisible())
        end
        assertAlmostEquals(30000, AuraCooldown(short):GetCooldownDuration())
        A_Admin.RemoveBuff(990013)
    end,
    function()
        AssertNextSlot(SeededAura(990012), SeededAura(990011))
        -- Remove the rest before adding replacements: this pinned simulator assigns
        -- instance IDs from list length and otherwise duplicates a surviving ID.
        A_Admin.RemoveBuff(990011)
        A_Admin.RemoveBuff(990012)
        A_Admin.AddBuff(990014, "UI permanent replacement", 135987, 0, 1)
    end,
    function()
        local button = SeededAura(990014)
        assertTrue(reused[button], "The scenario must reuse a native aura button")
        local cooldown = assert(AuraCooldown(button))
        assertFalse(cooldown:IsShown(), "Permanent replacement retained the old timed swipe")
        assertFalse(button.Duration:IsShown(), "Permanent replacement retained the old duration text")
        assertEquals(30, button.Icon:GetWidth())
        A_Admin.RemoveBuff(990014)
        A_Admin.AddBuff(990015, "UI timed replacement", 135987, 45, 3)
    end,
    function()
        local button = SeededAura(990015)
        assertTrue(reused[button])
        assertTrue(AuraCooldown(button):IsVisible())
        assertAlmostEquals(45000, AuraCooldown(button):GetCooldownDuration())
        assertTrue(button.Duration:IsVisible())
        UI.AssertInside(button.Icon, button, "Reused buff icon")
    end,
}, function()
    if sortMenu then sortMenu:CloseMenu() end
    for id = 990011, 990015 do A_Admin.RemoveBuff(id) end
    for key, setting in pairs(settings) do setting:SetValue(saved[key]) end
end)
