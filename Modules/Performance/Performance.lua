local _, ns = ...

ns.RegisterModule("performance", function(module)
    local editMode = ns.GetModule("editMode")
    local blockWidth, blockHeight = 85, 15
    local display = CreateFrame("Frame", "PyresinQoLPerformance", UIParent)
    display:SetSize(blockWidth, blockHeight * 2 + 5)
    display:SetMovable(true)
    display:SetClampedToScreen(true)
    display:EnableMouse(false)
    display:Hide()

    local rows = {}
    for index, name in ipairs({ "fps", "latency" }) do
        local caption = display:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
        caption:SetText(index == 1 and "FPS:" or "MS:")

        local value = display:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
        rows[name] = { caption = caption, value = value }
    end

    local function UpdateValues()
        local _, _, home, world = GetNetStats()
        rows.fps.value:SetFormattedText("%.1f", GetFramerate())
        rows.latency.value:SetText(tostring(math.max(home, world)))
    end

    local elapsedTime = 0
    display:SetScript("OnUpdate", function(_, elapsed)
        elapsedTime = elapsedTime + elapsed
        if elapsedTime >= 0.25 then
            elapsedTime = 0
            UpdateValues()
        end
    end)

    local mover = CreateFrame("Frame", nil, display, "EditModeSystemSelectionTemplate")
    mover:SetAllPoints(display)
    mover:SetSystem({ GetSystemName = function() return "PyresinQoL · FPS / MS" end })
    mover:Hide()
    display.Selection = mover
    module.performanceDisplay = display

    local editing = false
    function module.SavePerformancePosition()
        local x, y = display:GetCenter()
        local centerX, centerY = UIParent:GetCenter()
        -- ponytail: One shared position; use per-layout positions if separate layouts are needed.
        PyresinQoLDB.performancePosition = { x = x - centerX, y = y - centerY }
        display:ClearAllPoints()
        display:SetPoint("CENTER", UIParent, "CENTER", x - centerX, y - centerY)
    end

    local function StopDragging()
        if not display.isDragging then return end
        display:StopMovingOrSizing()
        display.isDragging = false
        module.SavePerformancePosition()
    end

    function module.UpdatePerformanceVisibility()
        local enabled = PyresinQoLDB.showFPS ~= false or PyresinQoLDB.showLatency ~= false
        if enabled and editing and not InCombatLockdown() then
            if not mover:IsShown() then mover:ShowHighlighted() end
        else
            mover:Hide()
        end
        display:SetShown(enabled)
    end

    function module.UpdatePerformanceLayout()
        local db = PyresinQoLDB
        local first = db.performanceOrder == "latency" and "latency" or "fps"
        local second = first == "fps" and "latency" or "fps"
        local column = db.performanceLayout ~= "row"
        local rowGap = db.performanceRowPadding or 14
        local columnGap = db.performanceColumnPadding or 5
        local count = 0
        local r, g, b = CreateColorFromHexString(db.performanceColor or "FFFFFFFF"):GetRGB()

        for _, name in ipairs({ first, second }) do
            local row = rows[name]
            local shown = db[name == "fps" and "showFPS" or "showLatency"] ~= false
            row.caption:SetShown(shown)
            row.value:SetShown(shown)
            row.caption:SetTextColor(r, g, b)
            row.value:SetTextColor(r, g, b)
            if shown then
                local x = column and 0 or count * (blockWidth + rowGap)
                local y = column and -count * (blockHeight + columnGap) or 0
                row.caption:ClearAllPoints()
                row.caption:SetPoint("TOPLEFT", display, "TOPLEFT", x, y)
                row.value:ClearAllPoints()
                row.value:SetPoint("TOPRIGHT", display, "TOPLEFT", x + blockWidth, y)
                count = count + 1
            end
        end

        display:SetSize(column and blockWidth or count * blockWidth + math.max(0, count - 1) * rowGap,
            column and count * blockHeight + math.max(0, count - 1) * columnGap or blockHeight)
        module.UpdatePerformanceVisibility()
    end

    mover:SetScript("OnMouseDown", function(self)
        if editing and not InCombatLockdown() then
            self:ShowSelected()
            if editMode.TogglePixelPerfectFrame then editMode.TogglePixelPerfectFrame(display) end
        end
    end)
    mover:SetScript("OnDragStart", function()
        if (PyresinQoLDB.showFPS ~= false or PyresinQoLDB.showLatency ~= false) and editing and not InCombatLockdown() then
            display.isDragging = true
            display:StartMoving()
            if editMode.OnPixelPerfectDragStart then editMode.OnPixelPerfectDragStart(display) end
        end
    end)
    mover:SetScript("OnDragStop", StopDragging)
    mover:SetScript("OnHide", function()
        StopDragging()
        if editMode.ClearPixelPerfectFrame then editMode.ClearPixelPerfectFrame(display) end
    end)

    EventRegistry:RegisterCallback("EditMode.Enter", function()
        editing = true
        module.UpdatePerformanceVisibility()
    end, display)
    EventRegistry:RegisterCallback("EditMode.Exit", function()
        editing = false
        mover:Hide()
    end, display)

    display:RegisterEvent("PLAYER_LOGIN")
    display:RegisterEvent("PLAYER_REGEN_DISABLED")
    display:RegisterEvent("PLAYER_REGEN_ENABLED")
    display:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            PyresinQoLDB = PyresinQoLDB or {}
            local position = PyresinQoLDB.performancePosition
            display:ClearAllPoints()
            if position then
                display:SetPoint("CENTER", UIParent, "CENTER", position.x, position.y)
            else
                display:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 20)
            end
            UpdateValues()
            module.UpdatePerformanceLayout()
            display:UnregisterEvent("PLAYER_LOGIN")
        else
            module.UpdatePerformanceVisibility()
        end
    end)
end)
