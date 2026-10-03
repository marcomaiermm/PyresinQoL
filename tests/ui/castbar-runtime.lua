local UI = PyresinQoLUITest
local frame = PlayerCastingBarFrame
local oldEnabled, oldConfig, enable, panel, color, previous
local function ColorDropdown()
    return assert(UI.Find(panel, function(row)
        if not row.Dropdown or not row:IsVisible() then return false end
        for _, region in ipairs({ row:GetRegions() }) do
            if region.GetText and region:GetText() == "Bar color" then return true end
        end
    end)).Dropdown
end

UI.Flow("Cast bar: configured native casts interrupt, channel and restart without stale state", {
    function()
        oldEnabled = PyresinQoLDB.castBarCustomization
        oldConfig = PyresinQoLDB.castBar and CopyTable(PyresinQoLDB.castBar)
        ShowUIPanel(EditModeManagerFrame)
        EditModeManagerFrame:SelectSystem(frame)
        local row
        enable, row = UI.Checkbox(EditModeSystemSettingsDialog, "Customize cast bar")
        panel = row:GetParent()
        if not enable:GetChecked() then UI.Click(enable, panel, "Customize live cast bar") end
        UI.Click(UI.Button(panel, "Appearance"), panel, "Appearance tab")
    end,
    function()
        color = ColorDropdown()
        local scroll = UI.Find(panel, function(f) return f:IsObjectType("ScrollFrame") end)
        UI.ScrollTo(scroll, color:GetParent())
    end,
    function() UI.OpenMenu(color) end,
    function() UI.SelectMenu(color, "Class color") end,
    function()
        HideUIPanel(EditModeManagerFrame)
        CastSpellByID(19750)
    end,
    function()
        assertNotNil(UnitCastingInfo("player"))
        assertTrue(frame:IsVisible())
        assertTrue(frame.casting)
        assertAlmostEquals(1.5, select(2, frame:GetMinMaxValues()))
        assertEquals(UnitCastingInfo("player"), frame.Text:GetText())
        previous = frame:GetValue()
    end,
    function()
        assert(frame:GetValue() > previous, "Native cast must fill across UI ticks")
        assertTrue(SpellStopCasting())
    end,
    function()
        assertNil(UnitCastingInfo("player"))
        assertFalse(frame.casting)
        assertContains(frame.Text:GetText(), INTERRUPTED)
        assertEquals("interrupted", frame.barType)
        assertEquals("ui-castingbar-interrupted", frame:GetStatusBarTexture():GetAtlas())
        A_Admin.StartChannel(990101, "UI channel", "Interface\\Icons\\Spell_Holy_HolyBolt", 10)
    end,
    function()
        assertNotNil(UnitChannelInfo("player"))
        assertTrue(frame:IsVisible())
        assertTrue(frame.channeling)
        assertAlmostEquals(10, select(2, frame:GetMinMaxValues()))
        assertEquals("UI channel", frame.Text:GetText())
        previous = frame:GetValue()
    end,
    function()
        assert(frame:GetValue() < previous, "Native channel must empty across UI ticks")
        assertTrue(A_Admin.StopChannel(true))
    end,
    function()
        assertNil(UnitChannelInfo("player"))
        assertFalse(frame.channeling)
        CastSpellByID(82326)
    end,
    function()
        assertTrue(frame.casting)
        assertFalse(frame.channeling)
        assertEquals(UnitCastingInfo("player"), frame.Text:GetText())
        assert(frame.Text:GetText() ~= INTERRUPTED)
        local _, class = UnitClass("player")
        local expected = RAID_CLASS_COLORS[class]
        local r, g, b = frame:GetStatusBarColor()
        assertAlmostEquals(expected.r, r); assertAlmostEquals(expected.g, g); assertAlmostEquals(expected.b, b)
    end,
}, function()
    if color then color:CloseMenu() end
    SpellStopCasting()
    A_Admin.StopChannel(false)
    ShowUIPanel(EditModeManagerFrame)
    EditModeManagerFrame:SelectSystem(frame)
    PyresinQoLDB.castBar = oldConfig
    if enable then
        if enable:GetChecked() == (oldEnabled == true) then enable:Click() end
        enable:Click()
    end
    PyresinQoLDB.castBarCustomization = oldEnabled
    HideUIPanel(EditModeManagerFrame)
end)
