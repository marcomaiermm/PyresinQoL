local UI = PyresinQoLUITest
local bars = {
    { "MainActionBar", "actionBarMain" },
    { "MultiBarBottomLeft", "actionBarBar2" },
    { "MultiBarBottomRight", "actionBarBar3" },
    { "MultiBarRight", "actionBarBar4" },
    { "MultiBarLeft", "actionBarBar5" },
    { "MultiBar5", "actionBarBar6" },
    { "MultiBar6", "actionBarBar7" },
    { "MultiBar7", "actionBarBar8" },
}

local function Find(frame, predicate)
    if predicate(frame) then return frame end
    for _, child in ipairs({ frame:GetChildren() }) do
        local found = Find(child, predicate)
        if found then return found end
    end
end

local function Button(frame, text)
    return assert(Find(frame, function(child)
        return child:IsObjectType("Button") and child.GetText and child:GetText() == text
    end), "Missing button: " .. text)
end

local function Checkbox(frame, text)
    local row = assert(Find(frame, function(child)
        return child.Label and child.Button and child.Label:GetText() == text
    end), "Missing checkbox: " .. text)
    return row.Button, row
end

local function Parts()
    local enable, row = Checkbox(EditModeSystemSettingsDialog, "Customize action bar")
    local panel = row:GetParent()
    local scroll = assert(Find(panel, function(child) return child:IsObjectType("ScrollFrame") end))
    return panel, enable, scroll, scroll:GetScrollChild()
end

local function Slider(text)
    local _, _, _, content = Parts()
    for _, row in ipairs({ content:GetChildren() }) do
        for _, region in ipairs({ row:GetRegions() }) do
            if region.GetText and region:GetText() == text then
                return assert(Find(row, function(child) return child.Slider and child.Back end))
            end
        end
    end
    error("Missing slider: " .. text)
end

local function Option(key)
    return assert(Settings.GetSetting("PyresinQoL_" .. key), "Missing setting: " .. key)
end

local function AssertBelow(upper, lower, name)
    local _, bottom = UI.PhysicalRect(upper)
    local _, _, _, top = UI.PhysicalRect(lower)
    assert(top <= bottom + 1, name .. " overlaps the preceding section")
end

local function AssertLayout()
    local dialog = EditModeSystemSettingsDialog
    local panel, enable, scroll = Parts()
    assertTrue(dialog:IsVisible())
    assertTrue(panel:IsVisible())
    UI.AssertInside(dialog, UIParent, "Edit Mode dialog")
    UI.AssertInside(dialog.Settings, dialog, "Blizzard settings")
    UI.AssertInside(panel, dialog, "Action-bar section")
    local heading
    for _, region in ipairs({ panel:GetRegions() }) do
        if region.GetText and region:GetText() == "PyresinQoL - Visibility" then heading = region end
    end
    assert(heading and heading:IsVisible(), "Missing action-bar section heading")
    UI.AssertInside(heading, panel, "Action-bar heading")
    UI.AssertInside(enable:GetParent(), panel, "Customize checkbox row")
    assertEquals("LEFT", enable:GetParent().Label:GetJustifyH())
    UI.AssertInside(enable, dialog, "Customize checkbox")
    UI.AssertInside(dialog.Buttons, dialog, "Blizzard buttons")
    AssertBelow(dialog.Settings, panel, "Action-bar section")
    AssertBelow(panel, dialog.Buttons, "Blizzard buttons")
    if scroll:IsVisible() then
        UI.AssertInside(scroll, panel, "Action-bar scroll viewport")
        UI.AssertInside(scroll.ScrollBar, panel, "Action-bar scrollbar")
        assertTrue(scroll:GetHeight() >= 80)
    end
end

local function ScrollTo(control)
    local _, _, scroll, content = Parts()
    local offset = content:GetTop() - control:GetTop()
    -- The simulator's range uses explicit sizes, missing this anchored viewport's height.
    local maximum = math.max(0, content:GetHeight() - scroll:GetHeight())
    scroll.ScrollBar:SetValue(math.min(offset, maximum))
end

local function Click(control, bounds, name)
    assertTrue(control:IsVisible())
    assertTrue(control:IsEnabled())
    assertTrue(control:IsMouseEnabled())
    -- Native checkbox art extends 5px left of its row; check the row's layout box.
    UI.AssertInside(control:IsObjectType("CheckButton") and control:GetParent() or control, bounds, name)
    if control:IsObjectType("CheckButton") then
        assertEquals("LEFT", control:GetParent().Label:GetJustifyH())
    end
    control:Click()
end

local function EditFlow(name, steps, restore)
    local flow = {
        function(_, sidebar, list)
            UI.PageButton(sidebar, "Action Bars"):Click()
            list:ScrollToElementByName("Visibility")
        end,
        function(_, _, list)
            Click(Button(list, "Customize in Edit Mode"), list.ScrollBox, "Edit Mode launcher")
        end,
        function(canvas)
            assertFalse(canvas:IsShown())
            assertTrue(EditModeManagerFrame:IsEditModeActive())
            assertEquals(MainActionBar, EditModeSystemSettingsDialog.attachedToSystem)
        end,
    }
    for _, step in ipairs(steps) do flow[#flow + 1] = step end
    UI.Flow("Action Bars: " .. name, flow, function()
        StaticPopup_Hide("PYRESINQOL_ACTIONBAR_CONDITION")
        HideUIPanel(EditModeManagerFrame)
        if restore then restore() end
    end)
end

for index, bar in ipairs(bars) do
    local original = {}
    EditFlow("bar " .. index .. " binds native controls to its own saved values", {
        function()
            for _, suffix in ipairs({ "Enabled", "HideCombat", "AlphaNormal" }) do
                original[suffix] = Option(bar[2] .. suffix):GetValue()
            end
            EditModeManagerFrame:SelectSystem(_G[bar[1]])
        end,
        function()
            assertEquals(_G[bar[1]], EditModeSystemSettingsDialog.attachedToSystem)
            assertEquals("Action Bar " .. index, EditModeSystemSettingsDialog.Title:GetText())
            AssertLayout()
            local panel, enable, scroll = Parts()
            assertFalse(enable:GetChecked())
            assertFalse(scroll:IsVisible())
            Click(enable, panel, "Customize checkbox")
        end,
        function()
            AssertLayout()
            local panel, enable, scroll = Parts()
            assertTrue(enable:GetChecked())
            assertTrue(scroll:IsVisible())
            assertEquals(true, PyresinQoLDB[bar[2] .. "Enabled"])
            Click(Checkbox(panel, "Hide in combat"), scroll, "Hide-in-combat checkbox")
        end,
        function()
            assertEquals(true, PyresinQoLDB[bar[2] .. "HideCombat"])
            ScrollTo(Slider("Opacity out of combat"):GetParent())
        end,
        function()
            local _, _, scroll = Parts()
            local slider = Slider("Opacity out of combat")
            assertEquals(100, slider.Slider:GetValue())
            Click(slider.Back, scroll, "Opacity stepper")
        end,
        function()
            assertAlmostEquals(.99, PyresinQoLDB[bar[2] .. "AlphaNormal"])
            assertEquals(99, Slider("Opacity out of combat").Slider:GetValue())
            for _, other in ipairs(bars) do
                if other ~= bar then
                    assertFalse(Option(other[2] .. "Enabled"):GetValue())
                    assertFalse(Option(other[2] .. "HideCombat"):GetValue())
                    assertEquals(1, Option(other[2] .. "AlphaNormal"):GetValue())
                end
            end
            EditModeSystemSettingsDialog.CloseButton:Click()
        end,
        function()
            local panel = Parts()
            assertFalse(panel:IsVisible())
            EditModeManagerFrame:SelectSystem(_G[bar[1]])
        end,
        function()
            AssertLayout()
            local panel, enable, scroll = Parts()
            assertTrue(enable:GetChecked())
            assertTrue(Checkbox(panel, "Hide in combat"):GetChecked())
            assertEquals(0, scroll:GetVerticalScroll())
            assertEquals(99, Slider("Opacity out of combat").Slider:GetValue())
            Click(enable, panel, "Customize checkbox")
        end,
        function()
            AssertLayout()
            local _, enable, scroll = Parts()
            assertFalse(enable:GetChecked())
            assertFalse(scroll:IsVisible())
            assertFalse(Option(bar[2] .. "Enabled"):GetValue())
            assertTrue(Option(bar[2] .. "HideCombat"):GetValue())
        end,
    }, function()
        for suffix, value in pairs(original) do Option(bar[2] .. suffix):SetValue(value) end
    end)
end

local macroPopup
EditFlow("macro dialog validates input and retains its bar when selection changes", {
    function()
        local panel, enable = Parts()
        Click(enable, panel, "Customize checkbox")
    end,
    function()
        local panel = Parts()
        ScrollTo(Button(panel, "Edit macro condition"))
    end,
    function()
        local panel, _, scroll = Parts()
        Click(Button(panel, "Edit macro condition"), scroll, "Macro condition button")
    end,
    function()
        macroPopup = assert(StaticPopup_FindVisible("PYRESINQOL_ACTIONBAR_CONDITION"))
        UI.AssertInside(macroPopup, UIParent, "Macro dialog")
        assertContains(macroPopup:GetTextFontString():GetText(), "Action Bar 1")
        macroPopup:GetEditBox():SetText("[combat] invalid")
    end,
    function()
        assertFalse(macroPopup:GetButton1():IsEnabled())
        assertEquals("", Option("actionBarMainCustomCondition"):GetValue())
        macroPopup:GetEditBox():SetText("[combat] hide; show")
        EditModeManagerFrame:SelectSystem(MultiBarBottomLeft)
    end,
    function()
        AssertLayout()
        local _, enable, scroll = Parts()
        assertFalse(enable:GetChecked())
        assertFalse(scroll:IsVisible())
        assertEquals(0, scroll:GetVerticalScroll())
        Click(macroPopup:GetButton1(), macroPopup, "Accept macro condition")
    end,
    function()
        assertFalse(macroPopup:IsShown())
        assertEquals("[combat] hide; show", Option("actionBarMainCustomCondition"):GetValue())
        assertEquals("", Option("actionBarBar2CustomCondition"):GetValue())
    end,
}, function()
    Option("actionBarMainEnabled"):SetValue(false)
    Option("actionBarMainCustomCondition"):SetValue("")
end)

EditFlow("switching to cast bar and player frame restores the matching sections", {
    function()
        local panel, enable = Parts()
        Click(enable, panel, "Customize checkbox")
    end,
    function()
        AssertLayout()
        EditModeManagerFrame:SelectSystem(PlayerCastingBarFrame)
    end,
    function()
        local panel = Parts()
        assertFalse(panel:IsShown())
        local castEnable, castRow = Checkbox(EditModeSystemSettingsDialog, "Customize cast bar")
        assertTrue(castEnable:IsVisible())
        UI.AssertInside(castRow:GetParent(), EditModeSystemSettingsDialog, "Cast-bar section")
        EditModeManagerFrame:SelectSystem(MainActionBar)
    end,
    function()
        AssertLayout()
        assertFalse(Checkbox(EditModeSystemSettingsDialog, "Customize cast bar"):IsVisible())
        EditModeManagerFrame:SelectSystem(PlayerFrame)
    end,
    function()
        local panel = Parts()
        assertFalse(panel:IsShown())
        assertFalse(Checkbox(EditModeSystemSettingsDialog, "Customize cast bar"):IsVisible())
        local dialog = EditModeSystemSettingsDialog
        UI.AssertInside(dialog, UIParent, "Player-frame dialog")
        local _, relative = dialog.Buttons:GetPoint()
        assertEquals(dialog.Settings, relative)
    end,
}, function() Option("actionBarMainEnabled"):SetValue(false) end)

EditFlow("hide rule previews in Edit Mode and drives the real bar after closing", {
    function()
        local panel, enable = Parts()
        Click(enable, panel, "Customize checkbox")
    end,
    function()
        local panel, _, scroll = Parts()
        Click(Checkbox(panel, "Hide out of combat"), scroll, "Hide-out-of-combat checkbox")
    end,
    function()
        assertTrue(Option("actionBarMainHideOutOfCombat"):GetValue())
        assertTrue(MainActionBar:IsShown())
        HideUIPanel(EditModeManagerFrame)
    end,
    function()
        assertFalse(EditModeManagerFrame:IsEditModeActive())
        assertFalse(MainActionBar:IsShown())
        ShowUIPanel(EditModeManagerFrame)
        EditModeManagerFrame:SelectSystem(MainActionBar)
    end,
    function()
        AssertLayout()
        assertTrue(MainActionBar:IsShown())
        local panel, enable = Parts()
        assertTrue(Checkbox(panel, "Hide out of combat"):GetChecked())
        Click(enable, panel, "Customize checkbox")
        HideUIPanel(EditModeManagerFrame)
    end,
    function()
        assertTrue(MainActionBar:IsShown())
        assertFalse(Option("actionBarMainEnabled"):GetValue())
    end,
}, function()
    Option("actionBarMainHideOutOfCombat"):SetValue(false)
    Option("actionBarMainEnabled"):SetValue(false)
end)
