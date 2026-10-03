local _, ns = ...
local L, maps = ns.L, ns.DungeonMaps

ns.RegisterModule("dungeonMaps", function(module)
    local installed
    local MODE_IDLE, MODE_DUNGEON, MODE_WORLD = "idle", "dungeon", "world"

    local function Enabled()
        return PyresinQoLDB.dungeonMapsEnabled ~= false
    end

    local function InstanceInfo()
        local ok, _, instanceType, _, _, _, _, _, instanceID = pcall(GetInstanceInfo)
        if not ok or instanceType ~= "party" then return nil end
        return instanceID
    end

    local function Public(value)
        if issecretvalue and issecretvalue(value) then return nil end
        return value
    end

    local function HasNativeDungeonMap(map)
        if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetMapInfo or not C_Map.GetMapArtLayers
            or not Enum or not Enum.UIMapType then return false end
        local ok, bestMapID = pcall(C_Map.GetBestMapForUnit, "player")
        bestMapID = ok and Public(bestMapID) or nil
        if type(bestMapID) ~= "number" or bestMapID ~= Public(map:GetMapID()) then return false end
        local infoOK, info = pcall(C_Map.GetMapInfo, bestMapID)
        if not infoOK or Public(info) == nil then return false end
        local typeOK, mapType = pcall(function() return Public(info.mapType) end)
        if not typeOK or mapType ~= Enum.UIMapType.Dungeon then return false end
        local layersOK, layers = pcall(C_Map.GetMapArtLayers, bestMapID)
        if not layersOK or type(layers) ~= "table" then return false end
        for _, layer in ipairs(layers) do
            local layerOK, width, height = pcall(function()
                return tonumber(Public(layer.layerWidth)), tonumber(Public(layer.layerHeight))
            end)
            if layerOK and width and height and width > 0 and height > 0 then return true end
        end
        return false
    end

    local function SetInteraction(map, navigate, zoom, pan)
        if map.SetShouldNavigateOnClick then map:SetShouldNavigateOnClick(navigate) end
        if map.SetShouldZoomInOnClick then map:SetShouldZoomInOnClick(zoom) end
        if map.SetShouldPanOnClick then map:SetShouldPanOnClick(pan) end
    end

    local function GetInteraction(map)
        return {
            navigate = map.ShouldNavigateOnClick and map:ShouldNavigateOnClick(),
            zoom = map.ShouldZoomInOnClick and map:ShouldZoomInOnClick(),
            pan = map.ShouldPanOnClick and map:ShouldPanOnClick(),
        }
    end

    local function FindNativeSurface(map, provider)
        for _, overlay in ipairs(map.overlayFrames or {}) do
            if WorldMapFloorNavigationFrameMixin
                and overlay.RefreshMenu == WorldMapFloorNavigationFrameMixin.RefreshMenu then
                provider.NativeFloorDropdown = overlay
            elseif WorldMapCoordsPanelMixin and overlay.OnUpdate == WorldMapCoordsPanelMixin.OnUpdate then
                provider.NativeCoordsPanel = overlay
            end
        end
        for dataProvider in pairs(map.dataProviders or {}) do
            if AreaLabelDataProviderMixin and dataProvider.OnSetAreaLabel == AreaLabelDataProviderMixin.OnSetAreaLabel then
                provider.NativeAreaLabel = dataProvider.Label
            end
        end
    end

    local function CreateProvider(map)
        local canvas = map:GetCanvas()
        local container = map:GetCanvasContainer()
        local provider = { map = map, Tiles = {}, suppressedPins = {}, displayMode = MODE_IDLE }
        map.PyresinDungeonMaps = provider

        function provider:GetMap() return self.map end

        local art = CreateFrame("Frame", nil, canvas)
        art:SetAllPoints(canvas)
        art:SetFrameLevel(canvas:GetFrameLevel() + 50)
        art:EnableMouse(false)
        art:Hide()
        provider.ArtFrame = art

        local background = art:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(.018, .014, .01, 1)
        provider.Background = background

        local image = CreateFrame("Frame", nil, art)
        image:SetPoint("CENTER")
        image:SetFrameLevel(art:GetFrameLevel() + 1)
        provider.ImageFrame = image

        for index = 1, 12 do
            provider.Tiles[index] = image:CreateTexture(nil, "ARTWORK")
            provider.Tiles[index]:Hide()
        end

        local controls = CreateFrame("Frame", nil, map)
        controls:SetAllPoints(map)
        controls:SetFrameLevel(art:GetFrameLevel() + 20)
        controls:EnableMouse(false)
        provider.ControlsFrame = controls

        local floorDropdown = CreateFrame("DropdownButton", nil, map, "WowStyle1DropdownTemplate")
        floorDropdown:SetFrameLevel(controls:GetFrameLevel() + 1)
        floorDropdown:SetPoint("TOPLEFT", container, "TOPLEFT", 2, 0)
        floorDropdown:SetWidth(210)
        floorDropdown:Hide()
        provider.FloorDropdown = floorDropdown

        local status = controls:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        status:SetPoint("BOTTOM", container, "BOTTOM", 0, 8)
        status:SetText(L.dungeonMapsPositionUnavailable)
        status:SetTextColor(.85, .82, .72)
        status:Hide()
        provider.Status = status

        function provider:LayoutImage()
            local selection = self.selection
            local floor = selection and selection.dungeon.floors[selection.floor]
            if not floor then return end
            local sourceWidth, sourceHeight = floor.width or 1002, floor.height or 668
            local availableWidth, availableHeight = art:GetWidth(), art:GetHeight()
            if not availableWidth or not availableHeight or availableWidth <= 0 or availableHeight <= 0 then return end
            local width, height = availableWidth, availableWidth * sourceHeight / sourceWidth
            if height > availableHeight then
                height = availableHeight
                width = availableHeight * sourceWidth / sourceHeight
            end
            image:SetSize(width, height)
        end

        function provider:DrawFloor(floor)
            for _, tile in ipairs(self.Tiles) do tile:Hide() end
            if not floor then return end
            self:LayoutImage()
            local width, height = floor.width or 1002, floor.height or 668
            for index, asset in ipairs(floor.textures or {}) do
                local column, row = (index - 1) % 4, math.floor((index - 1) / 4)
                local sourceWidth = math.min(256, width - column * 256)
                local sourceHeight = math.min(256, height - row * 256)
                local tile = self.Tiles[index]
                if sourceWidth > 0 and sourceHeight > 0 then
                    tile:ClearAllPoints()
                    tile:SetPoint("TOPLEFT", image, "TOPLEFT", column * 256 / width * image:GetWidth(),
                        -row * 256 / height * image:GetHeight())
                    tile:SetSize(sourceWidth / width * image:GetWidth(), sourceHeight / height * image:GetHeight())
                    tile:SetTexCoord(0, sourceWidth / 256, 0, sourceHeight / 256)
                    tile:SetTexture(asset)
                    tile:Show()
                end
            end
        end

        function provider:DisplayFloor(index)
            if self.displayMode ~= MODE_DUNGEON then return end
            local selection = self.selection
            local dungeon = selection and selection.dungeon
            if not dungeon then return end
            index = math.max(1, math.min(#dungeon.floors, index or 1))
            selection.floor = index
            local floor = dungeon.floors[index]
            floorDropdown:SetDefaultText(floor.name or L.dungeonMapsFloor:format(index))
            floorDropdown:SetShown(#dungeon.floors > 1)
            self:DrawFloor(floor)
        end

        floorDropdown:SetupMenu(function(_, root)
            local selection = provider.selection
            local dungeon = selection and selection.dungeon
            if not dungeon then return end
            for index, floor in ipairs(dungeon.floors) do
                root:CreateRadio(floor.name or L.dungeonMapsFloor:format(index),
                    function(value) return provider.selection and provider.selection.floor == value end,
                    function(value) provider:DisplayFloor(value) end, index)
            end
        end)

        function art:IsPinSuppressor() return true end
        function art:ShouldSuppressPin(pin) return pin ~= self end
        function art:TrackSuppressedPin(pin) self.suppressedPins[pin] = true end
        function art:FinalizeSuppression() end
        function art:ResetSuppression()
            for pin in pairs(self.suppressedPins) do
                if pin.GetPinSuppressor and pin:GetPinSuppressor() == self then
                    pin:ClearSuppression()
                    if not pin.GetMap or pin:GetMap() ~= map then pin:Hide() end
                end
                self.suppressedPins[pin] = nil
            end
        end
        art.suppressedPins = provider.suppressedPins

        function provider:RestoreDungeonReturnMenu()
            local nav = map.NavBar
            local home = nav and nav.homeButton
            local saved = self.HomeButtonState
            if not home or not saved then return end
            home.listFunc = saved.listFunc
            home:SetWidth(saved.width)
            if saved.arrow then
                saved.arrow:SetShown(saved.arrowShown)
                if NavButtonTemplate_SetupDropdown and saved.listFunc then
                    NavButtonTemplate_SetupDropdown(home, saved.arrow)
                end
            end
            self.HomeButtonState = nil
            if NavBar_CheckLength then NavBar_CheckLength(nav) end
        end

        function provider:ExposeDungeonReturnMenu()
            local nav = map.NavBar
            local home = nav and nav.homeButton
            local selection = self.selection
            local dungeon = selection and selection.dungeon
            if not home or not dungeon or not NavButtonTemplate_SetupDropdown then return end
            local arrow = home.MenuArrowButton
            local addonArrow = false
            if not arrow then
                addonArrow = true
                if not self.HomeMenuArrowButton then
                    arrow = CreateFrame("DropdownButton", nil, home, "WowStyle1ArrowDropdownTemplate")
                    arrow:SetPoint("RIGHT", home, "RIGHT", -4, 0)
                    arrow:SetFrameLevel(home:GetFrameLevel() + 2)
                    arrow:Hide()
                    self.HomeMenuArrowButton = arrow
                else
                    arrow = self.HomeMenuArrowButton
                end
            end
            if not self.HomeButtonState then
                self.HomeButtonState = {
                    listFunc = home.listFunc,
                    arrow = arrow,
                    arrowShown = arrow:IsShown(),
                    width = home:GetWidth(),
                }
            end
            local nativeListFunc = self.HomeButtonState.listFunc
            local routeSelection = selection
            home.listFunc = function(button)
                local nativeList = nativeListFunc and nativeListFunc(button) or {}
                local list = {}
                for index, entry in ipairs(nativeList) do list[index] = entry end
                list[#list + 1] = {
                    text = dungeon.name or L.dungeonMaps,
                    id = dungeon.id,
                    func = function()
                        if provider.displayMode == MODE_WORLD
                            and provider.selection == routeSelection then
                            provider:ReturnToDungeon()
                        end
                    end,
                }
                return list
            end
            arrow:Show()
            if not addonArrow then home:SetWidth(home.text:GetStringWidth() + 53) end
            NavButtonTemplate_SetupDropdown(home, arrow)
            if NavBar_CheckLength then NavBar_CheckLength(nav) end
        end

        function provider:ShowDungeonNavigation()
            local nav = map.NavBar
            local selection = self.selection
            local dungeon = selection and selection.dungeon
            if not nav or not dungeon or not NavBar_Reset or not NavBar_AddButton then return end
            self:RestoreDungeonReturnMenu()
            NavBar_Reset(nav)
            NavBar_AddButton(nav, {
                name = dungeon.name or L.dungeonMaps,
                pyresinDungeonMap = true,
            })
        end

        function provider:ApplyNavigation()
            if self.displayMode == MODE_DUNGEON then
                self:ShowDungeonNavigation()
            elseif self.displayMode == MODE_WORLD and self.selection then
                self:ExposeDungeonReturnMenu()
            else
                self:RestoreDungeonReturnMenu()
            end
        end

        function provider:RefreshNavigation()
            local nav = map.NavBar
            if not nav then return end
            nav:Show()
            if nav.Refresh then nav:Refresh() else self:ApplyNavigation() end
        end

        function provider:SuppressNativeSurface()
            FindNativeSurface(map, self)
            if self.NativeFloorDropdown then self.NativeFloorDropdown:Hide() end
            if self.NativeCoordsPanel then self.NativeCoordsPanel:Hide() end
            if self.NativeAreaLabel then
                if self.NativeAreaLabelWasShown == nil then
                    self.NativeAreaLabelWasShown = self.NativeAreaLabel:IsShown()
                end
                if self.NativeAreaLabel.ClearAllLabels then self.NativeAreaLabel:ClearAllLabels() end
                self.NativeAreaLabel:Hide()
            end
            if GameTooltip and GameTooltip.GetOwner and GameTooltip.IsShown and GameTooltip:IsShown() then
                local owner = GameTooltip:GetOwner()
                while owner and owner ~= map and owner.GetParent do owner = owner:GetParent() end
                if owner == map then GameTooltip:Hide() end
            end
            if map.RegisterPin then map:RegisterPin(art) end
            if map.SetPinSuppressionDirty then map:SetPinSuppressionDirty() end
            if map.UpdatePinSuppression then map:UpdatePinSuppression() end
        end

        function provider:RestoreNativeSurface()
            if map.UnregisterPin then map:UnregisterPin(art) else art:ResetSuppression() end
            art:ResetSuppression()
            if map.SetPinSuppressionDirty then map:SetPinSuppressionDirty() end
            if self.NativeFloorDropdown and self.NativeFloorDropdown.Refresh then self.NativeFloorDropdown:Refresh() end
            if self.NativeCoordsPanel then
                self.NativeCoordsPanel:Show()
                if self.NativeCoordsPanel.CVarsUpdated then self.NativeCoordsPanel:CVarsUpdated() end
                if self.NativeCoordsPanel.PostRefresh then self.NativeCoordsPanel:PostRefresh() end
            end
            if self.NativeAreaLabel then
                if self.NativeAreaLabel.ClearAllLabels then self.NativeAreaLabel:ClearAllLabels() end
                self.NativeAreaLabel:SetShown(self.NativeAreaLabelWasShown ~= false)
                self.NativeAreaLabelWasShown = nil
            end
        end

        function provider:ScheduleInitialFit()
            self.fitGeneration = (self.fitGeneration or 0) + 1
            local generation = self.fitGeneration
            -- The native quest-panel spacer settles after WorldMapFrame's OnShow.
            art:SetScript("OnUpdate", function(frame)
                frame:SetScript("OnUpdate", nil)
                C_Timer.After(0, function()
                    if provider.fitGeneration ~= generation or provider.displayMode ~= MODE_DUNGEON
                        or not map:IsShown() then return end
                    if map.ResetZoom then map:ResetZoom(true) end
                end)
            end)
        end

        function provider:SetDisplayMode(mode, selection)
            local previousMode = self.displayMode
            local previousSelection = self.selection
            local leavingDungeon = previousMode == MODE_DUNGEON and mode ~= MODE_DUNGEON
            local enteringDungeon = previousMode ~= MODE_DUNGEON and mode == MODE_DUNGEON
            local changedDungeon = mode == MODE_DUNGEON and (not previousSelection
                or previousSelection.dungeon ~= selection.dungeon)
            if previousMode ~= mode or changedDungeon then
                self.fitGeneration = (self.fitGeneration or 0) + 1
                art:SetScript("OnUpdate", nil)
            end

            -- Hooks fired by native surface restoration must observe the destination state.
            self.displayMode = mode
            self.selection = selection

            if leavingDungeon then
                art:Hide()
                floorDropdown:Hide()
                status:Hide()
                self:RestoreNativeSurface()
                if self.interaction then
                    SetInteraction(map, self.interaction.navigate, self.interaction.zoom, self.interaction.pan)
                    self.interaction = nil
                end
            end

            if enteringDungeon then
                self.interaction = GetInteraction(map)
                SetInteraction(map, false, self.interaction.zoom, self.interaction.pan)
                art:Show()
                status:Show()
                self:SuppressNativeSurface()
                self:DisplayFloor(selection.floor)
            elseif mode == MODE_DUNGEON then
                self:DisplayFloor(selection.floor)
            end

            if leavingDungeon then
                if mode ~= MODE_IDLE and map.ResetZoom then map:ResetZoom() end
                if map.RefreshAllDataProviders then map:RefreshAllDataProviders() end
            end
            self:RefreshNavigation()
            if enteringDungeon or changedDungeon then self:ScheduleInitialFit() end
        end

        function provider:ClearSelection()
            self:SetDisplayMode(MODE_IDLE, nil)
        end

        function provider:SelectionIsValid()
            local selection = self.selection
            if not selection then return false end
            local dungeon = maps.FindDungeon(InstanceInfo())
            if dungeon ~= selection.dungeon then return false end
            local floor = maps.FindFloor(dungeon, GetSubZoneText and GetSubZoneText(), selection.floor)
            return floor ~= nil
        end

        function provider:ReturnToDungeon()
            local selection = self.selection
            if self.displayMode ~= MODE_WORLD or not self:SelectionIsValid() then
                self:ClearSelection()
                return false
            end
            if type(selection.backingMapID) == "number" and map:GetMapID() ~= selection.backingMapID then
                map:SetMapID(selection.backingMapID)
            end
            self:SetDisplayMode(MODE_DUNGEON, selection)
            return true
        end

        function provider:NavigateToWorldMap()
            if self.displayMode ~= MODE_DUNGEON then return false end
            self:SetDisplayMode(MODE_WORLD, self.selection)
            local home = map.NavBar and map.NavBar.homeButton
            if home and home.myclick then home:myclick("LeftButton") end
            return true
        end

        function provider:Refresh(preserveFloor)
            local dungeon = maps.FindDungeon(InstanceInfo())
            if not dungeon then self:ClearSelection(); return false end
            if HasNativeDungeonMap(map) then
                self:SetDisplayMode(MODE_WORLD, nil)
                return true
            end
            local previousSelection = self.selection
            local selection = previousSelection
            if not selection or selection.dungeon ~= dungeon then
                selection = { dungeon = dungeon, backingMapID = map:GetMapID() }
            end
            local floorIndex = maps.FindFloor(dungeon, GetSubZoneText and GetSubZoneText(),
                preserveFloor and previousSelection and previousSelection.dungeon == dungeon
                    and previousSelection.floor or nil)
            if not floorIndex then
                self:SetDisplayMode(MODE_WORLD, nil)
                return false
            end
            selection.floor = floorIndex
            self:SetDisplayMode(MODE_DUNGEON, selection)
            return true
        end

        provider.canvasClickHandler = function(_, button)
            if provider.displayMode ~= MODE_DUNGEON then return false end
            if button == "RightButton" then provider:NavigateToWorldMap() end
            return button == "LeftButton" or button == "RightButton"
        end
        if map.AddCanvasClickHandler then map:AddCanvasClickHandler(provider.canvasClickHandler, 1000) end
        art:SetScript("OnSizeChanged", function()
            local selection = provider.selection
            local floor = selection and selection.dungeon.floors[selection.floor]
            if floor then provider:DrawFloor(floor) end
        end)
        return provider
    end

    local function Install()
        if installed or not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
        installed = true
        local map = WorldMapFrame
        local provider = CreateProvider(map)

        if map.NavBar and map.NavBar.Refresh then
            hooksecurefunc(map.NavBar, "Refresh", function() provider:ApplyNavigation() end)
            if map.NavBar.GoToMap then
                hooksecurefunc(map.NavBar, "GoToMap", function()
                    if provider.displayMode == MODE_DUNGEON then
                        provider:SetDisplayMode(MODE_WORLD, provider.selection)
                    end
                end)
            end
        end

        map:HookScript("OnShow", function()
            if Enabled() then provider:Refresh(false) end
        end)
        map:HookScript("OnHide", function()
            provider:ClearSelection()
        end)
        hooksecurefunc(map, "SetMapID", function(_, mapID)
            local selection = provider.selection
            if provider.displayMode == MODE_DUNGEON and selection and mapID ~= selection.backingMapID then
                provider:SetDisplayMode(MODE_WORLD, selection)
            elseif selection then
                provider:RefreshNavigation()
            end
        end)
        hooksecurefunc(map, "AcquirePin", function()
            if provider.displayMode == MODE_DUNGEON and map.SetPinSuppressionDirty and map.UpdatePinSuppression then
                map:SetPinSuppressionDirty()
                map:UpdatePinSuppression()
            end
        end)
        hooksecurefunc(map, "RefreshAllDataProviders", function()
            if provider.displayMode == MODE_DUNGEON and map.SetPinSuppressionDirty and map.UpdatePinSuppression then
                map:SetPinSuppressionDirty()
                map:UpdatePinSuppression()
            end
        end)

        function maps.Update(force)
            if not Enabled() then provider:ClearSelection(); return end
            if provider.displayMode == MODE_DUNGEON then
                provider:Refresh(true)
            elseif provider.displayMode == MODE_WORLD then
                if provider.selection and not provider:SelectionIsValid() then provider:ClearSelection() end
            elseif force and map:IsShown() and provider.displayMode == MODE_IDLE then
                provider:Refresh(false)
            end
        end
        function module.UpdateDungeonMaps() maps.Update(true) end
        module.dungeonMapProvider = provider
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ZONE_CHANGED")
    events:RegisterEvent("ZONE_CHANGED_INDOORS")
    events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    events:SetScript("OnEvent", function(_, event, addon)
        if event == "ADDON_LOADED" and addon ~= "Blizzard_WorldMap" then return end
        Install()
        if installed and (event == "PLAYER_ENTERING_WORLD" or event:match("^ZONE_")) then maps.Update(false) end
    end)
    Install()
end)
