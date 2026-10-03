local _, ns = ...

function ns.AuraNumber(key, default, minimum, maximum)
    local value = PyresinQoLDB[key]
    if type(value) ~= "number" or value ~= value then return default end
    return math.floor(math.max(minimum, math.min(maximum, value)))
end

ns.RegisterModule("unitFrames", function(module)
    local records = {}
    local nativeLayouts = {}
    -- Measure only addon-owned text: native aura duration strings can be restricted.
    local timerMeasure = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    timerMeasure:SetText("0")
    timerMeasure:Hide()

    local function Public(value)
        return not (issecretvalue and issecretvalue(value))
    end

    local function CaptureLayout(owner)
        local layout = { size = { owner:GetSize() }, regions = {} }
        local function Capture(region, size)
            local count = region:GetNumPoints()
            -- Native aura geometry can become secret on combat/respawn updates.
            -- Keep the last complete snapshot rather than saving empty anchors.
            if not Public(count) or type(count) ~= "number" then return false end
            local state = { region = region, points = {}, size = size and { region:GetSize() } }
            for index = 1, count do state.points[index] = { region:GetPoint(index) } end
            layout.regions[#layout.regions + 1] = state
            return true
        end
        if not Capture(owner.AuraContainer) then return end
        local buttons = {}
        for _, button in ipairs(owner.auraFrames or {}) do buttons[#buttons + 1] = button end
        if owner.ConsolidatedBuffs then buttons[#buttons + 1] = owner.ConsolidatedBuffs end
        for _, button in ipairs(buttons) do
            if not Capture(button, true) or not Capture(button.Icon) or not Capture(button.Duration) then return end
        end
        if owner.CollapseAndExpandButton then
            if not Capture(owner.CollapseAndExpandButton) then return end
            layout.orientation = owner.CollapseAndExpandButton.orientation
            layout.expandDirection = owner.CollapseAndExpandButton.expandDirection
        end
        nativeLayouts[owner] = layout
        return layout
    end

    local function RestoreLayout(owner, layout)
        owner:SetSize(unpack(layout.size))
        for _, state in ipairs(layout.regions) do
            if state.size then state.region:SetSize(unpack(state.size)) end
            state.region:ClearAllPoints()
            for _, point in ipairs(state.points) do state.region:SetPoint(unpack(point)) end
        end
        local toggle = owner.CollapseAndExpandButton
        if toggle then
            toggle.orientation, toggle.expandDirection = layout.orientation, layout.expandDirection
            toggle:UpdateOrientation()
        end
        layout.applied = false
    end

    local function StyleTimer(button, record)
        local config = record.config
        if not config then return end
        button.Duration:SetFont(record.font, config.fontSize, record.flags)
        button.Duration:SetAlpha(config.timer == "hidden" and 0 or 1)
        local position = config.timer == "native" and (config.up and "above" or "below") or config.timer
        button.Duration:ClearAllPoints()
        if position == "inside" then
            button.Duration:SetPoint("CENTER", button.Icon, "CENTER")
        elseif position == "above" then
            button.Duration:SetPoint("BOTTOM", button.Icon, "TOP", 0, config.timerGap)
        else
            button.Duration:SetPoint("TOP", button.Icon, "BOTTOM", 0, -config.timerGap)
        end
        if record.clipped then button:SetAlpha(0) end
    end

    local function Layout(owner, prefix)
        local container = owner.AuraContainer
        if not container then return end
        local enabled = PyresinQoLDB[prefix .. "Layout"] == true
        local nativeLayout = nativeLayouts[owner]
        if enabled then
            nativeLayout = nativeLayout or CaptureLayout(owner)
            if not nativeLayout then return end
            nativeLayout.applied = true
        end
        local config = {
            size = ns.AuraNumber(prefix .. "Size", 30, 16, 64),
            wrap = ns.AuraNumber(prefix .. "Wrap", 8, 1, 32),
            rows = ns.AuraNumber(prefix .. "Rows", 4, 1, 8),
            gapX = ns.AuraNumber(prefix .. "GapX", 5, 0, 40),
            gapY = ns.AuraNumber(prefix .. "GapY", 14, 0, 40),
            fontSize = ns.AuraNumber(prefix .. "TimerSize", 12, 8, 24),
            timerGap = ns.AuraNumber(prefix .. "TimerGap", 0, 0, 16),
            timer = PyresinQoLDB[prefix .. "TimerPosition"] or "native",
            swipe = PyresinQoLDB[prefix .. "Swipe"] == true,
            numbers = PyresinQoLDB[prefix .. "CooldownNumbers"] == true,
        }
        local entries, anchors = {}, {}
        local timerHeight = config.fontSize
        local now = GetTime()
        for index, button in ipairs(owner.auraFrames or {}) do
            if button.isAuraAnchor then
                if not owner:IsEditing() then anchors[#anchors + 1] = button end
            else
                local record = records[button]
                if enabled and not record then
                    local font, fontSize, flags = button.Duration:GetFont()
                    record = { font = font, fontSize = fontSize, flags = flags }
                    records[button] = record
                    button:HookScript("OnUpdate", function() StyleTimer(button, record) end)
                end
                if record then
                    if enabled then
                        timerMeasure:SetFont(record.font, config.fontSize, record.flags)
                        timerHeight = math.max(timerHeight, timerMeasure:GetStringHeight())
                    end
                    if record.clipped then button:SetAlpha(1); button:EnableMouse(true) end
                    record.clipped = false
                    record.config = enabled and config or nil
                    if not enabled then
                        button.Icon:SetSize(30, 30)
                        button.DebuffBorder:SetSize(40, 40)
                        button.TempEnchantBorder:SetSize(32, 32)
                        button.Duration:SetFont(record.font, record.fontSize, record.flags)
                        button.Duration:SetAlpha(1)
                        if record.cooldown then record.cooldown:Hide() end
                    end
                end
                if enabled and (button.hasValidInfo or button.isExample) then
                    local info = not button.isExample and button.buttonInfo or {}
                    local aura = Public(info.auraInstanceID) and info.auraInstanceID
                        and C_UnitAuras.GetAuraDataByAuraInstanceID(PlayerFrame.unit, info.auraInstanceID)
                    local source = aura and aura.sourceUnit
                    local own = info.auraType == "TempEnchant" or Public(source)
                        and (source == "player" or source == "pet" or source == "vehicle")
                    local expiration = Public(info.expirationTime) and info.expirationTime or 0
                    local modifier = Public(info.timeMod) and info.timeMod or 0
                    local remaining = expiration > 0 and math.max(0, expiration - now) or math.huge
                    if modifier > 0 then remaining = remaining / modifier end
                    entries[#entries + 1] = { button = button, index = index, own = own,
                        name = aura and Public(aura.name) and aura.name or "",
                        remaining = remaining }
                end
            end
        end
        if not enabled then
            if nativeLayout and nativeLayout.applied then RestoreLayout(owner, nativeLayout) end
            return
        end

        local separate = PyresinQoLDB[prefix .. "Own"] or "mixed"
        local sort = PyresinQoLDB[prefix .. "Sort"] or "index"
        local reverse = PyresinQoLDB[prefix .. "SortDirection"] == "descending"
        table.sort(entries, function(a, b)
            if separate ~= "mixed" and a.own ~= b.own then
                return separate == "last" and not a.own or separate ~= "last" and a.own
            end
            local left, right = a.index, b.index
            if sort == "name" then left, right = a.name, b.name end
            if sort == "time" then left, right = a.remaining, b.remaining end
            if left == right then return a.index < b.index end
            if reverse then return left > right end
            return left < right
        end)

        local right = PyresinQoLDB[prefix .. "Direction"] == "RIGHT"
        local up = PyresinQoLDB[prefix .. "Growth"] == "UP"
        config.up = up
        local point = (up and "BOTTOM" or "TOP") .. (right and "LEFT" or "RIGHT")
        local scale = container.iconScale or 1
        timerHeight = (config.timer == "below" or config.timer == "above" or config.timer == "native")
            and timerHeight + config.timerGap or 0
        local consolidated = owner.ConsolidatedBuffs and owner.ConsolidatedBuffs:ShouldShow()
            and owner.ConsolidatedBuffs
        local nativeSlots = #anchors > 0 or consolidated
        local privateWidth = container.isHorizontal and 30 or 60
        local privateHeight = container.isHorizontal and 40 or 30
        local cellWidth = nativeSlots and math.max(privateWidth, config.size) or config.size
        local cellHeight = nativeSlots and math.max(privateHeight, config.size + timerHeight) or config.size + timerHeight
        local column, row, previousOwn = 0, 0, nil
        local maxColumns = 1
        local function Place(button, private)
            if column == config.wrap then column, row = 0, row + 1 end
            local record = records[button]
            if not private then
                record.clipped = row >= config.rows
                button:SetAlpha(record.clipped and 0 or 1)
                button:EnableMouse(not record.clipped)
                button.Icon:SetSize(config.size, config.size)
                button.Icon:ClearAllPoints()
                local above = config.timer == "above" or config.timer == "native" and up
                button.Icon:SetPoint("TOP", button, "TOP", 0, above and -timerHeight or 0)
                button.DebuffBorder:SetSize(config.size + 10, config.size + 10)
                button.TempEnchantBorder:SetSize(config.size + 2, config.size + 2)
                local info = not button.isExample and button.buttonInfo or {}
                local expiration, duration = info.expirationTime, info.duration
                if (config.swipe or config.numbers) and Public(expiration) and expiration and expiration > 0
                    and Public(duration) then
                    if not record.cooldown then
                        record.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
                        record.cooldown:SetAllPoints(button.Icon)
                        record.cooldown:SetReverse(true)
                        record.cooldown:SetCountdownFont("NumberFontNormalSmall")
                    end
                    local cooldown = record.cooldown
                    cooldown:SetDrawSwipe(config.swipe)
                    cooldown:SetHideCountdownNumbers(not config.numbers)
                    local start = duration and duration > 0 and expiration - duration or GetTime()
                    local modifier = Public(info.timeMod) and info.timeMod or 1
                    cooldown:SetCooldown(start, duration and duration > 0 and duration or math.max(0, expiration - start),
                        modifier > 0 and modifier or 1)
                    cooldown:Show()
                elseif record.cooldown then
                    record.cooldown:Hide()
                end
                StyleTimer(button, record)
            end
            button:SetSize(private and privateWidth or config.size, private and privateHeight or cellHeight)
            button:ClearAllPoints()
            button:SetPoint(point, container, point, (right and 1 or -1) * column * (cellWidth + config.gapX),
                (up and 1 or -1) * row * (cellHeight + config.gapY))
            column = column + 1
            maxColumns = math.max(maxColumns, column)
        end
        if consolidated then Place(consolidated, true) end
        for _, entry in ipairs(entries) do
            if separate ~= "mixed" and PyresinQoLDB[prefix .. "OwnRow"] == true
                and previousOwn ~= nil and previousOwn ~= entry.own and column > 0 then
                column, row = 0, row + 1
            end
            Place(entry.button, false)
            previousOwn = entry.own
        end
        -- Private boss auras always retain space, even past the configured row limit.
        if row >= config.rows then column, row = 0, config.rows end
        for _, button in ipairs(anchors) do Place(button, true) end
        local shownRows = #anchors > 0 and row + 1 or math.min(config.rows, row + 1)
        local toggle = owner.CollapseAndExpandButton
        local toggleWidth = toggle and toggle:GetWidth() or 0
        owner:SetSize((maxColumns * (cellWidth + config.gapX) - config.gapX + toggleWidth) * scale,
            (shownRows * (cellHeight + config.gapY) - config.gapY) * scale)
        container:ClearAllPoints()
        container:SetPoint(point, owner, point, (right and 1 or -1) * toggleWidth * scale, 0)
        if toggle then
            toggle:ClearAllPoints()
            toggle:SetPoint(point, owner, point)
            toggle.orientation = 0 -- Native horizontal orientation.
            toggle.expandDirection = right and 1 or 0
            toggle:UpdateOrientation()
        end
    end

    function module.UpdatePlayerAuras()
        if not PyresinQoLDB or not BuffFrame then return end
        -- Native aura rendering compares secret counts and must run only in Blizzard's context.
        Layout(BuffFrame, "buff")
        Layout(DebuffFrame, "debuff")
    end

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        for _, pair in ipairs({ { BuffFrame, "buff" }, { DebuffFrame, "debuff" } }) do
            local owner, prefix = pair[1], pair[2]
            hooksecurefunc(owner, "UpdateGridLayout", function()
                CaptureLayout(owner)
                Layout(owner, prefix)
            end)
            hooksecurefunc(owner, "UpdateAuraButtons", function() Layout(owner, prefix) end)
        end
        module.UpdatePlayerAuras()
    end)
end)
