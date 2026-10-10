local UI = PyresinQoLUITest
local bar, saved = PyresinQoLFlyoutBar, {}
local keys = { "Orientation", "Rows", "Icons", "Slots", "IconSize", "Padding", "Visibility" }
local function Setting(key) return Settings.GetSetting("PyresinQoL_Flyouts" .. key) end
-- Test code runs tainted, where the secure snippets cannot run; a player's click is secure.
local function Click(button) securecallfunction(button.Click, button) end
local function Shown(frames)
    local count = 0
    for _, frame in ipairs(frames) do if frame:IsShown() then count = count + 1 end end
    return count
end

UI.Flow("flyout bar lays out like an action bar and opens one menu at a time", {
    function()
        for _, key in ipairs(keys) do saved[key] = Setting(key):GetValue() end
        Setting("Icons"):SetValue(6)
        Setting("Rows"):SetValue(2)
        Setting("Slots"):SetValue(4)
        Setting("Orientation"):SetValue("horizontal")
        Setting("IconSize"):SetValue(100)
        Setting("Padding"):SetValue(2)
    end,
    function()
        local first, fourth = PyresinQoLFlyoutButton1, PyresinQoLFlyoutButton4
        assertTrue(first:IsVisible() and PyresinQoLFlyoutButton6:IsShown())
        assertTrue(not PyresinQoLFlyoutButton7 or not PyresinQoLFlyoutButton7:IsShown(), "Six icons")
        -- Two rows of three: the fourth starts the second row.
        assertTrue(math.abs(fourth:GetLeft() - first:GetLeft()) < 0.5 and fourth:GetTop() < first:GetBottom())
        assertTrue(math.abs(bar:GetWidth() - (3 * 45 + 2 * 2)) < 0.5 and math.abs(bar:GetHeight() - (2 * 45 + 2)) < 0.5)
        UI.AssertInside(bar, UIParent, "Flyout bar")

        Click(first)
        assertTrue(first.popup:IsShown() and first:IsPopupOpen(), "A click opens the menu")
        assertEquals(4, Shown(first.slots), "Icons per menu")
        assertFalse(first:GetChecked())
        Click(PyresinQoLFlyoutButton2)
        assertFalse(first.popup:IsShown(), "Opening another menu closes the first")
        assertTrue(PyresinQoLFlyoutButton2.popup:IsShown())
        Click(PyresinQoLFlyoutButton2)
        assertFalse(PyresinQoLFlyoutButton2.popup:IsShown(), "A second click closes it")
        Click(fourth)
        if fourth:GetPopupDirection() == "UP" then
            assertEquals(0, first:GetAlpha(), "An open menu fades out the button it covers")
            assertEquals(1, PyresinQoLFlyoutButton2:GetAlpha())
        end
        Click(fourth)
        assertEquals(1, first:GetAlpha(), "Closing the menu brings it back")

        -- A right-click edits the menu's name and icon instead of opening it.
        saved.menu = PyresinQoLFlyouts[1]
        PyresinQoLFlyouts[1] = nil
        securecallfunction(first.Click, first, "RightButton")
        local picker = assert(PyresinQoLFlyoutIconPicker, "A right-click opens the icon picker")
        assertTrue(picker:IsShown() and not first.popup:IsShown())
        UI.AssertInside(picker, UIParent, "Flyout icon picker")
        picker.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(136243)
        picker.BorderBox.IconSelectorEditBox:SetText("Portals")
        picker:OkayButton_OnClick()
        assertFalse(picker:IsShown())
        assertEquals(136243, first.icon:GetTexture(), "The chosen icon replaces the first entry's")
        assertEquals("Portals", PyresinQoLFlyouts[1].name)
        securecallfunction(first.Click, first, "RightButton")
        picker.BorderBox.IconSelectorEditBox:SetText("  ")
        picker:OkayButton_OnClick()
        assertEquals(nil, PyresinQoLFlyouts[1].name, "A blank name falls back to the default")
        PyresinQoLFlyouts[1] = saved.menu

        ActionButtonUtil.SetAllQuickKeybindButtonHighlights(true)
        assertTrue(first.QuickKeybindHighlightTexture:IsShown(), "Quick Keybind Mode highlights the buttons")
        assertEquals("CLICK PyresinQoLFlyoutButton1:LeftButton", first.commandName)
        ActionButtonUtil.SetAllQuickKeybindButtonHighlights(false)
        assertFalse(first.QuickKeybindHighlightTexture:IsShown())

        Click(first)
        Click(first.slots[1])
        assertFalse(first.popup:IsShown(), "Using a menu button closes the menu")

        Setting("Slots"):SetValue(7)
        Setting("Orientation"):SetValue("vertical")
        Setting("IconSize"):SetValue(200)
        Click(first)
        assertEquals(7, Shown(first.slots))
        local direction = first:GetPopupDirection()
        assertTrue(direction == "LEFT" or direction == "RIGHT", "A vertical bar opens sideways")
        assertTrue(math.abs(bar:GetWidth() - 2 * (2 * 45 + 2)) < 0.5, "The bar grows with the icon size")
        Click(first)
    end,
}, function()
    PyresinQoLFlyouts[1] = saved.menu
    for _, key in ipairs(keys) do Setting(key):SetValue(saved[key]) end
end)

UI.Flow("a click with something on the cursor drops it instead of acting", {
    function()
        for _, key in ipairs(keys) do saved[key] = Setting(key):GetValue() end
        saved.entries, saved.GetCursorInfo, saved.PlayerHasToy = PyresinQoLFlyouts[1], GetCursorInfo, PlayerHasToy
        PyresinQoLFlyouts[1] = nil
        Setting("Icons"):SetValue(6)
        Setting("Slots"):SetValue(4)
        local cursor = { "item", 6948 }
        GetCursorInfo = function() return unpack(cursor) end
        PlayerHasToy = function(id) return id == 54452 end
        Click(PyresinQoLFlyoutButton1)
        assertFalse(PyresinQoLFlyoutButton1.popup:IsShown(), "Dropping does not open the menu")
        assertEquals("item", PyresinQoLFlyouts[1][1].type)
        cursor[2] = 54452
        Click(PyresinQoLFlyoutButton1)
        assertEquals("toy", PyresinQoLFlyouts[1][2].type, "Toys are kept as toys")
        assertEquals(54452, PyresinQoLFlyoutButton1.slots[2]:GetAttribute("toy"))
        assertEquals("toy", PyresinQoLFlyoutButton1.slots[2]:GetAttribute("type"))
        GetCursorInfo = saved.GetCursorInfo
        Click(PyresinQoLFlyoutButton1)
        assertTrue(PyresinQoLFlyoutButton1.popup:IsShown(), "An empty cursor opens the menu again")
        Click(PyresinQoLFlyoutButton1)
    end,
}, function()
    GetCursorInfo, PlayerHasToy = saved.GetCursorInfo, saved.PlayerHasToy
    PyresinQoLFlyouts[1] = saved.entries
    for _, key in ipairs(keys) do Setting(key):SetValue(saved[key]) end
end)

UI.Flow("flyout bar options open from Edit Mode", {
    function()
        saved.Visibility = Setting("Visibility"):GetValue()
        Setting("Visibility"):SetValue("hidden")
    end,
    function()
        assertFalse(bar:IsShown(), "A hidden bar stays hidden")
        ShowUIPanel(EditModeManagerFrame)
    end,
    function()
        assertTrue(bar.Selection:IsShown(), "Edit Mode shows the bar's mover")
        bar.Selection:GetScript("OnMouseDown")(bar.Selection)
    end,
    function()
        local dialog = assert(bar.Dialog, "Selecting the bar opens its options")
        assertTrue(dialog:IsVisible())
        UI.AssertInside(dialog, UIParent, "Flyout bar options")
        HideUIPanel(EditModeManagerFrame)
    end,
    function()
        assertFalse(bar.Dialog:IsShown(), "Leaving Edit Mode closes the options")
        assertFalse(bar:IsShown(), "Leaving Edit Mode hides the hidden bar again")
        Setting("Visibility"):SetValue("outOfCombat")
    end,
    function()
        assertTrue(bar:IsShown(), "Out of combat shows the bar")
    end,
}, function()
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
    Setting("Visibility"):SetValue(saved.Visibility)
end)
