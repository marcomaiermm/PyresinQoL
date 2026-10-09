local UI = PyresinQoLUITest
local bar, saved = PyresinQoLFlyoutBar, {}
local keys = { "Orientation", "Rows", "Icons", "Slots", "IconSize", "Padding" }
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
    for key, value in pairs(saved) do Setting(key):SetValue(value) end
end)

UI.Flow("flyout bar options open from Edit Mode", {
    function() ShowUIPanel(EditModeManagerFrame) end,
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
    end,
}, function()
    if EditModeManagerFrame:IsShown() then HideUIPanel(EditModeManagerFrame) end
end)
