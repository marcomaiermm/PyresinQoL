local pages = {
    -- Page, setting suffix, saved key, default. Each resettable page gets a real change.
    { "Modules", "Module_gameMenu", "gameMenu", true, modules = true },
    { "Game Menu", "CooldownShortcut", "cooldownShortcut", true },
    { "Edit Mode", "PixelPerfectEditMode", "pixelPerfectEditMode", false },
    { "FPS & Latency", "ShowFPS", "showFPS", true },
    { "Experience Bar", "XPAlwaysShow", "xpAlwaysShow", true },
    { "Action Bars", "actionBarColorIcons", "actionBarColorIcons", false },
    { "Quests", "QuestLevels", "questLevels", true },
    { "Player Frame", "playerClassColor", "playerClassColor", false },
    { "Target Frame", "targetClassColor", "targetClassColor", false },
    { "Nameplates", "NameplateThreat", "nameplateThreat", true },
    { "Status Text", "petHideStatusText", "petHideStatusText", false },
    { "Buffs & Debuffs", "buffLayout", "buffLayout", false },
    { "Tooltips", "TooltipAnchorCombat", "tooltipAnchorCombat", false },
}

local UI = PyresinQoLUITest
local SettingsParts, PageButton = UI.SettingsParts, UI.PageButton
local PhysicalRect, AssertInside, UIFlow = UI.PhysicalRect, UI.AssertInside, UI.Flow

local function AssertSettingsLayout(canvas, sidebar, list)
    AssertInside(canvas, UIParent, "Settings window")
    AssertInside(canvas.ClosePanelButton, UIParent, "Close button")
    AssertInside(sidebar, canvas, "Navigation")
    AssertInside(list, canvas, "Settings list")
    -- Blizzard's list template intentionally extends its ScrollBox past the list.
    if list.ScrollBox:IsVisible() then AssertInside(list.ScrollBox, canvas, "Scroll viewport") end
    AssertInside(list.Header.Title, list.Header, "Page title")
    if list.Header.DefaultsButton:IsVisible() then
        AssertInside(list.Header.DefaultsButton, list.Header, "Defaults button")
    end
    for _, button in ipairs({ sidebar:GetChildren() }) do
        if button:IsObjectType("Button") and button:IsVisible() then
            AssertInside(button, sidebar, "Navigation button")
        end
    end
end

local function VisibleCheckbox(list, setting)
    for _, frame in list.ScrollBox:EnumerateFrames() do
        if frame.GetSetting and frame:GetSetting() == setting then
            assertTrue(frame:IsVisible())
            assertEquals(setting:GetName(), frame.Text:GetText())
            assertTrue(frame.Text:IsVisible())
            assertTrue(frame.Checkbox:IsVisible())
            assertTrue(frame.Checkbox:IsEnabled())
            assertTrue(frame.Checkbox:GetWidth() > 0 and frame.Checkbox:GetHeight() > 0)
            AssertInside(frame, list.ScrollBox, "Setting row")
            AssertInside(frame.Text, frame, "Setting label")
            AssertInside(frame.Checkbox, frame, "Setting checkbox")
            assertEquals(setting, frame:GetElementData():GetSetting())
            return frame.Checkbox
        end
    end
    error("No rendered checkbox bound to " .. setting:GetVariable())
end

test("uses the requested physical UI resolution", function()
    local expected = assert(PyresinQoLUITestResolution, "Run via tests/run-ui.sh")
    local width, height = GetPhysicalScreenSize()
    assertEquals(expected[1], width)
    assertEquals(expected[2], height)
end)

test("loads Forever and initializes all settings pages", function()
    local version, _, _, interface = GetBuildInfo()
    assertEquals("1.60.1", version)
    assertEquals(16001, interface)
    assertNotNil(PyresinQoLDB.profileStore)
    assertNotNil(PyresinQoLPerformance)
    assertNotNil(PlayerCastingBarFrame)
    assertNotNil(StatusTrackingBarManager)
    local _, sidebar = SettingsParts()
    for _, page in ipairs(pages) do PageButton(sidebar, page[1]) end
    PageButton(sidebar, "Profiles")
    local count = 0
    for _, button in ipairs({ sidebar:GetChildren() }) do
        if button.selected then count = count + 1 end
    end
    assertEquals(#pages + 1, count)
end)

UIFlow("slash command opens and native close button closes settings", {
    function(canvas)
        assertTrue(canvas:IsVisible())
        assertTrue(canvas:GetScale() > 0)
    end,
    function(canvas, sidebar, list)
        AssertSettingsLayout(canvas, sidebar, list)
        local left, bottom, right, top = PhysicalRect(canvas)
        local width, height = GetPhysicalScreenSize()
        assert(math.abs((left + right) / 2 - width / 2) <= 1, "Settings are not horizontally centered")
        assert(math.abs((bottom + top) / 2 - height / 2) <= 1, "Settings are not vertically centered")
        canvas.ClosePanelButton:Click()
    end,
    function(canvas) assertFalse(canvas:IsShown()) end,
})

for _, page in ipairs(pages) do
    local setting, original
    local function SavedValues() return page.modules and PyresinQoLDB.modules or PyresinQoLDB end
    UIFlow(page[1] .. ": renders a bound control, changes it and restores defaults", {
        function(_, sidebar, list)
            setting = assert(Settings.GetSetting("PyresinQoL_" .. page[2]))
            original = setting:GetValue()
            PageButton(sidebar, page[1]):Click()
            list:ScrollToElementByName(setting:GetName())
        end,
        function(canvas, sidebar, list)
            AssertSettingsLayout(canvas, sidebar, list)
            assertEquals(page[1], list.Header.Title:GetText())
            assertTrue(PageButton(sidebar, page[1]).selected:IsShown())
            local checkbox = VisibleCheckbox(list, setting)
            assertEquals(page[4], checkbox:GetChecked())
            checkbox:Click()
        end,
        function(_, _, list)
            assertEquals(not page[4], setting:GetValue())
            assertEquals(not page[4], SavedValues()[page[3]])
            assertEquals(not page[4], VisibleCheckbox(list, setting):GetChecked())
            assertTrue(list.Header.DefaultsButton:IsVisible())
            assertTrue(list.Header.DefaultsButton:IsEnabled())
            list.Header.DefaultsButton:Click()
            list:ScrollToElementByName(setting:GetName())
        end,
        function(_, _, list)
            assertEquals(page[4], SavedValues()[page[3]])
            assertEquals(page[4], setting:GetValue())
            assertEquals(page[4], VisibleCheckbox(list, setting):GetChecked())
        end,
    }, function() if setting then setting:SetValue(original) end end)
end

UIFlow("Profiles: renders the active profile selector and creation button", {
    function(_, sidebar) PageButton(sidebar, "Profiles"):Click() end,
    function(canvas, sidebar, list)
        AssertSettingsLayout(canvas, sidebar, list)
        assertEquals("Profiles", list.Header.Title:GetText())
        assertFalse(list.Header.DefaultsButton:IsShown())
        local active, create
        for _, panel in ipairs({ list:GetChildren() }) do
            for _, control in ipairs({ panel:GetChildren() }) do
                if control:IsVisible() and control.GetText then
                    if control.SetupMenu and control:GetText() == "Default" then active = control end
                    if control:IsObjectType("Button") and control:GetText() == "Create" then create = control end
                end
            end
        end
        assertNotNil(active)
        assertTrue(active:GetWidth() > 0)
        assertNotNil(create)
        assertTrue(create:IsEnabled())
        AssertInside(active, list, "Profile selector")
        AssertInside(create, list, "Create profile button")
        assertNotNil(PyresinQoLDB.profileStore.profiles[PyresinQoLDB.profileStore.active])
    end,
})

local fps, latency, originalFPS, originalLatency
UIFlow("performance settings update the live display after UI ticks", {
    function(_, sidebar)
        PageButton(sidebar, "FPS & Latency"):Click()
        fps = assert(Settings.GetSetting("PyresinQoL_ShowFPS"))
        latency = assert(Settings.GetSetting("PyresinQoL_ShowLatency"))
        originalFPS, originalLatency = fps:GetValue(), latency:GetValue()
        fps:SetValue(false)
    end,
    function() latency:SetValue(false) end,
    function()
        assertFalse(PyresinQoLPerformance:IsVisible())
        fps:SetValue(true)
    end,
    function()
        assertTrue(PyresinQoLPerformance:IsVisible())
        AssertInside(PyresinQoLPerformance, UIParent, "Performance display")
    end,
}, function()
    if fps then fps:SetValue(originalFPS); latency:SetValue(originalLatency) end
end)
