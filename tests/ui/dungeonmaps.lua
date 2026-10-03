local UI = PyresinQoLUITest

local provider, originalInstanceInfo, restoreDungeon, dungeonFloor, expectedReturnFloor, routeSelection
local nativeWorldMapID, panBeforeX, panBeforeY
local baselineHomeListFunc, baselineHomeWidth, baselineHomeArrowShown
local staleReturnItem, staleReturnCallback, settingOriginal
local baselineHomeEntries
local WorldHomeMenuArrow
local resizeWasMinimized
local SetNativeBackingMap
local detectedFloorTexture

local function HideNativeMap()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        HideUIPanel(WorldMapFrame)
    end
end

local function InstallDungeonInstance(name, instanceID, instanceType)
    A_Admin.SetInstanceInfo(name, instanceType or "party", 1, 5)
    -- The simulator's admin API does not populate the instance map ID. Keep
    -- this one documented tuple fixture; all native C_Map APIs remain intact.
    GetInstanceInfo = function()
        local values = { originalInstanceInfo() }
        values[8] = instanceID
        return unpack(values, 1, 10)
    end
end

local function OpenDungeon(name, instanceID, subzone, instanceType)
    InstallDungeonInstance(name, instanceID, instanceType)
    A_Admin.SetSubZone(subzone or "Goblin Foundry")
    ToggleWorldMap()
end

local function BeginInstance(name, instanceID, subzone, backingMapID, homeListFunc)
    HideNativeMap()
    local home = WorldMapFrame.NavBar and WorldMapFrame.NavBar.homeButton
    local previousHomeListFunc = home and home.listFunc or nil
    if home and homeListFunc then home.listFunc = homeListFunc end
    baselineHomeListFunc = home and home.listFunc or nil
    baselineHomeWidth = home and home:GetWidth() or nil
    baselineHomeEntries = {}
    if home and baselineHomeListFunc then
        for _, entry in ipairs(baselineHomeListFunc(home) or {}) do
            baselineHomeEntries[#baselineHomeEntries + 1] = {
                text = entry.text, id = entry.id,
            }
        end
    end
    originalInstanceInfo = GetInstanceInfo
    restoreDungeon = function()
        HideNativeMap()
        if PyresinQoLDungeonMapFrame then PyresinQoLDungeonMapFrame:Hide() end
        if A_Admin.SetMouseOverFrame then A_Admin.SetMouseOverFrame(nil) end
        if A_Admin.SetAltKeyDown then A_Admin.SetAltKeyDown(false) end
        if home and homeListFunc then home.listFunc = previousHomeListFunc end
        GetInstanceInfo = originalInstanceInfo
        A_Admin.SetInstanceInfo("Stormwind City", "none", 0, 0)
        A_Admin.SetInInstance(false)
        A_Admin.SetZone("Stormwind City", 1519)
        A_Admin.SetSubZone("Trade District")
        if C_Map and C_Map.SetMapForQuestLog then C_Map.SetMapForQuestLog(1) end
        expectedReturnFloor = nil
        routeSelection = nil
        baselineHomeListFunc = nil
        baselineHomeWidth = nil
        baselineHomeArrowShown = nil
        baselineHomeEntries = nil
        staleReturnCallback = nil
    end
    if backingMapID then SetNativeBackingMap(backingMapID) end
    local addonProvider = WorldMapFrame.PyresinDungeonMaps
    local arrow = home and home.MenuArrowButton
        or addonProvider and addonProvider.HomeMenuArrowButton
    baselineHomeArrowShown = arrow and arrow:IsShown() or false
    provider = WorldMapFrame.PyresinDungeonMaps
    OpenDungeon(name, instanceID, subzone)
end

local function AssertHomeBaselineRestored()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    local home = assert(nav.homeButton, "Missing native World home button")
    assertEquals(baselineHomeListFunc, home.listFunc,
        "Clearing the dungeon route must restore the native World-home menu function")
    assertEquals(baselineHomeWidth, home:GetWidth(),
        "Clearing the dungeon route must restore the native World-home width")
    local currentArrow = WorldHomeMenuArrow(false)
    local currentArrowShown = currentArrow and currentArrow:IsShown() or false
    assertEquals(baselineHomeArrowShown, currentArrowShown,
        "Clearing the dungeon route must restore the native World-home arrow visibility")
    local current = {}
    if home.listFunc then
        for _, entry in ipairs(home.listFunc(home) or {}) do
            current[#current + 1] = { text = entry.text, id = entry.id }
        end
    end
    assertEquals(#baselineHomeEntries, #current,
        "Clearing the dungeon route must restore the native World-home entries")
    for index, expected in ipairs(baselineHomeEntries) do
        assertEquals(expected.text, current[index].text)
        assertEquals(expected.id, current[index].id)
    end
end

local function AssertNativeHomeListUnchanged()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    local home = assert(nav.homeButton, "Missing native World home button")
    local current = {}
    if baselineHomeListFunc then
        for _, entry in ipairs(baselineHomeListFunc(home) or {}) do
            current[#current + 1] = { text = entry.text, id = entry.id }
        end
    end
    assertEquals(#baselineHomeEntries, #current,
        "Dungeon return setup must not mutate the native World-home entry list")
    for index, expected in ipairs(baselineHomeEntries) do
        assertEquals(expected.text, current[index].text)
        assertEquals(expected.id, current[index].id)
    end
end

local function BeginDungeon()
    BeginInstance("The Deadmines", 36, "Goblin Foundry")
end

local function BeginDungeonOnMap(mapID)
    BeginInstance("The Deadmines", 36, "Goblin Foundry", mapID)
end

local function BeginDungeonWithSharedHomeList()
    local entries = {
        { text = "Native home fixture", id = 84, func = function() end },
    }
    BeginInstance("The Deadmines", 36, "Goblin Foundry", 84,
        function() return entries end)
end

SetNativeBackingMap = function(mapID)
    assert(C_Map and C_Map.SetMapForQuestLog, "Native map fixture is unavailable")
    C_Map.SetMapForQuestLog(mapID)
    WorldMapFrame:SetMapID(mapID)
end

local function FindDungeonNavButton()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    for _, button in ipairs(nav.navList or {}) do
        if button.data and button.data.pyresinDungeonMap then
            return button
        end
    end
    error("Missing rendered dungeon return breadcrumb")
end

local function FindNativeNavButtonIfPresent(mapID)
    local nav = WorldMapFrame.NavBar
    if not nav then return nil end
    for _, button in ipairs(nav.navList or {}) do
        if button.data and button.data.id == mapID then
            return button
        end
    end
end

local function NativeWorldHomeMapID()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    assertType("function", nav.GetTopMostUIMapType)
    local info = assert(MapUtil and MapUtil.GetMapParentInfo,
        "Missing native map parent resolver")
    local parent = info(WorldMapFrame:GetMapID(), nav:GetTopMostUIMapType(), true)
    return assert(parent and parent.mapID, "Native World home has no topmost map")
end

WorldHomeMenuArrow = function(required)
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    local home = assert(nav.homeButton, "Missing native World home button")
    local arrow = home.MenuArrowButton
        or (WorldMapFrame.PyresinDungeonMaps
            and WorldMapFrame.PyresinDungeonMaps.HomeMenuArrowButton)
    if required then
        arrow = assert(arrow, "Missing native World home menu arrow")
        assertEquals(home, arrow:GetParent(),
            "World-home return dropdown must be attached to Blizzard's home button")
    end
    return arrow
end

local function AssertNoDungeonNavEntry()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    for _, button in ipairs(nav.navList or {}) do
        assertFalse(button.data and button.data.pyresinDungeonMap,
            "Native world browsing must not append a dungeon breadcrumb")
    end
end

local function FindDungeonReturnMenuItem()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    assert(nav.homeButton, "Missing native World home button")
    local dropdown = WorldHomeMenuArrow(true)
    UI.OpenMenu(dropdown)
    local menu = assert(dropdown.menu, "Native World home menu did not open")
    local item, count = nil, 0
    local function visit(frame)
        local label = frame.fontString or frame.Text
        local value = label and label.GetText and label:GetText()
        if frame:IsVisible() and frame.GetElementDescription and value
            and provider and provider.selection and provider.selection.dungeon
            and value == provider.selection.dungeon.name then
            item, count = frame, count + 1
        end
        for _, child in ipairs({ frame:GetChildren() }) do visit(child) end
    end
    visit(menu)
    assertEquals(1, count, "Native World home menu must contain exactly one dungeon return entry")
    return assert(item, "Missing rendered dungeon return menu entry")
end

local function CaptureDungeonReturnCallback()
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    local home = assert(nav.homeButton, "Missing native World home button")
    assertType("function", home.listFunc)
    for _, entry in ipairs(home.listFunc(home) or {}) do
        if provider and provider.selection and provider.selection.dungeon
            and entry.text == provider.selection.dungeon.name then
            return assert(entry.func, "Dungeon return menu entry has no callback")
        end
    end
    error("Missing dungeon return callback in native World home list")
end

local function AssertAreaLabelSuppressed()
    assertNotNil(provider.NativeAreaLabel, "Missing native area-label surface")
    assertFalse(provider.NativeAreaLabel:IsShown(),
        "Native area labels must be hidden while dungeon art is active")
    if provider.NativeAreaLabel.GetHighestPriorityLabelInfo then
        assertNil(provider.NativeAreaLabel:GetHighestPriorityLabelInfo(),
            "Native area labels must be cleared while dungeon art is active")
    end
end

local function AssertMapHighlightsSuppressed()
    assertType("function", WorldMapFrame.EnumeratePinsByTemplate)
    local foundPin = false
    for pin in WorldMapFrame:EnumeratePinsByTemplate("MapHighlightPinTemplate") do
        foundPin = true
        assertTrue(pin:IsSuppressed(), "Native map highlight must be suppressed in dungeon art")
        assertFalse(pin:IsShown(), "Native map highlight must not render over dungeon art")
    end
    assertTrue(foundPin, "The simulator must provide a native map-highlight fixture")
end

local function DispatchCanvasClick(button)
    local scroll = assert(WorldMapFrame:GetCanvasContainer(), "Missing native map viewport")
    assertType("function", A_Admin.SetMouseOverFrame)
    A_Admin.SetMouseOverFrame(scroll)
    local down = assert(scroll:GetScript("OnMouseDown"), "Missing native mouse-down handler")
    local up = assert(scroll:GetScript("OnMouseUp"), "Missing native mouse-up handler")
    down(scroll, button)
    up(scroll, button)
    A_Admin.SetMouseOverFrame(nil)
end

local function AssertNativeDungeon()
    assertTrue(WorldMapFrame:IsShown(), "M must leave Blizzard's WorldMapFrame visible")
    assertNil(PyresinQoLDungeonMapFrame,
        "Dungeon maps must be rendered in Blizzard's WorldMapFrame, without a second top-level frame")
    provider = assert(WorldMapFrame.PyresinDungeonMaps,
        "Missing native dungeon-map provider on WorldMapFrame")
    assertType("function", provider.GetMap)
    assertEquals(WorldMapFrame, provider:GetMap())
    assertNotNil(provider.ArtFrame, "Missing native dungeon artwork frame")
    local canvas = assert(WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas(), "Missing native map canvas")
    assertEquals(canvas, provider.ArtFrame:GetParent(), "Dungeon artwork must be a direct canvas child")
    assertTrue(provider.ArtFrame:IsShown(), "Dungeon artwork should be visible in an active instance")
    assertTrue(provider.ArtFrame:GetWidth() > 0 and provider.ArtFrame:GetHeight() > 0)
    assertNotNil(provider.FloorDropdown, "Missing native floor dropdown")
    assertNil(provider.WorldMapButton, "Dungeon maps must use native navigation, not a custom world-map button")
    assertNotNil(provider.Status, "Missing native dungeon-map status")
    assertNotNil(provider.NativeFloorDropdown, "Missing native floor overlay tracking")
    assertFalse(provider.NativeFloorDropdown:IsShown(),
        "Native floor navigation must be hidden while dungeon artwork is active")
    assertNotNil(provider.NativeCoordsPanel, "Missing native coordinate overlay tracking")
    assertFalse(provider.NativeCoordsPanel:IsShown(),
        "Native coordinate overlay must be hidden while dungeon artwork is active")
    local dungeonButton = FindDungeonNavButton()
    assertTrue(dungeonButton:IsVisible(), "Dungeon return breadcrumb must be rendered")
    assertFalse(dungeonButton:IsEnabled(), "Active dungeon breadcrumb must be disabled")
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    assertEquals(2, #nav.navList,
        "Active dungeon navigation must contain only World and the dungeon leaf")
    assertEquals(nav.homeButton, nav.navList[1])
    assertEquals(WORLD, nav.homeButton:GetText(),
        "Active dungeon navigation must start at the native World home")
    assertEquals(dungeonButton, nav.navList[2],
        "Active dungeon navigation must not retain backing-map ancestors")
    local homeArrow = WorldHomeMenuArrow(false)
    if homeArrow then
        assertFalse(homeArrow:IsShown(),
            "World-home return dropdown must stay hidden while dungeon art is active")
    end
    AssertAreaLabelSuppressed()
    AssertMapHighlightsSuppressed()
    assertEquals("dungeon", provider.displayMode)
    assertNotNil(provider.selection)
    assertEquals("The Deadmines", provider.selection.dungeon.name)
    assertNotNil(provider.selection.floor)
    dungeonFloor = provider.selection.floor
end

local function FindMenuOption(dropdown, text)
    return assert(UI.Find(dropdown.menu, function(frame)
        local label = frame.fontString or frame.Text
        local value = label and label.GetText and label:GetText()
        return frame:IsVisible() and frame.GetElementDescription and value
            and value:find(text, 1, true) ~= nil
    end), "Missing rendered native floor option: " .. text)
end

local function AssertNoDungeonPlayerPin()
    assertType("function", WorldMapFrame.EnumeratePinsByTemplate)
    local foundPin = false
    for pin in WorldMapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
        foundPin = true
        assertType("function", pin.IsSuppressed,
            "Native player pins must expose map-canvas suppression state")
        assertTrue(pin:IsSuppressed(),
            "Dungeon art must suppress uncalibrated native player pins")
        assertFalse(pin:IsShown(),
            "Dungeon art must not show an uncalibrated native player pin")
    end
    assertTrue(foundPin, "The simulator must provide a native player-pin fixture")
end

local function AssertNativeSurfaceRestored()
    assertEquals("world", provider.displayMode, "Dungeon provider must deactivate after native map navigation")
    assertTrue(provider.NativeCoordsPanel:IsShown(),
        "Native coordinate overlay must return after leaving dungeon artwork")
    if WorldMapFrame.NavBar then
        assertTrue(WorldMapFrame.NavBar:IsShown(),
            "Native map navigation bar must return after leaving dungeon artwork")
    end
    assertTrue(provider.NativeAreaLabel:IsShown(),
        "Native area labels must return after leaving dungeon artwork")
    if provider.NativeAreaLabel.GetHighestPriorityLabelInfo then
        local info = provider.NativeAreaLabel:GetHighestPriorityLabelInfo()
        if info then assertTrue(info.name ~= "The Deadmines") end
    end
    AssertNoDungeonNavEntry()
    local homeArrow = WorldHomeMenuArrow(true)
    assertTrue(homeArrow:IsShown(),
        "Native World home must expose the dungeon return menu outside dungeon art")
    local native = FindNativeNavButtonIfPresent(WorldMapFrame:GetMapID())
    if native then
        assertFalse(native:IsEnabled(),
            "The native current-map breadcrumb must be disabled outside dungeon art")
        if native.selected then
            assertTrue(native.selected:IsShown(),
                "The native current-map breadcrumb must show its selected state")
        end
    end
    for pin in WorldMapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
        assertFalse(pin:IsSuppressed(),
            "Native player-pin suppression must be cleared after leaving dungeon artwork")
    end
    for pin in WorldMapFrame:EnumeratePinsByTemplate("MapHighlightPinTemplate") do
        assertFalse(pin:IsSuppressed(),
            "Native map-highlight suppression must be cleared after leaving dungeon artwork")
    end
end

local function AssertDungeonArtGeometry()
    local floor = assert(provider.selection.floor and provider.selection.dungeon.floors[provider.selection.floor])
    local imageWidth, imageHeight = provider.ImageFrame:GetSize()
    assertTrue(imageWidth > 0 and imageHeight > 0,
        "Dungeon artwork image must have non-zero dimensions")
    local expectedRatio = (floor.width or 1002) / (floor.height or 668)
    local actualRatio = imageWidth / imageHeight
    assertTrue(math.abs(actualRatio - expectedRatio) < .03,
        "Dungeon artwork must preserve the source floor aspect ratio")
    local visibleTiles = 0
    for _, tile in ipairs(provider.Tiles or {}) do
        if tile:IsShown() then
            visibleTiles = visibleTiles + 1
            local tileWidth, tileHeight = tile:GetSize()
            assertTrue(tileWidth > 0 and tileHeight > 0,
                "Visible dungeon map tiles must keep non-zero dimensions")
        end
    end
    assertTrue(visibleTiles > 0, "Dungeon floor must retain visible map tiles after layout")
end

local function AssertSelectedDungeonFloor(dungeonName, floorIndex, floorName)
    provider = assert(WorldMapFrame.PyresinDungeonMaps,
        "Missing native dungeon-map provider")
    assertTrue(WorldMapFrame:IsShown(), "Dungeon detection must keep the native world map open")
    assertEquals("dungeon", provider.displayMode,
        "Supported dungeon detection must activate illustrated art")
    local selection = assert(provider.selection, "Supported dungeon detection must retain a selection")
    assertEquals(dungeonName, selection.dungeon.name,
        "Instance detection selected the wrong dungeon catalog entry")
    assertEquals(floorIndex, selection.floor,
        "Subzone detection selected the wrong dungeon floor")
    local floor = assert(selection.dungeon.floors[floorIndex])
    assertEquals(floorName, floor.name)
    if dungeonName == "Scholomance" then
        for tileIndex, texture in ipairs(floor.textures) do
            assertEquals("Interface\\WorldMap\\ScholomanceOLD\\ScholomanceOLD"
                .. floorIndex .. "_" .. tileIndex, texture,
                "Rendered Scholomance floor must use the verified client-native texture family")
        end
    elseif dungeonName == "Ragefire Chasm" then
        for tileIndex, texture in ipairs(floor.textures) do
            assertEquals("Interface\\WorldMap\\Ragefire\\Ragefire1_" .. tileIndex, texture,
                "Rendered Ragefire Chasm must use the verified client-native texture family")
        end
    end
    assertEquals(floorName, provider.FloorDropdown:GetDefaultText(),
        "The rendered native floor control must show the detected floor")
    local firstTile = assert(provider.Tiles[1], "Missing first rendered dungeon tile")
    assertTrue(firstTile:IsShown(), "Detected floor artwork must be visible")
    local texture = firstTile:GetTexture()
    assertNotNil(texture, "Detected floor must retain a rendered texture asset")
    return texture
end

local function AssertUnsupportedNativeMap(reason)
    provider = assert(WorldMapFrame.PyresinDungeonMaps)
    assertTrue(WorldMapFrame:IsShown(), reason .. " must leave Blizzard's world map open")
    assertEquals("idle", provider.displayMode, reason .. " must not retain a dungeon route")
    assertNil(provider.selection, reason .. " must not select addon dungeon art")
    assertFalse(provider.ArtFrame:IsShown(), reason .. " must not display stale dungeon artwork")
    AssertNoDungeonNavEntry()
    local arrow = WorldHomeMenuArrow(false)
    if arrow then
        assertFalse(arrow:IsShown(), reason .. " must not expose a stale dungeon return menu")
    end
end

local function AssertDungeonViewportGeometry(resetZoom)
    local scroll = assert(WorldMapFrame:GetCanvasContainer(),
        "Missing native map viewport")
    local scrollLeft, _, scrollRight = UI.PhysicalRect(scroll)
    local questPanel = assert(QuestMapFrame, "Missing native quest map panel")
    if questPanel:IsShown() then
        local questLeft = UI.PhysicalRect(questPanel)
        assertTrue(scrollRight <= questLeft + 1,
            string.format("Native map viewport overlaps quest panel: %.1f > %.1f",
                scrollRight, questLeft))
    end

    if resetZoom then
        WorldMapFrame:ResetZoom(true)
    end
    local pLeft, pBottom, pRight, pTop = UI.PhysicalRect(scroll)
    local imageLeft, imageBottom, imageRight, imageTop = UI.PhysicalRect(provider.ImageFrame)
    assertTrue(imageLeft >= pLeft - 1.5 and imageBottom >= pBottom - 1.5
        and imageRight <= pRight + 1.5 and imageTop <= pTop + 1.5,
        "Dungeon image at native reset zoom must fit the map viewport")

    local first = assert(provider.Tiles[1], "Missing first dungeon tile")
    local last = assert(provider.Tiles[12], "Missing last dungeon tile")
    assertTrue(first:IsShown() and last:IsShown(),
        "Dungeon floor edge tiles must remain visible")
    local firstLeft, _, _, firstTop = UI.PhysicalRect(first)
    local _, lastBottom, lastRight = UI.PhysicalRect(last)
    assertTrue(math.abs(firstLeft - imageLeft) <= 1.5
        and math.abs(firstTop - imageTop) <= 1.5,
        "First dungeon tile must cover the image's top-left edge")
    assertTrue(math.abs(lastRight - imageRight) <= 1.5
        and math.abs(lastBottom - imageBottom) <= 1.5,
        "Last dungeon tile must cover the image's bottom-right edge")
end

UI.Flow("M opens illustrated dungeon art inside Blizzard's native WorldMapFrame", {
    function()
        BeginDungeon()
    end,
    function()
        AssertNativeDungeon()
        AssertDungeonViewportGeometry(false)
        AssertNoDungeonPlayerPin()
        assertTrue(provider.FloorDropdown:IsShown())
    end,
    function()
        local target = assert(provider.selection.dungeon.floors[dungeonFloor == 1 and 2 or 1])
        UI.OpenMenu(provider.FloorDropdown)
        UI.Click(FindMenuOption(provider.FloorDropdown, target.name), UIParent,
            "Native dungeon floor option")
    end,
    function()
        local targetIndex = dungeonFloor == 1 and 2 or 1
        assertTrue(provider.selection.floor ~= dungeonFloor,
            "Selecting a rendered native floor option must change the active floor")
        assertEquals(provider.selection.dungeon.floors[targetIndex].name,
            provider.selection.dungeon.floors[provider.selection.floor].name)
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native map handoff cancels a pending dungeon initial fit", {
    function()
        BeginDungeon()
        -- Move away in the same turn that schedules the first fit.  The
        -- deferred callback must not reapply dungeon zoom to the native map.
        WorldMapFrame:SetMapID(2)
    end,
    function()
        assertTrue(WorldMapFrame:IsShown(),
            "Native world map must remain open during a dungeon handoff")
        assertEquals("world", provider.displayMode,
            "Dungeon provider must deactivate before its deferred fit runs")
        assertFalse(provider.ArtFrame:IsShown(),
            "Dungeon artwork must stay hidden after native navigation")
        assertTrue(WorldMapFrame.NavBar and WorldMapFrame.NavBar:IsShown(),
            "Native navigation controls must be restored after handoff")
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon activation clears only map-owned tooltips", {
    function()
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        -- Leave through the real native World-home action first. The tooltip
        -- fixture is installed only after this handoff, so setup cannot clear it.
        UI.Click(WorldMapFrame.NavBar.homeButton, WorldMapFrame,
            "Native World home before map-owned tooltip fixture")
        assertEquals("world", provider.displayMode)
    end,
    function()
        -- Simulate a tooltip left by a native map canvas child immediately
        -- before the dungeon return leaf activates the illustrated art.
        GameTooltip:SetOwner(WorldMapFrame, "ANCHOR_NONE")
        GameTooltip:Show()
        assertTrue(GameTooltip:IsShown())
        staleReturnItem = FindDungeonReturnMenuItem()
        UI.Click(staleReturnItem, UIParent,
            "Dungeon return with map-owned tooltip visible")
    end,
    function()
        AssertNativeDungeon()
        assertFalse(GameTooltip:IsShown(),
            "Dungeon activation must clear a tooltip owned by WorldMapFrame")

        -- A tooltip belonging to another UI owner is unrelated to the map
        -- handoff and must remain visible through activation/deactivation.
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:Show()
        UI.Click(WorldMapFrame.NavBar.homeButton, WorldMapFrame,
            "Native World home while unrelated tooltip is visible")
    end,
    function()
        assertEquals("world", provider.displayMode)
        assertTrue(GameTooltip:IsShown(),
            "Leaving dungeon artwork must not hide an unrelated tooltip")
        staleReturnItem = FindDungeonReturnMenuItem()
        UI.Click(staleReturnItem, UIParent,
            "Dungeon return while unrelated tooltip is visible")
    end,
    function()
        AssertNativeDungeon()
        assertTrue(GameTooltip:IsShown(),
            "Re-entering dungeon artwork must not hide an unrelated tooltip")
    end,
}, function()
    GameTooltip:Hide()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon navigation stays flat and returns through World menu", {
    function()
        -- Map 84 is an unrelated native fixture. Active dungeon navigation
        -- must collapse to World + the dungeon leaf, without map ancestors.
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Dungeon artwork must retain the selected backing map ID")
        nativeWorldMapID = NativeWorldHomeMapID()

        -- Modified left-click must not navigate the backing outdoor map.
        A_Admin.SetAltKeyDown(true)
        DispatchCanvasClick("LeftButton")
        A_Admin.SetAltKeyDown(false)
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Modified left-click must not navigate the backing outdoor map")
        assertEquals("dungeon", provider.displayMode,
            "Modified left-click must keep dungeon art active")
    end,
    function()
        local target = assert(provider.selection.dungeon.floors[dungeonFloor == 1 and 2 or 1])
        UI.OpenMenu(provider.FloorDropdown)
        UI.Click(FindMenuOption(provider.FloorDropdown, target.name), UIParent,
            "Native dungeon floor option before navigation")
    end,
    function()
        assertTrue(provider.selection.floor ~= 1,
            "The native floor menu must select a different floor before navigation")
        dungeonFloor = provider.selection.floor
        expectedReturnFloor = dungeonFloor
        routeSelection = provider.selection
        assertEquals(2, dungeonFloor,
            "The selected floor fixture must be Deadmines floor two")
    end,
    function()
        -- Native right-click is dispatched through ScrollContainer's real
        -- handlers; only cursor placement is synthetic in this simulator.
        DispatchCanvasClick("RightButton")
    end,
    function()
        assertTrue(WorldMapFrame:IsShown(),
            "Right-click navigation must keep Blizzard's WorldMapFrame open")
        assertEquals("world", provider.displayMode,
            "Right-click must leave dungeon artwork")
        assertEquals(nativeWorldMapID, WorldMapFrame:GetMapID(),
            "Right-click must follow native World-home navigation")
        AssertNativeSurfaceRestored()
        staleReturnItem = FindDungeonReturnMenuItem()
        staleReturnCallback = CaptureDungeonReturnCallback()
        assertEquals(routeSelection, provider.selection,
            "Native browsing must retain the same dungeon selection object")
    end,
    function()
        UI.Click(staleReturnItem, UIParent,
            "Rendered World-menu dungeon return entry")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "World-menu return must restore the original backing map")
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "World-menu return must preserve the selected dungeon floor")
        assertEquals(routeSelection, provider.selection,
            "World-menu return must reuse the retained dungeon selection")
        staleReturnCallback()
        assertEquals("dungeon", provider.displayMode,
            "A stale World-menu callback must not clear an active dungeon selection")
    end,
    function()
        -- The native World home button must perform the same handoff as
        -- right-click, including the same topmost native map destination.
        local nav = assert(WorldMapFrame.NavBar)
        UI.Click(nav.homeButton, WorldMapFrame, "Native World home from dungeon art")
    end,
    function()
        assertEquals("world", provider.displayMode)
        assertEquals(nativeWorldMapID, WorldMapFrame:GetMapID(),
            "Native World-home click must reach the topmost native map")
        AssertNativeSurfaceRestored()
        staleReturnItem = FindDungeonReturnMenuItem()
        staleReturnCallback = CaptureDungeonReturnCallback()
    end,
    function()
        -- Browsing another native map must never append the dungeon leaf.
        WorldMapFrame:SetMapID(13)
        assertEquals(13, WorldMapFrame:GetMapID())
        AssertNoDungeonNavEntry()
        WorldMapFrame:RefreshAllDataProviders()
        WorldMapFrame.NavBar:Refresh()
        AssertNoDungeonNavEntry()
        AssertNativeHomeListUnchanged()
        staleReturnItem = FindDungeonReturnMenuItem()
    end,
    function()
        UI.Click(staleReturnItem, UIParent,
            "Rendered World-menu dungeon return after native browsing")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Native World-menu return must restore the original backing map")
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "Native World-menu return after browsing must preserve the floor")
        assertEquals(routeSelection, provider.selection,
            "Native browsing must not replace the retained dungeon selection")
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon return preserves the existing World-home menu list", {
    function()
        -- The native World home normally has no list function in this fixture.
        -- Install one real shared-return list for this bounded flow so the
        -- addon must copy it instead of appending into the native table.
        BeginDungeonWithSharedHomeList()
    end,
    function()
        AssertNativeDungeon()
        DispatchCanvasClick("RightButton")
    end,
    function()
        AssertNativeSurfaceRestored()
        AssertNativeHomeListUnchanged()
        local nav = assert(WorldMapFrame.NavBar)
        local home = assert(nav.homeButton)
        local entries = assert(home.listFunc(home))
        assertEquals(2, #entries,
            "Dungeon return setup must append one entry to the copied native menu")
        assertEquals("Native home fixture", entries[1].text)
        staleReturnItem = FindDungeonReturnMenuItem()
    end,
    function()
        UI.Click(staleReturnItem, UIParent,
            "Rendered return entry after preserving the native menu list")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID())
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon return cleanup restores World-home state on close", {
    function()
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        DispatchCanvasClick("RightButton")
    end,
    function()
        AssertNativeSurfaceRestored()
        staleReturnItem = FindDungeonReturnMenuItem()
        staleReturnCallback = CaptureDungeonReturnCallback()
        local close = assert(WorldMapFrame.BorderFrame.CloseButton,
            "Missing native world-map close button")
        UI.Click(close, UIParent, "Close native map with dungeon return route")
    end,
    function()
        assertFalse(WorldMapFrame:IsShown())
        assertEquals("idle", provider.displayMode)
        assertNil(provider.selection, "Closing the native map must clear the dungeon return selection")
        AssertNoDungeonNavEntry()
        AssertHomeBaselineRestored()

        -- A previously rendered menu callback must not resurrect a closed route.
        staleReturnCallback()
        assertEquals("idle", provider.displayMode,
            "A stale World-menu callback must not reactivate after close")
        ToggleWorldMap()
        assertTrue(WorldMapFrame:IsShown())
        AssertNativeDungeon()
    end,
}, function()
    staleReturnItem = nil
    staleReturnCallback = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon return cleanup restores World-home state when disabled", {
    function()
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        DispatchCanvasClick("RightButton")
    end,
    function()
        AssertNativeSurfaceRestored()
        staleReturnItem = FindDungeonReturnMenuItem()
        staleReturnCallback = CaptureDungeonReturnCallback()
        local setting = assert(Settings.GetSetting("PyresinQoL_DungeonMapsEnabled"))
        settingOriginal = setting:GetValue()
        setting:SetValue(false)
    end,
    function()
        assertEquals("idle", provider.displayMode)
        assertNil(provider.selection)
        AssertNoDungeonNavEntry()
        AssertHomeBaselineRestored()
        staleReturnCallback()
        assertEquals("idle", provider.displayMode,
            "A stale World-menu callback must not reactivate after disable")
    end,
}, function()
    local setting = Settings.GetSetting("PyresinQoL_DungeonMapsEnabled")
    if setting and settingOriginal ~= nil then setting:SetValue(settingOriginal) end
    settingOriginal = nil
    staleReturnItem = nil
    staleReturnCallback = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon return cleanup restores World-home state after instance invalidation", {
    function()
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        DispatchCanvasClick("RightButton")
    end,
    function()
        AssertNativeSurfaceRestored()
        staleReturnItem = FindDungeonReturnMenuItem()
        staleReturnCallback = CaptureDungeonReturnCallback()
        -- Keep the same native party fixture but change the instance ID to an
        -- unsupported value. This exercises the real selection-validity path.
        InstallDungeonInstance("Unknown instance", 999)
        A_Admin.SetSubZone("Unknown shared area")
        A_Admin.FireEvent("ZONE_CHANGED_NEW_AREA")
    end,
    function()
        assertEquals("idle", provider.displayMode)
        assertNil(provider.selection)
        AssertNoDungeonNavEntry()
        AssertHomeBaselineRestored()
        staleReturnCallback()
        assertEquals("idle", provider.displayMode,
            "A stale World-menu callback must not reactivate after instance invalidation")
    end,
}, function()
    staleReturnItem = nil
    staleReturnCallback = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon map keeps Blizzard zoom, pan, close and minimize controls", {
    function()
        BeginDungeon()
    end,
    function()
        AssertNativeDungeon()
        assertType("function", WorldMapFrame.ZoomIn)
        assertType("function", WorldMapFrame.ZoomOut)
        assertType("function", WorldMapFrame.PanTo)
        assertType("function", WorldMapFrame.ResetZoom)
        assertTrue(WorldMapFrame:HasZoomLevels(), "Native world map zoom must remain available")
        local scale = WorldMapFrame:GetCanvasScale()
        WorldMapFrame:ZoomIn()
        assertTrue(WorldMapFrame:GetCanvasScale() > scale or WorldMapFrame:IsZoomingIn(),
            "Native zoom-in did not change the map view")
        WorldMapFrame:ResetZoom()
    end,
    function()
        local scroll = WorldMapFrame:GetCanvasContainer()
        assertType("function", scroll:GetScript("OnMouseWheel"),
            "Native map viewport must retain its mouse-wheel handler")
        assertType("function", scroll:GetScript("OnMouseDown"),
            "Native map viewport must retain its drag-start handler")
        assertType("function", scroll:GetScript("OnMouseUp"),
            "Native map viewport must retain its drag-end handler")
        WorldMapFrame:ResetZoom()
        local wheelScale = scroll:GetCanvasScale()
        -- wow-cli supports mouse-move IPC for hover rendering, but this
        -- deterministic wheel check intentionally dispatches the native
        -- callback directly; the physical right-button limitation is covered
        -- by DispatchCanvasClick below with the same native scripts.
        scroll:GetScript("OnMouseWheel")(scroll, 1)
        assertTrue(scroll:GetCanvasScale() > wheelScale or scroll:IsZoomingIn(),
            "Native map mouse-wheel dispatch must retain zoom behavior")
    end,
    function()
        local scroll = WorldMapFrame:GetCanvasContainer()
        scroll:GetScript("OnMouseDown")(scroll, "LeftButton")
        assertTrue(scroll:IsPanning(), "Native map drag-start dispatch must enter panning state")
        scroll:GetScript("OnMouseUp")(scroll, "LeftButton")
        panBeforeX, panBeforeY = scroll:GetHorizontalScroll(), scroll:GetVerticalScroll()
        WorldMapFrame:PanTo(.8, .2)
    end,
    function()
        local scroll = WorldMapFrame:GetCanvasContainer()
        local afterX, afterY = scroll:GetHorizontalScroll(), scroll:GetVerticalScroll()
        assertTrue(afterX ~= panBeforeX or afterY ~= panBeforeY,
            "Native map pan did not change the canvas scroll position")
        local maxMin = assert(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame)
        if not maxMin.MinimizeButton:IsShown() then
            assertTrue(maxMin.MaximizeButton:IsShown())
            UI.Click(maxMin.MaximizeButton, WorldMapFrame, "Native map maximize from minimized state")
        end
        assertTrue(maxMin.MinimizeButton:IsShown())
        UI.Click(maxMin.MinimizeButton, WorldMapFrame, "Native map minimize")
        assertTrue(maxMin:IsMinimized())
        UI.Click(maxMin.MaximizeButton, WorldMapFrame, "Native map maximize")
        assertFalse(maxMin:IsMinimized())
    end,
    function()
        local close = assert(WorldMapFrame.BorderFrame.CloseButton, "Missing native world-map close button")
        UI.Click(close, UIParent, "Native world-map close")
        assertFalse(WorldMapFrame:IsShown())
        assertEquals("idle", provider.displayMode)
        assertNil(provider.selection, "Closing the native map must clear the retained dungeon route")
        ToggleWorldMap()
        assertTrue(WorldMapFrame:IsShown())
        AssertNativeDungeon()
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon art survives provider refresh and viewport resize", {
    function()
        BeginDungeon()
    end,
    function()
        AssertNativeDungeon()
        AssertDungeonArtGeometry()
        AssertDungeonViewportGeometry(true)
        assertType("function", WorldMapFrame.RefreshAllDataProviders)
        WorldMapFrame:RefreshAllDataProviders()
        local maxMin = assert(WorldMapFrame.BorderFrame.MaximizeMinimizeFrame,
            "Missing native map resize controls")
        resizeWasMinimized = maxMin:IsMinimized()
        if resizeWasMinimized then
            UI.Click(maxMin.MaximizeButton, WorldMapFrame,
                "Native map maximize before resize regression")
        else
            UI.Click(maxMin.MinimizeButton, WorldMapFrame,
                "Native map minimize before resize regression")
        end
    end,
    function()
        local maxMin = WorldMapFrame.BorderFrame.MaximizeMinimizeFrame
        assertEquals(not resizeWasMinimized, maxMin:IsMinimized(),
            "Native map resize control must change the display state")
        if resizeWasMinimized then
            UI.Click(maxMin.MinimizeButton, WorldMapFrame,
                "Native map restore minimized state")
        else
            UI.Click(maxMin.MaximizeButton, WorldMapFrame,
                "Native map restore maximized state")
        end
    end,
    function()
        local maxMin = WorldMapFrame.BorderFrame.MaximizeMinimizeFrame
        assertEquals(resizeWasMinimized, maxMin:IsMinimized(),
            "Native map resize flow must restore its original state")
        assertEquals("dungeon", provider.displayMode, "Refreshing native map providers must retain dungeon activation")
        assertTrue(provider.ArtFrame:IsShown(), "Refreshing native map providers must retain dungeon artwork")
        assertEquals("The Deadmines", provider.selection.dungeon.name)
        AssertNoDungeonPlayerPin()
        AssertDungeonArtGeometry()
        AssertDungeonViewportGeometry()
    end,
}, function()
    resizeWasMinimized = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native world-map navigation leaves and re-enters dungeon artwork", {
    function()
        BeginDungeon()
    end,
    function()
        AssertNativeDungeon()
        -- The illustrated Deadmines provider is layered on the simulator's
        -- initial world map (map 1), so map 2 is the real native navigation
        -- transition that must deactivate it while the instance is unchanged.
        WorldMapFrame:SetMapID(2)
    end,
    function()
        assertEquals(2, WorldMapFrame:GetMapID(), "Native map navigation should reach the normal world map")
        assertFalse(provider.ArtFrame:IsShown(), "Dungeon artwork must be hidden outside the dungeon")
        AssertNativeSurfaceRestored()
        A_Admin.SetZone("Stormwind City", 1519)
        A_Admin.SetSubZone("Trade District")
        A_Admin.FireEvent("ZONE_CHANGED_NEW_AREA")
        assertFalse(provider.ArtFrame:IsShown(),
            "Changing zones while native navigation is active must not reactivate dungeon artwork")
        InstallDungeonInstance("The Deadmines", 36)
        A_Admin.SetSubZone("Goblin Foundry")
        A_Admin.FireEvent("ZONE_CHANGED_NEW_AREA")
        assertFalse(provider.ArtFrame:IsShown(), "SetMapID navigation must stay inactive until native map close")
    end,
    function()
        ToggleWorldMap()
        assertFalse(WorldMapFrame:IsShown())
        ToggleWorldMap()
        AssertNativeDungeon()
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("native dungeon detection selects and follows known catalog subzones", {
    function()
        BeginInstance("Scholomance", 289, "The Laboratory")
    end,
    function()
        detectedFloorTexture = AssertSelectedDungeonFloor(
            "Scholomance", 4, "The Laboratory and Vaults")
        A_Admin.SetSubZone("Chamber of Summoning")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        local texture = AssertSelectedDungeonFloor("Scholomance", 2, "Chamber of Summoning")
        assertTrue(texture ~= detectedFloorTexture,
            "Known subzone movement must replace the visible floor artwork")
        detectedFloorTexture = texture
        A_Admin.SetSubZone("Hall of Secrets")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        local texture = AssertSelectedDungeonFloor(
            "Scholomance", 3, "The Great Ossuary and Headmaster's Study")
        assertTrue(texture ~= detectedFloorTexture,
            "The third Scholomance floor must replace the visible artwork")
        detectedFloorTexture = texture
        A_Admin.SetSubZone("The Reliquary")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        local texture = AssertSelectedDungeonFloor("Scholomance", 1, "The Reliquary")
        assertTrue(texture ~= detectedFloorTexture,
            "A second known subzone movement must replace the visible floor artwork")
    end,
}, function()
    detectedFloorTexture = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("Ragefire Chasm renders the client-native original-layout tiles", {
    function()
        BeginInstance("Ragefire Chasm", 389, "Ragefire Chasm")
    end,
    function()
        AssertSelectedDungeonFloor("Ragefire Chasm", 1, "Ragefire Chasm")
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("unknown and localized subzones use honest floor fallback rules", {
    function()
        BeginInstance("The Deadmines", 36, "Ironclad Cove")
    end,
    function()
        detectedFloorTexture = AssertSelectedDungeonFloor("The Deadmines", 2, "Ironclad Cove")
        HideNativeMap()
        A_Admin.SetSubZone("Eisenbucht")
        ToggleWorldMap()
    end,
    function()
        local texture = AssertSelectedDungeonFloor("The Deadmines", 1, "The Deadmines")
        assertTrue(texture ~= detectedFloorTexture,
            "Fresh unknown-subzone fallback must not reuse the previously selected floor artwork")
        assertTrue(provider.FloorDropdown:IsShown())
        UI.OpenMenu(provider.FloorDropdown)
        UI.Click(FindMenuOption(provider.FloorDropdown, "Ironclad Cove"), UIParent,
            "Manual floor after unmatched localized subzone")
    end,
    function()
        AssertSelectedDungeonFloor("The Deadmines", 2, "Ironclad Cove")
        A_Admin.SetSubZone("Unmapped passage")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        AssertSelectedDungeonFloor("The Deadmines", 2, "Ironclad Cove")
        A_Admin.SetSubZone("Goblin Foundry")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        AssertSelectedDungeonFloor("The Deadmines", 1, "The Deadmines")
    end,
}, function()
    detectedFloorTexture = nil
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("unsupported raids and Forever instances restore the native map", {
    function()
        BeginDungeon()
    end,
    function()
        AssertSelectedDungeonFloor("The Deadmines", 1, "The Deadmines")
        InstallDungeonInstance("Molten Core", 409, "raid")
        A_Admin.SetSubZone("Molten Core")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        AssertUnsupportedNativeMap("A raid instance")
        AssertHomeBaselineRestored()
        assertTrue(provider.NativeCoordsPanel:IsShown(),
            "Leaving supported dungeon art for a raid must restore native coordinates")
        assertTrue(provider.NativeAreaLabel:IsShown(),
            "Leaving supported dungeon art for a raid must restore native area labels")
        for pin in WorldMapFrame:EnumeratePinsByTemplate("GroupMembersPinTemplate") do
            assertFalse(pin:IsSuppressed(),
                "Leaving supported dungeon art for a raid must restore native pins")
        end
        HideNativeMap()
        OpenDungeon("Hall of Thanes", 3065, "Hall of Thanes")
    end,
    function()
        AssertUnsupportedNativeMap("The new Hall of Thanes party instance")
        HideNativeMap()
        OpenDungeon("Ruins of Lordaeron", 2999, "Ruins of Lordaeron")
    end,
    function()
        AssertUnsupportedNativeMap("The new Ruins of Lordaeron party instance")
        HideNativeMap()
        OpenDungeon("Unknown party instance", 987654, "Unknown area")
    end,
    function()
        AssertUnsupportedNativeMap("An unknown party instance")
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("missing original Vanilla layouts never display substitute dungeon art", {
    function()
        BeginInstance("The Temple of Atal'Hakkar", 109, "The Temple of Atal'Hakkar")
    end,
    function()
        provider = assert(WorldMapFrame.PyresinDungeonMaps)
        assertTrue(WorldMapFrame:IsShown(), "M must still open Blizzard's map for an unmapped dungeon")
        assertFalse(provider.ArtFrame:IsShown(), "Sunken Temple must not display removed Atlas art")
        assertNil(provider.selection)
        HideNativeMap()
        OpenDungeon("Blackrock Spire", 229, "Hordemar City")
    end,
    function()
        provider = assert(WorldMapFrame.PyresinDungeonMaps)
        assertTrue(provider.displayMode == "dungeon" and provider.ArtFrame:IsShown(),
            "A recognized Lower Blackrock Spire subzone must retain its native-art map")
        assertEquals("Lower Blackrock Spire", provider.selection.dungeon.name)
        assertEquals(229, provider.selection.dungeon.instanceID,
            "Recognized LBRS detection must use the single physical-instance catalog entry")
        A_Admin.SetSubZone("Hall of Blackhand")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        assertEquals("world", provider.displayMode,
            "Shared Hall of Blackhand must not guess the Lower Blackrock Spire wing")
        assertFalse(provider.ArtFrame:IsShown(),
            "Shared Hall of Blackhand must not display a false wing map")
        assertNil(provider.selection)
        HideNativeMap()
        OpenDungeon("Blackrock Spire", 229, "Hordemar City")
    end,
    function()
        assertEquals("dungeon", provider.displayMode)
        assertEquals("Lower Blackrock Spire", provider.selection.dungeon.name)
        A_Admin.SetSubZone("The Rookery")
        A_Admin.FireEvent("ZONE_CHANGED_INDOORS")
    end,
    function()
        assertEquals("world", provider.displayMode, "A recognized Upper Blackrock Spire subzone must close LBRS art")
        assertFalse(provider.ArtFrame:IsShown(), "Upper Blackrock Spire must not retain stale LBRS art")
        assertNil(provider.selection)
        HideNativeMap()
        OpenDungeon("Blackrock Spire", 229, "Unknown shared area")
    end,
    function()
        assertFalse(provider.ArtFrame:IsShown(),
            "An unknown shared Blackrock Spire subzone must not guess a wing map")
        assertNil(provider.selection)
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil end
end)

UI.Flow("disabled dungeon maps leave Blizzard's native world map unchanged", {
    function()
        HideNativeMap()
        originalInstanceInfo = GetInstanceInfo
        local setting = assert(Settings.GetSetting("PyresinQoL_DungeonMapsEnabled"))
        local original = setting:GetValue()
        restoreDungeon = function()
            setting:SetValue(original)
            HideNativeMap()
            GetInstanceInfo = originalInstanceInfo
            A_Admin.SetInstanceInfo("Stormwind City", "none", 0, 0)
            A_Admin.SetInInstance(false)
        end
        setting:SetValue(false)
        if C_Map and C_Map.SetMapForQuestLog then C_Map.SetMapForQuestLog(1) end
        OpenDungeon("The Deadmines", 36)
    end,
    function()
        assertTrue(WorldMapFrame:IsShown())
        provider = assert(WorldMapFrame.PyresinDungeonMaps)
        assertFalse(provider.ArtFrame:IsShown(), "Disabled dungeon maps must not replace native world-map content")
        assertNil(provider.selection)
    end,
}, function()
    if restoreDungeon then restoreDungeon(); restoreDungeon = nil else HideNativeMap() end
end)
