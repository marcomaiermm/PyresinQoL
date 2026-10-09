local _, ns = ...

ns.RegisterModule("performance", function(module)
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

    local function Enabled() return PyresinQoLDB.showFPS ~= false or PyresinQoLDB.showLatency ~= false end
    local entry = ns.CreateEditModeDisplay(display, {
        name = "PyresinQoL · FPS / MS", positionKey = "performancePosition", IsAvailable = Enabled,
        default = { "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -260, 20 },
    })
    module.performanceDisplay = display

    function module.UpdatePerformanceVisibility()
        entry.Update()
        display:SetShown(Enabled())
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

    display:RegisterEvent("PLAYER_LOGIN")
    display:SetScript("OnEvent", function()
        PyresinQoLDB = PyresinQoLDB or {}
        entry.Restore()
        UpdateValues()
        module.UpdatePerformanceLayout()
        display:UnregisterEvent("PLAYER_LOGIN")
    end)
end)
