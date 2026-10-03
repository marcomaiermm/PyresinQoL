local UI = PyresinQoLUITest
local original, panel, active, layouts, popup
local function Store() return PyresinQoLDB.profileStore end
local function NameDialog(name)
    popup = assert(StaticPopup_FindVisible("PYRESINQOL_PROFILE_NAME"))
    UI.AssertInside(popup, UIParent, "Profile name dialog")
    popup:GetEditBox():SetText(name)
end
local function Accept()
    UI.Click(popup:GetButton1(), popup, "Accept profile name")
end

UI.Flow("Profiles: native dialogs validate, copy, rename, link and delete profiles", {
    function(_, sidebar)
        panel, active, layouts, popup = nil, nil, nil, nil
        original = CopyTable(Store())
        UI.PageButton(sidebar, "Profiles"):Click()
    end,
    function(canvas, sidebar, list)
        assertEquals("Profiles", list.Header.Title:GetText())
        assertTrue(UI.PageButton(sidebar, "Profiles").selected:IsShown())
        assertFalse(list.Header.DefaultsButton:IsShown())
        UI.AssertInside(canvas, UIParent, "Profiles settings window")
        UI.AssertInside(sidebar, canvas, "Profiles navigation")
        UI.AssertInside(list, canvas, "Profiles settings list")
        panel = UI.Button(list, "Create"):GetParent()
        active = assert(UI.Find(panel, function(f) return f.SetupMenu and f:GetText() == "Default" end))
        layouts = assert(UI.Find(panel, function(f)
            return f.SetupMenu and f ~= active and f:GetWidth() == 240 and f:IsEnabled()
        end))
        UI.AssertInside(panel, list, "Profiles panel")
        for _, control in ipairs({ panel:GetChildren() }) do
            if control:IsVisible() then UI.AssertInside(control, panel, "Profile control") end
        end
        assertFalse(UI.Button(panel, "Rename"):IsEnabled())
        assertFalse(UI.Button(panel, DELETE):IsEnabled())
        UI.Click(UI.Button(panel, "Create"), panel, "Create profile")
    end,
    function() NameDialog("  "); assertFalse(popup:GetButton1():IsEnabled()) end,
    function() NameDialog("Default"); assertFalse(popup:GetButton1():IsEnabled()) end,
    function() NameDialog("bad|name"); assertFalse(popup:GetButton1():IsEnabled()) end,
    function() NameDialog("UI profile"); Accept() end,
    function()
        assertFalse(popup:IsShown())
        assertEquals("UI profile", Store().active)
        assertEquals("UI profile", active:GetText())
        assertEquals(PyresinQoLDB.showFPS, Store().profiles["UI profile"].showFPS)
        assertFalse(Store().profiles["UI profile"].modules == PyresinQoLDB.modules)
        assertEquals(PyresinQoLDB.modules.unitFrames, Store().profiles["UI profile"].modules.unitFrames)
        UI.Click(UI.Button(panel, "Rename"), panel, "Rename profile")
    end,
    function() NameDialog("UI renamed"); Accept() end,
    function()
        assertEquals("UI renamed", Store().active)
        assertNil(Store().profiles["UI profile"])
        assertEquals("UI renamed", active:GetText())
        UI.OpenMenu(layouts)
    end,
    function()
        local item = UI.MenuItem(layouts)
        assertContains(item.fontString:GetText(), "(Preset)")
        UI.Click(item, UIParent, "Assign profile layout")
    end,
    function()
        local character = UnitGUID("player")
        local key = Store().profileLayouts[character]["UI renamed"]
        assertNotNil(key)
        assertEquals("UI renamed", Store().characterBindings[character][key])
        UI.Click(UI.Button(panel, "Create"), panel, "Copy profile")
    end,
    function() NameDialog("UI renamed"); assertFalse(popup:GetButton1():IsEnabled()) end,
    function() NameDialog("UI keeper"); Accept() end,
    function()
        assertEquals("UI keeper", Store().active)
        UI.Click(UI.Button(panel, DELETE), panel, "Delete inactive profile")
    end,
    function()
        popup = assert(StaticPopup_FindVisible("PYRESINQOL_PROFILE_DELETE"))
        assertContains(popup:GetTextFontString():GetText(), "UI renamed")
        UI.Click(popup:GetButton2(), popup, "Cancel profile deletion")
    end,
    function()
        assertNotNil(Store().profiles["UI renamed"])
        UI.Click(UI.Button(panel, DELETE), panel, "Delete inactive profile")
    end,
    function()
        popup = assert(StaticPopup_FindVisible("PYRESINQOL_PROFILE_DELETE"))
        UI.Click(popup:GetButton1(), popup, "Confirm profile deletion")
    end,
    function()
        assertNil(Store().profiles["UI renamed"])
        assertEquals("UI keeper", Store().active)
        assertFalse(UI.Button(panel, DELETE):IsEnabled())
        UI.OpenMenu(active)
    end,
    function() UI.SelectMenu(active, "Default") end,
    function()
        popup = assert(StaticPopup_FindVisible("PYRESINQOL_PROFILE_SWITCH"))
        assertContains(popup:GetTextFontString():GetText(), "Default")
        UI.Click(popup:GetButton2(), popup, "Cancel profile switch")
    end,
    function() assertEquals("UI keeper", Store().active); assertNil(Store().pending) end,
}, function()
    if active then active:CloseMenu() end
    if layouts then layouts:CloseMenu() end
    for _, name in ipairs({ "NAME", "DELETE", "SWITCH" }) do StaticPopup_Hide("PYRESINQOL_PROFILE_" .. name) end
    if original then PyresinQoLDB.profileStore = original; EventRegistry:TriggerEvent("PyresinQoL.ProfileChanged") end
end)
