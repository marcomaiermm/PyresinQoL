local UI = PyresinQoLUITest

local provider, originalInstanceInfo, restoreDungeon, dungeonFloor, expectedReturnFloor, routeSelection, panBeforeX, panBeforeY
local resizeWasMinimized
local nativeBackingMapID
local SetNativeBackingMap

local function HideNativeMap()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        HideUIPanel(WorldMapFrame)
    end
end

local function InstallDungeonInstance(name, instanceID)
    A_Admin.SetInstanceInfo(name, "party", 1, 5)
    -- The simulator's admin API does not populate the instance map ID. Keep
    -- this one documented tuple fixture; all native C_Map APIs remain intact.
    GetInstanceInfo = function()
        local values = { originalInstanceInfo() }
        values[8] = instanceID
        return unpack(values, 1, 10)
    end
end

local function OpenDungeon(name, instanceID, subzone)
    InstallDungeonInstance(name, instanceID)
    A_Admin.SetSubZone(subzone or "Goblin Foundry")
    ToggleWorldMap()
end

local function BeginInstance(name, instanceID, subzone, backingMapID)
    HideNativeMap()
    originalInstanceInfo = GetInstanceInfo
    restoreDungeon = function()
        HideNativeMap()
        if PyresinQoLDungeonMapFrame then PyresinQoLDungeonMapFrame:Hide() end
        if A_Admin.SetMouseOverFrame then A_Admin.SetMouseOverFrame(nil) end
        if A_Admin.SetAltKeyDown then A_Admin.SetAltKeyDown(false) end
        GetInstanceInfo = originalInstanceInfo
        A_Admin.SetInstanceInfo("Stormwind City", "none", 0, 0)
        A_Admin.SetInInstance(false)
        A_Admin.SetZone("Stormwind City", 1519)
        A_Admin.SetSubZone("Trade District")
        if C_Map and C_Map.SetMapForQuestLog then C_Map.SetMapForQuestLog(1) end
        nativeBackingMapID = nil
        expectedReturnFloor = nil
        routeSelection = nil
    end
    if backingMapID then SetNativeBackingMap(backingMapID) end
    OpenDungeon(name, instanceID, subzone)
end

local function BeginDungeon()
    BeginInstance("The Deadmines", 36, "Goblin Foundry")
end

local function BeginDungeonOnMap(mapID)
    BeginInstance("The Deadmines", 36, "Goblin Foundry", mapID)
end

SetNativeBackingMap = function(mapID)
    assert(C_Map and C_Map.SetMapForQuestLog, "Native map fixture is unavailable")
    C_Map.SetMapForQuestLog(mapID)
    WorldMapFrame:SetMapID(mapID)
    nativeBackingMapID = mapID
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

local function FindNativeNavButton(mapID)
    local nav = assert(WorldMapFrame.NavBar, "Missing native map navigation bar")
    for _, button in ipairs(nav.navList or {}) do
        if button.data and button.data.id == mapID then
            return button
        end
    end
    error("Missing native breadcrumb for map " .. tostring(mapID))
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
    assertEquals(dungeonButton, provider.NavBarDungeonButton)
    assertTrue(dungeonButton:IsVisible(), "Dungeon return breadcrumb must be rendered")
    assertFalse(dungeonButton:IsEnabled(), "Active dungeon breadcrumb must be disabled")
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
    local dungeonButton = FindDungeonNavButton()
    assertTrue(dungeonButton:IsEnabled(),
        "Dungeon breadcrumb must be enabled as a return route outside dungeon art")
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
        -- Leave through the real native parent first. The tooltip fixture is
        -- installed only after this handoff, so setup cannot clear it.
        UI.Click(FindNativeNavButton(84), WorldMapFrame,
            "Native parent before map-owned tooltip fixture")
        assertEquals("world", provider.displayMode)
    end,
    function()
        -- Simulate a tooltip left by a native map canvas child immediately
        -- before the dungeon return leaf activates the illustrated art.
        GameTooltip:SetOwner(WorldMapFrame, "ANCHOR_NONE")
        GameTooltip:Show()
        assertTrue(GameTooltip:IsShown())
        UI.Click(FindDungeonNavButton(), WorldMapFrame,
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
        UI.Click(FindNativeNavButton(84), WorldMapFrame,
            "Native parent while unrelated tooltip is visible")
    end,
    function()
        assertEquals("world", provider.displayMode)
        assertTrue(GameTooltip:IsShown(),
            "Leaving dungeon artwork must not hide an unrelated tooltip")
        UI.Click(FindDungeonNavButton(), WorldMapFrame,
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

UI.Flow("native dungeon breadcrumbs round-trip through the backing world map", {
    function()
        -- Map 84 is a seeded native backing map with a rendered breadcrumb.
        -- The addon leaf is appended below this map and must not skip it.
        BeginDungeonOnMap(84)
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Dungeon artwork must retain the native backing map ID")
        local native = FindNativeNavButton(84)
        assertTrue(native:IsVisible(), "The native current-map breadcrumb must render")
        assertTrue(native:IsEnabled(), "The native backing-map breadcrumb must remain selectable")

        -- Left and modified-left clicks are consumed while the illustrated
        -- map is active; they must not navigate the outdoor native map.
        local before = WorldMapFrame:GetMapID()
        A_Admin.SetAltKeyDown(true)
        DispatchCanvasClick("LeftButton")
        A_Admin.SetAltKeyDown(false)
        assertEquals(before, WorldMapFrame:GetMapID(),
            "Modified left-click must not navigate the backing outdoor map")
        assertEquals("dungeon", provider.displayMode, "Modified left-click must keep dungeon art active")
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
        -- The native backing breadcrumb is an immediate parent action even
        -- when it resolves to the same C_Map ID as the custom artwork.
        local native = FindNativeNavButton(84)
        assertTrue(native:IsEnabled(), "The immediate native parent must be clickable")
        UI.Click(native, WorldMapFrame, "Immediate native backing breadcrumb")
    end,
    function()
        assertTrue(WorldMapFrame:IsShown())
        assertEquals("world", provider.displayMode,
            "Clicking the immediate native parent must leave dungeon artwork")
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Immediate native parent must retain the backing map ID")
        AssertNativeSurfaceRestored()
        assertEquals(routeSelection, provider.selection,
            "Native browsing must retain the same dungeon selection object")
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "Leaving through the native parent must preserve the selected floor")
    end,
    function()
        UI.Click(FindDungeonNavButton(), WorldMapFrame,
            "Native dungeon return breadcrumb after immediate parent")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID())
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "Native breadcrumb return must preserve the selected dungeon floor")
        assertEquals(routeSelection, provider.selection,
            "Breadcrumb return must reuse the retained dungeon selection")
    end,
    function()
        -- This is the native Blizzard ScrollContainer mouse path.  The
        -- simulator has no right-button CLI event, so only cursor placement
        -- is synthetic; OnMouseDown/OnMouseUp and canvas handler dispatch are
        -- the real native scripts.
        DispatchCanvasClick("RightButton")
    end,
    function()
        assertTrue(WorldMapFrame:IsShown(),
            "Right-click navigation must keep Blizzard's WorldMapFrame open")
        assertEquals("world", provider.displayMode, "Right-click must leave dungeon artwork")
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Right-click must reveal the logical backing map without skipping it")
        AssertNativeSurfaceRestored()
        local native = FindNativeNavButton(84)
        assertEquals("Stormwind City", native:GetText(),
            "The native backing breadcrumb must remain the current map")
    end,
    function()
        local dungeonButton = FindDungeonNavButton()
        assertTrue(dungeonButton:IsVisible() and dungeonButton:IsEnabled(),
            "The rendered dungeon breadcrumb must provide a return route")
        UI.Click(dungeonButton, WorldMapFrame, "Native dungeon return breadcrumb")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Returning through the native breadcrumb must restore the original backing map")
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "Native breadcrumb return must preserve the selected dungeon floor")
    end,
    function()
        DispatchCanvasClick("RightButton")
    end,
    function()
        assertTrue(WorldMapFrame:IsShown())
        assertEquals("world", provider.displayMode)
        assertEquals(84, WorldMapFrame:GetMapID(),
            "A second right-click must still reveal the same logical backing map")
        AssertNativeSurfaceRestored()
    end,
    function()
        -- Browsing another native map while outside the dungeon must not
        -- destroy the route back to the original backing map.
        WorldMapFrame:SetMapID(13)
        assertEquals(13, WorldMapFrame:GetMapID())
        assertEquals("world", provider.displayMode)
        local native = FindNativeNavButton(13)
        assertTrue(native:IsVisible(), "Native browsing must render the current-map breadcrumb")
        assertEquals("Eastern Kingdoms", native:GetText(),
            "Native browsing must keep the correct current-map breadcrumb")
        assertTrue(FindDungeonNavButton():IsEnabled(),
            "The dungeon return leaf must remain enabled while browsing native maps")
    end,
    function()
        UI.Click(FindDungeonNavButton(), WorldMapFrame,
            "Dungeon return after browsing another native map")
    end,
    function()
        AssertNativeDungeon()
        assertEquals(84, WorldMapFrame:GetMapID(),
            "Dungeon return must restore the original backing map after native browsing")
        assertEquals(expectedReturnFloor, provider.selection.floor,
            "Dungeon return after native browsing must preserve the selected floor")
        assertEquals(routeSelection, provider.selection,
            "Arbitrary native browsing must not replace the retained selection")
    end,
}, function()
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
        A_Admin.SetSubZone("The Rookery")
        A_Admin.FireEvent("ZONE_CHANGED_NEW_AREA")
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
