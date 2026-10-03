local UI = PyresinQoLUITest
local panel, enable, scroll, content, preview, dropdown
local original, originalEnabled, nativeWidth, nativeHeight
local function Parts()
    local row
    enable, row = UI.Checkbox(EditModeSystemSettingsDialog, "Customize cast bar")
    panel = row:GetParent()
    scroll = assert(UI.Find(panel, function(f) return f:IsObjectType("ScrollFrame") end))
    content = scroll:GetScrollChild()
    preview = assert(UI.Find(panel, function(f) return f.progress and f.name and f.time end))
end
local function Row(label)
    return assert(UI.Find(content, function(frame)
        if not frame:IsVisible() then return false end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetText and region:GetText() == label then return true end
        end
    end), "Missing cast-bar row: " .. label)
end
local function Layout()
    UI.AssertInside(EditModeSystemSettingsDialog, UIParent, "Cast-bar dialog")
    UI.AssertInside(panel, EditModeSystemSettingsDialog, "Cast-bar controls")
    UI.AssertInside(scroll, panel, "Cast-bar scroll viewport")
    UI.AssertInside(preview, panel, "Cast-bar preview")
    UI.AssertInside(EditModeSystemSettingsDialog.Buttons, EditModeSystemSettingsDialog, "Native buttons")
end

UI.Flow("Cast bar: native appearance, layout and details controls update preview and reset", {
    function(_, sidebar, list)
        original = PyresinQoLDB.castBar and CopyTable(PyresinQoLDB.castBar)
        originalEnabled = PyresinQoLDB.castBarCustomization
        nativeWidth, nativeHeight = PlayerCastingBarFrame:GetSize()
        UI.PageButton(sidebar, "Player Frame"):Click()
        list:ScrollToElementByName("Configure in Edit Mode")
    end,
    function(_, _, list) UI.Click(UI.Button(list, "Configure in Edit Mode"), list.ScrollBox, "Configure cast bar") end,
    function(canvas)
        assertFalse(canvas:IsShown())
        assertEquals(PlayerCastingBarFrame, EditModeSystemSettingsDialog.attachedToSystem)
        Parts()
        assertFalse(enable:GetChecked())
        UI.Click(enable, panel, "Enable cast bar")
    end,
    function()
        Layout()
        assertTrue(PyresinQoLDB.castBarCustomization)
        assertTrue(preview:IsVisible())
        assertEquals("Example spell", preview.name:GetText())
        dropdown = Row("Bar color").Dropdown
        UI.ScrollTo(scroll, dropdown:GetParent())
    end,
    function() UI.OpenMenu(dropdown) end,
    function() UI.SelectMenu(dropdown, "Class color") end,
    function()
        assertEquals("class", PyresinQoLDB.castBar.colorMode)
        local _, class = UnitClass("player")
        local color = RAID_CLASS_COLORS[class]
        local r, g, b = preview.progress:GetVertexColor()
        assertAlmostEquals(color.r, r); assertAlmostEquals(color.g, g); assertAlmostEquals(color.b, b)
        UI.ScrollTo(scroll, Row("Border style"))
    end,
    function() UI.Click(UI.Button(content, "Thin"), scroll, "Thin border") end,
    function()
        assertEquals("thin", PyresinQoLDB.castBar.borderStyle)
        assertNotNil(Row("Border thickness"))
        UI.Click(UI.Button(panel, "Layout"), panel, "Layout tab")
    end,
    function()
        Layout()
        assertEquals(0, scroll:GetVerticalScroll())
        dropdown = Row("Layout").Dropdown
        UI.OpenMenu(dropdown)
    end,
    function() UI.SelectMenu(dropdown, "Compact") end,
    function()
        assertEquals("compact", PyresinQoLDB.castBar.layout)
        assertEquals(240, PlayerCastingBarFrame:GetWidth())
        assertEquals(22, PlayerCastingBarFrame:GetHeight())
        assertEquals(240, preview.fill:GetWidth())
        local slider = assert(UI.Find(Row("Width"), function(f) return f.Slider and f.Forward end))
        UI.Click(slider.Forward, scroll, "Set explicit width")
    end,
    function()
        assertEquals(100, PyresinQoLDB.castBar.width)
        assertEquals(100, PlayerCastingBarFrame:GetWidth())
        assertEquals(100, preview.fill:GetWidth())
        UI.ScrollTo(scroll, Row("Spell icon"))
    end,
    function() UI.Click(UI.Button(content, "Off"), scroll, "Hide spell icon") end,
    function()
        assertEquals("off", PyresinQoLDB.castBar.icon)
        assertFalse(preview.icon:IsShown())
        UI.Click(UI.Button(panel, "Details"), panel, "Details tab")
    end,
    function()
        Layout()
        UI.Click(UI.Checkbox(content, "Show spell name"), scroll, "Hide spell name")
    end,
    function()
        assertEquals(false, PyresinQoLDB.castBar.showSpellName)
        assertFalse(preview.name:IsShown())
        UI.Click(UI.Button(panel, "Reset cast bar customization"), panel, "Reset cast bar")
    end,
    function()
        assertNil(PyresinQoLDB.castBar)
        assertTrue(PyresinQoLDB.castBarCustomization)
        assertTrue(preview.name:IsShown())
        assertEquals(nativeWidth, PlayerCastingBarFrame:GetWidth())
        assertEquals(nativeHeight, PlayerCastingBarFrame:GetHeight())
        UI.Click(enable, panel, "Disable cast bar")
    end,
    function()
        assertFalse(scroll:IsVisible())
        assertFalse(preview:IsVisible())
        assertFalse(PyresinQoLDB.castBarCustomization == true)
    end,
}, function()
    if dropdown then dropdown:CloseMenu() end
    PyresinQoLDB.castBar = original
    if enable then
        if enable:GetChecked() == (originalEnabled == true) then enable:Click() end
        enable:Click()
    end
    PyresinQoLDB.castBarCustomization = originalEnabled
    HideUIPanel(EditModeManagerFrame)
end)

for _, outcome in ipairs({ "cancel", "confirm", "dropdown" }) do
    local saved, enabled, oldPickerCallback
    UI.Flow("Cast bar: reset ignores stale " .. outcome .. " editor after scrolling", {
        function()
            saved, enabled = PyresinQoLDB.castBar and CopyTable(PyresinQoLDB.castBar), PyresinQoLDB.castBarCustomization
            ShowUIPanel(EditModeManagerFrame)
            EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
            Parts()
            if not enable:GetChecked() then UI.Click(enable, panel, "Enable cast bar") end
            UI.Click(UI.Button(panel, "Appearance"), panel, "Appearance tab")
        end,
        function()
            dropdown = Row("Bar color").Dropdown
            UI.ScrollTo(scroll, dropdown:GetParent())
        end,
        function() UI.OpenMenu(dropdown) end,
        function() UI.SelectMenu(dropdown, "Custom color") end,
        function() UI.ScrollTo(scroll, UI.Button(content, "Choose color"):GetParent()) end,
        function() UI.Click(UI.Button(content, "Choose color"), scroll, "Open color picker") end,
        function()
            assertTrue(ColorPickerFrame:IsShown())
            ColorPickerFrame.Content.ColorPicker:SetColorRGB(.2, .4, .6)
            UI.Click(ColorPickerFrame.Footer.OkayButton, ColorPickerFrame, "Keep initial color")
            assertAlmostEquals(.2, PyresinQoLDB.castBar.customColor.r)
        end,
        function()
            if outcome == "dropdown" then
                dropdown = Row("Bar color").Dropdown
                UI.ScrollTo(scroll, dropdown:GetParent())
                UI.OpenMenu(dropdown)
            else
                UI.Click(UI.Button(content, "Choose color"), scroll, "Reopen color picker")
                oldPickerCallback = outcome == "cancel" and ColorPickerFrame.cancelFunc or ColorPickerFrame.swatchFunc
                ColorPickerFrame.Content.ColorPicker:SetColorRGB(.8, .1, .3)
            end
        end,
        function()
            UI.Click(UI.Button(panel, "Reset cast bar customization"), panel, "Reset with editor open")
            assertNil(PyresinQoLDB.castBar)
        end,
        function()
            assert(scroll:GetVerticalScroll() <= math.max(0, content:GetHeight() - scroll:GetHeight()))
            if outcome == "dropdown" then
                if dropdown:IsMenuOpen() then UI.SelectMenu(dropdown, "Class color") end
            else
                if ColorPickerFrame:IsShown() then
                    UI.Click(outcome == "cancel" and ColorPickerFrame.Footer.CancelButton or ColorPickerFrame.Footer.OkayButton,
                        ColorPickerFrame, "Close stale picker")
                else
                    -- Exercise a callback already queued before the reset closed its editor.
                    oldPickerCallback()
                end
            end
        end,
        function()
            assertNil(PyresinQoLDB.castBar, "A stale editor resurrected reset overrides")
            assertFalse(UI.Find(content, function(f)
                return f:IsVisible() and f.GetText and f:GetText() == "Choose color"
            end))
            Layout()
        end,
    }, function()
        if dropdown then dropdown:CloseMenu() end
        ColorPickerFrame:Hide()
        PyresinQoLDB.castBar = saved
        if enable then
            if enable:GetChecked() == (enabled == true) then enable:Click() end
            enable:Click()
        end
        PyresinQoLDB.castBarCustomization = enabled
        HideUIPanel(EditModeManagerFrame)
    end)
end
