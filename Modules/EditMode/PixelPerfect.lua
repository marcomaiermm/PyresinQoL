local _, ns = ...

ns.RegisterModule("editMode", function(module)
    local unitFrames = ns.GetModule("unitFrames")
    -- Our own displays (CustomDisplay.lua) carry their entry.
    local function Custom(frame) return frame and frame.customEditModeEntry end
    local selected, editing
    local dismissed = false
    local dragHooks = {}
    local snapTarget, targetDropdown
    local wasDragging = false
    local snapButtons = {}
    local coordinateInputs = {}
    local coordinates = {}
    local inputsEnabled, snapButtonsEnabled
    local matchWidth
    local panelX, panelY
    local panel = CreateFrame("Frame", "PyresinQoLPixelPerfect", UIParent, "BackdropTemplate")
    panel:SetSize(260, 160)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", -10, -10)
    title:SetWidth(210)

    local function CanMove()
        if not selected or not editing or not PyresinQoLDB or not PyresinQoLDB.pixelPerfectEditMode
            or InCombatLockdown() or EditModeManagerFrame:IsEditModeLocked() or not selected:IsShown() then
            return false
        end
        if Custom(selected) then
            return selected.Selection:IsShown()
        end
        return selected:CanBeMoved()
    end

    local function CanSnapTo(frame)
        return frame and frame ~= selected and frame:IsShown() and frame:GetRect() ~= nil
            and frame.Selection ~= nil
    end

    local function SetSnapTarget(frame)
        if snapTarget == frame then return end
        snapTarget = frame
        targetDropdown:GenerateMenu()
    end

    local function DetectSnapTarget()
        if not Custom(selected) then
            if not selected.isDragging and CanSnapTo(selected.snappedToFrame) then
                return selected.snappedToFrame
            end
            local candidates = EditModeMagnetismManager:GetMagneticFrameInfos(selected)
            for _, candidate in ipairs(candidates or {}) do
                if CanSnapTo(candidate.frame) then return candidate.frame end
            end
        end

        -- Use the same edge search for every mover when Blizzard has no frame candidate (e.g. grid snapping).
        local function Bounds(frame)
            local x, y, width, height = frame:GetRect()
            local scale = frame:GetEffectiveScale()
            return x * scale, y * scale, (x + width) * scale, (y + height) * scale
        end
        if not selected:GetRect() then return end
        local left, bottom, right, top = Bounds(selected)
        local nearest, distance = nil, EditModeMagnetismManager.magnetismRange
        local function Consider(frame)
            if not CanSnapTo(frame) then return end
            local fl, fb, fr, ft = Bounds(frame)
            local gap = math.huge
            if right >= fl and left <= fr then gap = math.min(math.abs(bottom - ft), math.abs(top - fb)) end
            if top >= fb and bottom <= ft then gap = math.min(gap, math.abs(left - fr), math.abs(right - fl)) end
            if gap <= distance then nearest, distance = frame, gap end
        end
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do Consider(frame) end
        for _, entry in ipairs(ns.customEditModeDisplays) do Consider(entry.frame) end
        return nearest
    end

    -- Rendered bounds in physical pixels. Like Blizzard's magnetism, Edit Mode frames are measured by their
    -- visible selection: frames such as the player frame carry invisible padding around their art.
    local function PixelBounds(frame)
        local region = frame.Selection or frame
        local x, y, width, height = region:GetRect()
        local scale = region:GetEffectiveScale() / PixelUtil.GetPixelToUIUnitFactor()
        return x * scale, y * scale, width * scale, height * scale
    end

    -- Blizzard settings that size the frame itself in whole UI units, as width and height.
    local function SizeSettings(frame)
        local system = frame and frame.system and Enum.EditModeSystem
        if not system then return end
        local width, height
        if frame.system == system.SwingTimer then
            width, height = Enum.EditModeSwingTimerSetting.Width, Enum.EditModeSwingTimerSetting.Height
        elseif frame.system == system.DamageMeter then
            width, height = Enum.EditModeDamageMeterSetting.FrameWidth, Enum.EditModeDamageMeterSetting.FrameHeight
        elseif frame.system == system.UnitFrame then -- Raid-style member frames.
            width, height = Enum.EditModeUnitFrameSetting.FrameWidth, Enum.EditModeUnitFrameSetting.FrameHeight
        elseif frame.system == system.ChatFrame then
            width, height = Enum.EditModeChatFrameDisplayOnlySetting.Width, Enum.EditModeChatFrameDisplayOnlySetting.Height
        end
        if width and frame:HasSetting(width) and frame:ShouldShowSetting(width) then return width, height end
    end

    -- With cast-bar customization, our own width setting sizes the player cast bar in its UI units.
    local function OwnsCastBarWidth(frame)
        return frame == PlayerCastingBarFrame and unitFrames.active and ns.CastBar.IsEnabled()
    end

    local function CanMatchWidth(frame)
        return SizeSettings(frame) ~= nil or OwnsCastBarWidth(frame) or (Custom(frame) and Custom(frame).width) ~= nil
    end

    -- 1 when the setting sizes the frame's width, 2 for its height.
    function module.GetSizeAxis(frame, setting)
        local width, height = SizeSettings(frame)
        return width and (setting == width and 1 or setting == height and 2) or nil
    end

    -- The size setting value that gives the frame the snap target's visible width (axis 1) or height (axis 2).
    -- Size settings grow the visible frame unit for unit, so shift the current value by the measured gap.
    function module.GetSnapTargetUnits(frame, axis, current)
        if not PyresinQoLDB.pixelPerfectEditMode or not CanSnapTo(snapTarget) or snapTarget == frame then return end
        local gap = select(axis + 2, PixelBounds(snapTarget)) - select(axis + 2, PixelBounds(frame))
        return math.floor(current + gap * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale() + 0.5)
    end

    local function GetCoordinates()
        if not selected then return end
        local x, y = selected:GetCenter()
        if not x then return end
        local centerX, centerY = UIParent:GetCenter()
        local scale, parentScale = selected:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local pixel = PixelUtil.GetPixelToUIUnitFactor()
        return (x * scale - centerX * parentScale) / pixel,
            (y * scale - centerY * parentScale) / pixel
    end

    local function UpdateCoordinates()
        local x, y = GetCoordinates()
        if not x then return end
        local enabled = not selected.isDragging
        for index, input in ipairs(coordinateInputs) do
            if inputsEnabled ~= enabled then input:SetEnabled(enabled) end
            local value = index == 1 and x or y
            if not input:HasFocus() and coordinates[index] ~= value then
                input:SetTextColor(1, 1, 1)
                input:SetText(("%.2f"):format(value))
                coordinates[index] = value
            end
        end
        inputsEnabled = enabled
    end

    -- Reuse geometry snapshots; idle polling must not allocate placement candidates.
    local selectedBounds, screenBounds, managerBounds, dialogBounds = {}, {}, {}, {}
    local lastPanelWidth, lastPanelHeight
    local function ReadBounds(frame, bounds)
        local x, y, width, height, scale
        if frame and frame:IsShown() then
            x, y, width, height = frame:GetRect()
            scale = frame:GetEffectiveScale()
        end
        local changed = bounds.x ~= x or bounds.y ~= y or bounds.width ~= width
            or bounds.height ~= height or bounds.scale ~= scale
        if changed then
            bounds.x, bounds.y, bounds.width, bounds.height, bounds.scale = x, y, width, height, scale
        end
        return changed
    end

    local function ParentBounds(bounds)
        if not bounds.x then return end
        local scale = bounds.scale / screenBounds.scale
        return bounds.x * scale, bounds.y * scale, bounds.width * scale, bounds.height * scale
    end

    local function UpdatePanelPosition()
        local selection = selected.Selection
        local changed = ReadBounds(selection and selection:IsShown() and selection or selected, selectedBounds)
        if ReadBounds(UIParent, screenBounds) then changed = true end
        if ReadBounds(EditModeManagerFrame, managerBounds) then changed = true end
        if ReadBounds(EditModeSystemSettingsDialog, dialogBounds) then changed = true end
        local panelWidth, panelHeight = panel:GetSize()
        if not changed and panelX and panelWidth == lastPanelWidth and panelHeight == lastPanelHeight then return end
        lastPanelWidth, lastPanelHeight = panelWidth, panelHeight
        local left, bottom, width, height = ParentBounds(selectedBounds)
        if not left then return end
        local screenLeft, screenBottom, screenWidth, screenHeight = ParentBounds(screenBounds)
        local gap = 12
        local centerX, centerY = left + (width - panelWidth) / 2, bottom + (height - panelHeight) / 2
        local bestX, bestY, bestOverlap
        -- Clamp each candidate before testing: screen clamping can otherwise push it onto the selected frame.
        for _, position in ipairs({
            { centerX, bottom - panelHeight - gap },
            { centerX, bottom + height + gap },
            { left + width + gap, centerY },
            { left - panelWidth - gap, centerY },
        }) do
            local x = math.max(screenLeft, math.min(position[1], screenLeft + screenWidth - panelWidth))
            local y = math.max(screenBottom, math.min(position[2], screenBottom + screenHeight - panelHeight))
            local function Overlap(ox, oy, ow, oh)
                return math.max(0, math.min(x + panelWidth, ox + ow + gap) - math.max(x, ox - gap))
                    * math.max(0, math.min(y + panelHeight, oy + oh + gap) - math.max(y, oy - gap))
            end
            local overlap = Overlap(left, bottom, width, height)
            for _, bounds in ipairs({ managerBounds, dialogBounds }) do
                local dx, dy, dw, dh = ParentBounds(bounds)
                if dx then overlap = overlap + Overlap(dx, dy, dw, dh) end
            end
            if not bestOverlap or overlap < bestOverlap then
                bestX, bestY, bestOverlap = x, y, overlap
            end
            if overlap == 0 then break end
        end
        -- If every side is obstructed, keep the controls on screen with the least overlap.
        if bestX ~= panelX or bestY ~= panelY then
            panel:ClearAllPoints()
            panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", bestX - screenLeft, bestY - screenBottom)
            panelX, panelY = bestX, bestY
        end
    end

    function module.UpdatePixelPerfectMode()
        if dismissed or not CanMove() then panel:Hide(); return end
        if selected.isDragging or wasDragging then
            SetSnapTarget(EditModeManagerFrame:IsSnapEnabled() and DetectSnapTarget() or nil)
        elseif snapTarget and not CanSnapTo(snapTarget) then
            SetSnapTarget(nil)
        end
        wasDragging = selected.isDragging
        -- Cast-bar customization can change while the bar stays selected.
        local canMatch = CanMatchWidth(selected)
        if canMatch ~= matchWidth:IsShown() then
            matchWidth:SetShown(canMatch)
            panel:SetSize(260, canMatch and 190 or 160)
        end
        UpdateCoordinates()
        UpdatePanelPosition()
        local enabled = not selected.isDragging and not not CanSnapTo(snapTarget)
        if snapButtonsEnabled ~= enabled then
            for _, button in ipairs(snapButtons) do button:SetEnabled(enabled) end
            snapButtonsEnabled = enabled
        end
        if not panel:IsShown() then panel:Show() end
    end

    function module.ClearPixelPerfectFrame(frame)
        if frame and selected ~= frame then return end
        for _, input in ipairs(coordinateInputs) do input:ClearFocus() end
        if selected and Custom(selected) and selected.Selection:IsShown() then
            selected.Selection:ShowHighlighted()
        end
        selected = nil
        dismissed = false
        snapTarget, wasDragging = nil, false
        panelX, panelY = nil, nil
        panel:Hide()
        panel:ClearAllPoints()
    end

    function module.OnPixelPerfectDragStart(frame)
        if selected == frame and frame.isDragging then
            dismissed = false
            module.UpdatePixelPerfectMode()
        end
    end

    function module.SelectPixelPerfectFrame(frame)
        module.ClearPixelPerfectFrame()
        selected = frame
        if not frame then return end
        if not Custom(frame) and not dragHooks[frame] then
            hooksecurefunc(frame, "OnDragStart", module.OnPixelPerfectDragStart)
            dragHooks[frame] = true
        end
        title:SetText((Custom(frame) or frame):GetSystemName())
        if EditModeManagerFrame:IsSnapEnabled() and CanSnapTo(frame.snappedToFrame) then
            snapTarget = frame.snappedToFrame
        end
        targetDropdown:GenerateMenu()
        module.UpdatePixelPerfectMode()
    end

    function module.TogglePixelPerfectFrame(frame)
        if not editing or InCombatLockdown() or EditModeManagerFrame:IsEditModeLocked() then return end
        if selected == frame then
            dismissed = not frame.isDragging and not dismissed
            module.UpdatePixelPerfectMode()
        else
            if Custom(frame) then EditModeManagerFrame:ClearSelectedSystem() end
            module.SelectPixelPerfectFrame(frame)
        end
    end

    local function Nudge(dx, dy)
        if not CanMove() or selected.isDragging then return end
        local frame = selected
        local step = PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
        if Custom(frame) then
            Custom(frame).Nudge(dx * step, dy * step)
        else
            -- Follow Blizzard's movement path so layout saving/reverting and managed frames still work.
            if frame.isManagedFrame and frame:IsInDefaultPosition() then frame:BreakFromFrameManager() end
            if frame == PlayerCastingBarFrame then
                EditModeManagerFrame:OnSystemSettingChange(frame, Enum.EditModeCastBarSetting.LockToPlayerFrame, 0)
            end
            frame:ClearFrameSnap()
            frame:StopMovingOrSizing()
            frame:BreakFrameSnap(dx * step, dy * step)
        end
        module.UpdatePixelPerfectMode()
    end

    for index, direction in ipairs({ { -1, 0, math.pi }, { 0, 1, math.pi / 2 },
        { 0, -1, -math.pi / 2 }, { 1, 0, 0 } }) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(30, 30)
        button:SetPoint("TOPLEFT", 66 + (index - 1) * 32, -48)
        button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        button:GetNormalTexture():SetRotation(direction[3])
        button:GetPushedTexture():SetRotation(direction[3])
        button:SetScript("OnClick", function() Nudge(direction[1], direction[2]) end)
    end

    targetDropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    targetDropdown:SetSize(236, 26)
    targetDropdown:SetPoint("TOPLEFT", 12, -84)
    targetDropdown:SetDefaultText(ns.L.snapTarget)
    targetDropdown:SetupMenu(function(_, root)
        root:SetScrollMode(240)
        local function AddTarget(frame)
            if CanSnapTo(frame) then
                local name = (Custom(frame) or frame):GetSystemName()
                root:CreateRadio(name, function() return snapTarget == frame end, function()
                    snapTarget = frame
                    module.UpdatePixelPerfectMode()
                end)
            end
        end
        for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do AddTarget(frame) end
        for _, entry in ipairs(ns.customEditModeDisplays) do AddTarget(entry.frame) end
    end)

    local function Snap(direction)
        if not CanMove() or selected.isDragging or not CanSnapTo(snapTarget) then return end
        local x, y, width, height = PixelBounds(selected)
        local tx, ty, tw, th = PixelBounds(snapTarget)
        local dx, dy = tx + tw / 2 - x - width / 2, 0
        if direction == "above" then dy = ty + th - y
        elseif direction == "below" then dy = ty - y - height end
        -- Reuse the normal movement path: the result is a saved position, not a permanent frame dependency.
        Nudge(dx, dy)
    end

    for index, option in ipairs({ { "above", ns.L.snapAbove }, { "below", ns.L.snapBelow }, { "center", ns.L.snapCenter } }) do
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(78, 24)
        button:SetPoint("BOTTOMLEFT", 10 + (index - 1) * 81, 10)
        button:SetText(option[2])
        button:SetScript("OnClick", function() Snap(option[1]) end)
        snapButtons[index] = button
    end

    for index, axis in ipairs({ "X", "Y" }) do
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", 12 + (index - 1) * 120, -29)
        label:SetText(axis .. ":")
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetSize(78, 20)
        input:SetPoint("TOPLEFT", 34 + (index - 1) * 120, -25)
        input:SetAutoFocus(false)
        input:SetMaxLetters(16)
        input:SetJustifyH("RIGHT")
        input:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(axis .. " (px)")
            GameTooltip:AddLine(ns.L.coordinateInputHelp, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        input:SetScript("OnLeave", function() GameTooltip:Hide() end)
        input:SetScript("OnEditFocusLost", function(self)
            self:HighlightText(0, 0)
            coordinates[index] = nil
            UpdateCoordinates()
        end)
        input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        local function Commit(self)
            if not self:HasFocus() or not CanMove() or selected.isDragging then self:ClearFocus(); return end
            local value = tonumber((self:GetText():gsub(",", ".")))
            local _, _, width, height = UIParent:GetRect()
            local limit = (index == 1 and width or height) * UIParent:GetEffectiveScale()
                / (2 * PixelUtil.GetPixelToUIUnitFactor())
            if not value or value ~= value or math.abs(value) > limit then
                self:SetTextColor(1, 0.2, 0.2)
                return
            end
            local x, y = GetCoordinates()
            if not x then self:ClearFocus(); return end
            self:ClearFocus()
            Nudge(index == 1 and value - x or 0, index == 2 and value - y or 0)
        end
        input:SetScript("OnEnterPressed", Commit)
        input:SetScript("OnTabPressed", function(self)
            Commit(self)
            if not self:HasFocus() and CanMove() and not selected.isDragging then
                coordinateInputs[3 - index]:SetFocus()
            end
        end)
        coordinateInputs[index] = input
    end
    local units = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    units:SetPoint("TOPLEFT", 237, -29)
    units:SetText("px")
    panel:SetScript("OnHide", function()
        for _, input in ipairs(coordinateInputs) do input:ClearFocus() end
    end)
    local closeButton = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", 0, -1)
    closeButton:SetScript("OnClick", function()
        dismissed = true
        panel:Hide()
    end)

    -- Copies the snap target's width through the owning setting: Blizzard's (Save/Revert keep working) or ours.
    matchWidth = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    matchWidth:SetSize(236, 24)
    matchWidth:SetPoint("TOPLEFT", 12, -116)
    matchWidth:SetText(ns.L.snapWidth)
    matchWidth:Hide()
    matchWidth:SetScript("OnClick", function()
        if not CanMove() or selected.isDragging or not CanMatchWidth(selected) then return end
        local width = Custom(selected) and Custom(selected).width
        if width then
            -- The editor measures UI units; the setting sizes the display at Scale() of them each.
            local units = module.GetSnapTargetUnits(selected, 1, width.Get() * width.Scale())
            if units then width.Set(math.max(width.min, math.min(math.floor(units / width.Scale() + 0.5), width.max))) end
        elseif OwnsCastBarWidth(selected) then
            local units = module.GetSnapTargetUnits(selected, 1, (ns.CastBar.GetConfiguredSize()))
            local minimum, maximum = ns.CastBar.GetRange("width")
            if units then ns.CastBar.Set("width", math.max(minimum, math.min(units, maximum))) end
        else
            local setting = SizeSettings(selected)
            local units = module.GetSnapTargetUnits(selected, 1, selected:GetSettingValue(setting))
            local info = selected.settingDisplayInfoMap[setting]
            if units then
                EditModeManagerFrame:OnSystemSettingChange(selected, setting, math.max(info.minValue, math.min(units, info.maxValue)))
            end
        end
        module.UpdatePixelPerfectMode()
    end)
    snapButtons[#snapButtons + 1] = matchWidth

    -- Read the live position while dragging, including native keyboard movement and layout reverts.
    panel:SetScript("OnUpdate", module.UpdatePixelPerfectMode)
    hooksecurefunc(EditModeManagerFrame, "SelectSystem", function(_, frame)
        if frame.isSelected then module.TogglePixelPerfectFrame(frame) end
    end)
    hooksecurefunc(EditModeManagerFrame, "ClearSelectedSystem", function() module.ClearPixelPerfectFrame() end)
    hooksecurefunc(EditModeMagnetismManager, "ApplyMagnetism", function(_, frame)
        if selected == frame and CanMove() and EditModeManagerFrame:IsSnapEnabled() then
            SetSnapTarget(DetectSnapTarget())
        end
    end)
    EventRegistry:RegisterCallback("EditMode.Enter", function() editing = true end, panel)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        editing = false
        module.ClearPixelPerfectFrame()
    end, panel)
    panel:RegisterEvent("PLAYER_REGEN_DISABLED")
    panel:RegisterEvent("PLAYER_REGEN_ENABLED")
    panel:SetScript("OnEvent", module.UpdatePixelPerfectMode)
end)
