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
    { "Dungeon Maps", "DungeonMapsEnabled", "dungeonMapsEnabled", true },
    { "Flight Timer", "FlightTimerZones", "flightTimerZones", true },
}

local UI = PyresinQoLUITest
local SettingsParts, PageButton = UI.SettingsParts, UI.PageButton
local PhysicalRect, AssertInside, UIFlow = UI.PhysicalRect, UI.AssertInside, UI.Flow

local function AssertSettingsLayout(canvas, sidebar, list)
    AssertInside(canvas, UIParent, "Settings window")
    AssertInside(canvas.ClosePanelButton, UIParent, "Close button")
    AssertInside(sidebar, canvas, "Navigation")
    AssertInside(list, canvas, "Settings list")
    AssertInside(canvas.SearchBox, canvas, "Settings search")
    -- Blizzard's list template intentionally extends its ScrollBox past the list.
    if list.ScrollBox:IsVisible() then AssertInside(list.ScrollBox, canvas, "Scroll viewport") end
    AssertInside(list.Header.Title, list.Header, "Page title")
    assertEquals(920, canvas:GetWidth())
    assertEquals(724, canvas:GetHeight())
    assertEquals(199, sidebar:GetWidth())
    assertEquals(50, list.Header:GetHeight())
    for _, region in ipairs({ list.Header:GetRegions() }) do
        if region:IsObjectType("Texture") then
            assertEquals("Options_HorizontalDivider", region:GetAtlas())
            assertEquals(1, region:GetHeight())
        end
    end
    if list.Header.DefaultsButton:IsVisible() then
        AssertInside(list.Header.DefaultsButton, list.Header, "Defaults button")
    end
    for _, button in ipairs({ sidebar:GetChildren() }) do
        if button:IsObjectType("Button") and button:IsVisible() then
            AssertInside(button, sidebar, "Navigation button")
            if button.Background then
                local atlas = C_Texture.GetAtlasInfo(button.Background:GetAtlas())
                assertEquals(atlas.width, button.Background:GetWidth())
                assertEquals(atlas.height, button.Background:GetHeight())
                assertTrue(button.Background:GetHeight() > button:GetHeight())
            end
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
            assert(not frame.Text:IsTruncated(), "Incomplete setting label: " .. frame.Text:GetText())
            AssertInside(frame.Checkbox, frame, "Setting checkbox")
            local point, _, relativePoint, x = frame.Checkbox:GetPoint(1)
            assertEquals("LEFT", point)
            assertEquals("CENTER", relativePoint)
            assertEquals(-80, x)
            assertEquals(setting, frame:GetElementData():GetSetting())
            return frame.Checkbox
        end
    end
    error("No rendered checkbox bound to " .. setting:GetVariable())
end

local function AssertOneRefresh(list, action)
    local count, owner = 0, {}
    list:RegisterCallback(list.Event.OnSettingsUpdated, function() count = count + 1 end, owner)
    local ok, message = pcall(action)
    list:UnregisterCallback(list.Event.OnSettingsUpdated, owner)
    assert(ok, message)
    assertEquals(1, count)
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
    PageButton(sidebar, "Flyout Bar") -- sliders and a dropdown only; flyouts.lua drives them
    local count = 0
    for _, button in ipairs({ sidebar:GetChildren() }) do
        if button.selected then count = count + 1 end
    end
    assertEquals(#pages + 2, count)
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
            local navigation = PageButton(sidebar, page[1])
            assertTrue(navigation.selected:IsShown())
            local r, g, b = navigation.text:GetTextColor()
            assertEquals(1, r)
            assertEquals(1, g)
            assertEquals(1, b)
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

local searchSetting, searchOriginal
UIFlow("Search: native search box finds global controls and edits their original settings", {
    function(canvas, sidebar, list)
        searchSetting = assert(Settings.GetSetting("PyresinQoL_ShowFPS"))
        searchOriginal = searchSetting:GetValue()
        AssertOneRefresh(list, function() PageButton(sidebar, "Tooltips"):Click() end)
        assertFalse(canvas.SearchBox:HasFocus())
        canvas.SearchBox:SetText("  fPs  ")
        list:ScrollToElementByName(searchSetting:GetName())
    end,
    function(canvas, sidebar, list)
        AssertSettingsLayout(canvas, sidebar, list)
        assertEquals(SETTINGS_SEARCH_RESULTS, list.Header.Title:GetText())
        assertFalse(list.Header.DefaultsButton:IsShown())
        assertFalse(PageButton(sidebar, "Tooltips").selected:IsShown())
        assertTrue(canvas.SearchBox.clearButton:IsShown())
        UI.Click(VisibleCheckbox(list, searchSetting), list.ScrollBox, "Search result checkbox")
    end,
    function(canvas, _, list)
        assertEquals(not searchOriginal, PyresinQoLDB.showFPS)
        assertEquals("  fPs  ", canvas.SearchBox:GetText())
        assertEquals(not searchOriginal, VisibleCheckbox(list, searchSetting):GetChecked())
        UI.Click(canvas.SearchBox.clearButton, canvas, "Clear settings search")
    end,
    function(canvas, sidebar, list)
        assertEquals("", canvas.SearchBox:GetText())
        assertEquals("Tooltips", list.Header.Title:GetText())
        assertTrue(PageButton(sidebar, "Tooltips").selected:IsShown())
        assertTrue(list.Header.DefaultsButton:IsShown())
    end,
}, function() if searchSetting then searchSetting:SetValue(searchOriginal) end end)

UIFlow("Search: cross-page matches, literal punctuation, result links and close/reopen", {
    function(canvas, sidebar)
        PageButton(sidebar, "Tooltips"):Click()
        canvas.SearchBox:SetText("class color")
    end,
    function(canvas, _, list)
        local player, target = false, false
        for _, initializer in list.ScrollBox:GetDataProvider():Enumerate() do
            if initializer:GetSetting() == Settings.GetSetting("PyresinQoL_playerClassColor") then player = true end
            if initializer:GetSetting() == Settings.GetSetting("PyresinQoL_targetClassColor") then target = true end
        end
        assertTrue(player and target)
        canvas.SearchBox:SetText("[]%.")
    end,
    function(canvas, _, list)
        assertEquals(1, list.ScrollBox:GetDataProvider():GetSize())
        local message = assert(UI.Find(list.ScrollBox, function(f)
            return f.Title and f.Title:GetText() == SETTINGS_SEARCH_NOTHING_FOUND
        end))
        AssertInside(message, list.ScrollBox, "Empty search result")
        canvas.SearchBox:SetText("druid")
    end,
    function(_, _, list)
        local header = assert(UI.Find(list.ScrollBox, function(f)
            return f.Title and f.Title:GetText() == "Unit Frames > Player Frame"
        end))
        AssertOneRefresh(list, function() UI.Click(header, list.ScrollBox, "Search result page link") end)
    end,
    function(canvas, sidebar, list)
        assertEquals("", canvas.SearchBox:GetText())
        assertEquals("Player Frame", list.Header.Title:GetText())
        assertTrue(PageButton(sidebar, "Player Frame").selected:IsShown())
        assertTrue(list.Header.DefaultsButton:IsShown())
        AssertOneRefresh(list, function() PageButton(sidebar, "Player Frame"):Click() end)
        canvas.SearchBox:SetText("nameplates")
        assertEquals(SETTINGS_SEARCH_RESULTS, list.Header.Title:GetText())
        canvas:Hide()
    end,
    function(canvas)
        assertEquals("", canvas.SearchBox:GetText())
        SlashCmdList.PQOL()
    end,
    function(_, sidebar, list)
        assertEquals("Player Frame", list.Header.Title:GetText())
        assertTrue(PageButton(sidebar, "Player Frame").selected:IsShown())
    end,
})

local moduleSetting, moduleOriginal, playerSetting
UIFlow("Modules: pending reload locks page and search controls until enabled again", {
    function(canvas, sidebar, list)
        moduleSetting = assert(Settings.GetSetting("PyresinQoL_Module_unitFrames"))
        playerSetting = assert(Settings.GetSetting("PyresinQoL_playerClassColor"))
        moduleOriginal = moduleSetting:GetValue()
        PageButton(sidebar, "Modules"):Click()
        canvas.SearchBox:SetText("unit frames")
        list:ScrollToElementByName(moduleSetting:GetName())
    end,
    function(canvas, sidebar, list)
        UI.Click(UI.VisibleSetting(list, moduleSetting).Checkbox, list.ScrollBox, "Disable unit frames")
        assertEquals("unit frames", canvas.SearchBox:GetText())
        assertEquals(SETTINGS_SEARCH_RESULTS, list.Header.Title:GetText())
        AssertOneRefresh(list, function() PageButton(sidebar, "Player Frame *"):Click() end)
        list:ScrollToElementByName(playerSetting:GetName())
    end,
    function(canvas, _, list)
        assertFalse(PyresinQoLDB.modules.unitFrames)
        assertFalse(UI.VisibleSetting(list, playerSetting).Checkbox:IsEnabled())
        assertFalse(list.Header.DefaultsButton:IsEnabled())
        canvas.SearchBox:SetText("class color")
        list:ScrollToElementByName(playerSetting:GetName())
    end,
    function(_, sidebar, list)
        assertEquals(SETTINGS_SEARCH_RESULTS, list.Header.Title:GetText())
        assertFalse(UI.VisibleSetting(list, playerSetting).Checkbox:IsEnabled())
        assertFalse(list.Header.DefaultsButton:IsShown())
        PageButton(sidebar, "Modules"):Click()
        list:ScrollToElementByName(moduleSetting:GetName())
    end,
    function(_, sidebar, list)
        UI.Click(UI.VisibleSetting(list, moduleSetting).Checkbox, list.ScrollBox, "Enable unit frames")
        PageButton(sidebar, "Player Frame"):Click()
        list:ScrollToElementByName(playerSetting:GetName())
    end,
    function(_, _, list)
        assertTrue(PyresinQoLDB.modules.unitFrames)
        assertTrue(UI.VisibleSetting(list, playerSetting).Checkbox:IsEnabled())
    end,
}, function() if moduleSetting then moduleSetting:SetValue(moduleOriginal) end end)
